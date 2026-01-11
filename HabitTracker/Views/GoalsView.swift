import SwiftUI
import SwiftData

/// Goals management view with tabbed layout and SwiftData persistence.
struct GoalsView: View {
    
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = GoalsViewModel()
    @Binding var selectedTab: Tab
    var showsCustomTabBar: Bool = true
    
    var body: some View {
        ZStack {
            // Background
            AppMaterials.moodGradient
            
            // Scrollable content
            goalsList
            
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
        .sheet(isPresented: $viewModel.showingGoalForm) {
            GoalFormSheet(editingGoal: viewModel.editingGoal)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Goals")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(-0.5)
                
                Text("Manage your habits")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            // Add button
            Button { viewModel.addGoal() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(AppColors.textPrimary.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 4)
    }
    
    // MARK: - Goals List
    
    private var goalsList: some View {
        List {
            Section {
                header
                    .padding(.bottom, AppSpacing.lg)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                GoalTabPicker(selection: Binding(
                    get: { GoalFrequency(rawValue: viewModel.selectedTab) ?? .daily },
                    set: { viewModel.selectedTab = $0.rawValue }
                ))
                .padding(.bottom, AppSpacing.lg)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                let goals = viewModel.fetchGoals()
                if goals.isEmpty {
                    emptyState
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(goals, id: \.id) { goal in
                        GoalRow(
                            goal: goal,
                            category: viewModel.category(for: goal),
                            onEdit: { viewModel.editGoal(goal) },
                            onToggleStatus: { viewModel.toggleStatus(goal) }
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 12, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteGoal(goal)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.top, AppSpacing.xl)
        .padding(.bottom, 120)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "scope")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppColors.textMuted)
            
            Text("No \(viewModel.selectedTab) goals yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            
            Button { viewModel.addGoal() } label: {
                Text("Add Goal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppColors.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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

// MARK: - Goal Card for SwiftData

struct GoalRow: View {
    let goal: GoalModel
    let category: CategoryModel?
    var onEdit: (() -> Void)? = nil
    var onToggleStatus: (() -> Void)? = nil
    
    private var accent: Color {
        category?.color ?? AppColors.primary
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(accent.opacity(goal.isActive ? 0.9 : 0.4))
                .frame(width: 5, height: 40)
                .shadow(color: accent.opacity(goal.isActive ? 0.4 : 0.0), radius: 6)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if let category = category {
                        Text(category.name)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(accent.opacity(goal.isActive ? 0.9 : 0.6))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(accent.opacity(goal.isActive ? 0.16 : 0.08))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(accent.opacity(goal.isActive ? 0.3 : 0.15), lineWidth: 1)
                            )
                    }
                    
                    // Active/Paused indicator
                    HStack(spacing: 3) {
                        Circle()
                            .fill(goal.isActive ? Color.green : Color.gray.opacity(0.5))
                            .frame(width: 5, height: 5)
                        
                        Text(goal.isActive ? "Active" : "Paused")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(goal.isActive ? Color.green.opacity(0.9) : AppColors.textMuted)
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(goal.isActive ? Color.green.opacity(0.12) : Color.white.opacity(0.05))
                    )
                    .overlay(
                        Capsule()
                            .stroke(goal.isActive ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                
                Text(goal.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(goal.isActive ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.75))
                    .tracking(0.2)
                
                Text(goal.recurrenceText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(goal.isActive ? AppColors.textSecondary : AppColors.textMuted)
            }
            
            Spacer()
            
            // Active/Paused Toggle
            Toggle("", isOn: Binding(
                get: { goal.isActive },
                set: { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onToggleStatus?()
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: Color.green))
            .labelsHidden()
            .scaleEffect(0.75)
            
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.08), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.ultraThinMaterial.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous)
                .stroke(AppColors.glassBorder, lineWidth: 1)
        )
        .opacity(goal.isActive ? 1 : 0.7)
    }
}

// MARK: - Swipeable Goal Row (for ScrollView context)

struct SwipeableGoalRow: View {
    let goal: GoalModel
    let category: CategoryModel?
    var onEdit: (() -> Void)? = nil
    var onToggleStatus: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    @State private var offset: CGFloat = 0
    private let deleteThreshold: CGFloat = 80
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete action background
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onDelete?()
                    }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous)
                    .fill(Color.red.opacity(0.8))
            )
            .opacity(offset < 0 ? min(1, abs(offset) / deleteThreshold) : 0)
            
            // Main content
            GoalRow(
                goal: goal,
                category: category,
                onEdit: onEdit,
                onToggleStatus: onToggleStatus
            )
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        // Only respond to horizontal swipes (left direction)
                        // This allows vertical scrolling to work
                        let isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                        if isHorizontalDrag && value.translation.width < 0 {
                            offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        let isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if isHorizontalDrag && value.translation.width < -deleteThreshold {
                                // Trigger delete
                                offset = -UIScreen.main.bounds.width
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onDelete?()
                                }
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous))
    }
}

struct GoalCardSwiftData: View {
    let goal: GoalModel
    let category: CategoryModel?
    var onEdit: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // Category and status row
                HStack(spacing: 8) {
                    if let category = category {
                        Text(category.name)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(goal.isActive ? category.color : AppColors.textSecondary)
                            .textCase(.uppercase)
                            .tracking(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(goal.isActive ? category.color.opacity(0.1) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(goal.isActive ? category.color.opacity(0.2) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 4, height: 4)
                    
                    Text(goal.isActive ? "Active" : "Paused")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(goal.isActive ? AppColors.textSecondary : AppColors.textMuted)
                        .textCase(.uppercase)
                        .tracking(1)
                }
                
                // Title
                Text(goal.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(goal.isActive ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.8))
                    .tracking(0.3)
                
                // Recurrence
                Text(goal.recurrenceText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(goal.isActive ? AppColors.textSecondary : AppColors.textMuted)

                if let scheduleDetailText {
                    Text(scheduleDetailText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                }
            }
            
            Spacer()
            
            // Edit button
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(cardBackground)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous)
                .stroke(AppColors.glassBorder, lineWidth: 1)
        )
        .opacity(goal.isActive ? 1 : 0.6)
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        if goal.isActive {
            AppColors.glassBackground
        } else {
            LinearGradient(
                colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var scheduleDetailText: String? {
        var parts: [String] = []
        if let monthlyDay = goal.monthlyDayText {
            parts.append(monthlyDay)
        }
        if let timeText = goal.timeText {
            parts.append(timeText)
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " \u{00b7} ")
    }
}

// MARK: - Yearly Goal Card for SwiftData

struct YearlyGoalCardSwiftData: View {
    let goal: GoalModel
    let category: CategoryModel?
    let completed: Int
    let target: Int
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary.opacity(0.9))
                        .tracking(0.3)
                    
                    Text("\(category?.name ?? "") • \(goal.recurrenceText)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(completed)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary.opacity(0.9))
                    
                    Text("/")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary.opacity(0.2))
                    
                    Text("\(target)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                    
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    (category?.color ?? AppColors.primary).opacity(0.4),
                                    (category?.color ?? AppColors.primary).opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.ultraThinMaterial.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous)
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    GoalsView(selectedTab: .constant(.goals))
}
