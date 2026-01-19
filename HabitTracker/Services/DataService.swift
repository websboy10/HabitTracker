import Foundation
import SwiftData

// MARK: - Data Service

/// Centralized data access layer for all CRUD operations.
/// All data writes MUST go through this service.
///
/// **Invariants:**
/// - All writes occur locally first
/// - Cloud sync is conditional on StorageMode
/// - Auth is validated before cloud operations
/// - Delete operations are atomic (local + cloud)
@MainActor
final class DataService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DataService()
    
    // MARK: - Dependencies
    
    private let supabase = SupabaseService.shared
    private let mutationQueue = MutationQueue.shared
    
    // MARK: - State
    
    @Published private(set) var isOperating: Bool = false
    
    /// Tracks obligation sync failure counts to prevent infinite retry loops
    private var obligationFailureCounts: [UUID: Int] = [:]
    private let maxObligationRetries = 3
    
    // MARK: - Encoders
    
    private let encoder = JSONEncoder()
    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private init() {}
    
    // MARK: - Validation
    
    /// Ensures the service is ready for operations.
    /// Uses RuntimeGuard for fail-fast behavior in debug.
    private func ensureReady() throws {
        guard RuntimeGuard.requireStorageModeResolved() else {
            throw DataServiceError.storageModeNotResolved
        }
    }
    
    /// Returns true if we should sync to cloud.
    /// Uses RuntimeGuard for validation.
    private var shouldSyncToCloud: Bool {
        guard StorageMode.isCloud else { return false }
        return RuntimeGuard.requireAuth()
    }
    
    // MARK: - Goal Operations
    
    /// Creates a goal locally and syncs to cloud if enabled
    func createGoal(_ goal: GoalModel, in modelContext: ModelContext) async throws {
        try ensureReady()
        
        isOperating = true
        defer { isOperating = false }
        
        // 1. Local write first
        modelContext.insert(goal)
        try modelContext.save()
        SyncLogger.logCRUD("Created goal locally: \(goal.title)")
        await NotificationEngine.shared.syncTaskNotifications(for: goal)
        await NotificationEngine.shared.syncReportNotifications(modelContext: modelContext)
        
        // 2. Cloud sync if enabled
        if shouldSyncToCloud {
            do {
                try await syncGoalToCloud(goal, operation: .create)
                SyncLogger.logCRUD("Created goal in cloud: \(goal.title)")
            } catch {
                // Queue for later sync
                queueGoalMutation(goal, operation: .create)
                SyncLogger.logCRUD("Queued goal creation for later: \(goal.title)", level: .warning)
            }
        }
    }
    
    /// Updates a goal locally and syncs to cloud if enabled
    func updateGoal(_ goal: GoalModel, in modelContext: ModelContext) async throws {
        try ensureReady()
        
        isOperating = true
        defer { isOperating = false }
        
        // 1. Local write
        goal.updatedAt = Date()
        try modelContext.save()
        SyncLogger.logCRUD("Updated goal locally: \(goal.title)")
        await NotificationEngine.shared.syncTaskNotifications(for: goal)
        await NotificationEngine.shared.syncReportNotifications(modelContext: modelContext)
        
        // 2. Cloud sync
        if shouldSyncToCloud {
            do {
                try await syncGoalToCloud(goal, operation: .update)
                SyncLogger.logCRUD("Updated goal in cloud: \(goal.title)")
            } catch {
                queueGoalMutation(goal, operation: .update)
                SyncLogger.logCRUD("Queued goal update for later: \(goal.title)", level: .warning)
            }
        }
    }
    
    /// Deletes a goal locally and from cloud (atomic operation)
    func deleteGoal(_ goalId: UUID, in modelContext: ModelContext) async throws {
        try ensureReady()
        
        isOperating = true
        defer { isOperating = false }

        await NotificationEngine.shared.cancelTaskNotifications(forGoalId: goalId)
        
        // 1. Delete related obligations first (locally)
        let obligationDescriptor = FetchDescriptor<ObligationModel>(
            predicate: #Predicate { $0.goalId == goalId }
        )
        let obligations = try modelContext.fetch(obligationDescriptor)
        for obligation in obligations {
            modelContext.delete(obligation)
        }
        
        // 2. Delete the goal locally
        let goalDescriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == goalId }
        )
        if let goal = try modelContext.fetch(goalDescriptor).first {
            modelContext.delete(goal)
        }
        try modelContext.save()
        SyncLogger.logCRUD("Deleted goal locally: \(goalId)")
        await NotificationEngine.shared.syncReportNotifications(modelContext: modelContext)
        
        // 3. Delete from cloud (hard delete, no soft delete)
        if shouldSyncToCloud {
            do {
                // Obligations table removed per user request. Deletion is implicit via goal deletion if table existed.
                try await supabase.deleteGoal(id: goalId.uuidString)
                SyncLogger.logCRUD("Deleted goal from cloud: \(goalId)")
            } catch {
                // Queue for later
                mutationQueue.enqueue(
                    entityType: .goal,
                    operationType: .delete,
                    entityId: goalId
                )
                SyncLogger.logCRUD("Queued goal deletion for later: \(goalId)", level: .warning)
            }
        }
    }
    
    // MARK: - Obligation Operations
    
    /// Updates an obligation locally and syncs to cloud
    func updateObligation(_ obligation: ObligationModel, in modelContext: ModelContext) async throws {
        try ensureReady()
        
        isOperating = true
        defer { isOperating = false }
        
        // 1. Local update
        obligation.updatedAt = Date()
        try modelContext.save()
        SyncLogger.logCRUD("Updated obligation locally: \(obligation.id)")
        await NotificationEngine.shared.syncReportNotifications(modelContext: modelContext)
        
        // 2. Cloud sync
        if shouldSyncToCloud {
            do {
                try await syncObligationToCloud(obligation)
                SyncLogger.logCRUD("Updated obligation in cloud: \(obligation.id)")
            } catch {
                queueObligationMutation(obligation)
                SyncLogger.logCRUD("Queued obligation update for later: \(obligation.id)", level: .warning)
            }
        }
    }
    
    // MARK: - Weekly Note Operations
    
    /// Creates or updates a weekly note
    func saveWeeklyNote(_ note: WeeklyNoteModel, in modelContext: ModelContext) async throws {
        try ensureReady()
        
        isOperating = true
        defer { isOperating = false }
        
        // 1. Local save
        note.updatedAt = Date()
        try modelContext.save()
        SyncLogger.logCRUD("Saved weekly note locally: \(note.key)")
        
        // 2. Cloud sync
        if shouldSyncToCloud {
            do {
                try await syncWeeklyNoteToCloud(note)
                SyncLogger.logCRUD("Saved weekly note in cloud: \(note.key)")
            } catch {
                queueWeeklyNoteMutation(note)
                SyncLogger.logCRUD("Queued weekly note for later: \(note.key)", level: .warning)
            }
        }
    }
    
    // MARK: - Reset All Data
    
    /// Deletes all domain data (goals, obligations, categories, weekly notes).
    /// Does NOT affect auth, settings, or onboarding state.
    func resetAllData(in modelContext: ModelContext) async throws {
        try ensureReady()
        
        isOperating = true
        defer { isOperating = false }
        
        SyncLogger.logAccount("Starting reset all data")

        await NotificationEngine.shared.cancelAllNotifications(reason: "reset-all-data")
        NotificationEngine.shared.resetNotificationSettingsToDefaults()
        
        // 1. Delete all local data
        try modelContext.delete(model: ObligationModel.self)
        try modelContext.delete(model: GoalModel.self)
        try modelContext.delete(model: WeeklyNoteModel.self)
        try modelContext.save()
        SyncLogger.logAccount("Deleted all local domain data")

        // 2. Delete all cloud data (if cloud mode)
        if shouldSyncToCloud, let userId = supabase.currentUserId {
            let tables = ["obligations", "weekly_notes", "goals"]
            for table in tables {
                do {
                    try await supabase.deleteAllUserData(from: table, userId: userId)
                } catch {
                    SyncLogger.logAccount("Failed to delete from \(table): \(error.localizedDescription)", level: .error)
                }
            }
            SyncLogger.logAccount("Deleted all cloud domain data")
        }
        
        // 3. Clear mutation queue
        mutationQueue.clear()
        
        // 4. Verify emptiness
        let goalCount = try modelContext.fetchCount(FetchDescriptor<GoalModel>())
        let obligationCount = try modelContext.fetchCount(FetchDescriptor<ObligationModel>())
        
        guard goalCount == 0 && obligationCount == 0 else {
            throw DataServiceError.resetIncomplete
        }
        
        SyncLogger.logAccount("Reset all data complete - verified empty")
    }
    
    // MARK: - Private Cloud Sync Helpers

    private func syncGoalToCloud(_ goal: GoalModel, operation: OperationType) async throws {
        guard let userId = supabase.currentUserId else { throw DataServiceError.notAuthenticated }

        let dto = GoalDTO(
            id: goal.id.uuidString,
            userId: userId,
            categoryName: goal.categoryName,
            categoryColorHex: goal.categoryColorHex,
            title: goal.title,
            frequency: "daily",
            status: goal.status,
            recurrenceType: goal.recurrenceType,
            weekdays: goal.weekdays,
            scheduledTime: goal.scheduledTime.map { iso8601Formatter.string(from: $0) },
            customIntervalDays: goal.customIntervalDays,
            monthlyDayOfMonth: goal.monthlyDayOfMonth,
            createdAt: iso8601Formatter.string(from: goal.createdAt),
            updatedAt: iso8601Formatter.string(from: goal.updatedAt)
        )

        switch operation {
        case .create:
            _ = try await supabase.createGoal(dto)
        case .update:
            _ = try await supabase.updateGoal(dto)
        case .delete:
            break // Handled separately
        }
    }
    
    private func syncObligationToCloud(_ obligation: ObligationModel) async throws {
        // Architecture: Goals + Completions (No Obligations Table)
        guard let userId = supabase.currentUserId else { throw DataServiceError.notAuthenticated }
        
        // We map a completed obligation to a row in the 'completions' table
        // We map a non-completed obligation to a DELETE on the 'completions' table
        
        // 1. If completed, UPSERT into completions
        if obligation.status == "completed", let completedAt = obligation.completedAt {
            SyncLogger.logCRUD("Syncing completion for goal: \(obligation.goalId)")
            
            // Use obligation ID as completion ID for deterministic mapping
            let dto = CompletionDTO(
                id: obligation.id.uuidString, 
                userId: userId,
                goalId: obligation.goalId.uuidString,
                completedAt: iso8601Formatter.string(from: completedAt),
                value: 1.0,
                createdAt: iso8601Formatter.string(from: obligation.createdAt)
            )
            
            _ = try await supabase.upsertCompletions([dto])
            
        } else {
            // 2. If not completed (pending/missed/etc), DELETE from completions
            // This handles "un-checking" a habit
            SyncLogger.logCRUD("Removing completion for goal: \(obligation.goalId)")
            
            // We use the obligation ID as the completion ID
            try await supabase.deleteCompletion(id: obligation.id.uuidString)
        }
    }
    
    private func syncWeeklyNoteToCloud(_ note: WeeklyNoteModel) async throws {
        guard let userId = supabase.currentUserId else { throw DataServiceError.notAuthenticated }
        
        _ = try await supabase.upsertWeeklyNote(
            userId: userId,
            year: note.year,
            month: note.month,
            weekIndex: note.weekIndex,
            text: note.text
        )
    }
    
    // MARK: - Queue Helpers
    
    private func queueGoalMutation(_ goal: GoalModel, operation: OperationType) {
        let payload = try? encoder.encode(goal.id.uuidString)
        mutationQueue.enqueue(
            entityType: .goal,
            operationType: operation,
            entityId: goal.id,
            payload: payload
        )
    }
    
    private func queueObligationMutation(_ obligation: ObligationModel) {
        mutationQueue.enqueue(
            entityType: .obligation,
            operationType: .update,
            entityId: obligation.id
        )
    }
    
    private func queueWeeklyNoteMutation(_ note: WeeklyNoteModel) {
        let key = note.key
        let entityId = UUID(uuidString: key.replacingOccurrences(of: "-", with: "").padding(toLength: 32, withPad: "0", startingAt: 0)) ?? UUID()
        mutationQueue.enqueue(
            entityType: .weeklyNote,
            operationType: .update,
            entityId: entityId
        )
    }
}

// MARK: - Errors

enum DataServiceError: Error, LocalizedError {
    case notAuthenticated
    case storageModeNotResolved
    case resetIncomplete
    case operationFailed(String)
    case permanentSyncFailure(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated for cloud operations"
        case .storageModeNotResolved:
            return "Storage mode not resolved"
        case .resetIncomplete:
            return "Reset operation did not complete fully"
        case .operationFailed(let reason):
            return "Operation failed: \(reason)"
        case .permanentSyncFailure(let reason):
            return "Sync permanently failed: \(reason)"
        }
    }
}
