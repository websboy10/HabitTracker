import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Settings view following HTML reference design
struct SettingsView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: Tab
    @State private var settings = SettingsStore.shared
    var showsCustomTabBar: Bool = true
    
    // Time picker state
    @State private var showingTimePicker = false
    
    // Data management state
    @State private var showingResetConfirmation = false
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    
    // Account management state
    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var deleteAccountStep = 0  // 0 = hidden, 1 = first warning, 2 = final confirmation
    @State private var isLoggingOut = false
    @State private var isDeletingAccount = false
    
    var body: some View {
        ZStack {
            // Background
            AppMaterials.moodGradient
            
            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    header
                        .padding(.bottom, AppSpacing.lg)
                    
                    // Account Section
                    accountSection
                        .padding(.bottom, AppSpacing.lg)
                    
                    // Theme Section
                    themeSection
                        .padding(.bottom, AppSpacing.lg)
                    
                    // Display Options
                    displayOptionsSection
                        .padding(.bottom, AppSpacing.lg)
                    
                    // Calculations
                    calculationsSection
                        .padding(.bottom, AppSpacing.lg)
                    
                    // Day Boundary
                    dayBoundarySection
                        .padding(.bottom, AppSpacing.lg)
                    
                    // Data & Backup
                    dataBackupSection
                        .padding(.bottom, AppSpacing.lg)
                    
                    // About
                    aboutSection
                        .padding(.bottom, AppSpacing.lg)
                    
                    // Danger Zone (Delete Account)
                    dangerZoneSection
                        .padding(.bottom, 120)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.xl)
            }
            
            // Fixed bottom elements
            if showsCustomTabBar {
                VStack {
                    Spacer()
                    bottomNavigation
                }
            }
        }
        .sheet(isPresented: $showingTimePicker) {
            timePickerSheet
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .overlay {
            // Reset Data Confirmation
            RTSConfirmationAlert(
                isPresented: $showingResetConfirmation,
                icon: "trash",
                iconColor: Color.red,
                title: "Reset All Data?",
                message: "This will permanently delete all your goals, progress, and settings. This action cannot be undone.",
                confirmText: "Reset Everything",
                confirmColor: Color.red,
                onConfirm: { resetAllData() }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .animation(.easeInOut(duration: 0.2), value: showingResetConfirmation)
        }
        .overlay {
            // Logout Confirmation
            RTSConfirmationAlert(
                isPresented: $showingLogoutConfirmation,
                icon: "rectangle.portrait.and.arrow.right",
                iconColor: AppColors.primary,
                title: "Log Out?",
                message: "You will be signed out of your account and returned to the login screen.",
                confirmText: "Log Out",
                confirmColor: AppColors.primary,
                onConfirm: { performLogout() }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .animation(.easeInOut(duration: 0.2), value: showingLogoutConfirmation)
        }
        .overlay {
            // Delete Account Multi-Step Confirmation
            RTSDeleteAccountFlow(
                step: $deleteAccountStep,
                isDeleting: $isDeletingAccount,
                onDelete: { performDeleteAccount() }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .animation(.easeInOut(duration: 0.2), value: deleteAccountStep)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.5)
            
            Spacer()
        }
        .padding(.leading, 4)
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Account")
            
            GlassCard {
                VStack(spacing: 0) {
                    // User profile row
                    HStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.primary, Color(hex: 0x4a090e)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)
                                .shadow(color: AppColors.primary.opacity(0.4), radius: 10)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            
                            Text(settings.userInitials)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .tracking(1)
                        }
                        
                        // Name and title
                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.userName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(settings.userTitle)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    
                    Divider()
                        .background(Color.white.opacity(0.05))
                    
                    // Logout button
                    Button {
                        showingLogoutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 24)
                            
                            Text("Log Out")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                            
                            Spacer()
                            
                            if isLoggingOut {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(AppColors.textSecondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoggingOut)
                }
            }
        }
    }
    
    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Theme")

            ZStack(alignment: .topTrailing) {
                // Glow effect
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 128, height: 128)
                    .blur(radius: 60)
                    .offset(x: 32, y: -32)

                GlassCardHighlight {
                    AccentColorPicker(
                        selectedTheme: $settings.selectedTheme,
                        reduceMotion: settings.reduceMotion
                    )
                    .padding(20)
                }
            }
        }
    }
    
    // MARK: - Display Options Section
    
    private var displayOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Display Options")
            
            GlassCard {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        icon: "waveform",
                        label: "Reduce Motion",
                        isOn: $settings.reduceMotion,
                        reduceMotion: settings.reduceMotion
                    )
                    
                    Divider()
                        .background(Color.white.opacity(0.05))
                    
                    SettingsToggleRow(
                        icon: "iphone.radiowaves.left.and.right",
                        label: "Haptic Feedback",
                        isOn: $settings.hapticFeedback,
                        reduceMotion: settings.reduceMotion
                    )
                }
            }
        }
    }
    
    // MARK: - Calculations Section
    
    private var calculationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Calculations")
            
            GlassCard {
                VStack(spacing: 20) {
                    // Week Start
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Week Starts On")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                            .textCase(.uppercase)
                            .tracking(1)
                        
                        SettingsSegmentedControl(
                            options: WeekStart.allCases,
                            selection: $settings.weekStart,
                            labelProvider: { $0.label },
                            reduceMotion: settings.reduceMotion
                        )
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.05))
                    
                    // Month Calculation
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Month Calculation")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                            .textCase(.uppercase)
                            .tracking(1)
                        
                        SettingsSegmentedControl(
                            options: MonthCalculation.allCases,
                            selection: $settings.monthCalculation,
                            labelProvider: { $0.label },
                            reduceMotion: settings.reduceMotion
                        )
                    }
                }
                .padding(20)
            }
        }
    }
    
    // MARK: - Day Boundary Section
    
    private var dayBoundarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Day Boundary")
            
            GlassCard {
                Button { showingTimePicker = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Day Reset Time")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textPrimary.opacity(0.9))
                            
                            Text("Tasks reset after this time")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Text(settings.dayResetTimeFormatted)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(AppColors.textPrimary)
                            
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Time Picker Sheet
    
    private var timePickerSheet: some View {
        NavigationStack {
            ZStack {
                AppMaterials.moodGradient.ignoresSafeArea()
                
                DatePicker(
                    "Day Reset Time",
                    selection: $settings.dayResetTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
            }
            .navigationTitle("Day Reset Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingTimePicker = false }
                        .foregroundColor(AppColors.primary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.height(300)])
    }
    
    // MARK: - Data & Backup Section
    
    private var dataBackupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Data & Backup")
            
            GlassCardMuted {
                VStack(spacing: 0) {
                    SettingsActionRow(icon: "square.and.arrow.up", label: "Export Data") {
                        exportData()
                    }

                    Divider()
                        .background(Color.white.opacity(0.05))
                        .padding(.vertical, 4)
                    
                    SettingsActionRow(icon: "trash", label: "Reset All Data", isDestructive: true) {
                        showingResetConfirmation = true
                    }
                }
                .padding(4)
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "About App")
            
            GlassCard {
                VStack(spacing: 16) {
                    // App icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.primary.opacity(0.2))
                            .frame(width: 48, height: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: AppColors.primary.opacity(0.2), radius: 8)
                        
                        Image(systemName: "scope")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(AppColors.primary)
                    }
                    
                    // Name and version
                    VStack(spacing: 4) {
                        Text("Private Habit Tracker")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Version \(settings.appVersion) (Build \(settings.buildNumber))")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AppColors.textMuted)
                    }
                    
                    // Privacy statement
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "shield")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.top, 2)
                        
                        Text("Your data is stored locally on this device. We do not track your activity or sell your information.")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(2)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Danger Zone Section
    
    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Danger Zone")
            
            VStack(spacing: 0) {
                // Warning message
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.red.opacity(0.7))
                        .padding(.top, 2)
                    
                    Text("Deleting your account is permanent and cannot be undone. All your data will be lost.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                        .lineSpacing(2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.red.opacity(0.15), lineWidth: 1)
                )
                .padding(.bottom, 16)
                
                // Delete account button
                Button {
                    deleteAccountStep = 1
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.minus")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Delete Account")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Spacer()
                        
                        if isDeletingAccount {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.red.opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount)
                .shadow(color: Color.red.opacity(0.3), radius: 12, y: 4)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(.ultraThinMaterial.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.red.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Bottom Navigation
    
    private var bottomNavigation: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, AppColors.backgroundDark.opacity(0.8), AppColors.backgroundDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)
            
            TabBar(selectedTab: $selectedTab)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.md)
                .background(AppColors.backgroundDark)
        }
    }
    
    // MARK: - Data Management
    
    private func exportData() {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        
        let header = """
        HABIT TRACKER DATA EXPORT
        Generated: \(dateFormatter.string(from: date))
        User: \(settings.userName)
        
        ==================================================
        """
        
        // 1. Fetch Goals (Tasks)
        var goalsSection = "\n\n--- YOUR TASKS ---\n"
        let goalsDescriptor = FetchDescriptor<GoalModel>(sortBy: [SortDescriptor(\.createdAt)])
        if let goals = try? modelContext.fetch(goalsDescriptor), !goals.isEmpty {
            for goal in goals {
                goalsSection += "- \(goal.title)\n"
                goalsSection += "  Frequency: \(goal.recurrenceText)\n"
                if let time = goal.timeText {
                    goalsSection += "  Time: \(time)\n"
                }
                goalsSection += "  Status: \(goal.status.capitalized)\n"
                goalsSection += "\n"
            }
        } else {
            goalsSection += "No tasks found.\n"
        }
        
        // 2. Fetch Weekly Notes
        var notesSection = "\n--- WEEKLY NOTES ---\n"
        let notesDescriptor = FetchDescriptor<WeeklyNoteModel>(sortBy: [
            SortDescriptor(\.year, order: .reverse),
            SortDescriptor(\.month, order: .reverse),
            SortDescriptor(\.weekIndex, order: .reverse)
        ])
        
        if let notes = try? modelContext.fetch(notesDescriptor), !notes.isEmpty {
            for note in notes {
                // Determine month name for header
                let monthName = DateFormatter().monthSymbols[note.month - 1]
                notesSection += "Week \(note.weekIndex), \(monthName) \(note.year)\n"
                notesSection += "----------------------------\n"
                notesSection += note.text.trimmingCharacters(in: .whitespacesAndNewlines)
                notesSection += "\n\n"
            }
        } else {
            notesSection += "No weekly notes found.\n"
        }
        
        // 3. Calculate Stats
        // We need to use StatsCalculator. Since we are in a View, we are on MainActor.
        let calculator = StatsCalculator(modelContext: modelContext)
        var statsSection = "\n--- STATISTICS ---\n"
        
        // Yearly Stats
        let yearly = calculator.yearlyStats()
        statsSection += "Yearly Completion: \(Int(yearly.completedPercent * 100))%\n"
        
        // Monthly Stats
        let monthly = calculator.monthProgress()
        statsSection += "Current Month (\(monthly.monthName) \(monthly.year)):\n"
        statsSection += "  Completion: \(Int(monthly.completedPercent * 100))%\n"
        statsSection += "  Completed: \(monthly.completed)\n"
        statsSection += "  Missed: \(monthly.missed)\n"
        
        // Lifetime Missed
        let missed = calculator.lifetimeMissed()
        statsSection += "\nLifetime Missed Obligations: \(missed)\n"
        
        // Consistency Table
        statsSection += "\nGoal Consistency:\n"
        let consistency = calculator.goalConsistencyTable()
        if !consistency.isEmpty {
            for entry in consistency {
                statsSection += "- \(entry.title): \(Int(entry.consistency * 100))%\n"
            }
        } else {
            statsSection += "No consistency data available.\n"
        }
        
        // Assemble Final Text
        let finalOutput = header + goalsSection + notesSection + statsSection
        
        // Write to file
        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("HabitTracker_Export.txt")
            try finalOutput.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = tempURL
            showingExportSheet = true
        } catch {
            print("Export failed: \(error)")
        }
    }
    
    private func resetAllData() {
        Task {
            // 1. Delete from Supabase (if cloud sync is enabled)
            if SyncService.shared.isCloudSyncEnabled {
                do {
                    try await SupabaseService.shared.resetUserData()
                } catch {
                    print("Failed to reset Supabase data: \(error)")
                }
            }
            
            // 2. Clear local SwiftData
            await MainActor.run {
                do {
                    try modelContext.delete(model: ObligationModel.self)
                    try modelContext.delete(model: GoalModel.self)
                    try modelContext.delete(model: CategoryModel.self)
                    try modelContext.delete(model: WeeklyNoteModel.self)
                    try modelContext.save()
                    print("✅ Local data reset successfully")
                } catch {
                    print("Failed to reset local data: \(error)")
                }
                
                // 3. Reset settings (but keep user logged in)
                settings.resetAllData()
            }
        }
    }
    
    private func performDeleteAccount() {
        isDeletingAccount = true
        
        Task {
            // Deletion logic handled by manager (Remote + Local Wipe)
            do {
                try await AppSessionManager.shared.deleteAccount(modelContext: modelContext)
            } catch {
                print("Failed to delete account data: \(error)")
                // If it fails, we still want to log out in UI?
                // For now, just reset the spinner.
                await MainActor.run { isDeletingAccount = false }
            }
        }
    }
    
    private func performLogout() {
        isLoggingOut = true
        
        Task {
            // 1. Freeze sync explicitly
            await MainActor.run {
                AppSessionManager.shared.beginLogout()
            }
            
            // 2. Complete logout (Keep Local Data - Flow 6A)
            await AppSessionManager.shared.completeLogout()
            
            await MainActor.run {
                isLoggingOut = false
            }
        }
    }
    
    private func clearAllLocalData() {
        do {
            try modelContext.delete(model: GoalModel.self)
            try modelContext.delete(model: CategoryModel.self)
            try modelContext.delete(model: ObligationModel.self)
            try modelContext.delete(model: WeeklyNoteModel.self)
            try modelContext.save()
        } catch {
            print("Failed to clear local data: \(error)")
        }
    }
}

