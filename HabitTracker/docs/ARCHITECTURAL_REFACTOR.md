# Architecture Refactor: Lifecycle & Synchronization

Based on the critical audit of the app's current state, we are moving from a loosely coupled, race-condition-prone architecture to a strict **State-Driven Lifecycle**.

## 1. Core Principles

1.  **Single Source of Truth for Lifecycle**: `AppSessionManager` determines if the app is syncing, ready, or logging out.
2.  **Identity First**: User identity (Auth + Profile + Settings) must be fully resolved and authoritative *before* any content (Goals/Tasks) is touched.
3.  **Strict "Ready" State**: No writes, no sync pushes, and no UI interaction allowed until the app is in the `running` state.
4.  **Logout Barrier**: Synchronization must be explicitly frozen before data destruction begins to prevent "empty state" pushes.

## 2. New State Machine (`AppLifecycleState`)

The app will exist in one of these mutually exclusive states:

```swift
enum AppLifecycleState {
    case startup            // App launch, checking auth status
    case authenticating     // Active login request in progress
    case restoringIdentity  // Fetching Profile & Settings (Cloud Authoritative)
    case synchronizing      // Initial content pull (Goals, Tasks)
    case running            // Normal operation (Real-time sync active)
    case tearingDown        // Logout/Reset in progress (Sync FROZEN)
    case unauthenticated    // Logged out / Onboarding
}
```

## 3. Implementation Plan

### Phase 1: The Session Manager (`AppSessionManager`)
- **Action**: Create a singleton `AppSessionManager` (Observable).
- **Responsibility**: Holds the `state`. Exposed to Views.
- **Rules**: 
    - `AuthViewModel` does NOT touch UserDefaults/SwiftData directly anymore. It signals `AppSessionManager`.
    - `SyncService` observes `state`. If not `.running`, all Push operations return immediately.

### Phase 2: Refactor SyncService
- **Action**: Split massive `performFullSync` into distinct stages.
- **New Methods**:
    - `syncIdentity()`: Pulls Profile+Settings. Ignores local defaults.
    - `hydrateContent()`: Pulls Goals+Tasks. Deletes local if conflict (for initial login).
    - `enableRealtimeSync()`: Activates the listeners for ongoing changes.
- **Guardrails**: Add `guard AppSessionManager.shared.state == .running else { return }` to all push methods.

### Phase 3: Refactor Auth Flow
- **Input**: Login success.
- **Flow**:
    1. Auth success -> Transition to `.restoringIdentity`.
    2. `AppSessionManager` pulls Profile/Settings.
    3. If Profile exists -> Transition to `.synchronizing`.
    4. `AppSessionManager` triggers `hydrateContent()`.
    5. Success -> Transition to `.running`.
    6. UI switches to MainView.

### Phase 4: Fix Logout/Reset
- **Flow**:
    1. User clicks Logout.
    2. Transition to `.tearingDown`.
    3. `SyncService` cancels all tasks.
    4. Data is wiped.
    5. Transition to `.unauthenticated`.

## 4. Immediate Next Steps for AI

1. Create `AppSessionManager.swift`.
2. Refactor `HubitTrackerApp.swift` to use this manager.
3. Update `AuthViewModel` to delegate post-login logic to the manager.
4. Update `SyncService` to respect the lifecycle gates.
