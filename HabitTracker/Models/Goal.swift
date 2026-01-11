import Foundation
import SwiftUI

/// Represents a goal's frequency type
enum GoalFrequency: String, CaseIterable {
    case daily
    case weekly
    case monthly
    
    var label: String {
        switch self {
        case .daily: return "day"
        case .weekly: return "week"
        case .monthly: return "month"
        }
    }
}

/// Represents a goal's status
enum GoalStatus: String {
    case active
    case paused
    
    var label: String {
        rawValue.capitalized
    }
}

/// Represents a goal category with associated color
enum GoalCategory: String, CaseIterable {
    case health
    case focus
    case learning
    case fitness
    case personal
    case finance
    case household
    case family
    case social
    case home
    
    var color: Color {
        switch self {
        case .health: return Color(red: 0.8, green: 0.2, blue: 0.2) // Red (primary fallback)
        case .focus: return Color(red: 0.4, green: 0.4, blue: 1.0) // Indigo
        case .learning: return Color.white.opacity(0.5)
        case .fitness: return Color(red: 0.2, green: 0.8, blue: 0.5) // Emerald
        case .personal: return Color(red: 1.0, green: 0.7, blue: 0.2) // Amber
        case .finance: return Color(red: 0.4, green: 0.4, blue: 1.0) // Indigo
        case .household: return Color(red: 1.0, green: 0.7, blue: 0.2) // Amber
        case .family: return Color(red: 1.0, green: 0.4, blue: 0.5) // Rose
        case .social: return Color.white.opacity(0.5)
        case .home: return Color(red: 0.2, green: 0.8, blue: 0.5) // Emerald
        }
    }
}

/// Represents a single goal definition
struct Goal: Identifiable {
    let id: UUID
    var title: String
    var category: GoalCategory
    var frequency: GoalFrequency
    var frequencyCount: Int
    var frequencyUnit: String // "times", "hours", "km", etc.
    var status: GoalStatus
    
    // Yearly tracking
    var yearlyTarget: Int
    var yearlyCompleted: Int
    
    init(
        id: UUID = UUID(),
        title: String,
        category: GoalCategory,
        frequency: GoalFrequency,
        frequencyCount: Int = 1,
        frequencyUnit: String = "time",
        status: GoalStatus = .active,
        yearlyTarget: Int = 365,
        yearlyCompleted: Int = 0
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.frequency = frequency
        self.frequencyCount = frequencyCount
        self.frequencyUnit = frequencyUnit
        self.status = status
        self.yearlyTarget = yearlyTarget
        self.yearlyCompleted = yearlyCompleted
    }
    
    /// Formatted frequency string (e.g., "1 time / day")
    var frequencyText: String {
        let unit = frequencyCount == 1 ? frequencyUnit : "\(frequencyUnit)s"
        return "\(frequencyCount) \(unit) / \(frequency.label)"
    }
    
    /// Yearly progress percentage
    var yearlyProgress: Double {
        guard yearlyTarget > 0 else { return 0 }
        return min(Double(yearlyCompleted) / Double(yearlyTarget), 1.0)
    }
}
