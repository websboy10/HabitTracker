import Foundation
import SwiftData

/// SwiftData model for tracking goal completions.
/// Each completion record represents one unit of progress towards a goal.
@Model
final class CompletionModel {
    
    /// Unique identifier
    @Attribute(.unique) var id: UUID
    
    /// Reference to the goal this completion belongs to
    var goalId: UUID
    
    /// When the completion occurred
    var completedAt: Date
    
    /// Value for measurable goals (e.g., 5.0 for "5 km")
    /// For count-based goals, this is 1.0
    var value: Double
    
    /// Initializer
    init(
        id: UUID = UUID(),
        goalId: UUID,
        completedAt: Date = Date(),
        value: Double = 1.0
    ) {
        self.id = id
        self.goalId = goalId
        self.completedAt = completedAt
        self.value = value
    }
    
    // MARK: - Date Helpers
    
    /// The date component only (no time)
    var completionDate: Date {
        Calendar.current.startOfDay(for: completedAt)
    }
    
    /// The year of completion
    var year: Int {
        Calendar.current.component(.year, from: completedAt)
    }
    
    /// The week of year
    var weekOfYear: Int {
        Calendar.current.component(.weekOfYear, from: completedAt)
    }
    
    /// The month
    var month: Int {
        Calendar.current.component(.month, from: completedAt)
    }
}
