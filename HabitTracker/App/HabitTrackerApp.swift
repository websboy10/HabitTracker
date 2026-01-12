import SwiftUI
import SwiftData

/// Main app entry point with SwiftData container.
@main
struct HabitTrackerApp: App {

    /// Central Session Manager
    @StateObject private var session = AppSessionManager.shared

    /// SwiftData model container
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                GoalModel.self,
                CategoryModel.self,
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
            
            // Seed default categories on first launch
            seedDefaultCategoriesIfNeeded()
            
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    /// Controls splash screen visibility
    @State private var splashFinished = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Background layer
                Color.black.ignoresSafeArea()
                
                // Main State Switcher
                Group {
                    switch session.state {
                    case .unauthenticated:
                        AuthView()
                            .transition(.opacity)
                    case .onboarding:
                        OnboardingContainerView()
                            .transition(.opacity)
                    case .running, .synchronizing:
                        ContentView()
                            .transition(.opacity)
                    default:
                        // startup, authenticating, restoringIdentity, tearingDown
                        // Kept explicitly black/empty behind splash
                        Color.black.ignoresSafeArea()
                    }
                }
                .allowsHitTesting(splashFinished && session.state != .tearingDown)
                .zIndex(1)

                // Splash screen (Overlay)
                if !splashFinished {
                    SplashScreen(isFinished: $splashFinished)
                        .transition(.opacity)
                        .zIndex(100)
                }
                
                // Loading / Blocking overlay for sensitive states
                if session.state == .restoringIdentity || session.state == .authenticating {
                    // Optional: Add a spinner here if splash is already gone
                    if splashFinished {
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
            .animation(.easeInOut(duration: 0.5), value: session.state)
            .task {
                // Initialize Session Manager Logic
                await session.initialize()
            }
            .onChange(of: session.state) { newState in
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
                        
                        // Signal manager that we are done
                        await MainActor.run {
                            session.contentSyncCompleted()
                        }
                    }
                }
            }
        }
        .modelContainer(modelContainer)
    }
    
    /// Seeds default categories if none exist
    private func seedDefaultCategoriesIfNeeded() {
        let context = modelContainer.mainContext
        
        // Check if categories already exist
        let descriptor = FetchDescriptor<CategoryModel>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        
        guard existingCount == 0 else { return }
        
        // Insert default categories
        for (index, category) in CategoryModel.defaults.enumerated() {
            let model = CategoryModel(
                name: category.name,
                colorHex: category.colorHex,
                isDefault: true,
                sortOrder: index
            )
            context.insert(model)
        }
        
        try? context.save()
    }
}
