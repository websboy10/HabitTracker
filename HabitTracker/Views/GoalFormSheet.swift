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
    @State private var selectedCategoryId: UUID?
    @State private var recurrenceType: String = "daily"
    @State private var selectedWeekdays: Set<Int> = []
    @State private var scheduledTime: Date = Date()
    @State private var hasScheduledTime: Bool = false
    @State private var monthlyDayOfMonth: Int = 1
    @State private var status: String = "active"
    @State private var showRecurrenceOptions: Bool = true
    @State private var showDeleteConfirmation: Bool = false

    // Categories
    @Query(sort: \CategoryModel.sortOrder) private var categories: [CategoryModel]

    @Namespace private var animation
    @FocusState private var isTextFieldFocused: Bool

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
                        .disabled(title.isEmpty || selectedCategoryId == nil)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            if categories.isEmpty {
                // Fallback seeding if needed
                for (index, cat) in CategoryModel.defaults.enumerated() {
                    let model = CategoryModel(
                        name: cat.name,
                        colorHex: cat.colorHex,
                        isDefault: true,
                        sortOrder: index
                    )
                    modelContext.insert(model)
                }
            }
            loadExistingGoal()
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
            }
        }
    }

    private func categoryChip(_ category: CategoryModel) -> some View {
        let isSelected = selectedCategoryId == category.id

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedCategoryId = category.id
            }
        } label: {
            Text(category.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : category.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(category.color)
                                .matchedGeometryEffect(id: "activeCategory", in: animation)
                        } else {
                            Capsule()
                                .fill(category.color.opacity(0.1))
                        }
                    }
                )
                .overlay(
                    Capsule()
                        .stroke(category.color.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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

    private func loadExistingGoal() {
        guard let goal = editingGoal else {
            // Set default category
            selectedCategoryId = categories.first?.id
            recurrenceType = "daily"
            showRecurrenceOptions = true
            monthlyDayOfMonth = Calendar.current.component(.day, from: Date())
            return
        }

        title = goal.title
        selectedCategoryId = goal.categoryId
        recurrenceType = ["daily", "weekly", "monthly", "none"].contains(goal.recurrenceType)
            ? goal.recurrenceType
            : "daily"
        selectedWeekdays = Set(goal.weekdays)
        if let time = goal.scheduledTime {
            scheduledTime = time
            hasScheduledTime = true
        }
        if let day = goal.monthlyDayOfMonth {
            monthlyDayOfMonth = day
        } else {
            monthlyDayOfMonth = Calendar.current.component(.day, from: goal.createdAt)
        }
        status = goal.status
        showRecurrenceOptions = recurrenceType != "none"
    }

    private func saveGoal() {
        guard let categoryId = selectedCategoryId else { return }

        let obligationScheduler = ObligationScheduler(modelContext: modelContext)
        let calendar = Calendar.current

        if let goal = editingGoal {
            // Update existing goal
            goal.title = title
            goal.categoryId = categoryId
            goal.recurrenceType = recurrenceType
            goal.weekdays = Array(selectedWeekdays)
            goal.scheduledTime = hasScheduledTime ? scheduledTime : nil
            goal.customIntervalDays = nil
            goal.monthlyDayOfMonth = recurrenceType == "monthly" ? monthlyDayOfMonth : nil
            goal.status = status
            goal.updatedAt = Date()

            // Regenerate obligations for updated goal (backfill from creation to end of month)
            let backfillStart = goal.createdAt
            let backfillEnd = endOfCurrentMonth()
            obligationScheduler.ensureObligations(for: goal, from: backfillStart, to: backfillEnd)

            try? modelContext.save()

            // Sync to cloud
            Task {
                await SyncService.shared.syncGoalUpdate(goal)
            }
        } else {
            // Create new goal
            let goal = GoalModel(
                title: title,
                categoryId: categoryId,
                recurrenceType: recurrenceType,
                weekdays: Array(selectedWeekdays),
                scheduledTime: hasScheduledTime ? scheduledTime : nil,
                customIntervalDays: nil,
                monthlyDayOfMonth: recurrenceType == "monthly" ? monthlyDayOfMonth : nil
            )
            modelContext.insert(goal)
            try? modelContext.save()

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
                // Also sync the category if it's not yet synced
                if let category = categories.first(where: { $0.id == categoryId }) {
                    await SyncService.shared.syncCategoryCreation(category)
                }
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
}
