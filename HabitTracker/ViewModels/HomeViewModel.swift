import SwiftUI
import SwiftData

/// ViewModel for the Home screen with obligation-based system.
@MainActor
@Observable
final class HomeViewModel {

    /// Model context for SwiftData operations
    private var modelContext: ModelContext?

    /// Obligation scheduler service
    private var obligationScheduler: ObligationScheduler?

    /// Progress calculator service
    private var progressCalculator: ProgressCalculator?
    private var resetTimer: Timer?

    // MARK: - Configuration

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        self.obligationScheduler = ObligationScheduler(modelContext: modelContext)
        self.progressCalculator = ProgressCalculator(modelContext: modelContext)

        // Generate obligations for the current month (includes earlier days)
        obligationScheduler?.generateCurrentMonthObligations()

        // Ensure rolling 12 months for stats accuracy (Row-Based Truth)
        obligationScheduler?.ensureRolling12MonthObligations()

        DeadlineProcessor.shared.processPendingObligations(modelContext: modelContext)

        scheduleDailyReset()
    }

    // MARK: - Today's Obligations

    /// Fetches today's obligations with goal information
    func fetchTodaysObligations() -> [(obligation: ObligationModel, goal: GoalModel, category: CategoryModel?)] {
        obligationScheduler?.fetchTodaysObligations() ?? []
    }

    // MARK: - Progress

    /// Daily completion percentage
    var completionPercentage: Double {
        progressCalculator?.todayProgress() ?? 0
    }

    /// Today's counts (total, completed, remaining/pending)
    var todayCounts: (total: Int, completed: Int, remaining: Int) {
        progressCalculator?.todayCounts() ?? (0, 0, 0)
    }

    /// Extended counts with missed
    var todayCountsExtended: (total: Int, completed: Int, missed: Int, pending: Int) {
        progressCalculator?.todayCountsExtended() ?? (0, 0, 0, 0)
    }

    var totalCount: Int { todayCounts.total }
    var completedCount: Int { todayCounts.completed }
    var remainingCount: Int { todayCounts.remaining }
    var missedCount: Int { todayCountsExtended.missed }

    /// Weekly progress
    var weekProgress: (completed: Int, total: Int, dayProgress: [Bool]) {
        progressCalculator?.weekProgress() ?? (0, 0, [])
    }

    /// Week progress model for WeekOverviewCard
    var weekProgressModel: WeekProgress {
        let progress = weekProgress
        return WeekProgress(
            completed: progress.completed,
            total: progress.total,
            dayProgress: progress.dayProgress.isEmpty ? Array(repeating: false, count: 7) : progress.dayProgress
        )
    }

    /// Monthly week progress for Monthly Ledger (weeks 1-4)
    var monthlyWeekProgress: [(completed: Int, total: Int, percentage: Double)] {
        progressCalculator?.monthlyWeekProgress() ?? Array(repeating: (0, 0, 0), count: 4)
    }

    /// Monthly totals for Monthly Ledger header (entire month)
    var monthlyTotals: (completed: Int, total: Int) {
        progressCalculator?.monthlyTotals() ?? (0, 0)
    }
    
    /// Full monthly stats including completed, missed, pending, total, and percentage.
    /// This matches StatsCalculator's monthProgress output for consistency.
    var monthlyFullStats: (completed: Int, missed: Int, pending: Int, total: Int, percentage: Double) {
        progressCalculator?.monthlyStats() ?? (0, 0, 0, 0, 0)
    }

    // MARK: - Actions

    /// Toggle an obligation completion if within its window
    func completeObligation(_ obligation: ObligationModel) {
        guard let obligationScheduler else { return }

        let gracePeriod = SettingsStore.shared.gracePeriodMinutes
        let success = obligationScheduler.toggleCompletion(obligation, gracePeriodMinutes: gracePeriod)
        if success {
            HapticManager.shared.success()

            // Sync to cloud
            Task {
                await SyncService.shared.syncObligationUpdate(obligation)
            }
        }
    }

    /// Whether the obligation can be toggled (complete/uncomplete) within its window.
    func canToggleObligation(_ obligation: ObligationModel) -> Bool {
        guard let obligationScheduler else { return false }
        let gracePeriod = SettingsStore.shared.gracePeriodMinutes
        return obligationScheduler.canToggle(obligation, gracePeriodMinutes: gracePeriod)
    }

    private func scheduleDailyReset() {
        resetTimer?.invalidate()
        let now = Date()
        let nextReset = nextResetDate(after: now)
        let interval = max(1, nextReset.timeIntervalSince(now))

        resetTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self, let obligationScheduler = self.obligationScheduler, let modelContext = self.modelContext else { return }
            DeadlineProcessor.shared.processPendingObligations(modelContext: modelContext)
            obligationScheduler.generateCurrentMonthObligations()
            self.scheduleDailyReset()
        }
    }

    private func nextResetDate(after date: Date) -> Date {
        let calendar = Calendar.current
        let resetMinutes = SettingsStore.shared.dayResetMinutes
        let resetHour = resetMinutes / 60
        let resetMinute = resetMinutes % 60
        let startOfDay = calendar.startOfDay(for: date)
        let resetToday = calendar.date(bySettingHour: resetHour, minute: resetMinute, second: 0, of: startOfDay) ?? startOfDay
        if date < resetToday {
            return resetToday
        }
        return calendar.date(byAdding: .day, value: 1, to: resetToday) ?? resetToday
    }

    /// Refresh obligations (check for missed, generate new)
    func refreshObligations() {
        guard let obligationScheduler else { return }

        if let context = modelContext {
            DeadlineProcessor.shared.processPendingObligations(modelContext: context)
        }

        // Generate obligations for the current month
        obligationScheduler.generateCurrentMonthObligations()
    }

    // MARK: - Sync

    /// Triggers a full sync with cloud
    func performSync() {
        guard let modelContext else { return }

        Task {
            await SyncService.shared.performFullSync(modelContext: modelContext)
        }
    }
}
