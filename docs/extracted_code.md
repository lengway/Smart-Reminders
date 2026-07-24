```swift
import SwiftUI
import SmartRemindersCore
import BackgroundTasks

@main
struct SmartReminderaApp: App {
    @StateObject private var container = DependencyContainer()
    
    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
                .task {
                    await requestPermissions()
                    BackgroundTaskManager.shared.configure(
                        coordinator: container.coordinator,
                        notificationService: container.notificationService
                    )
                }
        }
    }
    
    private func requestPermissions() async {
        _ = try? await container.notificationService.requestPermissions()
        _ = try? await container.locationService.requestPermissions()
        _ = await container.repository.validateStore()
    }
}
```

```swift
import SwiftUI

struct ContentView: View {
    let container: DependencyContainer
    @StateObject private var permissionsVM = PermissionsViewModel()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("dailyGoal") private var dailyGoal = 3
    @State private var showOnboarding = false
    
    var body: some View {
        VStack(spacing: 0) {
            if permissionsVM.needsAttention {
                PermissionsBannerView(viewModel: permissionsVM)
            }
            TabView {
                ReminderListView(
                    coordinator: container.coordinator,
                    locationService: container.locationService
                )
                .tabItem {
                    Label("Reminders", systemImage: "list.bullet")
                }
                
                ActiveReminderView(coordinator: container.coordinator, locationService: container.locationService)
                    .tabItem {
                        Label("Active", systemImage: "bell.fill")
                    }
                
                StatsView(coordinator: container.coordinator)
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar.fill")
                    }
            }
        }
        .task {
            await permissionsVM.refresh()
            showOnboarding = !hasSeenOnboarding
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(dailyGoal: $dailyGoal) {
                hasSeenOnboarding = true
                showOnboarding = false
            }
        }
    }
}
```

```swift
import Foundation
import os.log

@MainActor
final class Telemetry {
    static let shared = Telemetry()
    private let logger = Logger(subsystem: "com.smartreminders", category: "telemetry")
    private init() {}
    
    func log(event: String, properties: [String: Any] = [:]) {
        let props = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        logger.info("event=\(event) props=\(props)")
    }
}
```

```swift
import Foundation
import Combine
import SmartRemindersCore

@MainActor
public class ReminderCoordinator: ObservableObject {
    public static var shared: ReminderCoordinator?
    
    private let repository: ReminderRepository
    private let createUseCase: CreateReminderUseCase
    private let snoozeUseCase: SnoozeReminderUseCase
    private let completeUseCase: CompleteReminderUseCase
    private let evaluateUseCase: EvaluateReminderUseCase
    private let liveActivityService: LiveActivityService
    private let locationService: LocationService
    private let telemetry: Telemetry
    
    @Published public private(set) var reminders: [Reminder] = []
    @Published public private(set) var activeReminder: Reminder?
    @Published public private(set) var lastDecision: ReminderDecision?
    
    init(
        repository: ReminderRepository,
        createUseCase: CreateReminderUseCase,
        snoozeUseCase: SnoozeReminderUseCase,
        completeUseCase: CompleteReminderUseCase,
        evaluateUseCase: EvaluateReminderUseCase,
        liveActivityService: LiveActivityService,
        locationService: LocationService,
        telemetry: Telemetry
    ) {
        self.repository = repository
        self.createUseCase = createUseCase
        self.snoozeUseCase = snoozeUseCase
        self.completeUseCase = completeUseCase
        self.evaluateUseCase = evaluateUseCase
        self.liveActivityService = liveActivityService
        self.locationService = locationService
        self.telemetry = telemetry
        
        Self.shared = self
        
        Task {
            await loadReminders()
            setupLocationTriggerCallback()
        }
    }
    
    public func createReminder(
        title: String,
        notes: String? = nil,
        scheduledDate: Date? = nil,
        locationTrigger: Reminder.LocationTrigger? = nil,
        priority: Reminder.Priority = .medium
    ) async throws {
        let reminder = try await createUseCase.execute(
            title: title,
            notes: notes,
            scheduledDate: scheduledDate,
            locationTrigger: locationTrigger,
            priority: priority
        )
        
        try await repository.saveReminder(reminder)
        await loadReminders()
        telemetry.log(event: "create", properties: ["id": reminder.id.uuidString, "priority": reminder.priority.rawValue])
    }
    
    public func snoozeReminder(id: UUID) async throws {
        guard let reminder = try await repository.fetchReminder(id: id) else {
            throw CoordinatorError.reminderNotFound
        }
        
        let history = try await repository.fetchHistory(for: id)
        
        let result = try await snoozeUseCase.execute(reminder: reminder, history: history)
        
        try await repository.saveReminder(result.reminder)
        try await repository.saveHistory(result.history)
        
        lastDecision = result.decision
        
        await loadReminders()
        
        if result.reminder.isActive {
            try await liveActivityService.updateActivity(for: result.reminder)
        }
        telemetry.log(event: "snooze", properties: ["id": reminder.id.uuidString, "escalation": result.reminder.escalationLevel])
    }
    
    public func completeReminder(id: UUID) async throws {
        guard let reminder = try await repository.fetchReminder(id: id) else {
            throw CoordinatorError.reminderNotFound
        }
        
        let history = try await repository.fetchHistory(for: id)
        
        let result = try await completeUseCase.execute(reminder: reminder, history: history)
        
        try await repository.saveReminder(result.reminder)
        try await repository.saveHistory(result.history)
        
        await loadReminders()
        
        if activeReminder?.id == id {
            activeReminder = nil
        }
        telemetry.log(event: "complete", properties: ["id": reminder.id.uuidString])
    }
    
    public func deleteReminder(id: UUID) async throws {
        try await repository.deleteReminder(id: id)
        await loadReminders()
    }
    
    public func activateReminder(id: UUID) async throws {
        guard var reminder = try await repository.fetchReminder(id: id) else {
            throw CoordinatorError.reminderNotFound
        }
        
        reminder.activate()
        try await repository.saveReminder(reminder)
        
        activeReminder = reminder
        
        try await liveActivityService.startActivity(for: reminder)
        
        await loadReminders()
    }
    
    public func evaluateReminder(id: UUID) async throws -> ReminderDecision {
        guard let reminder = try await repository.fetchReminder(id: id) else {
            throw CoordinatorError.reminderNotFound
        }
        
        let history = try await repository.fetchHistory(for: id)
        let decision = evaluateUseCase.execute(reminder: reminder, history: history)
        
        lastDecision = decision
        return decision
    }
    
    public func getHistory(for reminderId: UUID) async throws -> ReminderHistory {
        try await repository.fetchHistory(for: reminderId)
    }
    
    private func loadReminders() async {
        do {
            reminders = try await repository.fetchAllReminders()
            activeReminder = try await repository.fetchActiveReminder()
        } catch {
            print("Error loading reminders: \(error)")
        }
    }
    
    private func setupLocationTriggerCallback() {
        var locationService = self.locationService
        locationService.onGeofenceTriggered = { [weak self] reminderId in
            Task { @MainActor in
                try? await self?.activateReminder(id: reminderId)
            }
        }
    }
    
    public enum CoordinatorError: LocalizedError {
        case reminderNotFound
        case invalidState
        
        public var errorDescription: String? {
            switch self {
            case .reminderNotFound:
                return "Reminder not found"
            case .invalidState:
                return "Invalid reminder state"
            }
        }
    }
}
```

