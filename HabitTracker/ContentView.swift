import SwiftUI

/// The main content view that handles tab navigation.
struct ContentView: View {

    /// Currently selected tab
    @State private var selectedTab: Tab = .home

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                TabView(selection: $selectedTab) {
                    HomeView(selectedTab: $selectedTab, showsCustomTabBar: false)
                        .tag(Tab.home)
                        .tabItem {
                            Label("Home", systemImage: Tab.home.iconName)
                        }

                    GoalsView(selectedTab: $selectedTab, showsCustomTabBar: false)
                        .tag(Tab.goals)
                        .tabItem {
                            Label("Goals", systemImage: Tab.goals.iconName)
                        }

                    StatsView(selectedTab: $selectedTab, showsCustomTabBar: false)
                        .tag(Tab.stats)
                        .tabItem {
                            Label("Stats", systemImage: Tab.stats.iconName)
                        }

                    SettingsView(selectedTab: $selectedTab, showsCustomTabBar: false)
                        .tag(Tab.settings)
                        .tabItem {
                            Label("Settings", systemImage: Tab.settings.iconName)
                        }
                }
                .tint(AppColors.primary)
            } else {
                ZStack {
                    // Show the appropriate view based on selected tab
                    switch selectedTab {
                    case .home:
                        HomeView(selectedTab: $selectedTab)
                    case .goals:
                        GoalsView(selectedTab: $selectedTab)
                    case .stats:
                        StatsView(selectedTab: $selectedTab)
                    case .settings:
                        SettingsView(selectedTab: $selectedTab)
                    }
                }
            }
        }
        .animation(AppAnimation.quick, value: selectedTab)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
