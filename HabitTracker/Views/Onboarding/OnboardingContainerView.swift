import SwiftUI

struct OnboardingContainerView: View {

    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            // Each step view with custom transition
            Group {
                switch viewModel.currentStep {
                case .foundation:
                    OnboardingFoundationView(viewModel: viewModel)
                        .transition(.opacity)
                case .systemConfig:
                    OnboardingSystemConfigView(viewModel: viewModel)
                        .transition(.opacity)
                case .activation:
                    OnboardingActivationView(viewModel: viewModel)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentStep)
    }
}

#Preview {
    OnboardingContainerView()
}
