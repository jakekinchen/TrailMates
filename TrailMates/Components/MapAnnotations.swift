//
//  FriendAnnotation.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/13/24.
//


// MARK: - MapAnnotations.swift
import MapKit

// MARK: - Friend Annotation
final class FriendAnnotation: MKPointAnnotation {
    let friend: User
    let isMock: Bool
    
    init(friend: User, coordinate: CLLocationCoordinate2D, isMock: Bool = false) {
        self.friend = friend
        self.isMock = isMock
        super.init()
        self.coordinate = coordinate
        self.title = "\(friend.firstName) \(friend.lastName)"
    }
}

// MARK: - Event Annotation
final class EventAnnotation: MKPointAnnotation {
    let event: Event
    
    init(event: Event) {
        self.event = event
        super.init()
        self.coordinate = event.location
        self.title = event.title
    }
}

// MARK: - Recommended Location Annotation
final class RecommendedLocationAnnotation: MKPointAnnotation {
    let locationItem: LocationItem
    
    init(locationItem: LocationItem) {
        self.locationItem = locationItem
        super.init()
        self.coordinate = locationItem.coordinate
        self.title = locationItem.name
    }
}