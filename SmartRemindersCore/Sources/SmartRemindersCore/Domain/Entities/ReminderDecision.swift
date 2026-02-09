import Foundation

/// Represents a decision made by the rules engine about how to handle a reminder
public struct ReminderDecision: Equatable {
    /// Recommended next trigger time (nil if no reschedule needed)
    public let nextTriggerDate: Date?
    
    /// Recommended escalation level
    public let escalationLevel: Int
    
    /// Human-readable explanation of why this decision was made
    public let explanation: String
    
    /// Recommended action
    public let action: Action
    
    /// Confidence score (0.0 to 1.0)
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

// MARK: - Action Types

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

// MARK: - Convenience Constructors

extension ReminderDecision {
    /// Creates a decision to escalate the reminder
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
    
    /// Creates a decision to reschedule the reminder
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
    
    /// Creates a decision with a suggestion
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
    
    /// Creates a no-action decision
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
