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
    
    @State private var isProgrammaticChange = false  // Add this
        
        // Modify selectRecommendedLocation:
        private func selectRecommendedLocation(_ item: LocationItem) {
            guard selectedLocation?.name != item.title else { return }
            print("📍 selectRecommendedLocation called for \(item.title)")
            guard let mapView = mapView else { return }
            
            // Update selected location
            selectedLocation = LocationSelection.fromLocationItem(item)
            showCustomPin(false)
            
            // Mark as programmatic change
            isProgrammaticChange = true
            
            // Use coordinator to handle region change
            let newRegion = MKCoordinateRegion(
                center: item.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegionProgrammatically(newRegion)
            
            // Reset after slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isProgrammaticChange = false
            }
            
            if let annotation = mapView.annotations.first(where: { annotation in
                if let recommendedAnnotation = annotation as? RecommendedLocationAnnotation {
                    return recommendedAnnotation.locationItem.title == item.title
                }
                return false
            }) {
                mapView.selectAnnotation(annotation, animated: true)
            }
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
                        onRegionChanged: { _ in
                            handleMapRegionChange()
                        }
                    )
                )
                .ignoresSafeArea(edges: .bottom)
                
                // Center indicator - only show when no recommended location is selected
                if showCustomPin {
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
                        if !showCustomPin {
                            // We have a recommended location selected
                            dismiss()
                        } else {
                            // We're selecting a custom location
                            Task {
                                await selectCustomLocation()
                                await MainActor.run {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .foregroundColor(Color("pine"))
                    .disabled(selectedLocation == nil && showCustomPin)
                }
            }
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
        print("🗺 handleMapRegionChange called, isDragging: \(isDragging), isProgrammatic: \(isProgrammaticChange)")
        
        // Ignore programmatic changes
        if isProgrammaticChange {
            print("🗺 Ignoring programmatic change")
            return
        }
        
        guard let mapView = mapView else {
            print("🗺 Early return - no mapView")
            return
        }
        
        if let selectedLocation = selectedLocation, selectedLocation.isRecommended {
            let selectedCoordinate = selectedLocation.coordinate
            let centerCoordinate = mapView.region.center
            
            let distance = CLLocation(latitude: selectedCoordinate.latitude, longitude: selectedCoordinate.longitude)
                .distance(from: CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude))
            
            let thresholdDistance: CLLocationDistance = 5  // Increased from 2m to 5m
            
            print("🗺 Distance between selected RL and center: \(distance) meters")
            
            if distance > thresholdDistance {
                print("🗺 Distance threshold exceeded, showing custom pin")
                self.selectedLocation = nil
                showCustomPin(true)  // Using centralized method
            }
        } else if !showCustomPin {
            // Ensure custom pin is visible when no RL is selected
            showCustomPin(true)
        }
    }
    
    private func showCustomPin(_ show: Bool) {
        showCustomPin = show
        print("🗺 showCustomPin set to: \(show)")
    }
    
    private func selectCustomLocation() async {
            guard let mapView = mapView else { return }
            
            let locationName = await getLocationName(for: mapView.region.center)
            selectedLocation = LocationSelection(
                coordinate: mapView.region.center,
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
