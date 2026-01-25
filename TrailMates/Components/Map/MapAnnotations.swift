//
//  MapAnnotations.swift
//  TrailMates
//
//  Custom MKPointAnnotation subclasses for map data models.
//
//  Components:
//  - FriendAnnotation: Annotation containing friend User data
//  - EventAnnotation: Annotation containing Event data
//  - RecommendedLocationAnnotation: Annotation containing LocationItem data

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
        self.title = locationItem.title
    }
}
