import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject {
  @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
  @Published var currentLocation: CLLocation?
  @Published var isMonitoringLocation = false
  @Published var monitoredRegions: Set<String> = []

  private let locationManager = CLLocationManager()
  private let geocoder = CLGeocoder()

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    authorizationStatus = locationManager.authorizationStatus
  }

  // MARK: - Permission Management

  func requestPermission() {
    print("📍 LocationService: Requesting location permissions")
    locationManager.requestWhenInUseAuthorization()
  }

  func requestAlwaysAuthorization() {
    print("📍 LocationService: Requesting always authorization for geofencing")
    locationManager.requestAlwaysAuthorization()
  }

  var hasLocationPermission: Bool {
    switch authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      return true
    default:
      return false
    }
  }

  var hasAlwaysPermission: Bool {
    authorizationStatus == .authorizedAlways
  }

  // MARK: - Location Updates

  func startUpdatingLocation() {
    guard hasLocationPermission else {
      print("⚠️ LocationService: No location permission")
      return
    }

    print("📍 LocationService: Starting location updates")
    isMonitoringLocation = true
    locationManager.startUpdatingLocation()
  }

  func stopUpdatingLocation() {
    print("📍 LocationService: Stopping location updates")
    isMonitoringLocation = false
    locationManager.stopUpdatingLocation()
  }

  // MARK: - Geocoding

  func geocodeAddress(_ address: String) async throws -> CLLocation {
    print("🔍 LocationService: Geocoding address: \(address)")

    return try await withCheckedThrowingContinuation { continuation in
      geocoder.geocodeAddressString(address) { placemarks, error in
        if let error = error {
          print("❌ LocationService: Geocoding failed: \(error)")
          continuation.resume(throwing: error)
          return
        }

        guard let location = placemarks?.first?.location else {
          print("❌ LocationService: No location found for address")
          continuation.resume(throwing: LocationError.locationNotFound)
          return
        }

        print("✅ LocationService: Geocoded to: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        continuation.resume(returning: location)
      }
    }
  }

  func reverseGeocode(_ location: CLLocation) async throws -> String {
    print("🔍 LocationService: Reverse geocoding: \(location.coordinate.latitude), \(location.coordinate.longitude)")

    return try await withCheckedThrowingContinuation { continuation in
      geocoder.reverseGeocodeLocation(location) { placemarks, error in
        if let error = error {
          print("❌ LocationService: Reverse geocoding failed: \(error)")
          continuation.resume(throwing: error)
          return
        }

        guard let placemark = placemarks?.first else {
          print("❌ LocationService: No placemark found")
          continuation.resume(throwing: LocationError.locationNotFound)
          return
        }

        let address = [
          placemark.name,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country
        ].compactMap { $0 }.joined(separator: ", ")

        print("✅ LocationService: Reverse geocoded to: \(address)")
        continuation.resume(returning: address)
      }
    }
  }

  // MARK: - Geofencing

  func startMonitoring(
    identifier: String,
    coordinate: CLLocationCoordinate2D,
    radius: CLLocationDistance,
    notifyOnEntry: Bool,
    notifyOnExit: Bool
  ) {
    guard hasAlwaysPermission else {
      print("⚠️ LocationService: Need 'Always' permission for geofencing")
      return
    }

    // Remove existing region with same identifier
    stopMonitoring(identifier: identifier)

    let region = CLCircularRegion(
      center: coordinate,
      radius: radius,
      identifier: identifier
    )
    region.notifyOnEntry = notifyOnEntry
    region.notifyOnExit = notifyOnExit

    print("📍 LocationService: Starting geofence monitoring for \(identifier)")
    print("   Center: \(coordinate.latitude), \(coordinate.longitude)")
    print("   Radius: \(radius)m, Entry: \(notifyOnEntry), Exit: \(notifyOnExit)")

    locationManager.startMonitoring(for: region)
    monitoredRegions.insert(identifier)
  }

  func stopMonitoring(identifier: String) {
    guard let region = locationManager.monitoredRegions.first(where: { $0.identifier == identifier }) else {
      return
    }

    print("📍 LocationService: Stopping geofence monitoring for \(identifier)")
    locationManager.stopMonitoring(for: region)
    monitoredRegions.remove(identifier)
  }

  func stopAllMonitoring() {
    print("📍 LocationService: Stopping all geofence monitoring")
    for region in locationManager.monitoredRegions {
      locationManager.stopMonitoring(for: region)
    }
    monitoredRegions.removeAll()
  }

  // MARK: - Distance Calculation

  func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
    let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
    return fromLocation.distance(from: toLocation)
  }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor in
      let status = manager.authorizationStatus
      print("📍 LocationService: Authorization status changed to \(status.rawValue)")
      self.authorizationStatus = status
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    Task { @MainActor in
      guard let location = locations.last else { return }
      print("📍 LocationService: Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
      self.currentLocation = location
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      print("❌ LocationService: Location manager failed: \(error)")
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    Task { @MainActor in
      print("📍 LocationService: Entered region: \(region.identifier)")
      // Post notification for arrival
      NotificationCenter.default.post(
        name: .taskLocationEntered,
        object: nil,
        userInfo: ["regionId": region.identifier]
      )
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    Task { @MainActor in
      print("📍 LocationService: Exited region: \(region.identifier)")
      // Post notification for departure
      NotificationCenter.default.post(
        name: .taskLocationExited,
        object: nil,
        userInfo: ["regionId": region.identifier]
      )
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
    Task { @MainActor in
      if let region = region {
        print("❌ LocationService: Monitoring failed for region \(region.identifier): \(error)")
      } else {
        print("❌ LocationService: Monitoring failed: \(error)")
      }
    }
  }
}

// MARK: - Location Errors

enum LocationError: LocalizedError {
  case locationNotFound
  case permissionDenied
  case geofencingNotAvailable

  var errorDescription: String? {
    switch self {
    case .locationNotFound:
      return "Could not find location"
    case .permissionDenied:
      return "Location permission denied"
    case .geofencingNotAvailable:
      return "Geofencing not available on this device"
    }
  }
}

// MARK: - Notification Names

extension Notification.Name {
  static let taskLocationEntered = Notification.Name("taskLocationEntered")
  static let taskLocationExited = Notification.Name("taskLocationExited")
}
