import SwiftUI

struct OnboardingActivationView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            AppMaterials.moodGradient

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.bottom, 48)

                        dataStorageSection
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, 40)
                    .padding(.bottom, 160)
                }

                Spacer()
            }

            VStack {
                Spacer()
                activateButton
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Navigation row with back button and step indicator
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

                // Step indicator - step 3 of 3
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)

                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)

                    Capsule()
                        .fill(AppColors.primary)
                        .frame(width: 24, height: 6)
                        .shadow(color: AppColors.primary.opacity(0.6), radius: 4)
                }
            }
            .padding(.bottom, AppSpacing.xl)

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 48, height: 48)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 48, height: 48)

                Image(systemName: "server.rack")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.8))
            }
            .shadow(color: .black.opacity(0.3), radius: 16)
            .padding(.bottom, 24)

            Text("Data & Activation")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.3)
                .padding(.bottom, 8)

            Text("Configure persistent storage preferences and initialize system engine.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.white.opacity(0.4))
                .lineSpacing(4)
        }
    }

    // MARK: - Data Storage Section

    private var dataStorageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Storage")
                .font(.system(size: 10, weight: .bold))
                .textCase(.uppercase)
                .tracking(3)
                .foregroundColor(Color.white.opacity(0.3))
                .padding(.leading, 4)

            HStack(spacing: 0) {
                StorageOptionButton(
                    title: "Cloud",
                    subtitle: "Database",
                    isSelected: viewModel.storageMode == .cloud
                ) {
                    viewModel.storageMode = .cloud
                }

                StorageOptionButton(
                    title: "Local Only",
                    subtitle: "Device Storage",
                    isSelected: viewModel.storageMode == .local
                ) {
                    viewModel.storageMode = .local
                }
            }
            .padding(6)
            .background(Color.white.opacity(0.03))
            .background(.ultraThinMaterial.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )

            Text("Cloud database enables encrypted multi-device synchronization. Local storage restricts data to this device.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.white.opacity(0.3))
                .lineSpacing(4)
                .padding(.leading, 4)
        }
    }

    // MARK: - Activate Button

    private var activateButton: some View {
        VStack(spacing: 32) {
            Button {
                viewModel.completeOnboarding()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.5))

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)

                    Circle()
                        .fill(AppColors.primary.opacity(0.2))
                        .frame(width: 96, height: 96)
                        .blur(radius: 32)
                        .offset(x: -60, y: 20)

                    if viewModel.isCompletingOnboarding {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            
                            Text("Initializing...")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    } else {
                        HStack(spacing: 12) {
                            Text("Initialize")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Image(systemName: "power")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                    }
                }
                .frame(height: 72)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCompletingOnboarding)
            .opacity(viewModel.isCompletingOnboarding ? 0.7 : 1.0)

            if let error = viewModel.onboardingError {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.red.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 128, height: 4)
        }
    }
}

// MARK: - Storage Option Button

private struct StorageOptionButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.4))

                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                isSelected ?
                Color.white.opacity(0.1) :
                Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color.white.opacity(0.1) : Color.clear,
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 6, height: 6)
                        .shadow(color: AppColors.primary.opacity(0.8), radius: 4)
                        .padding(10)
                }
            }
            .opacity(isSelected ? 1 : 0.4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingActivationView(viewModel: OnboardingViewModel())
}
