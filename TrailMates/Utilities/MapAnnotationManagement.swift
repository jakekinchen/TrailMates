//
//  CustomPin.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/13/24.
//


// MARK: - MapAnnotationManagement.swift
import MapKit

extension MapCoordinator {
    // MARK: - Annotation Creation Helpers
    func createFriendAnnotationView(for annotation: FriendAnnotation, in mapView: MKMapView) -> MKAnnotationView? {
        let identifier = "FriendAnnotation"
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? FriendAnnotationView
            ?? FriendAnnotationView(annotation: annotation, reuseIdentifier: identifier, isMock: annotation.isMock)
        annotationView.configure(with: annotation.friend)
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
    func addFriendAnnotations(_ friends: [User], to mapView: MKMapView, isMock: Bool = false) {
        let annotations = friends.compactMap { friend -> FriendAnnotation? in
            guard let location = friend.location else { return nil }
            return FriendAnnotation(friend: friend, coordinate: location, isMock: isMock)
        }
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

// MARK: - CustomPin.swift
struct CustomPin: View {
    let isSelected: Bool
    @Binding var isDragging: Bool
    
    private let strokeLength: CGFloat = 16
    private let circleSize: CGFloat = 10
    private let topCircleSize: CGFloat = 16
    
    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color("pine"))
                .frame(width: topCircleSize, height: topCircleSize)
            
            Rectangle()
                .fill(Color("pine"))
                .frame(width: 2, height: strokeLength)
                .offset(y: isDragging ? -10 : 0)
            
            Circle()
                .fill(Color("pine").opacity(0.3))
                .frame(width: circleSize, height: circleSize)
                .opacity(isDragging ? 1 : 0)
                .scaleEffect(isDragging ? 1 : 0.5)
                .offset(y: isDragging ? -10 : 0)
        }
        .shadow(color: .black.opacity(0.2), radius: isDragging ? 4 : 0, y: isDragging ? 2 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }
}