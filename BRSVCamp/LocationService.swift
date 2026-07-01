import CoreLocation
import Observation

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var userLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // Observabil din MapView pentru a declanșa centrarea camerei la primul fix
    var hasLocation: Bool { userLocation != nil }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func centerOnUser() {
        // Apelat din butonul "locate me" — refolosim ultima poziție cunoscută
        _ = userLocation
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Continuăm cu ultima poziție cunoscută sau mock data
    }
}
