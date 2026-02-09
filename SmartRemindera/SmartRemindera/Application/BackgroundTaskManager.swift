import Foundation
import BackgroundTasks
import SmartRemindersCore

/// Manages background refresh to keep reminders and notifications up to date
@MainActor
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    private let refreshTaskIdentifier = "com.smartreminders.refresh"
    private var coordinator: ReminderCoordinator?
    private var notificationService: NotificationService?
    
    private init() {}
    
    func configure(coordinator: ReminderCoordinator, notificationService: NotificationService) {
        self.coordinator = coordinator
        self.notificationService = notificationService
        registerBackgroundTasks()
        scheduleAppRefresh()
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskIdentifier, using: nil) { [weak self] task in
            self?.handleRefresh(task: task as? BGAppRefreshTask)
        }
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule BG refresh: \(error)")
        }
    }
    
    private func handleRefresh(task: BGAppRefreshTask?) {
        guard let task else { return }
        scheduleAppRefresh() // reschedule next
        
        task.expirationHandler = { [weak task] in
            task?.setTaskCompleted(success: false)
        }
        
        Task { @MainActor in
            do {
                try await refreshNotifications()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func refreshNotifications() async throws {
        guard let coordinator, let notificationService else { return }
        let reminders = coordinator.reminders
        for reminder in reminders where reminder.status == .scheduled {
            try await notificationService.updateNotification(for: reminder)
        }
    }
}
