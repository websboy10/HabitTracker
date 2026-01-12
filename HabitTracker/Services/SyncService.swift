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
    
    // MARK: - Storage Mode
    
    /// Returns true if user has chosen cloud storage mode in onboarding
    var isCloudSyncEnabled: Bool {
        StorageMode.current == .cloud
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
    func performFullSync(modelContext: ModelContext) async {
        // Only sync if user chose cloud storage mode
        guard isCloudSyncEnabled else { return }
        
        // Ensure authoritative phase: Allow .synchronizing or .running
        let state = AppSessionManager.shared.state
        guard state == .synchronizing || state == .running else { return }
        
        guard supabase.isAuthenticated else {
            syncError = "Not authenticated"
            return
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Sync categories first (goals depend on them)
            try await syncCategories(modelContext: modelContext)
            
            // Sync goals
            try await syncGoals(modelContext: modelContext)
            
            // Sync obligations
            try await syncObligations(modelContext: modelContext)
            
            // Update last sync time
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            
        } catch {
            syncError = error.localizedDescription
            print("Sync error: \(error)")
        }
        
        isSyncing = false
    }
    
    // MARK: - Category Sync
    
    private func syncCategories(modelContext: ModelContext) async throws {
        guard let userId = supabase.currentUserId else { return }
        
        // Fetch remote categories
        let remoteCategories = try await supabase.getCategories()
        
        // Fetch local categories
        let descriptor = FetchDescriptor<CategoryModel>()
        let localCategories = try modelContext.fetch(descriptor)
        
        // Create lookup dictionaries
        let remoteDict = Dictionary(uniqueKeysWithValues: remoteCategories.compactMap { 
            category -> (UUID, CategoryDTO)? in
            guard let id = category.id, let uuid = UUID(uuidString: id) else { return nil }
            return (uuid, category)
        })
        
        let localDict = Dictionary(uniqueKeysWithValues: localCategories.map { ($0.id, $0) })
        
        // Add remote categories that don't exist locally
        for (id, remote) in remoteDict {
            if localDict[id] == nil {
                let local = CategoryModel(
                    id: id,
                    name: remote.name,
                    colorHex: remote.colorHex,
                    isDefault: remote.isDefault ?? false,
                    sortOrder: remote.sortOrder ?? 0
                )
                modelContext.insert(local)
            }
        }
        
        // Upload local categories that don't exist remotely
        var categoriesToUpload: [CategoryDTO] = []
        for (id, local) in localDict {
            if remoteDict[id] == nil {
                let dto = CategoryDTO(
                    id: id.uuidString,
                    userId: userId,
                    name: local.name,
                    colorHex: local.colorHex,
                    isDefault: local.isDefault,
                    sortOrder: local.sortOrder
                )
                categoriesToUpload.append(dto)
            }
        }
        
        // Batch upload
        for category in categoriesToUpload {
            _ = try await supabase.createCategory(category)
        }
        
        try modelContext.save()
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
                let categoryId = remote.categoryId.flatMap { UUID(uuidString: $0) } ?? UUID()
                let scheduledTime = remote.scheduledTime.flatMap { iso8601Formatter.date(from: $0) }
                let local = GoalModel(
                    id: id,
                    title: remote.title,
                    categoryId: categoryId,
                    recurrenceType: remote.recurrenceType ?? "none",
                    weekdays: remote.weekdays ?? [],
                    scheduledTime: scheduledTime,
                    customIntervalDays: remote.customIntervalDays,
                    monthlyDayOfMonth: remote.monthlyDayOfMonth,
                    status: remote.status ?? "active"
                )
                modelContext.insert(local)
            } else if let local = localDict[id] {
                // Update local with remote data if remote is newer
                if let remoteUpdated = remote.updatedAt,
                   let remoteDate = iso8601Formatter.date(from: remoteUpdated),
                   remoteDate > local.updatedAt {
                    local.title = remote.title
                    local.recurrenceType = remote.recurrenceType ?? "none"
                    local.weekdays = remote.weekdays ?? []
                    local.customIntervalDays = remote.customIntervalDays
                    local.monthlyDayOfMonth = remote.monthlyDayOfMonth
                    local.scheduledTime = remote.scheduledTime.flatMap { iso8601Formatter.date(from: $0) }
                    local.status = remote.status ?? "active"
                    if let catId = remote.categoryId, let catUUID = UUID(uuidString: catId) {
                        local.categoryId = catUUID
                    }
                }
            }
        }
        
        // Upload local goals that don't exist remotely
        var goalsToUpload: [GoalDTO] = []
        for (id, local) in localDict {
            if remoteDict[id] == nil {
                let dto = GoalDTO(
                    id: id.uuidString,
                    userId: userId,
                    categoryId: local.categoryId.uuidString,
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

    private func syncObligations(modelContext: ModelContext) async throws {
        guard let userId = supabase.currentUserId else { return }

        let (startDate, endDate) = obligationSyncRange()
        let remoteObligations = try await supabase.getObligations(from: startDate, to: endDate)

        let descriptor = FetchDescriptor<ObligationModel>(
            predicate: #Predicate { $0.scheduledAt >= startDate && $0.scheduledAt < endDate }
        )
        let localObligations = try modelContext.fetch(descriptor)

        let goalDescriptor = FetchDescriptor<GoalModel>()
        let localGoals = try modelContext.fetch(goalDescriptor)
        let localGoalIds = Set(localGoals.map { $0.id })

        let remoteDict = Dictionary(uniqueKeysWithValues: remoteObligations.compactMap {
            obligation -> (UUID, ObligationDTO)? in
            guard let id = obligation.id, let uuid = UUID(uuidString: id) else { return nil }
            return (uuid, obligation)
        })
        let localDict = Dictionary(uniqueKeysWithValues: localObligations.map { ($0.id, $0) })

        var obligationsToUpload: [ObligationDTO] = []

        for (id, remote) in remoteDict {
            if let local = localDict[id] {
                let remoteUpdatedAt = remote.updatedAt.flatMap { iso8601Formatter.date(from: $0) }
                let remoteIsMissed = remote.status == "missed"

                if local.isMissed && !remoteIsMissed {
                    obligationsToUpload.append(makeObligationDTO(from: local, userId: userId))
                    continue
                }

                if remoteIsMissed && !local.isMissed {
                    applyRemoteObligation(remote, to: local, remoteUpdatedAt: remoteUpdatedAt)
                    continue
                }

                if let remoteUpdatedAt, remoteUpdatedAt > local.updatedAt {
                    applyRemoteObligation(remote, to: local, remoteUpdatedAt: remoteUpdatedAt)
                } else if let remoteUpdatedAt {
                    if local.updatedAt > remoteUpdatedAt {
                        obligationsToUpload.append(makeObligationDTO(from: local, userId: userId))
                    }
                } else {
                    obligationsToUpload.append(makeObligationDTO(from: local, userId: userId))
                }
            } else if let local = makeLocalObligation(from: remote, allowedGoalIds: localGoalIds) {
                modelContext.insert(local)
            }
        }

        for (id, local) in localDict where remoteDict[id] == nil {
            obligationsToUpload.append(makeObligationDTO(from: local, userId: userId))
        }

        if !obligationsToUpload.isEmpty {
            _ = try await supabase.upsertObligations(obligationsToUpload)
        }

        try modelContext.save()
    }
    
    // MARK: - Individual Operations
    

    
    /// Sync a single category creation to cloud
    func syncCategoryCreation(_ category: CategoryModel) async {
        guard AppSessionManager.shared.state == .running else { return }
        guard isCloudSyncEnabled else { return }
        guard let userId = supabase.currentUserId else { return }
        
        let dto = CategoryDTO(
            id: category.id.uuidString,
            userId: userId,
            name: category.name,
            colorHex: category.colorHex,
            isDefault: category.isDefault,
            sortOrder: category.sortOrder
        )
        
        do {
            _ = try await supabase.createCategory(dto)
        } catch {
            print("Failed to sync category creation: \(error)")
        }
    }
    
    /// Sync a single goal creation to cloud
    func syncGoalCreation(_ goal: GoalModel) async {
        guard AppSessionManager.shared.state == .running else { return }
        guard isCloudSyncEnabled else { return }
        guard let userId = supabase.currentUserId else { return }
        
        let dto = GoalDTO(
            id: goal.id.uuidString,
            userId: userId,
            categoryId: goal.categoryId.uuidString,
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
        guard AppSessionManager.shared.state == .running else { return }
        guard isCloudSyncEnabled else { return }
        guard let userId = supabase.currentUserId else { return }
        
        let dto = GoalDTO(
            id: goal.id.uuidString,
            userId: userId,
            categoryId: goal.categoryId.uuidString,
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
        guard AppSessionManager.shared.state == .running else { return }
        guard isCloudSyncEnabled else { return }
        do {
            try await supabase.deleteObligations(goalId: goalId.uuidString)
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
        guard AppSessionManager.shared.state == .running else { return }
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
        guard AppSessionManager.shared.state == .running else { return }
        guard isCloudSyncEnabled else { return }
        guard let userId = supabase.currentUserId else { return }

        let dto = makeObligationDTO(from: obligation, userId: userId)
        do {
            _ = try await supabase.upsertObligations([dto])
        } catch {
            print("Failed to sync obligation update: \(error)")
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
}
