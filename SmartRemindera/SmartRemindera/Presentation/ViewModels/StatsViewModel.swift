import Foundation
import Combine
import SmartRemindersCore

/// ViewModel for statistics screen
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
        
        // Calculate stats from histories
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
            
            // Find most common hour
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
