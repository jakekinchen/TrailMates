// MARK: - MapConfiguration.swift
import MapKit
import SwiftUI

struct MapConfiguration {
    // MARK: - Display Options
    var showUserLocation: Bool = false
    var showFriendLocations: Bool = false
    var showRecommendedLocations: Bool = false
    var showEventLocations: Bool = false
    var showMockFriendLocations: Bool = false
    var isLocationPickerEnabled: Bool = false
    
    // MARK: - Data Sources
    var friends: [User]?
    var events: [Event]?
    
    // MARK: - Map State
    var mapRegion: MKCoordinateRegion
    var selectedLocation: Binding<LocationItem?>?
    var isDragging: Binding<Bool>?
    
    // MARK: - Callbacks
    var onLocationSelected: ((LocationItem) -> Void)?
    
    // MARK: - Map Constants
    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.25903, longitude: -97.74349),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    static let boundaryRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.25903, longitude: -97.74349),
        span: MKCoordinateSpan(latitudeDelta: 0.0325, longitudeDelta: 0.0601)
    )
    
    static let zoomRange = MKMapView.CameraZoomRange(
        minCenterCoordinateDistance: 100,
        maxCenterCoordinateDistance: 12500
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
        mapRegion: MKCoordinateRegion = defaultRegion,
        selectedLocation: Binding<LocationItem?>? = nil,
        isDragging: Binding<Bool>? = nil,
        onLocationSelected: ((LocationItem) -> Void)? = nil
    ) {
        self.showUserLocation = showUserLocation
        self.showFriendLocations = showFriendLocations
        self.showRecommendedLocations = showRecommendedLocations
        self.showEventLocations = showEventLocations
        self.showMockFriendLocations = showMockFriendLocations
        self.isLocationPickerEnabled = isLocationPickerEnabled
        self.friends = friends
        self.events = events
        self.mapRegion = mapRegion
        self.selectedLocation = selectedLocation
        self.isDragging = isDragging
        self.onLocationSelected = onLocationSelected
    }
}