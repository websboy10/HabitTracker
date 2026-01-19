import SwiftUI
import SwiftData

/// Goals management view with tabbed layout and SwiftData persistence.
struct GoalsView: View {
    
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = GoalsViewModel()
    @Binding var selectedTab: Tab
    var showsCustomTabBar: Bool = true
    
    // Observe goals to trigger re-renders on changes
    @Query private var allGoals: [GoalModel]
    
    var body: some View {
        // Force observation of goals to trigger re-renders on changes
        let _ = allGoals.count
        
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
            NavigationLogger.shared.logViewAppear("GoalsView")
            viewModel.configure(with: modelContext)
        }
        .onDisappear {
            NavigationLogger.shared.logViewDisappear("GoalsView")
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

                let goals = allGoals.filter { $0.recurrenceType == viewModel.selectedTab }
                if goals.isEmpty {
                    emptyState
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(goals, id: \.id) { goal in
                        GoalRow(
                            goal: goal,
                            onEdit: { viewModel.editGoal(goal) },
                            onToggleStatus: { viewModel.toggleStatus(goal) }
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 12, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.deleteGoal(goal)
                                }
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
        .contentMargins(.bottom, 140, for: .scrollContent)
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
                colors: [.clear, AppColors.backgroundDark.opacity(0.96), AppColors.backgroundDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 72)
            
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
    var onEdit: (() -> Void)? = nil
    var onToggleStatus: (() -> Void)? = nil

    private var accent: Color {
        goal.categoryColor
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(accent.opacity(goal.isActive ? 0.9 : 0.4))
                .frame(width: 5, height: 40)
                .shadow(color: accent.opacity(goal.isActive ? 0.4 : 0.0), radius: 6)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(goal.categoryName)
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
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)

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

// MARK: - Preview

#Preview {
    GoalsView(selectedTab: .constant(.goals))
}