```swift
import Foundation
import Combine
import SmartRemindersCore

@MainActor
public class DependencyContainer: ObservableObject {
    public let notificationService: NotificationService
    public let locationService: LocationService
    public let liveActivityService: LiveActivityService
    public let repository: ReminderRepository
    public let rulesEngine: ReminderRulesEngine
    public let createReminderUseCase: CreateReminderUseCase
    public let snoozeReminderUseCase: SnoozeReminderUseCase
    public let completeReminderUseCase: CompleteReminderUseCase
    public let evaluateReminderUseCase: EvaluateReminderUseCase
    public let coordinator: ReminderCoordinator
    private let telemetry = Telemetry.shared
    
    public init() {
        self.notificationService = NotificationServiceImpl()
        self.locationService = LocationServiceImpl()
        
        if #available(iOS 16.2, *) {
            self.liveActivityService = LiveActivityServiceImpl()
        } else {
            self.liveActivityService = NoOpLiveActivityService()
        }
        
        self.repository = ReminderRepository()
        self.rulesEngine = ReminderRulesEngine()
        
        self.createReminderUseCase = CreateReminderUseCase(
            notificationService: notificationService,
            locationService: locationService
        )
        
        self.snoozeReminderUseCase = SnoozeReminderUseCase(
            rulesEngine: rulesEngine,
            notificationService: notificationService
        )
        
        self.completeReminderUseCase = CompleteReminderUseCase(
            notificationService: notificationService,
            locationService: locationService,
            liveActivityService: liveActivityService
        )
        
        self.evaluateReminderUseCase = EvaluateReminderUseCase(
            rulesEngine: rulesEngine,
            personalizationService: HeuristicPersonalizationService()
        )
        
        self.coordinator = ReminderCoordinator(
            repository: repository,
            createUseCase: createReminderUseCase,
            snoozeUseCase: snoozeReminderUseCase,
            completeUseCase: completeReminderUseCase,
            evaluateUseCase: evaluateReminderUseCase,
            liveActivityService: liveActivityService,
            locationService: locationService,
            telemetry: telemetry
        )
    }
}

@MainActor
private class NoOpLiveActivityService: LiveActivityService {
    func startActivity(for reminder: Reminder) async throws {}
    func updateActivity(for reminder: Reminder) async throws {}
    func endActivity(for reminderId: UUID) async throws {}
    func isActivitySupported() -> Bool { false }
}
```

```swift
import Foundation
import BackgroundTasks
import SmartRemindersCore

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
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule BG refresh: \(error)")
        }
    }
    
    private func handleRefresh(task: BGAppRefreshTask?) {
        guard let task else { return }
        scheduleAppRefresh()
        
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
```

```swift
import Foundation
import ActivityKit

@available(iOS 16.1, *)
public struct ReminderActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let scheduledDate: Date
        public let escalationLevel: Int
        public let status: String
        public let notes: String?
        public let priorityRaw: String
        public let locationName: String?
        
        public init(
            scheduledDate: Date,
            escalationLevel: Int,
            status: String,
            notes: String?,
            priorityRaw: String,
            locationName: String?
        ) {
            self.scheduledDate = scheduledDate
            self.escalationLevel = escalationLevel
            self.status = status
            self.notes = notes
            self.priorityRaw = priorityRaw
            self.locationName = locationName
        }
    }
    
    public let reminderId: String
    public let title: String
    
    public init(reminderId: String, title: String) {
        self.reminderId = reminderId
        self.title = title
    }
}
```

```swift
import Foundation
import UserNotifications
import SmartRemindersCore

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
    
    private func createNotificationContent(for reminder: Reminder) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        
        if let notes = reminder.notes {
            content.body = notes
        }
        
        switch reminder.escalationLevel {
        case 0:
            content.sound = .default
        case 4:
            content.sound = .defaultCritical
        case 5:
            content.sound = .defaultCritical
            content.interruptionLevel = .timeSensitive
        default:
            content.sound = .defaultCritical
            content.interruptionLevel = .critical
        }
        
        content.categoryIdentifier = ActionID.category
        
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

extension NotificationServiceImpl: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
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
```

```swift
import Foundation
import CoreLocation
import SmartRemindersCore

@MainActor
public class LocationServiceImpl: NSObject, LocationService {
    private let locationManager = CLLocationManager()
    private var monitoredRegions: [UUID: CLCircularRegion] = [:]
    private var permissionContinuation: CheckedContinuation<Bool, Never>?
    private var locationContinuations: [CheckedContinuation<(latitude: Double, longitude: Double), Error>] = []
    
    public var onGeofenceTriggered: ((UUID) -> Void)?
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    public func requestPermissions() async throws -> Bool {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
            return await withCheckedContinuation { continuation in
                permissionContinuation = continuation
            }
        default:
            return false
        }
    }
    
    public func getCurrentLocation() async throws -> (latitude: Double, longitude: Double) {
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuations.append(continuation)
            locationManager.requestLocation()
        }
    }
    
    public func startMonitoring(trigger: Reminder.LocationTrigger, for reminderId: UUID) async throws {
        let coordinate = CLLocationCoordinate2D(
            latitude: trigger.latitude,
            longitude: trigger.longitude
        )
        
        let region = CLCircularRegion(
            center: coordinate,
            radius: trigger.radius,
            identifier: reminderId.uuidString
        )
        
        switch trigger.triggerType {
        case .enter:
            region.notifyOnEntry = true
            region.notifyOnExit = false
        case .exit:
            region.notifyOnEntry = false
            region.notifyOnExit = true
        case .both:
            region.notifyOnEntry = true
            region.notifyOnExit = true
        }
        
        monitoredRegions[reminderId] = region
        locationManager.startMonitoring(for: region)
    }
    
    public func stopMonitoring(for reminderId: UUID) async throws {
        guard let region = monitoredRegions[reminderId] else { return }
        
        locationManager.stopMonitoring(for: region)
        monitoredRegions.removeValue(forKey: reminderId)
    }
    
    private func resumePermissionContinuation(granted: Bool) {
        permissionContinuation?.resume(returning: granted)
        permissionContinuation = nil
    }
    
    private func flushLocationContinuations(with result: Result<(latitude: Double, longitude: Double), Error>) {
        locationContinuations.forEach { continuation in
            switch result {
            case .success(let value):
                continuation.resume(returning: value)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
        locationContinuations.removeAll()
    }
}

extension LocationServiceImpl: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        flushLocationContinuations(with: .success((
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )))
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        flushLocationContinuations(with: .failure(error))
    }
    
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let reminderId = UUID(uuidString: region.identifier) else { return }
        onGeofenceTriggered?(reminderId)
    }
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let reminderId = UUID(uuidString: region.identifier) else { return }
        onGeofenceTriggered?(reminderId)
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            resumePermissionContinuation(granted: true)
        case .denied, .restricted:
            resumePermissionContinuation(granted: false)
        default:
            break
        }
    }
}
```

