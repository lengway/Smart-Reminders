import Foundation

/// Protocol for location service operations
public protocol LocationService {
    /// Requests location permissions
    func requestPermissions() async throws -> Bool
    
    /// Gets current location
    func getCurrentLocation() async throws -> (latitude: Double, longitude: Double)
    
    /// Starts monitoring a geofence region
    func startMonitoring(trigger: Reminder.LocationTrigger, for reminderId: UUID) async throws
    
    /// Stops monitoring a geofence region
    func stopMonitoring(for reminderId: UUID) async throws
    
    /// Callback when a geofence is triggered
    var onGeofenceTriggered: ((UUID) -> Void)? { get set }
}
