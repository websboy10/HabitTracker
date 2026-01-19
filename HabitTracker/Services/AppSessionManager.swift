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
    
    // Publish changes for UI routing
    var isReady: Bool { state == .running }
    var isInteracting: Bool { state == .running || state == .synchronizing }
    
    private init() {}
    
    /// Called on App Launch
    /// Auth state is resolved BEFORE any data or notification operations.
    func initialize(modelContext: ModelContext) async {
        SyncLogger.logAuth("AppSessionManager initializing")
        state = .startup
        
        // 1. Resolve storage mode before any data operations
        StorageMode.resolve()
        
        // 2. Wait for Supabase session initialization
        await SupabaseService.shared.awaitSessionInitialization()
        
        // 3. Resolve auth state via AuthEngine (single authority)
        let authState = await AuthEngine.shared.resolve()
        
        // 4. Map auth state to app lifecycle state
        switch authState {
        case .authenticated:
            SyncLogger.logAuth("Auth resolved: authenticated")
            await restoreSession(modelContext: modelContext)
        case .invalid:
            SyncLogger.logAuth("Auth resolved: invalid - requires re-login")
            await NotificationEngine.shared.cancelAllNotifications(reason: "auth-invalid")
            state = .unauthenticated
        case .unauthenticated, .authenticating:
            SyncLogger.logAuth("Auth resolved: unauthenticated")
            await NotificationEngine.shared.cancelAllNotifications(reason: "auth-unauthenticated")
            state = .unauthenticated
        }
    }
    
    /// Transitions a returning user from Auth -> Ready
    func restoreSession(modelContext: ModelContext) async {
        print("🔄 RESTORE: Starting session restoration...")
        
        // 0. Security: User Data Isolation Check
        await verifySessionSecurity(modelContext: modelContext)
        
        // 1. Identity Phase
        state = .restoringIdentity
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
                    
                    // 2. Content Phase
                    state = .synchronizing
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
                // If we are offline but have local data, we assume we can run
                // But we must be careful about sync.
                // For now, let's treat as running (offline mode)
                state = .running
            } else {
                state = .unauthenticated
            }
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
    }
    
    /// Start logout process - Freezes Sync
    func beginLogout() {
        print("🛑 LOGOUT: Initiating tear down... Sync Frozen.")
        state = .tearingDown
        Task { @MainActor in
            await NotificationEngine.shared.cancelAllNotifications(reason: "logout")
        }
    }
    
    /// Deletes account from remote and wipes all local data.
    /// If auth deletion fails, the operation fails entirely.
    func deleteAccount(modelContext: ModelContext? = nil) async throws {
        SyncLogger.logAccount("Starting account deletion")
        beginLogout() // Freeze sync
        await NotificationEngine.shared.cancelAllNotifications(reason: "delete-account")
        
        do {
            // 1. Delete Remote - MUST succeed
            try await SupabaseService.shared.deleteAccount()
            SyncLogger.logAccount("Account deleted from Supabase")
            
            // 2. Wipe all local data
            await completeLogout(shouldWipe: true, modelContext: modelContext)
            
            // 3. Clear mutation queue
            MutationQueue.shared.clear()
            
            SyncLogger.logAccount("Account deletion complete")
        } catch {
            // If deletion fails, abort - do not proceed with local wipe
            SyncLogger.logAccount("Account deletion failed: \(error.localizedDescription)", level: .error)
            state = .running // Restore state
            throw error
        }
    }
    
    /// Finish logout.
    /// - Parameter shouldWipe: If true, wipes all local data (Flow 6B). If false, keeps data (Flow 6A).
    func completeLogout(shouldWipe: Bool = false, modelContext: ModelContext? = nil) async {
        // Use AuthEngine as single authority for logout
        await AuthEngine.shared.logout()
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
            // Use .synchronizing so that SyncService can attempt to sync (and potentially repair profile if we added that logic)
            // But if profile is missing, SyncService might fail partial syncs.
            // However, allowing access is better than blocking.
            state = .synchronizing
        } else {
            print("ℹ️ New User detected (or local onboarding incomplete). Redirecting to Onboarding.")
            state = .onboarding
            Task { @MainActor in
                _ = await NotificationEngine.shared.requestAuthorizationAfterSignup()
            }
        }
    }
}
