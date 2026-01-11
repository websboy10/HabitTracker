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
}
