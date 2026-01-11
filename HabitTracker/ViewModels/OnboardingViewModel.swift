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

enum StorageMode: String, CaseIterable {
    case cloud = "Cloud"
    case local = "Local Only"
    
    /// Reads persisted storage mode. Returns nil if not yet set (onboarding incomplete).
    static var current: StorageMode? {
        guard let raw = UserDefaults.standard.string(forKey: "storageMode") else {
            return nil
        }
        if raw.lowercased() == "cloud" || raw == StorageMode.cloud.rawValue {
            return .cloud
        }
        if raw.lowercased().contains("local") || raw == StorageMode.local.rawValue {
            return .local
        }
        return nil
    }
    
    /// Persists storage mode to UserDefaults
    static func persist(_ mode: StorageMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: "storageMode")
    }
    
    /// Clears persisted storage mode
    static func clear() {
        UserDefaults.standard.removeObject(forKey: "storageMode")
    }
}

@Observable
final class OnboardingViewModel {

    // MARK: - Navigation

    var currentStep: OnboardingStep = .foundation

    // MARK: - Foundation

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
    var dayResetTime: Date = Calendar.current.date(from: DateComponents(hour: 4, minute: 0)) ?? Date() {
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

    var dayResetHour: Int {
        Calendar.current.component(.hour, from: dayResetTime)
    }

    var dayResetMinute: Int {
        Calendar.current.component(.minute, from: dayResetTime)
    }

    var isAM: Bool {
        dayResetHour < 12
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
                let success = await syncToCloud()
                await MainActor.run {
                    isCompletingOnboarding = false
                    if success {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                            AppSessionManager.shared.completeOnboarding()
                        }
                    } else {
                        onboardingError = "Failed to sync. Please try again."
                        // Revert storage mode on failure
                        StorageMode.clear()
                    }
                }
            }
        } else {
            // Local mode: sync settings only (fire and forget), then complete
            Task {
                // Ensure we wait for any pending session refreshes
                await SupabaseService.shared.awaitSessionInitialization()
                
                print("[OnboardingViewModel] ⚙️ Syncing settings (Local Mode)...")
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: dayResetTime)
                let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                
                guard let userId = await SupabaseService.shared.currentUserId else { return }
                
                let themeString: String
                switch themeVariant {
                case .crimson: themeString = "red"
                case .onyx: themeString = "blue"
                case .grove: themeString = "forest"
                case .blossom: themeString = "pink"
                case .gold: themeString = "amber"
                case .aubergine: themeString = "purple"
                case .gunmetal: themeString = "graphite"
                case .steel: themeString = "teal"
                }

                let settingsDTO = UserSettingsDTO(
                    userId: userId,
                    theme: themeString,
                    hapticFeedback: hapticsEnabled,
                    compactLayout: false,
                    reduceMotion: false,
                    weekStart: weekStart.rawValue,
                    monthCalculation: monthCalculation.rawValue,
                    dayResetMinutes: minutes,
                    storageMode: "local"
                )
                
                do {
                    _ = try await SupabaseService.shared.upsertSettings(settingsDTO)
                    print("[OnboardingViewModel] ✅ Settings synced (Local Mode).")
                } catch {
                    print("[OnboardingViewModel] ⚠️ Failed to sync settings in local mode: \(error)")
                }
            }
            
            // Immediate completion
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
    }
    
    // MARK: - Cloud Sync
    
    @MainActor
    private func syncToCloud() async -> Bool {
        let supabase = SupabaseService.shared
        
        print("[OnboardingViewModel] ☁️ Starting cloud sync...")
        
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
        
        do {
            // Sync profile data
            print("[OnboardingViewModel] 👤 Syncing profile...")
            let ageInt = Int(age)
            try await SyncService.shared.syncProfileToCloud(
                name: UserDefaults.standard.string(forKey: "userName") ?? "User",
                title: UserDefaults.standard.string(forKey: "userTitle") ?? "Habit Enthusiast",
                age: ageInt,
                userGoal: userGoals.isEmpty ? nil : userGoals.joined(separator: ", ")
            )
            
            // Sync settings
            print("[OnboardingViewModel] ⚙️ Syncing settings...")
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: dayResetTime)
            let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

            let cloudThemeString: String
            switch themeVariant {
            case .crimson: cloudThemeString = "red"
            case .onyx: cloudThemeString = "blue"
            case .grove: cloudThemeString = "forest"
            case .blossom: cloudThemeString = "pink"
            case .gold: cloudThemeString = "amber"
            case .aubergine: cloudThemeString = "purple"
            case .gunmetal: cloudThemeString = "graphite"
            case .steel: cloudThemeString = "teal"
            }

            let settingsDTO = UserSettingsDTO(
                userId: userId,
                theme: cloudThemeString,
                hapticFeedback: hapticsEnabled,
                compactLayout: false,
                reduceMotion: false,
                weekStart: weekStart.rawValue,
                monthCalculation: monthCalculation.rawValue,
                dayResetMinutes: minutes,
                storageMode: "cloud"
            )
            
            let result = try await supabase.upsertSettings(settingsDTO)
            print("[OnboardingViewModel] ✅ Settings synced. Result ID: \(result.id ?? "nil")")
            return true
        } catch {
            print("[OnboardingViewModel] ❌ Failed to sync onboarding: \(error)")
            await MainActor.run {
                if let supabaseError = error as? SupabaseError {
                    onboardingError = "Sync Failed: \(supabaseError.localizedDescription)"
                } else {
                    onboardingError = "Sync Failed: \(error.localizedDescription)"
                }
            }
            return false
        }
    }
}
