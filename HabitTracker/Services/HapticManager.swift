import SwiftUI
import UIKit

/// Centralized haptic feedback manager.
/// Respects user's haptic feedback preference from settings.
@MainActor
final class HapticManager {
    
    /// Shared instance
    static let shared = HapticManager()
    
    /// Whether haptic feedback is enabled
    var isEnabled: Bool = true
    
    private init() {
        // Load preference
        isEnabled = UserDefaults.standard.object(forKey: "hapticFeedback") as? Bool ?? true
    }
    
    /// Update enabled state and persist
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "hapticFeedback")
    }
    
    // MARK: - Feedback Types
    
    /// Light impact - for subtle interactions (toggles, selections)
    func light() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    /// Medium impact - for confirmations (button taps)
    func medium() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    /// Heavy impact - for significant actions (task completion)
    func heavy() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    /// Soft impact - for gentle feedback
    func soft() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    
    /// Rigid impact - for firm, precise feedback
    func rigid() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
    
    /// Success notification - for successful completions
    func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    /// Warning notification - for warnings or alerts
    func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    /// Error notification - for errors or destructive actions
    func error() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    /// Selection changed - for picker/segment changes
    func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Adds haptic feedback on tap
    func hapticOnTap(_ type: HapticType = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                Task { @MainActor in
                    switch type {
                    case .light: HapticManager.shared.light()
                    case .medium: HapticManager.shared.medium()
                    case .heavy: HapticManager.shared.heavy()
                    case .soft: HapticManager.shared.soft()
                    case .rigid: HapticManager.shared.rigid()
                    case .success: HapticManager.shared.success()
                    case .warning: HapticManager.shared.warning()
                    case .error: HapticManager.shared.error()
                    case .selection: HapticManager.shared.selection()
                    }
                }
            }
        )
    }
}

enum HapticType {
    case light
    case medium
    case heavy
    case soft
    case rigid
    case success
    case warning
    case error
    case selection
}
