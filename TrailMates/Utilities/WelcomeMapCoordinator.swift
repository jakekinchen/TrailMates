import MapKit
import SwiftUI

class WelcomeMapCoordinator: ObservableObject {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.25903, longitude: -97.74349),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var isDragging = false
}