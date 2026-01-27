import Foundation
import SwiftData

/// Service responsible for managing historical monthly snapshots.
/// Enforces strict "Fail Closed" logic for data integrity.
///
/// **Invariants:**
/// - Never generates a snapshot if history is tainted (deletion occurred after month end)
/// - Never guesses or backfills
/// - Snapshot once created is immutable
@MainActor
final class SnapshotService: ObservableObject {
    
    static let shared = SnapshotService()
    
    private let calendar = Calendar.current
    private let defaults = UserDefaults.standard
    private let historyHorizonKey = "historyHorizon"
    
    // Dependencies
    private let syncService = SyncService.shared
    private let supabase = SupabaseService.shared
    
    private init() {}

    // MARK: - Query API
    
    /// Returns decoded snapshot data for a specific month/year.
    /// Returns nil when no snapshot exists or when data is missing/corrupted.
    func fetchSnapshot(year: Int, month: Int, in context: ModelContext) -> SnapshotData? {
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        
        // 1. Future or Current Month (no snapshots)
        if year > currentYear || (year == currentYear && month >= currentMonth) {
            return nil
        }
        
        // 2. Past Month - Check Local Storage
        let key = String(format: "%04d-%02d", year, month)
        let descriptor = FetchDescriptor<SnapshotModel>(
            predicate: #Predicate { $0.compositeKey == key }
        )
        
        if let local = try? context.fetch(descriptor).first {
            guard local.status == .available else { return nil }

            let decoder = JSONDecoder()
            return decodeSnapshot(local, using: decoder)
        }
        
        return nil
    }

    /// Decodes snapshot JSON into usable data. Returns nil if unavailable or corrupted.
    func decodeSnapshot(_ snapshot: SnapshotModel, using decoder: JSONDecoder = JSONDecoder()) -> SnapshotData? {
        guard snapshot.status == .available else { return nil }
        guard let stats = try? decoder.decode(SnapshotStatsData.self, from: snapshot.statsJSON),
              let ledger = try? decoder.decode([SnapshotLedgerData].self, from: snapshot.ledgerJSON) else {
            return nil
        }

        return SnapshotData(stats: stats, ledger: ledger)
    }

    /// Returns true if a snapshot exists and is marked available for a given month.
    func snapshotExists(year: Int, month: Int, in context: ModelContext) -> Bool {
        let key = String(format: "%04d-%02d", year, month)
        let descriptor = FetchDescriptor<SnapshotModel>(
            predicate: #Predicate { $0.compositeKey == key }
        )
        guard let local = try? context.fetch(descriptor).first else { return false }
        return local.status == .available
    }
    
    // MARK: - Generation Logic
    
    /// Main entry point. Iterates past months and generates/locks snapshots.
    func ensureSnapshotsGenerated(in context: ModelContext) async {
        guard let userId = supabase.currentUserId, let userUUID = UUID(uuidString: userId) else { return }
        guard !syncService.isFrozen else { return }
        
        // Range: From "First ever goal date" OR "Fixed Start Date"?
        // Let's assume absolute start logic or find earliest goal?
        // Finding earliest goal is expensive.
        // Better: Check `lastSnapshotMonth` from DB.
        // If no snapshots, look for earliest goal.
        
        let now = Date()
        let historyHorizon = defaults.object(forKey: historyHorizonKey) as? Date
        
        // Get earliest goal date to define start of history
        let goalDescriptor = FetchDescriptor<GoalModel>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        var startDate = now // Default to now (no history)
        if let firstGoal = (try? context.fetch(goalDescriptor))?.first {
            startDate = firstGoal.createdAt
        } else {
            return // No goals, nothing to snapshot
        }
        
        // Normalize start date to first of month
        let startComponents = calendar.dateComponents([.year, .month], from: startDate)
        guard let historyStart = calendar.date(from: startComponents) else { return }
        
        // Iterate month by month until Previous Month of `now`
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now)!
        let endComponents = calendar.dateComponents([.year, .month], from: previousMonthDate)
        guard let targetEnd = calendar.date(from: endComponents) else { return }
        
