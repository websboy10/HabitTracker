import SwiftUI

/// Centralized typography definitions for the Habit Tracker app.
/// Uses SF system fonts as native equivalents to Plus Jakarta Sans.
enum AppTypography {
    
    // MARK: - Display Fonts
    
    /// Large numeric display (e.g., "75%" in progress ring)
    /// CSS: text-5xl font-bold (48px)
    static let displayLarge = Font.system(size: 48, weight: .bold, design: .rounded)
    
    /// Medium numeric display (e.g., stat numbers)
    /// CSS: text-2xl font-bold (24px)
    static let displayMedium = Font.system(size: 24, weight: .bold, design: .rounded)
    
    // MARK: - Body Fonts
    
    /// Standard body text
    /// CSS: text-sm font-medium (14px)
    static let body = Font.system(size: 14, weight: .medium)

    /// Large body text for primary actions
    /// CSS: text-base font-medium (16px)
    static let bodyLarge = Font.system(size: 16, weight: .medium)
    
    /// Small body text
    /// CSS: text-xs (12px)
    static let bodySmall = Font.system(size: 12, weight: .regular)
    
    // MARK: - Caption Fonts
    
    /// Uppercase caption labels (e.g., "TODAY", "TOTAL")
    /// CSS: text-[10px] uppercase tracking-wider
    static let caption = Font.system(size: 10, weight: .medium)
    
    /// Micro text for subtle labels
    /// CSS: text-[10px]
    static let micro = Font.system(size: 10, weight: .regular)
    
    // MARK: - Icon Sizing
    
    /// Standard icon size for tab bar
    static let iconSize: CGFloat = 24
    
    /// Small icon size
    static let iconSizeSmall: CGFloat = 14
}

// MARK: - View Modifiers for Typography

extension View {
    /// Applies caption styling with uppercase and tracking
    func captionStyle() -> some View {
        self
            .font(AppTypography.caption)
            .textCase(.uppercase)
            .tracking(1.5)
    }
    
    /// Applies muted caption styling
    func mutedCaptionStyle() -> some View {
        self
            .font(AppTypography.micro)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundColor(AppColors.textMuted)
    }
}
