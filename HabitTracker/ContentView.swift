import SwiftUI

/// The main content view that handles tab navigation.
/// Implements deterministic navigation with state reset on tab switches.
struct ContentView: View {

    /// Currently selected tab
    @State private var selectedTab: Tab = .home

    /// Previous tab for logging and state management
    @State private var previousTab: Tab? = nil

    /// View identity keys to force view recreation on tab switch
    /// This ensures all transient state is reset when switching tabs
    @State private var viewIdentityKeys: [Tab: UUID] = [
        .home: UUID(),
        .goals: UUID(),
        .stats: UUID(),
        .settings: UUID()
    ]

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                TabView(selection: $selectedTab) {
                    HomeView(selectedTab: $selectedTab, showsCustomTabBar: false)
                        .id(viewIdentityKeys[.home])
                        .tag(Tab.home)
                        .tabItem {
                            Label("Home", systemImage: Tab.home.iconName)
                        }

                    GoalsView(selectedTab: $selectedTab, showsCustomTabBar: false)
                        .id(viewIdentityKeys[.goals])
                        .tag(Tab.goals)
                        .tabItem {
                            Label("Goals", systemImage: Tab.goals.iconName)
                        }

                    StatsView(selectedTab: $selectedTab, showsCustomTabBar: false)
                        .id(viewIdentityKeys[.stats])
                        .tag(Tab.stats)
                        .tabItem {
                            Label("Stats", systemImage: Tab.stats.iconName)
                        }

                    SettingsView(selectedTab: $selectedTab, showsCustomTabBar: false)
                        .id(viewIdentityKeys[.settings])
                        .tag(Tab.settings)
                        .tabItem {
                            Label("Settings", systemImage: Tab.settings.iconName)
                        }
                }
                .tint(AppColors.primary)
            } else {
                ZStack {
                    // Show the appropriate view based on selected tab
                    // Using .id() to force view recreation on tab switch
                    switch selectedTab {
                    case .home:
                        HomeView(selectedTab: $selectedTab)
                            .id(viewIdentityKeys[.home])
                    case .goals:
                        GoalsView(selectedTab: $selectedTab)
                            .id(viewIdentityKeys[.goals])
                    case .stats:
                        StatsView(selectedTab: $selectedTab)
                            .id(viewIdentityKeys[.stats])
                    case .settings:
                        SettingsView(selectedTab: $selectedTab)
                            .id(viewIdentityKeys[.settings])
                    }
                }
            }
        }
        .animation(AppAnimation.quick, value: selectedTab)
        .onChange(of: selectedTab) { oldValue, newValue in
            handleTabChange(from: oldValue, to: newValue)
        }
        .onAppear {
            NavigationLogger.shared.logViewAppear("ContentView")
        }
    }

    /// Handle tab change: log transition and reset previous tab's view state
    private func handleTabChange(from oldTab: Tab, to newTab: Tab) {
        // Log the navigation event
        NavigationLogger.shared.logTabChange(from: oldTab, to: newTab)

        // Reset the previous tab's view identity to force recreation next time
        // This ensures all @State variables are reset when returning to a tab
        viewIdentityKeys[oldTab] = UUID()

        // Store previous tab for reference
        previousTab = oldTab
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(PreviewModelContainer.container)
}
