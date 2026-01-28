import SwiftUI
import SwiftData

// MARK: - Int Identifiable for sheet(item:)
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

/// The main Home screen with scrollable dashboard.
/// Uses obligation-based system for tracking.
struct HomeView: View {

    @Environment(\.modelContext) private var modelContext
    @StateObject private var session = AppSessionManager.shared
    @State private var viewModel = HomeViewModel()
    @Binding var selectedTab: Tab
    var showsCustomTabBar: Bool = true

    // Observe model changes to trigger re-renders when data is deleted/added
    @Query private var obligations: [ObligationModel]
    @Query(sort: \GoalModel.orderIndex, order: .forward) private var goals: [GoalModel]
    @Query private var weeklyNotes: [WeeklyNoteModel]
    @Query private var snapshots: [SnapshotModel]
    
    // Calendar service for busy day awareness (disabled - not in project)
    // @StateObject private var calendarService = CalendarService.shared

    // Weekly note sheet state
    @State private var selectedWeekForNote: Int? = nil
    @State private var selectedMonth = Date()
    @State private var snapshotDataCache: SnapshotData?

    var body: some View {
        let _ = obligations.count + goals.count
        ZStack {
            // Fixed background
            AppMaterials.moodGradient

            // Scrollable content with automatic scroll reset
            ResetScrollView(viewName: "HomeView", showsIndicators: false) {
                VStack(spacing: 0) {
                    // SECTION 1: Hero / Daily Dashboard
                    heroSection
                        .padding(.bottom, AppSpacing.xl)

                    // SECTION 2: Today's Obligations
                    if isCurrentMonth {
                        todayObligationsSection
                            .padding(.bottom, AppSpacing.xl)
                    }

                    // SECTION 3: This Week
                    thisWeekSection
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
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                return
            }
            NavigationLogger.shared.logViewAppear("HomeView")
            viewModel.configure(with: modelContext)
            preloadNotesForSelectedMonth()
            refreshSnapshotData()
        }
        .onDisappear {
            NavigationLogger.shared.logViewDisappear("HomeView")
        }
        .onChange(of: session.securityLock) { _, locked in
            if !locked {
                preloadNotesForSelectedMonth()
            }
        }
        .onChange(of: selectedMonth) { _, _ in
            preloadNotesForSelectedMonth()
            refreshSnapshotData()
        }
        .onChange(of: snapshots) { _, _ in
            refreshSnapshotData()
        }
        .sheet(item: $selectedWeekForNote) { weekIndex in
            WeeklyNoteSheet(
                year: selectedYear,
                month: selectedMonthIndex,
                weekIndex: weekIndex,
                isPresented: Binding(
                    get: { selectedWeekForNote != nil },
                    set: { if !$0 { selectedWeekForNote = nil } }
                )
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
        }
    }

    // MARK: - Date Helpers

    private var selectedYear: Int {
        Calendar.current.component(.year, from: selectedMonth)
    }

    private var selectedMonthIndex: Int {
        Calendar.current.component(.month, from: selectedMonth)
    }

    /// Set of week numbers (1-4) that have notes for current month
    private var weeksWithNotes: Set<Int> {
        let year = selectedYear
        let month = selectedMonthIndex
        var result = Set<Int>()
        for note in weeklyNotes {
            if note.year == year && note.month == month && !note.text.isEmpty {
                result.insert(note.weekIndex)
            }
        }
        return result
    }

    // MARK: - Section 1: Hero

    private var heroSection: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressRing(
                percentage: viewModel.completionPercentage,
                label: "Today"
            )

            statsBar
            
            // Calendar awareness indicator (disabled - CalendarService not in project)
            // if calendarService.isAuthorized {
            //     let todayEvents = calendarService.todaysEvents()
            //     if !todayEvents.isEmpty {
            //         calendarIndicator(eventCount: todayEvents.count)
            //     }
            // }
        }
    }
    
    private func calendarIndicator(eventCount: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textMuted)
            
