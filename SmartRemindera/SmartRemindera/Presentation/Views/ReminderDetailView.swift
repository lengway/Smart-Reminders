import SwiftUI
import SmartRemindersCore

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
            // Basic Info
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
            
            // Trigger Info
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
            
            // Explainability
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
            
            // History
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
            
            // Actions
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
