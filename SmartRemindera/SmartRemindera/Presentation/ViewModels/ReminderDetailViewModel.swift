import Foundation
import SwiftUI
import Combine
import SmartRemindersCore

/// ViewModel for reminder detail screen
@MainActor
public class ReminderDetailViewModel: ObservableObject {
    @Published public var reminder: Reminder
    @Published public var history: ReminderHistory?
    @Published public var decision: ReminderDecision?
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let coordinator: ReminderCoordinator
    
    public init(reminder: Reminder, coordinator: ReminderCoordinator) {
        self.reminder = reminder
        self.coordinator = coordinator
        
        Task {
            await loadHistory()
            await evaluateReminder()
        }
    }
    
    public func loadHistory() async {
        do {
            history = try await coordinator.getHistory(for: reminder.id)
        } catch {
            errorMessage = "Failed to load history: \(error.localizedDescription)"
        }
    }
    
    public func evaluateReminder() async {
        do {
            decision = try await coordinator.evaluateReminder(id: reminder.id)
        } catch {
            errorMessage = "Failed to evaluate reminder: \(error.localizedDescription)"
        }
    }
    
    public func snooze() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await coordinator.snoozeReminder(id: reminder.id)
            decision = coordinator.lastDecision
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func complete() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await coordinator.completeReminder(id: reminder.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func pinToLiveActivity() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await coordinator.activateReminder(id: reminder.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
