import Foundation
import Combine
import CoreLocation
import SwiftUI
import SmartRemindersCore

/// ViewModel for creating reminders
@MainActor
public class CreateReminderViewModel: ObservableObject {
    @Published public var title = ""
    @Published public var notes = ""
    @Published public var scheduledDate = Date().addingTimeInterval(3600) // 1 hour from now
    @Published public var useTimeBasedTrigger = true
    @Published public var useLocationTrigger = false
    @Published public var priority: Reminder.Priority = .medium
    
    // Location fields
    @Published public var locationName = ""
    @Published public var latitude: Double = 0
    @Published public var longitude: Double = 0
    @Published public var radius: Double = 100
    @Published public var triggerType: Reminder.LocationTrigger.TriggerType = .enter
    
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let coordinator: ReminderCoordinator
    private let locationService: LocationService
    
    public init(coordinator: ReminderCoordinator, locationService: LocationService) {
        self.coordinator = coordinator
        self.locationService = locationService
    }
    
    public var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (useTimeBasedTrigger || useLocationTrigger)
    }
    
    public func getCurrentLocation() async {
        do {
            let granted = try await locationService.requestPermissions()
            guard granted else {
                errorMessage = "Разрешите доступ к геолокации в настройках"
                return
            }
            let location = try await locationService.getCurrentLocation()
            latitude = location.latitude
            longitude = location.longitude
        } catch {
            // Подсказываем пользователю про права
            errorMessage = "Не удалось получить локацию. Проверьте разрешения и GPS: \(error.localizedDescription)"
        }
    }
    
    public func save() async -> Bool {
        guard canSave else { return false }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let locationTrigger: Reminder.LocationTrigger? = useLocationTrigger ? 
                Reminder.LocationTrigger(
                    latitude: latitude,
                    longitude: longitude,
                    radius: radius,
                    triggerType: triggerType,
                    locationName: locationName.isEmpty ? nil : locationName
                ) : nil
            
            try await coordinator.createReminder(
                title: title,
                notes: notes.isEmpty ? nil : notes,
                scheduledDate: useTimeBasedTrigger ? scheduledDate : nil,
                locationTrigger: locationTrigger,
                priority: priority
            )
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
