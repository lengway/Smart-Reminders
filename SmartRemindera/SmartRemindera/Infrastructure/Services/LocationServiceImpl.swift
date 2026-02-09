import Foundation
import CoreLocation
import SmartRemindersCore

/// iOS implementation of LocationService using CoreLocation
@MainActor
public class LocationServiceImpl: NSObject, LocationService {
    private let locationManager = CLLocationManager()
    private var monitoredRegions: [UUID: CLCircularRegion] = [:]
    private var permissionContinuation: CheckedContinuation<Bool, Never>?
    private var locationContinuations: [CheckedContinuation<(latitude: Double, longitude: Double), Error>] = []
    
    public var onGeofenceTriggered: ((UUID) -> Void)?
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    public func requestPermissions() async throws -> Bool {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
            return await withCheckedContinuation { continuation in
                permissionContinuation = continuation
            }
        default:
            return false
        }
    }
    
    public func getCurrentLocation() async throws -> (latitude: Double, longitude: Double) {
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuations.append(continuation)
            locationManager.requestLocation()
        }
    }
    
    public func startMonitoring(trigger: Reminder.LocationTrigger, for reminderId: UUID) async throws {
        let coordinate = CLLocationCoordinate2D(
            latitude: trigger.latitude,
            longitude: trigger.longitude
        )
        
        let region = CLCircularRegion(
            center: coordinate,
            radius: trigger.radius,
            identifier: reminderId.uuidString
        )
        
        // Configure region based on trigger type
        switch trigger.triggerType {
        case .enter:
            region.notifyOnEntry = true
            region.notifyOnExit = false
        case .exit:
            region.notifyOnEntry = false
            region.notifyOnExit = true
        case .both:
            region.notifyOnEntry = true
            region.notifyOnExit = true
        }
        
        monitoredRegions[reminderId] = region
        locationManager.startMonitoring(for: region)
    }
    
    public func stopMonitoring(for reminderId: UUID) async throws {
        guard let region = monitoredRegions[reminderId] else { return }
        
        locationManager.stopMonitoring(for: region)
        monitoredRegions.removeValue(forKey: reminderId)
    }
    
    // MARK: - Private
    
    private func resumePermissionContinuation(granted: Bool) {
        permissionContinuation?.resume(returning: granted)
        permissionContinuation = nil
    }
    
    private func flushLocationContinuations(with result: Result<(latitude: Double, longitude: Double), Error>) {
        locationContinuations.forEach { continuation in
            switch result {
            case .success(let value):
                continuation.resume(returning: value)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
        locationContinuations.removeAll()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationServiceImpl: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        flushLocationContinuations(with: .success((
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )))
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        flushLocationContinuations(with: .failure(error))
    }
    
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let reminderId = UUID(uuidString: region.identifier) else { return }
        onGeofenceTriggered?(reminderId)
    }
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let reminderId = UUID(uuidString: region.identifier) else { return }
        onGeofenceTriggered?(reminderId)
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            resumePermissionContinuation(granted: true)
        case .denied, .restricted:
            resumePermissionContinuation(granted: false)
        default:
            break
        }
    }
}
