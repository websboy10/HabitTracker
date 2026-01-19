import UIKit

/// App delegate for handling system-level configuration.
/// Enforces portrait-only orientation across the app.
class AppDelegate: NSObject, UIApplicationDelegate {

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
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        NavigationLogger.shared.log(event: .appBackground, context: "App entering background")
    }
}
