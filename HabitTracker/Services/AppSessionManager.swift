import SwiftUI
import Combine
import SwiftData

/// Specific phases of the app lifecycle.
/// The app must strictly adhere to these states to avoid race conditions.
enum AppLifecycleState: String, CaseIterable {
    case startup            // Initial launch check
    case authenticating     // User is logging in
    case onboarding         // User is authenticated but needs to complete flow
    case restoringIdentity  // Fetching remote profile/settings (Cloud Authoritative)
    case synchronizing      // Initial content pull (Goals/Tasks)
    case running            // Normal operation (Read/Write allowed)
    case tearingDown        // Logging out (Sync FROZEN)
    case unauthenticated    // Show AuthView
}

/// The Single Source of Truth for the app's overall state.
/// This manager coordinates Auth, Data, and UI transitions to prevent race conditions.
@MainActor
final class AppSessionManager: ObservableObject {
    
    static let shared = AppSessionManager()
    
    @Published var state: AppLifecycleState = .startup
    @Published private(set) var authState: AuthState = .unauthenticated
    @Published private(set) var securityLock: Bool = false
    
    // Publish changes for UI routing
    var isReady: Bool { state == .running }
    var isInteracting: Bool { state == .running || state == .synchronizing }
    
    private init() {}
    
    /// Called on App Launch
    /// Auth state is resolved BEFORE any data or notification operations.
    func initialize(modelContext: ModelContext) async {
        SyncLogger.logAuth("AppSessionManager initializing")
        state = .startup
        securityLock = true
        setSharedModelContext(modelContext)

        if handlePendingDeletionIfNeeded(modelContext: modelContext) {
            return
        }
        
        // 1. Resolve storage mode before any data operations
        StorageMode.resolve()
        
        // 2. Wait for Supabase session initialization
        await SupabaseService.shared.awaitSessionInitialization()
        
        // 3. Resolve auth state via AuthEngine (single authority)
        let authState = await AuthEngine.shared.resolve()
        
        // 4. Map auth state to app lifecycle state
        await applyAuthState(authState, modelContext: modelContext)
    }

    /// Reconcile app lifecycle after an auth attempt completes.
    func handleAuthStateChange(modelContext: ModelContext) async {
        let latest = AuthEngine.shared.state
        await applyAuthState(latest, modelContext: modelContext)
    }
    
    /// Transitions a returning user from Auth -> Ready
    func restoreSession(modelContext: ModelContext) async {
        print("🔄 RESTORE: Starting session restoration...")
        
        // 0. Security: User Data Isolation Check
        await verifySessionSecurity(modelContext: modelContext)
        
        // 1. Lock operations until lifecycle is fully ready
        lockSecurityOperations(reason: "restore-session")
        state = .running
        do {
            // Force pull profile & settings (Bypass local)
            if let profile = try await SupabaseService.shared.getProfileForAuth() {
                
                // Check if profile is fully initialized (has name)
                // This handles cases where DB triggers create an empty profile row on signup
                if let name = profile.name, !name.isEmpty {
                    print("✅ RESTORE: Identity found: \(name)")
                    
                    // Update local storage to match authoritative cloud identity
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    UserDefaults.standard.set(name, forKey: "userName")
                    
                    // Fetch & Apply settings
                    if let settings = try await SupabaseService.shared.getSettingsForAuth() {
                        applyRemoteSettings(settings)
                    }
                    
                    // 2. Content Phase (sync in running state)
                    await performInitialSyncIfNeeded(modelContext: modelContext)
                } else {
                    print("⚠️ RESTORE: Profile exists but incomplete (no name). Checking local fallback.")
                    checkLocalOnboardingFallback()
                }
                
            } else {
                print("⚠️ RESTORE: Authenticated but no profile found. Checking local fallback.")
                checkLocalOnboardingFallback()
            }
        } catch {
            print("❌ RESTORE FAILED: \(error)")
            // Fallback
            if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                state = .running
                await performInitialSyncIfNeeded(modelContext: modelContext)
            } else {
                state = .unauthenticated
            }
        }
        
