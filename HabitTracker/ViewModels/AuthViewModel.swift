import SwiftUI
import AuthenticationServices
import CryptoKit

@Observable
final class AuthViewModel: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    // MARK: - Properties

    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    
    // Apple Sign In
    var currentNonce: String?
    
    // MARK: - Dependencies
    
    private let supabase = SupabaseService.shared

    // MARK: - Actions

    func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            await performLogin()
        }
    }

    func createAccount() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            await performSignUp()
        }
    }
    
    func startAppleSignIn() {
        isLoading = true
        errorMessage = nil
        
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
            errorMessage = "Please enter your email"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            await performPasswordReset()
        }
    }
    
    func logout() {
        Task {
            await supabase.signOut()
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
        let characters = "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
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
    
    // MARK: - State Helpers
    
    var isAuthenticated: Bool {
        supabase.isAuthenticated
    }

    // MARK: - Private Methods
    
    @MainActor
    private func performAppleSignIn(idToken: String, nonce: String) async {
         do {
             _ = try await supabase.signInWithIdToken(idToken: idToken, nonce: nonce)
             
             // Hand off to Session Manager
             await AppSessionManager.shared.loginSuccess()
             
         } catch let error as SupabaseError {
             errorMessage = error.localizedDescription
         } catch {
             errorMessage = "Sign in with Apple failed"
         }
         isLoading = false
    }


    @MainActor
    private func performLogin() async {
        defer { isLoading = false }

        print("[AuthViewModel] 🔐 Attempting login...")
        
        do {
            _ = try await supabase.signIn(email: email, password: password)
            print("[AuthViewModel] ✅ Login successful")
            
            // Hand off to Session Manager
            await AppSessionManager.shared.loginSuccess()
            
            // Clear fields on success
            email = ""
            password = ""
        } catch let error as SupabaseError {
            print("[AuthViewModel] ❌ Login failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        } catch {
            print("[AuthViewModel] ❌ Login network error: \(error)")
            errorMessage = "Network error"
        }
    }

    @MainActor
    private func performSignUp() async {
        defer { isLoading = false }

        print("[AuthViewModel] 📝 Attempting signup...")
        
        do {
            _ = try await supabase.signUp(email: email, password: password)
            print("[AuthViewModel] ✅ Signup successful")
            
            // Hand off to Session Manager - Explicit Onboarding
            await AppSessionManager.shared.startOnboarding()
            
            // Clear fields on success
            email = ""
            password = ""
        } catch let error as SupabaseError {
            print("[AuthViewModel] ❌ Signup failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        } catch {
            print("[AuthViewModel] ❌ Signup network error: \(error)")
            errorMessage = "Network error"
        }
    }

    @MainActor
    private func performPasswordReset() async {
        defer { isLoading = false }

        do {
            try await supabase.resetPassword(email: email)
            errorMessage = nil
        } catch let error as SupabaseError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Network error"
        }
    }
}
