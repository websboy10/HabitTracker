import SwiftUI

struct OnboardingSystemConfigView: View {

    @Bindable var viewModel: OnboardingViewModel
    @State private var selectedAppTheme: AppTheme = .red
    @State private var showingTimePicker = false

    var body: some View {
        ZStack {
            AppMaterials.moodGradient

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, 40)

                    VStack(spacing: AppSpacing.lg) {
                        interfaceSection
                        behaviorSection
                        chronometrySection
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.xl)

                    Spacer().frame(height: 180)
                }
            }

            nextButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
        }
        .onAppear {
            // Sync theme selection with viewModel
            switch viewModel.themeVariant {
            case .crimson: selectedAppTheme = .red
            case .onyx: selectedAppTheme = .blue
            case .grove: selectedAppTheme = .forest
            case .blossom: selectedAppTheme = .pink
            case .gold: selectedAppTheme = .amber
            case .aubergine: selectedAppTheme = .purple
            case .gunmetal: selectedAppTheme = .graphite
            case .steel: selectedAppTheme = .teal
            }
        }
        .onChange(of: selectedAppTheme) { _, newValue in
            // Map AppTheme to OnboardingThemeVariant
            let variant: OnboardingThemeVariant
            switch newValue {
            case .red: variant = .crimson
            case .blue: variant = .onyx
            case .forest: variant = .grove
            case .pink: variant = .blossom
            case .amber: variant = .gold
            case .purple: variant = .aubergine
            case .graphite: variant = .gunmetal
            case .teal: variant = .steel
            case .green: variant = .grove // fallback
            }
            viewModel.themeVariant = variant
            ThemeManager.shared.setTheme(newValue)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    viewModel.previousStep()
                } label: {
                    Circle()
                        .fill(Color.white.opacity(0.03))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.4))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)

                    Capsule()
                        .fill(AppColors.primary)
                        .frame(width: 24, height: 6)
                        .shadow(color: AppColors.primary.opacity(0.6), radius: 4)

                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, AppSpacing.xl)

            Text("System\nConfiguration")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.3)
                .lineSpacing(2)
                .padding(.bottom, 8)

            Text("Set up your tracking parameters")
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(3)
                .foregroundColor(Color.white.opacity(0.4))
        }
    }

    // MARK: - Interface Section

    private var interfaceSection: some View {
        GlassSection(title: "Interface", icon: "paintpalette") {
            AccentColorPicker(
                selectedTheme: $selectedAppTheme,
                reduceMotion: false
            )
        }
    }

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        GlassSection(title: "Behavior", icon: "slider.horizontal.3") {
            VStack(spacing: 20) {
                // Haptic Feedback
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haptic Feedback")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.9))

                        Text("Tactile response on interaction")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.4))
                    }

                    Spacer()

                    Toggle("", isOn: $viewModel.hapticsEnabled)
                        .toggleStyle(GlassToggleStyle(reduceMotion: false))
                        .onChange(of: viewModel.hapticsEnabled) { _, newValue in
                            // Apply haptic setting immediately
                            HapticManager.shared.setEnabled(newValue)
                            // Give feedback if enabling
                            if newValue {
                                HapticManager.shared.light()
                            }
                        }
                }

                Divider()
                    .background(Color.white.opacity(0.05))

                // Week Start
                VStack(alignment: .leading, spacing: 12) {
                    Text("Week Cycle Start")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.8))

                    HStack(spacing: 0) {
                        ForEach(WeekStart.allCases, id: \.self) { start in
                            SegmentButton(
                                title: start.rawValue,
                                isSelected: viewModel.weekStart == start
                            ) {
                                viewModel.weekStart = start
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                }

                Divider()
                    .background(Color.white.opacity(0.05))

                // Month Calculation
                VStack(alignment: .leading, spacing: 12) {
                    Text("Metric Calculation")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.8))

                    HStack(spacing: 0) {
                        ForEach(MonthCalculation.allCases, id: \.self) { calc in
                            SegmentButton(
                                title: calc.rawValue,
                                isSelected: viewModel.monthCalculation == calc
                            ) {
                                viewModel.monthCalculation = calc
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Chronometry Section

    private var chronometrySection: some View {
        GlassSection(title: "Chronometry", icon: "clock") {
            Button { showingTimePicker = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day Reset Time")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimary.opacity(0.9))

                        Text("Tasks reset after this time")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Text(viewModel.dayResetTimeFormatted)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(AppColors.textPrimary)

                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingTimePicker) {
            timePickerSheet
        }
    }

    // MARK: - Time Picker Sheet

    private var timePickerSheet: some View {
        NavigationStack {
            ZStack {
                AppMaterials.moodGradient.ignoresSafeArea()

                DatePicker(
                    "Day Reset Time",
                    selection: $viewModel.dayResetTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
            }
            .navigationTitle("Day Reset Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingTimePicker = false }
                        .foregroundColor(AppColors.primary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.height(300)])
    }

    // MARK: - Next Button

    private var nextButton: some View {
        ZStack {
            Circle()
                .fill(AppColors.primary.opacity(0.1))
                .frame(width: 128, height: 128)
                .blur(radius: 32)
                .offset(x: 16, y: 16)

            Button {
                viewModel.nextStep()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Circle()
                        .fill(.ultraThinMaterial.opacity(0.5))
                        .frame(width: 64, height: 64)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 64, height: 64)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(AppColors.primary)
                        .shadow(color: AppColors.primary.opacity(0.6), radius: 8)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Glass Section

private struct GlassSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(3)
                    .foregroundColor(Color.white.opacity(0.4))

                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.2))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.02))

            Divider()
                .background(Color.white.opacity(0.05))

            content()
                .padding(20)
        }
        .background(Color.white.opacity(0.03))
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Segment Button

private struct SegmentButton: View {
    let title: String
    let isSelected: Bool
    var accent: Color = AppColors.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSelected && accent != .white {
                    Circle()
                        .fill(AppColors.segmentSelectedIndicator)
                        .frame(width: 8, height: 8)
                        .shadow(color: AppColors.segmentSelectedIndicator, radius: 4)
                } else if isSelected {
                    EmptyView()
                } else {
                    Circle()
                        .fill(AppColors.segmentSelectedIndicator.opacity(0.5))
                        .frame(width: 8, height: 8)
                }

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? AppColors.segmentSelectedText : AppColors.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? AppColors.segmentSelectedBackground : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected ? AppColors.segmentSelectedBorder : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingSystemConfigView(viewModel: OnboardingViewModel())
}
