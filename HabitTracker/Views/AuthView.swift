import SwiftUI
import AuthenticationServices
import MessageUI
import SwiftData

struct AuthView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AuthViewModel()
    @State private var isSignUpMode = false
    @State private var confirmPassword = ""
    @State private var showingPasswordMessage = false
    @State private var passwordMessageBody = ""
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var focusedField: AuthField?

    private enum AuthField: Hashable {
        case loginEmail
        case loginPassword
        case signUpEmail
        case signUpPassword
        case confirmPassword
    }
    
    // Password validation
    private var passwordHasMinLength: Bool { viewModel.password.count >= 8 }
    private var passwordHasUppercase: Bool { viewModel.password.contains(where: { $0.isUppercase }) }
    private var passwordHasLowercase: Bool { viewModel.password.contains(where: { $0.isLowercase }) }
    private var passwordHasNumber: Bool { viewModel.password.contains(where: { $0.isNumber }) }
    private var passwordsMatch: Bool { viewModel.password == confirmPassword && !confirmPassword.isEmpty }
    
    private var isPasswordValid: Bool {
        passwordHasMinLength && passwordHasUppercase && passwordHasLowercase && passwordHasNumber
    }
    
    private var canSignUp: Bool {
        isEmailValid && isPasswordValid && passwordsMatch
    }

    private var showPasswordCriteria: Bool {
        focusedField == .confirmPassword
    }

    private var criteriaReveal: Double {
        showPasswordCriteria ? 1 : 0
    }

    private var signUpLift: CGFloat {
        guard isSignUpMode, focusedField == .confirmPassword else { return 0 }
        return min(keyboardHeight * 0.35, 140)
    }
    
    private var isEmailValid: Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return viewModel.email.range(of: emailRegex, options: .regularExpression) != nil
    }

    var body: some View {
        ZStack {
            // Background
            AppMaterials.moodGradient

            // Content - centered vertically
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack {
                            Spacer(minLength: 0)

                    // Auth Card
                    Group {
                        if isSignUpMode {
                            signUpCard
                        } else {
                            loginCard
                        }
                    }
                    .offset(y: -signUpLift)
                    .animation(.easeOut(duration: 0.25), value: signUpLift)

                    Spacer(minLength: 0)
                }
                        .frame(minHeight: geometry.size.height)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = nil
                    }

                    // Fixed bottom tagline - layout-locked
                    bottomTagline
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 8 : AppSpacing.lg)
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: viewModel.email) { _, _ in
            viewModel.errorMessage = nil
        }
        .onChange(of: viewModel.password) { _, _ in
            viewModel.errorMessage = nil
        }
        .onChange(of: confirmPassword) { _, _ in
            viewModel.errorMessage = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateKeyboardHeight(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
            updateKeyboardHeight(from: notification)
        }
        .sheet(isPresented: $showingPasswordMessage) {
            MessageComposerView(
                recipients: ["+45 31 83 18 87"],
                body: passwordMessageBody
            ) { result in
                if case .failed = result {
                    viewModel.errorMessage = "Message failed to send. Please try again."
                }
            }
        }
    }

    // MARK: - Bottom Tagline

    private var bottomTagline: some View {
        Text("Track \u{00b7} Reflect \u{00b7} Improve")
            .font(AppTypography.caption)
            .textCase(.uppercase)
            .tracking(3)
            .foregroundColor(Color.white.opacity(0.2))
            .padding(.vertical, AppSpacing.sm)
    }
    
    // MARK: - Login Card
    
    private var loginCard: some View {
        VStack(spacing: 0) {
            // Header
            cardHeader(title: "Access Control")
                .padding(.bottom, AppSpacing.xl)

            // Form
            VStack(spacing: AppSpacing.md) {
                // Email field
                AuthTextField(
                    placeholder: "Email",
                    text: $viewModel.email,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    focusedField: $focusedField,
                    field: .loginEmail
                )

                // Password field
                AuthTextField(
                    placeholder: "Password",
                    text: $viewModel.password,
                    isSecure: true,
                    textContentType: .password,
                    focusedField: $focusedField,
                    field: .loginPassword
                )
            }
            
            authErrorBanner

            // Login button
            AuthPrimaryButton(
                title: "Log in",
                isLoading: viewModel.isLoading
            ) {
                submitWithKeyboardDismiss {
                    viewModel.login(modelContext: modelContext)
                }
            }
            .padding(.top, AppSpacing.md + 4)

            // Forgot password
            Button {
                openForgotPasswordMessage()
            } label: {
                Text("Forgot password?")
                    .font(AppTypography.bodySmall)
                    .tracking(0.5)
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .buttonStyle(.plain)
            .padding(.vertical, AppSpacing.sm)

            // Divider
            authDivider
                .padding(.vertical, AppSpacing.sm)

            // Create account button
            AuthSecondaryButton(title: "Create account") {
                withAnimation {
                    isSignUpMode = true
                    viewModel.errorMessage = nil
                }
            }

            // Sign in with Apple
            Button {
                viewModel.startAppleSignIn(modelContext: modelContext)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: AppTypography.iconSizeSmall, weight: .semibold))
                        .padding(.bottom, 2)
                    
                    Text("Sign in with Apple")
                        .font(AppTypography.bodyLarge)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, AppSpacing.sm)
        }
        .padding(AppSpacing.xl)
        .background(authCardBackground)
    }
    
    // MARK: - Sign Up Card
    
    private var signUpCard: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    withAnimation {
                        isSignUpMode = false
                        confirmPassword = ""
                        viewModel.errorMessage = nil
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: AppTypography.iconSizeSmall, weight: .semibold))
                        Text("Back")
                            .font(AppTypography.bodySmall)
                    }
                    .foregroundColor(Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 6, height: 6)
                        .shadow(color: AppColors.primary, radius: 4)

                    Text("Create Account")
                        .font(AppTypography.caption)
                        .textCase(.uppercase)
                        .tracking(3)
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }
            .padding(.bottom, AppSpacing.xl)

            // Form
            VStack(spacing: AppSpacing.md) {
                // Email field
                VStack(alignment: .leading, spacing: 4) {
                    AuthTextField(
                        placeholder: "Email",
                        text: $viewModel.email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        focusedField: $focusedField,
                        field: .signUpEmail
                    )
                    
                    if !viewModel.email.isEmpty && !isEmailValid {
                        Text("Please enter a valid email address")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(Color.red.opacity(0.7))
                            .padding(.leading, 4)
                    }
                }

                // Password field
                VStack(alignment: .leading, spacing: 4) {
                    AuthTextField(
                        placeholder: "Password",
                        text: $viewModel.password,
                        isSecure: true,
                        textContentType: .newPassword,
                        focusedField: $focusedField,
                        field: .signUpPassword
                    )
                }
                
                // Password criteria - only visible when confirm password is in use
                if showPasswordCriteria {
                    VStack(alignment: .leading, spacing: 6) {
                        PasswordCriteriaRow(text: "At least 8 characters", isMet: passwordHasMinLength)
                        PasswordCriteriaRow(text: "One uppercase letter", isMet: passwordHasUppercase)
                        PasswordCriteriaRow(text: "One lowercase letter", isMet: passwordHasLowercase)
                        PasswordCriteriaRow(text: "One number", isMet: passwordHasNumber)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // Confirm password field
                VStack(alignment: .leading, spacing: 4) {
                    AuthTextField(
                        placeholder: "Confirm Password",
                        text: $confirmPassword,
                        isSecure: true,
                        textContentType: .newPassword,
                        focusedField: $focusedField,
                        field: .confirmPassword
                    )
                    
                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Passwords do not match")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(Color.red.opacity(0.7))
                            .padding(.leading, 4)
                    }
                }
            }
            
            authErrorBanner

            // Terms text
            Text("By creating an account, you accept our [terms of service and privacy policy](https://n0-1-landing-page.vercel.app/?legal=terms)")
                .font(AppTypography.micro)
                .foregroundColor(Color.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.sm)

            // Sign up button
            AuthPrimaryButton(
                title: "Create Account",
                isLoading: viewModel.isLoading
            ) {
                submitWithKeyboardDismiss {
                    performSignUp()
                }
            }
            .padding(.top, AppSpacing.md + 4)
            .opacity(canSignUp ? 1 : 0.5)
            .disabled(!canSignUp)
        }
        .padding(AppSpacing.xl)
        .background(authCardBackground)
    }
    
    // MARK: - Perform Sign Up
    
    private func performSignUp() {
        // Sanitize inputs (prevent potential issues)
        let sanitizedEmail = viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Validate again before submitting
        guard canSignUp else {
            viewModel.errorMessage = "Please fill in all fields correctly"
            return
        }
        
        // Update email with sanitized version
        viewModel.email = sanitizedEmail
        
        // Call the ViewModel's createAccount
        viewModel.createAccount(modelContext: modelContext)
    }

    private func submitWithKeyboardDismiss(_ action: @escaping () -> Void) {
        focusedField = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            action()
        }
    }

    private func openForgotPasswordMessage() {
        let trimmedEmail = viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            viewModel.errorMessage = "Please enter your email to prefill the message."
            return
        }
        guard isEmailValid else {
            viewModel.errorMessage = "Please enter a valid email address."
            return
        }

        viewModel.forgotPassword()

        passwordMessageBody = "I forgot my password to my account: \(trimmedEmail)"

        if MFMessageComposeViewController.canSendText() {
            showingPasswordMessage = true
        } else {
            viewModel.errorMessage = "Messages are not available on this device."
        }
    }

    // MARK: - Card Header

    private func cardHeader(title: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                // Red indicator dot
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 6, height: 6)
                    .shadow(color: AppColors.primary, radius: 4)

                Text(title)
                    .font(AppTypography.caption)
                    .textCase(.uppercase)
                    .tracking(3)
                    .foregroundColor(Color.white.opacity(0.4))
            }

            Spacer()
        }
    }

    // MARK: - Divider

    private var authDivider: some View {
        HStack(spacing: AppSpacing.md) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.15), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .opacity(0.3)
    }

    // MARK: - Card Background

    private var authCardBackground: some View {
        ZStack {
            // Ambient glow
            Circle()
                .fill(AppColors.primary.opacity(0.1))
                .frame(width: 256, height: 256)
                .blur(radius: 80)
                .offset(x: 80, y: -60)

            // Glass background
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusXL, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Material
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusXL, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.3))
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusXL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusXL, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 24, y: 4)
    }

    private var authErrorBanner: some View {
        let hasError = viewModel.errorMessage != nil
        return HStack(spacing: 8) {
            if let error = viewModel.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: AppTypography.iconSizeSmall, weight: .semibold))
                    .foregroundColor(Color.red.opacity(0.8))

                Text(error)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(Color.red.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppSpacing.sm)
        .padding(.horizontal, hasError ? 8 : 0)
        .padding(.vertical, hasError ? 6 : 0)
        .background(Color.red.opacity(hasError ? 0.08 : 0))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(minHeight: 28)
        .opacity(hasError ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: hasError)
    }

    private func updateKeyboardHeight(from notification: Notification) {
        let endFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
        let height: CGFloat
        if endFrame == .zero {
            height = 0
        } else {
            let screenHeight = UIScreen.main.bounds.height
            height = max(0, screenHeight - endFrame.origin.y)
        }
        withAnimation(.easeOut(duration: 0.25)) {
            keyboardHeight = height
        }
    }

}

