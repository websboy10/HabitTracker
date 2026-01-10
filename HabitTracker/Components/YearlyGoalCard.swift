import SwiftUI

/// A yearly goal progress card showing title, count, and subtle progress bar.
/// Read-only, no interaction.
struct YearlyGoalCard: View {
    
    let goal: Goal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary.opacity(0.9))
                        .tracking(0.3)
                    
                    Text("\(goal.category.rawValue.capitalized) • \(goal.frequencyUnit.capitalized)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                }
                
                Spacer()
                
                // Count
                HStack(spacing: 4) {
                    Text(formattedCount(goal.yearlyCompleted))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary.opacity(0.9))
                    
                    Text("/")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary.opacity(0.2))
                    
                    Text(formattedCount(goal.yearlyTarget))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                    
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(progressGradient)
                        .frame(width: geometry.size.width * goal.yearlyProgress)
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.ultraThinMaterial.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous)
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
        )
        .opacity(goal.status == .active ? 1 : 0.7)
    }
    
    // MARK: - Helpers
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [goal.category.color.opacity(0.4), goal.category.color.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private func formattedCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%,d", count).replacingOccurrences(of: ",", with: ",")
        }
        return "\(count)"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient
        
        VStack(spacing: 16) {
            YearlyGoalCard(
                goal: Goal(title: "Morning Hydration", category: .health, frequency: .daily,
                          yearlyTarget: 365, yearlyCompleted: 214)
            )
            
            YearlyGoalCard(
                goal: Goal(title: "Deep Work", category: .focus, frequency: .daily,
                          yearlyTarget: 1000, yearlyCompleted: 840)
            )
        }
        .padding()
    }
}
