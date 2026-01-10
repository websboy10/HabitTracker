import Foundation
import SwiftData

/// SwiftData model for daily generated tasks.
/// Tasks are created from goals and represent what the user needs to complete today.
@Model
final class TaskModel {
    
    /// Unique identifier
    @Attribute(.unique) var id: UUID
    
    /// Reference to the goal this task was generated from
    var goalId: UUID
    
    /// The date this task is for
    var date: Date
    
    /// Whether the task is completed
    var isCompleted: Bool
    
    /// When the task was completed (nil if not completed)
    var completedAt: Date?
    
    /// Initializer
    init(
        id: UUID = UUID(),
        goalId: UUID,
        date: Date = Date(),
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.goalId = goalId
        self.date = Calendar.current.startOfDay(for: date)
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
    
    /// Mark the task as completed
    func complete() {
        isCompleted = true
        completedAt = Date()
    }
    
    /// Mark the task as incomplete
    func uncomplete() {
        isCompleted = false
        completedAt = nil
    }
}
