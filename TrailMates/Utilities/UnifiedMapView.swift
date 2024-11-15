// MARK: - UnifiedMapView.swift
import SwiftUI
import MapKit

struct UnifiedMapView: UIViewRepresentable {
    // MARK: - Properties
    let configuration: MapConfiguration
    
    // MARK: - UIViewRepresentable Implementation
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Configure basic map settings
        configureMapView(mapView)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if needed and in location picker mode
        if configuration.isLocationPickerEnabled {
            context.coordinator.updateMapRegion(mapView)
        }
        
        // Update annotations
        context.coordinator.updateAnnotations(mapView)
    }
    
    func makeCoordinator() -> MapCoordinator {
        MapCoordinator(configuration: configuration)
    }
    
    // MARK: - Private Helper Methods
    private func configureMapView(_ mapView: MKMapView) {
        // Set initial region
        mapView.setRegion(configuration.mapRegion, animated: false)
        
        // Configure boundary
        let cameraBoundary = MKMapView.CameraBoundary(coordinateRegion: MapConfiguration.boundaryRegion)
        mapView.setCameraBoundary(cameraBoundary, animated: true)
        
        // Configure zoom range
        mapView.setCameraZoomRange(MapConfiguration.zoomRange, animated: true)
        
        // Configure user location
        mapView.showsUserLocation = configuration.showUserLocation
        
        // Add trail overlay
        let trailPolygon = createTrailPolygon()
        mapView.addOverlay(trailPolygon)
    }
    
    private func createTrailPolygon() -> MKPolygon {
        let innerPolygons = TrailData.innerCoordinatesList.map { coordinates in
            MKPolygon(coordinates: coordinates, count: coordinates.count)
        }
        
        return MKPolygon(
            coordinates: TrailData.outerCoordinates,
            count: TrailData.outerCoordinates.count,
            interiorPolygons: innerPolygons
        )
    }
}

// MARK: - MapCoordinator
extension UnifiedMapView {
    class MapCoordinator: NSObject, MKMapViewDelegate {
        // MARK: - Properties
        let configuration: MapConfiguration
        
        // MARK: - Initialization
        init(configuration: MapConfiguration) {
            self.configuration = configuration
        }
        
        // MARK: - Map Update Methods
        func updateMapRegion(_ mapView: MKMapView) {
            if !regionsAreEqual(mapView.region, configuration.mapRegion) {
                mapView.setRegion(configuration.mapRegion, animated: true)
            }
        }
        
        func updateAnnotations(_ mapView: MKMapView) {
            // Remove existing annotations
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
            
            // Add new annotations based on configuration
            if configuration.showFriendLocations, let friends = configuration.friends {
                addFriendAnnotations(friends, to: mapView, isMock: false)
            }
            
            if configuration.showMockFriendLocations {
                Task {
                    let mockFriends = await getMockFriends()
                    await MainActor.run {
                        addFriendAnnotations(mockFriends, to: mapView, isMock: true)
                    }
                }
            }
            
            if configuration.showRecommendedLocations {
                addRecommendedLocationAnnotations(to: mapView)
            }
            
            if configuration.showEventLocations, let events = configuration.events {
                addEventAnnotations(events, to: mapView)
            }
        }
        
        // MARK: - MKMapViewDelegate Methods
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            switch annotation {
            case let friendAnnotation as TrailMapView.FriendAnnotation:
                return createFriendAnnotationView(for: friendAnnotation, in: mapView)
            case _ as RecommendedLocationAnnotation:
                return createRecommendedLocationView(for: annotation, in: mapView)
            case _ as MKUserLocation:
                return nil
            default:
                return createDefaultAnnotationView(for: annotation, in: mapView)
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = UIColor(named: "pine")
                renderer.fillColor = UIColor(named: "pine")?.withAlphaComponent(0.3)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // MARK: - Region Change Handling
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            configuration.isDragging?.wrappedValue = true
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            handleRegionChange(mapView)
        }
        
        // MARK: - Selection Handling
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            if let title = annotation.title,
               let location = Locations.items.first(where: { $0.name == title ?? "" }) {
                configuration.onLocationSelected?(location)
                mapView.deselectAnnotation(annotation, animated: true)
            }
        }
        
        // MARK: - Private Helper Methods
        private func handleRegionChange(_ mapView: MKMapView) {
            // Update dragging state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.configuration.isDragging?.wrappedValue = false
            }
            
            // Handle location selection updates
            if configuration.isLocationPickerEnabled,
               let selectedLocation = configuration.selectedLocation?.wrappedValue {
                let locationPoint = MKMapPoint(selectedLocation.coordinate)
                let centerPoint = MKMapPoint(mapView.region.center)
                if locationPoint.distance(to: centerPoint) > 10 {
                    configuration.selectedLocation?.wrappedValue = nil
                }
            }
        }
        
        private func regionsAreEqual(_ region1: MKCoordinateRegion, _ region2: MKCoordinateRegion) -> Bool {
            let centerEqual = abs(region1.center.latitude - region2.center.latitude) < 0.000001 &&
                            abs(region1.center.longitude - region2.center.longitude) < 0.000001
            let spanEqual = abs(region1.span.latitudeDelta - region2.span.latitudeDelta) < 0.000001 &&
                           abs(region1.span.longitudeDelta - region2.span.longitudeDelta) < 0.000001
            return centerEqual && spanEqual
        }
    }
}

// MARK: - Usage Example
struct MapViewExample: View {
    @State private var selectedLocation: LocationItem?
    @State private var isDragging = false
    
    var body: some View {
        UnifiedMapView(configuration: MapConfiguration(
            showUserLocation: true,
            showFriendLocations: true,
            showRecommendedLocations: true,
            selectedLocation: $selectedLocation,
            isDragging: $isDragging,
            onLocationSelected: { location in
                // Handle location selection
            }
        ))
    }
}