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
    #if DEBUG
    print("📍 LocationService: Requesting location permissions")
    #endif
    locationManager.requestWhenInUseAuthorization()
  }

  func requestAlwaysAuthorization() {
    #if DEBUG
    print("📍 LocationService: Requesting always authorization for geofencing")
    #endif
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
      #if DEBUG
      print("⚠️ LocationService: No location permission")
      #endif
      return
    }

    #if DEBUG
    print("📍 LocationService: Starting location updates")
    #endif
    isMonitoringLocation = true
    locationManager.startUpdatingLocation()
  }

  func stopUpdatingLocation() {
    #if DEBUG
    print("📍 LocationService: Stopping location updates")
    #endif
    isMonitoringLocation = false
    locationManager.stopUpdatingLocation()
  }

  // MARK: - Geocoding

  func geocodeAddress(_ address: String) async throws -> CLLocation {
    #if DEBUG
    print("🔍 LocationService: Geocoding address: \(address)")
    #endif

    return try await withCheckedThrowingContinuation { continuation in
      geocoder.geocodeAddressString(address) { placemarks, error in
        if let error = error {
          #if DEBUG
          print("❌ LocationService: Geocoding failed: \(error)")
          #endif
          continuation.resume(throwing: error)
          return
        }

        guard let location = placemarks?.first?.location else {
          #if DEBUG
          print("❌ LocationService: No location found for address")
          #endif
          continuation.resume(throwing: LocationError.locationNotFound)
          return
        }

        #if DEBUG
        print("✅ LocationService: Geocoded to: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        #endif
        continuation.resume(returning: location)
      }
    }
  }

  func reverseGeocode(_ location: CLLocation) async throws -> String {
    #if DEBUG
    print("🔍 LocationService: Reverse geocoding: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    #endif

    return try await withCheckedThrowingContinuation { continuation in
      geocoder.reverseGeocodeLocation(location) { placemarks, error in
        if let error = error {
          #if DEBUG
          print("❌ LocationService: Reverse geocoding failed: \(error)")
          #endif
          continuation.resume(throwing: error)
          return
        }

        guard let placemark = placemarks?.first else {
          #if DEBUG
          print("❌ LocationService: No placemark found")
          #endif
          continuation.resume(throwing: LocationError.locationNotFound)
          return
        }

        let address = [
          placemark.name,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country
        ].compactMap { $0 }.joined(separator: ", ")

        #if DEBUG
        print("✅ LocationService: Reverse geocoded to: \(address)")
        #endif
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
      #if DEBUG
      print("⚠️ LocationService: Need 'Always' permission for geofencing")
      #endif
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

    #if DEBUG
    print("📍 LocationService: Starting geofence monitoring for \(identifier)")
    #endif
    #if DEBUG
    print("   Center: \(coordinate.latitude), \(coordinate.longitude)")
    #endif
    #if DEBUG
    print("   Radius: \(radius)m, Entry: \(notifyOnEntry), Exit: \(notifyOnExit)")
    #endif

    locationManager.startMonitoring(for: region)
    monitoredRegions.insert(identifier)
  }

  func stopMonitoring(identifier: String) {
    guard let region = locationManager.monitoredRegions.first(where: { $0.identifier == identifier }) else {
      return
    }

    #if DEBUG
    print("📍 LocationService: Stopping geofence monitoring for \(identifier)")
    #endif
    locationManager.stopMonitoring(for: region)
    monitoredRegions.remove(identifier)
  }

  func stopAllMonitoring() {
    #if DEBUG
    print("📍 LocationService: Stopping all geofence monitoring")
    #endif
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
      #if DEBUG
      print("📍 LocationService: Authorization status changed to \(status.rawValue)")
      #endif
      self.authorizationStatus = status
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    Task { @MainActor in
      guard let location = locations.last else { return }
      #if DEBUG
      print("📍 LocationService: Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
      #endif
      self.currentLocation = location
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      #if DEBUG
      print("❌ LocationService: Location manager failed: \(error)")
      #endif
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    Task { @MainActor in
      #if DEBUG
      print("📍 LocationService: Entered region: \(region.identifier)")
      #endif
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
      #if DEBUG
      print("📍 LocationService: Exited region: \(region.identifier)")
      #endif
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
        #if DEBUG
        print("❌ LocationService: Monitoring failed for region \(region.identifier): \(error)")
        #endif
      } else {
        #if DEBUG
        print("❌ LocationService: Monitoring failed: \(error)")
        #endif
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
