import Foundation
import ActivityKit

/// Attributes for the Reminder Live Activity
@available(iOS 16.1, *)
public struct ReminderActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let scheduledDate: Date
        public let escalationLevel: Int
        public let status: String
        public let notes: String?
        public let priorityRaw: String
        public let locationName: String?
        
        public init(
            scheduledDate: Date,
            escalationLevel: Int,
            status: String,
            notes: String?,
            priorityRaw: String,
            locationName: String?
        ) {
            self.scheduledDate = scheduledDate
            self.escalationLevel = escalationLevel
            self.status = status
            self.notes = notes
            self.priorityRaw = priorityRaw
            self.locationName = locationName
        }
    }
    
    public let reminderId: String
    public let title: String
    
    public init(reminderId: String, title: String) {
        self.reminderId = reminderId
        self.title = title
    }
}
