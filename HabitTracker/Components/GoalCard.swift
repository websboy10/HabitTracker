import SwiftUI

/// A single goal card showing title, category, frequency, and status.
/// Has edit affordance but no completion indicators.
struct GoalCard: View {
    
    let goal: Goal
    var onEdit: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // Category and status row - fixed layout to prevent clipping
                HStack(spacing: 6) {
                    categoryBadge

                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 3, height: 3)

                    statusBadge
                }
                .fixedSize(horizontal: true, vertical: false)

                // Title
                Text(goal.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(goal.status == .active ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.8))
                    .tracking(0.3)
                    .lineLimit(1)

                // Frequency
                Text(goal.frequencyText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(goal.status == .active ? AppColors.textSecondary : AppColors.textMuted)
            }

            Spacer(minLength: 8)

            // Edit button
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous))
        .overlay(cardBorder)
        .opacity(goal.status == .active ? 1 : 0.6)
    }
    
    // MARK: - Subviews

    private var categoryBadge: some View {
        Text(goal.category.rawValue.capitalized)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(goal.status == .active ? goal.category.color : AppColors.textSecondary)
            .textCase(.uppercase)
            .tracking(0.8)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(goal.status == .active ? goal.category.color.opacity(0.1) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(goal.status == .active ? goal.category.color.opacity(0.2) : Color.white.opacity(0.1), lineWidth: 1)
            )
    }

    private var statusBadge: some View {
        Text(goal.status.label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(goal.status == .active ? AppColors.textSecondary : AppColors.textMuted)
            .textCase(.uppercase)
            .tracking(0.8)
            .lineLimit(1)
            .fixedSize()
    }
    
    private var cardBackground: some View {
        Group {
            if goal.status == .active {
                AppColors.glassBackground
            } else {
                LinearGradient(
                    colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .background(.ultraThinMaterial.opacity(0.3))
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous)
            .stroke(AppColors.glassBorder, lineWidth: 1)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient
        
        VStack(spacing: 16) {
            GoalCard(
                goal: Goal(title: "Morning Hydration", category: .health, frequency: .daily),
                onEdit: {}
            )
            
            GoalCard(
                goal: Goal(title: "Tech Articles", category: .learning, frequency: .daily, status: .paused),
                onEdit: {}
            )
        }
        .padding()
    }
}
