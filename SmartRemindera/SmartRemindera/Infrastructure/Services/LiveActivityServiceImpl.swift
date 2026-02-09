import Foundation
import ActivityKit
import SmartRemindersCore

/// iOS implementation of LiveActivityService using ActivityKit
@available(iOS 16.2, *)
@MainActor
public class LiveActivityServiceImpl: LiveActivityService {
    private var activeActivities: [UUID: Activity<ReminderActivityAttributes>] = [:]
    private let storageKey = "liveActivityIds"
    
    public init() {
        rebuildFromSystemActivities()
    }
    
    public func isActivitySupported() -> Bool {
        let info = ActivityAuthorizationInfo()
        return info.areActivitiesEnabled
    }
    
    public func startActivity(for reminder: Reminder) async throws {
        guard isActivitySupported() else {
            throw ActivityError.notSupported
        }
        
        // Don't start if already active
        guard activeActivities[reminder.id] == nil else { return }
        
        let attributes = ReminderActivityAttributes(
            reminderId: reminder.id.uuidString,
            title: reminder.title
        )
        
        let contentState = ReminderActivityAttributes.ContentState(
            scheduledDate: reminder.scheduledDate ?? Date(),
            escalationLevel: reminder.escalationLevel,
            status: reminder.status.displayName,
            notes: reminder.notes,
            priorityRaw: reminder.priority.rawValue,
            locationName: reminder.locationTrigger?.locationName
        )
        let content = ActivityContent(state: contentState, staleDate: nil)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil // simplify: no push capability needed
            )
            
            activeActivities[reminder.id] = activity
            persistActiveIds()
        } catch {
            print("LiveActivity start error: \(error)")
            throw ActivityError.failedToStart(error)
        }
    }
    
    public func updateActivity(for reminder: Reminder) async throws {
        guard let activity = activeActivities[reminder.id] else {
            // If not active, start it
            try await startActivity(for: reminder)
            return
        }
        
        let contentState = ReminderActivityAttributes.ContentState(
            scheduledDate: reminder.scheduledDate ?? Date(),
            escalationLevel: reminder.escalationLevel,
            status: reminder.status.displayName,
            notes: reminder.notes,
            priorityRaw: reminder.priority.rawValue,
            locationName: reminder.locationTrigger?.locationName
        )
        let content = ActivityContent(state: contentState, staleDate: nil)
        await activity.update(content)
    }
    
    public func endActivity(for reminderId: UUID) async throws {
        guard let activity = activeActivities[reminderId] else { return }
        let finalContent = ActivityContent(state: activity.contentState, staleDate: nil)
        if #available(iOS 16.2, *) {
            await activity.end(finalContent, dismissalPolicy: .immediate)
        } else {
            await activity.end(dismissalPolicy: .immediate)
        }
        activeActivities.removeValue(forKey: reminderId)
        persistActiveIds()
    }
    
    enum ActivityError: LocalizedError {
        case notSupported
        case failedToStart(Error)
        case notFound
        
        var errorDescription: String? {
            switch self {
            case .notSupported:
                return "Live Activities недоступны: включите разрешение на Live Activities и установите виджет"
            case .failedToStart(let error):
                return "Не удалось запустить Live Activity: \(error.localizedDescription)"
            case .notFound:
                return "Live Activity not found"
            }
        }
    }
    
    // MARK: - Persistence helpers
    
    private func persistActiveIds() {
        let ids = activeActivities.keys.map { $0.uuidString }
        UserDefaults.standard.set(ids, forKey: storageKey)
    }
    
    private func rebuildFromSystemActivities() {
        let activities = Activity<ReminderActivityAttributes>.activities
        for activity in activities {
            if let reminderId = UUID(uuidString: activity.attributes.reminderId) {
                activeActivities[reminderId] = activity
            }
        }
        persistActiveIds()
    }
}
