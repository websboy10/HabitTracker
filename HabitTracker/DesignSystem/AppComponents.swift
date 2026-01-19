import SwiftUI

/// Shared small UI components used throughout the app.
enum AppComponents {
    

    
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
