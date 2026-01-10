import SwiftUI

/// Centralized color definitions for the Habit Tracker app.
/// Supports dynamic theming based on user selection.
enum AppColors {

    // MARK: - Theme State

    /// Current active theme (uses ThemeManager for reactive updates)
    @MainActor
    private static var currentTheme: AppTheme {
        ThemeManager.shared.currentTheme
    }

    // MARK: - Primary Accent (Dynamic)

    /// Primary accent color - adapts to current theme
    @MainActor static var primary: Color {
        currentTheme.primaryColor
    }

    /// Primary with glow opacity for shadows
    @MainActor static var primaryGlow: Color {
        currentTheme.primaryColor.opacity(0.6)
    }

    /// Primary with subtle opacity for backgrounds
    @MainActor static var primarySubtle: Color {
        currentTheme.primaryColor.opacity(0.2)
    }

    // MARK: - Background Colors (Dynamic)

    /// Deepest background layer
    @MainActor static var backgroundDark: Color {
        currentTheme.backgroundDark
    }

    /// Secondary dark background
    @MainActor static var backgroundLight: Color {
        currentTheme.backgroundLight
    }

    // MARK: - Gradient Colors (Dynamic)

    /// Gradient start color
    @MainActor static var gradientStart: Color {
        currentTheme.gradientStart
    }

    /// Gradient midpoint color
    @MainActor static var gradientMid: Color {
        currentTheme.gradientMid
    }

    /// Gradient end color
    @MainActor static var gradientEnd: Color {
        currentTheme.gradientEnd
    }

    // MARK: - Mood Background Glow Colors (Dynamic)

    /// Primary glow for mood background
    @MainActor static var moodGlowDark: Color {
        currentTheme.moodGlowDark
    }

    /// Secondary glow for mood background
    @MainActor static var moodGlowCrimson: Color {
        currentTheme.moodGlowMid
    }

    /// Deep glow for mood background
    @MainActor static var moodGlowDeep: Color {
        currentTheme.moodGlowDeep
    }
    
    // MARK: - Text Colors (Static)
    
    /// Primary text color (white)
    static let textPrimary = Color.white
    
    /// Secondary text color (theme-tuned)
    @MainActor static var textSecondary: Color {
        isCoolDarkTheme ? Color.white.opacity(0.6) : Color.white.opacity(0.4)
    }

    /// Muted text color (theme-tuned)
    @MainActor static var textMuted: Color {
        isCoolDarkTheme ? Color.white.opacity(0.5) : Color.white.opacity(0.3)
    }

    /// True when using the navy theme
    @MainActor static var isNavy: Bool {
        currentTheme == .blue
    }

    /// True when using a cool dark theme (navy, forest, graphite, teal) - requires enhanced glass visibility
    @MainActor static var isCoolDarkTheme: Bool {
        currentTheme == .blue || currentTheme == .forest || currentTheme == .graphite || currentTheme == .teal
    }

    /// Selected segment text color
    @MainActor static var segmentSelectedText: Color {
        isCoolDarkTheme ? Color.white : currentTheme.primaryColor
    }

    /// Selected segment background
    @MainActor static var segmentSelectedBackground: Color {
        isCoolDarkTheme ? Color.white.opacity(0.12) : currentTheme.primaryColor.opacity(0.15)
    }

    /// Selected segment border
    @MainActor static var segmentSelectedBorder: Color {
        isCoolDarkTheme ? Color.white.opacity(0.3) : currentTheme.primaryColor.opacity(0.3)
    }

    /// Selected segment indicator
    @MainActor static var segmentSelectedIndicator: Color {
        isCoolDarkTheme ? Color.white.opacity(0.9) : currentTheme.primaryColor
    }

    /// Toggle track for on state
    @MainActor static var toggleOnBackground: Color {
        isCoolDarkTheme ? Color.white.opacity(0.2) : currentTheme.primaryColor.opacity(0.2)
    }

    /// Toggle track border for on state
    @MainActor static var toggleOnBorder: Color {
        isCoolDarkTheme ? Color.white.opacity(0.4) : currentTheme.primaryColor.opacity(0.3)
    }

    /// Toggle knob color for on state
    @MainActor static var toggleOnKnob: Color {
        isCoolDarkTheme ? Color.white : currentTheme.primaryColor
    }

    /// Toggle knob color for off state
    @MainActor static var toggleOffKnob: Color {
        isCoolDarkTheme ? Color.white.opacity(0.6) : Color.white.opacity(0.4)
    }

    /// Toggle track background for off state
    @MainActor static var toggleOffBackground: Color {
        isCoolDarkTheme ? Color.white.opacity(0.12) : Color.white.opacity(0.1)
    }
    
    // MARK: - Glass Colors (Static)

    /// Glass card background (theme-tuned)
    @MainActor static var glassBackground: Color {
        isCoolDarkTheme ? Color.white.opacity(0.07) : Color.white.opacity(0.03)
    }

    /// Glass highlight gradient start (theme-tuned)
    @MainActor static var glassHighlightStart: Color {
        isCoolDarkTheme ? Color.white.opacity(0.18) : Color.white.opacity(0.1)
    }

    /// Glass highlight gradient end (theme-tuned)
    @MainActor static var glassHighlightEnd: Color {
        isCoolDarkTheme ? Color.white.opacity(0.06) : Color.white.opacity(0.02)
    }

    /// Glass border color (theme-tuned)
    @MainActor static var glassBorder: Color {
        isCoolDarkTheme ? Color.white.opacity(0.12) : Color.white.opacity(0.05)
    }

    /// Glass border top highlight (theme-tuned)
    @MainActor static var glassBorderTop: Color {
        isCoolDarkTheme ? Color.white.opacity(0.22) : Color.white.opacity(0.15)
    }

    /// Glass border bottom (theme-tuned)
    @MainActor static var glassBorderBottom: Color {
        isCoolDarkTheme ? Color.white.opacity(0.06) : Color.white.opacity(0.02)
    }

    // MARK: - Track & Separator Colors (Static)

    /// Progress track background (theme-tuned)
    @MainActor static var trackBackground: Color {
        isCoolDarkTheme ? Color.white.opacity(0.12) : Color.white.opacity(0.05)
    }

    /// Separator color for vertical dividers (theme-tuned)
    @MainActor static var separator: Color {
        isCoolDarkTheme ? Color.white.opacity(0.18) : Color.white.opacity(0.1)
    }
}

// MARK: - Color Extension for Hex Values

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }

    /// Returns a color with adjusted saturation (multiplier: 1.0 = unchanged, >1.0 = more saturated)
    func saturated(by multiplier: Double) -> Color {
        // Convert to UIColor to access HSB components
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let newSaturation = min(1.0, saturation * CGFloat(multiplier))
        return Color(hue: Double(hue), saturation: Double(newSaturation), brightness: Double(brightness), opacity: Double(alpha))
    }

    /// Returns a brightened version of the color
    func brightened(by amount: Double) -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let newBrightness = min(1.0, brightness + CGFloat(amount))
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(newBrightness), opacity: Double(alpha))
    }
}