```swift
import Foundation
import ActivityKit
import SmartRemindersCore

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
                pushType: nil
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
```

```swift
import Foundation
import SmartRemindersCore

public actor ReminderRepository {
    private struct Payload: Codable {
        var version: Int
        var reminders: [Reminder]
        var histories: [ReminderHistory]
    }
    
    private let fileManager = FileManager.default
    private let filename = "reminders.json"
    private let appGroupId: String? = {
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }()
    private let backupFilename = "reminders.backup.json"
    private let userDefaults = UserDefaults.standard
    private let legacyRemindersKey = "reminders"
    private let legacyHistoriesKey = "histories"
    private let currentVersion = 1
    
    public init() {}
    
    public func saveReminder(_ reminder: Reminder) throws {
        var payload = try loadPayload()
        
        if let index = payload.reminders.firstIndex(where: { $0.id == reminder.id }) {
            payload.reminders[index] = reminder
        } else {
            payload.reminders.append(reminder)
        }
        
        try persist(payload)
    }
    
    public func fetchReminder(id: UUID) throws -> Reminder? {
        let payload = try loadPayload()
        return payload.reminders.first { $0.id == id }
    }
    
    public func fetchAllReminders() throws -> [Reminder] {
        let payload = try loadPayload()
        return payload.reminders
    }
    
    public func deleteReminder(id: UUID) throws {
        var payload = try loadPayload()
        payload.reminders.removeAll { $0.id == id }
        try persist(payload)
    }
    
    public func saveHistory(_ history: ReminderHistory) throws {
        var payload = try loadPayload()
        
        if let index = payload.histories.firstIndex(where: { $0.reminderId == history.reminderId }) {
            payload.histories[index] = history
        } else {
            payload.histories.append(history)
        }
        
        try persist(payload)
    }
    
    public func fetchHistory(for reminderId: UUID) throws -> ReminderHistory {
        let payload = try loadPayload()
        
        if let history = payload.histories.first(where: { $0.reminderId == reminderId }) {
            return history
        }
        
        return ReminderHistory(reminderId: reminderId)
    }
    
    public func fetchAllHistories() throws -> [ReminderHistory] {
        let payload = try loadPayload()
        return payload.histories
    }
    
    public func fetchReminders(by status: Reminder.Status) throws -> [Reminder] {
        let payload = try loadPayload()
        return payload.reminders.filter { $0.status == status }
    }
    
    public func fetchActiveReminder() throws -> Reminder? {
        let payload = try loadPayload()
        return payload.reminders.first { $0.status == .active }
    }
    
    public func fetchUpcomingReminders(limit: Int = 10) throws -> [Reminder] {
        let payload = try loadPayload()
        return payload.reminders
            .filter { $0.status == .scheduled && $0.scheduledDate != nil }
            .sorted { ($0.scheduledDate ?? .distantFuture) < ($1.scheduledDate ?? .distantFuture) }
            .prefix(limit)
            .map { $0 }
    }
    
    private func loadPayload() throws -> Payload {
        if let data = try? Data(contentsOf: storageURL()),
           let decoded = try? JSONDecoder().decode(Payload.self, from: data) {
            return decoded
        }
        
        if let migrated = try? migrateFromLegacy() {
            return migrated
        }
        
        return Payload(version: currentVersion, reminders: [], histories: [])
    }
    
    private func persist(_ payload: Payload) throws {
        var mutablePayload = payload
        mutablePayload.version = currentVersion
        let data = try JSONEncoder().encode(mutablePayload)
        let url = try storageURL()
        try data.write(to: url, options: [.atomic])
        try? data.write(to: url.deletingLastPathComponent().appendingPathComponent(backupFilename), options: [.atomic])
    }
    
    private func storageURL() throws -> URL {
        if let appGroupId, !appGroupId.isEmpty,
           let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            return container.appendingPathComponent(filename)
        }
        
        let docs = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return docs.appendingPathComponent(filename)
    }
    
    private func migrateFromLegacy() throws -> Payload {
        let remindersData = userDefaults.data(forKey: legacyRemindersKey)
        let historiesData = userDefaults.data(forKey: legacyHistoriesKey)
        
        let reminders = (try? remindersData.flatMap { try JSONDecoder().decode([Reminder].self, from: $0) }) ?? []
        let histories = (try? historiesData.flatMap { try JSONDecoder().decode([ReminderHistory].self, from: $0) }) ?? []
        
        let payload = Payload(version: currentVersion, reminders: reminders, histories: histories)
        try persist(payload)
        
        userDefaults.removeObject(forKey: legacyRemindersKey)
        userDefaults.removeObject(forKey: legacyHistoriesKey)
        
        return payload
    }

    public func validateStore() async -> Bool {
        do {
            _ = try loadPayload()
            return true
        } catch {
            if let backup = try? Data(contentsOf: try storageURL().deletingLastPathComponent().appendingPathComponent(backupFilename)),
               let decoded = try? JSONDecoder().decode(Payload.self, from: backup) {
                try? persist(decoded)
                return true
            }
            return false
        }
    }
}
```

```swift
import SwiftUI
import Charts
import SmartRemindersCore

struct StatsView: View {
    @StateObject private var viewModel: StatsViewModel
    
    init(coordinator: ReminderCoordinator) {
        _viewModel = StateObject(wrappedValue: StatsViewModel(coordinator: coordinator))
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    StatRow(
                        title: "Total Reminders",
                        value: "\(viewModel.totalReminders)",
                        icon: "bell.fill",
                        color: .blue
                    )
                    
                    StatRow(
                        title: "Completed",
                        value: "\(viewModel.completedReminders)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    StatRow(
                        title: "Completion Rate",
                        value: viewModel.completionRatePercentage,
                        icon: "chart.line.uptrend.xyaxis",
                        color: .purple
                    )
                }
                
                Section("Behavior Patterns") {
                    StatRow(
                        title: "Total Snoozes",
                        value: "\(viewModel.totalSnoozes)",
                        icon: "clock.fill",
                        color: .orange
                    )
                    
                    StatRow(
                        title: "Avg Snoozes per Reminder",
                        value: String(format: "%.1f", viewModel.averageSnoozePerReminder),
                        icon: "chart.bar.fill",
                        color: .orange
                    )
                }
                
                if let avgHour = viewModel.averageCompletionHour {
                    Section("Productivity Insights") {
                        StatRow(
                            title: "Average Completion Time",
                            value: "\(avgHour):00",
                            icon: "clock.badge.checkmark",
                            color: .blue
                        )
                        
                        if let mostProductiveHour = viewModel.mostProductiveHour {
                            StatRow(
                                title: "Most Productive Hour",
                                value: "\(mostProductiveHour):00",
                                icon: "star.fill",
                                color: .yellow
                            )
                        }
                    }
                }
                
                Section {
                    Button {
                        Task {
                            await viewModel.calculateStats()
                        }
                    } label: {
                        Label("Refresh Stats", systemImage: "arrow.clockwise")
                    }
                }
            }
            .navigationTitle("Statistics")
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
```

