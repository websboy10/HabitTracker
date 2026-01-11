import SwiftUI
import SwiftData

/// ViewModel for the Goals view with obligation-based system.
@MainActor
@Observable
final class GoalsViewModel {

    /// Currently selected recurrence tab
    var selectedTab: String = "daily"

    /// Whether to show the goal form sheet
    var showingGoalForm = false

    /// Goal being edited (nil for new goal)
    var editingGoal: GoalModel? = nil

    /// Model context for SwiftData operations
    private var modelContext: ModelContext?

    /// Obligation scheduler for generating obligations
    private var obligationScheduler: ObligationScheduler?

    // MARK: - Initialization

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        self.obligationScheduler = ObligationScheduler(modelContext: modelContext)
        let allowedTabs = ["daily", "weekly", "monthly"]
        if !allowedTabs.contains(selectedTab) {
            selectedTab = "daily"
        }
    }

    // MARK: - Queries

    /// Fetches goals filtered by the selected recurrence type
    func fetchGoals() -> [GoalModel] {
        guard let modelContext else { return [] }

        let recurrence = selectedTab
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.recurrenceType == recurrence },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Fetches all categories
    func fetchCategories() -> [CategoryModel] {
        guard let modelContext else { return [] }

        let descriptor = FetchDescriptor<CategoryModel>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Gets category by ID
    func category(for goalId: UUID) -> CategoryModel? {
        guard let modelContext else { return nil }

        // First get the goal to find its categoryId
        let goalDescriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == goalId }
        )
        guard let goal = try? modelContext.fetch(goalDescriptor).first else { return nil }

        let categoryId = goal.categoryId
        let categoryDescriptor = FetchDescriptor<CategoryModel>(
            predicate: #Predicate { $0.id == categoryId }
        )

        return try? modelContext.fetch(categoryDescriptor).first
    }

    /// Gets category for a goal's categoryId
    func category(for goal: GoalModel) -> CategoryModel? {
        guard let modelContext else { return nil }

        let categoryId = goal.categoryId
        let descriptor = FetchDescriptor<CategoryModel>(
            predicate: #Predicate { $0.id == categoryId }
        )

        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Actions

    /// Opens form to create a new goal
    func addGoal() {
        editingGoal = nil
        showingGoalForm = true
    }

    /// Opens form to edit an existing goal
    func editGoal(_ goal: GoalModel) {
        editingGoal = goal
        showingGoalForm = true
    }

    /// Deletes a goal and all its associated obligations
    func deleteGoal(_ goal: GoalModel) {
        guard let modelContext else { return }
        let goalId = goal.id
        
        // First, delete all obligations associated with this goal
        let obligationDescriptor = FetchDescriptor<ObligationModel>()
        if let allObligations = try? modelContext.fetch(obligationDescriptor) {
            let relatedObligations = allObligations.filter { $0.goalId == goalId }
            for obligation in relatedObligations {
                modelContext.delete(obligation)
            }
        }
        
        // Then delete the goal itself
        modelContext.delete(goal)
        try? modelContext.save()

        // Sync deletion to cloud
        Task {
            await SyncService.shared.syncGoalDeletion(goalId)
        }
    }

    /// Toggles goal status between active and paused
    func toggleStatus(_ goal: GoalModel) {
        goal.status = goal.isActive ? "paused" : "active"
        goal.updatedAt = Date()
        try? modelContext?.save()

        // Sync update to cloud
        Task {
            await SyncService.shared.syncGoalUpdate(goal)
        }
    }

    /// Saves a new or updated goal
    func saveGoal(_ goal: GoalModel, isNew: Bool) {
        guard let modelContext else { return }

        if isNew {
            modelContext.insert(goal)
        }
        goal.updatedAt = Date()
        try? modelContext.save()

        // Generate obligations for the new/updated goal
        let daysAhead = daysRemainingInCurrentMonth()
        obligationScheduler?.generateUpcomingObligations(for: goal, daysAhead: daysAhead)

        // Sync to cloud
        Task {
            if isNew {
                await SyncService.shared.syncGoalCreation(goal)
            } else {
                await SyncService.shared.syncGoalUpdate(goal)
            }
        }
    }

    private func daysRemainingInCurrentMonth(from date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        let dayOfMonth = calendar.component(.day, from: date)
        return max(1, daysInMonth - dayOfMonth + 1)
    }
}
