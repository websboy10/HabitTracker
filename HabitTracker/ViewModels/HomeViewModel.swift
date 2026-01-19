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
    /// Category info is available directly on GoalModel via categoryName and categoryColorHex.
    func fetchTodaysObligations() -> [(obligation: ObligationModel, goal: GoalModel)] {
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

    /// Monthly week progress for Monthly Ledger (weeks 1-4)
    var monthlyWeekProgress: [(completed: Int, total: Int, percentage: Double)] {
        progressCalculator?.monthlyWeekProgress() ?? Array(repeating: (0, 0, 0), count: 4)
    }

    /// Monthly week progress for a selected month (weeks 1-4)
    func monthlyWeekProgress(for monthDate: Date) -> [(completed: Int, total: Int, percentage: Double)] {
        progressCalculator?.monthlyWeekProgress(for: monthDate) ?? Array(repeating: (0, 0, 0), count: 4)
    }

    /// Monthly totals for Monthly Ledger header (entire month)
    var monthlyTotals: (completed: Int, total: Int) {
        progressCalculator?.monthlyTotals() ?? (0, 0)
    }

    /// Monthly totals for a selected month (entire month)
    func monthlyTotals(for monthDate: Date) -> (completed: Int, total: Int) {
        progressCalculator?.monthlyTotals(for: monthDate) ?? (0, 0)
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

}
