//
//  WelcomeMapCoordinator.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/14/24.
//


import MapKit
import SwiftUI

@MainActor
class WelcomeMapCoordinator: ObservableObject {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.25903, longitude: -97.74349),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var isDragging: Bool = false
    @Published var mapView: MKMapView?


    func updateRegion(_ newRegion: MKCoordinateRegion) {
        mapView?.setRegion(newRegion, animated: true)
    }
}
