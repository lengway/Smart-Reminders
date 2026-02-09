import Foundation
import SwiftUI
import Combine
import SmartRemindersCore

/// ViewModel for active reminder screen
@MainActor
public class ActiveReminderViewModel: ObservableObject {
    @Published public var activeReminder: Reminder?
    @Published public var timeRemaining: String = ""
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var nextScheduled: Reminder?
    
    let coordinator: ReminderCoordinator
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    
    public init(coordinator: ReminderCoordinator) {
        self.coordinator = coordinator
        
        coordinator.$activeReminder
            .assign(to: &$activeReminder)
        coordinator.$reminders
            .sink { [weak self] reminders in
                self?.updateNextScheduled(from: reminders)
            }
            .store(in: &cancellables)
        
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateTimeRemaining()
            }
        }
    }

    private func updateNextScheduled(from reminders: [Reminder]) {
        nextScheduled = reminders
            .filter { $0.status == .scheduled && $0.scheduledDate != nil }
            .sorted { ($0.scheduledDate ?? .distantFuture) < ($1.scheduledDate ?? .distantFuture) }
            .first
    }
    
    private func updateTimeRemaining() {
        guard let reminder = activeReminder,
              let scheduledDate = reminder.scheduledDate else {
            timeRemaining = ""
            return
        }
        
        let interval = scheduledDate.timeIntervalSinceNow
        
        if interval < 0 {
            timeRemaining = "Now"
        } else {
            let minutes = Int(interval / 60)
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            
            if hours > 0 {
                timeRemaining = "\(hours)h \(remainingMinutes)m"
            } else {
                timeRemaining = "\(minutes)m"
            }
        }
    }
    
    public func snooze() async {
        guard let reminder = activeReminder else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await coordinator.snoozeReminder(id: reminder.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func complete() async {
        guard let reminder = activeReminder else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await coordinator.completeReminder(id: reminder.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func activateNextScheduled() async {
        guard let next = nextScheduled else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await coordinator.activateReminder(id: next.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
