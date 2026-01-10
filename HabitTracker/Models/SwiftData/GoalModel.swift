import Foundation
import SwiftData

/// SwiftData model for a goal definition.
/// Goals define what habits the user wants to track, their frequency, and category.
@Model
final class GoalModel {
    
    /// Unique identifier
    @Attribute(.unique) var id: UUID
    
    /// Goal title (e.g., "Morning Hydration")
    var title: String
    
    /// Reference to the category
    var categoryId: UUID
    
    /// Frequency type: "daily", "weekly", "monthly"
    var frequency: String
    
    /// How many times per frequency period
    var frequencyCount: Int
    
    /// Unit of measurement (e.g., "time", "hour", "km", "min")
    var frequencyUnit: String
    
    /// Status: "active" or "paused"
    var status: String
    
    /// When the goal was created
    var createdAt: Date
    
    /// When the goal was last updated
    var updatedAt: Date
    
    /// Initializer
    init(
        id: UUID = UUID(),
        title: String,
        categoryId: UUID,
        frequency: String = "daily",
        frequencyCount: Int = 1,
        frequencyUnit: String = "time",
        status: String = "active",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.categoryId = categoryId
        self.frequency = frequency
        self.frequencyCount = frequencyCount
        self.frequencyUnit = frequencyUnit
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Formatted frequency string (e.g., "1 time / day")
    var frequencyText: String {
        let unit = frequencyCount == 1 ? frequencyUnit : "\(frequencyUnit)s"
        let period: String
        switch frequency {
        case "daily": period = "day"
        case "weekly": period = "week"
        case "monthly": period = "month"
        default: period = frequency
        }
        return "\(frequencyCount) \(unit) / \(period)"
    }
    
    /// Whether the goal is active
    var isActive: Bool {
        status == "active"
    }
}
