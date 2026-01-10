import Foundation
import SwiftData

/// Service for calculating progress statistics for goals.
@MainActor
final class ProgressCalculator {
    
    private let modelContext: ModelContext
    private let calendar = Calendar.current
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Yearly Progress
    
    /// Calculates overall yearly progress across all active goals.
    func yearlyProgress() -> Double {
        let goals = fetchActiveGoals()
        guard !goals.isEmpty else { return 0 }
        
        let totalProgress = goals.reduce(0.0) { sum, goal in
            sum + yearlyProgress(for: goal)
        }
        
        return totalProgress / Double(goals.count)
    }
    
    /// Calculates yearly progress for a specific goal.
    func yearlyProgress(for goal: GoalModel) -> Double {
        let expected = expectedCompletionsYTD(for: goal)
        guard expected > 0 else { return 0 }
        
        let actual = actualCompletionsYTD(for: goal)
        return min(Double(actual) / Double(expected), 1.0)
    }
    
    /// Calculates expected completions year-to-date based on goal frequency.
    private func expectedCompletionsYTD(for goal: GoalModel) -> Int {
        let now = Date()
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
        let dayOfYear = calendar.dateComponents([.day], from: startOfYear, to: now).day ?? 0
        
        switch goal.frequency {
        case "daily":
            return dayOfYear * goal.frequencyCount
            
        case "weekly":
            let weekOfYear = calendar.component(.weekOfYear, from: now)
            return weekOfYear * goal.frequencyCount
            
        case "monthly":
            let month = calendar.component(.month, from: now)
            return month * goal.frequencyCount
            
        default:
            return 0
        }
    }
    
    /// Fetches actual completions year-to-date for a goal.
    private func actualCompletionsYTD(for goal: GoalModel) -> Int {
        let now = Date()
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
        
        // Fetch all completions and filter in-memory
        let allDescriptor = FetchDescriptor<CompletionModel>()
        let allCompletions = (try? modelContext.fetch(allDescriptor)) ?? []
        
        return allCompletions.filter { 
            $0.goalId == goal.id && $0.completedAt >= startOfYear 
        }.count
    }
    
    // MARK: - Daily Progress
    
    /// Calculates today's completion percentage.
    func todayProgress() -> Double {
        let today = calendar.startOfDay(for: Date())
        let tasks = fetchTasksForDate(today)
        
        guard !tasks.isEmpty else { return 0 }
        
        let completed = tasks.filter(\.isCompleted).count
        return Double(completed) / Double(tasks.count)
    }
    
    /// Returns counts for today: (total, completed, remaining)
    func todayCounts() -> (total: Int, completed: Int, remaining: Int) {
        let today = calendar.startOfDay(for: Date())
        let tasks = fetchTasksForDate(today)
        
        let completed = tasks.filter(\.isCompleted).count
        return (tasks.count, completed, tasks.count - completed)
    }
    
    // MARK: - Weekly Progress
    
    /// Returns weekly progress for the current week.
    func weekProgress() -> (completed: Int, total: Int, dayProgress: [Bool]) {
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        
        var dayProgress: [Bool] = []
        var totalCompleted = 0
        var totalTasks = 0
        
        // Fetch all tasks once
        let allTasksDescriptor = FetchDescriptor<TaskModel>()
        let allTasks = (try? modelContext.fetch(allTasksDescriptor)) ?? []
        
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else {
                dayProgress.append(false)
                continue
            }
            
            let dayTasks = allTasks.filter { $0.date == day }
            
            if !dayTasks.isEmpty {
                let completed = dayTasks.filter(\.isCompleted).count
                totalCompleted += completed
                totalTasks += dayTasks.count
                dayProgress.append(completed == dayTasks.count)
            } else {
                dayProgress.append(false)
            }
        }
        
        return (totalCompleted, totalTasks, dayProgress)
    }
    
    // MARK: - Helpers
    
    private func fetchActiveGoals() -> [GoalModel] {
        let descriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.status == "active" }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func fetchTasksForDate(_ date: Date) -> [TaskModel] {
        let allDescriptor = FetchDescriptor<TaskModel>()
        let allTasks = (try? modelContext.fetch(allDescriptor)) ?? []
        return allTasks.filter { $0.date == date }
    }
}
