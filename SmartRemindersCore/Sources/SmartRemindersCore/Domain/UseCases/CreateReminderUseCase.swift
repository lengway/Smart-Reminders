import Foundation

/// Use case for creating a new reminder
public struct CreateReminderUseCase {
    private let notificationService: NotificationService
    private let locationService: LocationService
    
    public init(
        notificationService: NotificationService,
        locationService: LocationService
    ) {
        self.notificationService = notificationService
        self.locationService = locationService
    }
    
    public func execute(
        title: String,
        notes: String? = nil,
        scheduledDate: Date? = nil,
        locationTrigger: Reminder.LocationTrigger? = nil,
        priority: Reminder.Priority = .medium
    ) async throws -> Reminder {
        // Validate input
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyTitle
        }
        
        if let scheduledDate = scheduledDate, scheduledDate < Date() {
            throw ValidationError.invalidDate
        }
        
        if let location = locationTrigger {
            guard (-90...90).contains(location.latitude), (-180...180).contains(location.longitude), location.radius > 0 else {
                throw ValidationError.invalidLocation
            }
        }
        
        // Create reminder
        var reminder = Reminder(
            title: title,
            notes: notes,
            scheduledDate: scheduledDate,
            locationTrigger: locationTrigger,
            priority: priority,
            status: .created
        )
        
        // Schedule notification if time-based
        if scheduledDate != nil {
            try await notificationService.scheduleNotification(for: reminder)
            reminder.status = .scheduled
        }
        
        // Setup geofencing if location-based
        if let trigger = locationTrigger {
            try await locationService.startMonitoring(trigger: trigger, for: reminder.id)
            reminder.status = .scheduled
        }
        
        return reminder
    }
    
    public enum ValidationError: LocalizedError {
        case emptyTitle
        case invalidDate
        case invalidLocation
        
        public var errorDescription: String? {
            switch self {
            case .emptyTitle:
                return "Reminder title cannot be empty"
            case .invalidDate:
                return "Scheduled date must be in the future"
            case .invalidLocation:
                return "Invalid location coordinates"
            }
        }
    }
}
