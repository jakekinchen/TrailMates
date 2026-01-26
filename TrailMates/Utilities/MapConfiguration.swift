//
//  MapConfiguration.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/13/24.
//


// MARK: - MapConfiguration.swift
import MapKit
import SwiftUI

@MainActor
struct MapConfiguration {
    // MARK: - Display Options
    var showUserLocation: Bool = false
    var showFriendLocations: Bool = false
    var showRecommendedLocations: Bool = false
    var showEventLocations: Bool = false
    var showMockFriendLocations: Bool = false
    var isLocationPickerEnabled: Bool = false
    var onRegionChanged: ((MKCoordinateRegion) -> Void)?
    var showCustomPin: Binding<Bool>?
    
    // MARK: - Data Sources
    var friends: [User]?
    var events: [Event]?
    
    // MARK: - Map State
    var selectedLocation: Binding<LocationItem?>?
    var isDragging: Binding<Bool>?
    
    // MARK: - Callbacks
    var onLocationSelected: ((LocationItem) -> Void)?
    
    // MARK: - Map Constants
    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.26074, longitude: -97.74550),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    static let boundaryRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.26074, longitude: -97.74550),
        span: MKCoordinateSpan(latitudeDelta: 0.0325, longitudeDelta: 0.0601)
    )
    
    static let zoomRange = MKMapView.CameraZoomRange(
        minCenterCoordinateDistance: 100,
        maxCenterCoordinateDistance: 27500
    )
    
    // MARK: - Initializer
    init(
        showUserLocation: Bool = false,
        showFriendLocations: Bool = false,
        showRecommendedLocations: Bool = false,
        showEventLocations: Bool = false,
        showMockFriendLocations: Bool = false,
        isLocationPickerEnabled: Bool = false,
        friends: [User]? = nil,
        events: [Event]? = nil,
        selectedLocation: Binding<LocationItem?>? = nil,
        showCustomPin: Binding<Bool>? = nil,
        isDragging: Binding<Bool>? = nil,
        onLocationSelected: ((LocationItem) -> Void)? = nil,
        onRegionChanged: ((MKCoordinateRegion) -> Void)? = nil
    ) {
        self.showUserLocation = showUserLocation
        self.showFriendLocations = showFriendLocations
        self.showRecommendedLocations = showRecommendedLocations
        self.showEventLocations = showEventLocations
        self.showMockFriendLocations = showMockFriendLocations
        self.isLocationPickerEnabled = isLocationPickerEnabled
        self.friends = friends
        self.events = events
        self.selectedLocation = selectedLocation
        self.showCustomPin = showCustomPin
        self.isDragging = isDragging
        self.onLocationSelected = onLocationSelected
        self.onRegionChanged = onRegionChanged
    }
}
