import Foundation

// MARK: - Entity Types

/// Entity types that can be mutated
enum EntityType: String, Codable {
    case goal
    case obligation
    case category
    case weeklyNote
}

// MARK: - Operation Types

/// CRUD operation types
enum OperationType: String, Codable {
    case create
    case update
    case delete
}

// MARK: - Pending Mutation

/// Represents a mutation waiting to be synced to cloud
struct PendingMutation: Codable, Identifiable {
    let id: UUID
    let entityType: EntityType
    let operationType: OperationType
    let entityId: UUID
    let payload: Data?  // Encoded DTO for create/update
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        entityType: EntityType,
        operationType: OperationType,
        entityId: UUID,
        payload: Data? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.entityType = entityType
        self.operationType = operationType
        self.entityId = entityId
        self.payload = payload
        self.timestamp = timestamp
    }
}

// MARK: - Mutation Queue

/// Durable offline mutation queue.
/// Persists mutations to disk and replays them when connectivity is restored.
///
/// **Invariants:**
/// - Mutations are persisted immediately upon enqueue
/// - Replay occurs in FIFO order
/// - Replay is aborted if auth is invalid
/// - Queue is cleared after successful full replay
@MainActor
final class MutationQueue: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = MutationQueue()
    
    // MARK: - State
    
    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var isReplaying: Bool = false
    
    // MARK: - Storage
    
    private let persistenceKey = "pendingMutations"
    private var mutations: [PendingMutation] = []
    
    // MARK: - Dependencies
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Init
    
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Queue Operations
    
    /// Enqueues a mutation for later sync.
    /// Mutation is persisted immediately.
    func enqueue(_ mutation: PendingMutation) {
        mutations.append(mutation)
        saveToDisk()
        pendingCount = mutations.count
        SyncLogger.logQueue("Enqueued \(mutation.operationType.rawValue) for \(mutation.entityType.rawValue) (\(mutation.entityId))")
    }
    
    /// Creates and enqueues a mutation
    func enqueue(
        entityType: EntityType,
        operationType: OperationType,
        entityId: UUID,
        payload: Data? = nil
    ) {
        let mutation = PendingMutation(
            entityType: entityType,
            operationType: operationType,
            entityId: entityId,
            payload: payload
        )
        enqueue(mutation)
    }
    
    /// Returns all pending mutations in FIFO order
    var pending: [PendingMutation] {
        mutations
    }
    
    /// Returns true if there are pending mutations
    var hasPending: Bool {
        !mutations.isEmpty
    }
    
    /// Removes a specific mutation (after successful sync)
    func remove(_ mutationId: UUID) {
        mutations.removeAll { $0.id == mutationId }
        saveToDisk()
        pendingCount = mutations.count
    }
    
    /// Clears all pending mutations
    func clear() {
        mutations.removeAll()
        saveToDisk()
        pendingCount = 0
        SyncLogger.logQueue("Queue cleared")
    }
    
    // MARK: - Replay
    
    /// Replays all pending mutations in order.
    /// Requires valid auth and cloud mode.
    /// Returns number of successfully replayed mutations.
    @discardableResult
    func replay(using syncHandler: MutationSyncHandler) async throws -> Int {
        guard !mutations.isEmpty else { return 0 }
        guard StorageMode.isCloud else {
            SyncLogger.logQueue("Replay skipped - not in cloud mode", level: .warning)
            return 0
        }
        
        // Validate auth
        guard await syncHandler.isAuthenticated() else {
            SyncLogger.logQueue("Replay aborted - auth invalid", level: .error)
            throw MutationQueueError.authInvalid
        }
        
        isReplaying = true
        defer { isReplaying = false }
        
        SyncLogger.logQueue("Starting replay of \(mutations.count) mutations")
        
        var successCount = 0
        var failedMutations: [PendingMutation] = []
        
        for mutation in mutations {
            do {
                try await syncHandler.sync(mutation)
                successCount += 1
                SyncLogger.logQueue("Replayed \(mutation.operationType.rawValue) for \(mutation.entityType.rawValue)")
            } catch {
                SyncLogger.logQueue("Failed to replay mutation: \(error.localizedDescription)", level: .error)
                failedMutations.append(mutation)
            }
        }
        
        // Keep only failed mutations
        mutations = failedMutations
        saveToDisk()
        pendingCount = mutations.count
        
        SyncLogger.logQueue("Replay complete: \(successCount) succeeded, \(failedMutations.count) failed")
        
        return successCount
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        do {
            let data = try encoder.encode(mutations)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            SyncLogger.logQueue("Failed to save queue: \(error.localizedDescription)", level: .error)
        }
    }
    
    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        do {
            mutations = try decoder.decode([PendingMutation].self, from: data)
            pendingCount = mutations.count
            if !mutations.isEmpty {
                SyncLogger.logQueue("Loaded \(mutations.count) pending mutations from disk")
            }
        } catch {
            SyncLogger.logQueue("Failed to load queue: \(error.localizedDescription)", level: .error)
            mutations = []
        }
    }
}

// MARK: - Errors

enum MutationQueueError: Error, LocalizedError {
    case authInvalid
    case replayFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .authInvalid:
            return "Cannot replay mutations - authentication invalid"
        case .replayFailed(let reason):
            return "Mutation replay failed: \(reason)"
        }
    }
}

// MARK: - Sync Handler Protocol

/// Protocol for handling mutation sync operations
protocol MutationSyncHandler {
    func isAuthenticated() async -> Bool
    func sync(_ mutation: PendingMutation) async throws
}
