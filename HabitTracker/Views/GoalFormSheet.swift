import SwiftUI
import SwiftData

/// Form sheet for creating or editing a goal.
struct GoalFormSheet: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    /// The goal being edited (nil for new goal)
    let editingGoal: GoalModel?
    
    // Form state
    @State private var title: String = ""
    @State private var selectedCategoryId: UUID?
    @State private var frequency: String = "daily"
    @State private var frequencyCount: Int = 1
    @State private var frequencyUnit: String = "time"
    @State private var status: String = "active"
    
    // Categories
    @Query(sort: \CategoryModel.sortOrder) private var categories: [CategoryModel]
    
    @Namespace private var animation
    
    private let frequencies = ["daily", "weekly", "monthly"]
    private let units = ["time", "hour", "min", "km", "page", "session"]
    
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
                        }
                        
                        // Category
                        formSection("Category") {
                            categoryPicker
                        }
                        
                        // Frequency
                        formSection("Frequency") {
                            frequencyPicker
                        }
                        
                        // Amount
                        formSection("Amount") {
                            amountPicker
                        }
                        
                        // Status (only for editing)
                        if editingGoal != nil {
                            formSection("Status") {
                                statusToggle
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.md)
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
    
    private var frequencyPicker: some View {
        HStack(spacing: 8) {
            ForEach(frequencies, id: \.self) { freq in
                frequencyButton(freq)
            }
        }
    }
    
    private func frequencyButton(_ freq: String) -> some View {
        let isSelected = frequency == freq
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                frequency = freq
            }
        } label: {
            Text(freq.capitalized)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppColors.primary)
                                .matchedGeometryEffect(id: "activeFrequency", in: animation)
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
    
    private var amountPicker: some View {
        HStack(spacing: 12) {
            // Count stepper
            HStack(spacing: 0) {
                Button { if frequencyCount > 1 { frequencyCount -= 1 } } label: {
                    Image(systemName: "minus")
                        .frame(width: 44, height: 44)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Text("\(frequencyCount)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 48)
                
                Button { frequencyCount += 1 } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Unit picker
            Menu {
                ForEach(units, id: \.self) { unit in
                    Button(unit) { frequencyUnit = unit }
                }
            } label: {
                HStack {
                    Text(frequencyCount == 1 ? frequencyUnit : "\(frequencyUnit)s")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
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
    
    // MARK: - Actions
    
    private func loadExistingGoal() {
        guard let goal = editingGoal else {
            // Set default category
            selectedCategoryId = categories.first?.id
            return
        }
        
        title = goal.title
        selectedCategoryId = goal.categoryId
        frequency = goal.frequency
        frequencyCount = goal.frequencyCount
        frequencyUnit = goal.frequencyUnit
        status = goal.status
    }
    
    private func saveGoal() {
        guard let categoryId = selectedCategoryId else { return }
        
        if let goal = editingGoal {
            // Update existing goal
            goal.title = title
            goal.categoryId = categoryId
            goal.frequency = frequency
            goal.frequencyCount = frequencyCount
            goal.frequencyUnit = frequencyUnit
            goal.status = status
            goal.updatedAt = Date()
        } else {
            // Create new goal
            let goal = GoalModel(
                title: title,
                categoryId: categoryId,
                frequency: frequency,
                frequencyCount: frequencyCount,
                frequencyUnit: frequencyUnit
            )
            modelContext.insert(goal)
        }
        
        try? modelContext.save()
        dismiss()
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
