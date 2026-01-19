import SwiftUI

/// Monthly ledger showing 4 weeks with progress and note access.
/// Tap a week to open the weekly note sheet.
struct WeekOverviewCard: View {

    /// Weekly progress data for weeks 1-4 (from obligations)
    let weeklyProgress: [(completed: Int, total: Int, percentage: Double)]

    /// Monthly totals for header (entire month)
    let monthlyTotals: (completed: Int, total: Int)?

    /// Month to display in the header
    let monthDate: Date

    /// Which weeks have notes (1-4 indexed as 0-3)
    let weeksWithNotes: Set<Int>

    /// Callback when a week is tapped
    var onWeekTapped: ((Int) -> Void)? = nil

    /// Computed totals for header display
    private var totalCompleted: Int {
        monthlyTotals?.completed ?? weeklyProgress.reduce(0) { $0 + $1.completed }
    }

    private var totalObligations: Int {
        monthlyTotals?.total ?? weeklyProgress.reduce(0) { $0 + $1.total }
    }

    var body: some View {
        GlassCard(highlight: true) {
            ZStack {
                // Ambient glow
                Circle()
                    .fill(AppColors.primary.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .blur(radius: 60)
                    .offset(x: 100, y: -20)
                    .allowsHitTesting(false)

                VStack(spacing: AppSpacing.md) {
                    // Header
                    ledgerHeader

                    // 4-week grid
                    weekGrid

                    // Hint for note writing
                    noteHint
                }
                .padding(AppSpacing.lg)
            }
        }
    }

    // MARK: - Header

    private var ledgerHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly Ledger")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1.5)

                Text(currentMonthYear)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textMuted)
            }

            Spacer()

            // Summary pill
            HStack(spacing: 4) {
                Text("\(totalCompleted)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Text("/ \(totalObligations)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppColors.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Week Grid

    private var weekGrid: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { weekNumber in
                weekCell(weekNumber: weekNumber)
            }
        }
    }

    private func weekCell(weekNumber: Int) -> some View {
        let isCurrentWeek = weekNumber == currentWeekOfMonth
        let weekIndex = weekNumber - 1
        let weekData = weeklyProgress[safe: weekIndex] ?? (0, 0, 0)
        let hasNote = weeksWithNotes.contains(weekNumber)

        return Button {
            onWeekTapped?(weekNumber)
        } label: {
            VStack(spacing: 6) {
                // Week number
                Text("\(weekNumber)")
                    .font(.system(size: 16, weight: isCurrentWeek ? .bold : .medium))
                    .foregroundColor(isCurrentWeek ? AppColors.textPrimary : AppColors.textSecondary)

                // Progress indicator - uses actual data
                weekProgressIndicator(progress: weekData.percentage, isCurrentWeek: isCurrentWeek)

                // Note indicator - connected to real data
                Circle()
                    .fill(hasNote ? AppColors.primary.opacity(0.6) : Color.white.opacity(0.1))
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(weekCellBackground(isCurrentWeek: isCurrentWeek))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(weekCellBorder(isCurrentWeek: isCurrentWeek))
        }
        .buttonStyle(WeekCellButtonStyle())
    }

    private func weekProgressIndicator(progress: Double, isCurrentWeek: Bool) -> some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 3)

            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isCurrentWeek ? AppColors.primary : AppColors.textMuted,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center dot when complete
            if progress >= 1.0 {
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 28, height: 28)
        .shadow(
            color: isCurrentWeek && progress > 0 ? AppColors.primary.opacity(0.4) : .clear,
            radius: 6
        )
    }

    private func weekCellBackground(isCurrentWeek: Bool) -> some View {
        Group {
            if isCurrentWeek {
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color.white.opacity(0.02)
            }
        }
    }

    private func weekCellBorder(isCurrentWeek: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(
                isCurrentWeek ? Color.white.opacity(0.15) : Color.white.opacity(0.05),
                lineWidth: 1
            )
    }

    // MARK: - Note Hint

    private var noteHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "pencil.line")
                .font(.system(size: 10, weight: .medium))

            Text("Tap a week to reflect")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(AppColors.textMuted)
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthDate)
    }

    private var currentWeekOfMonth: Int {
        let calendar = Calendar.current
        guard calendar.isDate(monthDate, equalTo: Date(), toGranularity: .month) else { return 0 }
        let day = calendar.component(.day, from: Date())
        return min(((day - 1) / 7) + 1, 4)
    }
}

// MARK: - Week Cell Button Style

private struct WeekCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient

        WeekOverviewCard(
            weeklyProgress: [
                (completed: 5, total: 7, percentage: 0.71),
                (completed: 3, total: 7, percentage: 0.43),
                (completed: 0, total: 7, percentage: 0.0),
                (completed: 0, total: 0, percentage: 0.0)
            ],
            monthlyTotals: (completed: 20, total: 28),
            monthDate: Date(),
            weeksWithNotes: [1, 2]
        ) { weekNumber in
            print("Tapped week \(weekNumber)")
        }
        .padding(AppSpacing.screenHorizontal)
    }
}
