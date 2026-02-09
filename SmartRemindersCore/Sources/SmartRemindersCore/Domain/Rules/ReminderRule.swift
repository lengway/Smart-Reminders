import Foundation

/// Protocol for individual reminder rules
public protocol ReminderRule {
    /// Evaluates the rule against a reminder and its history
    func evaluate(reminder: Reminder, history: ReminderHistory) -> ReminderDecision?
}
