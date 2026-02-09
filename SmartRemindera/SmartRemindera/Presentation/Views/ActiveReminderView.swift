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
                        // Large icon
                        Image(systemName: "bell.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)
                            .padding(.top, 40)
                        
                        // Title
                        Text(reminder.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Notes
                        if let notes = reminder.notes {
                            Text(notes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Countdown
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
                        
                        // Escalation indicator
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
                        
                        // Action buttons
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
