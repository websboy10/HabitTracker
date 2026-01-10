import SwiftUI

/// Shared small UI components used throughout the app.
enum AppComponents {
    
    // MARK: - Home Indicator Pill
    
    /// The bottom home indicator pill (iOS-style)
    struct HomePill: View {
        var body: some View {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Color.white.opacity(0.2))
                .frame(width: 128, height: 5)
                .padding(.vertical, AppSpacing.sm)
        }
    }
    
    // MARK: - Vertical Separator
    
    /// A gradient vertical separator line
    struct VerticalSeparator: View {
        var height: CGFloat = 40
        
        var body: some View {
            Rectangle()
                .fill(AppMaterials.separatorGradient)
                .frame(width: 1, height: height)
        }
    }
    
    // MARK: - Glow Circle
    
    /// Ambient glow circle for background effects
    struct GlowCircle: View {
        var color: Color = AppColors.primarySubtle
        var size: CGFloat = 256
        
        var body: some View {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .blur(radius: AppMaterials.glowBlur)
        }
    }
    
    // MARK: - Icon Button
    
    /// A circular icon button with optional active state
    struct IconCircle: View {
        let systemName: String
        var isActive: Bool = false
        
        var body: some View {
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: systemName)
                        .font(.system(size: AppTypography.iconSizeSmall, weight: .medium))
                        .foregroundColor(isActive ? AppColors.textPrimary : AppColors.textSecondary)
                )
        }
    }
}

// MARK: - Animation Timing

enum AppAnimation {
    /// Standard easeInOut animation (0.5s) for progress changes
    static let standard = Animation.easeInOut(duration: 0.5)
    
    /// Quick easeInOut animation (0.3s) for tab switches
    static let quick = Animation.easeInOut(duration: 0.3)
    
    /// Slow easeInOut animation (0.7s) for emphasis
    static let slow = Animation.easeInOut(duration: 0.7)
}
