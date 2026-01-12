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
    func initialize() async {
        print("🚀 AppSessionManager: Initializing...")
        state = .startup
        
        // 1. Wait for Supabase to refresh token if needed
        await SupabaseService.shared.awaitSessionInitialization()
        
        // 2. Check Auth Status
        if SupabaseService.shared.isAuthenticated {
            print("AUTH: Valid session found.")
            await restoreSession()
        } else {
            print("AUTH: No session.")
            state = .unauthenticated
        }
    }
    
    /// Transitions a returning user from Auth -> Ready
    func restoreSession() async {
        print("🔄 RESTORE: Starting session restoration...")
        
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
                    // We move to .synchronizing and WAIT. 
                    // The UI layer (HabitTrackerApp) observes this state, runs the heavy sync,
                    // and then calls contentSyncCompleted().
                    state = .synchronizing
                } else {
                    print("⚠️ RESTORE: Profile exists but incomplete (no name). Redirecting to Onboarding.")
                    state = .onboarding
                }
                
            } else {
                print("⚠️ RESTORE: Authenticated but no profile found. New User.")
                state = .onboarding
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
    func loginSuccess() async {
        await restoreSession()
    }
    
    /// Explicitly start onboarding (called from SignUp)
    func startOnboarding() {
        print("🔰 START ONBOARDING")
        state = .onboarding
    }
    
    /// Called by the sync orchestrator (App/SyncService) when initial content pull is done
    func contentSyncCompleted() {
        print("✅ APP READY: Transitioning to .running")
        state = .running
    }
    
    /// Called when onboarding completes
    func completeOnboarding() {
        state = .running
    }
    
    /// Start logout process - Freezes Sync
    func beginLogout() {
        print("🛑 LOGOUT: Initiating tear down... Sync Frozen.")
        state = .tearingDown
    }
    
    /// Deletes account from remote and wipes all local data
    func deleteAccount(modelContext: ModelContext? = nil) async throws {
        print("🛑 DELETE ACCOUNT: Initiating permanent deletion...")
        beginLogout() // Freeze sync
        
        // 1. Delete Remote
        try await SupabaseService.shared.deleteAccount()
        
        // 2. Logout and Wipe
        await completeLogout(shouldWipe: true, modelContext: modelContext)
    }

    /// Finish logout.
    /// - Parameter shouldWipe: If true, wipes all local data (Flow 6B). If false, keeps data (Flow 6A).
    func completeLogout(shouldWipe: Bool = false, modelContext: ModelContext? = nil) async {
        do {
            try await SupabaseService.shared.signOut(preserveLocalState: !shouldWipe)
            
            if shouldWipe {
                wipeAllLocalData()
                if let modelContext {
                    wipeAllSwiftData(modelContext: modelContext)
                }
            } else {
                // Flow 6A: Log out (keep data)
                // We only clear the active session tokens so the user is "logged out"
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: "supabase_session")
                defaults.removeObject(forKey: "supabase_access_token")
                defaults.set(false, forKey: "isAuthenticated")
                
                // NOTE: We KEEP `hasCompletedOnboarding`, `userName`, and SwiftData
                // This allows "Logging back in restores immediately" (Flow 6A)
            }
            
        } catch {
            print("Logout error: \(error)")
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
            try modelContext.delete(model: CategoryModel.self)
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
}