            Text("\(eventCount) event\(eventCount == 1 ? "" : "s") today")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var statsBar: some View {
        GlassCard {
            HStack {
                statItem(value: viewModel.totalCount, label: "TOTAL", color: AppColors.textPrimary)

                AppComponents.VerticalSeparator(height: 32)

                statItem(value: viewModel.completedCount, label: "DONE", color: AppColors.primary, hasGlow: true)

                AppComponents.VerticalSeparator(height: 32)

                // Show missed if any, otherwise show pending
                if viewModel.missedCount > 0 {
                    statItem(value: viewModel.missedCount, label: "MISSED", color: AppColors.textPrimary.opacity(0.6))
                } else {
                    statItem(value: viewModel.remainingCount, label: "LEFT", color: AppColors.textPrimary.opacity(0.8))
                }
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

    // MARK: - Section 2: Today's Obligations

    private var todayObligationsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("Today's Obligations")

            let obligations = viewModel.fetchTodaysObligations()

            if obligations.isEmpty {
                emptyObligationsState
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                ObligationsListView(
                    obligations: obligations,
                    isCurrentMonth: isCurrentMonth,
                    canToggle: viewModel.canToggleObligation,
                    onComplete: { obligation in
                        withAnimation(AppAnimation.standard) {
                            viewModel.completeObligation(obligation)
                        }
                    },
                    onMove: { source, destination in
                        moveObligations(from: source, to: destination, in: obligations)
                    }
                )
            }
        }
    }

    // MARK: - Reorder Logic

    /// Reorders goals based on obligation positions.
    /// When user reorders obligations, we update the underlying goal orderIndex values.
    private func moveObligations(from source: IndexSet, to destination: Int, in obligations: [(obligation: ObligationModel, goal: GoalModel)]) {
        var reorderedObligations = obligations
        reorderedObligations.move(fromOffsets: source, toOffset: destination)

        // Update goal orderIndex based on new obligation positions
        for (index, item) in reorderedObligations.enumerated() {
            item.goal.orderIndex = index
        }

        try? modelContext.save()
    }

    private var emptyObligationsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(AppColors.textMuted)

            Text("No obligations for today")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            Text("Add goals in the Goals tab")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Section 3: This Month

    private var thisWeekSection: some View {
        let snapshotData = snapshotData

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            monthSelectorHeader

            if isCurrentMonth {
                WeekOverviewCard(
                    weeklyProgress: viewModel.monthlyWeekProgress(for: selectedMonth),
                    monthlyTotals: viewModel.monthlyTotals(for: selectedMonth),
                    monthDate: selectedMonth,
                    weeksWithNotes: weeksWithNotes
                ) { weekIndex in
                    selectedWeekForNote = weekIndex
                }
            } else if let snapshotData {
                WeekOverviewCard(
                    weeklyProgress: snapshotData.ledger.toWeeklyProgress(),
                    monthlyTotals: snapshotData.stats.monthlyTotals,
                    monthDate: selectedMonth,
                    weeksWithNotes: weeksWithNotes
                ) { weekIndex in
                    selectedWeekForNote = weekIndex
                }
            } else {
                MissingSnapshotView()
            }
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

    private var monthSelectorHeader: some View {
        HStack {
            Text("THIS MONTH")
                .font(AppTypography.caption)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundColor(AppColors.textSecondary)

            if isCurrentMonth {
                LiveBadge()
            } else {
                ArchivedBadge()
            }

            Spacer()

            Menu {
                ForEach(monthOptions) { option in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMonth = option.date
                        }
                    }) {
                        HStack {
                            Text(option.label)
                            Spacer()

                            if option.isCurrentMonth {
                                Text("Live")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(AppColors.primary)
                            } else if availableSnapshotKeys.contains(option.id) {
                                Text("Archived")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(AppColors.textMuted)
                            } else {
                                Text("No Data")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(AppColors.textMuted)
                            }

                            if option.id == selectedMonthKey {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("\(monthLabel.uppercased()) \(selectedYear)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.primary)
                        .tracking(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .layoutPriority(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppColors.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AppColors.primary.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: selectedMonth)
    }

    // MARK: - Month Helpers

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var selectedMonthKey: String {
        String(format: "%04d-%02d", selectedYear, selectedMonthIndex)
    }

    private var snapshotData: SnapshotData? {
        snapshotDataCache
    }

    private var availableSnapshotKeys: Set<String> {
        Set(
            snapshots
                .filter { $0.status == .available }
                .map(\.compositeKey)
        )
    }

    private var monthOptions: [MonthOption] {
        let calendar = Calendar.current
        let now = Date()
        var options: [MonthOption] = []

        for monthsAgo in 0..<12 {
            guard let date = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else { continue }
            let comps = calendar.dateComponents([.year, .month], from: date)
            if let year = comps.year, let month = comps.month {
                options.append(MonthOption(year: year, month: month))
            }
        }

        let snapshotOptions = snapshots
            .filter { $0.status == .available }
            .map { MonthOption(year: $0.year, month: $0.month) }

        for option in snapshotOptions where !options.contains(option) {
            options.append(option)
        }

        return options.sorted { $0.id > $1.id }
    }

    private struct MonthOption: Identifiable, Hashable {
        let year: Int
        let month: Int

        var id: String {
            String(format: "%04d-%02d", year, month)
        }

        var date: Date {
            Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        }

        var label: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }

        var isCurrentMonth: Bool {
            Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
        }
    }

    private func preloadNotesForSelectedMonth() {
        guard AppSessionManager.shared.state == .running,
              !AppSessionManager.shared.securityLock else { return }
        let year = selectedYear
        let month = selectedMonthIndex
        Task {
            await WeeklyNoteService.shared.preloadNotes(
                year: year,
                month: month,
                modelContext: modelContext
            )
        }
    }

    private func refreshSnapshotData() {
        guard !isCurrentMonth else {
            snapshotDataCache = nil
            return
        }

        guard let snapshot = snapshots.first(where: {
            $0.year == selectedYear && $0.month == selectedMonthIndex && $0.status == .available
        }) else {
            snapshotDataCache = nil
            return
        }

        snapshotDataCache = SnapshotService.shared.decodeSnapshot(snapshot)
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

// MARK: - Obligations List View (Reorderable)

/// A List-based view for displaying obligations with native drag-to-reorder support.
struct ObligationsListView: View {
    let obligations: [(obligation: ObligationModel, goal: GoalModel)]
    let isCurrentMonth: Bool
    let canToggle: (ObligationModel) -> Bool
    let onComplete: (ObligationModel) -> Void
    let onMove: (IndexSet, Int) -> Void

    var body: some View {
        List {
            ForEach(obligations, id: \.obligation.id) { item in
                ObligationCard(
                    obligation: item.obligation,
                    goal: item.goal,
                    canToggle: isCurrentMonth && canToggle(item.obligation)
                ) {
                    onComplete(item.obligation)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: AppSpacing.md, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onMove(perform: onMove)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .frame(minHeight: CGFloat(obligations.count * 100))
        .environment(\.editMode, .constant(.active))
    }
}

// MARK: - Obligation Card

struct ObligationCard: View {

    let obligation: ObligationModel
    let goal: GoalModel
    let canToggle: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            if canToggle {
                onTap()
            }
        }) {
            HStack(spacing: AppSpacing.md) {
                completionIndicator

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(AppTypography.body)
                        .fontWeight(.medium)
                        .foregroundColor(statusTextColor)
                        .strikethrough(obligation.isCompleted, color: AppColors.textPrimary.opacity(0.3))
                        .tracking(0.3)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text(goal.categoryName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(goal.categoryColor.opacity(0.8))

                        Text(statusLabel)
                            .font(AppTypography.caption)
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundColor(statusLabelColor)
                            .fontWeight(.semibold)
                    }

                    Text(scheduledLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                // Multi-completion progress indicator (only shown when requiredCount > 1)
                if goal.hasMultipleCompletions {
                    multiCompletionBadge
                }

                if obligation.isPending && !goal.hasMultipleCompletions {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AppColors.trackBackground)
                        .frame(width: 4, height: 32)
                }
            }
            .padding(AppSpacing.md)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius, style: .continuous))
            .overlay(cardBorder)
            .shadow(color: shadowColor, radius: shadowRadius, y: 4)
        }
        .buttonStyle(ObligationButtonStyle())
        .disabled(!canToggle)
    }

    private var statusLabel: String {
        if obligation.isCompleted { return "Completed" }
        if obligation.isMissed { return "Missed" }

        // For multi-completion goals with partial progress, show count
        if goal.hasMultipleCompletions && obligation.completedCount > 0 {
            return "\(obligation.completedCount)/\(goal.requiredCount)"
        }

        return "Pending"
    }

    private var scheduledLabel: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: obligation.scheduledAt)
        let hasTime = (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = hasTime ? .short : .none
        let base = dateFormatter.string(from: obligation.scheduledAt)

        if hasTime {
            return base
        }
        return "\(base) • Any time"
    }

    private var statusTextColor: Color {
        if obligation.isMissed { return AppColors.textPrimary.opacity(0.5) }
        return AppColors.textPrimary
    }

    private var statusLabelColor: Color {
        if obligation.isCompleted { return AppColors.primary.opacity(0.7) }
        if obligation.isMissed { return AppColors.textMuted }
        return AppColors.textMuted
    }

    private var shadowColor: Color {
        if obligation.isCompleted { return AppColors.primary.opacity(0.15) }
        return .black.opacity(0.2)
    }

    private var shadowRadius: CGFloat {
        obligation.isCompleted ? 15 : 8
    }

    private var completionIndicator: some View {
        Circle()
            .fill(indicatorFill)
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .stroke(indicatorStroke, lineWidth: 1)
            )
            .overlay(indicatorContent)
            .shadow(color: obligation.isCompleted ? AppColors.primary.opacity(0.3) : .clear, radius: 15)
    }

    private var indicatorFill: Color {
        if obligation.isCompleted { return AppColors.primary.opacity(0.2) }
        if obligation.isMissed { return Color.white.opacity(0.02) }
        return Color.white.opacity(0.05)
    }

    private var indicatorStroke: Color {
        if obligation.isCompleted { return AppColors.primary.opacity(0.4) }
        if obligation.isMissed { return Color.white.opacity(0.05) }
        return Color.white.opacity(0.1)
    }

    @ViewBuilder
    private var indicatorContent: some View {
        if obligation.isCompleted {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.primary)
        } else if obligation.isMissed {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textMuted)
        } else {
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 8, height: 8)
        }
    }

    // MARK: - Multi-Completion Badge

    /// Badge showing progress for multi-completion goals (e.g., "2/5")
    private var multiCompletionBadge: some View {
        let progress = obligation.completionProgress(requiredCount: goal.requiredCount)
        let isPartiallyComplete = obligation.completedCount > 0 && !obligation.isCompleted

        return HStack(spacing: 4) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(AppColors.trackBackground, lineWidth: 3)
                    .frame(width: 28, height: 28)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isPartiallyComplete ? AppColors.primary.opacity(0.8) : AppColors.primary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))

