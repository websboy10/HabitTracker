import SwiftUI
import SwiftData

/// The main Home screen with scrollable dashboard.
/// Uses obligation-based system for tracking.
struct HomeView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()
    @Binding var selectedTab: Tab
    var showsCustomTabBar: Bool = true
    
    // Observe model changes to trigger re-renders when data is deleted/added
    @Query private var obligations: [ObligationModel]
    @Query private var goals: [GoalModel]

    var body: some View {
        let _ = obligations.count + goals.count
        ZStack {
            // Fixed background
            AppMaterials.moodGradient

            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // SECTION 1: Hero / Daily Dashboard
                    heroSection
                        .padding(.bottom, AppSpacing.xl)

                    // SECTION 2: Today's Obligations
                    todayObligationsSection
                        .padding(.bottom, AppSpacing.xl)

                    // SECTION 3: This Week
                    thisWeekSection
                        .padding(.bottom, 120)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.xl)
            }

            // Fixed bottom elements
            if showsCustomTabBar {
                VStack {
                    Spacer()
                    bottomNavigation
                }
            }
        }
        .onAppear {
            viewModel.configure(with: modelContext)
        }
    }

    // MARK: - Section 1: Hero

    private var heroSection: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressRing(
                percentage: viewModel.completionPercentage,
                label: "Today"
            )

            statsBar
        }
    }

    private var statsBar: some View {
        GlassCard {
            HStack {
                statItem(value: viewModel.totalCount, label: "TOTAL", color: AppColors.textPrimary)

                AppComponents.VerticalSeparator(height: 32)

                statItem(value: viewModel.completedCount, label: "DONE", color: AppColors.primary, hasGlow: true)

                AppComponents.VerticalSeparator(height: 32)

                // Show missed if any, otherwise show pending
                if viewModel.missedCount > 0 {
                    statItem(value: viewModel.missedCount, label: "MISSED", color: AppColors.textPrimary.opacity(0.6))
                } else {
                    statItem(value: viewModel.remainingCount, label: "LEFT", color: AppColors.textPrimary.opacity(0.8))
                }
            }
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.sm)
        }
    }

    private func statItem(value: Int, label: String, color: Color, hasGlow: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
                .shadow(
                    color: hasGlow ? AppColors.primary.opacity(0.5) : .clear,
                    radius: hasGlow ? 8 : 0
                )

            Text(label)
                .font(AppTypography.caption)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section 2: Today's Obligations

    private var todayObligationsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("Today's Obligations")

            let obligations = viewModel.fetchTodaysObligations()

            if obligations.isEmpty {
                emptyObligationsState
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                VStack(spacing: AppSpacing.md) {
                    ForEach(Array(obligations.enumerated()), id: \.element.obligation.id) { index, item in
                        ObligationCard(
                            obligation: item.obligation,
                            goal: item.goal,
                            category: item.category
                            ,
                            canToggle: viewModel.canToggleObligation(item.obligation)
                        ) {
                            withAnimation(AppAnimation.standard) {
                                viewModel.completeObligation(item.obligation)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .scale(scale: 0.8))
                        ))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: obligations.map { $0.obligation.id })
            }
        }
    }

    private var emptyObligationsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(AppColors.textMuted)

            Text("No obligations for today")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            Text("Add goals in the Goals tab")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Section 3: This Week

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("This Week")

            WeekOverviewCard(progress: viewModel.weekProgressModel)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, muted: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(muted ? AppColors.textMuted : AppColors.textSecondary)
            .textCase(.uppercase)
            .tracking(2)
            .padding(.leading, 4)
    }

    // MARK: - Bottom Navigation

    private var bottomNavigation: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, AppColors.backgroundDark.opacity(0.8), AppColors.backgroundDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)

            TabBar(selectedTab: $selectedTab)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.md)
                .background(AppColors.backgroundDark)
        }
    }
}

// MARK: - Obligation Card

struct ObligationCard: View {

