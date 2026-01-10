import SwiftUI
import SwiftData

/// ViewModel for the Goals view with SwiftData persistence.
@MainActor
@Observable
final class GoalsViewModel {
    
    /// Currently selected frequency tab
    var selectedTab: String = "daily"
    
    /// Whether to show the goal form sheet
    var showingGoalForm = false
    
    /// Goal being edited (nil for new goal)
    var editingGoal: GoalModel? = nil
    
    /// Model context for SwiftData operations
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Queries
    
    /// Fetches goals filtered by the selected tab
    func fetchGoals() -> [GoalModel] {
        guard let modelContext else { return [] }
        
        let frequency = selectedTab
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.frequency == frequency },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Fetches all active goals for yearly view
    func fetchActiveGoals() -> [GoalModel] {
        guard let modelContext else { return [] }
        
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.status == "active" },
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
    
    // MARK: - Progress
    
    /// Calculates yearly progress percentage
    func yearlyProgress() -> Double {
        guard let modelContext else { return 0 }
        let calculator = ProgressCalculator(modelContext: modelContext)
        return calculator.yearlyProgress()
    }
    
    /// Gets yearly progress for a specific goal
    func yearlyProgress(for goal: GoalModel) -> Double {
        guard let modelContext else { return 0 }
        let calculator = ProgressCalculator(modelContext: modelContext)
        return calculator.yearlyProgress(for: goal)
    }
    
    /// Gets completions count for a goal this year
    func yearlyCompletions(for goal: GoalModel) -> Int {
        guard let modelContext else { return 0 }
        
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: Date()))!
        let goalId = goal.id
        
        let descriptor = FetchDescriptor<CompletionModel>(
            predicate: #Predicate { $0.goalId == goalId && $0.completedAt >= startOfYear }
        )
        
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
    
    /// Gets expected yearly target for a goal
    func yearlyTarget(for goal: GoalModel) -> Int {
        let calendar = Calendar.current
        
        switch goal.frequency {
        case "daily":
            return 365 * goal.frequencyCount
        case "weekly":
            return 52 * goal.frequencyCount
        case "monthly":
            return 12 * goal.frequencyCount
        default:
            return goal.frequencyCount
        }
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
    
    /// Deletes a goal
    func deleteGoal(_ goal: GoalModel) {
        guard let modelContext else { return }
        let goalId = goal.id
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
        
        // Sync to cloud
        Task {
            if isNew {
                await SyncService.shared.syncGoalCreation(goal)
            } else {
                await SyncService.shared.syncGoalUpdate(goal)
            }
        }
    }
}
