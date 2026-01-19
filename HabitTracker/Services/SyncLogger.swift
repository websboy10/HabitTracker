import Foundation

// MARK: - Sync Logger

/// Structured logging for invariant-critical operations.
/// Non-blocking and side-effect free.
///
/// **Logged Operations:**
/// - Login / Logout
/// - Storage mode changes
/// - Sync start / success / failure
/// - CRUD operations
/// - Reset all data
/// - Delete account
enum SyncLogger {
    
    // MARK: - Log Levels
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    // MARK: - Log Categories
    
    enum LogCategory: String {
        case auth = "AUTH"
        case sync = "SYNC"
        case crud = "CRUD"
        case storage = "STORAGE"
        case account = "ACCOUNT"
        case queue = "QUEUE"
        case notification = "NOTIFICATION"
    }
    
    // MARK: - Logging
    
    /// Logs a message with category and level.
    /// Non-blocking - runs on background queue.
    static func log(
        _ message: String,
        category: LogCategory,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(category.rawValue)] \(message) (\(fileName):\(line))"
        
        // Non-blocking print
        DispatchQueue.global(qos: .utility).async {
            print(logMessage)
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Log auth events
    static func logAuth(_ message: String, level: LogLevel = .info) {
        log(message, category: .auth, level: level)
    }
    
    /// Log sync events
    static func logSync(_ message: String, level: LogLevel = .info) {
        log(message, category: .sync, level: level)
    }
    
    /// Log CRUD operations
    static func logCRUD(_ message: String, level: LogLevel = .info) {
        log(message, category: .crud, level: level)
    }
    
    /// Log storage mode events
    static func logStorage(_ message: String, level: LogLevel = .info) {
        log(message, category: .storage, level: level)
    }
    
    /// Log account events
    static func logAccount(_ message: String, level: LogLevel = .info) {
        log(message, category: .account, level: level)
    }
    
    /// Log mutation queue events
    static func logQueue(_ message: String, level: LogLevel = .info) {
        log(message, category: .queue, level: level)
    }

    /// Log notification events
    static func logNotification(_ message: String, level: LogLevel = .info) {
        log(message, category: .notification, level: level)
    }
}
