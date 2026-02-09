import Foundation
import Combine
import SmartRemindersCore

/// Central coordinator managing reminder lifecycle and state
@MainActor
public class ReminderCoordinator: ObservableObject {
    // Shared instance for AppIntents
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
    
    // MARK: - Public Methods
    
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
        
        // Update Live Activity if active
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
        
        // Clear active reminder if this was it
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
        
        // Start Live Activity
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
    
    // MARK: - Private Methods
    
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
