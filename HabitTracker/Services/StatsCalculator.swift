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
        
        // Days in year (365 or 366 for leap year)
        let daysInYear = calendar.dateComponents([.day], from: yearStart, to: yearEnd).day ?? 365
        
        // For current year, only count days up to today
        let effectiveEnd = min(yearEnd, now)
        let effectiveDays = calendar.dateComponents([.day], from: yearStart, to: effectiveEnd).day ?? daysInYear
        
        // Fetch all daily goals that were active during the year
        let dailyGoals = fetchDailyGoalsActiveInYear(targetYear)
        
        // Expected = effective days × daily goals count
        let expectedTotal = effectiveDays * dailyGoals.count
        
        // Actual completed from obligations
        let obligations = fetchObligationsForDateRange(from: yearStart, to: effectiveEnd)
        let dailyGoalIds = Set(dailyGoals.map { $0.id })
        let dailyObligations = obligations.filter { dailyGoalIds.contains($0.goalId) }
        let completed = dailyObligations.filter { $0.isCompleted }.count
        
        let percent = expectedTotal > 0 ? Double(completed) / Double(expectedTotal) : 0
        return YearlyStats(completedPercent: min(percent, 1.0), year: targetYear)
    }
    
    private func fetchDailyGoalsActiveInYear(_ year: Int) -> [GoalModel] {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.recurrenceType == "daily" }
        )
        let allDailyGoals = (try? modelContext.fetch(descriptor)) ?? []
        
        // Filter to goals that were created before the end of the year
        guard let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return allDailyGoals
        }
        
        return allDailyGoals.filter { $0.createdAt < yearEnd }
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
        
        // Check if this is a past month (not current month)
        let isPastMonth = endOfMonth <= now
        let monthKey = MonthlyStatsCache.makeKey(from: monthDate)
        
        // For past months, try to load from cache first
        if isPastMonth {
            if let cached = fetchCachedMonthStats(key: monthKey) {
                return cached.toMonthProgressStats()
            }
        }

        let obligations = fetchObligationsForDateRange(from: startOfMonth, to: endOfMonth)
        let effectiveNow = min(now, endOfMonth)

        let daysInMonth = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        let dailyGoals = fetchActiveDailyGoals()
        let dailyGoalIds = Set(dailyGoals.map { $0.id })
        let expectedDailyTotal = daysInMonth * dailyGoals.count

        let dailyObligations = obligations.filter { dailyGoalIds.contains($0.goalId) }
        let nonDailyObligations = obligations.filter { !dailyGoalIds.contains($0.goalId) }

        let dailyCompleted = dailyObligations.filter { $0.isCompleted }.count
        let dailyMissed = dailyObligations.filter { deadlineEngine.isEffectivelyMissed($0, at: effectiveNow) }.count

        let nonDailyCompleted = nonDailyObligations.filter { $0.isCompleted }.count
        let nonDailyMissed = nonDailyObligations.filter { deadlineEngine.isEffectivelyMissed($0, at: effectiveNow) }.count

        let total = expectedDailyTotal + nonDailyObligations.count
        let completed = dailyCompleted + nonDailyCompleted
        let missed = dailyMissed + nonDailyMissed
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
        
        // Cache past month stats for instant future access
        if isPastMonth {
            cacheMonthStats(stats: stats, key: monthKey)
        }

        return stats
    }
    
    private func fetchCachedMonthStats(key: String) -> MonthlyStatsCache? {
        let descriptor = FetchDescriptor<MonthlyStatsCache>(
            predicate: #Predicate { $0.monthKey == key }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func cacheMonthStats(stats: MonthProgressStats, key: String) {
        // Check if already cached
        if fetchCachedMonthStats(key: key) != nil {
            return
        }
        
        let cache = MonthlyStatsCache(
            monthKey: key,
            completed: stats.completed,
            missed: stats.missed,
            pending: stats.pending,
            totalObligations: stats.totalObligations,
            completedPercent: stats.completedPercent,
            monthName: stats.monthName,
            year: stats.year
        )
        modelContext.insert(cache)
        try? modelContext.save()
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
            let missed = obligations.filter { deadlineEngine.isEffectivelyMissed($0, at: effectiveEnd) }.count
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
    /// Week 1 starts on the first day of the month and spans 7 days.
    func monthlyWeekLedger(for date: Date = Date()) -> [WeekLedgerEntry] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30
        let endOfMonth = calendar.date(byAdding: .day, value: daysInMonth, to: startOfMonth) ?? startOfMonth
        let year = calendar.component(.year, from: startOfMonth)

        var entries: [WeekLedgerEntry] = []

        for index in 0..<4 {
            guard let weekStart = calendar.date(byAdding: .day, value: index * 7, to: startOfMonth) else { continue }
            guard weekStart < endOfMonth else { continue }
            let weekEnd = min(calendar.date(byAdding: .day, value: 7, to: weekStart) ?? endOfMonth, endOfMonth)
            let effectiveEnd = min(weekEnd, date)

            let obligations = fetchObligationsForDateRange(from: weekStart, to: weekEnd)
            let completed = obligations.filter { $0.isCompleted }.count
            let missed = obligations.filter { deadlineEngine.isEffectivelyMissed($0, at: effectiveEnd) }.count
            let total = obligations.count

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
        return all.filter { deadlineEngine.isEffectivelyMissed($0, at: now) }.count
    }

    // MARK: - Goal Consistency Table

    /// Returns consistency data for all goals, sorted by lowest consistency first.
    func goalConsistencyTable() -> [GoalConsistencyEntry] {
        let goals = fetchAllGoals()
        let now = Date()
        var entries: [GoalConsistencyEntry] = []

        for goal in goals {
            let obligations = fetchObligationsForGoal(goal.id)

            let completed = obligations.filter { $0.isCompleted }.count
            let missed = obligations.filter { deadlineEngine.isEffectivelyMissed($0, at: now) }.count
            let resolved = completed + missed

            let consistency = resolved > 0 ? Double(completed) / Double(resolved) : 0

            entries.append(GoalConsistencyEntry(
                goalId: goal.id,
                title: goal.title,
                activeSince: goal.createdAt,
                consistency: min(consistency, 1.0),
                missedLifetime: missed,
                isActive: goal.isActive
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
                let missed = obligations.filter { deadlineEngine.isEffectivelyMissed($0, at: effectiveEnd) }.count
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

    private func fetchActiveGoals() -> [GoalModel] {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.status == "active" }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchActiveDailyGoals() -> [GoalModel] {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.status == "active" && $0.recurrenceType == "daily" }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchObligationsForDateRange(from startDate: Date, to endDate: Date) -> [ObligationModel] {
        let descriptor = FetchDescriptor<ObligationModel>()
        let all = (try? modelContext.fetch(descriptor)) ?? []

        return all.filter { obligation in
            obligation.scheduledAt >= startDate && obligation.scheduledAt < endDate
        }
    }

    private func fetchObligationsForGoal(_ goalId: UUID) -> [ObligationModel] {
        let descriptor = FetchDescriptor<ObligationModel>()
        let all = (try? modelContext.fetch(descriptor)) ?? []

        return all.filter { $0.goalId == goalId }
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
