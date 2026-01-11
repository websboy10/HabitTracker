import Foundation
import SwiftData

/// Centralized deadline and status logic for obligations.
/// This is the single source of truth for all deadline-related calculations.
/// Both StatsCalculator and ProgressCalculator must use this engine.
@MainActor
final class DeadlineEngine {

    static let shared = DeadlineEngine()

    private let calendar = Calendar.current
    private var modelContext: ModelContext?

    private init() {}

    /// Configure with model context for goal lookups
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Deadline Calculation

    /// Calculate when an obligation must be completed by.
    /// - If goal has explicit scheduledTime: deadline is that time on the scheduled day
    /// - If no explicit time: deadline is next day at day reset time
    /// - Grace period extends the deadline by N minutes
    func completionDeadline(for obligation: ObligationModel, goal: GoalModel? = nil, gracePeriodMinutes: Int? = nil) -> Date {
        let scheduledAt = obligation.scheduledAt

        // Determine if goal has explicit time
        let hasExplicitTime: Bool = {
            if let goal = goal ?? fetchGoal(for: obligation.goalId) {
                return goal.scheduledTime != nil
            }
            // Fallback: check if scheduledAt has non-zero time components
            let components = calendar.dateComponents([.hour, .minute], from: scheduledAt)
            return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
        }()

        let baseDeadline: Date
        if hasExplicitTime {
            // Deadline is the scheduled time itself
            baseDeadline = scheduledAt
        } else {
            // Deadline is next day at day reset time
            let resetMinutes = SettingsStore.shared.dayResetMinutes
            let resetHour = resetMinutes / 60
            let resetMinute = resetMinutes % 60
            let dayStart = calendar.startOfDay(for: scheduledAt)
            let resetSameDay = calendar.date(bySettingHour: resetHour, minute: resetMinute, second: 0, of: dayStart) ?? dayStart
            baseDeadline = calendar.date(byAdding: .day, value: 1, to: resetSameDay) ?? resetSameDay
        }

        // Apply grace period if provided, otherwise use global setting
        let grace = gracePeriodMinutes ?? SettingsStore.shared.gracePeriodMinutes
        if grace > 0 {
            return calendar.date(byAdding: .minute, value: grace, to: baseDeadline) ?? baseDeadline
        }
        return baseDeadline
    }

    // MARK: - Status Checks

    /// Check if obligation is overdue (pending + past deadline).
    /// An overdue pending obligation should be treated as missed for stats purposes.
    func isOverdue(_ obligation: ObligationModel, at date: Date = Date(), goal: GoalModel? = nil) -> Bool {
        guard obligation.isPending else { return false }
        let deadline = completionDeadline(for: obligation, goal: goal)
        return deadline < date
    }

    /// Check if obligation can be toggled (within completion window).
    /// Returns true if:
    /// - Not missed (locked)
    /// - Current time is between scheduledAt and deadline
    func canToggle(_ obligation: ObligationModel, goal: GoalModel? = nil, gracePeriodMinutes: Int? = nil) -> Bool {
        guard !obligation.isMissed else { return false }
        let now = Date()
        let deadline = completionDeadline(for: obligation, goal: goal, gracePeriodMinutes: gracePeriodMinutes)
        return now >= obligation.scheduledAt && now <= deadline
    }

    /// Get effective status considering overdue.
    /// - pending that's overdue → "missed" (for stats)
    /// - otherwise → actual status
    func effectiveStatus(_ obligation: ObligationModel, at date: Date = Date(), goal: GoalModel? = nil) -> String {
        if obligation.isMissed {
            return "missed"
        }
        if obligation.isCompleted {
            return "completed"
        }
        // pending
        if isOverdue(obligation, at: date, goal: goal) {
            return "missed"
        }
        return "pending"
    }

    /// Check if obligation is effectively missed (status == missed OR overdue pending)
    func isEffectivelyMissed(_ obligation: ObligationModel, at date: Date = Date(), goal: GoalModel? = nil) -> Bool {
        return effectiveStatus(obligation, at: date, goal: goal) == "missed"
    }

    /// Check if obligation is effectively pending (status == pending AND not overdue)
    func isEffectivelyPending(_ obligation: ObligationModel, at date: Date = Date(), goal: GoalModel? = nil) -> Bool {
        return effectiveStatus(obligation, at: date, goal: goal) == "pending"
    }

    // MARK: - Helpers

    private func fetchGoal(for goalId: UUID) -> GoalModel? {
        guard let modelContext = modelContext else { return nil }
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == goalId }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
