import Foundation
import SwiftData

/// Service for scheduling and managing obligations.
/// Replaces TaskGenerator with forward-looking obligation generation.
@MainActor
final class ObligationScheduler {

    private let modelContext: ModelContext
    private let calendar = Calendar.current
    private let deadlineEngine = DeadlineEngine.shared

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        deadlineEngine.configure(with: modelContext)
    }

    // MARK: - Obligation Generation

    /// Generate obligations for a goal for the next N days.
    /// For one-off goals, creates a single obligation on the scheduled date.
    func generateUpcomingObligations(for goal: GoalModel, daysAhead: Int = 14) {
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let endDate = calendar.date(byAdding: .day, value: max(0, daysAhead - 1), to: today) ?? today
        generateObligations(for: goal, from: today, to: endDate)

        try? modelContext.save()
    }

    /// Generate obligations for the current month (includes past days in month).
    func generateCurrentMonthObligations() {
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let endOfMonth = calendar.date(byAdding: .day, value: (calendar.range(of: .day, in: .month, for: now)?.count ?? 30) - 1, to: startOfMonth) ?? now

        let goals = fetchActiveGoals()
        for goal in goals {
            generateObligations(for: goal, from: startOfMonth, to: endOfMonth)
        }
        try? modelContext.save()
    }

    // MARK: - Period-Based Generation (Row-Based Truth)

    /// Ensure obligations exist for a specific date range for all active goals.
    /// Idempotent: skips if obligation already exists for goal+date.
    /// Respects goal.createdAt: never generates before goal creation.
    /// Ensure obligations exist for a specific goal in a date range.
    /// Use this when creating or updating a goal to backfill historical obligations.
    func ensureObligations(for goal: GoalModel, from start: Date, to end: Date) {
        generateObligations(for: goal, from: start, to: end)
        try? modelContext.save()
    }

    /// Ensure obligations exist for rolling 12 months (for Stats accuracy).
    /// This is the key method for Row-Based Truth: stats can only count what exists.
    func ensureRolling12MonthObligations() {
        let now = Date()
        let today = calendar.startOfDay(for: now)
        guard let rolling12Start = calendar.date(byAdding: .month, value: -12, to: today) else { return }

        // Generate from 12 months ago to end of current month
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let endOfMonth = calendar.date(byAdding: .day, value: (calendar.range(of: .day, in: .month, for: now)?.count ?? 30) - 1, to: startOfMonth) ?? now

        let goals = fetchActiveGoals()
        for goal in goals {
            // Start from max(rolling12Start, goal.createdAt) to respect goal creation date
            let effectiveStart = max(rolling12Start, calendar.startOfDay(for: goal.createdAt))
            generateObligations(for: goal, from: effectiveStart, to: endOfMonth)
        }
        try? modelContext.save()
    }

    // MARK: - Today's Obligations

    /// Fetch today's obligations with their associated goals.
    /// Category info is available directly on GoalModel via category relationship + display helpers.
    /// Sorted by goal orderIndex first, then by scheduledAt for stable user-defined ordering.
    func fetchTodaysObligations() -> [(obligation: ObligationModel, goal: GoalModel)] {
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        let descriptor = FetchDescriptor<ObligationModel>(
            sortBy: [SortDescriptor(\.scheduledAt)]
        )

        guard let obligations = try? modelContext.fetch(descriptor) else { return [] }

        // Filter to today's obligations
        let todaysObligations = obligations.filter { obligation in
            obligation.scheduledAt >= today && obligation.scheduledAt < tomorrow
        }

        let results = todaysObligations.compactMap { obligation -> (obligation: ObligationModel, goal: GoalModel)? in
            let goalId = obligation.goalId
            let goalDescriptor = FetchDescriptor<GoalModel>(
                predicate: #Predicate { $0.id == goalId }
            )
            guard let goal = try? modelContext.fetch(goalDescriptor).first else { return nil }

            return (obligation: obligation, goal: goal)
        }

        // Sort by goal orderIndex first, then by scheduledAt for stable ordering
        return results.sorted { lhs, rhs in
            if lhs.goal.orderIndex != rhs.goal.orderIndex {
                return lhs.goal.orderIndex < rhs.goal.orderIndex
            }
            return lhs.obligation.scheduledAt < rhs.obligation.scheduledAt
        }
    }

    // MARK: - Obligation Completion

    /// Complete an obligation (single-completion goals).
    /// Returns false if the obligation is already locked.
    @discardableResult
    func completeObligation(_ obligation: ObligationModel) -> Bool {
        let success = obligation.markCompleted()
        if success {
            try? modelContext.save()
        }
        return success
    }

    /// Uncomplete an obligation (completed -> pending) if still within window.
    @discardableResult
    func uncompleteObligation(_ obligation: ObligationModel, gracePeriodMinutes: Int) -> Bool {
        guard obligation.isCompleted else { return false }
        let deadline = deadlineEngine.completionDeadline(for: obligation, gracePeriodMinutes: gracePeriodMinutes)
        guard Date() <= deadline else { return false }
        let success = obligation.markPending()
        if success {
            try? modelContext.save()
        }
        return success
    }

    /// Toggle completion state (pending <-> completed) if allowed.
    /// For single-completion goals (requiredCount == 1), behaves as before.
    /// For multi-completion goals, increments count on tap, resets when fully complete.
    @discardableResult
    func toggleCompletion(_ obligation: ObligationModel, gracePeriodMinutes: Int) -> Bool {
        // Get the goal to check requiredCount
        guard let goal = fetchGoal(for: obligation) else {
            // Fallback to single-completion behavior
            let result = toggleSingleCompletion(obligation, gracePeriodMinutes: gracePeriodMinutes)
            return result
        }

        let requiredCount = goal.requiredCount
        var result: Bool

        // Single-completion goal: use existing binary toggle logic
        if requiredCount <= 1 {
            result = toggleSingleCompletion(obligation, gracePeriodMinutes: gracePeriodMinutes)
        } else {
            // Multi-completion goal: increment or reset
            result = toggleMultiCompletion(obligation, requiredCount: requiredCount, gracePeriodMinutes: gracePeriodMinutes)
        }
        
        return result
    }

    /// Binary toggle for single-completion goals (original behavior)
    private func toggleSingleCompletion(_ obligation: ObligationModel, gracePeriodMinutes: Int) -> Bool {
        if obligation.isCompleted {
            return uncompleteObligation(obligation, gracePeriodMinutes: gracePeriodMinutes)
        }
        if obligation.isPending {
            guard canToggle(obligation, gracePeriodMinutes: gracePeriodMinutes) else { return false }
            return completeObligation(obligation)
        }
        return false
    }

    /// Multi-completion toggle: increment count, reset when fully complete
    private func toggleMultiCompletion(_ obligation: ObligationModel, requiredCount: Int, gracePeriodMinutes: Int) -> Bool {
        guard canToggle(obligation, gracePeriodMinutes: gracePeriodMinutes) else { return false }

        // If fully completed, tapping resets to 0
        if obligation.isCompleted {
            let deadline = deadlineEngine.completionDeadline(for: obligation, gracePeriodMinutes: gracePeriodMinutes)
            guard Date() <= deadline else { return false }
            let success = obligation.resetCompletion()
            if success {
                try? modelContext.save()
            }
            return success
        }

        // Otherwise, increment the completion count
        obligation.incrementCompletion(requiredCount: requiredCount)
        try? modelContext.save()
        return true
    }

    func canToggle(_ obligation: ObligationModel, gracePeriodMinutes: Int) -> Bool {
        deadlineEngine.canToggle(obligation, gracePeriodMinutes: gracePeriodMinutes)
    }

    /// Fetch the goal associated with an obligation
    private func fetchGoal(for obligation: ObligationModel) -> GoalModel? {
        let goalId = obligation.goalId
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == goalId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Helpers

    private func fetchActiveGoals() -> [GoalModel] {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.status == "active" }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func createObligationIfNeeded(for goal: GoalModel, on date: Date) {
        // Check if obligation already exists for this goal and date
        let goalId = goal.id
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let descriptor = FetchDescriptor<ObligationModel>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []

        let alreadyExists = existing.contains { obligation in
            obligation.goalId == goalId &&
            obligation.scheduledAt >= startOfDay &&
            obligation.scheduledAt < endOfDay
        }

        if !alreadyExists {
            let obligation = ObligationModel(goalId: goal.id, scheduledAt: date)
            modelContext.insert(obligation)
        }
    }

    private func generateObligations(for goal: GoalModel, from startDate: Date, to endDate: Date) {
        let start = max(calendar.startOfDay(for: startDate), calendar.startOfDay(for: goal.createdAt))
        let end = calendar.startOfDay(for: endDate)
        guard start <= end else { return }

        switch goal.recurrenceType {
        case "none":
            let scheduledDate = goal.scheduledTime ?? goal.createdAt
            if scheduledDate >= start && scheduledDate <= end {
                createObligationIfNeeded(for: goal, on: scheduledDate)
            }

        case "daily":
            var date = start
            while date <= end {
                let scheduledDate = applyScheduledTime(goal.scheduledTime, to: date)
                createObligationIfNeeded(for: goal, on: scheduledDate)
                guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
                date = next
            }

        case "weekly":
            let selectedWeekdays = goal.weekdays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : goal.weekdays
            var date = start
            while date <= end {
                let weekday = isoWeekday(from: date)
                if selectedWeekdays.contains(weekday) {
                    let scheduledDate = applyScheduledTime(goal.scheduledTime, to: date)
                    createObligationIfNeeded(for: goal, on: scheduledDate)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
                date = next
            }

        case "monthly":
            let dayOfMonth = goal.monthlyDayOfMonth ?? calendar.component(.day, from: goal.createdAt)
            var monthDate = calendar.date(from: calendar.dateComponents([.year, .month], from: start)) ?? start
            while monthDate <= end {
                var components = calendar.dateComponents([.year, .month], from: monthDate)
                components.day = min(dayOfMonth, daysInMonth(monthDate))
                if let date = calendar.date(from: components), date >= start && date <= end {
                    let scheduledDate = applyScheduledTime(goal.scheduledTime, to: date)
                    createObligationIfNeeded(for: goal, on: scheduledDate)
                }
                guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthDate) else { break }
                monthDate = nextMonth
            }

        case "custom":
            guard let intervalDays = goal.customIntervalDays, intervalDays > 0 else { return }
            var currentDate = calendar.startOfDay(for: goal.createdAt)
            while currentDate <= end {
                if currentDate >= start {
                    let scheduledDate = applyScheduledTime(goal.scheduledTime, to: currentDate)
                    createObligationIfNeeded(for: goal, on: scheduledDate)
                }
                guard let nextDate = calendar.date(byAdding: .day, value: intervalDays, to: currentDate) else { break }
                currentDate = nextDate
            }

        default:
            break
        }
    }

    private func applyScheduledTime(_ time: Date?, to date: Date) -> Date {
        guard let time = time else { return date }

        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute

        return calendar.date(from: dateComponents) ?? date
    }

    /// Convert to ISO weekday (Monday=1, Sunday=7)
    private func isoWeekday(from date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        // Calendar weekday: Sunday=1, Monday=2, ..., Saturday=7
        // ISO weekday: Monday=1, ..., Sunday=7
        return weekday == 1 ? 7 : weekday - 1
    }

    private func daysInMonth(_ date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }
}
