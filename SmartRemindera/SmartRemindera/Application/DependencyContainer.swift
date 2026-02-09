import Foundation
import Combine
import SmartRemindersCore

/// Dependency injection container
@MainActor
public class DependencyContainer: ObservableObject {
    // Services
    public let notificationService: NotificationService
    public let locationService: LocationService
    public let liveActivityService: LiveActivityService
    
    // Repository
    public let repository: ReminderRepository
    
    // Rules Engine
    public let rulesEngine: ReminderRulesEngine
    
    // Use Cases
    public let createReminderUseCase: CreateReminderUseCase
    public let snoozeReminderUseCase: SnoozeReminderUseCase
    public let completeReminderUseCase: CompleteReminderUseCase
    public let evaluateReminderUseCase: EvaluateReminderUseCase
    
    // Coordinator
    public let coordinator: ReminderCoordinator
    private let telemetry = Telemetry.shared
    
    public init() {
        // Initialize services
        self.notificationService = NotificationServiceImpl()
        self.locationService = LocationServiceImpl()
        
        if #available(iOS 16.2, *) {
            self.liveActivityService = LiveActivityServiceImpl()
        } else {
            self.liveActivityService = NoOpLiveActivityService()
        }
        
        // Initialize repository
        self.repository = ReminderRepository()
        
        // Initialize rules engine
        self.rulesEngine = ReminderRulesEngine()
        
        // Initialize use cases
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
        
        // Initialize coordinator
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

/// No-op implementation for iOS versions that don't support Live Activities
@MainActor
private class NoOpLiveActivityService: LiveActivityService {
    func startActivity(for reminder: Reminder) async throws {}
    func updateActivity(for reminder: Reminder) async throws {}
    func endActivity(for reminderId: UUID) async throws {}
    func isActivitySupported() -> Bool { false }
}
