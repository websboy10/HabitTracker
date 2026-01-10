import SwiftUI

/// A single task card with tap-to-complete interaction.
/// Visual state changes based on completion status.
struct TaskCard: View {
    
    let task: HabitTask
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // Completion indicator
                completionIndicator
                
                // Task content
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(AppTypography.body)
                        .fontWeight(.medium)
                        .foregroundColor(task.isCompleted ? AppColors.textPrimary.opacity(0.9) : AppColors.textPrimary)
                        .strikethrough(task.isCompleted, color: AppColors.textPrimary.opacity(0.3))
                        .tracking(0.3)
                    
                    Text(task.isCompleted ? "Completed" : "Pending")
                        .font(AppTypography.caption)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundColor(task.isCompleted ? AppColors.primary.opacity(0.7) : AppColors.textMuted)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                // Pending indicator bar
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
    
    // MARK: - Subviews
    
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

// MARK: - Button Style

private struct TaskButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient
        
        VStack(spacing: AppSpacing.md) {
            TaskCard(
                task: HabitTask(title: "Morning Meditation", isCompleted: true),
                onTap: {}
            )
            
            TaskCard(
                task: HabitTask(title: "Deep Work Session", isCompleted: false),
                onTap: {}
            )
        }
        .padding(AppSpacing.screenHorizontal)
    }
}
