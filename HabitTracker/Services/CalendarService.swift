import EventKit
import Foundation
import UIKit

/// Read-only calendar service for detecting busy/free days.
/// Uses EventKit to access the user's iOS calendar with proper permission handling.
@MainActor
final class CalendarService: ObservableObject {
    
    static let shared = CalendarService()
    
    private let eventStore = EKEventStore()
    private let calendar = Calendar.current
    
    /// Current authorization status for calendar access
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    
    /// Whether calendar access is granted
    var isAuthorized: Bool {
        authorizationStatus == .fullAccess || authorizationStatus == .authorized
    }
    
    private init() {
        updateAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    /// Updates the current authorization status
    private func updateAuthorizationStatus() {
        if #available(iOS 17.0, *) {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        } else {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }
    
    /// Requests read-only access to the user's calendar.
    /// - Returns: `true` if access was granted, `false` otherwise.
    func requestAccess() async -> Bool {
        // Check current status first
        updateAuthorizationStatus()
        
        switch authorizationStatus {
        case .authorized, .fullAccess:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            break
        case .writeOnly:
            // writeOnly doesn't help us - we need read access
            return false
        @unknown default:
            return false
        }
        
        // Request access
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }
            
            updateAuthorizationStatus()
            return granted
        } catch {
            print("CalendarService: Failed to request access - \(error.localizedDescription)")
            updateAuthorizationStatus()
            return false
        }
    }
    
    // MARK: - Event Fetching
    
    /// Fetches all calendar events within the specified date range.
    /// - Parameters:
    ///   - startDate: Start of the date range (inclusive)
    ///   - endDate: End of the date range (inclusive)
    /// - Returns: Array of events, or empty array if access is denied
    func events(from startDate: Date, to endDate: Date) -> [EKEvent] {
        guard isAuthorized else {
            print("CalendarService: Cannot fetch events - access not granted")
            return []
        }
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil  // Include all calendars
        )
        
        return eventStore.events(matching: predicate)
    }
    
    /// Checks if a specific date has any calendar events.
    /// - Parameter date: The date to check
    /// - Returns: `true` if events exist on that date, `false` otherwise
    func hasEvents(on date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return false
        }
        
        return !events(from: startOfDay, to: endOfDay).isEmpty
    }
    
    /// Returns a set of dates that have calendar events (busy days).
    /// Useful for planning logic to avoid scheduling on busy days.
    /// - Parameters:
    ///   - startDate: Start of the date range
    ///   - endDate: End of the date range
    /// - Returns: Set of dates (normalized to start of day) that have events
    func busyDates(from startDate: Date, to endDate: Date) -> Set<Date> {
        let allEvents = events(from: startDate, to: endDate)
        
        var busy = Set<Date>()
        for event in allEvents {
            // Normalize to start of day for consistent comparison
            let eventDate = calendar.startOfDay(for: event.startDate)
            busy.insert(eventDate)
        }
        
        return busy
    }
    
    /// Returns events for today.
    /// Convenience method for quick lookups.
    func todaysEvents() -> [EKEvent] {
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        
        return events(from: startOfDay, to: endOfDay)
    }
    
    /// Returns events for the current week.
    func thisWeeksEvents() -> [EKEvent] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }
        
        return events(from: weekInterval.start, to: weekInterval.end)
    }
    
    /// Returns events for the current month.
    func thisMonthsEvents() -> [EKEvent] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else {
            return []
        }
        
        return events(from: monthInterval.start, to: monthInterval.end)
    }
    
    // MARK: - Utility
    
    /// Checks if calendar access has been determined (user has seen prompt).
    var hasRequestedAccess: Bool {
        authorizationStatus != .notDetermined
    }
    
    /// Opens Settings app to allow user to enable calendar access.
    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}