```swift
import SwiftUI
import SmartRemindersCore

struct ReminderListView: View {
    @StateObject private var viewModel: ReminderListViewModel
    @State private var showingCreateSheet = false
    @State private var selectedReminder: Reminder?
    
    private let coordinator: ReminderCoordinator
    private let locationService: LocationService
    
    init(coordinator: ReminderCoordinator, locationService: LocationService) {
        self.coordinator = coordinator
        self.locationService = locationService
        _viewModel = StateObject(wrappedValue: ReminderListViewModel(coordinator: coordinator))
    }
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.displayedReminders.isEmpty {
                    ContentUnavailableView(
                        "No Reminders",
                        systemImage: "bell.slash",
                        description: Text("Tap + to create your first reminder")
                    )
                } else {
                    ForEach(viewModel.displayedReminders) { reminder in
                        ReminderRow(reminder: reminder)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedReminder = reminder
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteReminder(reminder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if reminder.status == .scheduled {
                                    Button {
                                        viewModel.activateReminder(reminder)
                                    } label: {
                                        Label("Activate", systemImage: "play.fill")
                                    }
                                    .tint(.green)
                                }
                            }
                    }
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All") {
                            viewModel.filteredStatus = nil
                        }
                        Button("Scheduled") {
                            viewModel.filteredStatus = .scheduled
                        }
                        Button("Active") {
                            viewModel.filteredStatus = .active
                        }
                        Button("Completed") {
                            viewModel.filteredStatus = .completed
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateReminderView(coordinator: coordinator, locationService: locationService)
            }
            .sheet(item: $selectedReminder) { reminder in
                NavigationStack {
                    ReminderDetailView(reminder: reminder, coordinator: coordinator)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}

struct ReminderRow: View {
    let reminder: Reminder
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.headline)
                
                if let scheduledDate = reminder.scheduledDate {
                    Text(scheduledDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let locationTrigger = reminder.locationTrigger {
                    Label(locationTrigger.locationName ?? "Location", systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(reminder.priority.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.2))
                    .foregroundStyle(priorityColor)
                    .clipShape(Capsule())
                
                if reminder.escalationLevel > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(reminder.escalationLevel, 3), id: \.self) { _ in
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reminder.title), статус \(reminder.status.displayName), приоритет \(reminder.priority.displayName)")
    }
    
    private var statusColor: Color {
        switch reminder.status {
        case .created: return .gray
        case .scheduled: return .blue
        case .active: return .green
        case .completed: return .purple
        case .snoozed: return .orange
        case .ignored: return .red
        }
    }
    
    private var priorityColor: Color {
        switch reminder.priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}
```

```swift
import SwiftUI

struct ReminderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ReminderDetailViewModel
    
    init(reminder: Reminder, coordinator: ReminderCoordinator) {
        _viewModel = StateObject(wrappedValue: ReminderDetailViewModel(
            reminder: reminder,
            coordinator: coordinator
        ))
    }
    
    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Title", value: viewModel.reminder.title)
                
                if let notes = viewModel.reminder.notes {
                    LabeledContent("Notes") {
                        Text(notes)
                            .foregroundStyle(.secondary)
                    }
                }
                
                LabeledContent("Status", value: viewModel.reminder.status.displayName)
                LabeledContent("Priority", value: viewModel.reminder.priority.displayName)
                
                if viewModel.reminder.escalationLevel > 0 {
                    LabeledContent("Escalation Level", value: "\(viewModel.reminder.escalationLevel)")
                }
            }
            
            Section("Triggers") {
                if let scheduledDate = viewModel.reminder.scheduledDate {
                    LabeledContent("Scheduled") {
                        VStack(alignment: .trailing) {
                            Text(scheduledDate, style: .date)
                            Text(scheduledDate, style: .time)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                if let location = viewModel.reminder.locationTrigger {
                    LabeledContent("Location") {
                        VStack(alignment: .trailing, spacing: 4) {
                            if let name = location.locationName {
                                Text(name)
                            }
                            Text("Lat: \(location.latitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Lon: \(location.longitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Radius: \(Int(location.radius))m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            if let decision = viewModel.decision {
                Section("Why This Behavior?") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Rules Engine Analysis", systemImage: "brain")
                            .font(.headline)
                        
                        Text(decision.explanation)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        if let nextDate = decision.nextTriggerDate {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Next trigger: \(nextDate, style: .relative)")
                            }
                            .font(.caption)
                            .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            if let history = viewModel.history {
                Section("History") {
                    LabeledContent("Snooze Count", value: "\(history.snoozeCount)")
                    LabeledContent("Completion Count", value: "\(history.completionCount)")
                    LabeledContent("Ignore Count", value: "\(history.ignoreCount)")
                    
                    if let avgHour = history.averageCompletionHour {
                        LabeledContent("Avg Completion Time", value: "\(avgHour):00")
                    }
                    
                    if history.completionRate > 0 {
                        LabeledContent("Completion Rate") {
                            Text("\(Int(history.completionRate * 100))%")
                        }
                    }
                }
            }
            
            if viewModel.reminder.status != .completed {
                Section {
                    if viewModel.reminder.status != .active {
                        Button {
                            Task { await viewModel.pinToLiveActivity() }
                        } label: {
                            Label("Pin to Live Activity", systemImage: "pin.fill")
                        }
                        .disabled(viewModel.isLoading)
                    }
                    Button {
                        Task {
                            await viewModel.snooze()
                        }
                    } label: {
                        Label("Snooze", systemImage: "clock.fill")
                    }
                    .disabled(viewModel.isLoading)
                    
                    Button {
                        Task {
                            await viewModel.complete()
                            dismiss()
                        }
                    } label: {
                        Label("Complete", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .navigationTitle("Reminder Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}
```

```swift
import SwiftUI
import UserNotifications
import CoreLocation

struct PermissionsBannerView: View {
    @ObservedObject var viewModel: PermissionsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Требуются разрешения для уведомлений и локации")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            HStack(spacing: 12) {
                permissionPill(title: "Уведомления", status: viewModel.notificationStatus)
                permissionPill(title: "Локация", status: viewModel.locationStatus)
                Spacer()
                Button {
                    Task { await viewModel.requestNotifications(); await viewModel.requestLocation() }
                } label: {
                    Text("Разрешить")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .disabled(viewModel.isRequesting)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding([.horizontal, .top])
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Разрешения нужны для корректной работы уведомлений и геозон")
    }
    
    private func permissionPill(title: String, status: UNAuthorizationStatus) -> some View {
        let color: Color
        switch status {
        case .authorized, .provisional, .ephemeral:
            color = .green
        case .denied:
            color = .red
        default:
            color = .gray
        }
        return Label(title, systemImage: "shield.lefthalf.fill")
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
    
    private func permissionPill(title: String, status: CLAuthorizationStatus) -> some View {
        let color: Color
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            color = .green
        case .denied, .restricted:
            color = .red
        default:
            color = .gray
        }
        return Label(title, systemImage: "location.fill")
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
```

