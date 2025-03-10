//
//  UnifiedMapView.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/13/24.
//


// MARK: - UnifiedMapView.swift
import SwiftUI
import MapKit

struct UnifiedMapView: UIViewRepresentable {
    // MARK: - Properties
    @Binding var mapView: MKMapView?
    var configuration: MapConfiguration
    var initialRegion: MKCoordinateRegion?
    var interactionModes: [MapInteractionMode]
    
    init(mapView: Binding<MKMapView?>, 
         configuration: MapConfiguration,
         initialRegion: MKCoordinateRegion? = nil,
         interactionModes: [MapInteractionMode] = [.all]) {
        self._mapView = mapView
        self.configuration = configuration
        self.initialRegion = initialRegion
        self.interactionModes = interactionModes
    }
    
    // MARK: - UIViewRepresentable Implementation
    func makeUIView(context: Context) -> MKMapView {
            let mapView = MKMapView()
            
            DispatchQueue.main.async {
                self.mapView = mapView
            }
        
            mapView.delegate = context.coordinator
            
            // Configure interaction modes
            mapView.isScrollEnabled = interactionModes.contains(.pan)
            mapView.isZoomEnabled = interactionModes.contains(.zoom)
            mapView.isRotateEnabled = interactionModes.contains(.rotate)
            mapView.isPitchEnabled = interactionModes.contains(.pitch)
            mapView.isUserInteractionEnabled = !interactionModes.isEmpty
            
            mapView.register(FriendAnnotationView.self, forAnnotationViewWithReuseIdentifier: "FriendAnnotation")
            mapView.register(EventAnnotationView.self, forAnnotationViewWithReuseIdentifier: "EventAnnotation")
            mapView.register(RecommendedLocationView.self, forAnnotationViewWithReuseIdentifier: "RecommendedLocation")
            
            // Configure basic map settings
            configureMapView(mapView)
            
            return mapView
        }
    
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
            // Update annotations
            context.coordinator.updateAnnotations(mapView)
        }
    
    func makeCoordinator() -> MapCoordinator {
            MapCoordinator(configuration: configuration)
        }
    
    // MARK: - Private Helper Methods
    private func configureMapView(_ mapView: MKMapView) {
            // Set initial region
            mapView.setRegion(initialRegion ?? MapConfiguration.defaultRegion, animated: false)
            
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
            private var shouldIgnoreRegionChanges = false
            private var isRegionChangeFromUserInteraction = false
            let configuration: MapConfiguration

            init(configuration: MapConfiguration) {
                    self.configuration = configuration
                    super.init()
                }
        
        func setRegionProgrammatically(_ region: MKCoordinateRegion, mapView: MKMapView) {
                    print("🎯 Setting region programmatically")
                    shouldIgnoreRegionChanges = true
                    mapView.setRegion(region, animated: true)
                }
        
        // MARK: - Map Updates
        func updateMapRegion(_ mapView: MKMapView) {
            if let selectedAnnotation = mapView.selectedAnnotations.first {
                shouldIgnoreRegionChanges = true
                mapView.setRegion(MKCoordinateRegion(
                    center: selectedAnnotation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ), animated: true)
            }
        }
        
        func updateAnnotations(_ mapView: MKMapView) {
                // Remove existing annotations except user location
                mapView.removeAnnotations(mapView.annotations.filter {
                    !($0 is MKUserLocation)
                })
                
                // Add friend annotations if enabled
                if configuration.showFriendLocations, let friends = configuration.friends {
                    addFriendAnnotations(friends, to: mapView, isMock: false)
                }
                
                // Add event annotations if enabled
                if configuration.showEventLocations, let events = configuration.events {
                    let eventAnnotations = events.map { EventAnnotation(event: $0) }
                    mapView.addAnnotations(eventAnnotations)
                }
                
                // Add recommended location annotations if enabled
                if configuration.showRecommendedLocations {
                    let recommendedLocations = Locations.items.map {
                        RecommendedLocationAnnotation(locationItem: $0)
                    }
                    mapView.addAnnotations(recommendedLocations)
                }
            }
        
        // MARK: - MKMapViewDelegates
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
                    switch annotation {
                    case _ as RecommendedLocationAnnotation:
                        let view = mapView.dequeueReusableAnnotationView(withIdentifier: "RecommendedLocation", for: annotation) as! RecommendedLocationView
                        // Ensure selection animation is enabled
                        view.animatesWhenAdded = true
                        return view
                    case let friendAnnotation as FriendAnnotation:
                        return createFriendAnnotationView(for: friendAnnotation, in: mapView)
                    case let eventAnnotation as EventAnnotation:
                        return createEventAnnotationView(for: eventAnnotation, in: mapView)
                    case is MKUserLocation:
                        return nil
                    default:
                        return nil
                    }
                }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
                if let polygon = overlay as? MKPolygon {
                    let renderer = MKPolygonRenderer(polygon: polygon)
                    renderer.strokeColor = UIColor(named: "sage")
                    renderer.fillColor = UIColor(named: "sage")?.withAlphaComponent(0.3)
                    renderer.lineWidth = 1
                    return renderer
                }
                return MKOverlayRenderer(overlay: overlay)
            }
            
        
        // For syncing map movements
        

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            if !shouldIgnoreRegionChanges {
                print("🎯 User initiated region change")
                isRegionChangeFromUserInteraction = true
                DispatchQueue.main.async {
                    self.configuration.isDragging?.wrappedValue = true
                }
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if shouldIgnoreRegionChanges {
                print("🎯 Ignored programmatic region change")
                shouldIgnoreRegionChanges = false
                return
            }

            if isRegionChangeFromUserInteraction {
                isRegionChangeFromUserInteraction = false
                print("🎯 User region change completed")
                DispatchQueue.main.async {
                    self.configuration.isDragging?.wrappedValue = false
                    self.configuration.onRegionChanged?(mapView.region)
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // This delegate method will be called when an annotation view is selected
            print("🎯 Annotation selected")
            if let annotation = view.annotation,
               let title = annotation.title,
               let location = Locations.items.first(where: { $0.title == title ?? "" }) {
               print("🎯 Found location: \(location.title)")
                        // Center map on selected annotation
                        let newRegion = MKCoordinateRegion(
                            center: annotation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                        mapView.setRegion(newRegion, animated: true)
                        
                        // Hide custom pin when selecting a recommended location
                        DispatchQueue.main.async {
                            self.configuration.showCustomPin?.wrappedValue = false
                            print("🎯 showCustomPin after set: \(self.configuration.showCustomPin?.wrappedValue ?? false)")
                        }
                        
                        // Update selected location
                        configuration.onLocationSelected?(location)
                        
                        // Don't deselect the annotation immediately to allow the visual feedback
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            mapView.deselectAnnotation(annotation, animated: true)
                        }
                    }
                }
        
    }
    
}

extension MKMapView {
    func setRegionProgrammatically(_ region: MKCoordinateRegion) {
        if let delegate = self.delegate as? UnifiedMapView.MapCoordinator {
            delegate.setRegionProgrammatically(region, mapView: self)
        }
    }
}

// MARK: - Map Interaction Modes
enum MapInteractionMode {
    case pan
    case zoom
    case rotate
    case pitch
    case all
    
    static let allModes: Set<MapInteractionMode> = [.pan, .zoom, .rotate, .pitch]
}

extension Array where Element == MapInteractionMode {
    func contains(_ mode: MapInteractionMode) -> Bool {
        if mode == .all {
            return self.contains(.all)
        }
        if self.contains(where: { $0 == .all }) {
            return true
        }
        return self.contains(where: { $0 == mode })
    }
}
