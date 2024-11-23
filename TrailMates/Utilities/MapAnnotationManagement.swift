//
//  MapAnnotationManagement.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/13/24.
//


// MARK: - MapAnnotationManagement.swift
import MapKit

extension UnifiedMapView.MapCoordinator {
    // MARK: - Annotation Creation Helpers
    func createFriendAnnotationView(for annotation: MKAnnotation, in mapView: MKMapView) -> MKAnnotationView {
            guard let friendAnnotation = annotation as? FriendAnnotation else {
                return MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
            }
            
            // Create the annotation view with the isMock parameter
            let annotationView = mapView.dequeueReusableAnnotationView(
                withIdentifier: "FriendAnnotation",
                for: annotation
            ) as? FriendAnnotationView ?? FriendAnnotationView(
                annotation: annotation,
                reuseIdentifier: "FriendAnnotation",
                isMock: friendAnnotation.isMock
            )
            
            // Configure the view with the friend
            annotationView.configure(with: friendAnnotation.friend)
            
            return annotationView
        }
    
    func createEventAnnotationView(for annotation: EventAnnotation, in mapView: MKMapView) -> MKAnnotationView? {
        let identifier = "EventAnnotation"
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? EventAnnotationView
            ?? EventAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        annotationView.configure(with: annotation.event)
        return annotationView
    }
    
    func createRecommendedLocationView(for annotation: RecommendedLocationAnnotation, in mapView: MKMapView) -> MKAnnotationView? {
        let identifier = "RecommendedLocation"
        return mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? RecommendedLocationView
            ?? RecommendedLocationView(annotation: annotation, reuseIdentifier: identifier)
    }
    
    // MARK: - Annotation Management
    func addFriendAnnotations(_ friends: [User], to mapView: MKMapView, isMock: Bool) {
            // Filter for active friends if not mock data
            let friendsToShow = isMock ? friends : friends.filter { $0.isActive }
            
            // Create annotations for friends with locations
            let annotations = friendsToShow.compactMap { friend -> FriendAnnotation? in
                // Use the friend's location if available, otherwise use a default coordinate
                let coordinate = friend.location ?? CLLocationCoordinate2D(latitude: 30.26074, longitude: -97.74550)
                return FriendAnnotation(friend: friend, coordinate: coordinate, isMock: isMock)
            }
            
            // Add new annotations
            mapView.addAnnotations(annotations)
        }
    
    func addEventAnnotations(_ events: [Event], to mapView: MKMapView) {
        let annotations = events.map { event in
            EventAnnotation(event: event)
        }
        mapView.addAnnotations(annotations)
    }
    
    func addRecommendedLocationAnnotations(to mapView: MKMapView) {
        let annotations = Locations.items.map { location in
            RecommendedLocationAnnotation(locationItem: location)
        }
        mapView.addAnnotations(annotations)
    }
    
    // MARK: - Region Comparison
    func regionsAreEqual(_ region1: MKCoordinateRegion, _ region2: MKCoordinateRegion) -> Bool {
        let centerEqual = abs(region1.center.latitude - region2.center.latitude) < 0.000001 &&
                          abs(region1.center.longitude - region2.center.longitude) < 0.000001
        let spanEqual = abs(region1.span.latitudeDelta - region2.span.latitudeDelta) < 0.000001 &&
                        abs(region1.span.longitudeDelta - region2.span.longitudeDelta) < 0.000001
        return centerEqual && spanEqual
    }
}
