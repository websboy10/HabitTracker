import SwiftUI

// MARK: - Theme Manager (Global Observable)

/// Singleton theme manager that triggers UI updates when theme changes
@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    /// Current active theme - changing this updates the entire app UI
    var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "theme")
        }
    }

    private init() {
        let themeString = UserDefaults.standard.string(forKey: "theme") ?? "red"
        self.currentTheme = AppTheme(rawValue: themeString) ?? .red
    }

    /// Sets the theme and triggers UI refresh
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
}

/// Available app themes with full color palettes
enum AppTheme: String, CaseIterable, Codable {
    case red = "red"
    case blue = "blue"  // Navy blue
    case green = "green"
    case amber = "amber"
    case purple = "purple"
    case pink = "pink"
    case forest = "forest"  // Dark forest green
    case graphite = "graphite"  // Gunmetal gray
    case teal = "teal"  // Steel teal (blue-green)
    
    /// Theme swatch color (for settings picker)
    var color: Color {
        primaryColor
    }
    
    // MARK: - Primary Colors
    
    var primaryColor: Color {
        switch self {
        case .red: return Color(hex: 0xD11A2A)
        case .blue: return Color(hex: 0x2F5B9C)  // Navy blue (brighter)
        case .green: return Color(hex: 0x10B981)
        case .amber: return Color(hex: 0xF59E0B)
        case .purple: return Color(hex: 0x8B5CF6)
        case .pink: return Color(hex: 0xEC4899)
        case .forest: return Color(hex: 0x6B8E6B)  // Desaturated forest green
        case .graphite: return Color(hex: 0x8A9199)  // Gunmetal gray
        case .teal: return Color(hex: 0x5B9A9A)  // Steel teal
        }
    }
    
    // MARK: - Background Colors
    
    var backgroundDark: Color {
        switch self {
        case .red: return Color(hex: 0x050101)
        case .blue: return Color(hex: 0x05080F)  // Deep navy black
        case .green: return Color(hex: 0x010503)
        case .amber: return Color(hex: 0x050301)
        case .purple: return Color(hex: 0x030105)
        case .pink: return Color(hex: 0x050103)
        case .forest: return Color(hex: 0x0A0F0A)  // Near-black forest tint
        case .graphite: return Color(hex: 0x0A0B0C)  // Near-black neutral
        case .teal: return Color(hex: 0x070C0C)  // Near-black teal tint
        }
    }
    
    var backgroundLight: Color {
        switch self {
        case .red: return Color(hex: 0x0f0505)
        case .blue: return Color(hex: 0x0B1320)  // Navy tinted
        case .green: return Color(hex: 0x050f08)
        case .amber: return Color(hex: 0x0f0805)
        case .purple: return Color(hex: 0x08050f)
        case .pink: return Color(hex: 0x0f0508)
        case .forest: return Color(hex: 0x141A14)  // Slightly elevated forest surface
        case .graphite: return Color(hex: 0x141516)  // Elevated neutral surface
        case .teal: return Color(hex: 0x101616)  // Elevated teal surface
        }
    }
    
    // MARK: - Gradient Colors
    
    var gradientStart: Color {
        switch self {
        case .red: return Color(hex: 0x2b0406)
        case .blue: return Color(hex: 0x0C1626)  // Deep navy
        case .green: return Color(hex: 0x062b15)
        case .amber: return Color(hex: 0x2b1a06)
        case .purple: return Color(hex: 0x1a062b)
        case .pink: return Color(hex: 0x2b0620)
        case .forest: return Color(hex: 0x1A2A1A)  // Forest gradient entry
        case .graphite: return Color(hex: 0x1A1C1E)  // Graphite gradient entry
        case .teal: return Color(hex: 0x142020)  // Teal gradient entry
        }
    }
    
    var gradientMid: Color {
        switch self {
        case .red: return Color(hex: 0x630b12)
        case .blue: return Color(hex: 0x254F85)  // Navy blue
        case .green: return Color(hex: 0x0b6330)
        case .amber: return Color(hex: 0x634a0b)
        case .purple: return Color(hex: 0x3d0b63)
        case .pink: return Color(hex: 0x630b45)
        case .forest: return Color(hex: 0x2A4D2A)  // Forest mid-tone
        case .graphite: return Color(hex: 0x3A3E42)  // Graphite mid-tone
        case .teal: return Color(hex: 0x2A4A4A)  // Teal mid-tone
        }
    }
    
    var gradientEnd: Color {
        switch self {
        case .red: return Color(hex: 0x1a0203)
        case .blue: return Color(hex: 0x05080F)  // Near black navy
        case .green: return Color(hex: 0x031a0a)
        case .amber: return Color(hex: 0x1a0f03)
        case .purple: return Color(hex: 0x0a031a)
        case .pink: return Color(hex: 0x1a030f)
        case .forest: return Color(hex: 0x080C08)  // Returns to forest darkness
        case .graphite: return Color(hex: 0x08090A)  // Returns to graphite darkness
        case .teal: return Color(hex: 0x060A0A)  // Returns to teal darkness
        }
    }
    
