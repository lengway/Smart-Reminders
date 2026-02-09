import SwiftUI
import SmartRemindersCore

struct ReminderListView: View {
    @StateObject private var viewModel: ReminderListViewModel
    @State private var showingCreateSheet = false
    @State private var selectedReminder: Reminder?
    
    private let coordinator: ReminderCoordinator
    private let locationService: LocationService
    
    init(coordinator: ReminderCoordinator, locationService: LocationService) {
        self.coordinator = coordinator
        self.locationService = locationService
        _viewModel = StateObject(wrappedValue: ReminderListViewModel(coordinator: coordinator))
    }
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.displayedReminders.isEmpty {
                    ContentUnavailableView(
                        "No Reminders",
                        systemImage: "bell.slash",
                        description: Text("Tap + to create your first reminder")
                    )
                } else {
                    ForEach(viewModel.displayedReminders) { reminder in
                        ReminderRow(reminder: reminder)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedReminder = reminder
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteReminder(reminder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if reminder.status == .scheduled {
                                    Button {
                                        viewModel.activateReminder(reminder)
                                    } label: {
                                        Label("Activate", systemImage: "play.fill")
                                    }
                                    .tint(.green)
                                }
                            }
                    }
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All") {
                            viewModel.filteredStatus = nil
                        }
                        Button("Scheduled") {
                            viewModel.filteredStatus = .scheduled
                        }
                        Button("Active") {
                            viewModel.filteredStatus = .active
                        }
                        Button("Completed") {
                            viewModel.filteredStatus = .completed
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateReminderView(coordinator: coordinator, locationService: locationService)
            }
            .sheet(item: $selectedReminder) { reminder in
                NavigationStack {
                    ReminderDetailView(reminder: reminder, coordinator: coordinator)
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
        }
    }
}

struct ReminderRow: View {
    let reminder: Reminder
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.headline)
                
                if let scheduledDate = reminder.scheduledDate {
                    Text(scheduledDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let locationTrigger = reminder.locationTrigger {
                    Label(locationTrigger.locationName ?? "Location", systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Priority badge
                Text(reminder.priority.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.2))
                    .foregroundStyle(priorityColor)
                    .clipShape(Capsule())
                
                // Escalation indicator
                if reminder.escalationLevel > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(reminder.escalationLevel, 3), id: \.self) { _ in
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reminder.title), статус \(reminder.status.displayName), приоритет \(reminder.priority.displayName)")
    }
    
    private var statusColor: Color {
        switch reminder.status {
        case .created: return .gray
        case .scheduled: return .blue
        case .active: return .green
        case .completed: return .purple
        case .snoozed: return .orange
        case .ignored: return .red
        }
    }
    
    private var priorityColor: Color {
        switch reminder.priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}
