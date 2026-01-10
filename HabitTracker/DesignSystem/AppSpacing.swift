import SwiftUI

/// Centralized spacing definitions for the Habit Tracker app.
/// Values derived from Tailwind spacing scale.
enum AppSpacing {
    
    // MARK: - Core Spacing Scale
    
    /// Extra small spacing (4pt) - Tailwind: 1
    static let xs: CGFloat = 4
    
    /// Small spacing (8pt) - Tailwind: 2
    static let sm: CGFloat = 8
    
    /// Medium spacing (16pt) - Tailwind: 4
    static let md: CGFloat = 16
    
    /// Large spacing (24pt) - Tailwind: 6
    static let lg: CGFloat = 24
    
    /// Extra large spacing (32pt) - Tailwind: 8
    static let xl: CGFloat = 32
    
    /// Extra extra large spacing (48pt) - Tailwind: 12
    static let xxl: CGFloat = 48
    
    // MARK: - Component-Specific Spacing
    
    /// Screen horizontal padding
    static let screenHorizontal: CGFloat = 24
    
    /// Screen top padding
    static let screenTop: CGFloat = 48
    
    /// Screen bottom padding
    static let screenBottom: CGFloat = 24
    
    /// Card internal padding
    static let cardPadding: CGFloat = 16
    
    /// Tab bar height
    static let tabBarHeight: CGFloat = 80
    
    /// Progress ring size
    static let progressRingSize: CGFloat = 224
    
    /// Progress ring stroke width
    static let progressRingStroke: CGFloat = 8
    
    /// Stat card height
    static let statCardHeight: CGFloat = 96
    
    // MARK: - Corner Radii
    
    /// Default corner radius (16pt) - Tailwind: rounded
    static let cornerRadius: CGFloat = 16
    
    /// Large corner radius (24pt) - Tailwind: rounded-xl
    static let cornerRadiusLarge: CGFloat = 24
    
    /// Extra large corner radius (32pt) - Tailwind: rounded-2xl
    static let cornerRadiusXL: CGFloat = 32
    
    /// Pill/capsule corner radius (40pt)
    static let cornerRadiusPill: CGFloat = 40
}
