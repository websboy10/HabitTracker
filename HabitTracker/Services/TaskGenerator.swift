import Foundation
import SwiftData

/// Service for generating daily tasks from active goals.
@MainActor
final class TaskGenerator {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Generates tasks for today from all active goals.
    /// Only creates tasks that don't already exist for today.
    func generateTodaysTasks() {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Fetch all active goals
        let goalsDescriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.status == "active" }
        )
        
        guard let goals = try? modelContext.fetch(goalsDescriptor) else { return }
        
        for goal in goals {
            generateTasksForGoal(goal, on: today)
        }
        
        try? modelContext.save()
    }
    
    /// Generates tasks for a specific goal on a given date.
    private func generateTasksForGoal(_ goal: GoalModel, on date: Date) {
        // Check if we should create a task today based on frequency
        guard shouldCreateTask(for: goal, on: date) else { return }
        
        // Check if task already exists for this goal today
        // Fetch all tasks and filter in-memory due to predicate limitations
        let allTasksDescriptor = FetchDescriptor<TaskModel>()
        let existingTasks = (try? modelContext.fetch(allTasksDescriptor)) ?? []
        let hasExisting = existingTasks.contains { $0.goalId == goal.id && $0.date == date }
        
        guard !hasExisting else { return }
        
        // Create the task
        let task = TaskModel(goalId: goal.id, date: date)
        modelContext.insert(task)
    }
    
    /// Determines if a task should be created for a goal on a given date.
    /// Legacy: Uses new recurrenceType field
    private func shouldCreateTask(for goal: GoalModel, on date: Date) -> Bool {
        let calendar = Calendar.current
        
        switch goal.recurrenceType {
        case "daily":
            // Daily goals always get a task
            return true
            
        case "weekly":
            // For weekly goals, check if today is in the weekdays array
            let weekday = calendar.component(.weekday, from: date)
            // Convert to ISO weekday (1=Monday, 7=Sunday)
            let isoWeekday = weekday == 1 ? 7 : weekday - 1
            return goal.weekdays.contains(isoWeekday)
            
        case "monthly":
            // For monthly goals, create task on day 1
            let day = calendar.component(.day, from: date)
            return day == 1
            
        case "custom":
            // For custom interval, check based on customIntervalDays
            guard let interval = goal.customIntervalDays, interval > 0 else { return false }
            let daysSinceCreation = calendar.dateComponents([.day], from: goal.createdAt, to: date).day ?? 0
            return daysSinceCreation >= 0 && daysSinceCreation % interval == 0
            
        case "none":
            // One-off goals - only create task on creation date
            return calendar.isDate(date, inSameDayAs: goal.createdAt)
            
        default:
            return false
        }
    }
    
    /// Returns which days of the week to create tasks for weekly goals.
    private func weeklyTaskDays(count: Int) -> [Int] {
        switch count {
        case 1: return [2]
        case 2: return [2, 5]
        case 3: return [2, 4, 6]
        case 4: return [2, 3, 5, 6]
        case 5: return [2, 3, 4, 5, 6]
        case 6: return [2, 3, 4, 5, 6, 7]
        case 7: return [1, 2, 3, 4, 5, 6, 7]
        default: return Array(2...min(count + 1, 7))
        }
    }
    
    /// Returns which days of the month to create tasks for monthly goals.
    private func monthlyTaskDays(count: Int, totalDays: Int) -> [Int] {
        guard count > 0 else { return [] }
        let interval = totalDays / count
        return (0..<count).map { 1 + ($0 * interval) }
    }
    
    /// Fetches today's tasks with their associated goal info.
    func fetchTodaysTasks() -> [(task: TaskModel, goal: GoalModel)] {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Fetch all tasks and filter in-memory
        let allTasksDescriptor = FetchDescriptor<TaskModel>()
        let allTasks = (try? modelContext.fetch(allTasksDescriptor)) ?? []
        let todaysTasks = allTasks.filter { $0.date == today }
        
        // Fetch all goals
        let allGoalsDescriptor = FetchDescriptor<GoalModel>()
        let allGoals = (try? modelContext.fetch(allGoalsDescriptor)) ?? []
        
        return todaysTasks.compactMap { task in
            guard let goal = allGoals.first(where: { $0.id == task.goalId }) else { return nil }
            return (task: task, goal: goal)
        }
    }
}
