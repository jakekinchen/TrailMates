// LocationPickerView.swift

import SwiftUI
import MapKit

// MARK: - Location Selection Model
struct LocationSelection: Identifiable, Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String
    let isRecommended: Bool
    
    static func == (lhs: LocationSelection, rhs: LocationSelection) -> Bool {
        lhs.id == rhs.id &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.name == rhs.name
    }
    
    // Helper to create from LocationItem
    static func fromLocationItem(_ item: LocationItem) -> LocationSelection {
        LocationSelection(
            coordinate: item.coordinate,
            name: item.title,
            isRecommended: true
        )
    }
}

// First, let's create a wrapper for MKMapItem to make it Identifiable
struct MapItemWrapper: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    
    var coordinate: CLLocationCoordinate2D {
        mapItem.placemark.coordinate
    }
    
    var name: String {
        mapItem.name ?? "Unknown Location"
    }
    
    var address: String? {
        mapItem.placemark.title
    }
}

struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLocation: LocationSelection?
    @State private var mapView: MKMapView?
    @State private var isDragging = false
    @State private var showCustomPin = true
    @State private var isMapInitialized = false
    
    // Add this to track internal state
    @State private var internalSelectedLocation: LocationSelection?
    
    // Add this to track the current map center for custom locations
    @State private var currentCustomLocation: LocationSelection?
    
    // Add a debounce time state
    @State private var lastGeocodingTime: Date = .distantPast
    
    init(selectedLocation: Binding<LocationSelection?>) {
        self._selectedLocation = selectedLocation
        self._internalSelectedLocation = State(initialValue: selectedLocation.wrappedValue)
    }
    
    private func updateSelectedLocation(_ location: LocationSelection) {
        print("🎯 START updateSelectedLocation")
        print("🎯 Before update - internalSelectedLocation: \(String(describing: internalSelectedLocation))")
        print("🎯 Before update - selectedLocation: \(String(describing: selectedLocation))")
        
        internalSelectedLocation = location
        selectedLocation = location
        
        print("🎯 After update - internalSelectedLocation: \(String(describing: internalSelectedLocation))")
        print("🎯 After update - selectedLocation: \(String(describing: selectedLocation))")
        print("🎯 END updateSelectedLocation")
    }
    
    private func selectRecommendedLocation(_ item: LocationItem) {
        print("🎯 START selectRecommendedLocation")
        print("🎯 Current selectedLocation: \(String(describing: selectedLocation))")
        print("🎯 Current internalSelectedLocation: \(String(describing: internalSelectedLocation))")
        
        guard isMapInitialized else {
            print("🎯 Map not initialized, deferring")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.selectRecommendedLocation(item)
            }
            return
        }
        
        let newLocation = LocationSelection.fromLocationItem(item)
        print("🎯 Created new location: \(newLocation.name)")
        updateSelectedLocation(newLocation)
        print("🎯 After updateSelectedLocation - selectedLocation: \(String(describing: selectedLocation))")
        showCustomPin(false)
        print("🎯 END selectRecommendedLocation")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                UnifiedMapView(
                    mapView: $mapView,
                    configuration: MapConfiguration(
                        showUserLocation: true,
                        showRecommendedLocations: true,
                        isLocationPickerEnabled: true,
                        showCustomPin: $showCustomPin,
                        isDragging: $isDragging,
                        onLocationSelected: { location in
                            selectRecommendedLocation(location)
                        },
                        onRegionChanged: { region in
                            handleMapRegionChange()
                            if showCustomPin {
                                updateCustomLocation(for: region.center)
                            }
                        }
                    )
                )
                .ignoresSafeArea(edges: .bottom)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isMapInitialized = true
                    }
                }
                
                if showCustomPin && isMapInitialized {
                    CustomPin(isSelected: false, isDragging: $isDragging)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                VStack {
                    Menu {
                        ForEach(Locations.items, id: \.title) { item in
                            Button(item.title) {
                                selectRecommendedLocation(item)
                            }
                        }
                    } label: {
                        HStack {
                            Text(menuLabel)
                                .foregroundColor(Color("pine"))
                            Image(systemName: "chevron.down")
                                .foregroundColor(Color("pine"))
                        }
                        .padding()
                        .background(Color("beige"))
                        .cornerRadius(10)
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color("pine"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select") {
                        confirmSelection()
                    }
                    .foregroundColor(Color("pine"))
                    .disabled(selectedLocation == nil && currentCustomLocation == nil)
                }
            }
        }
        .onAppear {
            print("📍 LocationPickerView appeared with location: \(String(describing: selectedLocation))")
            if let existing = selectedLocation {
                internalSelectedLocation = existing
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isMapInitialized = true
            }
        }
        .onChange(of: selectedLocation) { oldValue, newValue in
            print("🗺 LocationPickerView: selectedLocation changed to: \(String(describing: newValue))")
        }
        .onDisappear {
            // No longer needed
            // geocodingDebouncer?.invalidate()
            // geocodingDebouncer = nil
        }
    }
    
    private var isRecommendedLocationSelected: Bool {
            selectedLocation?.isRecommended == true
        }
    
    private var menuLabel: String {
        if let selected = selectedLocation, selected.isRecommended {
            return selected.name
        }
        return "Recommended Locations"
    }
    
    private func handleMapRegionChange() {
        print("🗺 handleMapRegionChange called, isDragging: \(isDragging)")
        
        guard let mapView = mapView else {
            print("🗺 Early return - no mapView")
            return
        }
        
        let center = mapView.region.center
        guard isValidCoordinate(center) else {
            print("🗺 Invalid coordinates detected in region change")
            return
        }
        
        if let selectedLocation = selectedLocation,
           selectedLocation.isRecommended,
           isValidCoordinate(selectedLocation.coordinate) {
            let selectedCoordinate = selectedLocation.coordinate
            let centerCoordinate = center
            
            let distance = CLLocation(latitude: selectedCoordinate.latitude, longitude: selectedCoordinate.longitude)
                .distance(from: CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude))
            
            let thresholdDistance: CLLocationDistance = 5
            
            print("🗺 Distance between selected RL and center: \(distance) meters")
            
            if distance > thresholdDistance {
                self.selectedLocation = nil
                currentCustomLocation = nil  // Reset custom location too
                showCustomPin(true)
            }
        } else if !showCustomPin {
            showCustomPin(true)
        }
    }
    
    private func showCustomPin(_ show: Bool) {
        showCustomPin = show
        print("🗺 showCustomPin set to: \(show)")
    }
    
    private func selectCustomLocation() async {
        print("🗺 selectCustomLocation called")
        guard let mapView = mapView else {
            print("🗺 No mapView available")
            return
        }
        
        let center = mapView.region.center
        guard isValidCoordinate(center) else {
            print("🗺 Invalid coordinates detected")
            return
        }
            
        let locationName = await getLocationName(for: center)
        selectedLocation = LocationSelection(
            coordinate: center,
            name: locationName,
            isRecommended: false
        )
    }
    
    private func getLocationName(for coordinate: CLLocationCoordinate2D) async -> String {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let geocoder = CLGeocoder()
            
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    var components: [String] = []
                    
                    if let name = placemark.name {
                        components.append(name)
                    }
                    if let thoroughfare = placemark.thoroughfare {
                        components.append(thoroughfare)
                    }
                    if let locality = placemark.locality {
                        components.append(locality)
                    }
                    
                    return components.isEmpty ? "Selected Location" : components.joined(separator: ", ")
                }
            } catch {
                print("Reverse geocoding error: \(error.localizedDescription)")
            }
            
            return "Selected Location"
        }
    
    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude.isFinite && 
               coordinate.longitude.isFinite &&
               coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
               coordinate.longitude >= -180 && coordinate.longitude <= 180
    }
    
    private func updateCustomLocation(for coordinate: CLLocationCoordinate2D) {
        let now = Date()
        // Only update if enough time has passed (500ms)
        guard now.timeIntervalSince(lastGeocodingTime) > 0.5 else { return }
        
        Task {
            guard isValidCoordinate(coordinate) else { return }
            let locationName = await getLocationName(for: coordinate)
            await MainActor.run {
                currentCustomLocation = LocationSelection(
                    coordinate: coordinate,
                    name: locationName,
                    isRecommended: false
                )
                lastGeocodingTime = Date()
            }
        }
    }
    
    private func confirmSelection() {
        print("🎯 Confirming selection")
        
        // Create a local copy of the location to update
        let locationToConfirm: LocationSelection?
        
        if !showCustomPin, let location = selectedLocation {
            print("🎯 Confirming recommended location: \(location.name)")
            locationToConfirm = location
        } else if let customLocation = currentCustomLocation {
            print("🎯 Confirming custom location: \(customLocation.name)")
            locationToConfirm = customLocation
        } else {
            locationToConfirm = nil
        }
        
        // Update the binding on the main thread
        if let location = locationToConfirm {
            DispatchQueue.main.async {
                selectedLocation = location
                print("🎯 Updated selectedLocation: \(String(describing: selectedLocation))")
                
                // Dismiss after a short delay to ensure the binding is updated
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    dismiss()
                }
            }
        } else {
            dismiss()
        }
    }
}

extension CLLocationCoordinate2D {
    var stringRepresentation: String {
        return "\(latitude), \(longitude)"
    }
}

extension Event {
    func getLocationName() -> String {
        // Check if it's a recommended location
        let recommendedLocation = Locations.items.first {
            abs($0.coordinate.latitude - location.latitude) < 0.0001 &&
            abs($0.coordinate.longitude - location.longitude) < 0.0001
        }
        
        if let recommended = recommendedLocation {
            return recommended.title
        }
        
        // If not a recommended location, return coordinate string
        return "Custom Location (\(location.stringRepresentation))"
    }
}
