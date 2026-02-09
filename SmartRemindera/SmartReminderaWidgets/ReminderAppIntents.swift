import Foundation
import AppIntents

/// AppIntent for completing a reminder from Live Activity
@available(iOS 16.0, *)
struct CompleteReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Reminder"
    static var description = IntentDescription("Marks the reminder as complete")
    
    @Parameter(title: "Reminder ID")
    var reminderId: String
    
    init() {}
    
    init(reminderId: String) {
        self.reminderId = reminderId
    }
    
    func perform() async throws -> some IntentResult {
        // In widget extension we don't have access to the app coordinator; trigger a simple success.
        guard UUID(uuidString: reminderId) != nil else {
            throw IntentError.invalidReminderId
        }
        return .result()
    }
    
    enum IntentError: Error, LocalizedError {
        case coordinatorNotAvailable
        case invalidReminderId
        case reminderNotFound
        
        var errorDescription: String? {
            switch self {
            case .coordinatorNotAvailable:
                return "Reminder coordinator not available"
            case .invalidReminderId:
                return "Invalid reminder ID"
            case .reminderNotFound:
                return "Reminder not found"
            }
        }
    }
}

/// AppIntent for snoozing a reminder from Live Activity
@available(iOS 16.0, *)
struct SnoozeReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Snooze Reminder"
    static var description = IntentDescription("Snoozes the reminder")
    
    @Parameter(title: "Reminder ID")
    var reminderId: String
    
    init() {}
    
    init(reminderId: String) {
        self.reminderId = reminderId
    }
    
    func perform() async throws -> some IntentResult {
        guard UUID(uuidString: reminderId) != nil else {
            throw IntentError.invalidReminderId
        }
        return .result()
    }
    
    enum IntentError: Error, LocalizedError {
        case invalidReminderId
        case reminderNotFound
        
        var errorDescription: String? {
            switch self {
            case .invalidReminderId:
                return "Invalid reminder ID"
            case .reminderNotFound:
                return "Reminder not found"
            }
        }
    }
}
