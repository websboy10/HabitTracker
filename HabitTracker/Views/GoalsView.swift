import SwiftUI
import SwiftData

private struct GoalsStackFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct RowStrideKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private enum AutoScrollDirection {
    case up
    case down
    case none
}

/// Goals management view with tabbed layout and SwiftData persistence.
struct GoalsView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = GoalsViewModel()
    @Binding var selectedTab: Tab
    var showsCustomTabBar: Bool = true

    // Observe goals to trigger re-renders on changes, sorted by orderIndex
    @Query(sort: \GoalModel.orderIndex, order: .forward) private var allGoals: [GoalModel]
    @State private var orderedGoals: [GoalModel] = []
    @State private var goalsStackFrame: CGRect = .zero
    @State private var scrollViewHeight: CGFloat = 0
    @State private var activeDragGoalId: UUID?
    @State private var activeDragIndex: Int?
    @State private var isReordering = false
    @State private var isReorderMode = false
    @State private var autoScrollDirection: AutoScrollDirection = .none
    @State private var autoScrollAnchorIndex: Int?
    @State private var measuredRowStride: CGFloat = 0
    @State private var dragRowStride: CGFloat = 0

    private let autoScrollTick = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()
    private let autoScrollEdgeInset: CGFloat = 72
    private let defaultRowStride: CGFloat = 84

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
            NavigationLogger.shared.logViewAppear("GoalsView")
            viewModel.configure(with: modelContext)
            syncOrderedGoals()
        }
        .onDisappear {
            NavigationLogger.shared.logViewDisappear("GoalsView")
        }
        .onChange(of: allGoals) { _, _ in
            if isReordering {
                cancelDrag()
            }
            syncOrderedGoals()
        }
        .onChange(of: viewModel.selectedTab) { _, _ in
            cancelDrag()
            isReorderMode = false
            syncOrderedGoals()
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
            HStack(spacing: 8) {
                Button {
                    toggleReorderMode()
                } label: {
                    Text(isReorderMode ? "Done" : "Reorder")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

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
        }
        .padding(.leading, 4)
    }
    
    // MARK: - Goals List

    private var goalsList: some View {
        GeometryReader { scrollGeo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        header
                            .padding(.top, AppSpacing.xl)
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                            .padding(.bottom, AppSpacing.lg)

                        GoalTabPicker(selection: Binding(
                            get: { GoalFrequency(rawValue: viewModel.selectedTab) ?? .daily },
                            set: { viewModel.selectedTab = $0.rawValue }
                        ))
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.bottom, AppSpacing.lg)

                        goalsStack

                        Color.clear
                            .frame(height: 140)
                    }
                }
                .coordinateSpace(name: "GoalsScroll")
                .scrollDisabled(isReorderMode)
                .onAppear {
                    scrollViewHeight = scrollGeo.size.height
                }
                .onChange(of: scrollGeo.size.height) { _, newHeight in
                    scrollViewHeight = newHeight
                }
                .onReceive(autoScrollTick) { _ in
                    guard isReordering, autoScrollDirection != .none else { return }
                    autoScrollStep(proxy: proxy)
                }
            }
        }
    }

    private var goalsStack: some View {
        VStack(spacing: 0) {
            if orderedGoals.isEmpty {
                emptyState
                    .padding(.horizontal, AppSpacing.screenHorizontal)
            } else {
                ForEach(orderedGoals, id: \.id) { goal in
                    GoalRow(
                        goal: goal,
                        onEdit: { viewModel.editGoal(goal) },
                        onToggleStatus: { viewModel.toggleStatus(goal) }
                    )
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                    .allowsHitTesting(!isReorderMode)
                    .background(
                        Group {
                            if measuredRowStride == 0,
                               orderedGoals.first?.id == goal.id {
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: RowStrideKey.self,
                                        value: proxy.size.height
                                    )
                                }
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .id(goal.id)
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: GoalsStackFrameKey.self,
                    value: proxy.frame(in: .named("GoalsScroll"))
                )
            }
        )
        .onPreferenceChange(GoalsStackFrameKey.self) { frame in
            goalsStackFrame = frame
        }
        .onPreferenceChange(RowStrideKey.self) { height in
            guard height > 0 else { return }
            if measuredRowStride == 0 || abs(measuredRowStride - height) > 0.5 {
                measuredRowStride = height
            }
        }
        .overlay(reorderGestureOverlay)
    }

    private var reorderGestureOverlay: some View {
        Group {
            if isReorderMode {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(reorderGesture)
            }
        }
    }

    private var reorderGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("GoalsScroll"))
            .onChanged { value in
                if !isReordering {
                    beginDrag(at: value.startLocation)
                }
                if isReordering {
                    updateDrag(at: value.location)
                }
            }
            .onEnded { _ in
                endDrag()
            }
    }

    private func syncOrderedGoals() {
        guard !isReordering else { return }
        orderedGoals = allGoals
            .filter { $0.recurrenceType == viewModel.selectedTab }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private var rowStride: CGFloat {
        guard !orderedGoals.isEmpty else { return 0 }
        if dragRowStride > 0 {
            return dragRowStride
        }
        if measuredRowStride > 0 {
            return measuredRowStride
        }
        if goalsStackFrame.height > 0 {
            return goalsStackFrame.height / CGFloat(orderedGoals.count)
        }
        return defaultRowStride
    }

    private func beginDrag(at location: CGPoint) {
        guard !isReordering else { return }
        guard !orderedGoals.isEmpty else { return }
        guard goalsStackFrame != .zero else {
            debugLog("beginDrag: goalsStackFrame is zero")
            return
        }
        guard goalsStackFrame.contains(location) else { return }
        let stride = rowStride
        guard stride > 0 else {
            debugLog("beginDrag: rowStride is zero")
            return
        }
        guard let index = targetIndex(for: location.y, rowStride: stride) else {
            debugLog("beginDrag: targetIndex nil")
            return
        }
        isReordering = true
        activeDragIndex = index
        activeDragGoalId = orderedGoals[index].id
        autoScrollAnchorIndex = index
        dragRowStride = stride
        debugLog("beginDrag: index=\(index) stride=\(stride) frame=\(goalsStackFrame)")
    }

    private func updateDrag(at location: CGPoint) {
        guard isReordering, let currentIndex = activeDragIndex else {
            debugLog("updateDrag: guard failed isReordering=\(isReordering) activeDragIndex=\(String(describing: activeDragIndex))")
            return
        }
        updateAutoScroll(for: location.y)
        let stride = rowStride
        guard let targetIndex = targetIndex(for: location.y, rowStride: stride) else {
            debugLog("updateDrag: targetIndex nil stride=\(stride) frame=\(goalsStackFrame)")
            return
        }
        if currentIndex != targetIndex {
            moveGoal(from: currentIndex, to: targetIndex)
            activeDragIndex = targetIndex
            autoScrollAnchorIndex = targetIndex
        }
    }

    private func targetIndex(for dragLocationY: CGFloat, rowStride: CGFloat) -> Int? {
        guard !orderedGoals.isEmpty, rowStride > 0 else { return nil }
        let relativeY = dragLocationY - goalsStackFrame.minY
        let adjustedY = relativeY - (rowStride / 2)
        let rawIndex = Int(floor(adjustedY / rowStride))
        return min(max(rawIndex, 0), orderedGoals.count - 1)
    }

    private func moveGoal(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex != targetIndex else { return }
        var updated = orderedGoals
        let goal = updated.remove(at: sourceIndex)
        updated.insert(goal, at: min(max(0, targetIndex), updated.count))
        orderedGoals = updated
    }

    private func updateAutoScroll(for dragLocationY: CGFloat) {
        guard scrollViewHeight > 0 else { return }
        let topEdge = autoScrollEdgeInset
        let bottomEdge = scrollViewHeight - autoScrollEdgeInset
        if dragLocationY < topEdge {
            autoScrollDirection = .up
        } else if dragLocationY > bottomEdge {
            autoScrollDirection = .down
        } else {
            autoScrollDirection = .none
        }
    }

    private func autoScrollStep(proxy: ScrollViewProxy) {
        guard let anchorIndex = autoScrollAnchorIndex else { return }
        let direction = autoScrollDirection
        guard direction != .none else { return }
        let delta = direction == .up ? -1 : 1
        let nextIndex = min(max(anchorIndex + delta, 0), orderedGoals.count - 1)
        guard nextIndex != anchorIndex else { return }
        autoScrollAnchorIndex = nextIndex
        withAnimation(.linear(duration: 0.08)) {
            proxy.scrollTo(orderedGoals[nextIndex].id, anchor: direction == .up ? .top : .bottom)
        }
    }

    private func endDrag() {
        guard activeDragGoalId != nil else { return }
        autoScrollDirection = .none
        autoScrollAnchorIndex = nil
        activeDragGoalId = nil
        activeDragIndex = nil
        isReordering = false
        dragRowStride = 0
        persistGoalOrder()
    }

    private func cancelDrag() {
        autoScrollDirection = .none
        autoScrollAnchorIndex = nil
        activeDragGoalId = nil
        activeDragIndex = nil
        isReordering = false
        dragRowStride = 0
    }

    private func toggleReorderMode() {
        if isReorderMode {
            cancelDrag()
            isReorderMode = false
        } else {
            isReorderMode = true
        }
    }

    private func debugLog(_ message: String) {
#if DEBUG
        print("[GoalsReorder] \(message)")
#endif
    }

    private func persistGoalOrder() {
        for (index, goal) in orderedGoals.enumerated() {
            goal.orderIndex = index
        }
        try? modelContext.save()
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
        .modelContainer(PreviewModelContainer.container)
}
