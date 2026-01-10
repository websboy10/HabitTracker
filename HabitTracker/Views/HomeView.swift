import SwiftUI
import SwiftData

/// The main Home screen with scrollable dashboard.
/// Uses SwiftData for task management.
struct HomeView: View {
    
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()
    @Binding var selectedTab: Tab
    var showsCustomTabBar: Bool = true
    
    var body: some View {
        ZStack {
            // Fixed background
            AppMaterials.moodGradient
            
            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // SECTION 1: Hero / Daily Dashboard
                    heroSection
                        .padding(.bottom, AppSpacing.xl)
                    
                    // SECTION 2: Today's Tasks
                    todayTasksSection
                        .padding(.bottom, AppSpacing.xl)
                    
                    // SECTION 3: This Week
                    thisWeekSection
                        .padding(.bottom, AppSpacing.xl)
                    
                    // SECTION 4: Next Week
                    nextWeekSection
                        .padding(.bottom, AppSpacing.xl)
                    
                    // SECTION 5: This Month
                    thisMonthSection
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
            viewModel.configure(with: modelContext)
        }
    }
    
    // MARK: - Section 1: Hero
    
    private var heroSection: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressRing(
                percentage: viewModel.completionPercentage,
                label: "Today"
            )
            
            statsBar
        }
    }
    
    private var statsBar: some View {
        GlassCard {
            HStack {
                statItem(value: viewModel.totalCount, label: "TOTAL", color: AppColors.textPrimary)
                
                AppComponents.VerticalSeparator(height: 32)
                
                statItem(value: viewModel.completedCount, label: "DONE", color: AppColors.primary, hasGlow: true)
                
                AppComponents.VerticalSeparator(height: 32)
                
                statItem(value: viewModel.remainingCount, label: "LEFT", color: AppColors.textPrimary.opacity(0.8))
            }
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.sm)
        }
    }
    
    private func statItem(value: Int, label: String, color: Color, hasGlow: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
                .shadow(
                    color: hasGlow ? AppColors.primary.opacity(0.5) : .clear,
                    radius: hasGlow ? 8 : 0
                )
            
            Text(label)
                .font(AppTypography.caption)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Section 2: Today's Tasks
    
    private var todayTasksSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("Today's Focus")
            
            let tasks = viewModel.fetchTodaysTasks()
            
            if tasks.isEmpty {
                emptyTasksState
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                VStack(spacing: AppSpacing.md) {
                    ForEach(Array(tasks.enumerated()), id: \.element.task.id) { index, item in
                        TaskCardSwiftData(
                            task: item.task,
                            goal: item.goal,
                            category: item.category
                        ) {
                            withAnimation(AppAnimation.standard) {
                                viewModel.toggleTask(item.task)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .scale(scale: 0.8))
                        ))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: tasks.map { $0.task.id })
            }
        }
    }
    
    private var emptyTasksState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(AppColors.textMuted)
            
            Text("No tasks for today")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            
            Text("Add goals in the Goals tab")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Section 3: This Week
    
    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("This Week")
            
            WeekOverviewCard(progress: viewModel.weekProgressModel)
        }
    }
    
    // MARK: - Section 4: Next Week
    
    private var nextWeekSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("Next Week", muted: true)
            
            NextWeekCard(upcomingGoals: viewModel.nextWeekGoals)
        }
    }
    
    // MARK: - Section 5: This Month
    
    private var thisMonthSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("This Month")
            
            MonthCard(progress: viewModel.monthProgress)
        }
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String, muted: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(muted ? AppColors.textMuted : AppColors.textSecondary)
            .textCase(.uppercase)
            .tracking(2)
            .padding(.leading, 4)
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
}

// MARK: - Task Card for SwiftData

struct TaskCardSwiftData: View {
    
    let task: TaskModel
    let goal: GoalModel
    let category: CategoryModel?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                completionIndicator
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(AppTypography.body)
                        .fontWeight(.medium)
                        .foregroundColor(task.isCompleted ? AppColors.textPrimary.opacity(0.9) : AppColors.textPrimary)
                        .strikethrough(task.isCompleted, color: AppColors.textPrimary.opacity(0.3))
                        .tracking(0.3)
                    
                    HStack(spacing: 6) {
                        if let category = category {
                            Text(category.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(category.color.opacity(0.8))
                        }
                        
                        Text(task.isCompleted ? "Completed" : "Pending")
                            .font(AppTypography.caption)
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundColor(task.isCompleted ? AppColors.primary.opacity(0.7) : AppColors.textMuted)
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
                
                if !task.isCompleted {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AppColors.trackBackground)
                        .frame(width: 4, height: 32)
                }
            }
            .padding(AppSpacing.md)
            .background(taskBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius, style: .continuous))
            .overlay(taskBorder)
            .shadow(color: task.isCompleted ? AppColors.primary.opacity(0.15) : .black.opacity(0.2), radius: task.isCompleted ? 15 : 8, y: 4)
        }
        .buttonStyle(TaskButtonStyle())
    }
    
    private var completionIndicator: some View {
        Circle()
            .fill(task.isCompleted ? AppColors.primary.opacity(0.2) : Color.white.opacity(0.05))
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .stroke(
                        task.isCompleted ? AppColors.primary.opacity(0.4) : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            )
            .overlay(
                Group {
                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
            )
            .shadow(color: task.isCompleted ? AppColors.primary.opacity(0.3) : .clear, radius: 15)
    }
    
    private var taskBackground: some View {
        Group {
            if task.isCompleted {
                LinearGradient(
                    colors: [AppColors.primary.opacity(0.2), AppColors.primary.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                AppColors.glassBackground
            }
        }
        .background(.ultraThinMaterial.opacity(0.3))
    }
    
    private var taskBorder: some View {
        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius, style: .continuous)
            .stroke(
                task.isCompleted
                    ? AppColors.primary.opacity(0.3)
                    : AppColors.glassBorder,
                lineWidth: 1
            )
    }
}

private struct TaskButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    HomeView(selectedTab: .constant(.home))
}
