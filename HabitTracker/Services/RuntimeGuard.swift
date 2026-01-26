import Foundation

// MARK: - Runtime Guard

/// Central utility for runtime invariant enforcement.
/// Differentiates behavior between Debug and Production builds.
///
/// **Invariants:**
/// - Debug: Fail fast and loud (assertions/fatal errors)
/// - Production: Block operation, transition to safe state, log violation
/// - Never allow silent corruption or undefined state
enum RuntimeGuard {
    
    // MARK: - Build Configuration
    
    /// Returns true if running in DEBUG build
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Auth Guards
    
    /// Asserts that user is authenticated before protected operations.
    /// Debug: Fatal error. Production: Logs and returns false.
    @MainActor
    @discardableResult
    static func requireAuth(
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> Bool {
        let isAuthenticated = AuthEngine.shared.isAuthenticated
        
        if !isAuthenticated {
            let context = "\(file):\(line) in \(function)"
            SyncLogger.log("GUARD VIOLATION: Auth required but not authenticated", category: .auth, level: .error)
            
            #if DEBUG
            fatalError("RuntimeGuard.requireAuth failed at \(context)")
            #else
            // Production: Log and block operation
            SyncLogger.log("Auth guard blocked operation at \(context)", category: .auth, level: .error)
            return false
            #endif
        }
        
        return true
    }
    
    /// Asserts valid auth state (not invalid or authenticating mid-operation).
    @MainActor
    @discardableResult
    static func requireValidAuthState(
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> Bool {
        let state = AuthEngine.shared.state
        
        guard state == .authenticated else {
            let context = "\(file):\(line) in \(function)"
            SyncLogger.log("GUARD VIOLATION: Valid auth state required, got \(state.rawValue)", category: .auth, level: .error)
            
            #if DEBUG
            fatalError("RuntimeGuard.requireValidAuthState failed at \(context): state=\(state.rawValue)")
            #else
            return false
            #endif
        }
        
        return true
    }

    /// Requires authenticated auth state AND lifecycle running.
    /// Optionally allows operations when the AppSessionManager is security-locked.
    @MainActor
    @discardableResult
    static func requireAuthenticatedRunning(
        allowWhenLocked: Bool = false,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> Bool {
        guard AuthEngine.shared.state == .authenticated else {
            let context = "\(file):\(line) in \(function)"
            SyncLogger.log("GUARD VIOLATION: Authenticated state required", category: .auth, level: .error)
            
            #if DEBUG
            fatalError("RuntimeGuard.requireAuthenticatedRunning failed at \(context): auth=\(AuthEngine.shared.state.rawValue)")
            #else
            return false
            #endif
        }
        
        guard AppSessionManager.shared.state == .running else {
            let context = "\(file):\(line) in \(function)"
            SyncLogger.log("GUARD VIOLATION: Lifecycle running required, got \(AppSessionManager.shared.state.rawValue)", category: .sync, level: .error)
            
            #if DEBUG
            fatalError("RuntimeGuard.requireAuthenticatedRunning failed at \(context): state=\(AppSessionManager.shared.state.rawValue)")
            #else
            return false
            #endif
        }
        
        if AppSessionManager.shared.securityLock && !allowWhenLocked {
            let context = "\(file):\(line) in \(function)"
            SyncLogger.log("GUARD VIOLATION: Security lock active", category: .sync, level: .error)
            
            #if DEBUG
            fatalError("RuntimeGuard.requireAuthenticatedRunning failed at \(context): securityLock=true")
            #else
            return false
            #endif
        }
        
        return true
    }
    
    // MARK: - Storage Mode Guards
    
    /// Asserts that storage mode is resolved before data operations.
    @discardableResult
    static func requireStorageModeResolved(
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> Bool {
        guard StorageMode.current != nil else {
            let context = "\(file):\(line) in \(function)"
            SyncLogger.log("GUARD VIOLATION: Storage mode not resolved", category: .storage, level: .error)
            
            #if DEBUG
            fatalError("RuntimeGuard.requireStorageModeResolved failed at \(context)")
            #else
            return false
            #endif
        }
        
        return true
    }
    
    /// Asserts CLOUD mode for cloud operations.
    @discardableResult
    static func requireCloudMode(
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> Bool {
        guard StorageMode.isCloud else {
            let context = "\(file):\(line) in \(function)"
            SyncLogger.log("GUARD VIOLATION: Cloud mode required but not active", category: .storage, level: .error)
            
            #if DEBUG
            fatalError("RuntimeGuard.requireCloudMode failed at \(context)")
            #else
            return false
            #endif
        }
        
        return true
    }
    
    // MARK: - Data Guards
    
    /// Asserts conditions required for data write operations.
    /// Combines auth + storage mode checks.
    @MainActor
    @discardableResult
    static func requireDataWriteConditions(
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> Bool {
        // Must have resolved storage mode
        guard requireStorageModeResolved(file: file, function: function, line: line) else {
            return false
        }
        
        // If cloud mode, must be authenticated
        if StorageMode.isCloud {
            guard requireAuth(file: file, function: function, line: line) else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Sync Guards
    
    /// Asserts conditions required for sync operations.
    @MainActor
    @discardableResult
    static func requireSyncConditions(
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> Bool {
        guard requireCloudMode(file: file, function: function, line: line) else {
            return false
        }
        
        guard requireAuthenticatedRunning(file: file, function: function, line: line) else {
            return false
        }
        
        return true
    }
    
    // MARK: - Generic Assertions
    
    /// Asserts a condition with custom message.
    /// Debug: Fatal error. Production: Log and return false.
    @discardableResult
    static func assert(
        _ condition: @autoclosure () -> Bool,
        _ message: String,
        category: SyncLogger.LogCategory = .sync,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> Bool {
        guard condition() else {
            let context = "\(file):\(line) in \(function)"
            SyncLogger.log("GUARD VIOLATION: \(message)", category: category, level: .error)
            
            #if DEBUG
            fatalError("RuntimeGuard.assert failed at \(context): \(message)")
            #else
            return false
            #endif
        }
        
        return true
    }
    
    /// Unconditional failure for impossible states.
    /// Debug: Fatal error. Production: Log and transition to safe state.
    static func impossibleState(
        _ message: String,
        category: SyncLogger.LogCategory = .sync,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> Never {
        let context = "\(file):\(line) in \(function)"
        SyncLogger.log("IMPOSSIBLE STATE: \(message) at \(context)", category: category, level: .error)
        
        #if DEBUG
        fatalError("RuntimeGuard.impossibleState at \(context): \(message)")
        #else
        // In production, we still crash for truly impossible states
        // This should never happen if guards are properly placed
        fatalError("RuntimeGuard.impossibleState at \(context): \(message)")
        #endif
    }
    
    // MARK: - Safe State Transitions
    
    /// Transitions app to a safe state after invariant violation in production.
    @MainActor
    static func transitionToSafeState() async {
        SyncLogger.log("Transitioning to safe state after guard violation", category: .sync, level: .warning)
        
        // Force logout to ensure clean state
        await AuthEngine.shared.logout()
        
        // Clear any pending operations
        MutationQueue.shared.clear()
        
        // App will naturally transition to unauthenticated state
    }
}

// MARK: - Convenience Extensions

extension RuntimeGuard {
    
    /// Precondition wrapper that fails fast in debug, logs in production.
    static func precondition(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        #if DEBUG
        Swift.precondition(condition(), message(), file: file, line: line)
        #else
        if !condition() {
            SyncLogger.log("Precondition failed: \(message())", category: .sync, level: .error)
        }
        #endif
    }
}
