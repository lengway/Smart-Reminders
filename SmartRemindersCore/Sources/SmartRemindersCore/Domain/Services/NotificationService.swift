import Foundation

/// Protocol for notification service operations
public protocol NotificationService {
    /// Schedules a notification for a reminder
    func scheduleNotification(for reminder: Reminder) async throws
    
    /// Cancels a scheduled notification
    func cancelNotification(for reminderId: UUID) async throws
    
    /// Updates an existing notification
    func updateNotification(for reminder: Reminder) async throws
    
    /// Requests notification permissions
    func requestPermissions() async throws -> Bool
}
