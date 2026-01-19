import SwiftUI
import SwiftData

/// Main app entry point with SwiftData container.
@main
struct HabitTrackerApp: App {

    /// App delegate for orientation locking and system events
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Central Session Manager
    @StateObject private var session = AppSessionManager.shared

    /// SwiftData model container
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                GoalModel.self,
                ObligationModel.self,
                WeeklyNoteModel.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    /// Controls when main content is rendered (happens BEFORE splash removal)
    @State private var splashFinished = false

    /// Controls when splash view is removed from hierarchy (happens AFTER main content appears)
    @State private var splashRemoved = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Background layer - always present, prevents any flash-to-white
                Color.black.ignoresSafeArea()

                // Main State Switcher
                // Renders main content as soon as splash signals finish (while splash is still at opacity 0)
                // This ensures content is ready BEFORE splash is removed from hierarchy
                Group {
                    if splashFinished {
                        switch session.state {
                        case .unauthenticated:
                            AuthView()
                        case .onboarding:
                            OnboardingContainerView()
                        case .running, .synchronizing:
                            ContentView()
                        default:
                            // startup, authenticating, restoringIdentity, tearingDown
                            // Kept explicitly black/empty behind splash
                            Color.black.ignoresSafeArea()
                        }
                    } else {
                        // Placeholder during splash - pure black, no content
                        Color.black.ignoresSafeArea()
                    }
                }
                .allowsHitTesting(splashFinished && session.state != .tearingDown)
                .zIndex(1)

                // Splash screen (Overlay)
                // Removed via splashRemoved which is set AFTER main content is rendered
                if !splashRemoved {
                    SplashScreen(isFinished: $splashFinished)
                        .zIndex(100)
                        .allowsHitTesting(false)  // Disable interaction during fade-out
                }

                // Loading / Blocking overlay for sensitive states
                if session.state == .restoringIdentity || session.state == .authenticating {
                    // Optional: Add a spinner here if splash is already gone
                    if splashRemoved {
                        ZStack {
                            Color.black.opacity(0.8).ignoresSafeArea()
                            ProgressView()
                                .tint(AppColors.primary)
                        }
                        .zIndex(99)
                    }
                }
            }
            .preferredColorScheme(.dark)
            // Only animate state changes AFTER splash is fully removed
            .animation(splashRemoved ? .easeInOut(duration: 0.5) : nil, value: session.state)
            // Two-phase transition: first reveal content, then remove splash
            .onChange(of: splashFinished) { _, finished in
                if finished {
                    // Phase 1: Main content is now rendered (splash is at opacity 0, still in hierarchy)
                    // Wait one frame for main content to fully render, then remove splash
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        // Phase 2: Remove splash from hierarchy (main content is already visible)
                        splashRemoved = true
                    }
                }
            }
            .task {
                // Initialize Session Manager Logic
                await session.initialize(modelContext: modelContainer.mainContext)
            }
            .onChange(of: session.state) { _, newState in
                if newState == .synchronizing {
                    // Trigger Data Sync Phase
                    Task {
                        // Only sync if we are strictly in sync phase (and splash is done)
                        // We might want to wait for splash, but SessionManager handles logic.
                        if StorageMode.current == .cloud {
                             // Ensure local state is strictly up to date before syncing
                             await MainActor.run {
                                 DeadlineProcessor.shared.processPendingObligations(modelContext: modelContainer.mainContext)
                             }
                             
                             await SyncService.shared.performFullSync(
                                modelContext: modelContainer.mainContext
                            )
                        }
                        
                        // Signal manager that we are done - pass sync result
                        let syncSuccess = SyncService.shared.lastSyncSucceeded
                        await MainActor.run {
                            session.contentSyncCompleted(success: syncSuccess)
                        }
                    }
                }
                if newState == .running {
                    Task { @MainActor in
                        await NotificationEngine.shared.syncAllNotifications(modelContext: modelContainer.mainContext)
                    }
                }
            }
        }
        .modelContainer(modelContainer)
    }
}
