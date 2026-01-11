import SwiftUI

/// Compact weekly progress overview card.
/// Shows progress bar for each day and numeric summary.
struct WeekOverviewCard: View {
    
    let progress: WeekProgress
    
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        GlassCard(highlight: true) {
            ZStack {
                // Ambient glow
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 128, height: 128)
                    .blur(radius: 40)
                    .offset(x: 80, y: -40)
                
                VStack(spacing: AppSpacing.md) {
                    // Header with summary
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(progress.completed)")
                                    .font(AppTypography.displayMedium)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("/ \(progress.total)")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(AppColors.textMuted)
                            }
                            
                            Text("Tasks Completed")
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Mini progress ring
                        miniProgressRing
                    }
                    
                    // Day progress bars
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(dayFill(for: index))
                                .frame(height: 6)
                                .shadow(
                                    color: progress.dayProgress[safe: index] == true
                                        ? AppColors.primary.opacity(0.4)
                                        : .clear,
                                    radius: 8
                                )
                        }
                    }
                    
                    // Day labels
                    HStack(spacing: 4) {
                        ForEach(days, id: \.self) { day in
                            Text(day)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(AppColors.textPrimary.opacity(0.2))
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(AppSpacing.lg)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var miniProgressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: progress.percentage)
                .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: AppColors.primary.opacity(0.8), radius: 4)
        }
        .frame(width: 40, height: 40)
    }
    
    private func dayFill(for index: Int) -> some ShapeStyle {
        if progress.dayProgress[safe: index] == true {
            return AnyShapeStyle(AppColors.primary)
        } else if index < progress.dayProgress.filter({ $0 }).count + 2 {
            return AnyShapeStyle(Color.white.opacity(0.1))
        } else {
            return AnyShapeStyle(Color.white.opacity(0.05))
        }
    }
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient
        
        WeekOverviewCard(
            progress: WeekProgress(
                completed: 3,
                total: 5,
                dayProgress: [true, true, true, false, false, false, false]
            )
        )
        .padding(AppSpacing.screenHorizontal)
    }
}