```swift
import Foundation
import SmartRemindersCore

public struct APIClient {
    public enum APIError: Error {
        case invalidResponse
        case decodingError(Error)
        case networkError(Error)
    }

    private let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func fetchReminders(endpoint: String = "reminders") async throws -> [Reminder] {
        let url = baseURL.appendingPathComponent(endpoint)

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw APIError.invalidResponse
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let items = try decoder.decode([Reminder].self, from: data)
                return items
            } catch {
                throw APIError.decodingError(error)
            }
        } catch {
            throw APIError.networkError(error)
        }
    }

    public func uploadReminder(_ reminder: Reminder, endpoint: String = "reminders") async throws {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let body = try encoder.encode(reminder)
            let (_, response) = try await URLSession.shared.upload(for: request, from: body)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw APIError.invalidResponse
            }
        } catch let err as APIError {
            throw err
        } catch {
            throw APIError.networkError(error)
        }
    }
}
```

```swift
import SwiftUI

struct OnboardingView: View {
    @Binding var dailyGoal: Int
    let dismiss: () -> Void
    @State private var page = 0
    
    var body: some View {
        VStack {
            TabView(selection: $page) {
                OnboardingPage(
                    title: "Умные напоминания",
                    subtitle: "Приложение адаптируется под твои привычки: время, геозоны, эскалации",
                    image: "brain.head.profile"
                ).tag(0)
                OnboardingPage(
                    title: "Разреши уведомления",
                    subtitle: "Так ты получишь вовремя подсказки и Live Activities",
                    image: "bell.badge.fill"
                ).tag(1)
                OnboardingGoalPage(dailyGoal: $dailyGoal).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            
            Button {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    dismiss()
                }
            } label: {
                Text(page < 2 ? "Далее" : "Начать")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

private struct OnboardingPage: View {
    let title: String
    let subtitle: String
    let image: String
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: image)
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .padding()
    }
}

private struct OnboardingGoalPage: View {
    @Binding var dailyGoal: Int
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "target")
                .font(.system(size: 72))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Дневная цель")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Сколько напоминаний ты хочешь закрывать ежедневно?")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Stepper(value: $dailyGoal, in: 1...10) {
                Text("Цель: \(dailyGoal) в день")
            }
            .accessibilityLabel("Установить дневную цель")
            Spacer()
        }
        .padding()
    }
}
```

```swift
import SwiftUI
import MapKit
import SmartRemindersCore
import UIKit

struct CreateReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateReminderViewModel
    
    init(coordinator: ReminderCoordinator, locationService: LocationService) {
        _viewModel = StateObject(wrappedValue: CreateReminderViewModel(
            coordinator: coordinator,
            locationService: locationService
        ))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $viewModel.title)
                    TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Priority") {
                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(Reminder.Priority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Toggle("Time-based trigger", isOn: $viewModel.useTimeBasedTrigger)
                    
                    if viewModel.useTimeBasedTrigger {
                        DatePicker("Scheduled for", selection: $viewModel.scheduledDate)
                    }
                }
                
                Section {
                    Toggle("Location-based trigger", isOn: $viewModel.useLocationTrigger)
                    
                    if viewModel.useLocationTrigger {
                        TextField("Location name (optional)", text: $viewModel.locationName)
                        
                        Button("Use Current Location") {
                            Task {
                                await viewModel.getCurrentLocation()
                            }
                        }
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundStyle(.blue)
                        
                        HStack {
                            Text("Latitude")
                            Spacer()
                            Text(String(format: "%.6f", viewModel.latitude))
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Longitude")
                            Spacer()
                            Text(String(format: "%.6f", viewModel.longitude))
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Radius")
                            Spacer()
                            Text("\(Int(viewModel.radius))m")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $viewModel.radius, in: 50...500, step: 50)
                        
                        Picker("Trigger type", selection: $viewModel.triggerType) {
                            Text("Enter").tag(Reminder.LocationTrigger.TriggerType.enter)
                            Text("Exit").tag(Reminder.LocationTrigger.TriggerType.exit)
                            Text("Both").tag(Reminder.LocationTrigger.TriggerType.both)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isLoading)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}
```

```swift
import SwiftUI
import SmartRemindersCore

struct ActiveReminderView: View {
    @StateObject private var viewModel: ActiveReminderViewModel
    @State private var showingCreateSheet = false
    private let locationService: LocationService
    
    init(coordinator: ReminderCoordinator, locationService: LocationService) {
        self.locationService = locationService
        _viewModel = StateObject(wrappedValue: ActiveReminderViewModel(coordinator: coordinator))
    }
    
    var body: some View {
        NavigationStack {
            if let reminder = viewModel.activeReminder {
                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)
                            .padding(.top, 40)
                        
                        Text(reminder.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if let notes = reminder.notes {
                            Text(notes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        if !viewModel.timeRemaining.isEmpty {
                            VStack(spacing: 8) {
                                Text("Time Remaining")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Text(viewModel.timeRemaining)
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.blue)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        
                        if reminder.escalationLevel > 0 {
                            HStack(spacing: 8) {
                                ForEach(0..<min(reminder.escalationLevel, 3), id: \.self) { _ in
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.red)
                                }
                                Text("Priority Escalated")
                                    .font(.headline)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Button {
                                Task {
                                    await viewModel.complete()
                                }
                            } label: {
                                Label("Mark as Done", systemImage: "checkmark.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .accessibilityLabel("Отметить как выполнено")
                            .disabled(viewModel.isLoading)
                            
                            Button {
                                Task {
                                    await viewModel.snooze()
                                }
                            } label: {
                                Label("Snooze", systemImage: "clock.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .accessibilityLabel("Отложить напоминание")
                            .disabled(viewModel.isLoading)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
                .navigationTitle("Active Reminder")
            } else {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No Active Reminder",
                        systemImage: "bell.slash",
                        description: Text("You don't have any active reminders right now")
                    )
                    if let next = viewModel.nextScheduled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Next scheduled")
                                .font(.headline)
                            Text(next.title)
                                .font(.subheadline)
                            if let date = next.scheduledDate {
                                Text(date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(date, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button {
                                Task { await viewModel.activateNextScheduled() }
                            } label: {
                                Label("Activate next", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("Create reminder", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
                .navigationTitle("Active Reminder")
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateReminderView(coordinator: viewModel.coordinator, locationService: locationService)
        }
    }
}
```

```swift
import Foundation
import SwiftUI
import Combine
import SmartRemindersCore

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
```

```swift
import Foundation
import Combine
import UserNotifications
import CoreLocation

@MainActor
final class PermissionsViewModel: NSObject, ObservableObject {
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isRequesting = false
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    var needsAttention: Bool {
        notificationStatus == .denied || locationStatus == .denied
    }
    
    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
        locationStatus = locationManager.authorizationStatus
    }
    
    func requestNotifications() async {
        isRequesting = true
        defer { isRequesting = false }
        let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert])
        if granted == false {
            notificationStatus = .denied
        } else {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationStatus = settings.authorizationStatus
        }
    }
    
    func requestLocation() async {
        isRequesting = true
        defer { isRequesting = false }
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            locationStatus = status
        default:
            locationStatus = status
        }
    }
}

extension PermissionsViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
    }
}
```