        if state == .running {
            SyncService.shared.unfreezeSync(reason: "restore-session-complete")
            unlockSecurityOperations(reason: "restore-session-complete")
        }
    }
    
    /// Explicitly Login (called from AuthViewModel)
    func loginSuccess(modelContext: ModelContext) async {
        await restoreSession(modelContext: modelContext)
    }
    
    /// Explicitly start onboarding (called from SignUp)
    func startOnboarding(modelContext: ModelContext) async {
        print("🔰 START ONBOARDING")
        
        // Security check for new signups (prevents leaking previous user data)
        await verifySessionSecurity(modelContext: modelContext)
        
        unlockSecurityOperations(reason: "start-onboarding")
        state = .onboarding
        await NotificationEngine.shared.requestAuthorizationAfterSignup()
    }
    
    /// Verifies that the current Supabase user matches the last known local user.
    /// If there is a mismatch, it WIPES all local data to prevent privacy leaks.
    private func verifySessionSecurity(modelContext: ModelContext) async {
        let currentUserId = SupabaseService.shared.currentUserId
        let lastUserId = UserDefaults.standard.string(forKey: "lastAuthenticatedUserId")
        
        if let current = currentUserId {
            // If we have a stored ID and it doesn't match current -> WIPE
            // Also, if we have NO stored ID (fresh install or wiped), we are fine.
            // But if we had a previous user who just logged out (lastUserId exists),
            // and now a NEW user is here (currentUserId != lastUserId) -> WIPE.
            if let last = lastUserId, last != current {
                print("🔒 SECURITY: User switch detected (\(last) -> \(current)). Wiping local data.")
                SyncLogger.logAccount("User switch detected! Wiping local data.")
                wipeAllLocalData()
                wipeAllSwiftData(modelContext: modelContext)
            } else if lastUserId == nil {
                 // First time user on this install? Or data wiped.
                 // Ensure we start clean implies we trust current state.
            }
            
            // Establish trust for this session
            UserDefaults.standard.set(current, forKey: "lastAuthenticatedUserId")
        }
    }
    
    /// Called by the sync orchestrator (App/SyncService) when initial content pull is done
    /// INVARIANT: If sync fails, app must NOT transition to .running
    func contentSyncCompleted(success: Bool) {
        if success {
            print("✅ APP READY: Transitioning to .running")
            state = .running
        } else {
            SyncLogger.logSync("Initial sync failed - app remains in synchronizing state", level: .error)
            print("⚠️ SYNC FAILED: App staying in .synchronizing state")
            // Stay in .synchronizing - user can retry
        }
    }
    
    /// Called when onboarding completes
    func completeOnboarding() {
        state = .running
        SyncService.shared.unfreezeSync(reason: "complete-onboarding")
        unlockSecurityOperations(reason: "complete-onboarding")
    }
    
    /// Start logout process - Freezes Sync
    func beginLogout() {
        print("🛑 LOGOUT: Initiating tear down... Sync Frozen.")
        lockSecurityOperations(reason: "begin-logout")
        SyncService.shared.cancelInFlight(reason: "logout")
        SyncService.shared.freezeSync(reason: "logout")
        state = .tearingDown
        Task { @MainActor in
            await NotificationEngine.shared.cancelAllNotifications(reason: "logout")
        }
    }
    
    /// Deletes account from remote and wipes all local data.
    /// If auth deletion fails, the operation fails entirely.
    func deleteAccount(modelContext: ModelContext? = nil) async throws {
        SyncLogger.logAccount("Starting account deletion")
        lockSecurityOperations(reason: "delete-account")
        SyncService.shared.cancelInFlight(reason: "delete-account")
        SyncService.shared.freezeSync(reason: "delete-account")
        await NotificationEngine.shared.cancelAllNotifications(reason: "delete-account")
        
        do {
            // 1. Revoke auth + delete server-side data (provider-agnostic)
            try await SupabaseService.shared.deleteAccount()
            SyncLogger.logAccount("Account deleted from Supabase")
            UserDefaults.standard.set(true, forKey: "pendingAccountDeletion")
            
            // 2. Wipe all local data
            if let modelContext {
                wipeAllSwiftData(modelContext: modelContext)
            }
            wipeAllLocalData()
            
            // 3. Clear auth/provider state
            AuthEngine.shared.purgeLocalStateAfterDeletion()
            authState = .unauthenticated
            
            // 4. Clear mutation queue
            MutationQueue.shared.clear()
            
            // 5. Finalize lifecycle
            NotificationEngine.shared.clearNotificationSettingsOnLogout()
            UserDefaults.standard.removeObject(forKey: "pendingAccountDeletion")
            state = .unauthenticated
            unlockSecurityOperations(reason: "delete-account-complete")
            
            SyncLogger.logAccount("Account deletion complete")
        } catch {
            // If deletion fails, abort - do not proceed with local wipe
            SyncLogger.logAccount("Account deletion failed: \(error.localizedDescription)", level: .error)
            SyncService.shared.unfreezeSync(reason: "delete-account-failed")
            unlockSecurityOperations(reason: "delete-account-failed")
            state = .running // Restore state
            throw error
        }
    }
    
    /// Finish logout.
    /// - Parameter shouldWipe: If true, wipes all local data (Flow 6B). If false, keeps data (Flow 6A).
    func completeLogout(shouldWipe: Bool = false, modelContext: ModelContext? = nil) async {
        SyncService.shared.freezeSync(reason: "logout-complete")
        // Use AuthEngine as single authority for logout
        await AuthEngine.shared.logout()
        authState = .unauthenticated
        SyncLogger.logAuth("Logged out via AuthEngine")
        await NotificationEngine.shared.cancelAllNotifications(reason: "logout-complete")

        // Clear notification settings (report toggles, etc.) on logout
        NotificationEngine.shared.clearNotificationSettingsOnLogout()

        if shouldWipe {
            wipeAllLocalData()
            if let modelContext {
                wipeAllSwiftData(modelContext: modelContext)
            }
        } else {
            // Flow 6A: Log out (KEEP DATA - this is an invariant)
            // Auth state cleared by AuthEngine, but we keep local data
            // NOTE: We KEEP `hasCompletedOnboarding`, `userName`, and SwiftData
            // Logout NEVER deletes local data (invariant)
            // NOTE: Notification settings (including report toggles) ARE cleared on logout
        }

        MutationQueue.shared.clear()
        unlockSecurityOperations(reason: "logout-complete")
        state = .unauthenticated
    }
    
    /// Wipes all local data including UserDefaults and StorageMode
    private func wipeAllLocalData() {
        print("🧹 WIPING ALL LOCAL DATA...")
        
        // 1. Clear Storage Mode
        StorageMode.clear()
        
        // 2. Clear UserDefaults Domain (Aggressive Wipe)
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
        }
        
        // 3. Explicitly remove known keys (Fallback)
        let keys = [
            "supabase_session", "supabase_access_token", "isAuthenticated", 
            "hasCompletedOnboarding",
            "userName", "userTitle", "userAge", "userGoals",
            "theme", "onboardingTheme",
            "hapticFeedback", "compactLayout", "reduceMotion",
            "weekStart", "monthCalculation", "dayResetMinutes",
            "lastSyncDate"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    private func wipeAllSwiftData(modelContext: ModelContext) {
        do {
            try modelContext.delete(model: GoalModel.self)
            try modelContext.delete(model: ObligationModel.self)
            try modelContext.delete(model: WeeklyNoteModel.self)
            try modelContext.save()
        } catch {
            print("Failed to wipe local SwiftData: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func applyRemoteSettings(_ settings: UserSettingsDTO) {
        if let mode = settings.storageMode, let storage = StorageMode(rawValue: mode) {
            StorageMode.persist(storage)
        }
        if let theme = settings.theme {
            UserDefaults.standard.set(theme, forKey: "theme")
        }
        // ... apply other settings
    }
    
    private func checkLocalOnboardingFallback() {
        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            print("⚠️ RESTORE: Cloud profile missing/incomplete, but local onboarding complete. Trusting local.")
            state = .running
            Task { @MainActor in
                if let modelContext = AppSessionManager.sharedModelContext {
                    await performInitialSyncIfNeeded(modelContext: modelContext)
                }
            }
        } else {
            print("ℹ️ New User detected (or local onboarding incomplete). Redirecting to Onboarding.")
            state = .onboarding
            Task { @MainActor in
                _ = await NotificationEngine.shared.requestAuthorizationAfterSignup()
            }
        }
    }

    private func handlePendingDeletionIfNeeded(modelContext: ModelContext) -> Bool {
        guard UserDefaults.standard.bool(forKey: "pendingAccountDeletion") else { return false }
        SyncLogger.logAccount("Pending account deletion detected - finalizing local wipe")
        wipeAllSwiftData(modelContext: modelContext)
        wipeAllLocalData()
        AuthEngine.shared.purgeLocalStateAfterDeletion()
        MutationQueue.shared.clear()
        NotificationEngine.shared.clearNotificationSettingsOnLogout()
        UserDefaults.standard.removeObject(forKey: "pendingAccountDeletion")
        securityLock = false
        state = .unauthenticated
        return true
    }

    // MARK: - Initial Sync

    private static var sharedModelContext: ModelContext?
    
    func setSharedModelContext(_ modelContext: ModelContext) {
        AppSessionManager.sharedModelContext = modelContext
    }
    
    private func performInitialSyncIfNeeded(modelContext: ModelContext) async {
        guard StorageMode.isCloud else { return }
        await SyncService.shared.performFullSync(modelContext: modelContext, allowWhenLocked: true)
    }

    // MARK: - Auth State Mapping

    private func applyAuthState(_ authState: AuthState, modelContext: ModelContext) async {
        self.authState = authState
        
        switch authState {
        case .authenticated:
            SyncLogger.logAuth("Auth resolved: authenticated")
            lockSecurityOperations(reason: "auth-resolved")
            await restoreSession(modelContext: modelContext)
        case .waitingForEmailConfirmation:
            SyncLogger.logAuth("Auth resolved: waiting for email confirmation")
            await NotificationEngine.shared.cancelAllNotifications(reason: "auth-email-confirmation")
            SyncService.shared.freezeSync(reason: "auth-email-confirmation")
            unlockSecurityOperations(reason: "email-confirmation")
            state = .unauthenticated
        case .invalid:
            SyncLogger.logAuth("Auth resolved: invalid - requires re-login")
            await NotificationEngine.shared.cancelAllNotifications(reason: "auth-invalid")
            SyncService.shared.freezeSync(reason: "auth-invalid")
            unlockSecurityOperations(reason: "auth-invalid")
            state = .unauthenticated
        case .unauthenticated, .authenticating:
            SyncLogger.logAuth("Auth resolved: unauthenticated")
            await NotificationEngine.shared.cancelAllNotifications(reason: "auth-unauthenticated")
            SyncService.shared.freezeSync(reason: "auth-unauthenticated")
            unlockSecurityOperations(reason: "auth-unauthenticated")
            state = .unauthenticated
        }
    }

    // MARK: - Security Lock

    private func lockSecurityOperations(reason: String) {
        securityLock = true
        SyncLogger.logAuth("Security lock enabled: \(reason)")
    }

    private func unlockSecurityOperations(reason: String) {
        securityLock = false
        SyncLogger.logAuth("Security lock disabled: \(reason)")
    }
}
