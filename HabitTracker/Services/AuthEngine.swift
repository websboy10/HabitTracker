import Combine
import Foundation

// MARK: - Auth State

/// Explicit authentication states - no ambiguity allowed.
/// Auth state MUST be resolved before any data or notification operation.
enum AuthState: String, CaseIterable {
    case unauthenticated   // No valid session, requires login
    case authenticating    // Login in progress
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
        
        // 3. Load provider from persisted state
        if let providerRaw = UserDefaults.standard.string(forKey: providerKey),
           let provider = AuthProvider(rawValue: providerRaw) {
            currentProvider = provider
        }
        
        // 4. INVARIANT: Must have known provider to be authenticated
        guard currentProvider != nil else {
            SyncLogger.logAuth("Auth failed: provider unknown - state invalid", level: .error)
            state = .invalid
            return state
        }
        
        // 5. Establish authenticated state
        userId = session.user.id
        userEmail = session.user.email
        state = .authenticated
        
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
            state = .authenticated
            
            SyncLogger.logAuth("Email login successful")
            
        } catch let error as AuthEngineError {
            state = .unauthenticated
            throw error
        } catch {
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
            state = .authenticated
            
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
            state = .authenticated
            
            SyncLogger.logAuth("Email signup successful")
            
        } catch {
            SyncLogger.logAuth("Email signup failed: \(error.localizedDescription)", level: .error)
            state = .unauthenticated
            throw AuthEngineError.signupFailed(error.localizedDescription)
        }
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
        
        // 3. Transition to unauthenticated
        state = .unauthenticated
        
        SyncLogger.logAuth("Logout complete - fully unauthenticated")
    }
    
    // MARK: - Session Management
    
    /// Validates the current session. Returns false if invalid.
    func validateSession() async -> Bool {
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
    
    // MARK: - Helpers
    
    /// Returns true if currently authenticated
    var isAuthenticated: Bool {
        state == .authenticated
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
        }
    }
}
