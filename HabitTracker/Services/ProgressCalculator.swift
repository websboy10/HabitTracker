import Foundation
import SwiftData

/// Service for calculating progress statistics based on obligations.
/// Uses DeadlineEngine for all deadline/status calculations (single source of truth).
@MainActor
final class ProgressCalculator {

    private let modelContext: ModelContext
    private let calendar = Calendar.current
    private let deadlineEngine = DeadlineEngine.shared

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Configure deadline engine with model context for goal lookups
        deadlineEngine.configure(with: modelContext)
    }

    // MARK: - Daily Progress

    /// Calculates today's completion percentage (completed / total).
    func todayProgress() -> Double {
        let counts = todayCountsExtended()
        guard counts.total > 0 else { return 0 }
        return Double(counts.completed) / Double(counts.total)
    }

    /// Returns counts for today: (total, completed, remaining).
    /// Remaining now means pending (not yet resolved).
    func todayCounts() -> (total: Int, completed: Int, remaining: Int) {
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return (0, 0, 0)
        }

        let obligations = fetchObligationsForDateRange(from: today, to: tomorrow)
        let now = Date()

        let completed = obligations.filter { $0.isCompleted }.count
        let pending = obligations.filter { deadlineEngine.isEffectivelyPending($0, at: now) }.count

        return (obligations.count, completed, pending)
    }

    /// Extended counts including missed.
    func todayCountsExtended() -> (total: Int, completed: Int, missed: Int, pending: Int) {
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return (0, 0, 0, 0)
        }

        let obligations = fetchObligationsForDateRange(from: today, to: tomorrow)
        let now = Date()

        let completed = obligations.filter { $0.isCompleted }.count
        let missed = obligations.filter { deadlineEngine.isEffectivelyMissed($0, at: now) }.count
        let pending = obligations.filter { deadlineEngine.isEffectivelyPending($0, at: now) }.count

        return (obligations.count, completed, missed, pending)
    }

    // MARK: - Monthly Week Progress

    /// Returns progress for each week (1-4) of the current month.
    /// Each week is a 7-day block starting from the 1st of the month.
    /// Week ranges are clamped to month boundaries.
    func monthlyWeekProgress() -> [(completed: Int, total: Int, percentage: Double)] {
        monthlyWeekProgress(for: Date())
    }

    /// Returns progress for each week (1-4) of the selected month.
    func monthlyWeekProgress(for monthDate: Date) -> [(completed: Int, total: Int, percentage: Double)] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30
        guard let endOfMonth = calendar.date(byAdding: .day, value: daysInMonth, to: startOfMonth) else {
            return Array(repeating: (0, 0, 0), count: 4)
        }

        var weekResults: [(completed: Int, total: Int, percentage: Double)] = []

        for weekIndex in 0..<4 {
            guard let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: startOfMonth),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                weekResults.append((0, 0, 0))
                continue
            }

            // Clamp week range to month boundaries
            let rangeStart = max(weekStart, startOfMonth)
            let rangeEnd = min(weekEnd, endOfMonth)
            
            guard rangeStart < rangeEnd else {
                weekResults.append((0, 0, 0))
                continue
            }

            let obligations = fetchObligationsForDateRange(from: rangeStart, to: rangeEnd)
            let completed = obligations.filter { $0.isCompleted }.count
            let total = expectedTotalObligations(from: rangeStart, to: rangeEnd)
            let percentage = total > 0 ? Double(completed) / Double(total) : 0

            weekResults.append((completed, total, percentage))
        }

        return weekResults
    }

    /// Returns completed/total obligations for the entire current month.
    func monthlyTotals() -> (completed: Int, total: Int) {
        let stats = monthlyStats()
        return (stats.completed, stats.total)
    }

    /// Returns completed/total obligations for the selected month.
    func monthlyTotals(for monthDate: Date) -> (completed: Int, total: Int) {
        let stats = monthlyStats(for: monthDate)
        return (stats.completed, stats.total)
    }
    
    /// Returns comprehensive monthly stats matching StatsCalculator's format.
    /// This is the single source of truth for monthly obligation stats in HomeView.
    func monthlyStats() -> (completed: Int, missed: Int, pending: Int, total: Int, percentage: Double) {
        monthlyStats(for: Date())
    }

    /// Returns comprehensive monthly stats for a selected month.
    func monthlyStats(for monthDate: Date) -> (completed: Int, missed: Int, pending: Int, total: Int, percentage: Double) {
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
        guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return (0, 0, 0, 0, 0)
        }

        let obligations = fetchObligationsForDateRange(from: startOfMonth, to: startOfNextMonth)
        let completed = obligations.filter { $0.isCompleted }.count
        let missed = obligations.filter { deadlineEngine.isEffectivelyMissed($0, at: now) }.count
        let total = expectedTotalObligations(from: startOfMonth, to: startOfNextMonth)
        let pending = max(0, total - completed - missed)
        let percentage = total > 0 ? Double(completed) / Double(total) : 0
        
        return (completed, missed, pending, total, percentage)
    }

    // MARK: - Monthly Progress

    // MARK: - Yearly Progress

    /// Returns yearly totals based on active goals and completed obligations.
    /// Expected counts follow frequency rules (daily/weekly/monthly) for the full calendar year.
    func yearlyTotals(for year: Int? = nil) -> (completed: Int, expected: Int, percentage: Double, year: Int) {
        let now = Date()
        let targetYear = year ?? calendar.component(.year, from: now)

        guard let yearStart = calendar.date(from: DateComponents(year: targetYear, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: targetYear + 1, month: 1, day: 1)) else {
            return (0, 0, 0, targetYear)
        }

        let activeGoals = fetchActiveGoals()
        let activeGoalIds = Set(activeGoals.map(\.id))

        let completed = completedObligations(from: yearStart, to: yearEnd, activeGoalIds: activeGoalIds)
        let expected = expectedYearlyTotal(for: activeGoals, from: yearStart, to: yearEnd)
        let percentage = expected > 0 ? Double(completed) / Double(expected) : 0

        return (completed, expected, min(percentage, 1.0), targetYear)
    }

    // MARK: - Helpers

    private func completedObligations(from startDate: Date, to endDate: Date, activeGoalIds: Set<UUID>) -> Int {
        guard !activeGoalIds.isEmpty else { return 0 }
        let descriptor = FetchDescriptor<ObligationModel>()
        let all = (try? modelContext.fetch(descriptor)) ?? []

        return all.filter { obligation in
            guard activeGoalIds.contains(obligation.goalId) else { return false }
            guard obligation.isCompleted else { return false }
            let completionDate = obligation.completedAt ?? obligation.scheduledAt
            return completionDate >= startDate && completionDate < endDate
        }.count
    }

    private func fetchObligationsForDateRange(from startDate: Date, to endDate: Date) -> [ObligationModel] {
        let descriptor = FetchDescriptor<ObligationModel>()
        let all = (try? modelContext.fetch(descriptor)) ?? []

        return all.filter { obligation in
            obligation.scheduledAt >= startDate && obligation.scheduledAt < endDate
        }
    }

    private func fetchObligationsForGoal(_ goalId: UUID, from startDate: Date, to endDate: Date) -> [ObligationModel] {
        let descriptor = FetchDescriptor<ObligationModel>()
        let all = (try? modelContext.fetch(descriptor)) ?? []

        return all.filter { obligation in
            obligation.goalId == goalId &&
            obligation.scheduledAt >= startDate &&
            obligation.scheduledAt < endDate
        }
    }

    private func fetchActiveGoals() -> [GoalModel] {
        let descriptor = FetchDescriptor<GoalModel>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "active" }
    }

    private func expectedTotalObligations(from startDate: Date, to endDate: Date) -> Int {
        let goals = fetchActiveGoals()
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start < end else { return 0 }

        return goals.reduce(0) { total, goal in
            total + expectedOccurrences(for: goal, from: start, to: end)
        }
    }

    private func expectedOccurrences(for goal: GoalModel, from start: Date, to end: Date) -> Int {
        let rangeStart = calendar.startOfDay(for: start)
        guard rangeStart < end else { return 0 }

        let recurrence = normalizedRecurrence(goal.recurrenceType)

        switch recurrence {
        case "none", "one-off", "oneoff":
            let scheduled = applyScheduledTime(goal.scheduledTime, to: goal.createdAt)
            return scheduled >= rangeStart && scheduled < end ? 1 : 0

        case "daily":
            let days = calendar.dateComponents([.day], from: rangeStart, to: end).day ?? 0
            return max(0, days)

        case "weekly":
            let selectedWeekdays = normalizedWeekdays(goal.weekdays)
            var count = 0
            var date = rangeStart
            while date < end {
                if selectedWeekdays.contains(isoWeekday(from: date)) {
                    count += 1
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
                date = next
            }
            return count

        case "monthly":
            let dayOfMonth = goal.monthlyDayOfMonth ?? calendar.component(.day, from: goal.createdAt)
            var count = 0
            var monthCursor = calendar.date(from: calendar.dateComponents([.year, .month], from: rangeStart)) ?? rangeStart
            while monthCursor < end {
                var components = calendar.dateComponents([.year, .month], from: monthCursor)
                components.day = min(dayOfMonth, daysInMonth(monthCursor))
                if let date = calendar.date(from: components), date >= rangeStart && date < end {
                    count += 1
                }
                guard let next = calendar.date(byAdding: .month, value: 1, to: monthCursor) else { break }
                monthCursor = next
            }
            return count

        case "custom":
            guard let intervalDays = goal.customIntervalDays, intervalDays > 0 else { return 0 }
            var count = 0
            var date = calendar.startOfDay(for: goal.createdAt)
            while date < end {
                if date >= rangeStart {
                    count += 1
                }
                guard let next = calendar.date(byAdding: .day, value: intervalDays, to: date) else { break }
                date = next
            }
            return count

        default:
            return 0
        }
    }

    private func expectedYearlyTotal(for goals: [GoalModel], from startDate: Date, to endDate: Date) -> Int {
        guard !goals.isEmpty else { return 0 }
        return goals.reduce(0) { total, goal in
            total + expectedYearlyOccurrences(for: goal, from: startDate, to: endDate)
        }
    }

    private func expectedYearlyOccurrences(for goal: GoalModel, from start: Date, to end: Date) -> Int {
        let recurrence = normalizedRecurrence(goal.recurrenceType)

        switch recurrence {
        case "daily":
            return frequencyCount(for: goal, recurrence: recurrence) * 365
        case "weekly":
            return frequencyCount(for: goal, recurrence: recurrence) * 52
        case "monthly":
            return frequencyCount(for: goal, recurrence: recurrence) * 12
        case "custom", "none", "one-off", "oneoff":
            return expectedOccurrences(for: goal, from: start, to: end)
        default:
            return 0
        }
    }

    private func frequencyCount(for goal: GoalModel, recurrence: String) -> Int {
        switch recurrence {
        case "weekly":
            return normalizedWeekdays(goal.weekdays).count
        case "daily", "monthly":
            return 1
        default:
            return 0
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

    private func isoWeekday(from date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    private func daysInMonth(_ date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private func normalizedRecurrence(_ recurrence: String) -> String {
        let trimmed = recurrence.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let collapsed = lower
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        switch collapsed {
        case "", "daily", "day", "everyday":
            return "daily"
        case "custom":
            return "custom"
        case "none", "oneoff", "oneoffgoal", "oneofftask", "once", "single":
            return "none"
        default:
            if collapsed.hasPrefix("weekly") || collapsed == "week" {
                return "weekly"
            }
            if collapsed.hasPrefix("monthly") || collapsed == "month" {
                return "monthly"
            }
            if collapsed.hasPrefix("daily") || collapsed == "day" {
                return "daily"
            }
            return lower
        }
    }

    private func normalizedWeekdays(_ weekdays: [Int]) -> [Int] {
        guard !weekdays.isEmpty else { return [1, 2, 3, 4, 5, 6, 7] }
        if weekdays.contains(0) {
            return weekdays.map { $0 == 0 ? 7 : $0 }
        }
        return weekdays
    }
}