```swift
import Foundation
import Combine
import CoreLocation
import SwiftUI
import SmartRemindersCore

@MainActor
public class CreateReminderViewModel: ObservableObject {
    @Published public var title = ""
    @Published public var notes = ""
    @Published public var scheduledDate = Date().addingTimeInterval(3600)
    @Published public var useTimeBasedTrigger = true
    @Published public var useLocationTrigger = false
    @Published public var priority: Reminder.Priority = .medium
    
    @Published public var locationName = ""
    @Published public var latitude: Double = 0
    @Published public var longitude: Double = 0
    @Published public var radius: Double = 100
    @Published public var triggerType: Reminder.LocationTrigger.TriggerType = .enter
    
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let coordinator: ReminderCoordinator
    private let locationService: LocationService
    
    public init(coordinator: ReminderCoordinator, locationService: LocationService) {
        self.coordinator = coordinator
        self.locationService = locationService
    }
    
    public var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (useTimeBasedTrigger || useLocationTrigger)
    }
    
    public func getCurrentLocation() async {
        do {
            let granted = try await locationService.requestPermissions()
            guard granted else {
                errorMessage = "Разрешите доступ к геолокации в настройках"
                return
            }
            let location = try await locationService.getCurrentLocation()
            latitude = location.latitude
            longitude = location.longitude
        } catch {
            errorMessage = "Не удалось получить локацию. Проверьте разрешения и GPS: \(error.localizedDescription)"
        }
    }
    
    public func save() async -> Bool {
        guard canSave else { return false }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let locationTrigger: Reminder.LocationTrigger? = useLocationTrigger ? 
                Reminder.LocationTrigger(
                    latitude: latitude,
                    longitude: longitude,
                    radius: radius,
                    triggerType: triggerType,
                    locationName: locationName.isEmpty ? nil : locationName
                ) : nil
            
            try await coordinator.createReminder(
                title: title,
                notes: notes.isEmpty ? nil : notes,
                scheduledDate: useTimeBasedTrigger ? scheduledDate : nil,
                locationTrigger: locationTrigger,
                priority: priority
            )
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
```

```swift
import Foundation
import Combine
import SmartRemindersCore

@MainActor
public class StatsViewModel: ObservableObject {
    @Published public var totalReminders = 0
    @Published public var completedReminders = 0
    @Published public var totalSnoozes = 0
    @Published public var completionRate: Double = 0
    @Published public var averageCompletionHour: Int?
    @Published public var mostProductiveHour: Int?
    
    private let coordinator: ReminderCoordinator
    private var cancellables: Set<AnyCancellable> = []
    
    public init(coordinator: ReminderCoordinator) {
        self.coordinator = coordinator
        
        coordinator.$reminders
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.calculateStats() }
            }
            .store(in: &cancellables)
        
        Task { await calculateStats() }
    }
    
    public func calculateStats() async {
        let reminders = coordinator.reminders
        totalReminders = reminders.count
        completedReminders = reminders.filter { $0.status == .completed }.count
        
        var allSnoozes = 0
        var allCompletionHours: [Int] = []
        
        for reminder in reminders {
            if let history = try? await coordinator.getHistory(for: reminder.id) {
                allSnoozes += history.snoozeCount
                allCompletionHours.append(contentsOf: history.executionHours)
            }
        }
        
        totalSnoozes = allSnoozes
        
        if totalReminders > 0 {
            completionRate = Double(completedReminders) / Double(totalReminders)
        }
        
        if !allCompletionHours.isEmpty {
            let sum = allCompletionHours.reduce(0, +)
            averageCompletionHour = sum / allCompletionHours.count
            
            let hourCounts = Dictionary(grouping: allCompletionHours, by: { $0 })
                .mapValues { $0.count }
            mostProductiveHour = hourCounts.max(by: { $0.value < $1.value })?.key
        }
    }
    
    public var completionRatePercentage: String {
        String(format: "%.0f%%", completionRate * 100)
    }
    
    public var averageSnoozePerReminder: Double {
        guard completedReminders > 0 else { return 0 }
        return Double(totalSnoozes) / Double(completedReminders)
    }
}
```

```swift
import Foundation
import SwiftUI
import Combine
import SmartRemindersCore

@MainActor
public class ReminderListViewModel: ObservableObject {
    @Published public var reminders: [Reminder] = []
    @Published public var filteredStatus: Reminder.Status?
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let coordinator: ReminderCoordinator
    
    public init(coordinator: ReminderCoordinator) {
        self.coordinator = coordinator
        
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
```

```swift
import Foundation

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
        
        updatedReminder.complete()
        
        updatedHistory.recordCompletion()
        
        try await notificationService.cancelNotification(for: updatedReminder.id)
        
        if updatedReminder.locationTrigger != nil {
            try await locationService.stopMonitoring(for: updatedReminder.id)
        }
        
        try await liveActivityService.endActivity(for: updatedReminder.id)
        
        return (updatedReminder, updatedHistory)
    }
}
```

```swift
import Foundation

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
        
        updatedReminder.snooze()
        
        updatedHistory.recordSnooze()
        
        let decision = rulesEngine.evaluate(reminder: updatedReminder, history: updatedHistory)
        
        if let nextDate = decision.nextTriggerDate {
            updatedReminder.scheduledDate = nextDate
        }
        
        if decision.escalationLevel > updatedReminder.escalationLevel {
            updatedReminder.escalationLevel = decision.escalationLevel
        }
        
        updatedReminder.status = .scheduled
        try await notificationService.updateNotification(for: updatedReminder)
        
        return (updatedReminder, updatedHistory, decision)
    }
}
```

```swift
import Foundation

public struct EvaluateReminderUseCase {
    private let rulesEngine: ReminderRulesEngine
    private let personalizationService: PersonalizationService?
    
    public init(rulesEngine: ReminderRulesEngine, personalizationService: PersonalizationService? = nil) {
        self.rulesEngine = rulesEngine
        self.personalizationService = personalizationService
    }
    
    public func execute(
        reminder: Reminder,
        history: ReminderHistory
    ) -> ReminderDecision {
        let decision = rulesEngine.evaluate(reminder: reminder, history: history)
        if let personalization = personalizationService,
           decision.action == .noAction,
           let suggestion = personalization.suggestSchedule(reminder: reminder, history: history) {
            return suggestion
        }
        return decision
    }
}
```

