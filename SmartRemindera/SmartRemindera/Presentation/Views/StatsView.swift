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
