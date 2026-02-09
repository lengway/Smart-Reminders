import Foundation
import Combine
import UserNotifications
import CoreLocation

@MainActor
final class PermissionsViewModel: NSObject, ObservableObject {
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isRequesting = false
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    var needsAttention: Bool {
        notificationStatus == .denied || locationStatus == .denied
    }
    
    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
        locationStatus = locationManager.authorizationStatus
    }
    
    func requestNotifications() async {
        isRequesting = true
        defer { isRequesting = false }
        let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert])
        if granted == false {
            notificationStatus = .denied
        } else {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationStatus = settings.authorizationStatus
        }
    }
    
    func requestLocation() async {
        isRequesting = true
        defer { isRequesting = false }
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            locationStatus = status
        default:
            locationStatus = status
        }
    }
}

extension PermissionsViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
    }
}