    // MARK: - Mood Glow Colors
    
    var moodGlowDark: Color {
        switch self {
        case .red: return Color(red: 139/255, green: 0, blue: 0).opacity(0.4)
        case .blue: return Color(red: 10/255, green: 40/255, blue: 110/255).opacity(0.5)  // Deep navy glow
        case .green: return Color(red: 0, green: 139/255, blue: 69/255).opacity(0.4)
        case .amber: return Color(red: 139/255, green: 100/255, blue: 0).opacity(0.4)
        case .purple: return Color(red: 75/255, green: 0, blue: 139/255).opacity(0.4)
        case .pink: return Color(red: 139/255, green: 0, blue: 90/255).opacity(0.4)
        case .forest: return Color(red: 30/255, green: 61/255, blue: 30/255).opacity(0.5)  // Deep forest glow
        case .graphite: return Color(red: 60/255, green: 65/255, blue: 70/255).opacity(0.5)  // Deep graphite glow
        case .teal: return Color(red: 30/255, green: 70/255, blue: 70/255).opacity(0.5)  // Deep teal glow
        }
    }
    
    var moodGlowMid: Color {
        switch self {
        case .red: return Color(red: 220/255, green: 20/255, blue: 60/255).opacity(0.2)
        case .blue: return Color(red: 70/255, green: 130/255, blue: 220/255).opacity(0.3)  // Bright navy glow
        case .green: return Color(red: 20/255, green: 220/255, blue: 100/255).opacity(0.2)
        case .amber: return Color(red: 220/255, green: 160/255, blue: 20/255).opacity(0.2)
        case .purple: return Color(red: 140/255, green: 20/255, blue: 220/255).opacity(0.2)
        case .pink: return Color(red: 220/255, green: 20/255, blue: 140/255).opacity(0.2)
        case .forest: return Color(red: 42/255, green: 77/255, blue: 42/255).opacity(0.3)  // Medium forest glow
        case .graphite: return Color(red: 100/255, green: 110/255, blue: 120/255).opacity(0.3)  // Medium graphite glow
        case .teal: return Color(red: 60/255, green: 120/255, blue: 120/255).opacity(0.3)  // Medium teal glow
        }
    }
    
    var moodGlowDeep: Color {
        switch self {
        case .red: return Color(red: 100/255, green: 0, blue: 0).opacity(0.3)
        case .blue: return Color(red: 5/255, green: 30/255, blue: 90/255).opacity(0.4)  // Deep navy
        case .green: return Color(red: 0, green: 100/255, blue: 50/255).opacity(0.3)
        case .amber: return Color(red: 100/255, green: 70/255, blue: 0).opacity(0.3)
        case .purple: return Color(red: 50/255, green: 0, blue: 100/255).opacity(0.3)
        case .pink: return Color(red: 100/255, green: 0, blue: 60/255).opacity(0.3)
        case .forest: return Color(red: 13/255, green: 31/255, blue: 13/255).opacity(0.4)  // Deep ambient forest
        case .graphite: return Color(red: 40/255, green: 45/255, blue: 50/255).opacity(0.4)  // Deep ambient graphite
        case .teal: return Color(red: 15/255, green: 40/255, blue: 40/255).opacity(0.4)  // Deep ambient teal
        }
    }
}

/// Week start day preference
enum WeekStart: String, CaseIterable, Codable {
    case sunday = "sunday"
    case monday = "monday"
    
    var label: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        }
    }
}

/// Month calculation method
enum MonthCalculation: String, CaseIterable, Codable {
    case calendar = "calendar"
    case rolling = "rolling"
    
    var label: String {
        switch self {
        case .calendar: return "Calendar"
        case .rolling: return "Rolling (30d)"
        }
    }
}

/// Centralized settings store with persistence
@MainActor
@Observable
final class SettingsStore {

    static let shared = SettingsStore()

    // MARK: - Theme
    var selectedTheme: AppTheme {
        didSet {
            save()
            // Apply theme immediately via ThemeManager
            ThemeManager.shared.setTheme(selectedTheme)
        }
    }
    
    // MARK: - Display Options
    var compactLayout: Bool {
        didSet { save() }
    }
    
    var reduceMotion: Bool {
        didSet { save() }
    }
    
    var hapticFeedback: Bool {
        didSet {
            save()
            HapticManager.shared.setEnabled(hapticFeedback)
        }
    }
    
    // MARK: - Calculations
    var weekStart: WeekStart {
        didSet { save() }
    }
    
    var monthCalculation: MonthCalculation {
        didSet { save() }
    }
    
    // MARK: - Day Boundary
    /// Minutes since midnight (e.g., 240 = 4:00 AM)
    var dayResetMinutes: Int {
        didSet { save() }
    }

