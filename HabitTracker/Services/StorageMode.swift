import Foundation

// MARK: - Storage Mode

/// Defines the authoritative storage mode for the app.
/// This is the SINGLE SOURCE OF TRUTH for where data is persisted.
///
/// **Invariants:**
/// - Exactly one storage mode is active at all times
/// - Storage mode is resolved before any data operation
/// - CLOUD mode: Supabase is source of truth for all non-auth data
/// - LOCAL mode: Supabase is auth-only, no user data written
/// - Switching is explicit, user-initiated, and atomic
enum StorageMode: String, CaseIterable, Codable {
    case cloud = "Cloud"
    case local = "Local Only"
    
    // MARK: - Persistence Key
    
    private static let persistenceKey = "storageMode"
    
    // MARK: - Current Mode
    
    /// Returns the current persisted storage mode.
    /// Returns nil if not yet set (onboarding incomplete).
    /// Thread-safe read from UserDefaults.
    static var current: StorageMode? {
        guard let raw = UserDefaults.standard.string(forKey: persistenceKey) else {
            return nil
        }
        // Handle legacy values for robustness
        if raw.lowercased() == "cloud" || raw == StorageMode.cloud.rawValue {
            return .cloud
        }
        if raw.lowercased().contains("local") || raw == StorageMode.local.rawValue {
            return .local
        }
        return nil
    }
    
    /// Returns true if cloud sync is enabled
    static var isCloud: Bool {
        current == .cloud
    }
    
    /// Returns true if local-only mode is active
    static var isLocal: Bool {
        current == .local
    }
    
    // MARK: - Persistence
    
    /// Persists storage mode to UserDefaults.
    /// This is the ONLY way to change storage mode.
    static func persist(_ mode: StorageMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: persistenceKey)
        SyncLogger.log("Storage mode changed to: \(mode.rawValue)", category: .storage)
    }
    
    /// Clears persisted storage mode (used during logout/reset)
    static func clear() {
        UserDefaults.standard.removeObject(forKey: persistenceKey)
        SyncLogger.log("Storage mode cleared", category: .storage)
    }
    
    // MARK: - Resolution
    
    /// Resolves the current storage mode at app launch.
    /// Must be called before initializing any data models.
    /// Returns the resolved mode or nil if onboarding is required.
    @discardableResult
    static func resolve() -> StorageMode? {
        let mode = current
        if let mode = mode {
            SyncLogger.log("Storage mode resolved: \(mode.rawValue)", category: .storage)
        } else {
            SyncLogger.log("Storage mode not set - onboarding required", category: .storage, level: .warning)
        }
        return mode
    }
    
    // MARK: - Validation
    
    /// Ensures a valid storage mode is set. Throws if not.
    /// Use this before any data operation.
    static func ensureResolved() throws {
        guard current != nil else {
            throw StorageModeError.notResolved
        }
    }
}

// MARK: - Errors

enum StorageModeError: Error, LocalizedError {
    case notResolved
    case transitionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notResolved:
            return "Storage mode not resolved. Complete onboarding first."
        case .transitionFailed(let reason):
            return "Storage mode transition failed: \(reason)"
        }
    }
}
