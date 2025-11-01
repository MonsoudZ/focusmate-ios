import SwiftUI
import MapKit

struct LocationPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var locationService: LocationService
  @Binding var locationName: String
  @Binding var latitude: Double?
  @Binding var longitude: Double?
  @Binding var radius: Int

  @State private var region: MKCoordinateRegion
  @State private var searchText = ""
  @State private var isSearching = false
  @State private var selectedCoordinate: CLLocationCoordinate2D?
  @State private var error: String?

  init(
    locationService: LocationService,
    locationName: Binding<String>,
    latitude: Binding<Double?>,
    longitude: Binding<Double?>,
    radius: Binding<Int>
  ) {
    _locationService = StateObject(wrappedValue: locationService)
    _locationName = locationName
    _latitude = latitude
    _longitude = longitude
    _radius = radius

    // Initialize region with existing coordinates or default
    let coordinate: CLLocationCoordinate2D
    if let lat = latitude.wrappedValue, let lon = longitude.wrappedValue {
      coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    } else {
      coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco default
    }

    _region = State(initialValue: MKCoordinateRegion(
      center: coordinate,
      span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    ))

    _selectedCoordinate = State(initialValue: latitude.wrappedValue != nil && longitude.wrappedValue != nil ? coordinate : nil)
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Search Bar
        HStack {
          Image(systemName: "magnifyingglass")
            .foregroundColor(.secondary)

          TextField("Search location or address", text: $searchText)
            .textFieldStyle(.plain)
            .onSubmit {
              Task {
                await searchLocation()
              }
            }

          if !searchText.isEmpty {
            Button {
              searchText = ""
            } label: {
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
            }
          }
        }
        .padding()
        .background(Color(.systemGray6))

        // Map
        ZStack(alignment: .center) {
          Map(coordinateRegion: $region, annotationItems: selectedCoordinate.map { [$0] } ?? []) { coordinate in
            MapAnnotation(coordinate: coordinate.asCLLocationCoordinate2D) {
              VStack(spacing: 0) {
                Image(systemName: "mappin.circle.fill")
                  .font(.system(size: 40))
                  .foregroundColor(.red)

                Circle()
                  .fill(Color.red.opacity(0.2))
                  .frame(width: CGFloat(radius) * 2, height: CGFloat(radius) * 2)
                  .overlay(
                    Circle()
                      .stroke(Color.red.opacity(0.5), lineWidth: 2)
                  )
              }
            }
          }
          .onTapGesture { location in
            // Convert tap location to coordinate
            // Note: This is approximate, Map doesn't provide exact coordinate from tap
          }

          // Center crosshair (for manual selection)
          if selectedCoordinate == nil {
            Image(systemName: "plus.circle")
              .font(.system(size: 40))
              .foregroundColor(.blue)
              .allowsHitTesting(false)
          }
        }

        // Location Info
        if let coordinate = selectedCoordinate {
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                if !locationName.isEmpty {
                  Text(locationName)
                    .font(.headline)
                }
                Text("Lat: \(coordinate.latitude, specifier: "%.6f"), Lon: \(coordinate.longitude, specifier: "%.6f")")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }

              Spacer()

              Button("Clear") {
                selectedCoordinate = nil
                locationName = ""
                latitude = nil
                longitude = nil
              }
              .font(.caption)
              .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
              Text("Notification Radius")
                .font(.subheadline)
                .fontWeight(.medium)

              HStack {
                Slider(value: Binding(
                  get: { Double(radius) },
                  set: { radius = Int($0) }
                ), in: 50...1000, step: 50)

                Text("\(radius)m")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .frame(width: 60, alignment: .trailing)
              }
            }
          }
          .padding()
          .background(Color(.systemGray6))
        }

        // Current Location Button
        HStack {
          Button {
            Task {
              await useCurrentLocation()
            }
          } label: {
            HStack {
              Image(systemName: "location.fill")
              Text("Use Current Location")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }
          .disabled(!locationService.hasLocationPermission)

          Button {
            // Use map center as selected location
            let center = region.center
            selectedCoordinate = center
            Task {
              do {
                let location = CLLocation(latitude: center.latitude, longitude: center.longitude)
                locationName = try await locationService.reverseGeocode(location)
              } catch {
                locationName = "Selected Location"
              }
            }
          } label: {
            HStack {
              Image(systemName: "mappin.and.ellipse")
              Text("Use Map Center")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }
        }
        .padding()
      }
      .navigationTitle("Pick Location")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            if let coordinate = selectedCoordinate {
              latitude = coordinate.latitude
              longitude = coordinate.longitude
            }
            dismiss()
          }
          .disabled(selectedCoordinate == nil)
        }
      }
      .alert("Error", isPresented: .constant(error != nil)) {
        Button("OK") {
          error = nil
        }
      } message: {
        if let error {
          Text(error)
        }
      }
      .task {
        if !locationService.hasLocationPermission {
          locationService.requestPermission()
        }
      }
    }
  }

  private func searchLocation() async {
    guard !searchText.isEmpty else { return }

    isSearching = true
    do {
      let location = try await locationService.geocodeAddress(searchText)
      let coordinate = location.coordinate

      selectedCoordinate = coordinate
      locationName = searchText
      region.center = coordinate

      print("✅ LocationPickerView: Found location: \(coordinate.latitude), \(coordinate.longitude)")
    } catch {
      self.error = "Could not find location: \(searchText)"
      print("❌ LocationPickerView: Geocoding failed: \(error)")
    }
    isSearching = false
  }

  private func useCurrentLocation() async {
    guard locationService.hasLocationPermission else {
      locationService.requestPermission()
      return
    }

    locationService.startUpdatingLocation()

    // Wait a moment for location to update
    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

    guard let location = locationService.currentLocation else {
      error = "Could not get current location"
      return
    }

    let coordinate = location.coordinate
    selectedCoordinate = coordinate
    region.center = coordinate

    // Reverse geocode to get address
    do {
      locationName = try await locationService.reverseGeocode(location)
    } catch {
      locationName = "Current Location"
    }

    locationService.stopUpdatingLocation()
  }
}

// Helper to make CLLocationCoordinate2D identifiable for Map
extension CLLocationCoordinate2D: Identifiable {
  public var id: String {
    "\(latitude),\(longitude)"
  }

  var asCLLocationCoordinate2D: CLLocationCoordinate2D {
    self
  }
}

#Preview {
  LocationPickerView(
    locationService: LocationService(),
    locationName: .constant(""),
    latitude: .constant(nil),
    longitude: .constant(nil),
    radius: .constant(100)
  )
}
