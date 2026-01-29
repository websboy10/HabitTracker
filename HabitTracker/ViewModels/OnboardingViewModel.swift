import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case foundation = 0
    case systemConfig = 1
    case activation = 2
}

enum OnboardingThemeVariant: String, CaseIterable {
    case onyx = "Onyx"
    case crimson = "Crimson"
    case grove = "Grove"
    case blossom = "Blossom"
    case gold = "Gold"
    case aubergine = "Aubergine"
    case gunmetal = "Gunmetal"
    case steel = "Steel"
}

// StorageMode enum moved to Services/StorageMode.swift

@Observable
final class OnboardingViewModel {

    // MARK: - Navigation

    var currentStep: OnboardingStep = .foundation

    // MARK: - Foundation

    var userName: String = UserDefaults.standard.string(forKey: "userName") ?? "" {
        didSet {
            UserDefaults.standard.set(userName, forKey: "userName")
            Task { @MainActor in
                SettingsStore.shared.userName = userName
            }
        }
    }

    var age: String = "" {
        didSet { UserDefaults.standard.set(age, forKey: "userAge") }
    }
    var userGoals: Set<String> = [] {
        didSet { UserDefaults.standard.set(Array(userGoals), forKey: "userGoals") }
    }

    // MARK: - System Configuration

    var themeVariant: OnboardingThemeVariant = .crimson {
        didSet { UserDefaults.standard.set(themeVariant.rawValue, forKey: "onboardingTheme") }
    }
    var hapticsEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(hapticsEnabled, forKey: "hapticFeedback")
            Task { @MainActor in
                HapticManager.shared.setEnabled(hapticsEnabled)
            }
        }
    }
    var weekStart: WeekStart = .monday {
        didSet { UserDefaults.standard.set(weekStart.rawValue, forKey: "weekStart") }
    }
    var monthCalculation: MonthCalculation = .calendar {
        didSet { UserDefaults.standard.set(monthCalculation.rawValue, forKey: "monthCalculation") }
    }
    var dayResetTime: Date = Calendar.current.date(from: DateComponents(hour: 0, minute: 0)) ?? Date() {
        didSet {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: dayResetTime)
            let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            UserDefaults.standard.set(minutes, forKey: "dayResetMinutes")
        }
    }

    // MARK: - Activation

    var storageMode: StorageMode = .cloud

    // MARK: - Computed

    var dayResetTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: dayResetTime)
    }

    // MARK: - Completion State
    
    var isCompletingOnboarding = false
    var onboardingError: String?
    
    // MARK: - Actions

    func nextStep() {
        guard let nextIndex = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            completeOnboarding()
            return
        }
        currentStep = nextIndex
    }

    func previousStep() {
        guard let prevIndex = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prevIndex
    }

    func completeOnboarding() {
        // 1. Persist storage mode FIRST (permanent decision)
        StorageMode.persist(storageMode)
        
        // 2. Persist local settings
        persistSettings()
        
        // 3. Handle based on mode
        if storageMode == .cloud {
            isCompletingOnboarding = true
            onboardingError = nil
            Task {
                let success = await validateCloudSession()
                await MainActor.run {
                    isCompletingOnboarding = false
                    if success {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                            AppSessionManager.shared.completeOnboarding()
                        }
                    } else {
                        onboardingError = "Authentication session validation failed. Please try again."
                        // Revert storage mode on failure
                        StorageMode.clear()
                    }
                }
            }
        } else {
            // Local mode: complete immediately (cloud bootstrap happens post-onboarding)
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.2)) {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    AppSessionManager.shared.completeOnboarding()
                }
            }
        }
    }

    private func persistSettings() {
        let defaults = UserDefaults.standard
        defaults.set(age, forKey: "userAge")
        defaults.set(Array(userGoals), forKey: "userGoals")
        defaults.set(themeVariant.rawValue, forKey: "onboardingTheme")
        defaults.set(hapticsEnabled, forKey: "hapticFeedback")
        defaults.set(weekStart.rawValue, forKey: "weekStart")
        defaults.set(monthCalculation.rawValue, forKey: "monthCalculation")

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: dayResetTime)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        defaults.set(minutes, forKey: "dayResetMinutes")
        
        // CRITICAL FIX: Update SettingsStore singleton so it reflects the new values immediately.
        // If SettingsStore was already initialized (e.g. at app launch), it holds stale defaults.
        // We must update it before the first sync occurs to prevent overwriting cloud/local data with defaults.
        Task { @MainActor in
            let store = SettingsStore.shared
            print("[Onboarding] ⚠️ Updating SettingsStore singleton with onboarding values...")
            
            // Theme mapping (Manual sync from ThemeManager since SettingsStore doesn't observe it)
            store.selectedTheme = ThemeManager.shared.currentTheme
            
            store.hapticFeedback = hapticsEnabled
            store.weekStart = weekStart
            store.monthCalculation = monthCalculation
            store.dayResetMinutes = minutes
            store.userName = userName
            
            print("[Onboarding] ✅ SettingsStore updated. Theme: \(store.selectedTheme), ResetTime: \(minutes)m")
        }
    }
    
    // MARK: - Cloud Sync
    
    @MainActor
    private func validateCloudSession() async -> Bool {
        let supabase = SupabaseService.shared
        
        // Ensure we wait for any pending session refreshes
        await supabase.awaitSessionInitialization()
        
        print("[OnboardingViewModel] 🔐 Auth status: \(supabase.isAuthenticated), UserID: \(supabase.currentUserId ?? "nil")")
        print("[OnboardingViewModel] 💾 Storage Mode: \(storageMode.rawValue)")
        
        guard supabase.isAuthenticated, let userId = supabase.currentUserId else { 
            print("[OnboardingViewModel] ❌ Sync failed: Not authenticated")
            // If we are locally authenticated (AppStorage) but service isn't, try to reload/recover?
            // For now, let's just fail with a specific log.
            await MainActor.run {
                onboardingError = "Authentication session validation failed. Please try restarting the app."
            }
            return false 
        }
        
        return true
    }
}
