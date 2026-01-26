import SwiftUI
import AuthenticationServices
import CryptoKit
import SwiftData

enum EmailConfirmationState: Equatable {
    case none
    case waiting
}

@Observable
final class AuthViewModel: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    // MARK: - Properties

    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var emailConfirmationState: EmailConfirmationState = .none
    
    // Apple Sign In
    var currentNonce: String?
    
    // Context for wiping data on user switch
    var modelContext: ModelContext?
    
    // MARK: - Dependencies
    
    private let authEngine = AuthEngine.shared
    
    override init() {
        super.init()
        syncEmailConfirmationState()
    }

    // MARK: - Actions

    func login(modelContext: ModelContext) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }

        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isLoading = true
        errorMessage = nil

        // Store context for use in performLogin
        self.modelContext = modelContext
        Task {
            await performLogin()
        }
    }

    func createAccount(modelContext: ModelContext) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }

        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isLoading = true
        errorMessage = nil

        // Store context for use in performSignUp
        self.modelContext = modelContext
        Task {
            await performSignUp()
        }
    }
    
    func startAppleSignIn(modelContext: ModelContext) {
        isLoading = true
        errorMessage = nil
        self.modelContext = modelContext
        
        // Generate nonce
        let nonce = generateNonceString()
        currentNonce = nonce
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func forgotPassword() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email."
            return
        }

        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            await performPasswordReset()
        }
    }

    func resendConfirmationEmail() {
        isLoading = true
        errorMessage = nil
        
        Task {
            await performResendConfirmation()
        }
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {

            
            guard let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                print("Unable to fetch identity token")
                return
            }
            
            // Checking nonce match (optional but recommended)
            // Note: In the delegate we are in a non-isolated context or main thread depending on OS.
            // We need to jump back to MainActor to update state.
            
            Task { @MainActor in
                // Because we stored currentNonce on MainActor, we should access it here.
                // Note: 'appleIDCredential.state' is NOT the nonce. The nonce is in the ID token claim, 
                // but checking it here usually involves decoding the JWT which Supabase does.
                // Just pass the RAW nonce we generated to Supabase.
                
                guard let currentNonce = self.currentNonce else {
                    self.errorMessage = "Nonce lost during sign in."
                    self.isLoading = false
                    return
                }
                
                await performAppleSignIn(idToken: idTokenString, nonce: currentNonce)
            }
        }
    }
    
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple failed: \(error)")
        Task { @MainActor in
            self.errorMessage = "Sign in cancelled or failed."
            self.isLoading = false
        }
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return DispatchQueue.main.sync {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
                ?? scenes.first(where: { $0.activationState == .foregroundInactive }) as? UIWindowScene
                ?? scenes.compactMap { $0 as? UIWindowScene }.first
            
            if let window = windowScene?.windows.first(where: { $0.isKeyWindow }) {
                print("[AuthViewModel] 🖼️ Found key window for Apple Sign In presentation")
                return window
            }
            
            print("[AuthViewModel] ⚠️ CRITICAL: Could not find key window for Apple Sign In! Creating temporary window (this may fail).")
            return UIWindow()
        }
    }
    
    // MARK: - Apple Helpers
    
    func generateNonceString() -> String {
        let characters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._"
        var randomString = ""
        var error: Error? = nil
        
        // 32 bytes of randomness
        let length = 32
        
        let result = Result {
            var randomBytes = [UInt8](repeating: 0, count: length)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)
            if errorCode != errSecSuccess {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(errorCode), userInfo: nil)
            }
            return randomBytes
        }
        
        switch result {
        case .success(let bytes):
            randomString = String(bytes.map { characters[characters.index(characters.startIndex, offsetBy: Int($0) % characters.count)] })
        case .failure(let err):
            error = err
        }
        
        if let error = error {
            print("Failed to generate nonce: \(error)")
            // Fallback (should strictly not happen)
            return UUID().uuidString
        }
        
        return randomString
    }
    
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        return hashString
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func performAppleSignIn(idToken: String, nonce: String) async {
        do {
            // Use AuthEngine as single authority
            try await authEngine.loginWithApple(idToken: idToken, nonce: nonce)
            if authEngine.isWaitingForEmailConfirmation {
                SyncLogger.logAuth("Apple login pending email confirmation via AuthViewModel")
            } else {
                SyncLogger.logAuth("Apple login successful via AuthViewModel")
            }
            
            guard let context = self.modelContext else {
                 SyncLogger.logAuth("Apple Login: Missing ModelContext", level: .error)
                 return
            }
            
            // Hand off to Session Manager (auth-state reconciliation)
            await AppSessionManager.shared.handleAuthStateChange(modelContext: context)
            
        } catch let error as AuthEngineError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = friendlyErrorMessage(from: error, fallback: "Sign in with Apple failed. Please try again.")
        }
        syncEmailConfirmationState()
        isLoading = false
    }


    @MainActor
    private func performLogin() async {
        defer { isLoading = false }

        SyncLogger.logAuth("AuthViewModel: Starting email login")
        
        do {
            // Use AuthEngine as single authority
            try await authEngine.loginWithEmail(email: email, password: password)
            if authEngine.isWaitingForEmailConfirmation {
                SyncLogger.logAuth("Email login pending confirmation via AuthViewModel")
            } else {
                SyncLogger.logAuth("Email login successful via AuthViewModel")
            }
            
            guard let context = self.modelContext else {
                 SyncLogger.logAuth("Login: Missing ModelContext", level: .error)
                 return
            }
            
            // Hand off to Session Manager (auth-state reconciliation)
            await AppSessionManager.shared.handleAuthStateChange(modelContext: context)
            
            // Clear fields on success
            if authEngine.isAuthenticated {
                email = ""
                password = ""
            }
        } catch let error as AuthEngineError {
            SyncLogger.logAuth("Email login failed: \(error.localizedDescription)", level: .error)
            errorMessage = error.localizedDescription
            emailConfirmationState = .none
        } catch {
            let friendly = friendlyErrorMessage(from: error, fallback: "Unable to log in. Please try again.")
            SyncLogger.logAuth("Email login failed: \(friendly)", level: .error)
            errorMessage = friendly
            emailConfirmationState = .none
        }
        syncEmailConfirmationState()
    }

    @MainActor
    private func performSignUp() async {
        defer { isLoading = false }

        SyncLogger.logAuth("AuthViewModel: Starting email signup")
        
        do {
            // Use AuthEngine as single authority
            try await authEngine.signUpWithEmail(email: email, password: password)
            if authEngine.isWaitingForEmailConfirmation {
                SyncLogger.logAuth("Email signup pending confirmation via AuthViewModel")
            } else {
                SyncLogger.logAuth("Email signup successful via AuthViewModel")
            }
            
            guard let context = self.modelContext else {
                 SyncLogger.logAuth("Signup: Missing ModelContext", level: .error)
                 return
            }
            
            // Hand off to Session Manager (auth-state reconciliation)
            await AppSessionManager.shared.handleAuthStateChange(modelContext: context)
            
            // Clear fields on success
            if authEngine.isAuthenticated {
                email = ""
                password = ""
            }
        } catch let error as AuthEngineError {
            SyncLogger.logAuth("Email signup failed: \(error.localizedDescription)", level: .error)
            errorMessage = error.localizedDescription
            emailConfirmationState = .none
        } catch {
            let friendly = friendlyErrorMessage(from: error, fallback: "Unable to create account. Please try again.")
            SyncLogger.logAuth("Email signup failed: \(friendly)", level: .error)
            errorMessage = friendly
            emailConfirmationState = .none
        }
        syncEmailConfirmationState()
    }

    @MainActor
    private func performPasswordReset() async {
        defer { isLoading = false }

        do {
            try await SupabaseService.shared.resetPassword(email: email)
            errorMessage = nil
        } catch {
            errorMessage = friendlyErrorMessage(from: error, fallback: "Unable to send reset email. Please try again.")
        }
    }

    @MainActor
    private func performResendConfirmation() async {
        defer { isLoading = false }
        
        do {
            try await authEngine.resendEmailConfirmation(to: email)
        } catch let error as AuthEngineError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = friendlyErrorMessage(from: error, fallback: "Unable to resend confirmation. Please try again.")
        }
        syncEmailConfirmationState()
    }

    // MARK: - Error Handling

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private func friendlyErrorMessage(from error: Error, fallback: String) -> String {
        if let supabaseError = error as? SupabaseError {
            return supabaseError.localizedDescription
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection. Please try again."
            case .timedOut:
                return "The request timed out. Please try again."
            default:
                return "We couldn't reach the server. Please try again."
            }
        }
        return fallback
    }

    private func syncEmailConfirmationState() {
        emailConfirmationState = authEngine.isWaitingForEmailConfirmation ? .waiting : .none
    }
}
