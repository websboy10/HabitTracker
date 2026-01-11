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
    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private init() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
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
            
            // Sync completions
            try await syncCompletions(modelContext: modelContext)
            
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
    
    // MARK: - Completion Sync
    
    private func syncCompletions(modelContext: ModelContext) async throws {
        guard let userId = supabase.currentUserId else { return }
        
        // For completions, we do a simpler approach:
        // Get completions from the last 30 days and merge
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let endDate = Date()
        
        let remoteCompletions = try await supabase.getCompletions(from: startDate, to: endDate)
        
        // Fetch local completions for the same period
        let descriptor = FetchDescriptor<CompletionModel>(
            predicate: #Predicate { $0.completedAt >= startDate && $0.completedAt <= endDate }
        )
        let localCompletions = try modelContext.fetch(descriptor)
        
        // Create lookup dictionaries
        let remoteDict = Dictionary(uniqueKeysWithValues: remoteCompletions.compactMap { 
            completion -> (UUID, CompletionDTO)? in
            guard let id = completion.id, let uuid = UUID(uuidString: id) else { return nil }
            return (uuid, completion)
        })
        
        let localDict = Dictionary(uniqueKeysWithValues: localCompletions.map { ($0.id, $0) })
        
        // Add remote completions that don't exist locally
        for (id, remote) in remoteDict {
            if localDict[id] == nil {
                guard let goalId = UUID(uuidString: remote.goalId),
                      let completedAt = iso8601Formatter.date(from: remote.completedAt) else { continue }
                
                let local = CompletionModel(
                    id: id,
                    goalId: goalId,
                    completedAt: completedAt,
                    value: remote.value ?? 1.0
                )
                modelContext.insert(local)
            }
        }
        
        // Upload local completions that don't exist remotely
        var completionsToUpload: [CompletionDTO] = []
        for (id, local) in localDict {
            if remoteDict[id] == nil {
                let dto = CompletionDTO(
                    id: id.uuidString,
                    userId: userId,
                    goalId: local.goalId.uuidString,
                    completedAt: iso8601Formatter.string(from: local.completedAt),
                    value: local.value
                )
                completionsToUpload.append(dto)
            }
        }
        
        // Batch upload
        if !completionsToUpload.isEmpty {
            _ = try await supabase.upsertCompletions(completionsToUpload)
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
            try await supabase.deleteGoal(id: goalId.uuidString)
        } catch {
            print("Failed to sync goal deletion: \(error)")
        }
    }
    
    /// Sync a completion creation to cloud
    func syncCompletionCreation(_ completion: CompletionModel) async {
        guard AppSessionManager.shared.state == .running else { return }
        guard isCloudSyncEnabled else { return }
        guard let userId = supabase.currentUserId else { return }
        
        let dto = CompletionDTO(
            id: completion.id.uuidString,
            userId: userId,
            goalId: completion.goalId.uuidString,
            completedAt: iso8601Formatter.string(from: completion.completedAt),
            value: completion.value
        )
        
        do {
            _ = try await supabase.createCompletion(dto)
        } catch {
            print("Failed to sync completion creation: \(error)")
        }
    }
    
    /// Sync a completion deletion to cloud
    func syncCompletionDeletion(_ completionId: UUID) async {
        guard AppSessionManager.shared.state == .running else { return }
        guard isCloudSyncEnabled else { return }
        do {
            try await supabase.deleteCompletion(id: completionId.uuidString)
        } catch {
            print("Failed to sync completion deletion: \(error)")
        }
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
        // TODO: Implement obligation sync logic
        print("Syncing obligation update: \(obligation.id)")
    }
}
