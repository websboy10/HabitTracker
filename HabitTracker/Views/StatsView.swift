import SwiftUI
import SwiftData

/// Stats view - the single authoritative location for all statistics.
/// Read-only. No actions. No explanations. No rewards.
struct StatsView: View {

    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: Tab
    var showsCustomTabBar: Bool = true

    @State private var statsCalculator: StatsCalculator?
    @State private var selectedWeek: WeekLedgerEntry?
    @State private var selectedMonth: Date = Date()
    @State private var showMonthPicker: Bool = false
    
    // Observe model changes to trigger re-renders when data is deleted/added
    @Query private var obligations: [ObligationModel]
    @Query private var goals: [GoalModel]

    var body: some View {
        let _ = obligations.count + goals.count
        ZStack {
            AppMaterials.moodGradient

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // SECTION 1: Primary Reality Block (Rolling 12-Month)
                    primaryRealitySection
                        .padding(.bottom, AppSpacing.xl)

                    // SECTION 2: Month Progress (Time vs Obligations)
                    monthProgressSection
                        .padding(.bottom, AppSpacing.xl)

                    // SECTION 3: Weekly Ledger
                    weeklyLedgerSection
                        .padding(.bottom, AppSpacing.xl)

                    // SECTION 4: Lifetime Missed
                    lifetimeMissedSection
                        .padding(.bottom, AppSpacing.xl)

                    // SECTION 5: Goal Consistency Table
                    goalConsistencySection
                        .padding(.bottom, AppSpacing.xl)

                    // SECTION 6: Archive
                    archiveSection
                        .padding(.bottom, 120)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.xl)
            }

