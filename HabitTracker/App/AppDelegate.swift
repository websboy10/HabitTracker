import UIKit
import SwiftData

/// App delegate for handling system-level configuration.
/// Enforces portrait-only orientation across the app.
class AppDelegate: NSObject, UIApplicationDelegate {

    /// Reference to the model container, set by HabitTrackerApp after initialization.
    var modelContainer: ModelContainer?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NavigationLogger.shared.log(event: .appLaunch, context: "Application launched")
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        // Lock to portrait only - no landscape allowed
        return .portrait
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        NavigationLogger.shared.log(event: .appForeground, context: "App entering foreground")

        // Refresh report notifications with fresh stats when returning to foreground.
        // This ensures notifications always have current data even if user made changes
        // via widgets, shortcuts, or if time has passed since last app use.
        Task { @MainActor in
            guard AppSessionManager.shared.state == .running,
                  let container = modelContainer else { return }
            await NotificationEngine.shared.syncReportNotifications(modelContext: container.mainContext)
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        NavigationLogger.shared.log(event: .appBackground, context: "App entering background")
    }
}
