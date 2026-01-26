import Combine
import Foundation

// MARK: - Auth State

/// Explicit authentication states - no ambiguity allowed.
/// Auth state MUST be resolved before any data or notification operation.
enum AuthState: String, CaseIterable {
    case unauthenticated   // No valid session, requires login
    case authenticating    // Login in progress
    case waitingForEmailConfirmation // Signup complete, email not confirmed
    case authenticated     // Valid session, all systems unblocked
    case invalid           // Session was valid but is now invalid (expired, revoked)
}

// MARK: - Auth Provider

/// Authentication providers. Each account is bound to exactly one provider.
/// Cross-provider login attempts are hard failures.
enum AuthProvider: String, Codable {
    case emailPassword = "email"
    case apple = "apple"
}

// MARK: - Auth Engine

/// Central authority for ALL authentication operations.
/// No other component may access Supabase auth directly.
///
/// **Invariants:**
/// - Exactly one AuthEngine exists (singleton)
/// - Auth state is resolved before data/notifications
/// - Each account has exactly one provider
/// - Invalid session = immediate re-login required
/// - All auth operations are fail-fast
@MainActor
final class AuthEngine: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AuthEngine()
    
    // MARK: - Published State
    
    @Published private(set) var state: AuthState = .unauthenticated
    @Published private(set) var currentProvider: AuthProvider?
    @Published private(set) var userId: String?
    @Published private(set) var userEmail: String?
    
    // MARK: - Dependencies
    
    private let supabase = SupabaseService.shared
    
    private let providerKey = "auth_provider"
    private let confirmationPendingKey = "auth_email_confirmation_pending"
    private let confirmationPendingEmailKey = "auth_email_confirmation_email"
    
    // MARK: - Init
    
    private init() {
        SyncLogger.logAuth("AuthEngine initialized")
    }
    
    // MARK: - State Resolution
    
    /// Resolves auth state at app launch.
    /// MUST be called before any data or notification operation.
    /// Returns the resolved state.
    @discardableResult
    func resolve() async -> AuthState {
        SyncLogger.logAuth("Resolving auth state...")
        state = .authenticating
        
        // 1. Check for persisted session
        guard let session = supabase.currentSession else {
            if isConfirmationPending {
                SyncLogger.logAuth("No session found - awaiting email confirmation")
                currentProvider = .emailPassword
                userEmail = pendingConfirmationEmail
                state = .waitingForEmailConfirmation
                return state
            }
            
            SyncLogger.logAuth("No session found - unauthenticated")
            state = .unauthenticated
            return state
        }
        
        // 2. Validate session is not expired
        if let expiresAt = session.expiresAt {
            let expiryDate = Date(timeIntervalSince1970: TimeInterval(expiresAt))
            if expiryDate < Date() {
                SyncLogger.logAuth("Session expired - attempting refresh")
                
                do {
                    try await refreshSession()
                    // Refresh succeeded - session is valid
                } catch {
                    SyncLogger.logAuth("Session refresh failed - invalid", level: .error)
                    state = .invalid
                    return state
                }
            }
        }
        
        // 3. Load provider from persisted state or infer from session
        if let providerRaw = UserDefaults.standard.string(forKey: providerKey),
           let provider = AuthProvider(rawValue: providerRaw) {
            currentProvider = provider
        } else {
            // Fallback: Infer provider from session metadata
            // This handles cases where UserDefaults was cleared but session is valid
            if let providerString = session.user.appMetadata?.provider {
                switch providerString.lowercased() {
                case "email":
                    currentProvider = .emailPassword
                    persistProvider(.emailPassword)
                    SyncLogger.logAuth("Provider inferred from session: email")
                case "apple":
                    currentProvider = .apple
                    persistProvider(.apple)
                    SyncLogger.logAuth("Provider inferred from session: apple")
                default:
                    SyncLogger.logAuth("Unknown provider in session: \(providerString)", level: .warning)
                }
            }
        }
        
        // 4. INVARIANT: Must have known provider to be authenticated
        guard currentProvider != nil else {
            SyncLogger.logAuth("Auth failed: provider unknown - state invalid", level: .error)
            state = .invalid
            return state
        }
        
        // 5. Establish user identity
        userId = session.user.id
        userEmail = session.user.email

        // 6. Email confirmation gate
        if !isEmailConfirmed(session.user, provider: currentProvider) {
            SyncLogger.logAuth("Auth resolved: email not confirmed")
            state = .waitingForEmailConfirmation
            persistPendingConfirmation(email: session.user.email)
            await supabase.signOut(preserveLocalState: true)
            return state
        }

        // 7. Establish authenticated state
        state = .authenticated
        clearPendingConfirmation()
        
        SyncLogger.logAuth("Auth resolved: authenticated (provider: \(currentProvider!.rawValue))")
        return state
    }
    
    // MARK: - Email + Password Login
    
    /// Sign in with email and password.
    /// Fails immediately on any error.
    func loginWithEmail(email: String, password: String) async throws {
        guard state != .authenticating else {
            throw AuthEngineError.alreadyAuthenticating
        }
        
        state = .authenticating
        SyncLogger.logAuth("Starting email login")
        
        do {
            let session = try await supabase.signIn(email: email, password: password)
            
            // Validate provider consistency
            // For email login, the provider must be email or not set
            if let existingProvider = currentProvider, existingProvider != .emailPassword {
                SyncLogger.logAuth("Cross-provider login rejected: account uses \(existingProvider.rawValue)", level: .error)
                await supabase.signOut()
                state = .unauthenticated
                throw AuthEngineError.crossProviderRejected(existingProvider)
            }
            
            // Establish session
            currentProvider = .emailPassword
            persistProvider(.emailPassword)
            userId = session.user.id
            userEmail = session.user.email

            if !isEmailConfirmed(session.user, provider: currentProvider) {
                SyncLogger.logAuth("Email login requires confirmation")
                state = .waitingForEmailConfirmation
                persistPendingConfirmation(email: session.user.email ?? email)
                await supabase.signOut(preserveLocalState: true)
                return
            }

            state = .authenticated
            clearPendingConfirmation()
            
            SyncLogger.logAuth("Email login successful")
            
        } catch let error as AuthEngineError {
            state = .unauthenticated
            throw error
        } catch {
            if let supabaseError = error as? SupabaseError,
               supabaseError.error?.lowercased() == "email_not_confirmed" {
                SyncLogger.logAuth("Email login requires confirmation")
                currentProvider = .emailPassword
                persistProvider(.emailPassword)
                userEmail = email
                state = .waitingForEmailConfirmation
                persistPendingConfirmation(email: email)
                return
            }
            
            SyncLogger.logAuth("Email login failed: \(error.localizedDescription)", level: .error)
            state = .unauthenticated
            throw AuthEngineError.loginFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Apple Login
    
    /// Sign in with Apple ID token.
    /// Follows identical logic path as email login.
    func loginWithApple(idToken: String, nonce: String) async throws {
        guard state != .authenticating else {
            throw AuthEngineError.alreadyAuthenticating
        }
        
        state = .authenticating
        SyncLogger.logAuth("Starting Apple login")
        
        do {
            let session = try await supabase.signInWithIdToken(idToken: idToken, nonce: nonce)
            
            // Validate provider consistency
            if let existingProvider = currentProvider, existingProvider != .apple {
                SyncLogger.logAuth("Cross-provider login rejected: account uses \(existingProvider.rawValue)", level: .error)
                await supabase.signOut()
                state = .unauthenticated
                throw AuthEngineError.crossProviderRejected(existingProvider)
            }
            
            // Establish session
            currentProvider = .apple
            persistProvider(.apple)
            userId = session.user.id
            userEmail = session.user.email

            if !isEmailConfirmed(session.user, provider: currentProvider) {
                SyncLogger.logAuth("Apple login requires confirmation")
                state = .waitingForEmailConfirmation
                persistPendingConfirmation(email: session.user.email)
                await supabase.signOut(preserveLocalState: true)
                return
            }

            state = .authenticated
            clearPendingConfirmation()
            
            SyncLogger.logAuth("Apple login successful")
            
        } catch let error as AuthEngineError {
            state = .unauthenticated
            throw error
        } catch {
            SyncLogger.logAuth("Apple login failed: \(error.localizedDescription)", level: .error)
            state = .unauthenticated
            throw AuthEngineError.loginFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Sign Up
    
    /// Sign up with email and password.
    func signUpWithEmail(email: String, password: String) async throws {
        guard state != .authenticating else {
            throw AuthEngineError.alreadyAuthenticating
        }
        
        state = .authenticating
        SyncLogger.logAuth("Starting email signup for: \(email)")
        
        do {
            let session = try await supabase.signUp(email: email, password: password)
            
            // Establish session
            currentProvider = .emailPassword
            persistProvider(.emailPassword)
            userId = session.user.id
            userEmail = session.user.email

            if !isEmailConfirmed(session.user, provider: currentProvider) {
                SyncLogger.logAuth("Signup requires email confirmation")
                state = .waitingForEmailConfirmation
                persistPendingConfirmation(email: session.user.email ?? email)
                await supabase.signOut(preserveLocalState: true)
                return
            }

            state = .authenticated
            clearPendingConfirmation()
            
            SyncLogger.logAuth("Email signup successful")
            
        } catch {
            if let supabaseError = error as? SupabaseError,
               let statusCode = supabaseError.statusCode,
               (200..<300).contains(statusCode) {
                SyncLogger.logAuth("Signup created user - awaiting email confirmation")
                currentProvider = .emailPassword
                persistProvider(.emailPassword)
                userEmail = email
                state = .waitingForEmailConfirmation
                persistPendingConfirmation(email: email)
                return
            }
            
            SyncLogger.logAuth("Email signup failed: \(error.localizedDescription)", level: .error)
            state = .unauthenticated
            throw AuthEngineError.signupFailed(error.localizedDescription)
        }
    }

    // MARK: - Email Confirmation

    /// Resend email confirmation link.
    func resendEmailConfirmation(to email: String? = nil) async throws {
        let targetEmail = (email?.isEmpty == false) ? email : userEmail
        guard let targetEmail, !targetEmail.isEmpty else {
            throw AuthEngineError.missingEmailForConfirmation
        }
        
        try await supabase.resendConfirmationEmail(email: targetEmail)
        SyncLogger.logAuth("Resent email confirmation to \(targetEmail)")
    }
    
    // MARK: - Logout
    
    /// Logout invalidates session server-side and clears all local auth state.
    /// After logout, app is fully unauthenticated.
    func logout() async {
        SyncLogger.logAuth("Starting logout")
        
        // 1. Invalidate session server-side
        await supabase.signOut(preserveLocalState: false)

        await NotificationEngine.shared.cancelAllNotifications(reason: "auth-logout")
        
        // 2. Clear all local auth state
        clearAuthState()
        clearPendingConfirmation()
        
        // 3. Transition to unauthenticated
        state = .unauthenticated
        
        SyncLogger.logAuth("Logout complete - fully unauthenticated")
    }

    /// Hard purge of all local auth state after server-side account deletion.
    /// Does NOT attempt server-side recovery.
    func purgeLocalStateAfterDeletion() {
        SyncLogger.logAuth("Purging local auth state after deletion")
        supabase.clearSession(preserveLocalState: false)
        clearAuthState()
        clearPendingConfirmation()
        state = .unauthenticated
    }
    
    // MARK: - Session Management
    
    /// Validates the current session. Returns false if invalid.
    func validateSession() async -> Bool {
        if state == .waitingForEmailConfirmation {
            SyncLogger.logAuth("Session validation failed: email not confirmed")
            return false
        }
        
        guard supabase.isAuthenticated else {
            SyncLogger.logAuth("Session validation failed: not authenticated")
            return false
        }
        
        guard let session = supabase.currentSession else {
            SyncLogger.logAuth("Session validation failed: no session")
            return false
        }
        
        // Check expiry
        if let expiresAt = session.expiresAt {
            let expiryDate = Date(timeIntervalSince1970: TimeInterval(expiresAt))
            if expiryDate < Date() {
                SyncLogger.logAuth("Session expired - needs refresh")
                do {
                    try await refreshSession()
                    return true
                } catch {
                    state = .invalid
                    return false
                }
            }
        }
        
        return true
    }
    
    /// Refreshes the access token.
    /// Throws if refresh fails (session becomes invalid).
    private func refreshSession() async throws {
        SyncLogger.logAuth("Refreshing session token")
        
        do {
            try await supabase.refreshToken()
            SyncLogger.logAuth("Token refresh successful")
        } catch {
            SyncLogger.logAuth("Token refresh failed: \(error.localizedDescription)", level: .error)
            throw AuthEngineError.refreshFailed
        }
    }
    
    // MARK: - Provider Persistence
    
    private func persistProvider(_ provider: AuthProvider) {
        UserDefaults.standard.set(provider.rawValue, forKey: providerKey)
    }
    
    private func clearAuthState() {
        currentProvider = nil
        userId = nil
        userEmail = nil
        UserDefaults.standard.removeObject(forKey: providerKey)
    }

    private func persistPendingConfirmation(email: String?) {
        UserDefaults.standard.set(true, forKey: confirmationPendingKey)
        if let email {
            UserDefaults.standard.set(email, forKey: confirmationPendingEmailKey)
        }
    }

    private func clearPendingConfirmation() {
        UserDefaults.standard.removeObject(forKey: confirmationPendingKey)
        UserDefaults.standard.removeObject(forKey: confirmationPendingEmailKey)
    }

    private var isConfirmationPending: Bool {
        UserDefaults.standard.bool(forKey: confirmationPendingKey)
    }

    private var pendingConfirmationEmail: String? {
        UserDefaults.standard.string(forKey: confirmationPendingEmailKey)
    }

    private func isEmailConfirmed(_ user: SupabaseUser, provider: AuthProvider?) -> Bool {
        if provider != .emailPassword {
            return true
        }
        if let confirmedAt = user.emailConfirmedAt ?? user.confirmedAt {
            return !confirmedAt.isEmpty
        }
        return false
    }
    
    // MARK: - Helpers
    
    /// Returns true if currently authenticated
    var isAuthenticated: Bool {
        state == .authenticated
    }

    /// Returns true if email confirmation is pending
    var isWaitingForEmailConfirmation: Bool {
        state == .waitingForEmailConfirmation
    }
    
    /// Blocks execution until auth is resolved
    func ensureAuthenticated() throws {
        guard state == .authenticated else {
            throw AuthEngineError.notAuthenticated
        }
    }
}

// MARK: - Errors

enum AuthEngineError: Error, LocalizedError {
    case alreadyAuthenticating
    case notAuthenticated
    case loginFailed(String)
    case signupFailed(String)
    case refreshFailed
    case crossProviderRejected(AuthProvider)
    case sessionInvalid
    case missingEmailForConfirmation
    
    var errorDescription: String? {
        switch self {
        case .alreadyAuthenticating:
            return "Authentication already in progress"
        case .notAuthenticated:
            return "Not authenticated"
        case .loginFailed(let reason):
            return "Login failed: \(reason)"
        case .signupFailed(let reason):
            return "Signup failed: \(reason)"
        case .refreshFailed:
            return "Session refresh failed. Please log in again."
        case .crossProviderRejected(let provider):
            return "This account uses \(provider.rawValue) login. Please use that method."
        case .sessionInvalid:
            return "Session is invalid. Please log in again."
        case .missingEmailForConfirmation:
            return "Email address is required to resend confirmation."
        }
    }
}