```swift
import Foundation

public struct CreateReminderUseCase {
    private let notificationService: NotificationService
    private let locationService: LocationService
    
    public init(
        notificationService: NotificationService,
        locationService: LocationService
    ) {
        self.notificationService = notificationService
        self.locationService = locationService
    }
    
    public func execute(
        title: String,
        notes: String? = nil,
        scheduledDate: Date? = nil,
        locationTrigger: Reminder.LocationTrigger? = nil,
        priority: Reminder.Priority = .medium
    ) async throws -> Reminder {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyTitle
        }
        
        if let scheduledDate = scheduledDate, scheduledDate < Date() {
            throw ValidationError.invalidDate
        }
        
        if let location = locationTrigger {
            guard (-90...90).contains(location.latitude), (-180...180).contains(location.longitude), location.radius > 0 else {
                throw ValidationError.invalidLocation
            }
        }
        
        var reminder = Reminder(
            title: title,
            notes: notes,
            scheduledDate: scheduledDate,
            locationTrigger: locationTrigger,
            priority: priority,
            status: .created
        )
        
        if scheduledDate != nil {
            try await notificationService.scheduleNotification(for: reminder)
            reminder.status = .scheduled
        }
        
        if let trigger = locationTrigger {
            try await locationService.startMonitoring(trigger: trigger, for: reminder.id)
            reminder.status = .scheduled
        }
        
        return reminder
    }
    
    public enum ValidationError: LocalizedError {
        case emptyTitle
        case invalidDate
        case invalidLocation
        
        public var errorDescription: String? {
            switch self {
            case .emptyTitle:
                return "Reminder title cannot be empty"
            case .invalidDate:
                return "Scheduled date must be in the future"
            case .invalidLocation:
                return "Invalid location coordinates"
            }
        }
    }
}
```

```swift
import Foundation

public protocol LiveActivityService {
    func startActivity(for reminder: Reminder) async throws
    func updateActivity(for reminder: Reminder) async throws
    func endActivity(for reminderId: UUID) async throws
    func isActivitySupported() -> Bool
}
```

```swift
import Foundation

public protocol LocationService {
    func requestPermissions() async throws -> Bool
    func getCurrentLocation() async throws -> (latitude: Double, longitude: Double)
    func startMonitoring(trigger: Reminder.LocationTrigger, for reminderId: UUID) async throws
    func stopMonitoring(for reminderId: UUID) async throws
    var onGeofenceTriggered: ((UUID) -> Void)? { get set }
}
```

```swift
import Foundation

public protocol PersonalizationService {
    func suggestSchedule(reminder: Reminder, history: ReminderHistory) -> ReminderDecision?
}

public struct HeuristicPersonalizationService: PersonalizationService {
    public init() {}
    
    public func suggestSchedule(reminder: Reminder, history: ReminderHistory) -> ReminderDecision? {
        guard let avgHour = history.averageCompletionHour else { return nil }
        guard let scheduledDate = reminder.scheduledDate else { return nil }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
        components.hour = avgHour
        components.minute = 0
        guard let suggested = calendar.date(from: components) else { return nil }
        if abs((calendar.component(.hour, from: scheduledDate)) - avgHour) < 2 { return nil }
        return .suggest("Лучшее время по привычкам: \(avgHour):00", confidence: 0.7)
    }
}
```

```swift
import Foundation

public protocol NotificationService {
    func scheduleNotification(for reminder: Reminder) async throws
    func cancelNotification(for reminderId: UUID) async throws
    func updateNotification(for reminder: Reminder) async throws
    func requestPermissions() async throws -> Bool
}
```

```swift
import Foundation

public struct ReminderDecision: Equatable {
    public let nextTriggerDate: Date?
    public let escalationLevel: Int
    public let explanation: String
    public let action: Action
    public let confidence: Double
    
    public init(
        nextTriggerDate: Date? = nil,
        escalationLevel: Int = 0,
        explanation: String,
        action: Action,
        confidence: Double = 1.0
    ) {
        self.nextTriggerDate = nextTriggerDate
        self.escalationLevel = escalationLevel
        self.explanation = explanation
        self.action = action
        self.confidence = min(max(confidence, 0.0), 1.0)
    }
}

extension ReminderDecision {
    public enum Action: Equatable {
        case schedule(date: Date)
        case escalate
        case reschedule(date: Date, reason: String)
        case suggest(suggestion: String)
        case noAction
        
        public var displayName: String {
            switch self {
            case .schedule: return "Schedule"
            case .escalate: return "Escalate"
            case .reschedule: return "Reschedule"
            case .suggest: return "Suggestion"
            case .noAction: return "No Action"
            }
        }
    }
}

extension ReminderDecision {
    public static func escalate(
        to level: Int,
        because reason: String
    ) -> ReminderDecision {
        ReminderDecision(
            escalationLevel: level,
            explanation: reason,
            action: .escalate,
            confidence: 0.9
        )
    }
    
    public static func reschedule(
        to date: Date,
        because reason: String,
        escalationLevel: Int = 0
    ) -> ReminderDecision {
        ReminderDecision(
            nextTriggerDate: date,
            escalationLevel: escalationLevel,
            explanation: reason,
            action: .reschedule(date: date, reason: reason),
            confidence: 0.85
        )
    }
    
    public static func suggest(
        _ suggestion: String,
        confidence: Double = 0.7
    ) -> ReminderDecision {
        ReminderDecision(
            explanation: suggestion,
            action: .suggest(suggestion: suggestion),
            confidence: confidence
        )
    }
    
    public static func noAction(
        because reason: String = "No changes needed"
    ) -> ReminderDecision {
        ReminderDecision(
            explanation: reason,
            action: .noAction,
            confidence: 1.0
        )
    }
}
```

```swift
import Foundation

public struct ReminderHistory: Codable, Equatable {
    public let reminderId: UUID
    public var snoozeCount: Int
    public var ignoreCount: Int
    public var completionCount: Int
    public var snoozeTimes: [Date]
    public var completionTimes: [Date]
    public var ignoreTimes: [Date]
    public var executionHours: [Int]
    public var lastInteractionDate: Date?
    
    public init(
        reminderId: UUID,
        snoozeCount: Int = 0,
        ignoreCount: Int = 0,
        completionCount: Int = 0,
        snoozeTimes: [Date] = [],
        completionTimes: [Date] = [],
        ignoreTimes: [Date] = [],
        executionHours: [Int] = [],
        lastInteractionDate: Date? = nil
    ) {
        self.reminderId = reminderId
        self.snoozeCount = snoozeCount
        self.ignoreCount = ignoreCount
        self.completionCount = completionCount
        self.snoozeTimes = snoozeTimes
        self.completionTimes = completionTimes
        self.ignoreTimes = ignoreTimes
        self.executionHours = executionHours
        self.lastInteractionDate = lastInteractionDate
    }
}

extension ReminderHistory {
    public mutating func recordSnooze(at date: Date = Date()) {
        snoozeCount += 1
        snoozeTimes.append(date)
        lastInteractionDate = date
    }
    
    public mutating func recordCompletion(at date: Date = Date()) {
        completionCount += 1
        completionTimes.append(date)
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        executionHours.append(hour)
        
        lastInteractionDate = date
    }
    
    public mutating func recordIgnore(at date: Date = Date()) {
        ignoreCount += 1
        ignoreTimes.append(date)
        lastInteractionDate = date
    }
}

extension ReminderHistory {
    public var averageCompletionHour: Int? {
        guard !executionHours.isEmpty else { return nil }
        let sum = executionHours.reduce(0, +)
        return sum / executionHours.count
    }
    
    public var snoozeFrequency: Double {
        guard completionCount > 0 else { return 0 }
        return Double(snoozeCount) / Double(completionCount)
    }
    
    public var completionRate: Double {
        let total = completionCount + ignoreCount
        guard total > 0 else { return 0 }
        return Double(completionCount) / Double(total)
    }
    
    public var recentSnoozePattern: [Date] {
        Array(snoozeTimes.suffix(3))
    }
    
    public var averageSnoozeDuration: TimeInterval? {
        let recent = recentSnoozePattern
        guard recent.count >= 2 else { return nil }
        
        var durations: [TimeInterval] = []
        for i in 1..<recent.count {
            let duration = recent[i].timeIntervalSince(recent[i-1])
            durations.append(duration)
        }
        
        return durations.reduce(0, +) / Double(durations.count)
    }
}
```

