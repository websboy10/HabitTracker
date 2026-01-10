import SwiftUI

// Goal options for habit tracker
enum UserGoalOption: String, CaseIterable, Identifiable {
    case buildHabits = "Build better habits"
    case breakBadHabits = "Break bad habits"
    case improveHealth = "Improve health & fitness"
    case boostProductivity = "Boost productivity"
    case personalGrowth = "Personal growth"
    case trackProgress = "Track daily progress"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .buildHabits: return "arrow.up.circle"
        case .breakBadHabits: return "xmark.circle"
        case .improveHealth: return "heart.circle"
        case .boostProductivity: return "bolt.circle"
        case .personalGrowth: return "star.circle"
        case .trackProgress: return "chart.line.uptrend.xyaxis.circle"
        }
    }
}

struct OnboardingFoundationView: View {

    @Bindable var viewModel: OnboardingViewModel

    // Age picker state
    @State private var selectedAge: Int = 25
    @State private var showingAgePicker = false

    var body: some View {
        ZStack {
            AppMaterials.moodGradient

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.bottom, 48)

                        formFields
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, 40)
                    .padding(.bottom, 120)
                }

                Spacer()
            }

            nextButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
        }
        .onAppear {
            // Initialize age from viewModel if available
            if let age = Int(viewModel.age), age > 0 {
                selectedAge = age
            }
        }
        .onChange(of: selectedAge) { _, newValue in
            viewModel.age = String(newValue)
        }
        .sheet(isPresented: $showingAgePicker) {
            agePickerSheet
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Navigation row with step indicator
            HStack {
                // Empty space for symmetry (no back button on step 1)
                Circle()
                    .fill(Color.clear)
                    .frame(width: 40, height: 40)

                Spacer()

                // Step indicator
                HStack(spacing: 4) {
                    Capsule()
                        .fill(AppColors.primary)
                        .frame(width: 24, height: 6)
                        .shadow(color: AppColors.primary.opacity(0.6), radius: 4)

                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)

                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, AppSpacing.xl)

            Text("Foundation")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.5)
                .padding(.bottom, 8)

            RoundedRectangle(cornerRadius: 2)
                .fill(AppColors.primary)
                .frame(width: 48, height: 4)
                .shadow(color: AppColors.primary.opacity(0.6), radius: 6)
        }
    }

    // MARK: - Form Fields

    private var formFields: some View {
        VStack(spacing: 48) {
            // Age picker
            agePickerSection

            // Goal options
            goalOptionsSection
        }
    }

    // MARK: - Age Picker Section

    private var agePickerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Age")
                .font(.system(size: 10, weight: .bold))
                .textCase(.uppercase)
                .tracking(3)
                .foregroundColor(Color.white.opacity(0.3))
                .padding(.leading, 4)

            Button { showingAgePicker = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your Age")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimary.opacity(0.9))

                        Text("Used to personalize your experience")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Text("\(selectedAge)")
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
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(glassInputBackground)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Goal Options Section

    private var goalOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("What are your goals?")
                    .font(.system(size: 10, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(3)
                    .foregroundColor(Color.white.opacity(0.3))
                
                Spacer()
                
                Text("\(viewModel.userGoals.count)/2")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(viewModel.userGoals.count == 2 ? AppColors.primary : Color.white.opacity(0.3))
            }
            .padding(.leading, 4)

            VStack(spacing: 8) {
                ForEach(UserGoalOption.allCases) { option in
                    GoalOptionButton(
                        option: option,
                        isSelected: viewModel.userGoals.contains(option.rawValue)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if viewModel.userGoals.contains(option.rawValue) {
                                // Deselect
                                viewModel.userGoals.remove(option.rawValue)
                            } else if viewModel.userGoals.count < 2 {
                                // Select if under limit
                                viewModel.userGoals.insert(option.rawValue)
                            }
                        }
                        HapticManager.shared.light()
                    }
                    .opacity(viewModel.userGoals.count == 2 && !viewModel.userGoals.contains(option.rawValue) ? 0.5 : 1.0)
                }
            }
        }
    }

    // MARK: - Glass Input Background

    private var glassInputBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(.ultraThinMaterial.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.03), lineWidth: 1)
            )
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

    // MARK: - Age Picker Sheet

    private var agePickerSheet: some View {
        NavigationStack {
            ZStack {
                AppMaterials.moodGradient.ignoresSafeArea()

                Picker("Age", selection: $selectedAge) {
                    ForEach(13...100, id: \.self) { age in
                        Text("\(age)")
                            .tag(age)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
            }
            .navigationTitle("Age")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingAgePicker = false }
                        .foregroundColor(AppColors.primary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.height(300)])
    }
}

// MARK: - Goal Option Button

private struct GoalOptionButton: View {
    let option: UserGoalOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? AppColors.primary : Color.white.opacity(0.5))
                    .frame(width: 32)

                Text(option.rawValue)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.6))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AppColors.primary.opacity(0.15) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? AppColors.primary.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingFoundationView(viewModel: OnboardingViewModel())
}