// MARK: - Glass Card Highlight

struct GlassCardHighlight<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(.ultraThinMaterial.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }
}

// MARK: - Glass Card Muted

struct GlassCardMuted<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(.ultraThinMaterial.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.03), lineWidth: 1)
            )
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - RTS Confirmation Alert

/// Custom glassmorphism confirmation alert matching RTS design
struct RTSConfirmationAlert: View {
    @Binding var isPresented: Bool
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let confirmText: String
    let confirmColor: Color
    let onConfirm: () -> Void
    
    var body: some View {
        if isPresented {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isPresented = false
                        }
                    }
                
                // Alert card
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("CONFIRMATION")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Color.white.opacity(0.7))
                        
                        Spacer()
                        
                        Text("SECURITY")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(iconColor.opacity(0.16))
                            .frame(width: 72, height: 72)
                        
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(iconColor.opacity(0.35), lineWidth: 1)
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(iconColor)
                    }
                    .shadow(color: iconColor.opacity(0.35), radius: 16)
                    
                    // Text content
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(message)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    
                    // Buttons
                    VStack(spacing: 10) {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isPresented = false
                            }
                            onConfirm()
                        } label: {
                            Text(confirmText)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.black.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color.white, Color.white.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .shadow(color: Color.white.opacity(0.2), radius: 14, y: 6)
                        
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isPresented = false
                            }
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(28)
                .background(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.35), AppColors.primary.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
                .padding(.horizontal, 36)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.easeOut(duration: 0.2), value: isPresented)
        }
    }
}

