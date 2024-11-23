// MARK: - MapView+AnnotationManagement.swift
extension UnifiedMapView {
    // Helper methods for managing annotations
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