    // MARK: - Grace Period (Global)
    /// Minutes after scheduled time before an obligation is marked as missed.
    /// This is a GLOBAL setting - all obligations follow the same discipline rules.
    var gracePeriodMinutes: Int {
        didSet { save() }
    }
    
    /// Day reset time as Date for picker
    var dayResetTime: Date {
        get {
            let calendar = Calendar.current
            let hour = dayResetMinutes / 60
            let minute = dayResetMinutes % 60
            return calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        }
        set {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: newValue)
            dayResetMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    }
    
    /// Formatted time string
    var dayResetTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: dayResetTime)
    }
    
    // MARK: - User Profile
    var userName: String {
        didSet { save() }
    }
    
    var userTitle: String {
        didSet { save() }
    }
    
    var userInitials: String {
        let parts = userName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        } else if let first = parts.first {
            return String(first.prefix(2))
        }
        return "HT"
    }
    
    // MARK: - App Info
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - Initialization

    private init() {
        // Load from UserDefaults
        let defaults = UserDefaults.standard

        // Theme: use ThemeManager as source of truth (it may have been changed during onboarding)
        self.selectedTheme = ThemeManager.shared.currentTheme
        self.compactLayout = defaults.bool(forKey: "compactLayout")
        self.reduceMotion = defaults.bool(forKey: "reduceMotion")
        self.weekStart = WeekStart(rawValue: defaults.string(forKey: "weekStart") ?? "") ?? .monday
        self.monthCalculation = MonthCalculation(rawValue: defaults.string(forKey: "monthCalculation") ?? "") ?? .calendar
        self.dayResetMinutes = defaults.object(forKey: "dayResetMinutes") as? Int ?? 240 // 4:00 AM default
        self.gracePeriodMinutes = defaults.object(forKey: "gracePeriodMinutes") as? Int ?? 0 // No grace by default
        self.userName = defaults.string(forKey: "userName") ?? "User"
        self.userTitle = defaults.string(forKey: "userTitle") ?? "Habit Enthusiast"
        self.hapticFeedback = defaults.object(forKey: "hapticFeedback") as? Bool ?? true

        // Sync HapticManager
        HapticManager.shared.setEnabled(hapticFeedback)
    }
    
    // MARK: - Persistence
    
    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(selectedTheme.rawValue, forKey: "theme")
        defaults.set(compactLayout, forKey: "compactLayout")
        defaults.set(reduceMotion, forKey: "reduceMotion")
        defaults.set(weekStart.rawValue, forKey: "weekStart")
        defaults.set(monthCalculation.rawValue, forKey: "monthCalculation")
        defaults.set(dayResetMinutes, forKey: "dayResetMinutes")
        defaults.set(gracePeriodMinutes, forKey: "gracePeriodMinutes")
        defaults.set(userName, forKey: "userName")
        defaults.set(userTitle, forKey: "userTitle")
        defaults.set(hapticFeedback, forKey: "hapticFeedback")
        
        // Sync to cloud (debounced - only if authenticated)
        syncToCloudDebounced()
    }
    
    private var syncWorkItem: DispatchWorkItem?
    
    private func syncToCloudDebounced() {
        // Only sync if cloud mode
        guard StorageMode.isCloud else { return }
        
        // Cancel any pending sync
        syncWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await SyncService.shared.syncSettingsToCloud(settings: self)
                await SyncService.shared.syncSettingsToCloud(settings: self)
                do {
                    try await SyncService.shared.syncProfileToCloud(
                        name: self.userName,
                        title: self.userTitle
                    )
                } catch {
                    print("Available to sync profile from settings: \(error)")
                }
            }
        }
        
        syncWorkItem = workItem
        
        // Debounce sync by 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }
    
    // MARK: - Data Management
    
    func resetAllData() {
        // We do NOT want to wipe the entire domain because that would clear
        // auth tokens, isAuthenticated state, and onboarding status.
        // Instead, we just reset the configurable settings to defaults.
        
        let defaults = UserDefaults.standard
        
        // Remove specific settings keys
        let keysToReset = [
            "theme", "compactLayout", "reduceMotion", "weekStart",
            "monthCalculation", "dayResetMinutes", "gracePeriodMinutes",
            "userName", "userTitle", "hapticFeedback"
        ]
        
        for key in keysToReset {
            defaults.removeObject(forKey: key)
        }
        
        // Reset properties to defaults
        selectedTheme = .red
        compactLayout = false
        reduceMotion = false
        weekStart = .monday
        monthCalculation = .calendar
        dayResetMinutes = 240
        gracePeriodMinutes = 0
        userName = "User"
        userTitle = "Habit Enthusiast"
        hapticFeedback = true
        
        // Trigger save to persist these defaults back to UserDefaults
        save()
    }
    
    // MARK: - Cloud Sync
    
    /// Syncs settings from cloud to local
    func syncFromCloud() {
        Task {
            await SyncService.shared.syncSettingsFromCloud(settings: self)
            await SyncService.shared.syncProfileFromCloud(settings: self)
        }
    }
}
