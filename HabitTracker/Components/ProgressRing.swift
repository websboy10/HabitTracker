import SwiftUI

/// A circular progress ring indicator.
/// Displays completion percentage with center text.
struct ProgressRing: View {
    
    /// The completion percentage (0.0 to 1.0)
    let percentage: Double
    
    /// The label text below the percentage
    var label: String = "Today"
    
    @State private var animatedPercentage: Double = 0
    
    /// Ring diameter
    private let ringSize: CGFloat = AppSpacing.progressRingSize
    
    /// Stroke width
    private let strokeWidth: CGFloat = AppSpacing.progressRingStroke
    
    /// The circle radius for SVG-style calculations
    private var radius: CGFloat {
        (ringSize - strokeWidth) / 2
    }
    
    /// The circumference of the progress circle
    private var circumference: CGFloat {
        2 * .pi * radius
    }
    
    /// The stroke offset for the current percentage
    private var strokeOffset: CGFloat {
        circumference * (1 - percentage)
    }
    
    var body: some View {
        ZStack {
            // Ambient glow behind the ring
            AppComponents.GlowCircle(
                color: AppColors.primarySubtle,
                size: ringSize
            )
            
            // Track circle (background)
            Circle()
                .stroke(
                    AppColors.trackBackground,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: ringSize - 32, height: ringSize - 32)
            
                .shadow(color: AppColors.primaryGlow, radius: 6)
                .onAppear {
                    // Reset to 0 initially if needed, but for simple entrance just animate to value
                    // This ensures it animates from 0 if we use a separate state, but for simplicity
                    // we can rely on standard SwiftUI transitions or add a state property.
                }
            
            // Progress circle (animated)
            Circle()
                .trim(from: 0, to: animatedPercentage)
                .stroke(
                    AppColors.primary,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: ringSize - 32, height: ringSize - 32)
                .rotationEffect(.degrees(-90))
                .shadow(color: AppColors.primaryGlow, radius: 6)
                .animation(AppAnimation.slow, value: animatedPercentage)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.0)) {
                        animatedPercentage = percentage
                    }
                }
                .onChange(of: percentage) { _, newValue in
                    withAnimation(.easeOut(duration: 1.0)) {
                        animatedPercentage = newValue
                    }
                }
            
            // Center content
            VStack(spacing: AppSpacing.sm) {
                Text(percentageText)
                    .font(AppTypography.displayLarge)
                    .foregroundColor(AppColors.textPrimary)
                    .shadow(color: .white.opacity(0.3), radius: 20)
                
                Text(label.uppercased())
                    .font(AppTypography.caption)
                    .textCase(.uppercase)
                    .tracking(3)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
    
    /// Formatted percentage string
    private var percentageText: String {
        "\(Int(percentage * 100))%"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient
        
        ProgressRing(percentage: 0.75)
    }
}
