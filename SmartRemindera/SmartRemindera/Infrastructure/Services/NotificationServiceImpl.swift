import Foundation
import UserNotifications
import SmartRemindersCore

/// iOS implementation of NotificationService using UNUserNotificationCenter
@MainActor
public class NotificationServiceImpl: NSObject, NotificationService {
    private let center = UNUserNotificationCenter.current()
    private enum ActionID {
        static let complete = "COMPLETE_ACTION"
        static let snooze = "SNOOZE_ACTION"
        static let category = "REMINDER_CATEGORY"
    }
    
    public override init() {
        super.init()
        center.delegate = self
        setupNotificationCategories()
    }
    
    public func requestPermissions() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
        let granted = try await center.requestAuthorization(options: options)
        guard granted else { throw NotificationError.permissionDenied }
        return granted
    }
    
    public func scheduleNotification(for reminder: Reminder) async throws {
        let content = createNotificationContent(for: reminder)
        
        guard let trigger = createTrigger(for: reminder) else {
            throw NotificationError.invalidTrigger
        }
        
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        try await center.add(request)
    }
    
    public func cancelNotification(for reminderId: UUID) async throws {
        center.removePendingNotificationRequests(withIdentifiers: [reminderId.uuidString])
        center.removeDeliveredNotifications(withIdentifiers: [reminderId.uuidString])
    }
    
    public func updateNotification(for reminder: Reminder) async throws {
        try await cancelNotification(for: reminder.id)
        try await scheduleNotification(for: reminder)
    }
    
    // MARK: - Private Helpers
    
    private func createNotificationContent(for reminder: Reminder) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        
        if let notes = reminder.notes {
            content.body = notes
        }
        
        // Apply escalation
        switch reminder.escalationLevel {
        case 0:
            content.sound = .default
        case 4: // High
            content.sound = .defaultCritical
        case 5: // Critical
            content.sound = .defaultCritical
            content.interruptionLevel = .timeSensitive
        default:
            content.sound = .defaultCritical
            content.interruptionLevel = .critical
        }
        
        // Add category for actions
        content.categoryIdentifier = ActionID.category
        
        // Add user info for handling
        content.userInfo = [
            "reminderId": reminder.id.uuidString,
            "escalationLevel": reminder.escalationLevel
        ]
        
        return content
    }
    
    private func createTrigger(for reminder: Reminder) -> UNNotificationTrigger? {
        guard let scheduledDate = reminder.scheduledDate else {
            return nil
        }
        
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: scheduledDate
        )
        
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
    
    private func setupNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: ActionID.complete,
            title: "Done",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: ActionID.snooze,
            title: "Snooze",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: ActionID.category,
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        center.setNotificationCategories([category])
    }
    
    enum NotificationError: LocalizedError {
        case invalidTrigger
        case permissionDenied
        
        var errorDescription: String? {
            switch self {
            case .invalidTrigger:
                return "Could not create notification trigger"
            case .permissionDenied:
                return "Notification permission denied"
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationServiceImpl: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard let reminderIdString = response.notification.request.content.userInfo["reminderId"] as? String,
              let reminderId = UUID(uuidString: reminderIdString) else {
            completionHandler()
            return
        }

        Task { @MainActor in
            switch response.actionIdentifier {
            case ActionID.complete:
                try? await ReminderCoordinator.shared?.completeReminder(id: reminderId)
            case ActionID.snooze:
                try? await ReminderCoordinator.shared?.snoozeReminder(id: reminderId)
            default:
                break
            }
            completionHandler()
        }
    }
}
