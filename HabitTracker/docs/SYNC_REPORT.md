# Synchronization & App Flow Report

This document outlines the architecture for synchronization between the HabitTracker iOS app (SwiftData) and the Supabase backend, as well as the authentication and data flow lifecycles.

## 1. Authentication & User Flow

The app uses a hybrid authentication flow that handles both new users (Onboarding) and returning users (restoring state).

### A. Login & Session Management
- **Auth Provider**: Supabase Auth (Email/Password & Apple Sign In).
- **Session Handling**: `SupabaseService` manages the session. The app checks `isAuthenticated` state on launch.
- **Root Phase**: `HabitTrackerApp.swift` determines the root view based on:
  1. `isAuthenticated`: If false → **AuthView**
  2. `hasCompletedOnboarding`: If false → **Onboarding**
  3. Else → **MainView (ContentView)**

### B. Returning User Detection (Skip Onboarding)
When a user logs in (or signs in with Apple), the app performs a check to see if they are a returning user who has explicitly cleared local data (or is on a new device).

1. **Authentication Success**: User signs in via `AuthViewModel`.
2. **Profile Check**: `AuthViewModel` calls `SupabaseService.getProfileForAuth()`.
   - *Note*: This special method bypasses the `StorageMode` check because locally stored settings are cleared on logout.
3. **Restoration**:
   - If a profile exists:
     - `hasCompletedOnboarding` is set to TRUE.
     - User settings (theme, storage mode, etc.) are fetched via `getSettingsForAuth()` and restored to `UserDefaults`.
     - User is directed straight to **MainView**.
   - If no profile exists:
     - User is directed to **Onboarding**.

### C. Logout & Reset
- **Logout**: Clears all local SwiftData, all UserDefaults (including valid session tokens), and signs out from Supabase.
- **Reset All Data**: Deletes all user data (Goals, Tasks, Obligations) from both SwiftData and Supabase, but **maintains the user session** and profile/settings.

---

## 2. Data Synchronization (Cloud Sync)

The app supports a "Cloud Storage" mode where data is synchronized between local persistence (SwiftData) and the backend (Supabase). Syncing is handled by `SyncService`.

### A. Full Synchronization (Pull & Push)
A full bidirectional sync (`performFullSync`) occurs automatically in two main scenarios:
1. **App Launch**: After the splash screen animation finishes.
2. **Post-Login**: Immediately after a successful login.

**Sync Order (Respecting Foreign Keys):**
Because of database constraints (Goal depends on Category, Obligation depends on Goal), sync happens in a strict sequence:
1. **Categories**:
   - Download remote categories.
   - Upload local categories that are missing remotely.
   - *Result*: Categories are harmonised before goals are processed.
2. **Goals**:
   - Download remote goals.
   - Upload local goals that are missing remotely.
   - Update local goals if remote is newer.
3. **Completions**:
   - Sync completion records.
4. **Obligations**:
   - (Currently pending full implementation) Future sync for generated obligations.

### B. Real-Time / Event-Based Sync (Push)
Changes made in the UI are immediately pushed to Supabase to keep the cloud state fresh.

- **Goal Creation**:
  - User saves goal in `GoalFormSheet`.
  - **Local**: Goal inserted into `modelContext`.
  - **Cloud**: `SyncService.syncGoalCreation(goal)` is called.
  - *Note*: If the category was just created locally, `syncCategoryCreation(category)` is called first.
- **Goal Update**: `SyncService.syncGoalUpdate(goal)` updates the record in Supabase.
- **Goal Deletion**: `SyncService.syncGoalDeletion(id)` removes the record from Supabase.

### C. Settings & Profile Sync
User preferences (Theme, Haptics, Profile Name) are also synced.
- **Trigger**: `SettingsStore` saves property changes.
- **Debounce**: Multiple rapid changes (e.g., typing a name) are debounced by 2 seconds before triggering `syncSettingsToCloud`.
- **Direction**:
  - **Push**: `SettingsStore` change → `syncSettingsToCloud`.
  - **Pull**: On login/launch → `syncSettingsFromCloud`.

---

## 3. Database Schema Mapping

| SwiftData Model | Supabase Table | Description |
| :--- | :--- | :--- |
| `GoalModel` | `goals` | Core habit/goal definitions. |
| `CategoryModel` | `categories` | Categorization for goals. |
| `CompletionModel` | `completions` | Records of habit completions. |
| `ObligationModel` | `obligations` | (New) Scheduled instances of goals. |
| `UserProfile` (Settings) | `profiles`, `settings` | User metadata and app preference config. |

## 4. Key Logic Controllers

- **`HabitTrackerApp.swift`**: Orchestrates the high-level lifecycle (Splash -> Auth -> Sync -> Main).
- **`SupabaseService`**: Low-level API client handling Auth, CRUD operations, and raw Request construction.
- **`SyncService`**: Business logic for reconciling local vs. remote state, handling conflicts (simplistic "newest wins" or "remote wins"), and managing sync order.
- **`AuthViewModel`**: Manages the UI state for login/signup and handling the "Returning User" restoration logic.

---

## 5. Current Implementation Status

- **Completed**:
  - Auth Flow (Apple/Email) + Returning User Detection.
  - Category & Goal Sync (Bidirectional).
  - Settings Sync.
  - "Reset All Data" functionality.
  - "Logout" functionality.

- **In Progress / Future**:
  - **Obligation Sync**: The backend table exists, but full bidirectional sync for `ObligationModel` is being integrated as part of the architecture shift from "Tasks" to "Obligations".
