import Foundation

/// Protocol for Live Activity service operations
public protocol LiveActivityService {
    /// Starts a Live Activity for a reminder
    func startActivity(for reminder: Reminder) async throws
    
    /// Updates an active Live Activity
    func updateActivity(for reminder: Reminder) async throws
    
    /// Ends a Live Activity
    func endActivity(for reminderId: UUID) async throws
    
    /// Checks if Live Activities are supported and enabled
    func isActivitySupported() -> Bool
}
