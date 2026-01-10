import SwiftUI

/// Centralized material and effect definitions for the Habit Tracker app.
/// Provides reusable glass effects, gradients, and shadows.
enum AppMaterials {
    
    // MARK: - Blur Radii
    
    /// Standard glass blur (20pt)
    static let glassBlur: CGFloat = 20
    
    /// Highlight glass blur (24pt)
    static let glassBlurHighlight: CGFloat = 24
    
    /// Ambient glow blur (80pt)
    static let glowBlur: CGFloat = 80
    
    /// Red glow blur for progress ring
    static let redGlowBlur: CGFloat = 40
    
    // MARK: - Gradients
    
    /// Background mood gradient - dynamically adapts to current theme
    @MainActor static var moodGradient: some View {
        ZStack {
            // Base gradient - uses theme colors
            LinearGradient(
                colors: [AppColors.gradientEnd, Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Radial glows - dynamic based on theme
            RadialGradient(
                colors: [AppColors.moodGlowDark, .clear],
                center: UnitPoint(x: 0.1, y: 0.2),
                startRadius: 0,
                endRadius: 300
            )
            
            RadialGradient(
                colors: [AppColors.moodGlowCrimson, .clear],
                center: UnitPoint(x: 0.9, y: 0.6),
                startRadius: 0,
                endRadius: 350
            )
            
            RadialGradient(
                colors: [AppColors.moodGlowDeep, .clear],
                center: UnitPoint(x: 0.5, y: 0.9),
                startRadius: 0,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }
    
    /// Glass card gradient (standard)
    @MainActor static var glassGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassHighlightStart, AppColors.glassHighlightEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Progress bar gradient
    @MainActor static var progressGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.2), AppColors.primary.opacity(0.6)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    /// Separator gradient (vertical fade)
    @MainActor static var separatorGradient: LinearGradient {
        LinearGradient(
            colors: [.clear, AppColors.separator, .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    let isHighlight: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if isHighlight {
                        AppMaterials.glassGradient
                    } else {
                        AppColors.glassBackground
                    }
                }
            )
            .background(.ultraThinMaterial.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous)
                    .stroke(
                        isHighlight
                            ? LinearGradient(
                                colors: [
                                    AppColors.glassBorderTop,
                                    AppColors.glassBorder,
                                    AppColors.glassBorderBottom
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [AppColors.glassBorder, AppColors.glassBorder],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(isHighlight ? 0.2 : 0.37), radius: isHighlight ? 12 : 16, y: isHighlight ? 4 : 8)
    }
}

extension View {
    /// Applies glass card styling
    func glassCard(highlight: Bool = false) -> some View {
        modifier(GlassCardModifier(isHighlight: highlight))
    }
}

// MARK: - Red Glow Modifier

struct RedGlowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: AppColors.primary.opacity(0.2), radius: AppMaterials.redGlowBlur)
    }
}

extension View {
    /// Applies red glow shadow effect
    func redGlow() -> some View {
        modifier(RedGlowModifier())
    }
}
