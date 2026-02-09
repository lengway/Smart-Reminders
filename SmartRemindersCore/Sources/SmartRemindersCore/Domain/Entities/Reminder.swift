import Foundation

/// Represents a smart reminder with time-based and location-based triggers
public struct Reminder: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var notes: String?
    
    // Time-based trigger
    public var scheduledDate: Date?
    
    // Location-based trigger
    public var locationTrigger: LocationTrigger?
    
    // Priority and status
    public var priority: Priority
    public var status: Status
    public var escalationLevel: Int
    
    // Metadata
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        scheduledDate: Date? = nil,
        locationTrigger: LocationTrigger? = nil,
        priority: Priority = .medium,
        status: Status = .created,
        escalationLevel: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.scheduledDate = scheduledDate
        self.locationTrigger = locationTrigger
        self.priority = priority
        self.status = status
        self.escalationLevel = escalationLevel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Nested Types

extension Reminder {
    public enum Priority: String, Codable, CaseIterable {
        case low
        case medium
        case high
        case critical
        
        public var displayName: String {
            rawValue.capitalized
        }
    }
    
    public enum Status: String, Codable {
        case created
        case scheduled
        case active
        case completed
        case snoozed
        case ignored
        
        public var displayName: String {
            rawValue.capitalized
        }
    }
    
    public struct LocationTrigger: Codable, Equatable {
        public let latitude: Double
        public let longitude: Double
        public let radius: Double // in meters
        public let triggerType: TriggerType
        public let locationName: String?
        
        public enum TriggerType: String, Codable {
            case enter
            case exit
            case both
        }
        
        public init(
            latitude: Double,
            longitude: Double,
            radius: Double = 100,
            triggerType: TriggerType = .enter,
            locationName: String? = nil
        ) {
            self.latitude = latitude
            self.longitude = longitude
            self.radius = radius
            self.triggerType = triggerType
            self.locationName = locationName
        }
    }
}

// MARK: - Helper Methods

extension Reminder {
    public var isActive: Bool {
        status == .active
    }
    
    public var isCompleted: Bool {
        status == .completed
    }
    
    public var hasPassed: Bool {
        guard let scheduledDate = scheduledDate else { return false }
        return scheduledDate < Date()
    }
    
    public mutating func activate() {
        status = .active
        updatedAt = Date()
    }
    
    public mutating func complete() {
        status = .completed
        updatedAt = Date()
    }
    
    public mutating func snooze() {
        status = .snoozed
        updatedAt = Date()
    }
    
    public mutating func ignore() {
        status = .ignored
        updatedAt = Date()
    }
    
    public mutating func escalate() {
        escalationLevel += 1
        updatedAt = Date()
    }
}
