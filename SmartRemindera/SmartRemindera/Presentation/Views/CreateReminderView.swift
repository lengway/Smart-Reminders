import SwiftUI
import MapKit
import SmartRemindersCore
import UIKit

struct CreateReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateReminderViewModel
    
    init(coordinator: ReminderCoordinator, locationService: LocationService) {
        _viewModel = StateObject(wrappedValue: CreateReminderViewModel(
            coordinator: coordinator,
            locationService: locationService
        ))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $viewModel.title)
                    TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Priority") {
                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(Reminder.Priority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Toggle("Time-based trigger", isOn: $viewModel.useTimeBasedTrigger)
                    
                    if viewModel.useTimeBasedTrigger {
                        DatePicker("Scheduled for", selection: $viewModel.scheduledDate)
                    }
                }
                
                Section {
                    Toggle("Location-based trigger", isOn: $viewModel.useLocationTrigger)
                    
                    if viewModel.useLocationTrigger {
                        TextField("Location name (optional)", text: $viewModel.locationName)
                        
                        Button("Use Current Location") {
                            Task {
                                await viewModel.getCurrentLocation()
                            }
                        }
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundStyle(.blue)
                        
                        HStack {
                            Text("Latitude")
                            Spacer()
                            Text(String(format: "%.6f", viewModel.latitude))
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Longitude")
                            Spacer()
                            Text(String(format: "%.6f", viewModel.longitude))
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Radius")
                            Spacer()
                            Text("\(Int(viewModel.radius))m")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $viewModel.radius, in: 50...500, step: 50)
                        
                        Picker("Trigger type", selection: $viewModel.triggerType) {
                            Text("Enter").tag(Reminder.LocationTrigger.TriggerType.enter)
                            Text("Exit").tag(Reminder.LocationTrigger.TriggerType.exit)
                            Text("Both").tag(Reminder.LocationTrigger.TriggerType.both)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isLoading)
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
