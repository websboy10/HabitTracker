import SwiftUI
import SwiftData

/// Main app entry point with SwiftData container.
@main
struct HabitTrackerApp: App {

    /// SwiftData model container
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                GoalModel.self,
                CategoryModel.self,
                CompletionModel.self,
                TaskModel.self
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
    
    /// Controls splash screen visibility - set to true when animation finishes
    @State private var splashFinished = false
    
    /// Check if user is authenticated
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    
    /// Check if user has completed onboarding
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var rootPhase: RootPhase = .auth

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Background layer to ensure smooth cross-dissolves
                Color.black.ignoresSafeArea()
                
                // Main content with independent Z-layers for cross-dissolve
                Group {
                    if rootPhase == .auth {
                        AuthView()
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                            .zIndex(0)
                    }
                    
                    if rootPhase == .onboarding {
                        OnboardingContainerView()
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                            .zIndex(1)
                    }
                    
                    if rootPhase == .main {
                        ContentView()
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                            .zIndex(2)
                    }
                }
                // Content is always visible - splash fades out on top to reveal it
                .allowsHitTesting(splashFinished) // Prevent interaction until splash done

                // Splash screen (fades out when finished)
                if !splashFinished {
                    SplashScreen(isFinished: $splashFinished)
                        .transition(.opacity)
                        .zIndex(100)
                        .allowsHitTesting(false) // Splash is non-interactive
                }
            }
            .preferredColorScheme(.dark)
            // NOTE: No animation on splashFinished - splash controls its own exit fade
            // The view swap happens after splash is already invisible
            .animation(.easeInOut(duration: 0.5), value: rootPhase)
            .onAppear {
                rootPhase = computeRootPhase()
            }
            .onChange(of: isAuthenticated) { _, _ in
                Task { @MainActor in
                    updateRootPhase()
                }
            }
            .onChange(of: hasCompletedOnboarding) { _, _ in
                Task { @MainActor in
                    updateRootPhase()
                }
            }
            .task {
                // Wait for splash transition to fully complete before heavy sync
                // This prevents sync work from competing with the crossfade animation
                while !splashFinished {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms poll
                }
                // Extra buffer after transition
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                
                if SupabaseService.shared.isAuthenticated && StorageMode.current == .cloud {
                    await SyncService.shared.performFullSync(
                        modelContext: modelContainer.mainContext
                    )
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
    
    private enum RootPhase {
        case auth
        case onboarding
        case main
    }
    
    private func computeRootPhase() -> RootPhase {
        if !isAuthenticated {
            return .auth
        }
        if !hasCompletedOnboarding {
            return .onboarding
        }
        return .main
    }
    
    private func updateRootPhase() {
        let next = computeRootPhase()
        guard next != rootPhase else { return }
        rootPhase = next
    }
}
