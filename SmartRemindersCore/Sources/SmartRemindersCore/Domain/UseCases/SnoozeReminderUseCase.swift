import Foundation

/// Use case for snoozing a reminder
public struct SnoozeReminderUseCase {
    private let rulesEngine: ReminderRulesEngine
    private let notificationService: NotificationService
    
    public init(
        rulesEngine: ReminderRulesEngine,
        notificationService: NotificationService
    ) {
        self.rulesEngine = rulesEngine
        self.notificationService = notificationService
    }
    
    public func execute(
        reminder: Reminder,
        history: ReminderHistory
    ) async throws -> (reminder: Reminder, history: ReminderHistory, decision: ReminderDecision) {
        var updatedReminder = reminder
        var updatedHistory = history
        
        // Update reminder status
        updatedReminder.snooze()
        
        // Record snooze in history
        updatedHistory.recordSnooze()
        
        // Evaluate rules to determine snooze duration and escalation
        let decision = rulesEngine.evaluate(reminder: updatedReminder, history: updatedHistory)
        
        // Apply decision
        if let nextDate = decision.nextTriggerDate {
            updatedReminder.scheduledDate = nextDate
        }
        
        if decision.escalationLevel > updatedReminder.escalationLevel {
            updatedReminder.escalationLevel = decision.escalationLevel
        }
        
        // Reschedule notification
        updatedReminder.status = .scheduled
        try await notificationService.updateNotification(for: updatedReminder)
        
        return (updatedReminder, updatedHistory, decision)
    }
}