```swift
import Foundation

public class ReminderRulesEngine {
    private let rules: [ReminderRule]
    
    public init(rules: [ReminderRule] = []) {
        self.rules = rules.isEmpty ? Self.defaultRules() : rules
    }
    
    public func evaluate(reminder: Reminder, history: ReminderHistory) -> ReminderDecision {
        let decisions = rules.compactMap { rule in
            rule.evaluate(reminder: reminder, history: history)
        }
        
        return decisions.max(by: { $0.confidence < $1.confidence })
            ?? .noAction(because: "No applicable rules found")
    }
    
    private static func defaultRules() -> [ReminderRule] {
        [
            SnoozePatternRule(),
            EscalationRule(),
            TimeOfDayOptimizationRule(),
            LocationSuggestionRule()
        ]
    }
}

private struct SnoozePatternRule: ReminderRule {
    func evaluate(reminder: Reminder, history: ReminderHistory) -> ReminderDecision? {
        guard reminder.status == .snoozed else { return nil }
        guard history.snoozeCount > 0 else { return nil }
        
        if history.snoozeCount >= 3 {
            let baseDuration: TimeInterval = 15 * 60
            let multiplier = min(Double(history.snoozeCount), 8.0)
            let duration = baseDuration * multiplier
            
            let nextDate = Date().addingTimeInterval(duration)
            let minutes = Int(duration / 60)
            
            return .reschedule(
                to: nextDate,
                because: "You've snoozed this \(history.snoozeCount) times. Extending snooze to \(minutes) minutes to give you more time.",
                escalationLevel: min(history.snoozeCount / 2, 3)
            )
        }
        
        let nextDate = Date().addingTimeInterval(10 * 60)
        return .reschedule(
            to: nextDate,
            because: "Standard 10-minute snooze applied."
        )
    }
}

private struct EscalationRule: ReminderRule {
    func evaluate(reminder: Reminder, history: ReminderHistory) -> ReminderDecision? {
        if history.ignoreCount >= 2 {
            let newLevel = reminder.escalationLevel + 1
            return .escalate(
                to: newLevel,
                because: "This reminder has been ignored \(history.ignoreCount) times. Increasing priority to ensure it gets your attention."
            )
        }
        
        if history.snoozeCount >= 5 && history.completionCount == 0 {
            let newLevel = reminder.escalationLevel + 1
            return .escalate(
                to: newLevel,
                because: "You've snoozed this \(history.snoozeCount) times without completing it. This might be important."
            )
        }
        
        return nil
    }
}

private struct TimeOfDayOptimizationRule: ReminderRule {
    func evaluate(reminder: Reminder, history: ReminderHistory) -> ReminderDecision? {
        guard let averageHour = history.averageCompletionHour else { return nil }
        guard history.completionCount >= 3 else { return nil }
        
        guard let scheduledDate = reminder.scheduledDate else { return nil }
        
        let calendar = Calendar.current
        let scheduledHour = calendar.component(.hour, from: scheduledDate)
        
        if abs(scheduledHour - averageHour) >= 2 {
            var components = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
            components.hour = averageHour
            components.minute = 0
            
            if let optimizedDate = calendar.date(from: components) {
                return .suggest(
                    "You usually complete similar reminders around \(averageHour):00. Consider scheduling for that time instead.",
                    confidence: 0.75
                )
            }
        }
        
        return nil
    }
}

private struct LocationSuggestionRule: ReminderRule {
    func evaluate(reminder: Reminder, history: ReminderHistory) -> ReminderDecision? {
        guard reminder.locationTrigger == nil else { return nil }
        guard history.completionRate < 0.7 else { return nil }
        
        if history.snoozeFrequency > 2.0 {
            return .suggest(
                "You often snooze this reminder. Consider adding a location trigger (like 'Home' or 'Office') to make it more contextual.",
                confidence: 0.6
            )
        }
        
        return nil
    }
}
```

```swift
import Foundation

public struct Reminder: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var notes: String?
    public var scheduledDate: Date?
    public var locationTrigger: LocationTrigger?
    public var priority: Priority
    public var status: Status
    public var escalationLevel: Int
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        scheduledDate: Date? = nil,
        locationTrigger: LocationTrigger? = nil,
        priority: Priority = .medium,
        status: Status = .created,
        escalationLevel: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.scheduledDate = scheduledDate
        self.locationTrigger = locationTrigger
        self.priority = priority
        self.status = status
        self.escalationLevel = escalationLevel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Reminder {
    public enum Priority: String, Codable, CaseIterable {
        case low
        case medium
        case high
        case critical
        
        public var displayName: String {
            rawValue.capitalized
        }
    }
    
    public enum Status: String, Codable {
        case created
        case scheduled
        case active
        case completed
        case snoozed
        case ignored
        
        public var displayName: String {
            rawValue.capitalized
        }
    }
    
    public struct LocationTrigger: Codable, Equatable {
        public let latitude: Double
        public let longitude: Double
        public let radius: Double
        public let triggerType: TriggerType
        public let locationName: String?
        
        public enum TriggerType: String, Codable {
            case enter
            case exit
            case both
        }
        
        public init(
            latitude: Double,
            longitude: Double,
            radius: Double = 100,
            triggerType: TriggerType = .enter,
            locationName: String? = nil
        ) {
            self.latitude = latitude
            self.longitude = longitude
            self.radius = radius
            self.triggerType = triggerType
            self.locationName = locationName
        }
    }
}

extension Reminder {
    public var isActive: Bool {
        status == .active
    }
    
    public var isCompleted: Bool {
        status == .completed
    }
    
    public var hasPassed: Bool {
        guard let scheduledDate = scheduledDate else { return false }
        return scheduledDate < Date()
    }
    
    public mutating func activate() {
        status = .active
        updatedAt = Date()
    }
    
    public mutating func complete() {
        status = .completed
        updatedAt = Date()
    }
    
    public mutating func snooze() {
        status = .snoozed
        updatedAt = Date()
    }
    
    public mutating func ignore() {
        status = .ignored
        updatedAt = Date()
    }
    
    public mutating func escalate() {
        escalationLevel += 1
        updatedAt = Date()
    }
}
```

```swift
import Foundation

public protocol ReminderRule {
    func evaluate(reminder: Reminder, history: ReminderHistory) -> ReminderDecision?
}
```
