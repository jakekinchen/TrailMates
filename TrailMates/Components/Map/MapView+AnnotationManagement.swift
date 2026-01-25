//
//  MapView+AnnotationManagement.swift
//  TrailMates
//
//  Extension on UnifiedMapView providing helper methods for adding annotations to the map.
//
//  Methods:
//  - addFriendAnnotations: Adds friend markers to the map
//  - addEventAnnotations: Adds event markers to the map
//  - addRecommendedLocationAnnotations: Adds recommended location markers

import MapKit

extension UnifiedMapView {
    /// Helper methods for managing map annotations
    func addFriendAnnotations(_ friends: [User], to mapView: MKMapView, isMock: Bool = false) {
        let annotations = friends.compactMap { friend -> FriendAnnotation? in
            guard let location = friend.location else { return nil }
            return FriendAnnotation(friend: friend, coordinate: location, isMock: isMock)
        }
        mapView.addAnnotations(annotations)
    }
    
    func addEventAnnotations(_ events: [Event], to mapView: MKMapView) {
        let annotations = events.map { EventAnnotation(event: $0) }
        mapView.addAnnotations(annotations)
    }
    
    func addRecommendedLocationAnnotations(to mapView: MKMapView) {
        let annotations = Locations.items.map { RecommendedLocationAnnotation(locationItem: $0) }
        mapView.addAnnotations(annotations)
    }
}

