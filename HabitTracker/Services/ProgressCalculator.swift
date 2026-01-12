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

    /// Count of missed obligations for today.
    func missedToday() -> Int {
        todayCountsExtended().missed
    }

    // MARK: - Weekly Progress

    /// Returns weekly progress for the current week.
    func weekProgress() -> (completed: Int, total: Int, dayProgress: [Bool]) {
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!

        var dayProgress: [Bool] = []
        var totalCompleted = 0
        var totalObligations = 0

        for dayOffset in 0..<7 {
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                dayProgress.append(false)
                continue
            }

            let dayObligations = fetchObligationsForDateRange(from: dayStart, to: dayEnd)

            if !dayObligations.isEmpty {
                let completed = dayObligations.filter { $0.isCompleted }.count
                let missed = dayObligations.filter { deadlineEngine.isEffectivelyMissed($0, at: now) }.count
                totalCompleted += completed
                totalObligations += dayObligations.count

                // Day passed if ALL obligations completed AND none missed
                let allCompleted = completed == dayObligations.count && missed == 0
                dayProgress.append(allCompleted)
            } else {
                dayProgress.append(false)
            }
        }

        return (totalCompleted, totalObligations, dayProgress)
    }

    /// Binary: true if ALL obligations completed this week, false if ANY missed or pending.
    /// CORRECTED: Week passed = ALL completed AND zero misses.
    func weeklyPassed() -> Bool {
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else { return false }

        let obligations = fetchObligationsForDateRange(from: startOfWeek, to: min(endOfWeek, now))

        let total = obligations.count
        let completed = obligations.filter { $0.isCompleted }.count
        let missed = obligations.filter { deadlineEngine.isEffectivelyMissed($0, at: now) }.count

        // FIXED: Week passed = ALL completed AND zero misses
        return total > 0 && completed == total && missed == 0
    }

    // MARK: - Monthly Week Progress

    /// Returns progress for each week (1-4) of the current month.
    /// Each week is a 7-day block starting from the 1st of the month.
    /// Week ranges are clamped to month boundaries.
    func monthlyWeekProgress() -> [(completed: Int, total: Int, percentage: Double)] {
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
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
    
    /// Returns comprehensive monthly stats matching StatsCalculator's format.
    /// This is the single source of truth for monthly obligation stats in HomeView.
    func monthlyStats() -> (completed: Int, missed: Int, pending: Int, total: Int, percentage: Double) {
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
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

    /// Returns monthly resolved counts: (completed, missed, pending).
    func monthlyResolved() -> (completed: Int, missed: Int, pending: Int) {
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return (0, 0, 0)
        }

        let obligations = fetchObligationsForDateRange(from: startOfMonth, to: startOfNextMonth)

        let completed = obligations.filter { $0.isCompleted }.count
        let missed = obligations.filter { deadlineEngine.isEffectivelyMissed($0, at: now) }.count
        let pending = obligations.filter { deadlineEngine.isEffectivelyPending($0, at: now) }.count

        return (completed, missed, pending)
    }

    // MARK: - Yearly Progress

    /// Calculates yearly consistency: percentage of passed weeks + total misses.
    /// CORRECTED: Uses DeadlineEngine and proper week passed logic.
    func yearlyConsistency() -> (passedWeeksPercent: Double, totalMissed: Int) {
        let now = Date()
        let currentWeek = calendar.component(.weekOfYear, from: now)
        let currentYear = calendar.component(.year, from: now)

        var passedWeeks = 0
        var totalMissed = 0

        for weekNum in 1...currentWeek {
            guard let weekStart = calendar.date(from: DateComponents(weekOfYear: weekNum, yearForWeekOfYear: currentYear)) else {
                continue
            }
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                continue
            }

            let effectiveEnd = min(weekEnd, now)
            let obligations = fetchObligationsForDateRange(from: weekStart, to: effectiveEnd)

            // FIXED: Use DeadlineEngine for consistent missed detection
            let missed = obligations.filter { deadlineEngine.isEffectivelyMissed($0, at: effectiveEnd) }.count
            let completed = obligations.filter { $0.isCompleted }.count
            let total = obligations.count

            totalMissed += missed

            // FIXED: Week passed = ALL completed AND zero misses
            if total > 0 && completed == total && missed == 0 {
                passedWeeks += 1
            }
        }

        let percent = currentWeek > 0 ? Double(passedWeeks) / Double(currentWeek) : 0
        return (percent, totalMissed)
    }

    /// Overall yearly progress across all active goals.
    func yearlyProgress() -> Double {
        let consistency = yearlyConsistency()
        return consistency.passedWeeksPercent
    }

    /// Yearly progress for a specific goal.
    func yearlyProgress(for goal: GoalModel) -> Double {
        let now = Date()
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!

        let obligations = fetchObligationsForGoal(goal.id, from: startOfYear, to: now)

        let completed = obligations.filter { $0.isCompleted }.count
        let missed = obligations.filter { deadlineEngine.isEffectivelyMissed($0, at: now) }.count
        let resolved = completed + missed

        guard resolved > 0 else { return 0 }
        return Double(completed) / Double(resolved)
    }

    // MARK: - Helpers

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
