import Foundation
import SwiftUI
import Combine
import SmartRemindersCore

/// ViewModel for the reminder list screen
@MainActor
public class ReminderListViewModel: ObservableObject {
    @Published public var reminders: [Reminder] = []
    @Published public var filteredStatus: Reminder.Status?
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let coordinator: ReminderCoordinator
    
    public init(coordinator: ReminderCoordinator) {
        self.coordinator = coordinator
        
        // Observe coordinator changes
        coordinator.$reminders
            .assign(to: &$reminders)
    }
    
    public var displayedReminders: [Reminder] {
        if let status = filteredStatus {
            return reminders.filter { $0.status == status }
        }
        return reminders.filter { $0.status != .completed }
    }
    
    public func deleteReminder(_ reminder: Reminder) {
        Task {
            do {
                try await coordinator.deleteReminder(id: reminder.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    public func activateReminder(_ reminder: Reminder) {
        Task {
            do {
                try await coordinator.activateReminder(id: reminder.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