                if obligation.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.primary)
                }
            }

            // Count label
            Text("\(obligation.completedCount)/\(goal.requiredCount)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(badgeTextColor)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(badgeBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(badgeBorderColor, lineWidth: 1)
        )
    }

    private var badgeTextColor: Color {
        if obligation.isCompleted { return AppColors.primary }
        if obligation.completedCount > 0 { return AppColors.textPrimary }
        return AppColors.textMuted
    }

    private var badgeBackground: Color {
        if obligation.isCompleted { return AppColors.primary.opacity(0.15) }
        if obligation.completedCount > 0 { return Color.white.opacity(0.08) }
        return Color.white.opacity(0.04)
    }

    private var badgeBorderColor: Color {
        if obligation.isCompleted { return AppColors.primary.opacity(0.3) }
        if obligation.completedCount > 0 { return AppColors.primary.opacity(0.2) }
        return Color.white.opacity(0.08)
    }

    private var cardBackground: some View {
        Group {
            if obligation.isCompleted {
                LinearGradient(
                    colors: [AppColors.primary.opacity(0.2), AppColors.primary.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else if obligation.isMissed {
                Color.white.opacity(0.02)
            } else {
                AppColors.glassBackground
            }
        }
        .background(.ultraThinMaterial.opacity(obligation.isMissed ? 0.1 : 0.3))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius, style: .continuous)
            .stroke(
                obligation.isCompleted
                    ? AppColors.primary.opacity(0.3)
                    : (obligation.isMissed ? Color.white.opacity(0.05) : AppColors.glassBorder),
                lineWidth: 1
            )
    }
}

private struct ObligationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    HomeView(selectedTab: .constant(.home))
        .modelContainer(PreviewModelContainer.container)
}
