import SwiftUI

/// Monthly progress summary card.
/// Shows overall progress with ring and days remaining.
struct MonthCard: View {
    
    let progress: MonthProgress
    
    var body: some View {
        GlassCard {
            HStack(spacing: AppSpacing.lg) {
                // Progress ring with month label
                monthRing
                
                // Progress details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(Int(progress.percentage * 100))%")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Overall")
                            .font(AppTypography.caption)
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Text("\(progress.daysRemaining) days remaining")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            .padding(AppSpacing.lg)
            .overlay(
                // Subtle gradient accent
                LinearGradient(
                    colors: [.clear, AppColors.primary.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous))
                .allowsHitTesting(false)
            )
        }
    }
    
    // MARK: - Subviews
    
    private var monthRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 8)
            
            // Progress
            Circle()
                .trim(from: 0, to: progress.percentage)
                .stroke(
                    AppColors.primary.opacity(0.6),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // Month label
            Text(progress.monthAbbreviation)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColors.textPrimary.opacity(0.8))
        }
        .frame(width: 80, height: 80)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient
        
        MonthCard(
            progress: MonthProgress(
                percentage: 0.42,
                daysRemaining: 18,
                monthAbbreviation: "Jan"
            )
        )
        .padding(AppSpacing.screenHorizontal)
    }
}
