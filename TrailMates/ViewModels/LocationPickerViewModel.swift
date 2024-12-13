import os.log
import SwiftUI
import MapKit

// MARK: - LocationPickerViewModel
@MainActor
class LocationPickerViewModel: ObservableObject {
    @Published var selectedLocation: LocationSelection?
    @Published var currentCustomLocation: LocationSelection?
    @Published var isDragging = false
    @Published var showCustomPin = true
    @Published var mapView: MKMapView?
    
    private let logger = Logger(subsystem: "com.bridges.trailmatesatx", category: "LocationPicker")
    private var lastGeocodingTime: Date = .distantPast
    
    init(initialLocation: LocationSelection? = nil) {
        self.selectedLocation = initialLocation
        logger.debug("Initialized with location: \(String(describing: initialLocation))")
    }
    
    func selectRecommendedLocation(_ item: LocationItem) {
        logger.debug("Selecting recommended location: \(item.title)")
        let newLocation = LocationSelection.fromLocationItem(item)
        updateSelectedLocation(newLocation)
        showCustomPin = false
    }
    
    func updateSelectedLocation(_ location: LocationSelection) {
        logger.debug("Updating location to: \(location.name)")
        selectedLocation = location
    }
    
    func handleMapRegionChange(_ region: MKCoordinateRegion) {
        let center = region.center
        guard isValidCoordinate(center) else {
            logger.debug("Invalid coordinates detected")
            return
        }
        
        if let selectedLocation = selectedLocation,
           selectedLocation.isRecommended,
           isValidCoordinate(selectedLocation.coordinate) {
            let distance = CLLocation(latitude: selectedLocation.coordinate.latitude, longitude: selectedLocation.coordinate.longitude)
                .distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude))
            
            if distance > 5 {  // 5 meters threshold
                logger.debug("Distance threshold exceeded, resetting location")
                self.selectedLocation = nil
                self.currentCustomLocation = nil
                showCustomPin = true
            }
        }
    }
    
    func updateCustomLocation(for coordinate: CLLocationCoordinate2D) async {
        let now = Date()
        guard now.timeIntervalSince(lastGeocodingTime) > 0.5 else { return }
        
        guard isValidCoordinate(coordinate) else {
            logger.debug("Invalid coordinate for custom location")
            return
        }
        
        let locationName = await getLocationName(for: coordinate)
        await MainActor.run {
            currentCustomLocation = LocationSelection(
                coordinate: coordinate,
                name: locationName,
                isRecommended: false
            )
            lastGeocodingTime = now
            logger.debug("Updated custom location: \(locationName)")
        }
    }
    
    var menuLabel: String {
        if let selected = selectedLocation, selected.isRecommended {
            return selected.name
        }
        return "Recommended Locations"
    }
    
    // Helper functions
    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude.isFinite && 
               coordinate.longitude.isFinite &&
               coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
               coordinate.longitude >= -180 && coordinate.longitude <= 180
    }
    
    private func getLocationName(for coordinate: CLLocationCoordinate2D) async -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var components: [String] = []
                
                if let name = placemark.name { components.append(name) }
                if let thoroughfare = placemark.thoroughfare { components.append(thoroughfare) }
                if let locality = placemark.locality { components.append(locality) }
                
                return components.isEmpty ? "Selected Location" : components.joined(separator: ", ")
            }
        } catch {
            logger.error("Reverse geocoding error: \(error.localizedDescription)")
        }
        
        return "Selected Location"
    }
}