            if showsCustomTabBar {
                VStack {
                    Spacer()
                    bottomNavigation
                }
            }
        }
        .onAppear {
            // Ensure obligations exist for all displayed periods (Row-Based Truth)
            let scheduler = ObligationScheduler(modelContext: modelContext)
            scheduler.ensureRolling12MonthObligations()

            // Initialize stats calculator
            statsCalculator = StatsCalculator(modelContext: modelContext)
        }
        .sheet(item: $selectedWeek) { week in
            WeekDetailSheet(week: week)
        }
    }

    // MARK: - Section 1: Primary Reality Block

    private var primaryRealitySection: some View {
        let stats = statsCalculator?.yearlyStats() ?? YearlyStats(
            completedPercent: 0,
            year: Calendar.current.component(.year, from: Date())
        )

        return VStack(spacing: AppSpacing.lg) {
            consistencyRing(percentage: stats.completedPercent)

            Text("YEAR \(String(stats.year))")
                .font(AppTypography.caption)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundColor(AppColors.textMuted)
        }
    }

    private func consistencyRing(percentage: Double) -> some View {
        ZStack {
            AppComponents.GlowCircle(
                color: AppColors.primarySubtle,
                size: AppSpacing.progressRingSize
            )

            Circle()
                .stroke(
                    AppColors.trackBackground,
                    style: StrokeStyle(lineWidth: AppSpacing.progressRingStroke, lineCap: .round)
                )
                .frame(width: AppSpacing.progressRingSize - 32, height: AppSpacing.progressRingSize - 32)

            Circle()
                .trim(from: 0, to: percentage)
                .stroke(
                    AppColors.primary,
                    style: StrokeStyle(lineWidth: AppSpacing.progressRingStroke, lineCap: .round)
                )
                .frame(width: AppSpacing.progressRingSize - 32, height: AppSpacing.progressRingSize - 32)
                .rotationEffect(.degrees(-90))
                .shadow(color: AppColors.primaryGlow, radius: 6)

            VStack(spacing: AppSpacing.sm) {
                Text("\(Int(percentage * 100))%")
                    .font(AppTypography.displayLarge)
                    .foregroundColor(AppColors.textPrimary)
                    .shadow(color: .white.opacity(0.3), radius: 20)
            }
        }
    }

    private func statColumn(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.textPrimary)

            Text(label)
                .font(AppTypography.caption)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section 2: Month Progress

    private var monthProgressSection: some View {
        let stats = statsCalculator?.monthProgress(for: selectedMonth) ?? MonthProgressStats(
            completedPercent: 0,
            totalObligations: 0,
            completed: 0,
            missed: 0,
            pending: 0
        )

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Month selector header
            monthSelectorHeader(stats: stats)

            GlassCard {
                VStack(spacing: AppSpacing.lg) {
                    monthCompletionGauge(value: stats.completedPercent)

                    HStack {
                        monthStatItem(value: stats.completed, label: "COMPLETED")
                        Spacer()
                        monthStatItem(value: stats.missed, label: "MISSED")
                        Spacer()
                        monthStatItem(value: stats.pending, label: "PENDING")
                    }
                }
                .padding(AppSpacing.lg)
            }
        }
    }
    
    private func monthSelectorHeader(stats: MonthProgressStats) -> some View {
        HStack {
            Text("THIS MONTH")
                .font(AppTypography.caption)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            // Month dropdown
            Menu {
                ForEach(0..<12, id: \.self) { monthsAgo in
                    let monthDate = Calendar.current.date(byAdding: .month, value: -monthsAgo, to: Date()) ?? Date()
                    let formatter = DateFormatter()
                    let _ = (formatter.dateFormat = "MMMM yyyy")
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMonth = monthDate
                        }
                    }) {
                        HStack {
                            Text(formatter.string(from: monthDate))
                            if Calendar.current.isDate(monthDate, equalTo: selectedMonth, toGranularity: .month) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(stats.monthName.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.primary)
                        .tracking(1)
                    
                    Text(String(stats.year))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textMuted)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppColors.textMuted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
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

    private func monthCompletionGauge(value: Double) -> some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .stroke(AppColors.trackBackground, lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: value)
                    .stroke(AppColors.primary.opacity(0.7), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(value * 100))%")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)
            }

            Text("DONE")
                .font(AppTypography.caption)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func monthStatItem(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.textPrimary)

            Text(label)
                .font(.system(size: 8, weight: .medium))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(AppColors.textMuted)
        }
    }

    // MARK: - Section 3: Weekly Ledger

    private var weeklyLedgerSection: some View {
        let weeks = statsCalculator?.monthlyWeekLedger(for: selectedMonth) ?? []

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("WEEKLY LEDGER")

            GlassCard {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(weeks) { week in
                        Button {
                            selectedWeek = week
                        } label: {
                            weekCell(week: week, hasNote: hasNote(for: week))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppSpacing.lg)
            }
        }
    }

    private func weekCell(week: WeekLedgerEntry, hasNote: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(week.passed ? AppColors.primary.opacity(0.3) : Color.white.opacity(0.05))
                    .frame(height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(
                                week.passed ? AppColors.primary.opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: 1
                            )
                    )

                if hasNote {
                    Circle()
                        .fill(AppColors.primary.opacity(0.7))
                        .frame(width: 6, height: 6)
                        .padding(4)
                }
            }

            Text("\(week.weekNumber)")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(AppColors.textMuted)
        }
    }

    private func hasNote(for week: WeekLedgerEntry) -> Bool {
        // WeeklyNoteModel not available - stubbed out
        return false
    }

    // MARK: - Section 4: Lifetime Missed

    private var lifetimeMissedSection: some View {
        let missed = statsCalculator?.lifetimeMissed() ?? 0

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("LIFETIME")

            GlassCard {
                VStack(spacing: AppSpacing.sm) {
                    Text("MISSED")
                        .font(AppTypography.caption)
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundColor(AppColors.textMuted)

                    Text("\(missed)")
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            }
        }
    }

    // MARK: - Section 5: Goal Consistency Table

    private var goalConsistencySection: some View {
        let goals = statsCalculator?.goalConsistencyTable() ?? []

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("GOAL CONSISTENCY")

            if goals.isEmpty {
                GlassCard {
                    Text("No goals")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xl)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(goals) { entry in
                        goalConsistencyRow(entry: entry)
                    }
                }
            }
        }
    }

    private func goalConsistencyRow(entry: GoalConsistencyEntry) -> some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(entry.isActive ? AppColors.textPrimary : AppColors.textSecondary)
                        .lineLimit(1)

                    Text(formatDate(entry.activeSince))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                HStack(spacing: AppSpacing.lg) {
                    VStack(spacing: 2) {
                        Text("\(Int(entry.consistency * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.textPrimary)

                        Text("CONS")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(AppColors.textMuted)
                    }

                    VStack(spacing: 2) {
                        Text("\(entry.missedLifetime)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.textPrimary)

                        Text("MISS")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(AppColors.textMuted)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .opacity(entry.isActive ? 1.0 : 0.6)
    }

    // MARK: - Section 6: Archive

    private var archiveSection: some View {
        let years = statsCalculator?.yearlyArchive() ?? []

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("ARCHIVE")

            if years.isEmpty {
                GlassCard {
                    Text("No data")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xl)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(years) { year in
                        archiveYearRow(year: year)
                    }
                }
            }
        }
    }

    private func archiveYearRow(year: YearArchiveEntry) -> some View {
        GlassCard {
            HStack {
                Text(String(year.year))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                HStack(spacing: AppSpacing.lg) {
                    VStack(spacing: 2) {
                        Text("\(Int(year.weeksPassedPercent * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.textPrimary)

                        Text("WEEKS")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(AppColors.textMuted)
                    }

                    VStack(spacing: 2) {
                        Text("\(year.missedInYear)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.textPrimary)

                        Text("MISSED")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(AppColors.textMuted)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(AppColors.textSecondary)
            .textCase(.uppercase)
            .tracking(2)
            .padding(.leading, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
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

// MARK: - Week Detail Sheet

struct WeekDetailSheet: View {
    let week: WeekLedgerEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var noteText: String = ""
    // @State private var noteModel: WeeklyNoteModel? // Not available in target

    var body: some View {
        ZStack {
            AppColors.backgroundDark
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.lg)

                VStack(spacing: AppSpacing.sm) {
                    Text("WEEK \(week.weekNumber)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary)

                    Text(formatWeekDate(week.startDate))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                        .textCase(.uppercase)
                        .tracking(1)
                }

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(week.passed ? AppColors.primary.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 120, height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                week.passed ? AppColors.primary.opacity(0.4) : Color.white.opacity(0.1),
                                lineWidth: 2
                            )
                    )
                    .overlay(
                        Text(week.passed ? "PASSED" : "FAILED")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(week.passed ? AppColors.primary : AppColors.textMuted)
                    )

                VStack(spacing: AppSpacing.lg) {
                    detailRow(label: "OBLIGATIONS", value: "\(week.totalObligations)")
                    detailRow(label: "COMPLETED", value: "\(week.completed)")
                    detailRow(label: "MISSED", value: "\(week.missed)")
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("NOTE")
                        .font(AppTypography.caption)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundColor(AppColors.textSecondary)

                    GlassCard {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $noteText)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 140)

                            if noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Write a private note for this week...")
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.textMuted)
                                    .padding(.top, 8)
                                    .padding(.leading, 6)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)

                Spacer()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            loadNote()
        }
        .onChange(of: noteText) { _, newValue in
            persistNote(text: newValue)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
                .tracking(1)

            Spacer()

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }

    private func formatWeekDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func noteKey() -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: week.startDate)
        return "\(week.year)-\(month)-\(week.weekNumber)"
    }

    private func loadNote() {
        // WeeklyNoteModel not available - stubbed out
        noteText = ""
    }

    private func persistNote(text: String) {
        // WeeklyNoteModel not available - stubbed out
    }
}

// MARK: - Preview

#Preview {
    StatsView(selectedTab: .constant(.stats))
}
