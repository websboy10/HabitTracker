import Foundation
import SwiftData
import SwiftUI

/// SwiftData model for a goal definition.
/// Goals are plans/templates that spawn concrete, time-bound obligations.
@Model
final class GoalModel {

    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Goal title (e.g., "Morning Hydration")
    var title: String

    /// Category Name (e.g., "Health")
    var categoryName: String = "General"

    /// Category Color Hex (e.g., "D11A2A")
    var categoryColorHex: String = "D11A2A"

    /// Recurrence type: "none" (one-off), "daily", "weekly", "monthly", "custom"
    /// Default to "daily" for backward compatibility with old frequency-based goals
    var recurrenceType: String = "daily"

    /// Weekdays for weekly recurrence [1-7], Monday=1, Sunday=7
    /// e.g., [1,3,5] for Mon/Wed/Fri
    var weekdays: [Int] = []

    /// Optional scheduled time of day
    var scheduledTime: Date?

    /// Whether notifications are enabled for this goal
    var notificationsEnabled: Bool = false

    /// Optional notification time of day (hour/minute used)
    var notificationTime: Date?

    /// Custom interval in days (for "custom" recurrence)
    /// e.g., 14 for every 2 weeks
    var customIntervalDays: Int?

    /// Day of month for monthly recurrence (1-31)
    var monthlyDayOfMonth: Int?

    /// Number of completions required per obligation (default: 1)
    /// When > 1, each tap increments the obligation's completedCount
    var requiredCount: Int = 1

    /// Status: "active" or "paused"
    var status: String = "active"

    /// Display order index for user-defined sorting
    var orderIndex: Int = 0

    /// When the goal was created
    var createdAt: Date

    /// When the goal was last updated
    var updatedAt: Date

    /// Initializer
    init(
        id: UUID = UUID(),
        title: String,
        categoryName: String = "General",
        categoryColorHex: String = "D11A2A",
        recurrenceType: String = "none",
        weekdays: [Int] = [],
        scheduledTime: Date? = nil,
        notificationsEnabled: Bool = false,
        notificationTime: Date? = nil,
        customIntervalDays: Int? = nil,
        monthlyDayOfMonth: Int? = nil,
        requiredCount: Int = 1,
        status: String = "active",
        orderIndex: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.categoryName = categoryName
        self.categoryColorHex = categoryColorHex
        self.recurrenceType = recurrenceType
        self.weekdays = weekdays
        self.scheduledTime = scheduledTime
        self.notificationsEnabled = notificationsEnabled
        self.notificationTime = notificationTime
        self.customIntervalDays = customIntervalDays
        self.monthlyDayOfMonth = monthlyDayOfMonth
        self.requiredCount = max(1, requiredCount)  // Ensure minimum of 1
        self.status = status
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Whether the goal is active
    var isActive: Bool {
        status == "active"
    }

    /// Whether this is a one-off goal (no recurrence)
    var isOneOff: Bool {
        recurrenceType == "none"
    }

    /// Whether this goal has recurrence
    var hasRecurrence: Bool {
        recurrenceType != "none"
    }

    /// Formatted recurrence string for display
    var recurrenceText: String {
        switch recurrenceType {
        case "none":
            return "One-off"
        case "daily":
            return "Daily"
        case "weekly":
            if weekdays.isEmpty {
                return "Weekly"
            } else {
                let dayNames = weekdays.sorted().compactMap { weekdayName($0) }
                return dayNames.joined(separator: ", ")
            }
        case "monthly":
            return "Monthly"
        case "custom":
            if let days = customIntervalDays {
                return "Every \(days) days"
            }
            return "Custom"
        default:
            return recurrenceType
        }
    }

    /// Formatted time string for display
    var timeText: String? {
        guard let time = scheduledTime else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    /// Formatted monthly day (e.g., "15th")
    var monthlyDayText: String? {
        guard recurrenceType == "monthly" else { return nil }
        let day = monthlyDayOfMonth ?? Calendar.current.component(.day, from: createdAt)
        return "\(day)\(ordinalSuffix(for: day))"
    }

    private func ordinalSuffix(for day: Int) -> String {
        let tens = day % 100
        if tens >= 11 && tens <= 13 { return "th" }
        switch day % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    /// Helper to get weekday name from number (1=Mon, 7=Sun)
    private func weekdayName(_ day: Int) -> String? {
        switch day {
        case 1: return "Mon"
        case 2: return "Tue"
        case 3: return "Wed"
        case 4: return "Thu"
        case 5: return "Fri"
        case 6: return "Sat"
        case 7: return "Sun"
        default: return nil
        }
    }

    /// Whether this goal requires multiple completions per day
    var hasMultipleCompletions: Bool {
        requiredCount > 1
    }
    
    /// SwiftUI Color for the category
    var categoryColor: SwiftUI.Color {
        SwiftUI.Color(hex: UInt(categoryColorHex, radix: 16) ?? 0xD11A2A)
    }
}
