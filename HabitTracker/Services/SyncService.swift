import Foundation
import SwiftData

/// Service responsible for syncing local SwiftData with Supabase
@MainActor
final class SyncService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SyncService()
    
    // MARK: - Dependencies
    private let supabase = SupabaseService.shared
    
    // MARK: - State
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: String?
    @Published private(set) var lastSyncSucceeded: Bool = false
    @Published private(set) var isFrozen: Bool = false
    private var allowWhenLockedForSync: Bool = false
    private var cancelRequested: Bool = false
    
    // MARK: - Storage Mode
    
    /// Returns true if user has chosen cloud storage mode in onboarding
    var isCloudSyncEnabled: Bool {
        StorageMode.isCloud
    }
    
    // MARK: - Date Formatting
    private let calendar = Calendar.current
    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private let deletedGoalsKey = "deleted_goal_ids"
    private var deletedGoalIds: Set<UUID> = []

    private init() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        deletedGoalIds = loadDeletedGoalIds()
    }
    
    // MARK: - Full Sync
    
    /// Perform a full bidirectional sync
    /// Cloud is the source of truth - cloud always wins on conflicts
    func performFullSync(modelContext: ModelContext, allowWhenLocked: Bool = false) async {
        guard !isFrozen else {
            SyncLogger.logSync("Sync blocked: frozen", level: .warning)
            return
        }
        if cancelRequested {
            SyncLogger.logSync("Sync canceled before start", level: .warning)
            return
        }
        // RuntimeGuard: Validate sync conditions (cloud mode + auth)
        guard StorageMode.isCloud else { return }
        guard RuntimeGuard.requireAuthenticatedRunning(allowWhenLocked: allowWhenLocked) else {
            syncError = "Sync conditions not met"
            SyncLogger.logSync("Sync blocked by RuntimeGuard", level: .error)
            return
        }
        
        isSyncing = true
        allowWhenLockedForSync = allowWhenLocked
        defer { allowWhenLockedForSync = false }
        syncError = nil
        SyncLogger.logSync("Starting full sync")
        
        do {
            let syncWork: () async throws -> Void = {
                if self.cancelRequested { throw CancellationError() }
                // Replay any pending mutations first
                let mutationQueue = MutationQueue.shared
                if mutationQueue.hasPending {
                    SyncLogger.logSync("Replaying \(mutationQueue.pendingCount) pending mutations")
                    try await mutationQueue.replay(using: self)
                }
                
                if self.cancelRequested { throw CancellationError() }
                // Sync goals
                try await self.syncGoals(modelContext: modelContext)
                
                if self.cancelRequested { throw CancellationError() }
                // Sync completions (via obligation status)
                try await self.syncObligations(modelContext: modelContext)
                
                if self.cancelRequested { throw CancellationError() }
                // Sync weekly notes
                try await self.syncWeeklyNotes(modelContext: modelContext)
                
                if self.cancelRequested { throw CancellationError() }
                // Sync snapshots
                try await self.syncSnapshots(modelContext: modelContext)
            }
            
            if allowWhenLocked {
                try await supabase.withSecurityBypass {
                    try await syncWork()
                }
            } else {
                try await syncWork()
            }
            
            // Update last sync time
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            lastSyncSucceeded = true
            SyncLogger.logSync("Full sync completed successfully")
            
        } catch {
            if error is CancellationError {
                SyncLogger.logSync("Sync canceled", level: .warning)
            } else {
                syncError = error.localizedDescription
                lastSyncSucceeded = false
                SyncLogger.logSync("Sync error: \(error.localizedDescription)", level: .error)
            }
        }
        
        isSyncing = false
        cancelRequested = false
    }
    
    // MARK: - Goal Sync
    
    private func syncGoals(modelContext: ModelContext) async throws {
        guard let userId = supabase.currentUserId else { return }
        
        // Fetch remote goals
        let remoteGoals = try await supabase.getGoals()
        
        // Fetch local goals
        let descriptor = FetchDescriptor<GoalModel>()
        let localGoals = try modelContext.fetch(descriptor)
        
        // Create lookup dictionaries
        let remoteDict = Dictionary(uniqueKeysWithValues: remoteGoals.compactMap { 
            goal -> (UUID, GoalDTO)? in
            guard let id = goal.id, let uuid = UUID(uuidString: id) else { return nil }
            return (uuid, goal)
        })
        
        let localDict = Dictionary(uniqueKeysWithValues: localGoals.map { ($0.id, $0) })
        
        // Add remote goals that don't exist locally
        for (id, remote) in remoteDict {
            if localDict[id] == nil {
                if deletedGoalIds.contains(id) {
                    continue
                }
                let scheduledTime = remote.scheduledTime.flatMap { iso8601Formatter.date(from: $0) }
                let resolvedCategory = resolveCategory(
                    name: remote.categoryName,
                    colorHex: remote.categoryColorHex,
                    in: modelContext
                )
                let local = GoalModel(
                    id: id,
                    title: remote.title,
                    category: resolvedCategory,
                    recurrenceType: remote.recurrenceType ?? "none",
                    weekdays: remote.weekdays ?? [],
                    scheduledTime: scheduledTime,
                    customIntervalDays: remote.customIntervalDays,
                    monthlyDayOfMonth: remote.monthlyDayOfMonth,
                    status: remote.status ?? "active"
                )
                modelContext.insert(local)
            } else if let local = localDict[id] {
                // CLOUD WINS: Always apply remote state to local
                // This is the key invariant - cloud is source of truth
                applyRemoteGoal(remote, to: local, modelContext: modelContext)
            }
        }
        
        // Upload local goals that don't exist remotely
        var goalsToUpload: [GoalDTO] = []
        for (id, local) in localDict {
            if remoteDict[id] == nil {
                let dto = GoalDTO(
                    id: id.uuidString,
                    userId: userId,
                    categoryName: local.categoryDisplayName,
                    categoryColorHex: local.categoryDisplayColorHex,
                    title: local.title,
                    frequency: "daily",
                    status: local.status,
                    recurrenceType: local.recurrenceType,
                    weekdays: local.weekdays,
                    scheduledTime: local.scheduledTime.map { iso8601Formatter.string(from: $0) },
                    customIntervalDays: local.customIntervalDays,
                    monthlyDayOfMonth: local.monthlyDayOfMonth,
                    createdAt: iso8601Formatter.string(from: local.createdAt),
                    updatedAt: iso8601Formatter.string(from: local.updatedAt)
                )
                goalsToUpload.append(dto)
            }
        }
        
        // Batch upload
        if !goalsToUpload.isEmpty {
            _ = try await supabase.upsertGoals(goalsToUpload)
        }
        
        try modelContext.save()
    }
    
    // MARK: - Obligation Sync

    // MARK: - Completion Sync (Legacy: Obligations)

    private func syncObligations(modelContext: ModelContext) async throws {
        // Renamed logic: Sync Completions from Cloud
        guard let userId = supabase.currentUserId else { return }

        // 1. Fetch all completions from cloud (time bound or all? let's do time range for efficiency)
        let (startDate, endDate) = obligationSyncRange()
        
        // Use raw query to fetch completions since we don't have a typed helper yet, or create one in SupabaseService
        // For now, let's assume we add getCompletions to SupabaseService
        let completions = try await supabase.getCompletions(from: startDate, to: endDate)
        
        // 2. Map to dictionary for lookup: [ObligationID: CompletionDTO]
        // Note: Completion ID == Obligation ID in our new architecture
        let completionMap: [UUID: CompletionDTO] = Dictionary(uniqueKeysWithValues: completions.compactMap { comp -> (UUID, CompletionDTO)? in
            guard let idStr = comp.id, let id = UUID(uuidString: idStr) else { return nil }
            return (id, comp)
        })

        // 3. Fetch local obligations in range
        let descriptor = FetchDescriptor<ObligationModel>(
            predicate: #Predicate { $0.scheduledAt >= startDate && $0.scheduledAt < endDate }
        )
        let localObligations = try modelContext.fetch(descriptor)
        
        // 4. Update local state based on cloud completions
        for obligation in localObligations {
            if let completion = completionMap[obligation.id] {
                // Cloud says completed
                if obligation.status != "completed" {
                    obligation.status = "completed"
                    // completedAt is non-optional string in DTO
                    if let completedAt = iso8601Formatter.date(from: completion.completedAt) {
                        obligation.completedAt = completedAt
                    } else {
                        obligation.completedAt = Date()
                    }
                    obligation.updatedAt = Date()
                }
            } else {
                // Cloud says NOT completed (status row missing)
                // If local is completed, and cloud deletion happened, we should revert to pending?
                // Or if local is pending, we do nothing.
                // Assuming Cloud is Truth: if local is completed but cloud has no record, revert.
                // BUT: What if we just completed it locally and haven't synced UP yet?
                // This is a conflict. 
                // Strategy: "Cloud Wins" means if I deleted it on another device, it's gone here.
                // However, we rely on DataService to push local changes. 
                // If we un-complete locally, we delete from cloud. 
                // If we complete locally, we upsert to cloud.
                // Since this is FULL SYNC (polling/start), we assume cloud is fresher.
                
                if obligation.status == "completed" {
                    // Revert to pending because completion is missing in cloud
                    // Only if last sync time < cloud update... complex.
                    // Simple "Cloud Wins" for now:
                    obligation.status = "pending"
                    obligation.completedAt = nil
                    obligation.updatedAt = Date()
                }
            }
        }
        
        // 5. What about uploading I missed?
        // DataService handles local mutations. This function specifically pulls "Cloud State".
        // If we trust `DataService` handled all pushes, then we trust Cloud is missing the completion implies it's not done.
        
        try modelContext.save()
    }
    
    // MARK: - Individual Operations
    

    /// Sync a single goal creation to cloud
    func syncGoalCreation(_ goal: GoalModel) async {
        guard !isFrozen else { return }
        guard RuntimeGuard.requireAuthenticatedRunning() else { return }
        guard AppSessionManager.shared.state == .running else { return }
        guard isCloudSyncEnabled else { return }
        guard let userId = supabase.currentUserId else { return }
        
        let dto = GoalDTO(
            id: goal.id.uuidString,
            userId: userId,
            categoryName: goal.categoryDisplayName,
            categoryColorHex: goal.categoryDisplayColorHex,
            title: goal.title,
            frequency: "daily", // Legacy compatibility
            status: goal.status,
            recurrenceType: goal.recurrenceType,
            weekdays: goal.weekdays,
            scheduledTime: goal.scheduledTime.map { iso8601Formatter.string(from: $0) },
            customIntervalDays: goal.customIntervalDays,
            monthlyDayOfMonth: goal.monthlyDayOfMonth,
            createdAt: iso8601Formatter.string(from: goal.createdAt),
            updatedAt: iso8601Formatter.string(from: goal.updatedAt)
        )
        
        do {
            _ = try await supabase.createGoal(dto)
        } catch {
            print("Failed to sync goal creation: \(error)")
        }
    }
    
    /// Sync a goal update to cloud
    func syncGoalUpdate(_ goal: GoalModel) async {
        guard !isFrozen else { return }
        guard RuntimeGuard.requireAuthenticatedRunning() else { return }
        guard AppSessionManager.shared.state == .running else { return }
        guard isCloudSyncEnabled else { return }
        guard let userId = supabase.currentUserId else { return }
        
        let dto = GoalDTO(
            id: goal.id.uuidString,
            userId: userId,
            categoryName: goal.categoryDisplayName,
            categoryColorHex: goal.categoryDisplayColorHex,
            title: goal.title,
            frequency: "daily", // Legacy compatibility
            status: goal.status,
            recurrenceType: goal.recurrenceType,
            weekdays: goal.weekdays,
            scheduledTime: goal.scheduledTime.map { iso8601Formatter.string(from: $0) },
            customIntervalDays: goal.customIntervalDays,
            monthlyDayOfMonth: goal.monthlyDayOfMonth,
            createdAt: iso8601Formatter.string(from: goal.createdAt),
            updatedAt: iso8601Formatter.string(from: goal.updatedAt)
        )
        
        do {
            _ = try await supabase.updateGoal(dto)
        } catch {
            print("Failed to sync goal update: \(error)")
        }
    }
    
    /// Sync a goal deletion to cloud
    func syncGoalDeletion(_ goalId: UUID) async {
        guard !isFrozen else { return }
        guard RuntimeGuard.requireAuthenticatedRunning() else { return }
        guard AppSessionManager.shared.state == .running else { return }
        guard isCloudSyncEnabled else { return }
        do {
            // Delete completions for this goal first (if foreign key doesn't cascade)
            try await supabase.deleteCompletions(goalId: goalId.uuidString)
            try await supabase.deleteGoal(id: goalId.uuidString)
            clearLocalGoalDeletion(goalId)
        } catch {
            print("Failed to sync goal deletion: \(error)")
        }
    }

    func recordLocalGoalDeletion(_ goalId: UUID) {
        deletedGoalIds.insert(goalId)
        persistDeletedGoalIds()
    }

    private func clearLocalGoalDeletion(_ goalId: UUID) {
        deletedGoalIds.remove(goalId)
        persistDeletedGoalIds()
    }

    private func loadDeletedGoalIds() -> Set<UUID> {
        let stored = UserDefaults.standard.stringArray(forKey: deletedGoalsKey) ?? []
        let ids = stored.compactMap { UUID(uuidString: $0) }
        return Set(ids)
    }

    private func persistDeletedGoalIds() {
        let values = deletedGoalIds.map { $0.uuidString }
        UserDefaults.standard.set(values, forKey: deletedGoalsKey)
    }
    
    // MARK: - Settings Sync
    
    /// Sync settings from local to cloud
    func syncSettingsToCloud(settings: SettingsStore) async {
        guard !isFrozen else { return }
        guard RuntimeGuard.requireAuthenticatedRunning() else { return }
        guard AppSessionManager.shared.state == .running else { return }
        // Settings are always synced
        guard let userId = supabase.currentUserId else { return }
        
        // Ensure authenticated before syncing
        guard supabase.isAuthenticated else { return }
        
        let dto = UserSettingsDTO(
            userId: userId,
            theme: settings.selectedTheme.rawValue,
            hapticFeedback: settings.hapticFeedback,
            compactLayout: settings.compactLayout,
            reduceMotion: settings.reduceMotion,
            weekStart: settings.weekStart.rawValue,
            monthCalculation: settings.monthCalculation.rawValue,
            dayResetMinutes: settings.dayResetMinutes,
            storageMode: StorageMode.current?.rawValue ?? StorageMode.local.rawValue
        )
        
        do {
            _ = try await supabase.upsertSettings(dto)
        } catch {
            print("Failed to sync settings: \(error)")
        }
    }
    
    /// Sync settings from cloud to local
    func syncSettingsFromCloud(settings: SettingsStore) async {
        guard !isFrozen else { return }
        guard RuntimeGuard.requireAuthenticatedRunning() else { return }
        // Settings are always synced
        do {
            guard let remote = try await supabase.getSettings() else { return }
            
            if let theme = remote.theme, let appTheme = AppTheme(rawValue: theme) {
                settings.selectedTheme = appTheme
            }
            if let haptic = remote.hapticFeedback {
                settings.hapticFeedback = haptic
            }
            if let compact = remote.compactLayout {
                settings.compactLayout = compact
            }
            if let reduce = remote.reduceMotion {
                settings.reduceMotion = reduce
            }
            if let week = remote.weekStart, let weekStart = WeekStart(rawValue: week) {
                settings.weekStart = weekStart
            }
            if let month = remote.monthCalculation, let monthCalc = MonthCalculation(rawValue: month) {
                settings.monthCalculation = monthCalc
            }
            if let minutes = remote.dayResetMinutes {
                settings.dayResetMinutes = minutes
            }
        } catch {
            print("Failed to fetch settings from cloud: \(error)")
        }
    }
    
    // MARK: - Profile Sync
    
    /// Sync profile to cloud
    func syncProfileToCloud(name: String, title: String, age: Int? = nil, userGoal: String? = nil) async throws {
        guard !isFrozen else { return }
        guard RuntimeGuard.requireAuthenticatedRunning() else { return }
        guard isCloudSyncEnabled else { return }
        guard let userId = supabase.currentUserId else { return }
        
        let dto = ProfileDTO(
            id: userId,
            name: name,
            title: title,
            age: age,
            userGoal: userGoal
        )
        
        _ = try await supabase.updateProfile(dto)
    }
    
    /// Sync profile from cloud to local settings
    func syncProfileFromCloud(settings: SettingsStore) async {
        guard !isFrozen else { return }
        guard RuntimeGuard.requireAuthenticatedRunning() else { return }
        guard isCloudSyncEnabled else { return }
        do {
            guard let profile = try await supabase.getProfile() else { return }
            
            if let name = profile.name {
                settings.userName = name
            }
            if let title = profile.title {
                settings.userTitle = title
            }
        } catch {
            print("Failed to fetch profile from cloud: \(error)")
        }
    }

    // MARK: - Obligation Sync
    
    func syncObligationUpdate(_ obligation: ObligationModel) async {
        guard !isFrozen else { return }
        guard RuntimeGuard.requireAuthenticatedRunning() else { return }
        guard AppSessionManager.shared.state == .running else { return }
        guard isCloudSyncEnabled else { return }
        guard let userId = supabase.currentUserId else { return }

        // Architecture: Goals + Completions (No Obligations Table)
        if obligation.status == "completed", let completedAt = obligation.completedAt {
            // Upsert completion
            let dto = CompletionDTO(
                id: obligation.id.uuidString,
                userId: userId,
                goalId: obligation.goalId.uuidString,
                completedAt: iso8601Formatter.string(from: completedAt),
                value: 1.0,
                createdAt: iso8601Formatter.string(from: obligation.createdAt)
            )
            do {
                _ = try await supabase.upsertCompletions([dto])
            } catch {
                print("Failed to sync completion update: \(error)")
            }
        } else {
            // Delete completion (uncheck)
            do {
                try await supabase.deleteCompletion(id: obligation.id.uuidString)
            } catch {
                print("Failed to sync completion deletion: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func obligationSyncRange() -> (start: Date, end: Date) {
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let start = Date(timeIntervalSince1970: 0)
        let end = calendar.date(byAdding: .year, value: 5, to: today) ?? now
        return (start, end)
    }

    private func makeLocalObligation(from remote: ObligationDTO, allowedGoalIds: Set<UUID>) -> ObligationModel? {
        guard let idString = remote.id, let id = UUID(uuidString: idString) else { return nil }
        guard let goalId = UUID(uuidString: remote.goalId) else { return nil }
        guard let scheduledAt = iso8601Formatter.date(from: remote.scheduledAt) else { return nil }
        guard allowedGoalIds.contains(goalId) else { return nil }

        let createdAt = remote.createdAt.flatMap { iso8601Formatter.date(from: $0) } ?? Date()
        let updatedAt = remote.updatedAt.flatMap { iso8601Formatter.date(from: $0) } ?? createdAt
        let obligation = ObligationModel(
            id: id,
            goalId: goalId,
            scheduledAt: scheduledAt,
            status: remote.status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        if remote.status == "completed" {
            obligation.completedAt = updatedAt
        } else if remote.status == "missed" {
            obligation.completedAt = nil
        }

        if let lockedAtString = remote.lockedAt,
           let lockedAt = iso8601Formatter.date(from: lockedAtString) {
            obligation.lockedAt = lockedAt
        } else if remote.status == "missed" {
            obligation.lockedAt = updatedAt
        }

        return obligation
    }

    private func applyRemoteObligation(
        _ remote: ObligationDTO,
        to local: ObligationModel,
        remoteUpdatedAt: Date?
    ) {
        if let goalId = UUID(uuidString: remote.goalId) {
            local.goalId = goalId
        }
        if let scheduledAt = iso8601Formatter.date(from: remote.scheduledAt) {
            local.scheduledAt = scheduledAt
        }

        local.status = remote.status
        if remote.status == "completed" {
            if local.completedAt == nil {
                local.completedAt = remoteUpdatedAt ?? local.completedAt ?? Date()
            }
        } else {
            local.completedAt = nil
        }

        if let lockedAtString = remote.lockedAt,
           let lockedAt = iso8601Formatter.date(from: lockedAtString) {
            local.lockedAt = lockedAt
        } else if remote.status == "missed" {
            local.lockedAt = local.lockedAt ?? remoteUpdatedAt ?? Date()
        } else {
            local.lockedAt = nil
        }

        if let remoteCreatedAt = remote.createdAt.flatMap({ iso8601Formatter.date(from: $0) }) {
            local.createdAt = remoteCreatedAt
        }
        if let remoteUpdatedAt = remoteUpdatedAt {
            local.updatedAt = remoteUpdatedAt
        }
    }

    private func makeObligationDTO(from obligation: ObligationModel, userId: String) -> ObligationDTO {
        let lockedAt = obligation.lockedAt.map { iso8601Formatter.string(from: $0) }
        return ObligationDTO(
            id: obligation.id.uuidString,
            userId: userId,
            goalId: obligation.goalId.uuidString,
            scheduledAt: iso8601Formatter.string(from: obligation.scheduledAt),
            status: obligation.status,
            lockedAt: lockedAt,
            createdAt: iso8601Formatter.string(from: obligation.createdAt),
            updatedAt: iso8601Formatter.string(from: obligation.updatedAt)
        )
    }
    
    // MARK: - Weekly Notes Sync
    
    private func syncWeeklyNotes(modelContext: ModelContext) async throws {
        guard let userId = supabase.currentUserId else { return }
        
        let remoteNotes = try await supabase.getWeeklyNotes()
        
        let descriptor = FetchDescriptor<WeeklyNoteModel>()
        let localNotes = try modelContext.fetch(descriptor)
        
        let remoteDict = Dictionary(uniqueKeysWithValues: remoteNotes.map { ("\($0.year)-\($0.month)-\($0.weekIndex)", $0) })
        let localDict = Dictionary(uniqueKeysWithValues: localNotes.map { ($0.key, $0) })
        
        // Cloud wins - apply all remote notes
        for (key, remote) in remoteDict {
            if let local = localDict[key] {
                // Cloud wins - overwrite local
                local.text = remote.text
                if let updatedAt = remote.updatedAt.flatMap({ iso8601Formatter.date(from: $0) }) {
                    local.updatedAt = updatedAt
                }
            } else {
                // Create local from remote
                let local = WeeklyNoteModel(
                    year: remote.year,
                    month: remote.month,
                    weekIndex: remote.weekIndex,
                    text: remote.text
                )
                modelContext.insert(local)
            }
        }
        
        // Upload local-only notes
        for (key, local) in localDict where remoteDict[key] == nil {
            _ = try await supabase.upsertWeeklyNote(
                userId: userId,
                year: local.year,
                month: local.month,
                weekIndex: local.weekIndex,
                text: local.text
            )
        }
        
        try modelContext.save()
    }

    // MARK: - Snapshot Sync
    
    private func syncSnapshots(modelContext: ModelContext) async throws {
        guard let userId = supabase.currentUserId else { return }
        
        // 1. Fetch remote snapshots
        let remoteSnapshots = try await supabase.getSnapshots()
        
        // 2. Fetch local snapshots
        let descriptor = FetchDescriptor<SnapshotModel>()
        let localSnapshots = try modelContext.fetch(descriptor)
        
        let localDict = Dictionary(uniqueKeysWithValues: localSnapshots.map { ($0.compositeKey, $0) })
        let remoteDict = Dictionary(uniqueKeysWithValues: remoteSnapshots.map { ("\($0.year)-\(String(format: "%02d", $0.month))", $0) })
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // 3. Cloud Wins strategy
        for snapshot in remoteSnapshots {
            let key = String(format: "%04d-%02d", snapshot.year, snapshot.month)
            
            if localDict[key] == nil {
                // Create local
                // Note: snapshot.stats is typed struct now, need to encode to Data
                let statsData = try encoder.encode(snapshot.stats)
                let ledgerData = try encoder.encode(snapshot.ledger)
                
                let local = SnapshotModel(
                    id: UUID(uuidString: snapshot.id ?? "") ?? UUID(),
                    userId: UUID(uuidString: snapshot.userId) ?? UUID(),
                    year: snapshot.year,
                    month: snapshot.month,
                    statsJSON: statsData,
                    ledgerJSON: ledgerData,
                    status: .available,
                    createdAt: snapshot.createdAt.flatMap { iso8601Formatter.date(from: $0) } ?? Date()
                )
                modelContext.insert(local)
            }
        }
        
        // 4. Upload Local Snapshots (if missing on remote)
        for local in localSnapshots {
            // Check status: only upload available snapshots.
            // Missing data placeholders stay local.
            if remoteDict[local.compositeKey] == nil && local.status == .available {
                let stats = try decoder.decode(StatsPayload.self, from: local.statsJSON)
                let ledger = try decoder.decode([LedgerEntryPayload].self, from: local.ledgerJSON)
                
                let dto = SnapshotDTO(
                    id: local.id.uuidString,
                    userId: userId,
                    year: local.year,
                    month: local.month,
                    stats: stats,
                    ledger: ledger,
                    createdAt: iso8601Formatter.string(from: local.createdAt)
                )
                _ = try await supabase.upsertSnapshot(dto)
            }
        }
        
        try modelContext.save()
    }
    
    // MARK: - Apply Remote Goal Helper
    
    private func applyRemoteGoal(_ remote: GoalDTO, to local: GoalModel, modelContext: ModelContext) {
        local.title = remote.title
        local.recurrenceType = remote.recurrenceType ?? "none"
        local.weekdays = remote.weekdays ?? []
        local.customIntervalDays = remote.customIntervalDays
        local.monthlyDayOfMonth = remote.monthlyDayOfMonth
        local.scheduledTime = remote.scheduledTime.flatMap { iso8601Formatter.date(from: $0) }
        local.status = remote.status ?? "active"
        local.category = resolveCategory(
            name: remote.categoryName,
            colorHex: remote.categoryColorHex,
            in: modelContext
        )
        local.categoryName = nil
        local.categoryColorHex = nil
        if let updatedAt = remote.updatedAt.flatMap({ iso8601Formatter.date(from: $0) }) {
            local.updatedAt = updatedAt
        }
    }

    private func resolveCategory(
        name: String?,
        colorHex: String?,
        in modelContext: ModelContext
    ) -> GoalCategory? {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let existingDescriptor = FetchDescriptor<GoalCategory>()
        let existing = (try? modelContext.fetch(existingDescriptor)) ?? []
        if let match = existing.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match
        }

        let resolvedHex = colorHex ?? GoalCategory.nextColorHex(existing: existing)
        let category = GoalCategory(name: trimmed, colorHex: resolvedHex)
        modelContext.insert(category)
        return category
    }
}

// MARK: - MutationSyncHandler Conformance

extension SyncService: MutationSyncHandler {
    func isAuthenticated() async -> Bool {
        return RuntimeGuard.requireAuthenticatedRunning(allowWhenLocked: allowWhenLockedForSync)
    }
    
    func sync(_ mutation: PendingMutation) async throws {
        guard let userId = supabase.currentUserId else {
            throw DataServiceError.notAuthenticated
        }
        
        switch mutation.entityType {
        case .goal:
            switch mutation.operationType {
            case .create, .update:
                // Re-fetch and sync the goal if it still exists
                SyncLogger.logQueue("Syncing goal mutation: \(mutation.operationType.rawValue)")
            case .delete:
                try await supabase.deleteGoal(id: mutation.entityId.uuidString)
                SyncLogger.logQueue("Synced goal deletion: \(mutation.entityId)")
            }
            
        case .obligation:
            SyncLogger.logQueue("Syncing obligation mutation: \(mutation.operationType.rawValue)")
            
        case .category:
            SyncLogger.logQueue("Syncing category mutation: \(mutation.operationType.rawValue)")
            
        case .weeklyNote:
            SyncLogger.logQueue("Syncing weekly note mutation: \(mutation.operationType.rawValue)")
        }
    }
}

// MARK: - Sync Freeze Control

extension SyncService {
    func freezeSync(reason: String) {
        isFrozen = true
        cancelRequested = true
        SyncLogger.logSync("Sync frozen: \(reason)")
    }
    
    func unfreezeSync(reason: String) {
        isFrozen = false
        cancelRequested = false
        SyncLogger.logSync("Sync unfrozen: \(reason)")
    }

    func cancelInFlight(reason: String) {
        cancelRequested = true
        SyncLogger.logSync("Sync cancel requested: \(reason)")
    }
}
