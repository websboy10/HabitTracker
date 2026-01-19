import Foundation

/// Navigation event types for structured logging
enum NavigationEvent: String {
    case appLaunch = "APP_LAUNCH"
    case appForeground = "APP_FOREGROUND"
    case appBackground = "APP_BACKGROUND"
    case tabChange = "TAB_CHANGE"
    case viewAppear = "VIEW_APPEAR"
    case viewDisappear = "VIEW_DISAPPEAR"
    case sheetPresent = "SHEET_PRESENT"
    case sheetDismiss = "SHEET_DISMISS"
    case scrollReset = "SCROLL_RESET"
    case stateReset = "STATE_RESET"
    case unexpectedStateRetention = "UNEXPECTED_STATE_RETENTION"
}

/// Centralized navigation logging for debugging and validation.
/// Logs navigation transitions, view appearances, and state management events.
/// Thread-safe and non-blocking to avoid affecting UI behavior.
@MainActor
final class NavigationLogger {

    static let shared = NavigationLogger()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    /// Enable/disable logging (can be toggled for debugging)
    var isEnabled: Bool = true

    /// Store recent logs for debugging (circular buffer of last 100 entries)
    private var recentLogs: [String] = []
    private let maxLogCount = 100

    private init() {}

    /// Log a navigation event with optional context
    func log(event: NavigationEvent, context: String? = nil) {
        guard isEnabled else { return }

        let timestamp = dateFormatter.string(from: Date())
        var message = "[\(timestamp)] [NAV] \(event.rawValue)"

        if let context = context {
            message += " - \(context)"
        }

        // Print to console (non-blocking)
        #if DEBUG
        print(message)
        #endif

        // Store in circular buffer
        recentLogs.append(message)
        if recentLogs.count > maxLogCount {
            recentLogs.removeFirst()
        }
    }

    /// Log tab change with from/to tabs
    func logTabChange(from oldTab: Tab?, to newTab: Tab) {
        let fromStr = oldTab?.rawValue.description ?? "nil"
        let toStr = newTab.rawValue.description
        log(event: .tabChange, context: "from: \(fromStr) -> to: \(toStr)")
    }

    /// Log view appearance
    func logViewAppear(_ viewName: String) {
        log(event: .viewAppear, context: viewName)
    }

    /// Log view disappearance
    func logViewDisappear(_ viewName: String) {
        log(event: .viewDisappear, context: viewName)
    }

    /// Log scroll position reset
    func logScrollReset(_ viewName: String) {
        log(event: .scrollReset, context: "\(viewName) scroll reset to top")
    }

    /// Log state reset
    func logStateReset(_ viewName: String, stateDescription: String) {
        log(event: .stateReset, context: "\(viewName): \(stateDescription)")
    }

    /// Log unexpected state retention (potential violation)
    func logUnexpectedState(_ viewName: String, description: String) {
        log(event: .unexpectedStateRetention, context: "\(viewName): \(description)")
    }

    /// Get recent logs for debugging
    func getRecentLogs() -> [String] {
        return recentLogs
    }

    /// Clear log history
    func clearLogs() {
        recentLogs.removeAll()
    }
}
