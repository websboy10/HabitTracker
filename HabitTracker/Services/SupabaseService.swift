import Foundation
import SwiftUI
import Security

// MARK: - Supabase Response Models

/// User session after authentication
struct SupabaseSession: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let expiresAt: Int?
    let refreshToken: String
    let user: SupabaseUser
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case refreshToken = "refresh_token"
        case user
    }
}

/// Supabase user data
struct SupabaseUser: Codable {
    let id: String
    let email: String?
    let phone: String?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case phone
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - DTOs for Database Tables

/// Profile DTO matching the profiles table
struct ProfileDTO: Codable {
    let id: String
    var email: String?
    var name: String?
    var title: String?
    var age: Int?
    var userGoal: String?
    var createdAt: String?
    var updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, nameCapitalized = "Name", title, age
        case userGoal = "user_goal"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        email: String? = nil,
        name: String? = nil,
        title: String? = nil,
        age: Int? = nil,
        userGoal: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.title = title
        self.age = age
        self.userGoal = userGoal
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        userGoal = try container.decodeIfPresent(String.self, forKey: .userGoal)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        if let capitalized = try container.decodeIfPresent(String.self, forKey: .nameCapitalized) {
            name = capitalized
        } else {
            name = try container.decodeIfPresent(String.self, forKey: .name)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(name, forKey: .name)  // Use lowercase 'name' to match schema
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(age, forKey: .age)
        try container.encodeIfPresent(userGoal, forKey: .userGoal)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

/// User Settings DTO matching user_settings table
struct UserSettingsDTO: Codable {
    var id: String?
    let userId: String
    var theme: String?
    var hapticFeedback: Bool?
    var compactLayout: Bool?
    var reduceMotion: Bool?
    var weekStart: String?
    var monthCalculation: String?
    var dayResetMinutes: Int?
    var storageMode: String?
    var createdAt: String?
    var updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case theme
        case hapticFeedback = "haptic_feedback"
        case compactLayout = "compact_layout"
        case reduceMotion = "reduce_motion"
        case weekStart = "week_start"
        case monthCalculation = "month_calculation"
        case dayResetMinutes = "day_reset_minutes"
        case storageMode = "storage_mode"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Goal DTO matching goals table
struct GoalDTO: Codable {
    var id: String?
    let userId: String
    var categoryName: String?
    var categoryColorHex: String?
    var title: String
    var frequency: String
    var frequencyCount: Int?
    var frequencyUnit: String?
    var status: String?
    var recurrenceType: String?
    var weekdays: [Int]?
    var scheduledTime: String?
    var customIntervalDays: Int?
    var monthlyDayOfMonth: Int?
    var createdAt: String?
    var updatedAt: String?
    var deletedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case categoryName = "category_name"
        case categoryColorHex = "category_color_hex"
        case title, frequency
        case frequencyCount = "frequency_count"
        case frequencyUnit = "frequency_unit"
        case status
        case recurrenceType = "recurrence_type"
        case weekdays
        case scheduledTime = "scheduled_time"
        case customIntervalDays = "custom_interval_days"
        case monthlyDayOfMonth = "monthly_day_of_month"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

/// Completion DTO matching completions table
struct CompletionDTO: Codable {
    var id: String?
    let userId: String
    let goalId: String
    let completedAt: String
    var value: Double?
    var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case goalId = "goal_id"
        case completedAt = "completed_at"
        case value
        case createdAt = "created_at"
    }
}

/// Obligation DTO matching obligations table
struct ObligationDTO: Codable {
    var id: String?
    let userId: String
    let goalId: String
    let scheduledAt: String
    var status: String
    var lockedAt: String?
    var createdAt: String?
    var updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case goalId = "goal_id"
        case scheduledAt = "scheduled_at"
        case status
        case lockedAt = "locked_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Weekly note DTO matching weekly_notes table
struct WeeklyNoteDTO: Codable {
    var id: String?
    let userId: String
    let year: Int
    let month: Int
    let weekIndex: Int
    var text: String
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case year
        case month
        case weekIndex = "week_index"
        case text = "note"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WeeklyNoteUpsertDTO: Encodable {
    let userId: String
    let year: Int
    let month: Int
    let weekIndex: Int
    let text: String
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case year
        case month
        case weekIndex = "week_index"
        case text = "note"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Task DTO matching tasks table
struct TaskDTO: Codable {
    var id: String?
    let userId: String
    let goalId: String
    let date: String
    var isCompleted: Bool?
    var completedAt: String?
    var createdAt: String?
    var updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case goalId = "goal_id"
        case date
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Supabase Error

struct SupabaseError: Codable, Error, LocalizedError {
    let message: String?
    let error: String?
    let errorDescription: String?
    let statusCode: Int?
    
    enum CodingKeys: String, CodingKey {
        case message, error
        case errorDescription = "error_description"
        case statusCode = "status_code"
    }
    
    var localizedDescription: String {
        // Map technical errors to user-friendly messages
        let rawMessage = errorDescription ?? message ?? error ?? ""
        
        switch rawMessage.lowercased() {
        case let msg where msg.contains("invalid api key"):
            return "Unable to connect. Please try again."
        case let msg where msg.contains("invalid login credentials"):
            return "Incorrect email or password"
        case let msg where msg.contains("user already registered"):
            return "An account with this email already exists"
        case let msg where msg.contains("email not confirmed"):
            return "Please verify your email address"
        case let msg where msg.contains("invalid email"):
            return "Please enter a valid email address"
        case let msg where msg.contains("password"):
            return "Password must be at least 6 characters"
        case let msg where msg.contains("rate limit"):
            return "Too many attempts. Please wait a moment."
        case let msg where msg.isEmpty:
            return "Something went wrong. Please try again."
        default:
            // Return a cleaned up version of the original message
            return rawMessage.isEmpty ? "Something went wrong. Please try again." : rawMessage
        }
    }
}

// MARK: - Supabase Service

/// Central service for all Supabase operations
@MainActor
final class SupabaseService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SupabaseService()
    
    // MARK: - Configuration
    // SECURITY: Move Supabase URL/key into a secure, non-source-controlled config.
    private let supabaseURL = "https://frhmmwdsllaiwhbheakr.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZyaG1td2RzbGxhaXdoYmhlYWtyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc4NjQxODcsImV4cCI6MjA4MzQ0MDE4N30.sk8FIGQW9FDUE67we6Q-NyGtNukQMBaAH6p2Mlt9Y2I"
    
    // MARK: - State
    @Published private(set) var currentSession: SupabaseSession?
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var currentUserId: String?
    
    private var sessionInitializationTask: Task<Void, Never>?
    
    /// Returns true ONLY if cloud storage mode is active
    private var isCloudModeEnabled: Bool {
        StorageMode.current == .cloud
    }
    
    // MARK: - Private
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    
    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    // MARK: - Init
    
    private init() {
        loadSession()
    }
    
    // MARK: - Session Management
    
    private func loadSession() {
        // 1. Try to load from Keychain (Secure)
        if let data = KeychainHelper.standard.read(service: "supabase-session", account: "current-user"),
           let session = try? decoder.decode(SupabaseSession.self, from: data) {
            print("[SupabaseService] 🔐 Session loaded from Keychain")
            processLoadedSession(session)
            return
        }
        
        // 2. Fallback: Try to load from UserDefaults (Legacy)
        if let data = UserDefaults.standard.data(forKey: "supabase_session"),
           let session = try? decoder.decode(SupabaseSession.self, from: data) {
            print("[SupabaseService] ⚠️ Legacy session found. Migrating to Keychain...")
            // 3. Migrate to Keychain
            if KeychainHelper.standard.save(data, service: "supabase-session", account: "current-user") {
                // Remove from UserDefaults only after successful save
                UserDefaults.standard.removeObject(forKey: "supabase_session")
                UserDefaults.standard.removeObject(forKey: "supabase_access_token")
                print("[SupabaseService] ✅ Migration successful.")
            }
            
            processLoadedSession(session)
            return
        }
    }
    
    private func processLoadedSession(_ session: SupabaseSession) {
        // Check if token is expired
        if let expiresAt = session.expiresAt {
            let expirationDate = Date(timeIntervalSince1970: TimeInterval(expiresAt))
            if expirationDate > Date() {
                self.currentSession = session
                self.isAuthenticated = true
                self.currentUserId = session.user.id
            } else {
                // Token expired, try to refresh
                print("[SupabaseService] 🔄 Token expired, refreshing...")
                sessionInitializationTask = Task {
                    await refreshSession(session.refreshToken)
                    sessionInitializationTask = nil
                }
            }
        } else {
            self.currentSession = session
            self.isAuthenticated = true
            self.currentUserId = session.user.id
        }
    }
    
    /// Await this if you need to ensure any pending session refresh is complete
    func awaitSessionInitialization() async {
        if let task = sessionInitializationTask {
            print("[SupabaseService] ⏳ Waiting for session initialization...")
            _ = await task.result
            print("[SupabaseService] ✅ Session initialization finished")
        }
    }
    
    func saveSession(_ session: SupabaseSession) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.currentSession = session
            self.isAuthenticated = true
            self.currentUserId = session.user.id
        }
        
        if let data = try? encoder.encode(session) {
            // Save to Keychain
            _ = KeychainHelper.standard.save(data, service: "supabase-session", account: "current-user")
        }
        
        // Legacy cleanup (just in case they logged in fresh)
        UserDefaults.standard.removeObject(forKey: "supabase_session")
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        
        // We still keep this flag for simple checks in other parts of the app, 
        // as it contains no sensitive data.
        UserDefaults.standard.set(true, forKey: "isAuthenticated")
    }
    
    func clearSession(preserveLocalState: Bool = false) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentSession = nil
            isAuthenticated = false
            currentUserId = nil
        }
        
        // Clear from Keychain
        KeychainHelper.standard.delete(service: "supabase-session", account: "current-user")
        
        // Clear Legacy
        UserDefaults.standard.removeObject(forKey: "supabase_session")
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        
        if !preserveLocalState {
            // Clear all app state
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "storageMode")
        }
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
    }
    
    private func refreshSession(_ refreshToken: String) async {
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try? encoder.encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let session = try decoder.decode(SupabaseSession.self, from: data)
                saveSession(session)
            } else {
                clearSession()
            }
        } catch {
            clearSession()
        }
    }
    
