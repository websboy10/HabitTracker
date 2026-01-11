import SwiftUI

/// Represents the available tabs in the app
enum Tab: Int, CaseIterable {
    case home
    case goals
    case stats
    case settings

    /// SF Symbol name for the tab icon
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .goals: return "scope"
        case .stats: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

/// A custom floating tab bar component.
/// iOS 26 native style with liquid glass effect.
struct TabBar: View {
    
    /// Currently selected tab
    @Binding var selectedTab: Tab
    
    @Namespace private var animation
    
    /// Native floating tab bar height
    private let barHeight: CGFloat = 64
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .frame(height: barHeight)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
        .clipShape(Capsule())
    }
    
    /// Creates a tab button for the given tab
    private func tabButton(for tab: Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
            HapticManager.shared.selection()
        } label: {
            ZStack {
                // Active background pill
                if selectedTab == tab {
                    Capsule()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 56, height: 40)
                        .overlay(
                            Capsule()
                                .stroke(AppColors.primary.opacity(0.3), lineWidth: 0.5)
                        )
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 8)
                        .matchedGeometryEffect(id: "activeTab", in: animation)
                }
                
                Image(systemName: tab.iconName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        selectedTab == tab
                            ? AppColors.primary
                            : Color.white.opacity(0.4)
                    )
                    .symbolEffect(.bounce, value: selectedTab == tab)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient
        
        VStack {
            Spacer()
            TabBar(selectedTab: .constant(.home))
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.md)
        }
    }
}
