import SwiftUI

/// Muted preview card for next week's upcoming goals.
/// Low contrast, teaser style - no interaction.
struct NextWeekCard: View {
    
    let upcomingGoals: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Upcoming Goals")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                
                Text("Preparation Phase")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textMuted)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Text("\(upcomingGoals)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
                
                // Subtle progress placeholder
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 48, height: 6)
                    
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 12, height: 6)
                }
            }
        }
        .padding(AppSpacing.lg)
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
        .opacity(0.8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient
        
        NextWeekCard(upcomingGoals: 4)
            .padding(AppSpacing.screenHorizontal)
    }
}