    /// Public token refresh for AuthEngine. Throws on failure.
    func refreshToken() async throws {
        guard let token = currentSession?.refreshToken else {
            throw SupabaseError(message: "No refresh token available", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token") else {
            throw SupabaseError(message: "Invalid URL", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = ["refresh_token": token]
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            SyncLogger.logAuth("Token refresh failed", level: .error)
            throw SupabaseError(message: "Token refresh failed", error: nil, errorDescription: nil, statusCode: (response as? HTTPURLResponse)?.statusCode)
        }
        
        let session = try decoder.decode(SupabaseSession.self, from: data)
        saveSession(session)
        SyncLogger.logAuth("Token refresh successful")
    }
    
    // MARK: - Authentication
    
    /// Sign up with email and password
    func signUp(email: String, password: String) async throws -> SupabaseSession {
        print("[SupabaseService] 📝 Starting signup for email: \(email)")
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/signup") else {
            print("[SupabaseService] ❌ Invalid URL")
            throw SupabaseError(message: "Invalid URL", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = ["email": email, "password": password]
        request.httpBody = try encoder.encode(body)

        print("[SupabaseService] 📤 Sending signup request to: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[SupabaseService] ❌ Invalid response type")
            throw SupabaseError(message: "Invalid response", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        print("[SupabaseService] 📥 Response status code: \(httpResponse.statusCode)")
        
        // Log raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("[SupabaseService] 📄 Response body: \(responseString)")
        }
        
        // Accept any 2xx status code as success
        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            do {
                let session = try decoder.decode(SupabaseSession.self, from: data)
                print("[SupabaseService] ✅ Signup successful! User ID: \(session.user.id)")
                saveSession(session)
                return session
            } catch {
                print("[SupabaseService] ⚠️ Decoding session failed: \(error)")
                // Some Supabase configs require email confirmation - check for that
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if json["id"] != nil {
                        print("[SupabaseService] 📧 Email confirmation is ENABLED in Supabase Project Settings")
                        // If this triggers, it means the backend setting "Confirm email" is ON.
                        // To fix this: Go to Supabase Dashboard -> Authentication -> Providers -> Email -> Disable "Confirm email"
                        throw SupabaseError(
                            message: nil,
                            error: nil,
                            errorDescription: "Account created! Please verify your email. (To skip this, disable 'Confirm email' in Supabase Dashboard)",
                            statusCode: httpResponse.statusCode
                        )
                    }
                }
                throw SupabaseError(message: "Sign up failed", error: nil, errorDescription: nil, statusCode: httpResponse.statusCode)
            }
        } else {
            print("[SupabaseService] ❌ Signup failed with status: \(httpResponse.statusCode)")
            let error = try? decoder.decode(SupabaseError.self, from: data)
            if let error = error {
                print("[SupabaseService] ❌ Error: \(error.localizedDescription)")
            }
            throw error ?? SupabaseError(message: "Sign up failed", error: nil, errorDescription: nil, statusCode: httpResponse.statusCode)
        }
    }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws -> SupabaseSession {
        print("[SupabaseService] 🔐 Starting sign in for email: \(email)")
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password") else {
            print("[SupabaseService] ❌ Invalid URL")
            throw SupabaseError(message: "Invalid URL", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = ["email": email, "password": password]
        request.httpBody = try encoder.encode(body)

        print("[SupabaseService] 📤 Sending sign in request")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[SupabaseService] ❌ Invalid response type")
            throw SupabaseError(message: "Invalid response", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        print("[SupabaseService] 📥 Response status code: \(httpResponse.statusCode)")
        
        // Log raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("[SupabaseService] 📄 Response body: \(responseString)")
        }
        
        if httpResponse.statusCode == 200 {
            let session = try decoder.decode(SupabaseSession.self, from: data)
            print("[SupabaseService] ✅ Sign in successful! User ID: \(session.user.id)")
            await checkOnboardingStatus(userId: session.user.id)
            saveSession(session)
            return session
        } else {
            print("[SupabaseService] ❌ Sign in failed with status: \(httpResponse.statusCode)")
            let error = try? decoder.decode(SupabaseError.self, from: data)
            if let error = error {
                print("[SupabaseService] ❌ Error: \(error.localizedDescription)")
            }
            throw error ?? SupabaseError(message: "Sign in failed", error: nil, errorDescription: nil, statusCode: httpResponse.statusCode)
        }
    }
    
    /// Sign in with Apple ID Token
    func signInWithIdToken(idToken: String, nonce: String) async throws -> SupabaseSession {
        print("[SupabaseService]  Starting Sign in with Apple")
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=id_token") else {
            throw SupabaseError(message: "Invalid URL", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = [
            "provider": "apple",
            "id_token": idToken,
            "nonce": nonce
        ]
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError(message: "Invalid response", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        if httpResponse.statusCode == 200 {
            let session = try decoder.decode(SupabaseSession.self, from: data)
            print("[SupabaseService] ✅ Apple Sign in successful! User ID: \(session.user.id)")
            await checkOnboardingStatus(userId: session.user.id)
            saveSession(session)
            return session
        } else {
            print("[SupabaseService] ❌ Apple Sign in failed: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("[SupabaseService] 📄 RAW ERROR RESPONSE: \(responseString)")
            }
            let error = try? decoder.decode(SupabaseError.self, from: data)
            throw error ?? SupabaseError(message: "Apple Sign in failed (Status: \(httpResponse.statusCode))", error: nil, errorDescription: nil, statusCode: httpResponse.statusCode)
        }
    }
    
    /// Sign out
    func signOut(preserveLocalState: Bool = false) async {
        guard let token = currentSession?.accessToken,
              let url = URL(string: "\(supabaseURL)/auth/v1/logout") else {
            clearSession(preserveLocalState: preserveLocalState)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        _ = try? await URLSession.shared.data(for: request)
        clearSession(preserveLocalState: preserveLocalState)
    }
    
    /// Delete account and all associated data.
    /// INVARIANT: If auth user deletion fails, the entire operation fails.
    func deleteAccount() async throws {
        guard let userId = currentUserId else { 
            throw SupabaseError(message: "No user ID available for deletion", error: nil, errorDescription: nil, statusCode: nil)
        }
        SyncLogger.logAccount("Starting account deletion for user: \(userId)")
        
        // 1. Delete all data from public tables - ATOMIC: fail on any error
        // Order matters - delete dependent tables first
        let tables = ["completions", "weekly_notes", "goals", "categories", "user_settings", "profiles"]
        
        for table in tables {
            SyncLogger.logAccount("Deleting from \(table)...")
            do {
                _ = try await makeRequest(
                    path: table,
                    method: "DELETE",
                    queryParams: [(table == "profiles" ? "id" : "user_id", "eq.\(userId)")]
                )
            } catch {
                SyncLogger.logAccount("Failed to delete from \(table) - ABORTING entire deletion", level: .error)
                throw SupabaseError(
                    message: "Account deletion aborted: failed to delete from \(table). No data was removed.",
                    error: nil,
                    errorDescription: error.localizedDescription,
                    statusCode: nil
                )
            }
        }
        
        // 2. Delete Auth User - THIS MUST SUCCEED
        // If auth deletion fails, the entire operation fails
        SyncLogger.logAccount("Deleting auth user via RPC...")
        do {
            _ = try await makeRequest(path: "rpc/delete_user", method: "POST", body: nil)
            SyncLogger.logAccount("Auth user deleted successfully")
        } catch {
            SyncLogger.logAccount("Auth user deletion failed - aborting", level: .error)
            throw SupabaseError(
                message: "Account deletion failed: could not delete auth user. Your data remains intact.",
                error: nil,
                errorDescription: error.localizedDescription,
                statusCode: nil
            )
        }

        // 3. Sign out locally only after successful auth deletion
        await signOut()
        SyncLogger.logAccount("Account deletion complete")
    }
    
    /// Password reset
    func resetPassword(email: String) async throws {
        guard let url = URL(string: "\(supabaseURL)/auth/v1/recover") else {
            throw SupabaseError(message: "Invalid URL", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = ["email": email]
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let error = try? decoder.decode(SupabaseError.self, from: data)
            throw error ?? SupabaseError(message: "Failed to send reset email", error: nil, errorDescription: nil, statusCode: nil)
        }
    }
    
    /// Checks if the user has completed onboarding by fetching their profile regardless of local settings.
    /// If a valid profile is found, updates local UserDefaults to reflect this.
    func checkOnboardingStatus(userId: String? = nil) async {
        guard let targetUserId = userId ?? currentUserId else { return }
        print("[SupabaseService] 🔍 Checking remote onboarding status for user: \(targetUserId)")
        
        do {
            // Manually fetch profile to bypass 'isCloudModeEnabled' guard
            // We select 'name' specifically as a heuristic for completion
            let data = try await makeRequest(
                path: "profiles",
                method: "GET",
                queryParams: [("id", "eq.\(targetUserId)"), ("select", "*")]
            )
            
            let profiles = try decoder.decode([ProfileDTO].self, from: data)
            if let profile = profiles.first, let name = profile.name, !name.isEmpty {
                print("[SupabaseService] ✅ Existing profile found for '\(name)'. Restoring cloud state.")
                await MainActor.run {
                    // Mark onboarding as complete
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    
                    // Force set storage mode to cloud since we found a cloud profile
                    StorageMode.persist(.cloud)
                    
                    // Trigger a settings fetch to ensure local settings sync
                    Task {
                        try? await self.getSettings()
                    }
                }
            } else {
                print("[SupabaseService] ℹ️ No complete profile found. User must complete onboarding.")
            }
        } catch {
            print("[SupabaseService] ⚠️ Error checking onboarding status: \(error)")
        }
    }
    
    // MARK: - REST API Helpers
    
    private var authHeaders: [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "apikey": supabaseAnonKey,
            "Prefer": "return=representation"
        ]
        if let token = currentSession?.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }
    
    private func makeRequest(path: String, method: String, body: Data? = nil, queryParams: [(String, String)]? = nil) async throws -> Data {
        var urlString = "\(supabaseURL)/rest/v1/\(path)"
        
        if let queryParams = queryParams, !queryParams.isEmpty {
            let queryString = queryParams.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }
        
        guard let url = URL(string: urlString) else {
            throw SupabaseError(message: "Invalid URL", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError(message: "Invalid response", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            return data
        } else {
            let error = try? decoder.decode(SupabaseError.self, from: data)
            throw error ?? SupabaseError(message: "Request failed", error: nil, errorDescription: nil, statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Profile Operations
    
    /// Get current user's profile
    func getProfile() async throws -> ProfileDTO? {
        guard isCloudModeEnabled else { return nil }
        guard let userId = currentUserId else { return nil }
        
        let data = try await makeRequest(
            path: "profiles",
            method: "GET",
            queryParams: [("id", "eq.\(userId)"), ("select", "*")]
        )
        
        let profiles = try decoder.decode([ProfileDTO].self, from: data)
        return profiles.first
    }
    
    /// Get current user's profile for authentication purposes.
    /// This bypasses storage mode check since we need to check if user exists
    /// before storage mode is determined (during re-login after logout).
    func getProfileForAuth() async throws -> ProfileDTO? {
        guard let userId = currentUserId else { return nil }
        
        let data = try await makeRequest(
            path: "profiles",
            method: "GET",
            queryParams: [("id", "eq.\(userId)"), ("select", "*")]
        )
        
        let profiles = try decoder.decode([ProfileDTO].self, from: data)
        return profiles.first
    }
    
    /// Get current user's settings for authentication purposes.
    /// This bypasses storage mode check for re-login scenarios.
    func getSettingsForAuth() async throws -> UserSettingsDTO? {
        guard let userId = currentUserId else { return nil }
        
        let data = try await makeRequest(
            path: "user_settings",
            method: "GET",
            queryParams: [("user_id", "eq.\(userId)"), ("select", "*")]
        )
        
        let settings = try decoder.decode([UserSettingsDTO].self, from: data)
        return settings.first
    }
    
    /// Update current user's profile
    func updateProfile(_ profile: ProfileDTO) async throws -> ProfileDTO {
        guard isCloudModeEnabled else { return profile }
        guard let userId = currentUserId else {
            throw SupabaseError(message: "Not authenticated", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        // Try to update first
        let body = try encoder.encode(profile)
        do {
            let data = try await makeRequest(
                path: "profiles",
                method: "PATCH",
                body: body,
                queryParams: [("id", "eq.\(userId)")]
            )
            
            let profiles = try decoder.decode([ProfileDTO].self, from: data)
            if let updated = profiles.first {
                return updated
            }
        } catch {
            print("[SupabaseService] ⚠️ Update failed, trying upsert: \(error)")
        }
        
        // If update failed or returned empty (row doesn't exist), try upsert
        return try await upsertProfile(profile)
    }
    
    /// Upsert profile (create or update)
    func upsertProfile(_ profile: ProfileDTO) async throws -> ProfileDTO {
        guard isCloudModeEnabled else { return profile }
        
        var profileToSave = profile
        profileToSave.updatedAt = iso8601Formatter.string(from: Date())
        
        let body = try encoder.encode(profileToSave)
        
        var request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/profiles")!)
        request.httpMethod = "POST"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = body
        
        print("[SupabaseService] 📤 Upserting profile for user: \(profile.id)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
             throw SupabaseError(message: "Invalid response", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            let results = try decoder.decode([ProfileDTO].self, from: data)
            return results.first ?? profileToSave
        } else {
            print("[SupabaseService] ❌ Upsert profile failed with status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("[SupabaseService] 📄 Response body: \(responseString)")
            }
            
            let error = try? decoder.decode(SupabaseError.self, from: data)
            throw error ?? SupabaseError(message: "Failed to upsert profile", error: nil, errorDescription: nil, statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Settings Operations
    
    /// Get current user's settings
    func getSettings() async throws -> UserSettingsDTO? {
        // Settings are always synced, regardless of storage mode
        guard let userId = currentUserId else { return nil }
        
        let data = try await makeRequest(
            path: "user_settings",
            method: "GET",
            queryParams: [("user_id", "eq.\(userId)"), ("select", "*")]
        )
        
        let settings = try decoder.decode([UserSettingsDTO].self, from: data)
        return settings.first
    }
    
    /// Update current user's settings (upsert)
    func upsertSettings(_ settings: UserSettingsDTO) async throws -> UserSettingsDTO {
        // Settings are always synced, regardless of storage mode
        var settingsToSave = settings
        settingsToSave.updatedAt = iso8601Formatter.string(from: Date())
        
        let body = try encoder.encode(settingsToSave)
        
        var request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/user_settings?on_conflict=user_id")!)
        request.httpMethod = "POST"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = body
        
        print("[SupabaseService] ⚙️ Upserting settings for user: \(settings.userId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError(message: "Invalid response", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            guard !data.isEmpty else {
                return settingsToSave
            }
            
            let results = try decoder.decode([UserSettingsDTO].self, from: data)
            return results.first ?? settingsToSave
        } else {
            print("[SupabaseService] ❌ Upsert settings failed with status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("[SupabaseService] 📄 Response body: \(responseString)")
            }
            
            let error = try? decoder.decode(SupabaseError.self, from: data)
            throw error ?? SupabaseError(message: "Failed to save settings", error: nil, errorDescription: nil, statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Goal Operations
    
    /// Get all goals for current user
    func getGoals(includeDeleted: Bool = false) async throws -> [GoalDTO] {
        guard isCloudModeEnabled else { return [] }
        guard let userId = currentUserId else { return [] }
        
        var params: [(String, String)] = [
            ("user_id", "eq.\(userId)"),
            ("select", "*"),
            ("order", "created_at.desc")
        ]
        if !includeDeleted {
            params.append(("deleted_at", "is.null"))
        }
        
        let data = try await makeRequest(path: "goals", method: "GET", queryParams: params)
        return try decoder.decode([GoalDTO].self, from: data)
    }
    
    /// Create a new goal
    func createGoal(_ goal: GoalDTO) async throws -> GoalDTO {
        guard isCloudModeEnabled else { return goal }
        let body = try encoder.encode(goal)
        let data = try await makeRequest(path: "goals", method: "POST", body: body)
        
        let results = try decoder.decode([GoalDTO].self, from: data)
        guard let created = results.first else {
            throw SupabaseError(message: "Failed to create goal", error: nil, errorDescription: nil, statusCode: nil)
        }
        return created
    }
    
    /// Update a goal
    func updateGoal(_ goal: GoalDTO) async throws -> GoalDTO {
        guard isCloudModeEnabled else { return goal }
        guard let goalId = goal.id else {
            throw SupabaseError(message: "Goal ID required", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        var goalToUpdate = goal
        goalToUpdate.updatedAt = iso8601Formatter.string(from: Date())
        
        let body = try encoder.encode(goalToUpdate)
        let data = try await makeRequest(
            path: "goals",
            method: "PATCH",
            body: body,
            queryParams: [("id", "eq.\(goalId)")]
        )
        
        let results = try decoder.decode([GoalDTO].self, from: data)
        guard let updated = results.first else {
            throw SupabaseError(message: "Goal not found", error: nil, errorDescription: nil, statusCode: nil)
        }
        return updated
    }
    
    /// Deletes a goal
    func deleteGoal(id: String) async throws {
        guard isCloudModeEnabled else { return }
        _ = try await makeRequest(
            path: "goals",
            method: "DELETE",
            queryParams: [("id", "eq.\(id)")]
        )
    }
    
    // MARK: - Completion Operations
    
    // MARK: - Completion Operations
    
    // getCompletions(from:to:) is defined below
    

    
    /// Get completions for a specific goal
    func getCompletions(goalId: String) async throws -> [CompletionDTO] {
        guard isCloudModeEnabled else { return [] }
        guard let userId = currentUserId else { return [] }
        
        let data = try await makeRequest(
            path: "completions",
            method: "GET",
            queryParams: [
                ("user_id", "eq.\(userId)"),
                ("goal_id", "eq.\(goalId)"),
                ("select", "*"),
                ("order", "completed_at.desc")
            ]
        )
        
        return try decoder.decode([CompletionDTO].self, from: data)
    }
    
    /// Create a completion
    func createCompletion(_ completion: CompletionDTO) async throws -> CompletionDTO {
        guard isCloudModeEnabled else { return completion }
        let body = try encoder.encode(completion)
        let data = try await makeRequest(path: "completions", method: "POST", body: body)
        
        let results = try decoder.decode([CompletionDTO].self, from: data)
        guard let created = results.first else {
            throw SupabaseError(message: "Failed to create completion", error: nil, errorDescription: nil, statusCode: nil)
        }
        return created
    }
    
    /// Delete a completion
    func deleteCompletion(id: String) async throws {
        guard isCloudModeEnabled else { return }
        _ = try await makeRequest(
            path: "completions",
            method: "DELETE",
            queryParams: [("id", "eq.\(id)")]
        )
    }

    // MARK: - Obligation Operations

    /// Fetch completions in date range
    func getCompletions(from start: Date, to end: Date) async throws -> [CompletionDTO] {
        guard isCloudModeEnabled else { return [] }
        guard let userId = currentUserId else { return [] }
        
        let startStr = iso8601Formatter.string(from: start)
        let endStr = iso8601Formatter.string(from: end)
        
        let data = try await makeRequest(
            path: "completions",
            method: "GET",
            queryParams: [
                ("select", "*"),
                ("user_id", "eq.\(userId)"),
                ("completed_at", "gte.\(startStr)"),
                ("completed_at", "lt.\(endStr)")
            ]
        )
        
        return try decoder.decode([CompletionDTO].self, from: data)
    }

    /// Upsert multiple obligations
    func upsertObligations(_ obligations: [ObligationDTO]) async throws -> [ObligationDTO] {
        guard isCloudModeEnabled else { return obligations }
        guard !obligations.isEmpty else { return [] }

        let body = try encoder.encode(obligations)

        var request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/obligations?on_conflict=id")!)
        request.httpMethod = "POST"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw SupabaseError(message: "Failed to upsert obligations", error: nil, errorDescription: nil, statusCode: nil)
        }

        return try decoder.decode([ObligationDTO].self, from: data)
    }

    /// Delete an obligation
    func deleteObligation(id: String) async throws {
        guard isCloudModeEnabled else { return }
        _ = try await makeRequest(
            path: "obligations",
            method: "DELETE",
            queryParams: [("id", "eq.\(id)")]
        )
    }

    /// Delete obligations for a goal
    func deleteObligations(goalId: String) async throws {
        guard isCloudModeEnabled else { return }
        _ = try await makeRequest(
            path: "obligations",
            method: "DELETE",
            queryParams: [("goal_id", "eq.\(goalId)")]
        )
    }
    
    // MARK: - Bulk Operations
    
    /// Upsert multiple goals
    func upsertGoals(_ goals: [GoalDTO]) async throws -> [GoalDTO] {
        guard isCloudModeEnabled else { return goals }
        guard !goals.isEmpty else { return [] }
        
        let body = try encoder.encode(goals)
        
        var request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/goals")!)
        request.httpMethod = "POST"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw SupabaseError(message: "Failed to upsert goals", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        return try decoder.decode([GoalDTO].self, from: data)
    }
    
    /// Upsert multiple completions
    func upsertCompletions(_ completions: [CompletionDTO]) async throws -> [CompletionDTO] {
        guard isCloudModeEnabled else { return completions }
        guard !completions.isEmpty else { return [] }
        
        let body = try encoder.encode(completions)
        
        var request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/completions")!)
        request.httpMethod = "POST"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw SupabaseError(message: "Failed to upsert completions", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        return try decoder.decode([CompletionDTO].self, from: data)
    }

    // MARK: - Weekly Notes Operations

    /// Get weekly notes for a specific month
    func getWeeklyNotes(year: Int, month: Int) async throws -> [WeeklyNoteDTO] {
        guard isCloudModeEnabled else { return [] }
        guard let userId = currentUserId else { return [] }

        let data = try await makeRequest(
            path: "weekly_notes",
            method: "GET",
            queryParams: [
                ("user_id", "eq.\(userId)"),
                ("year", "eq.\(year)"),
                ("month", "eq.\(month)"),
                ("select", "*"),
                ("order", "week_index.asc")
            ]
        )

        return try decoder.decode([WeeklyNoteDTO].self, from: data)
    }
    
    /// Get all weekly notes for the current user
    func getWeeklyNotes() async throws -> [WeeklyNoteDTO] {
        guard isCloudModeEnabled else { return [] }
        guard let userId = currentUserId else { return [] }

        let data = try await makeRequest(
            path: "weekly_notes",
            method: "GET",
            queryParams: [
                ("user_id", "eq.\(userId)"),
                ("select", "*")
            ]
        )

        return try decoder.decode([WeeklyNoteDTO].self, from: data)
    }
    
    /// Delete all user data from a specific table
    func deleteAllUserData(from table: String, userId: String) async throws {
        let queryParam = table == "profiles" ? ("id", "eq.\(userId)") : ("user_id", "eq.\(userId)")
        
        _ = try await makeRequest(
            path: table,
            method: "DELETE",
            queryParams: [queryParam]
        )
        
        SyncLogger.logAccount("Deleted user data from \(table)")
    }

    /// Upsert multiple weekly notes
    func upsertWeeklyNotes(_ notes: [WeeklyNoteUpsertDTO]) async throws -> [WeeklyNoteDTO] {
        guard isCloudModeEnabled else { return [] }
        guard !notes.isEmpty else { return [] }

        let body = try encoder.encode(notes)

        var request = URLRequest(
            url: URL(string: "\(supabaseURL)/rest/v1/weekly_notes?on_conflict=user_id,year,month,week_index")!
        )
        request.httpMethod = "POST"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw SupabaseError(message: "Failed to upsert weekly notes", error: nil, errorDescription: nil, statusCode: nil)
        }

        return try decoder.decode([WeeklyNoteDTO].self, from: data)
    }
    
    /// Upsert a single weekly note (convenience wrapper)
    func upsertWeeklyNote(userId: String, year: Int, month: Int, weekIndex: Int, text: String) async throws {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = isoFormatter.string(from: Date())
        
        let dto = WeeklyNoteUpsertDTO(
            userId: userId,
            year: year,
            month: month,
            weekIndex: weekIndex,
            text: text,
            createdAt: now,
            updatedAt: now
        )
        _ = try await upsertWeeklyNotes([dto])
    }
    
    // MARK: - Account Deletion
    
    /// Deletes ALL user data from Supabase (completions, goals, settings, profile)
    /// This is called when user deletes their account
    func deleteAllUserData() async throws {
        guard let userId = currentUserId else {
            throw SupabaseError(message: "No user ID available", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        // Delete in order: completions -> goals -> settings -> profile
        // (respecting foreign key constraints)
        
        // 1. Delete all completions
        var request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/completions?user_id=eq.\(userId)")!)
        request.httpMethod = "DELETE"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let _ = try await URLSession.shared.data(for: request)
        
        // 2. Delete all goals
        request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/goals?user_id=eq.\(userId)")!)
        request.httpMethod = "DELETE"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let _ = try await URLSession.shared.data(for: request)
        
        // 3. Delete settings
        request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/settings?user_id=eq.\(userId)")!)
        request.httpMethod = "DELETE"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let _ = try await URLSession.shared.data(for: request)
        
        // 4. Delete profile
        request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/profiles?id=eq.\(userId)")!)
        request.httpMethod = "DELETE"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let _ = try await URLSession.shared.data(for: request)
        
        print("✅ All user data deleted from Supabase")
    }
    
    /// Resets user's goal/task data without deleting account or settings.
    /// Deletes: completions, obligations, goals
    /// Keeps: profile, settings (user stays logged in)
    func resetUserData() async throws {
        guard let userId = currentUserId else {
            throw SupabaseError(message: "No user ID available", error: nil, errorDescription: nil, statusCode: nil)
        }
        
        // Delete in order respecting foreign key constraints:
        // completions -> obligations -> weekly_notes -> goals
        
        // 1. Delete all completions
        var request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/completions?user_id=eq.\(userId)")!)
        request.httpMethod = "DELETE"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let _ = try await URLSession.shared.data(for: request)
        
        // 2. Delete all obligations
        request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/obligations?user_id=eq.\(userId)")!)
        request.httpMethod = "DELETE"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let _ = try await URLSession.shared.data(for: request)

        // 3. Delete all weekly notes
        request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/weekly_notes?user_id=eq.\(userId)")!)
        request.httpMethod = "DELETE"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let _ = try await URLSession.shared.data(for: request)

        // 4. Delete all goals
        request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/goals?user_id=eq.\(userId)")!)
        request.httpMethod = "DELETE"
        authHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let _ = try await URLSession.shared.data(for: request)
        
        print("✅ User data reset in Supabase (profile and settings preserved)")
    }
}

// MARK: - Keychain Helper

private struct KeychainHelper {
    static let standard = KeychainHelper()
    
    private init() {}
    
    func save(_ data: Data, service: String, account: String) -> Bool {
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as [CFString: Any]
        
        // Add
        var status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // Item already exists, update it
            let query = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account
            ] as [CFString: Any]
            
            let attributesToUpdate = [kSecValueData: data] as [CFString: Any]
            
            status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        }
        
        return status == errSecSuccess
    }
    
    func read(service: String, account: String) -> Data? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [CFString: Any]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        
        return nil
    }
    
    func delete(service: String, account: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as [CFString: Any]
        
        SecItemDelete(query as CFDictionary)
    }
}
