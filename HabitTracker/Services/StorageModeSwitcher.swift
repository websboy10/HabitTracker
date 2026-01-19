import Foundation
import SwiftData

// MARK: - Storage Mode Switcher

/// Handles atomic storage mode transitions.
/// Blocks user interaction during transition.
///
/// **Invariants:**
/// - LOCAL → CLOUD: Upload all data first, validate, then switch
/// - CLOUD → LOCAL: Stop cloud writes immediately
/// - Transition is blocking and atomic
@MainActor
final class StorageModeSwitcher: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = StorageModeSwitcher()
    
    // MARK: - State
    
    @Published private(set) var isTransitioning: Bool = false
    @Published private(set) var transitionProgress: String = ""
    @Published var transitionError: String?
    
    // MARK: - Dependencies
    
    private let supabase = SupabaseService.shared
    
    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private init() {}
    
    // MARK: - Switch to Cloud
    
    /// Switches from LOCAL to CLOUD mode.
    /// Uploads all local data before switching.
    func switchToCloud(modelContext: ModelContext) async throws {
        guard StorageMode.current == .local else {
            throw StorageModeError.transitionFailed("Already in cloud mode")
        }
        
        guard supabase.isAuthenticated, let userId = supabase.currentUserId else {
            throw StorageModeError.transitionFailed("Not authenticated")
        }
        
        isTransitioning = true
        transitionError = nil
        defer { isTransitioning = false }
        
        SyncLogger.logStorage("Starting transition: LOCAL → CLOUD")
        
        do {
            // 1. Upload goals
            transitionProgress = "Uploading goals..."
            try await uploadGoals(modelContext: modelContext, userId: userId)

            // 2. Upload obligations
            transitionProgress = "Uploading obligations..."
            try await uploadObligations(modelContext: modelContext, userId: userId)

            // 3. Upload weekly notes
            transitionProgress = "Uploading notes..."
            try await uploadWeeklyNotes(modelContext: modelContext, userId: userId)

            // 4. Persist new storage mode ONLY after success
            transitionProgress = "Finalizing..."
            StorageMode.persist(.cloud)

            // 5. Update settings in cloud
            try await updateCloudSettings(userId: userId)
            
            transitionProgress = ""
            SyncLogger.logStorage("Transition complete: LOCAL → CLOUD")
            
        } catch {
            transitionError = error.localizedDescription
            SyncLogger.logStorage("Transition failed: \(error.localizedDescription)", level: .error)
            throw error
        }
    }
    
    // MARK: - Switch to Local
    
    /// Switches from CLOUD to LOCAL mode.
    /// Stops all cloud writes immediately.
    func switchToLocal() async {
        guard StorageMode.current == .cloud else { return }
        
        isTransitioning = true
        transitionError = nil
        defer { isTransitioning = false }
        
        SyncLogger.logStorage("Starting transition: CLOUD → LOCAL")
        
        // 1. Persist new storage mode immediately
        StorageMode.persist(.local)
        
        // 2. Clear mutation queue (no need to sync anymore)
        MutationQueue.shared.clear()
        
        // 3. Update settings in cloud (fire and forget)
        if let userId = supabase.currentUserId {
            Task {
                try? await updateCloudSettings(userId: userId)
            }
        }
        
        SyncLogger.logStorage("Transition complete: CLOUD → LOCAL")
    }
    
    // MARK: - Private Upload Methods

    private func uploadGoals(modelContext: ModelContext, userId: String) async throws {
        let descriptor = FetchDescriptor<GoalModel>()
        let goals = try modelContext.fetch(descriptor)

        var dtos: [GoalDTO] = []
        for goal in goals {
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
            dtos.append(dto)
        }

        if !dtos.isEmpty {
            _ = try await supabase.upsertGoals(dtos)
        }

        SyncLogger.logStorage("Uploaded \(goals.count) goals")
    }
    
    private func uploadObligations(modelContext: ModelContext, userId: String) async throws {
        let descriptor = FetchDescriptor<ObligationModel>()
        let obligations = try modelContext.fetch(descriptor)
        
        var dtos: [ObligationDTO] = []
        for obligation in obligations {
            let dto = ObligationDTO(
                id: obligation.id.uuidString,
                userId: userId,
                goalId: obligation.goalId.uuidString,
                scheduledAt: iso8601Formatter.string(from: obligation.scheduledAt),
                status: obligation.status,
                lockedAt: obligation.lockedAt.map { iso8601Formatter.string(from: $0) },
                createdAt: iso8601Formatter.string(from: obligation.createdAt),
                updatedAt: iso8601Formatter.string(from: obligation.updatedAt)
            )
            dtos.append(dto)
        }
        
        // Batch upload in chunks
        let chunkSize = 100
        for chunk in stride(from: 0, to: dtos.count, by: chunkSize) {
            let end = min(chunk + chunkSize, dtos.count)
            let batch = Array(dtos[chunk..<end])
            _ = try await supabase.upsertObligations(batch)
        }
        
        SyncLogger.logStorage("Uploaded \(obligations.count) obligations")
    }
    
    private func uploadWeeklyNotes(modelContext: ModelContext, userId: String) async throws {
        let descriptor = FetchDescriptor<WeeklyNoteModel>()
        let notes = try modelContext.fetch(descriptor)
        
        for note in notes {
            _ = try await supabase.upsertWeeklyNote(
                userId: userId,
                year: note.year,
                month: note.month,
                weekIndex: note.weekIndex,
                text: note.text
            )
        }
        
        SyncLogger.logStorage("Uploaded \(notes.count) weekly notes")
    }
    
    private func updateCloudSettings(userId: String) async throws {
        let settings = SettingsStore.shared
        let dto = UserSettingsDTO(
            userId: userId,
            theme: settings.selectedTheme.rawValue,
            hapticFeedback: settings.hapticFeedback,
            compactLayout: settings.compactLayout,
            reduceMotion: settings.reduceMotion,
            weekStart: settings.weekStart.rawValue,
            monthCalculation: settings.monthCalculation.rawValue,
            dayResetMinutes: settings.dayResetMinutes,
            storageMode: StorageMode.current?.rawValue ?? "local"
        )
        _ = try await supabase.upsertSettings(dto)
    }
}
