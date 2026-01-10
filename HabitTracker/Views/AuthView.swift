import SwiftUI
import AuthenticationServices

struct AuthView: View {

    @State private var viewModel = AuthViewModel()
    @State private var isSignUpMode = false
    @State private var confirmPassword = ""
    @State private var showPasswordCriteria = false
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
                ScrollView(.vertical, showsIndicators: false) {
                    VStack {
                        Spacer()
                            .frame(minHeight: 40)

                        // Auth Card
                        if isSignUpMode {
                            signUpCard
                        } else {
                            loginCard
                        }

                        Spacer()
                            .frame(minHeight: 40)

                        // Developer Mode Controls
                        VStack(spacing: 12) {
                            Text("Developer Tools")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.primary.opacity(0.8))
                                .textCase(.uppercase)
                                .tracking(1)

                            HStack(spacing: 12) {
                                Button {
                                    SupabaseService.shared.debugLogin(skipOnboarding: false)
                                } label: {
                                    Text("Debug: Onboarding")
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Capsule())
                                }

                                Button {
                                    SupabaseService.shared.debugLogin(skipOnboarding: true)
                                } label: {
                                    Text("Debug: Skip All")
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.bottom, 20)
                        .foregroundColor(.white.opacity(0.6))

                        // Bottom text
                        Text("Track \u{00b7} Reflect \u{00b7} Improve")
                            .font(.system(size: 10, weight: .medium))
                            .textCase(.uppercase)
                            .tracking(3)
                            .foregroundColor(Color.white.opacity(0.2))
                            .padding(.bottom, AppSpacing.lg)
                    }
                    .frame(minHeight: geometry.size.height)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isSignUpMode)
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
            
            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.red.opacity(0.8))
                    .padding(.top, AppSpacing.sm)
            }

            // Login button
            AuthPrimaryButton(
                title: "Log in",
                isLoading: viewModel.isLoading
            ) {
                submitWithKeyboardDismiss {
                    viewModel.login()
                }
            }
            .padding(.top, AppSpacing.md + 4)

            // Forgot password
            Button {
                viewModel.forgotPassword()
            } label: {
                Text("Forgot password?")
                    .font(.system(size: 12, weight: .medium))
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
                viewModel.startAppleSignIn()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 16))
                        .padding(.bottom, 2)
                    
                    Text("Sign in with Apple")
                        .font(.system(size: 16, weight: .medium))
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
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 12, weight: .medium))
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
                        .font(.system(size: 10, weight: .semibold))
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
                            .font(.system(size: 10, weight: .medium))
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
                    .onChange(of: viewModel.password) { _, _ in
                        if !viewModel.password.isEmpty {
                            showPasswordCriteria = true
                        }
                    }
                }
                
                // Password criteria
                if showPasswordCriteria {
                    VStack(alignment: .leading, spacing: 6) {
                        PasswordCriteriaRow(text: "At least 8 characters", isMet: passwordHasMinLength)
                        PasswordCriteriaRow(text: "One uppercase letter", isMet: passwordHasUppercase)
                        PasswordCriteriaRow(text: "One lowercase letter", isMet: passwordHasLowercase)
                        PasswordCriteriaRow(text: "One number", isMet: passwordHasNumber)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
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
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.red.opacity(0.7))
                            .padding(.leading, 4)
                    }
                }
            }
            
            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.red.opacity(0.8))
                    .padding(.top, AppSpacing.sm)
            }

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

            // Terms text
            Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(Color.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.md)
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
        viewModel.createAccount()
    }

    private func submitWithKeyboardDismiss(_ action: @escaping () -> Void) {
        focusedField = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            action()
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
                    .font(.system(size: 10, weight: .semibold))
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


}

// MARK: - Password Criteria Row

private struct PasswordCriteriaRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isMet ? Color.green.opacity(0.8) : Color.white.opacity(0.3))
            
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isMet ? Color.white.opacity(0.7) : Color.white.opacity(0.4))
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
        .font(.system(size: 14, weight: .regular))
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
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.5)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
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

// MARK: - Auth Secondary Button

private struct AuthSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
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
}
