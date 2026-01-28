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
                WeeklyNoteModel.self,
                SnapshotModel.self
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
    
    /// Prevents duplicate post-unlock syncs within the same running session
    @State private var didRunPostUnlockTasks = false

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
                        switch session.entryState {
                        case .loading:
                            ProgressView()
                                .tint(AppColors.primary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.ignoresSafeArea())
                        case .unauthenticated:
                            AuthView()
                        case .onboarding:
                            OnboardingContainerView()
                        case .ready:
                            ContentView()
                        }
                    } else {
                        // Placeholder during splash - pure black, no content
                        Color.black.ignoresSafeArea()
                    }
                }
                .allowsHitTesting(splashFinished && contentReady && session.isUserInteractive)
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
            // Two-phase transition: first reveal content, then remove splash
            .onChange(of: splashFinished) { _, finished in
                if finished {
                    attemptSplashRemoval()
                }
            }
            .onChange(of: session.state) { _, _ in
                attemptSplashRemoval()
            }
            .onChange(of: session.entryState) { _, _ in
                attemptSplashRemoval()
            }
            .task {
                // Provide model container to AppDelegate for foreground notification refresh
                appDelegate.modelContainer = modelContainer
                // Initialize Session Manager Logic
                await session.initialize(modelContext: modelContainer.mainContext)
            }
            .onChange(of: session.state) { _, newState in
                if newState != .running {
                    didRunPostUnlockTasks = false
                }
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
                    runPostUnlockTasksIfNeeded()
                }
            }
            .onChange(of: session.securityLock) { _, locked in
                if locked {
                    return
                }
                runPostUnlockTasksIfNeeded()
            }
        }
        .modelContainer(modelContainer)
    }
    
    private var contentReady: Bool {
        session.entryState != .loading
    }
    
    private func attemptSplashRemoval() {
        guard splashFinished, contentReady, !splashRemoved else { return }
        DispatchQueue.main.async {
            splashRemoved = true
        }
    }
    
    private func runPostUnlockTasksIfNeeded() {
        guard session.state == .running else { return }
        guard !session.securityLock else { return }
        guard !didRunPostUnlockTasks else { return }
        didRunPostUnlockTasks = true
        
        Task { @MainActor in
            // Ensure snapshots are generated for past months
            await SnapshotService.shared.ensureSnapshotsGenerated(in: modelContainer.mainContext)
            
            await NotificationEngine.shared.syncAllNotifications(modelContext: modelContainer.mainContext)
        }
    }
}
