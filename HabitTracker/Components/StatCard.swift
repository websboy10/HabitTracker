import SwiftUI

/// A glassmorphism stat card with stacked depth effect.
/// Displays TOTAL, DONE, and LEFT statistics.
struct StatCard: View {
    
    /// Total number of habits
    let total: Int
    
    /// Number of completed habits
    let done: Int
    
    /// Number of remaining habits
    let left: Int
    
    /// Card height
    private let cardHeight: CGFloat = AppSpacing.statCardHeight
    
    var body: some View {
        ZStack {
            // Back layer (deepest)
            stackedLayer(scale: 0.85, opacity: 0.4, offsetY: 24)
            
            // Middle layer
            stackedLayer(scale: 0.9, opacity: 0.7, offsetY: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .scaleEffect(0.9)
                        .offset(y: 12)
                )
            
            // Front layer (main content)
            GlassCard(highlight: true) {
                HStack {
                    statItem(value: total, label: "TOTAL", color: AppColors.textPrimary)
                    
                    AppComponents.VerticalSeparator()
                    
                    statItem(value: done, label: "DONE", color: AppColors.primary, hasGlow: true)
                    
                    AppComponents.VerticalSeparator()
                    
                    statItem(value: left, label: "LEFT", color: AppColors.textPrimary.opacity(0.8))
                }
                .frame(height: cardHeight)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: cardHeight + 28) // Account for stacked layers
    }
    
    /// Creates a stacked background layer
    private func stackedLayer(scale: CGFloat, opacity: Double, offsetY: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous)
            .fill(AppColors.glassBackground)
            .frame(height: cardHeight)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: offsetY)
    }
    
    /// Creates a single stat item
    private func statItem(
        value: Int,
        label: String,
        color: Color,
        hasGlow: Bool = false
    ) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text("\(value)")
                .font(AppTypography.displayMedium)
                .foregroundColor(color)
                .shadow(
                    color: hasGlow ? AppColors.primary.opacity(0.5) : .clear,
                    radius: hasGlow ? 10 : 0
                )
            
            Text(label)
                .font(AppTypography.caption)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient
        
        StatCard(total: 8, done: 6, left: 2)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}