    let obligation: ObligationModel
    let goal: GoalModel
    let category: CategoryModel?
    let canToggle: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            if canToggle {
                onTap()
            }
        }) {
            HStack(spacing: AppSpacing.md) {
                completionIndicator

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(AppTypography.body)
                        .fontWeight(.medium)
                        .foregroundColor(statusTextColor)
                        .strikethrough(obligation.isCompleted, color: AppColors.textPrimary.opacity(0.3))
                        .tracking(0.3)

                    HStack(spacing: 6) {
                        if let category = category {
                            Text(category.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(category.color.opacity(0.8))
                        }

                        Text(statusLabel)
                            .font(AppTypography.caption)
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundColor(statusLabelColor)
                            .fontWeight(.semibold)
                    }

                    Text(scheduledLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                if obligation.isPending {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AppColors.trackBackground)
                        .frame(width: 4, height: 32)
                }
            }
            .padding(AppSpacing.md)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius, style: .continuous))
            .overlay(cardBorder)
            .shadow(color: shadowColor, radius: shadowRadius, y: 4)
        }
        .buttonStyle(ObligationButtonStyle())
        .disabled(!canToggle)
    }

    private var statusLabel: String {
        if obligation.isCompleted { return "Completed" }
        if obligation.isMissed { return "Missed" }
        return "Pending"
    }

    private var scheduledLabel: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: obligation.scheduledAt)
        let hasTime = (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = hasTime ? .short : .none
        let base = dateFormatter.string(from: obligation.scheduledAt)

        if hasTime {
            return base
        }
        return "\(base) • Any time"
    }

    private var statusTextColor: Color {
        if obligation.isMissed { return AppColors.textPrimary.opacity(0.5) }
        return AppColors.textPrimary
    }

    private var statusLabelColor: Color {
        if obligation.isCompleted { return AppColors.primary.opacity(0.7) }
        if obligation.isMissed { return AppColors.textMuted }
        return AppColors.textMuted
    }

    private var shadowColor: Color {
        if obligation.isCompleted { return AppColors.primary.opacity(0.15) }
        return .black.opacity(0.2)
    }

    private var shadowRadius: CGFloat {
        obligation.isCompleted ? 15 : 8
    }

    private var completionIndicator: some View {
        Circle()
            .fill(indicatorFill)
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .stroke(indicatorStroke, lineWidth: 1)
            )
            .overlay(indicatorContent)
            .shadow(color: obligation.isCompleted ? AppColors.primary.opacity(0.3) : .clear, radius: 15)
    }

    private var indicatorFill: Color {
        if obligation.isCompleted { return AppColors.primary.opacity(0.2) }
        if obligation.isMissed { return Color.white.opacity(0.02) }
        return Color.white.opacity(0.05)
    }

    private var indicatorStroke: Color {
        if obligation.isCompleted { return AppColors.primary.opacity(0.4) }
        if obligation.isMissed { return Color.white.opacity(0.05) }
        return Color.white.opacity(0.1)
    }

    @ViewBuilder
    private var indicatorContent: some View {
        if obligation.isCompleted {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.primary)
        } else if obligation.isMissed {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textMuted)
        } else {
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 8, height: 8)
        }
    }

    private var cardBackground: some View {
        Group {
            if obligation.isCompleted {
                LinearGradient(
                    colors: [AppColors.primary.opacity(0.2), AppColors.primary.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else if obligation.isMissed {
                Color.white.opacity(0.02)
            } else {
                AppColors.glassBackground
            }
        }
        .background(.ultraThinMaterial.opacity(obligation.isMissed ? 0.1 : 0.3))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius, style: .continuous)
            .stroke(
                obligation.isCompleted
                    ? AppColors.primary.opacity(0.3)
                    : (obligation.isMissed ? Color.white.opacity(0.05) : AppColors.glassBorder),
                lineWidth: 1
            )
    }
}

private struct ObligationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    HomeView(selectedTab: .constant(.home))
}
