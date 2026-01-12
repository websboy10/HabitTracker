import Foundation
import SwiftData

/// Service for calculating aggregate statistics for the Stats view.
/// Provides read-only metrics based on obligations: no actions, no interpretation.
/// Uses DeadlineEngine for all deadline/status calculations (single source of truth).
@MainActor
final class StatsCalculator {

    private let modelContext: ModelContext
    private let calendar = Calendar.current
    private let deadlineEngine = DeadlineEngine.shared

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Configure deadline engine with model context for goal lookups
        deadlineEngine.configure(with: modelContext)
    }

    // MARK: - Yearly Stats (365-day math)

    /// Returns yearly statistics for a specific year based on daily goal volume.
    /// Calculates as: completed_daily_tasks / (days_in_year × daily_goals_count) × 100
    func yearlyStats(for year: Int? = nil) -> YearlyStats {
        let now = Date()
        let targetYear = year ?? calendar.component(.year, from: now)
        
        guard let yearStart = calendar.date(from: DateComponents(year: targetYear, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: targetYear + 1, month: 1, day: 1)) else {
            return YearlyStats(completedPercent: 0, year: targetYear)
        }
        
        // For current year, only count days up to today
        let effectiveEnd = min(yearEnd, now)

        let obligations = fetchObligationsForDateRange(from: yearStart, to: effectiveEnd)
        let completed = obligations.filter { $0.isCompleted }.count
        let total = obligations.count

        let percent = total > 0 ? Double(completed) / Double(total) : 0
        return YearlyStats(completedPercent: min(percent, 1.0), year: targetYear)
    }

    // MARK: - Monthly Progress (Obligations Only)

    /// Returns current month progress based on obligations only.
    func monthProgress() -> MonthProgressStats {
        return monthProgress(for: Date())
    }
    
    /// Returns progress for a specific month based on obligations.
    /// Uses cache for past months to enable instant loading.
    func monthProgress(for monthDate: Date) -> MonthProgressStats {
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
        guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return MonthProgressStats(completedPercent: 0, totalObligations: 0, completed: 0, missed: 0, pending: 0, monthName: "", year: 0)
        }
        
        let obligations = fetchObligationsForDateRange(from: startOfMonth, to: endOfMonth)
        let effectiveNow = min(now, endOfMonth)

        let completed = obligations.filter { $0.isCompleted }.count
        let missed = obligations.filter { deadlineEngine.isEffectivelyMissed($0, at: effectiveNow) }.count
        let total = expectedTotalObligations(from: startOfMonth, to: endOfMonth)
        let pending = max(0, total - completed - missed)

        let completedPercent = total > 0 ? Double(completed) / Double(total) : 0
        
        // Get month name and year
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        let monthName = monthFormatter.string(from: monthDate)
        let year = calendar.component(.year, from: monthDate)
        
        let stats = MonthProgressStats(
            completedPercent: completedPercent,
            totalObligations: total,
            completed: completed,
            missed: missed,
            pending: pending,
            monthName: monthName,
            year: year
        )
        
        return stats
    }

    // MARK: - Weekly Ledger

    /// Returns weekly binary outcomes for the past N weeks.
    /// CORRECTED: Week passed = ALL obligations completed AND zero misses.
    func weeklyLedger(weeks: Int = 12) -> [WeekLedgerEntry] {
        let now = Date()
        var entries: [WeekLedgerEntry] = []

        for weekOffset in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)) else {
                continue
            }

            guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else { continue }
            let weekNumber = calendar.component(.weekOfYear, from: startOfWeek)
            let year = calendar.component(.year, from: startOfWeek)

            let effectiveEnd = min(endOfWeek, now)
            let obligations = fetchObligationsForDateRange(from: startOfWeek, to: effectiveEnd)

            let completed = obligations.filter { $0.isCompleted }.count
            let missed = obligations.filter { $0.isMissed }.count
            let total = obligations.count

            // FIXED: Week passed = ALL obligations completed AND zero misses
            // A week with pending obligations is NOT passed (incomplete)
            // A week with any misses is NOT passed
            let passed = total > 0 && completed == total && missed == 0

            entries.append(WeekLedgerEntry(
                weekNumber: weekNumber,
                year: year,
                startDate: startOfWeek,
                passed: passed,
                totalObligations: total,
                completed: completed,
                missed: missed
            ))
        }

        return entries.reversed()
    }

    /// Returns 4 weekly entries for the current month (weeks 1-4).
    /// Each week is a fixed 7-day block starting from the 1st of the month.
    /// Week ranges are clamped to month boundaries.
    func monthlyWeekLedger(for date: Date = Date()) -> [WeekLedgerEntry] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30
        let endOfMonth = calendar.date(byAdding: .day, value: daysInMonth, to: startOfMonth) ?? startOfMonth
        let year = calendar.component(.year, from: startOfMonth)
        let now = Date()

        var entries: [WeekLedgerEntry] = []

        for index in 0..<4 {
            guard let weekStart = calendar.date(byAdding: .day, value: index * 7, to: startOfMonth) else { continue }
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { continue }
            
            // Clamp week range to month boundaries
            let rangeStart = max(weekStart, startOfMonth)
            let rangeEnd = min(weekEnd, endOfMonth)
            
            guard rangeStart < rangeEnd else { continue }

            let effectiveEnd = min(rangeEnd, now)
            let obligations = fetchObligationsForDateRange(from: rangeStart, to: rangeEnd)
            let completed = obligations.filter { $0.isCompleted }.count
            let missed = obligations.filter { deadlineEngine.isEffectivelyMissed($0, at: effectiveEnd) }.count
            let total = expectedTotalObligations(from: rangeStart, to: rangeEnd)

            let passed = total > 0 && completed == total && missed == 0

            entries.append(WeekLedgerEntry(
                weekNumber: index + 1,
                year: year,
                startDate: weekStart,
                passed: passed,
                totalObligations: total,
                completed: completed,
                missed: missed
            ))
        }

        return entries
    }

    // MARK: - Lifetime Missed

    /// Returns total lifetime missed obligations. Never resets.
    func lifetimeMissed() -> Int {
        let descriptor = FetchDescriptor<ObligationModel>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        let now = Date()
        return all.filter { $0.isMissed }.count
    }

    // MARK: - Goal Consistency Table

    /// Returns consistency data for all goals, sorted by lowest consistency first.
    func goalConsistencyTable() -> [GoalConsistencyEntry] {
        let goals = fetchAllGoals()
        let goalsById = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0) })
        let obligations = fetchObligationsForAllGoals()
        let now = Date()
        var entries: [GoalConsistencyEntry] = []

        let grouped = Dictionary(grouping: obligations, by: { $0.goalId })
        for (goalId, group) in grouped {
            let completed = group.filter { $0.isCompleted }.count
            let missed = group.filter { deadlineEngine.isEffectivelyMissed($0, at: now) }.count
            let resolved = completed + missed

            let consistency = resolved > 0 ? Double(completed) / Double(resolved) : 0
            let earliest = group.map(\.scheduledAt).min() ?? now
            let goal = goalsById[goalId]

            entries.append(GoalConsistencyEntry(
                goalId: goalId,
                title: goal?.title ?? "Unknown Goal",
                activeSince: earliest,
                consistency: min(consistency, 1.0),
                missedLifetime: missed,
                isActive: goal?.isActive ?? false
            ))
        }

        return entries.sorted { $0.consistency < $1.consistency }
    }

    // MARK: - Yearly Archive

    /// Returns year-by-year summary for archive view.
    /// CORRECTED: Week passed = ALL obligations completed AND zero misses.
    func yearlyArchive() -> [YearArchiveEntry] {
        let allGoals = fetchAllGoals()
        let now = Date()
        let currentYear = calendar.component(.year, from: now)

        var years = Set<Int>()
        for goal in allGoals {
            let goalYear = calendar.component(.year, from: goal.createdAt)
            years.insert(goalYear)
        }
        years.insert(currentYear)

        var entries: [YearArchiveEntry] = []

        for year in years.sorted().reversed() {
            guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
                  let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
                continue
            }

            let effectiveEnd = min(yearEnd, now)
            let currentWeekOfYear = calendar.component(.weekOfYear, from: effectiveEnd)
            let totalWeeksInYear = year == currentYear ? currentWeekOfYear : 52

            var passedWeeks = 0
            var totalMissedInYear = 0

            for weekNum in 1...totalWeeksInYear {
                guard let weekStart = calendar.date(from: DateComponents(weekOfYear: weekNum, yearForWeekOfYear: year)) else {
                    continue
                }
                guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { continue }

                let obligations = fetchObligationsForDateRange(from: weekStart, to: min(weekEnd, effectiveEnd))

                let completed = obligations.filter { $0.isCompleted }.count
                let missed = obligations.filter { $0.isMissed }.count
                let total = obligations.count

                totalMissedInYear += missed

                // FIXED: Week passed = ALL obligations completed AND zero misses
                if total > 0 && completed == total && missed == 0 {
                    passedWeeks += 1
                }
            }

            let weeksPassedPercent = totalWeeksInYear > 0 ? Double(passedWeeks) / Double(totalWeeksInYear) : 0

            entries.append(YearArchiveEntry(
                year: year,
                weeksPassedPercent: weeksPassedPercent,
                passedWeeks: passedWeeks,
                totalWeeks: totalWeeksInYear,
                missedInYear: totalMissedInYear
            ))
        }

        return entries
    }

    // MARK: - Helpers

    private func fetchAllGoals() -> [GoalModel] {
        let descriptor = FetchDescriptor<GoalModel>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchObligationsForDateRange(from startDate: Date, to endDate: Date) -> [ObligationModel] {
        let descriptor = FetchDescriptor<ObligationModel>()
        let all = (try? modelContext.fetch(descriptor)) ?? []

        return all.filter { obligation in
            obligation.scheduledAt >= startDate && obligation.scheduledAt < endDate
        }
    }

    private func fetchObligationsForAllGoals() -> [ObligationModel] {
        let descriptor = FetchDescriptor<ObligationModel>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchActiveGoals() -> [GoalModel] {
        fetchAllGoals().filter { normalizedStatus($0.status) == "active" }
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
        case "none":
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

    private func normalizedStatus(_ status: String) -> String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

// MARK: - Data Structures

struct Rolling12MonthStats {
    let completedPercent: Double
    let totalObligations: Int
    let completed: Int
    let missed: Int
}

struct YearlyStats {
    let completedPercent: Double
    let year: Int
}

struct MonthProgressStats {
    let completedPercent: Double
    let totalObligations: Int
    let completed: Int
    let missed: Int
    let pending: Int
    var monthName: String = ""
    var year: Int = 0
}

struct WeekLedgerEntry: Identifiable {
    let id = UUID()
    let weekNumber: Int
    let year: Int
    let startDate: Date
    let passed: Bool
    let totalObligations: Int
    let completed: Int
    let missed: Int
}

struct GoalConsistencyEntry: Identifiable {
    let id = UUID()
    let goalId: UUID
    let title: String
    let activeSince: Date
    let consistency: Double
    let missedLifetime: Int
    let isActive: Bool
}

struct YearArchiveEntry: Identifiable {
    let id = UUID()
    let year: Int
    let weeksPassedPercent: Double
    let passedWeeks: Int
    let totalWeeks: Int
    let missedInYear: Int
}
