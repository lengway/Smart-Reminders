import Foundation

/// Use case for completing a reminder
public struct CompleteReminderUseCase {
    private let notificationService: NotificationService
    private let locationService: LocationService
    private let liveActivityService: LiveActivityService
    
    public init(
        notificationService: NotificationService,
        locationService: LocationService,
        liveActivityService: LiveActivityService
    ) {
        self.notificationService = notificationService
        self.locationService = locationService
        self.liveActivityService = liveActivityService
    }
    
    public func execute(
        reminder: Reminder,
        history: ReminderHistory
    ) async throws -> (reminder: Reminder, history: ReminderHistory) {
        var updatedReminder = reminder
        var updatedHistory = history
        
        // Update reminder status
        updatedReminder.complete()
        
        // Record completion in history
        updatedHistory.recordCompletion()
        
        // Cancel notification
        try await notificationService.cancelNotification(for: updatedReminder.id)
        
        // Stop location monitoring if applicable
        if updatedReminder.locationTrigger != nil {
            try await locationService.stopMonitoring(for: updatedReminder.id)
        }
        
        // End Live Activity if active
        try await liveActivityService.endActivity(for: updatedReminder.id)
        
        return (updatedReminder, updatedHistory)
    }
}
