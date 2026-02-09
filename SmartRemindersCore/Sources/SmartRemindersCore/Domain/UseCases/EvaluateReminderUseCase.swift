import Foundation

/// Use case for evaluating a reminder using the rules engine
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
