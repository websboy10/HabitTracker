import Foundation

/// Represents a single habit/task in the tracker.
/// Used for today's tasks and weekly/monthly aggregation.
struct HabitTask: Identifiable {
    let id: UUID
    let title: String
    var isCompleted: Bool
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

/// Represents weekly progress data
struct WeekProgress {
    let completed: Int
    let total: Int
    let dayProgress: [Bool] // 7 days, true = completed
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

/// Represents monthly progress data
struct MonthProgress {
    let percentage: Double
    let daysRemaining: Int
    let monthAbbreviation: String
}
