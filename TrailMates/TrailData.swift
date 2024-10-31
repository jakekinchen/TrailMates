// TrailData.swift

import Foundation
import MapKit

struct TrailData {
    static let outerCoordinates: [CLLocationCoordinate2D] = [
        // Outer Boundary Coordinates (your coordinates here)
        CLLocationCoordinate2D(latitude: 30.262040, longitude: -97.745396),
        // ... (rest of the outerCoordinates)
        CLLocationCoordinate2D(latitude: 30.262040, longitude: -97.745396) // Ensure the loop is closed
    ]
    
    static let innerCoordinatesList: [[CLLocationCoordinate2D]] = [
        // Inner Ring 1 Coordinates
        [
            CLLocationCoordinate2D(latitude: 30.270384, longitude: -97.768305),
            // ... (rest of innerCoordinates1)
            CLLocationCoordinate2D(latitude: 30.270384, longitude: -97.768305) // Ensure the loop is closed
        ],
        // Inner Ring 2 Coordinates
        [
            CLLocationCoordinate2D(latitude: 30.264399, longitude: -97.754046),
            // ... (rest of innerCoordinates2)
            CLLocationCoordinate2D(latitude: 30.264399, longitude: -97.754046) // Ensure the loop is closed
        ],
        // ... (Add inner rings 3, 4, 5 similarly)
    ]
}
