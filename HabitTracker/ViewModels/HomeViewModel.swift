import SwiftUI
import SwiftData

/// ViewModel for the Home screen with SwiftData integration.
@MainActor
@Observable
final class HomeViewModel {
    
    /// Model context for SwiftData operations
    private var modelContext: ModelContext?
    
    /// Task generator service
    private var taskGenerator: TaskGenerator?
    
    /// Progress calculator service
    private var progressCalculator: ProgressCalculator?
    
    // MARK: - Configuration
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        self.taskGenerator = TaskGenerator(modelContext: modelContext)
        self.progressCalculator = ProgressCalculator(modelContext: modelContext)
        
        // Generate today's tasks on launch
        taskGenerator?.generateTodaysTasks()
    }
    
    // MARK: - Today's Tasks
    
    /// Fetches today's tasks with goal information
    func fetchTodaysTasks() -> [(task: TaskModel, goal: GoalModel, category: CategoryModel?)] {
        guard let modelContext else { return [] }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        let tasksDescriptor = FetchDescriptor<TaskModel>(
            predicate: #Predicate { $0.date == today },
            sortBy: [SortDescriptor(\.goalId)]
        )
        
        guard let tasks = try? modelContext.fetch(tasksDescriptor) else { return [] }
        
        return tasks.compactMap { task in
            // Fetch goal
            let goalId = task.goalId
            let goalDescriptor = FetchDescriptor<GoalModel>(
                predicate: #Predicate { $0.id == goalId }
            )
            guard let goal = try? modelContext.fetch(goalDescriptor).first else { return nil }
            
            // Fetch category
            let categoryId = goal.categoryId
            let categoryDescriptor = FetchDescriptor<CategoryModel>(
                predicate: #Predicate { $0.id == categoryId }
            )
            let category = try? modelContext.fetch(categoryDescriptor).first
            
            return (task: task, goal: goal, category: category)
        }
    }
    
    // MARK: - Progress
    
    /// Daily completion percentage
    var completionPercentage: Double {
        progressCalculator?.todayProgress() ?? 0
    }
    
    /// Today's counts
    var todayCounts: (total: Int, completed: Int, remaining: Int) {
        progressCalculator?.todayCounts() ?? (0, 0, 0)
    }
    
    var totalCount: Int { todayCounts.total }
    var completedCount: Int { todayCounts.completed }
    var remainingCount: Int { todayCounts.remaining }
    
    /// Weekly progress
    var weekProgress: (completed: Int, total: Int, dayProgress: [Bool]) {
        progressCalculator?.weekProgress() ?? (0, 0, [])
    }
    
    /// Week progress model for WeekOverviewCard
    var weekProgressModel: WeekProgress {
        let progress = weekProgress
        let percentage = progress.total > 0 ? Double(progress.completed) / Double(progress.total) : 0
        return WeekProgress(
            completed: progress.completed,
            total: max(progress.total, 1),
            dayProgress: progress.dayProgress.isEmpty ? Array(repeating: false, count: 7) : progress.dayProgress
        )
    }
    
    /// Monthly progress
    var monthProgress: MonthProgress {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let dayOfMonth = calendar.component(.day, from: now)
        let daysRemaining = daysInMonth - dayOfMonth
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let monthAbbrev = formatter.string(from: now)
        
        // Calculate based on yearly progress for now
        let yearlyProgress = progressCalculator?.yearlyProgress() ?? 0
        
        return MonthProgress(
            percentage: yearlyProgress,
            daysRemaining: daysRemaining,
            monthAbbreviation: monthAbbrev
        )
    }
    
    /// Next week goals count
    var nextWeekGoals: Int {
        guard let modelContext else { return 0 }
        
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.status == "active" }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
    
    // MARK: - Actions
    
    /// Toggle task completion
    func toggleTask(_ task: TaskModel) {
        guard let modelContext else { return }
        
        if task.isCompleted {
            // Uncomplete
            task.isCompleted = false
            task.completedAt = nil
            
            // Remove completion record
            let taskId = task.id
            let goalId = task.goalId
            let today = Calendar.current.startOfDay(for: Date())
            
            let descriptor = FetchDescriptor<CompletionModel>(
                predicate: #Predicate { $0.goalId == goalId && $0.completedAt >= today }
            )
            
            if let completions = try? modelContext.fetch(descriptor) {
                for completion in completions {
                    let completionId = completion.id
                    modelContext.delete(completion)
                    
                    // Sync deletion to cloud
                    Task {
                        await SyncService.shared.syncCompletionDeletion(completionId)
                    }
                }
            }
            
            HapticManager.shared.soft()
        } else {
            // Complete
            task.isCompleted = true
            task.completedAt = Date()
            
            // Add completion record
            let completion = CompletionModel(goalId: task.goalId)
            modelContext.insert(completion)
            
            // Sync creation to cloud
            Task {
                await SyncService.shared.syncCompletionCreation(completion)
            }
            
            HapticManager.shared.success()
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Sync
    
    /// Triggers a full sync with cloud
    func performSync() {
        guard let modelContext else { return }
        
        Task {
            await SyncService.shared.performFullSync(modelContext: modelContext)
        }
    }
}
