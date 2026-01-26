import Foundation
import SwiftData

/// Local storage for monthly immutable snapshots.
/// Corresponds to `monthly_snapshots` table in Supabase.
/// This data is read-only and authoritative.
@Model
final class SnapshotModel {
    // MARK: - Identifiers
    @Attribute(.unique) var id: UUID
    var userId: UUID
    
    // MARK: - Time Component
    var year: Int
    var month: Int
    
    // MARK: - Composite Key for Fast Lookup
    /// Format: "YYYY-MM" (e.g., "2024-01")
    /// Ensures local uniqueness effectively
    @Attribute(.unique) var compositeKey: String
    
    // MARK: - Data Payload (JSON Storage)
    /// Stored as JSON Data to ensure flexibility and exact parity with Supabase JSONB
    var statsJSON: Data
    var ledgerJSON: Data
    
    // MARK: - Status
    /// Indicates if data is authoritative or missing
    var statusValue: String
    
    // MARK: - Timestamps
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        year: Int,
        month: Int,
        statsJSON: Data,
        ledgerJSON: Data,
        status: SnapshotStatus = .available,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.year = year
        self.month = month
        self.compositeKey = String(format: "%04d-%02d", year, month)
        self.statsJSON = statsJSON
        self.ledgerJSON = ledgerJSON
        self.statusValue = status.rawValue
        self.createdAt = createdAt
    }
    
    var status: SnapshotStatus {
        get { SnapshotStatus(rawValue: statusValue) ?? .missingData }
        set { statusValue = newValue.rawValue }
    }
}

enum SnapshotStatus: String, Codable {
    case available
    case missingData // Explicitly records that data is corrupted/absent
}
