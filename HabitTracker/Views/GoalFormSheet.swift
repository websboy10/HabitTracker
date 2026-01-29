import SwiftUI
import SwiftData

/// Form sheet for creating or editing a goal with recurrence options.
struct GoalFormSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// The goal being edited (nil for new goal)
    let editingGoal: GoalModel?

    // Form state
    @State private var title: String = ""
    @State private var selectedCategory: GoalCategory?
    @State private var recurrenceType: String = "daily"
    @State private var selectedWeekdays: Set<Int> = []
    @State private var scheduledTime: Date = Date()
    @State private var hasScheduledTime: Bool = false
    @State private var notificationsEnabled: Bool = false
    @State private var useCustomNotificationTime: Bool = false
    @State private var notificationTime: Date = Date()
    @State private var defaultNotificationTime: Date = Date()
    @State private var monthlyDayOfMonth: Int = 1
    @State private var requiredCount: Int = 1
    @State private var status: String = "active"
    @State private var showRecurrenceOptions: Bool = true
    @State private var showDeleteConfirmation: Bool = false
    @State private var showNotificationTimePicker: Bool = false
    @State private var showNewCategoryPrompt: Bool = false
    @State private var newCategoryName: String = ""
    @State private var pendingLegacyCategoryName: String?
    @State private var pendingLegacyCategoryColorHex: String?
    @State private var didSeedCategories: Bool = false

    @Query(sort: \GoalCategory.createdAt, order: .forward) private var categories: [GoalCategory]

    @Namespace private var animation
    @FocusState private var isTextFieldFocused: Bool

    init(editingGoal: GoalModel?) {
        self.editingGoal = editingGoal
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppMaterials.moodGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Title
                        formSection("Title") {
                            TextField("Goal name", text: $title)
                                .textFieldStyle(GlassTextFieldStyle())
                                .focused($isTextFieldFocused)
                        }

                        // Category
                        formSection("Category") {
                            categoryPicker
                        }

                        // Scheduled Time (optional)
                        formSection("Time") {
                            timeSection
                        }

                        // Notifications
                        formSection("Notifications") {
                            notificationSection
                        }

                        // Daily Count (for multi-completion goals)
                        formSection("Daily Count") {
                            dailyCountSection
                        }

                        // Recurrence Toggle
                        repeatToggle

                        // Recurrence Options (expanded)
                        if showRecurrenceOptions {
                            recurrenceSection
                        }

                        // Status (only for editing)
                        if editingGoal != nil {
                            formSection("Status") {
                                statusToggle
                            }
                            
                            // Delete Goal Button (only for editing)
                            deleteGoalButton
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.md)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isTextFieldFocused = false
                }
            }
            .navigationTitle(editingGoal == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveGoal() }
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                        .disabled(title.isEmpty)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            seedSystemCategoriesIfNeeded()
            loadExistingGoal()
            resolveInitialCategorySelection()
        }
        .onChange(of: categories) { _, _ in
            resolveInitialCategorySelection()
        }
        .alert("New category", isPresented: $showNewCategoryPrompt) {
            TextField("Category name", text: $newCategoryName)
            Button("Cancel", role: .cancel) {
                newCategoryName = ""
            }
            Button("Create") {
                createCategory()
            }
            .disabled(!canCreateCategory)
        }
    }

    // MARK: - Form Sections

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
                .tracking(1)

            content()
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    categoryChip(category)
                }
                addCategoryButton
            }
        }
    }

    private func categoryChip(_ category: GoalCategory) -> some View {
        let isSelected = selectedCategory?.id == category.id
        let color = Color(hex: UInt(category.colorHex, radix: 16) ?? 0xD11A2A)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedCategory = category
            }
        } label: {
            Text(category.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(color)
                                .matchedGeometryEffect(id: "activeCategory", in: animation)
                        } else {
                            Capsule()
                                .fill(color.opacity(0.1))
                        }
                    }
                )
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var addCategoryButton: some View {
        Button {
            newCategoryName = ""
            showNewCategoryPrompt = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add category")
    }

    // MARK: - Time Section

    private var timeSection: some View {
        HStack {
            Toggle("", isOn: $hasScheduledTime)
                .tint(AppColors.primary)
                .labelsHidden()

            if hasScheduledTime {
                DatePicker("", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(AppColors.primary)
            } else {
                Text("No specific time")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textMuted)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Notifications Section

    private var notificationSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Enable Notifications")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Toggle("", isOn: $notificationsEnabled)
                    .tint(AppColors.primary)
                    .labelsHidden()
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if newValue {
                            // When enabling notifications, show the time picker sheet
                            showNotificationTimePicker = true
                        }
                    }
            }

            if notificationsEnabled {
                Divider()
                    .background(Color.white.opacity(0.08))

                // Notification time button (opens wheel picker sheet)
                Button { showNotificationTimePicker = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppColors.primary)

                                Text("Notification Time")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary.opacity(0.9))
                            }

                            Text("When to remind you")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            Text(notificationTimeFormatted)
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
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .sheet(isPresented: $showNotificationTimePicker) {
            notificationTimePickerSheet
        }
    }

    // MARK: - Notification Time Picker Sheet

    private var notificationTimePickerSheet: some View {
        NavigationStack {
            ZStack {
                AppMaterials.moodGradient.ignoresSafeArea()

                DatePicker(
                    "Notification Time",
                    selection: $notificationTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
            }
            .navigationTitle("Notification Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showNotificationTimePicker = false }
                        .foregroundColor(AppColors.primary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.height(300)])
    }

    // MARK: - Daily Count Section

    private var dailyCountSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Times per day")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                // Stepper-style count selector
                HStack(spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            requiredCount = max(1, requiredCount - 1)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(requiredCount > 1 ? AppColors.primary : AppColors.textMuted)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.05))
                    }
                    .disabled(requiredCount <= 1)

                    Text("\(requiredCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 44, height: 36)
                        .background(Color.white.opacity(0.08))
                        .monospacedDigit()

                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            requiredCount = min(99, requiredCount + 1)
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.05))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }

            // Helper text
            if requiredCount > 1 {
                Text("Complete this goal \(requiredCount) times each day")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Repeat Toggle

    private var repeatToggle: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showRecurrenceOptions.toggle()
                if showRecurrenceOptions && recurrenceType == "none" {
                    recurrenceType = "daily"
                } else if !showRecurrenceOptions {
                    recurrenceType = "none"
                }
            }
        } label: {
            HStack {
                Image(systemName: "repeat")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(showRecurrenceOptions ? AppColors.primary : AppColors.textSecondary)

                Text("Repeat")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Image(systemName: showRecurrenceOptions ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(16)
            .background(showRecurrenceOptions ? AppColors.primary.opacity(0.1) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(showRecurrenceOptions ? AppColors.primary.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recurrence Section

    private var recurrenceSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Recurrence Type Picker
            formSection("Recurrence") {
                recurrenceTypePicker
            }

            // Weekday Selector (for weekly)
            if recurrenceType == "weekly" {
                formSection("Days") {
                    weekdaySelector
                }
            }

            // Day of Month (for monthly)
            if recurrenceType == "monthly" {
                formSection("Day of Month") {
                    monthlyDayPicker
                }
            }

        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var recurrenceTypePicker: some View {
        HStack(spacing: 8) {
            ForEach(["daily", "weekly", "monthly"], id: \.self) { type in
                recurrenceTypeButton(type)
            }
        }
    }

    private func recurrenceTypeButton(_ type: String) -> some View {
        let isSelected = recurrenceType == type

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                recurrenceType = type
            }
        } label: {
            Text(type.capitalized)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppColors.primary)
                                .matchedGeometryEffect(id: "activeRecurrence", in: animation)
                        } else {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private var weekdaySelector: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                weekdayButton(day)
            }
        }
    }

    private func weekdayButton(_ day: Int) -> some View {
        let isSelected = selectedWeekdays.contains(day)
        let dayLabel = ["M", "T", "W", "T", "F", "S", "S"][day - 1]

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    selectedWeekdays.remove(day)
                } else {
                    selectedWeekdays.insert(day)
                }
            }
        } label: {
            Text(dayLabel)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? AppColors.primary : Color.white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }

    private var monthlyDayPicker: some View {
        HStack(spacing: 12) {
            Picker("Day", selection: $monthlyDayOfMonth) {
                ForEach(1...31, id: \.self) { day in
                    Text("\(day)")
                        .tag(day)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .clipped()

            Text("day")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            Spacer()
        }
    }

    private var notificationTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: notificationTime)
    }

    private var statusToggle: some View {
        HStack {
            Text(status == "active" ? "Active" : "Paused")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Toggle("", isOn: Binding(
                get: { status == "active" },
                set: { status = $0 ? "active" : "paused" }
            ))
            .tint(AppColors.primary)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var deleteGoalButton: some View {
        Button(action: {
            showDeleteConfirmation = true
        }) {
            HStack {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                Text("Delete Goal")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, AppSpacing.lg)
        .alert("Delete Goal", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteGoal()
            }
        } message: {
            Text("Are you sure you want to delete this goal? All associated obligations will also be deleted. This action cannot be undone.")
        }
    }
    
    private func deleteGoal() {
        guard let goal = editingGoal else { return }
        let goalId = goal.id

        Task { @MainActor in
            await NotificationEngine.shared.cancelTaskNotifications(forGoalId: goalId)
        }

        SyncService.shared.recordLocalGoalDeletion(goalId)
        
        // Delete all obligations associated with this goal
        let obligationDescriptor = FetchDescriptor<ObligationModel>()
        if let allObligations = try? modelContext.fetch(obligationDescriptor) {
            let relatedObligations = allObligations.filter { $0.goalId == goalId }
            for obligation in relatedObligations {
                modelContext.delete(obligation)
            }
        }
        
        // Delete the goal
        modelContext.delete(goal)
        try? modelContext.save()
        
        // Sync deletion to cloud
        Task {
            await SyncService.shared.syncGoalDeletion(goalId)
        }
        
        dismiss()
    }

    // MARK: - Actions

    @MainActor
    private func loadExistingGoal() {
        defaultNotificationTime = NotificationEngine.shared.defaultNotificationTime
        notificationTime = defaultNotificationTime
        notificationsEnabled = false
        useCustomNotificationTime = false

        guard let goal = editingGoal else {
            pendingLegacyCategoryName = nil
            pendingLegacyCategoryColorHex = nil
            recurrenceType = "daily"
            showRecurrenceOptions = true
            monthlyDayOfMonth = Calendar.current.component(.day, from: Date())
            return
        }

        title = goal.title
        selectedCategory = goal.category
        if goal.category == nil {
            pendingLegacyCategoryName = goal.categoryName
            pendingLegacyCategoryColorHex = goal.categoryColorHex
        } else {
            pendingLegacyCategoryName = nil
            pendingLegacyCategoryColorHex = nil
        }
        recurrenceType = ["daily", "weekly", "monthly", "none"].contains(goal.recurrenceType)
            ? goal.recurrenceType
            : "daily"
        selectedWeekdays = Set(goal.weekdays)
        if let time = goal.scheduledTime {
            scheduledTime = time
            hasScheduledTime = true
        }
        notificationsEnabled = goal.notificationsEnabled
        if let goalNotificationTime = goal.notificationTime {
            notificationTime = goalNotificationTime
        } else {
            notificationTime = defaultNotificationTime
        }
        // When notifications are enabled, always show time picker
        useCustomNotificationTime = notificationsEnabled
        if let day = goal.monthlyDayOfMonth {
            monthlyDayOfMonth = day
        } else {
            monthlyDayOfMonth = Calendar.current.component(.day, from: goal.createdAt)
        }
        requiredCount = max(1, goal.requiredCount)
        status = goal.status
        showRecurrenceOptions = recurrenceType != "none"
    }

    private func seedSystemCategoriesIfNeeded() {
        guard !didSeedCategories else { return }
        didSeedCategories = true
        let count = (try? modelContext.fetchCount(FetchDescriptor<GoalCategory>())) ?? 0
        guard count == 0 else { return }

        for option in GoalCategory.systemDefaults {
            let category = GoalCategory(
                name: option.name,
                colorHex: option.colorHex,
                isSystemCategory: true
            )
            modelContext.insert(category)
        }
        try? modelContext.save()
    }

    private func resolveInitialCategorySelection() {
        guard selectedCategory == nil else { return }
        guard !categories.isEmpty else { return }

        if let preferredName = pendingLegacyCategoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !preferredName.isEmpty {
            if let match = categories.first(where: { $0.name.caseInsensitiveCompare(preferredName) == .orderedSame }) {
                selectedCategory = match
            } else {
                let legacyHex = pendingLegacyCategoryColorHex?.trimmingCharacters(in: .whitespacesAndNewlines)
                let colorHex = (legacyHex?.isEmpty == false ? legacyHex : nil)
                    ?? GoalCategory.nextColorHex(existing: categories)
                let created = GoalCategory(name: preferredName, colorHex: colorHex)
                modelContext.insert(created)
                selectedCategory = created
                try? modelContext.save()
            }
        } else {
            selectedCategory = categories.first
        }

        pendingLegacyCategoryName = nil
        pendingLegacyCategoryColorHex = nil
    }

    private var canCreateCategory: Bool {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !isDuplicateCategoryName(trimmed)
    }

    private func createCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isDuplicateCategoryName(trimmed) else { return }

        let colorHex = GoalCategory.nextColorHex(existing: categories)
        let category = GoalCategory(name: trimmed, colorHex: colorHex)
        modelContext.insert(category)
        selectedCategory = category
        try? modelContext.save()
        newCategoryName = ""
        showNewCategoryPrompt = false
    }

    private func isDuplicateCategoryName(_ name: String) -> Bool {
        categories.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private func saveGoal() {
        let obligationScheduler = ObligationScheduler(modelContext: modelContext)
        let calendar = Calendar.current
        let effectiveCategory = selectedCategory ?? categories.first

        if let goal = editingGoal {
            // Update existing goal
            goal.title = title
            goal.category = effectiveCategory
            goal.categoryName = nil
            goal.categoryColorHex = nil
            goal.recurrenceType = recurrenceType
            goal.weekdays = Array(selectedWeekdays)
            goal.scheduledTime = hasScheduledTime ? scheduledTime : nil
            goal.notificationsEnabled = notificationsEnabled
            goal.notificationTime = notificationsEnabled ? notificationTime : nil
            goal.customIntervalDays = nil
            goal.monthlyDayOfMonth = recurrenceType == "monthly" ? monthlyDayOfMonth : nil
            goal.requiredCount = max(1, requiredCount)
            goal.status = status
            goal.updatedAt = Date()

            // Regenerate obligations for updated goal (backfill from creation to end of month)
            let backfillStart = goal.createdAt
            let backfillEnd = endOfCurrentMonth()
            obligationScheduler.ensureObligations(for: goal, from: backfillStart, to: backfillEnd)

            try? modelContext.save()

            Task { @MainActor in
                await NotificationEngine.shared.syncTaskNotifications(for: goal)
            }

            // Sync to cloud
            Task {
                await SyncService.shared.syncGoalUpdate(goal)
            }
        } else {
            // Create new goal with next available orderIndex
            let nextOrderIndex = computeNextOrderIndex()
            let goal = GoalModel(
                title: title,
                category: effectiveCategory,
                recurrenceType: recurrenceType,
                weekdays: Array(selectedWeekdays),
                scheduledTime: hasScheduledTime ? scheduledTime : nil,
                notificationsEnabled: notificationsEnabled,
                notificationTime: notificationsEnabled ? notificationTime : nil,
                customIntervalDays: nil,
                monthlyDayOfMonth: recurrenceType == "monthly" ? monthlyDayOfMonth : nil,
                requiredCount: max(1, requiredCount),
                orderIndex: nextOrderIndex
            )
            modelContext.insert(goal)
            try? modelContext.save()

            Task { @MainActor in
                await NotificationEngine.shared.syncTaskNotifications(for: goal)
            }

            // BACKFILL: Generate obligations from max(createdAt, 12 months ago) to end of current month
            // This ensures stats are accurate from the moment the goal is created
            let now = Date()
            let rolling12Start = calendar.date(byAdding: .month, value: -12, to: now) ?? now
            let backfillStart = max(goal.createdAt, rolling12Start)
            let backfillEnd = endOfCurrentMonth()
            obligationScheduler.ensureObligations(for: goal, from: backfillStart, to: backfillEnd)

            // Sync to cloud
            Task {
                await SyncService.shared.syncGoalCreation(goal)
            }
        }

        try? modelContext.save()
        dismiss()
    }

    private func endOfCurrentMonth() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        return calendar.date(byAdding: .day, value: daysInMonth - 1, to: startOfMonth) ?? now
    }

    /// Computes the next available orderIndex for a new goal
    private func computeNextOrderIndex() -> Int {
        let descriptor = FetchDescriptor<GoalModel>(
            sortBy: [SortDescriptor(\.orderIndex, order: .reverse)]
        )
        if let goals = try? modelContext.fetch(descriptor),
           let maxIndex = goals.first?.orderIndex {
            return maxIndex + 1
        }
        return 0
    }

}

// MARK: - Glass Text Field Style

struct GlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(AppColors.textPrimary)
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    GoalFormSheet(editingGoal: nil)
        .modelContainer(PreviewModelContainer.container)
}
