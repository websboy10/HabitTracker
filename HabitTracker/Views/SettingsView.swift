import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

/// Settings view following HTML reference design
struct SettingsView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: Tab
    @State private var settings = SettingsStore.shared
    var showsCustomTabBar: Bool = true
    
    // Calendar service for permissions (requires adding CalendarService.swift to Xcode project)
    // @StateObject private var calendarService = CalendarService.shared
    
    // Time picker state
    @State private var showingTimePicker = false
    @State private var showingNotificationSettings = false
    @State private var notificationsEnabled = NotificationEngine.shared.globallyEnabled
    @State private var defaultNotificationTime = NotificationEngine.shared.defaultNotificationTime
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    // Report notification toggles
    @State private var dailyReportEnabled = ReportNotificationStore.dailyReportEnabled
    @State private var weeklyReportEnabled = ReportNotificationStore.weeklyReportEnabled
    @State private var monthlyReportEnabled = ReportNotificationStore.monthlyReportEnabled

    // Time picker sheets
    @State private var showingDefaultTimePicker = false
    @State private var showingDailyTimePicker = false
    @State private var showingWeeklyTimePicker = false
    @State private var showingMonthlyTimePicker = false

    // Report notification times
    @State private var dailyReportTime: Date = ReportNotificationStore.dailyReportTime
    @State private var weeklyReportTime: Date = ReportNotificationStore.weeklyReportTime
    @State private var monthlyReportTime: Date = ReportNotificationStore.monthlyReportTime
    
    // Data management state
    @State private var showingResetConfirmation = false
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var exportState: ExportState = .loading
    @State private var exportNotice: String?
    @State private var showingShareSheet = false
    
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

            // Scrollable content with automatic scroll reset
            ResetScrollView(viewName: "SettingsView", showsIndicators: false) {
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

                    // Permissions
                    permissionsSection
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
        .onAppear {
            NavigationLogger.shared.logViewAppear("SettingsView")
        }
        .onDisappear {
            NavigationLogger.shared.logViewDisappear("SettingsView")
        }
        .sheet(isPresented: $showingTimePicker) {
            timePickerSheet
        }
        .sheet(isPresented: $showingNotificationSettings) {
            notificationSettingsSheet
        }
        .sheet(isPresented: $showingExportSheet) {
            exportSheet
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
        .task {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                return
            }
            await refreshNotificationStatus()
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
    
    // MARK: - Permissions Section

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionHeader(title: "Permissions")

            GlassCard {
                VStack(spacing: 0) {
                    // Notifications settings row
                    Button {
                        showingNotificationSettings = true
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(notificationsEnabled ? AppColors.primary.opacity(0.2) : Color.white.opacity(0.05))
                                    .frame(width: 40, height: 40)

                                Image(systemName: "bell")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(notificationsEnabled ? AppColors.primary : AppColors.textMuted)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notifications")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)

                                Text(notificationStatusText)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppColors.textMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @MainActor
    private func refreshNotificationStatus() async {
        let storedEnabled = NotificationEngine.shared.globallyEnabled
        defaultNotificationTime = NotificationEngine.shared.defaultNotificationTime
        notificationAuthorizationStatus = await NotificationEngine.shared.authorizationStatus()
        notificationsEnabled = storedEnabled && notificationAuthorizationStatus == .authorized
    }

    @MainActor
    private func handleNotificationToggleChange(_ isEnabled: Bool) async {
        if isEnabled {
            let granted = await NotificationEngine.shared.requestAuthorizationFromSettings()
            notificationAuthorizationStatus = await NotificationEngine.shared.authorizationStatus()
            if !granted {
                notificationsEnabled = false
            }
        }
        await applyNotificationSettings()
    }

    @MainActor
    private func applyNotificationSettings() async {
        await NotificationEngine.shared.applyGlobalSettings(
            enabled: notificationsEnabled,
            defaultTime: defaultNotificationTime,
            modelContext: modelContext
        )
        await refreshNotificationStatus()
    }

    private var notificationStatusText: String {
        if notificationAuthorizationStatus == .denied {
            return "Disabled in system settings"
        }
        if !notificationsEnabled {
            return "Notifications turned off"
        }
        return "Default \(notificationTimeFormatted)"
    }

    private var notificationTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: defaultNotificationTime)
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

    // MARK: - Notification Settings Sheet

    private var notificationSettingsSheet: some View {
        NavigationStack {
            notificationSettingsContent
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingNotificationSettings = false }
                            .foregroundColor(AppColors.primary)
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .task {
                    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                        return
                    }
                    notificationsEnabled = NotificationEngine.shared.globallyEnabled
                    defaultNotificationTime = NotificationEngine.shared.defaultNotificationTime
                    // Load report toggle states
                    dailyReportEnabled = ReportNotificationStore.dailyReportEnabled
                    weeklyReportEnabled = ReportNotificationStore.weeklyReportEnabled
                    monthlyReportEnabled = ReportNotificationStore.monthlyReportEnabled
                    await refreshNotificationStatus()
                }
                .onChange(of: notificationsEnabled) { _, newValue in
                    Task { await handleNotificationToggleChange(newValue) }
                }
                .onChange(of: defaultNotificationTime) { _, _ in
                    Task { await applyNotificationSettings() }
                }
                .onChange(of: dailyReportEnabled) { _, newValue in
                    if newValue {
                        showingDailyTimePicker = true
                    }
                    Task { await handleReportToggleChange(.daily, enabled: newValue) }
                }
                .onChange(of: weeklyReportEnabled) { _, newValue in
                    if newValue {
                        showingWeeklyTimePicker = true
                    }
                    Task { await handleReportToggleChange(.weekly, enabled: newValue) }
                }
                .onChange(of: monthlyReportEnabled) { _, newValue in
                    if newValue {
                        showingMonthlyTimePicker = true
                    }
                    Task { await handleReportToggleChange(.monthly, enabled: newValue) }
                }
        }
        .presentationDetents([.height(520), .large])
    }

    // MARK: - Export Sheet

    private var exportSheet: some View {
        ExportSheetView(
            state: exportState,
            exportNotice: $exportNotice,
            exportURL: exportURL,
            showingShareSheet: $showingShareSheet,
            onPrepare: { await prepareExport() },
            onExport: { exportNow() },
            onClose: { showingExportSheet = false }
        )
        .presentationDetents([.height(520), .large])
    }

    private var notificationSettingsContent: some View {
        ZStack {
            AppMaterials.moodGradient.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    SettingsSectionHeader(title: "Notifications")
                    notificationToggleCard
                    notificationDeniedCard

                    SettingsSectionHeader(title: "Reports Notifications")
                    reportNotificationsCard
                }
                .padding(AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
            }
        }
    }

    private var notificationToggleCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "bell.badge",
                    label: "Enable Notifications",
                    isOn: $notificationsEnabled,
                    reduceMotion: settings.reduceMotion
                )

                Divider()
                    .background(Color.white.opacity(0.05))

                // Default time button (opens wheel picker sheet)
                Button { showingDefaultTimePicker = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Time")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textPrimary.opacity(0.9))

                            Text("When to remind you")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            Text(defaultNotificationTimeFormatted)
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
                }
                .buttonStyle(.plain)
                .disabled(!notificationsEnabled)
                .opacity(notificationsEnabled ? 1.0 : 0.5)
                .padding(16)
            }
        }
        .sheet(isPresented: $showingDefaultTimePicker) {
            defaultTimePickerSheet
        }
    }

    private var defaultTimePickerSheet: some View {
        NavigationStack {
            ZStack {
                AppMaterials.moodGradient.ignoresSafeArea()

                DatePicker(
                    "Default Time",
                    selection: $defaultNotificationTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
            }
            .navigationTitle("Default Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingDefaultTimePicker = false }
                        .foregroundColor(AppColors.primary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.height(300)])
    }

    private var defaultNotificationTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: defaultNotificationTime)
    }

    @ViewBuilder
    private var notificationDeniedCard: some View {
        if notificationAuthorizationStatus == .denied {
            GlassCardMuted {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notifications are disabled in system settings.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                    Button {
                        NotificationEngine.shared.openSystemSettings()
                    } label: {
                        Text("Open Settings")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppColors.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
        }
    }

    // MARK: - Report Notifications Card

    private var reportNotificationsCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                // Daily Report Toggle
                reportToggleRow(
                    type: .daily,
                    isOn: $dailyReportEnabled
                )

                Divider()
                    .background(Color.white.opacity(0.05))

                // Weekly Report Toggle
                reportToggleRow(
                    type: .weekly,
                    isOn: $weeklyReportEnabled
                )

                Divider()
                    .background(Color.white.opacity(0.05))

                // Monthly Report Toggle
                reportToggleRow(
                    type: .monthly,
                    isOn: $monthlyReportEnabled
                )
            }
        }
        .opacity(reportTogglesDisabled ? 0.5 : 1.0)
        .sheet(isPresented: $showingDailyTimePicker) {
            reportTimePickerSheet(type: .daily, time: $dailyReportTime)
        }
        .sheet(isPresented: $showingWeeklyTimePicker) {
            reportTimePickerSheet(type: .weekly, time: $weeklyReportTime)
        }
        .sheet(isPresented: $showingMonthlyTimePicker) {
            reportTimePickerSheet(type: .monthly, time: $monthlyReportTime)
        }
    }

    private func reportTimePickerSheet(
        type: ReportNotificationStore.ReportType,
        time: Binding<Date>
    ) -> some View {
        NavigationStack {
            ZStack {
                AppMaterials.moodGradient.ignoresSafeArea()

                DatePicker(
                    type.displayName,
                    selection: time,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
            }
            .navigationTitle(type.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { closeReportTimePicker(for: type) }
                        .foregroundColor(AppColors.primary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.height(300)])
    }

    private func closeReportTimePicker(for type: ReportNotificationStore.ReportType) {
        switch type {
        case .daily:
            showingDailyTimePicker = false
            ReportNotificationStore.dailyReportTime = dailyReportTime
        case .weekly:
            showingWeeklyTimePicker = false
            ReportNotificationStore.weeklyReportTime = weeklyReportTime
        case .monthly:
            showingMonthlyTimePicker = false
            ReportNotificationStore.monthlyReportTime = monthlyReportTime
        }
        // Reschedule the notification with new time
        Task {
            await NotificationEngine.shared.setReportNotificationEnabled(type, enabled: true, modelContext: modelContext)
        }
    }

    private func reportToggleRow(
        type: ReportNotificationStore.ReportType,
        isOn: Binding<Bool>
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 32, height: 32)

                    Image(systemName: type.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }

                // Label
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary.opacity(0.9))

                    Text(reportDescription(for: type))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                // Toggle
                Toggle("", isOn: isOn)
                    .toggleStyle(GlassToggleStyle(reduceMotion: settings.reduceMotion))
                    .labelsHidden()
                    .disabled(reportTogglesDisabled)
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                if reportTogglesDisabled {
                    handleReportToggleBlockedTap()
                }
            }

            // Time picker button (shown when enabled)
            if isOn.wrappedValue {
                Divider()
                    .background(Color.white.opacity(0.05))

                reportTimeButton(for: type)
            }
        }
    }

    private func reportTimeButton(for type: ReportNotificationStore.ReportType) -> some View {
        Button { openReportTimePicker(for: type) } label: {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.primary)

                    Text("Notification Time")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary.opacity(0.9))
                }

                Spacer()

                HStack(spacing: 12) {
                    Text(reportTimeFormatted(for: type))
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
        }
        .buttonStyle(.plain)
        .padding(16)
    }

    private func reportTimeFormatted(for type: ReportNotificationStore.ReportType) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let time: Date
        switch type {
        case .daily: time = dailyReportTime
        case .weekly: time = weeklyReportTime
        case .monthly: time = monthlyReportTime
        }
        return formatter.string(from: time)
    }

    private func openReportTimePicker(for type: ReportNotificationStore.ReportType) {
        switch type {
        case .daily: showingDailyTimePicker = true
        case .weekly: showingWeeklyTimePicker = true
        case .monthly: showingMonthlyTimePicker = true
        }
    }

    private func reportDescription(for type: ReportNotificationStore.ReportType) -> String {
        switch type {
        case .daily: return "Daily reminder"
        case .weekly: return "Every Sunday"
        case .monthly: return "1st of each month"
        }
    }

    /// Returns true if report toggles should be disabled (no permission or notifications off)
    private var reportTogglesDisabled: Bool {
        notificationAuthorizationStatus == .denied || !notificationsEnabled
    }

    /// Handles tap on disabled report toggle - prompts for permission
    private func handleReportToggleBlockedTap() {
        if notificationAuthorizationStatus == .denied {
            NotificationEngine.shared.openSystemSettings()
        } else if notificationAuthorizationStatus == .notDetermined {
            Task {
                let granted = await NotificationEngine.shared.requestAuthorizationFromSettings()
                await refreshNotificationStatus()
                if !granted {
                    SyncLogger.logNotification("Report toggle tap: permission denied")
                }
            }
        }
    }

    /// Handles report toggle state change
    private func handleReportToggleChange(_ type: ReportNotificationStore.ReportType, enabled: Bool) async {
        // Double-check permission gating
        guard notificationAuthorizationStatus == .authorized else {
            SyncLogger.logNotification("Report toggle blocked: permission not authorized", level: .warning)
            // Revert the toggle
            await MainActor.run {
                switch type {
                case .daily: dailyReportEnabled = false
                case .weekly: weeklyReportEnabled = false
                case .monthly: monthlyReportEnabled = false
                }
            }
            return
        }

        guard notificationsEnabled else {
            SyncLogger.logNotification("Report toggle blocked: notifications globally disabled", level: .warning)
            // Revert the toggle
            await MainActor.run {
                switch type {
                case .daily: dailyReportEnabled = false
                case .weekly: weeklyReportEnabled = false
                case .monthly: monthlyReportEnabled = false
                }
            }
            return
        }

        // Apply the change through NotificationEngine
        await NotificationEngine.shared.setReportNotificationEnabled(type, enabled: enabled, modelContext: modelContext)
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
        exportState = .loading
        exportNotice = nil
        exportURL = nil
        showingExportSheet = true
    }

    @MainActor
    private func prepareExport() async {
        exportNotice = nil
        exportURL = nil

        if let reason = exportUnavailableReason() {
            exportState = .unavailable(reason)
            return
        }

        let plan = buildExportPlan()

        guard !plan.includedMonths.isEmpty || plan.goalsCount > 0 || plan.notesCount > 0 else {
            exportState = .unavailable(.noData)
            return
        }

        for month in plan.archivedMonths {
            guard SnapshotService.shared.fetchSnapshot(
                year: month.year,
                month: month.month,
                in: modelContext
            ) != nil else {
                exportState = .error("An archived month could not be loaded.")
                return
            }
        }

        exportState = .ready(plan)
    }

    @MainActor
    private func exportNow() {
        guard case .ready(let plan) = exportState else { return }

        if AuthEngine.shared.state != .authenticated {
            exportState = .unavailable(.unauthenticated)
            return
        }

        if AppSessionManager.shared.state != .running {
            exportState = .unavailable(.lifecycleInactive)
            return
        }

        if AppSessionManager.shared.securityLock {
            exportState = .unavailable(.securityLocked)
            return
        }

        _ = RuntimeGuard.requireAuthenticatedRunning()

        do {
            let url = try buildExportFile(from: plan)
            exportURL = url
            showingShareSheet = true
            exportNotice = "Export file is ready."
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.exportNotice = nil
            }
        } catch {
            exportState = .error("We couldn't prepare the export file.")
        }
    }

    private func exportUnavailableReason() -> ExportUnavailableReason? {
        if AuthEngine.shared.state != .authenticated {
            return .unauthenticated
        }
        if AppSessionManager.shared.state != .running {
            return .lifecycleInactive
        }
        if AppSessionManager.shared.securityLock {
            return .securityLocked
        }
        return nil
    }

    @MainActor
    private func buildExportPlan() -> ExportPlan {
        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        let liveMonth = ExportMonth(year: currentYear, month: currentMonth, status: .live)

        let snapshotDescriptor = FetchDescriptor<SnapshotModel>(sortBy: [
            SortDescriptor(\.year, order: .reverse),
            SortDescriptor(\.month, order: .reverse)
        ])
        let snapshots = (try? modelContext.fetch(snapshotDescriptor)) ?? []

        var archivedMonths = snapshots
            .filter { $0.status == .available }
            .map { ExportMonth(year: $0.year, month: $0.month, status: .archived) }
            .filter { !$0.matches(liveMonth) }

        var excludedMonths = snapshots
            .filter { $0.status == .missingData }
            .map { ExportMonth(year: $0.year, month: $0.month, status: .missing) }

        archivedMonths.sort { $0.sortKey > $1.sortKey }
        excludedMonths.sort { $0.sortKey > $1.sortKey }

        let goalsCount = (try? modelContext.fetchCount(FetchDescriptor<GoalModel>())) ?? 0
        let notesCount = (try? modelContext.fetchCount(FetchDescriptor<WeeklyNoteModel>())) ?? 0

        return ExportPlan(
            liveMonth: liveMonth,
            archivedMonths: archivedMonths,
            excludedMonths: excludedMonths,
            generatedAt: now,
            goalsCount: goalsCount,
            notesCount: notesCount
        )
    }

    @MainActor
    private func buildExportFile(from plan: ExportPlan) throws -> URL {
        let content = try buildExportContent(from: plan)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmm"
        let stamp = dateFormatter.string(from: plan.generatedAt)
        let filename = "HabitTracker_Export_\(stamp).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    @MainActor
    private func buildExportContent(from plan: ExportPlan) throws -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        var output = """
        HABIT TRACKER DATA EXPORT
        Generated: \(dateFormatter.string(from: plan.generatedAt))
        User: \(settings.userName)

        ==================================================

        EXPORT SCOPE
        """

        output += "\nIncluded Months:\n"
        for month in plan.includedMonths {
            output += "- \(month.label) (\(month.statusLabel))\n"
        }

        if !plan.excludedMonths.isEmpty {
            output += "\nExcluded Months (Archived data unavailable):\n"
            for month in plan.excludedMonths {
                output += "- \(month.label)\n"
            }
        }

        // Goals
        output += "\n\n--- YOUR TASKS ---\n"
        let goalsDescriptor = FetchDescriptor<GoalModel>(sortBy: [SortDescriptor(\.createdAt)])
        if let goals = try? modelContext.fetch(goalsDescriptor), !goals.isEmpty {
            for goal in goals {
                output += "- \(goal.title)\n"
                output += "  Frequency: \(goal.recurrenceText)\n"
                if let time = goal.timeText {
                    output += "  Time: \(time)\n"
                }
                output += "  Status: \(goal.status.capitalized)\n"
                output += "\n"
            }
        } else {
            output += "No tasks found.\n"
        }

        // Weekly Notes
        output += "\n--- WEEKLY NOTES ---\n"
        let notesDescriptor = FetchDescriptor<WeeklyNoteModel>(sortBy: [
            SortDescriptor(\.year, order: .reverse),
            SortDescriptor(\.month, order: .reverse),
            SortDescriptor(\.weekIndex, order: .reverse)
        ])

        if let notes = try? modelContext.fetch(notesDescriptor), !notes.isEmpty {
            for note in notes {
                let monthName = DateFormatter().monthSymbols[note.month - 1]
                output += "Week \(note.weekIndex), \(monthName) \(note.year)\n"
                output += "----------------------------\n"
                output += note.text.trimmingCharacters(in: .whitespacesAndNewlines)
                output += "\n\n"
            }
        } else {
            output += "No weekly notes found.\n"
        }

        // Monthly Summaries
        output += "\n--- MONTHLY SUMMARY ---\n"
        let statsCalculator = StatsCalculator(modelContext: modelContext)

        for month in plan.includedMonths {
            output += "\n\(month.label) (\(month.statusLabel))\n"
            output += "----------------------------\n"

            if month.status == .live {
                let stats = statsCalculator.monthProgress(for: month.date)
                output += "Completion: \(Int(stats.completedPercent * 100))%\n"
                output += "Completed: \(stats.completed)\n"
                output += "Missed: \(stats.missed)\n"
                output += "Total: \(stats.totalObligations)\n"

                let ledger = statsCalculator.monthlyWeekLedger(for: month.date)
                output += "Weekly Ledger:\n"
                if ledger.isEmpty {
                    output += "- No weekly data\n"
                } else {
                    for entry in ledger {
                        let status = entry.passed ? "Passed" : "Incomplete"
                        output += "- Week \(entry.weekNumber): \(entry.completed)/\(entry.totalObligations) (\(status))\n"
                    }
                }
            } else {
                guard let snapshot = SnapshotService.shared.fetchSnapshot(
                    year: month.year,
                    month: month.month,
                    in: modelContext
                ) else {
                    throw ExportPreparationError.missingSnapshot(month)
                }

                let stats = snapshot.stats
                output += "Completion: \(Int(stats.completedPercent * 100))%\n"
                output += "Completed: \(stats.completed)\n"
                output += "Missed: \(stats.missed)\n"
                output += "Total: \(stats.totalObligations)\n"

                output += "Weekly Ledger:\n"
                if snapshot.ledger.isEmpty {
                    output += "- No weekly data\n"
                } else {
                    for entry in snapshot.ledger {
                        let status = entry.passed ? "Passed" : "Incomplete"
                        output += "- Week \(entry.week): \(entry.completed)/\(entry.total) (\(status))\n"
                    }
                }
            }
        }

        return output
    }
    
    private func resetAllData() {
        Task {
            do {
                await NotificationEngine.shared.cancelAllNotifications(reason: "reset-all-data")
                NotificationEngine.shared.resetNotificationSettingsToDefaults()

                // Use DataService for atomic reset (local + cloud)
                // This preserves auth, settings, and onboarding state
                try await DataService.shared.resetAllData(in: modelContext)
                SyncLogger.logAccount("Reset all data completed via SettingsView")
                
                await MainActor.run {
                    // Reset settings defaults (but keep user logged in)
                    settings.resetAllData()
                }
            } catch {
                SyncLogger.logAccount("Reset all data failed: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    private func performDeleteAccount() {
        isDeletingAccount = true
        
        Task {
            do {
                try await AppSessionManager.shared.deleteAccount(modelContext: modelContext)
                // If success, AppSessionManager sets state to .unauthenticated
                // which will trigger navigation away from settings
            } catch {
                // Delete failed - show error and reset UI
                SyncLogger.logAccount("Delete account failed from SettingsView: \(error.localizedDescription)", level: .error)
                await MainActor.run { 
                    isDeletingAccount = false 
                    deleteAccountStep = 0
                }
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

// MARK: - Export Models

private enum ExportState: Equatable {
    case loading
    case ready(ExportPlan)
    case unavailable(ExportUnavailableReason)
    case error(String)
}

private enum ExportUnavailableReason: Equatable {
    case unauthenticated
    case lifecycleInactive
    case securityLocked
    case noData

    var title: String {
        switch self {
        case .unauthenticated:
            return "Sign in required"
        case .lifecycleInactive:
            return "Export unavailable"
        case .securityLocked:
            return "Export unavailable"
        case .noData:
            return "No exportable data"
        }
    }

    var message: String {
        switch self {
        case .unauthenticated:
            return "You must be signed in to export data."
        case .lifecycleInactive:
            return "Export is unavailable while the app is not running."
        case .securityLocked:
            return "Export is unavailable while the app is locked."
        case .noData:
            return "No months are eligible for export."
        }
    }
}

private enum ExportPreparationError: Error {
    case missingSnapshot(ExportMonth)
}

private struct ExportPlan: Equatable {
    let liveMonth: ExportMonth
    let archivedMonths: [ExportMonth]
    let excludedMonths: [ExportMonth]
    let generatedAt: Date
    let goalsCount: Int
    let notesCount: Int

    var includedMonths: [ExportMonth] {
        [liveMonth] + archivedMonths
    }
}

private struct ExportMonth: Identifiable, Hashable {
    let year: Int
    let month: Int
    let status: ExportMonthStatus

    var id: String { String(format: "%04d-%02d", year, month) }

    var sortKey: Int { year * 100 + month }

    var date: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    var label: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    var statusLabel: String {
        switch status {
        case .live:
            return "Live"
        case .archived:
            return "Archived"
        case .missing:
            return "Unavailable"
        }
    }

    func matches(_ other: ExportMonth) -> Bool {
        year == other.year && month == other.month
    }
}

private enum ExportMonthStatus: Equatable {
    case live
    case archived
    case missing
}

// MARK: - Export Sheet View

private struct ExportSheetView: View {
    let state: ExportState
    @Binding var exportNotice: String?
    let exportURL: URL?
    @Binding var showingShareSheet: Bool
    let onPrepare: () async -> Void
    let onExport: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppMaterials.moodGradient.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        content
                    }
                    .padding(AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onClose() }
                        .foregroundColor(AppColors.primary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                    return
                }
                await onPrepare()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            loadingView
        case .ready(let plan):
            readyView(plan: plan)
        case .unavailable(let reason):
            unavailableView(reason: reason)
        case .error(let message):
            errorView(message: message)
        }
    }

    private var loadingView: some View {
        GlassCard {
            VStack(spacing: AppSpacing.md) {
                ProgressView()
                    .tint(AppColors.primary)
                Text("Preparing Export")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text("Validating session and collecting exportable months…")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppColors.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.lg)
        }
    }

    private func readyView(plan: ExportPlan) -> some View {
        VStack(spacing: AppSpacing.lg) {
            GlassCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Export Summary")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)

                    Text("Includes goals, weekly notes, and monthly summaries for the months below.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.lg)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Included Months")
                        .font(AppTypography.caption)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundColor(AppColors.textSecondary)

                    VStack(spacing: 10) {
                        ForEach(plan.includedMonths) { month in
                            exportMonthRow(month: month, tint: month.status == .live ? AppColors.primary : AppColors.textMuted)
                        }
                    }
                }
                .padding(AppSpacing.lg)
            }

            if !plan.excludedMonths.isEmpty {
                GlassCardMuted {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Excluded Months")
                            .font(AppTypography.caption)
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundColor(AppColors.textSecondary)

                        Text("Archived data unavailable")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AppColors.textMuted)

                        VStack(spacing: 10) {
                            ForEach(plan.excludedMonths) { month in
                                exportMonthRow(month: month, tint: AppColors.textMuted)
                            }
                        }
                    }
                    .padding(AppSpacing.lg)
                }
            }

            VStack(spacing: AppSpacing.sm) {
                Button(action: onExport) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Export")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.primary.opacity(0.9))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(showingShareSheet)

                if let exportNotice {
                    Text(exportNotice)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private func unavailableView(reason: ExportUnavailableReason) -> some View {
        GlassCardMuted {
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.textMuted)

                Text(reason.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text(reason.message)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppColors.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.lg)
        }
    }

    private func errorView(message: String) -> some View {
        GlassCardMuted {
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.red.opacity(0.8))

                Text("Export Failed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text(message)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppColors.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.lg)
        }
    }

    private func exportMonthRow(month: ExportMonth, tint: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(month.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                Text(month.statusLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(tint)
            }
            Spacer()
            exportStatusBadge(text: month.statusLabel, tint: tint)
        }
        .padding(.vertical, 6)
    }

    private func exportStatusBadge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
        .modelContainer(PreviewModelContainer.container)
}
