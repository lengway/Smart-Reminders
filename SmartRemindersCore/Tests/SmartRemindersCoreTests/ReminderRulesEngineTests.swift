import XCTest
@testable import SmartRemindersCore

final class ReminderRulesEngineTests: XCTestCase {
    func testEscalationRuleWhenIgnoredTwice() throws {
        let engine = ReminderRulesEngine()
        let reminder = Reminder(title: "Test", status: .scheduled, escalationLevel: 0)
        var history = ReminderHistory(reminderId: reminder.id)
        history.recordIgnore()
        history.recordIgnore()
        
        let decision = engine.evaluate(reminder: reminder, history: history)
        switch decision.action {
        case .escalate:
            XCTAssertEqual(decision.escalationLevel, 1)
        default:
            XCTFail("Expected escalation decision")
        }
    }
    
    func testSnoozeRuleSuggestsLongerDelayAfterMultipleSnoozes() throws {
        let engine = ReminderRulesEngine()
        let reminder = Reminder(title: "Test", status: .snoozed)
        var history = ReminderHistory(reminderId: reminder.id)
        history.recordSnooze()
        history.recordSnooze()
        history.recordSnooze()
        
        let decision = engine.evaluate(reminder: reminder, history: history)
        switch decision.action {
        case .reschedule(let date, _):
            XCTAssertGreaterThan(date.timeIntervalSinceNow, 10 * 60)
        default:
            XCTFail("Expected reschedule decision")
        }
    }
}

final class CreateReminderValidationTests: XCTestCase {
    private func makeUseCase() -> CreateReminderUseCase {
        CreateReminderUseCase(
            notificationService: DummyNotificationService(),
            locationService: DummyLocationService()
        )
    }
    
    func testRejectsPastDate() async {
        let useCase = makeUseCase()
        let past = Date().addingTimeInterval(-3600)
        await XCTAssertThrowsErrorAsync(try await useCase.execute(title: "Test", scheduledDate: past)) { error in
            XCTAssertEqual(error as? CreateReminderUseCase.ValidationError, .invalidDate)
        }
    }
    
    func testRejectsInvalidLocation() async {
        let useCase = makeUseCase()
        let trigger = Reminder.LocationTrigger(latitude: 200, longitude: 0) // invalid latitude
        await XCTAssertThrowsErrorAsync(try await useCase.execute(title: "Test", locationTrigger: trigger)) { error in
            XCTAssertEqual(error as? CreateReminderUseCase.ValidationError, .invalidLocation)
        }
    }
}

// MARK: - Test helpers

private final class DummyNotificationService: NotificationService {
    func scheduleNotification(for reminder: Reminder) async throws {}
    func cancelNotification(for reminderId: UUID) async throws {}
    func updateNotification(for reminder: Reminder) async throws {}
    func requestPermissions() async throws -> Bool { true }
}

private final class DummyLocationService: LocationService {
    var onGeofenceTriggered: ((UUID) -> Void)?
    func requestPermissions() async throws -> Bool { true }
    func getCurrentLocation() async throws -> (latitude: Double, longitude: Double) { (0, 0) }
    func startMonitoring(trigger: Reminder.LocationTrigger, for reminderId: UUID) async throws {}
    func stopMonitoring(for reminderId: UUID) async throws {}
}

extension XCTestCase {
    func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail(message(), file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
}