// MARK: - Multi-Step Delete Account Flow

/// Two-step account deletion confirmation
struct RTSDeleteAccountFlow: View {
    @Binding var step: Int  // 0 = hidden, 1 = first warning, 2 = final confirmation
    @Binding var isDeleting: Bool
    let onDelete: () -> Void
    
    var body: some View {
        if step > 0 {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.75)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            step = 0
                        }
                    }
                
                // Step content
                if step == 1 {
                    stepOneContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                } else if step == 2 {
                    stepTwoContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: step)
        }
    }
    
    // MARK: - Step 1: First Warning
    
    private var stepOneContent: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("DELETE ACCOUNT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color.white.opacity(0.7))
                
                Spacer()
                
                Text("STEP 1 OF 2")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color.white.opacity(0.7))
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.orange.opacity(0.18))
                    .frame(width: 80, height: 80)
                
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color.orange)
            }
            .shadow(color: Color.orange.opacity(0.35), radius: 20)
            
            VStack(spacing: 10) {
                Text("Are you sure?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text("This will permanently delete your account including all your goals, progress, and settings.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            
            VStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        step = 2
                    }
                } label: {
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .shadow(color: Color.white.opacity(0.2), radius: 12, y: 6)
                
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        step = 0
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .background(
            LinearGradient(
                colors: [AppColors.primary.opacity(0.35), AppColors.primary.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.ultraThinMaterial.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
        .padding(.horizontal, 36)
    }
    
    // MARK: - Step 2: Final Confirmation
    
    private var stepTwoContent: some View {
        VStack(spacing: 20) {
            HStack {
                Text("DELETE ACCOUNT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color.white.opacity(0.7))
                
                Spacer()
                
                Text("STEP 2 OF 2")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color.white.opacity(0.7))
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.red.opacity(0.18))
                    .frame(width: 80, height: 80)
                
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "trash.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color.red)
            }
            .shadow(color: Color.red.opacity(0.35), radius: 20)
            
            VStack(spacing: 10) {
                Text("Final Confirmation")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text("This action is irreversible. Your account and all data will be permanently deleted.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            
            VStack(spacing: 10) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        step = 0
                    }
                    onDelete()
                } label: {
                    HStack(spacing: 8) {
                        if isDeleting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(isDeleting ? "Deleting..." : "Delete My Account")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(Color.black.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
                .shadow(color: Color.white.opacity(0.2), radius: 12, y: 6)
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        step = 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                        Text("Go Back")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .background(
            LinearGradient(
                colors: [AppColors.primary.opacity(0.35), AppColors.primary.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.ultraThinMaterial.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
        .padding(.horizontal, 36)
    }
}

// MARK: - Preview

#Preview {
    SettingsView(selectedTab: .constant(.settings))
}