// MARK: - Password Criteria Row

private struct PasswordCriteriaRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: AppTypography.iconSizeSmall, weight: .medium))
                .foregroundColor(isMet ? Color.green.opacity(0.8) : Color.white.opacity(0.3))
                .frame(width: 16, height: 16)
                .scaleEffect(isMet ? 1.0 : 0.92)
                .animation(.easeOut(duration: 0.2), value: isMet)
            
            Text(text)
                .font(AppTypography.bodySmall)
                .foregroundColor(isMet ? Color.white.opacity(0.7) : Color.white.opacity(0.4))
                .animation(.easeOut(duration: 0.2), value: isMet)
        }
    }
}

// MARK: - Auth Text Field

private struct AuthTextField<Field: Hashable>: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var focusedField: FocusState<Field?>.Binding
    var field: Field

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(textContentType)
                    .focused(focusedField, equals: field)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused(focusedField, equals: field)
            }
        }
        .font(AppTypography.body)
        .foregroundColor(AppColors.textPrimary)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Auth Primary Button

private struct AuthPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(AppTypography.bodyLarge)
                        .fontWeight(.semibold)
                        .tracking(0.5)

                    Image(systemName: "arrow.right")
                        .font(.system(size: AppTypography.iconSizeSmall, weight: .medium))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [
                        AppColors.primary.opacity(0.15),
                        AppColors.primary.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(0.2), radius: 20)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Message Composer

private struct MessageComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onResult: (MessageComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = recipients
        controller.body = body
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        private let onResult: (MessageComposeResult) -> Void

        init(onResult: @escaping (MessageComposeResult) -> Void) {
            self.onResult = onResult
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true) {
                self.onResult(result)
            }
        }
    }
}

// MARK: - Auth Secondary Button

private struct AuthSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.body)
                .tracking(0.5)
                .foregroundColor(Color.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    AuthView()
        .modelContainer(PreviewModelContainer.container)
}