        // Loop
        var cursor = historyStart
        while cursor <= targetEnd {
            let y = calendar.component(.year, from: cursor)
            let m = calendar.component(.month, from: cursor)
            let key = String(format: "%04d-%02d", y, m)
            
            // Check if exists
            let descriptor = FetchDescriptor<SnapshotModel>(predicate: #Predicate { $0.compositeKey == key })
            let count = (try? context.fetchCount(descriptor)) ?? 0
            
            if count == 0 {
                // Determine Month End Date
                guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: cursor)?.addingTimeInterval(-1) else { break }
                
                // DATA INTEGRITY CHECK
                // If historyHorizon exists, and it is BEFORE or DURING this month...
                // Actually constraint: If deletion occurred ANY TIME after the month ended, but before we generated this snapshot.
                // Wait. If deletion happened in 2025, and we are snapshotting 2024.
                // Does the deletion affect 2024?
                // Yes, because "Goal Deletion" deletes the Goal row.
                // If the Goal row is gone, `StatsCalculator` cannot find it to recompute 2024 stats.
                // (Since we calculate stats by iterating Goals and checking obligations).
                // So ANY deletion updates `historyHorizon` to `Now`.
                // `historyHorizon` represents "The moment the timeline was tainted".
                // If `historyHorizon` is set, we can only safely generate snapshots for months that ended BEFORE the horizon?
                // NO. If `historyHorizon` is set (to Now), it means "A deletion JUST happened".
                // That deletion removed a Goal that existed in the past.
                // Therefore, ALL past history that wasn't already snapshotted is now compromised.
                // Any snapshot generated NOW would miss that goal.
                // So: If `historyHorizon` is present, it taints *everything* that hasn't been snapped yet.
                // UNLESS `historyHorizon` > `monthEnd`?
                // No. `historyHorizon` is "Date of Deletion".
                // If Deletion Date > Month End?
                // Example: Jan 2024 Ends.
                // March 2024: Delete Goal X (created in 2023). `historyHorizon` = March 10.
                // We try to snapshot Jan 2024 now.
                // Goal X is gone. Jan 2024 stats will be wrong.
                // So validity requires: The Data used for calculation must exist.
                // Since `StatsCalculator` relies on `GoalModel` existence, and `GoalModel` was hard deleted...
                // ANY hard deletion permanently compromises ALL unsnapped history.
                // So if `historyHorizon` is non-nil, we logically cannot generate ANY past snapshots that relied on that goal.
                // We don't know *which* goal was deleted or when it was created.
                // Strict Safety: If `historyHorizon` is set, we fail closed for ALL missing snapshots.
                
                // Exceptions: If we knew the deleted goal was created *after* the target month.
                // But we don't store deleted goals metadata locally (we wipe it).
                // So we must be conservative.
                
                // Result: If `historyHorizon != nil`, we mark snapshot as .missingData.
                
                let isCompromised = (historyHorizon != nil)
                
                if isCompromised {
                    // Mark as missing
                    let placeholder = SnapshotModel(
                        userId: userUUID,
                        year: y,
                        month: m,
                        statsJSON: Data(),
                        ledgerJSON: Data(),
                        status: .missingData
                    )
                    context.insert(placeholder)
                    SyncLogger.logSync("Snapshot for \(key) marked missing due to data taint.")
                } else {
                    // Safe to generate
                    let calculator = StatsCalculator(modelContext: context)
                    let stats = calculator.monthProgress(for: cursor)
                    let weeks = calculator.monthlyWeekLedger(for: cursor)
                    
                    let statsPayload = StatsPayload(
                        completedCount: stats.completed,
                        totalObligations: stats.totalObligations,
                        missedCount: stats.missed,
                        completedPercent: stats.completedPercent
                    )
                    let ledgerPayload = weeks.map { LedgerEntryPayload(week: $0.weekNumber, passed: $0.passed, total: $0.totalObligations, completed: $0.completed) }
                    
                    if let statsJSON = try? JSONEncoder().encode(statsPayload),
                       let ledgerJSON = try? JSONEncoder().encode(ledgerPayload) {
                        
                        let snapshot = SnapshotModel(
                            userId: userUUID,
                            year: y,
                            month: m,
                            statsJSON: statsJSON,
                            ledgerJSON: ledgerJSON,
                            status: .available
                        )
                        context.insert(snapshot)
                        
                        // Push to Cloud ("Push immediately")
                        Task {
                            let dto = SnapshotDTO(
                                id: snapshot.id.uuidString,
                                userId: userId,
                                year: y,
                                month: m,
                                stats: statsPayload,
                                ledger: ledgerPayload,
                                createdAt: ISO8601DateFormatter().string(from: Date())
                            )
                            try? await supabase.upsertSnapshot(dto)
                        }
                    }
                }
            }
            
            // Increment month
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor)!
        }
        
        try? context.save()
    }
}
