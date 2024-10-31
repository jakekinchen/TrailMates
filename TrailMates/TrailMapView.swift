// TrailMapView.swift

import SwiftUI
import MapKit

struct TrailMapView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.26613, longitude: -97.75543),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    
    var body: some View {
        Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: true) {
            // Overlay the trail area
            MapPolygon(polygon: trailPolygon)
                .stroke(Color("pine"), lineWidth: 2)
                .fill(Color("pine").opacity(0.3))
        }
        .ignoresSafeArea(edges: .all)
    }
    
    private var trailPolygon: MKPolygon {
        let outerPolygon = MKPolygon(coordinates: TrailData.outerCoordinates, count: TrailData.outerCoordinates.count)
        
        let innerPolygons = TrailData.innerCoordinatesList.map { coordinates in
            MKPolygon(coordinates: coordinates, count: coordinates.count)
        }
        
        return MKPolygon(
            coordinates: TrailData.outerCoordinates,
            count: TrailData.outerCoordinates.count,
            interiorPolygons: innerPolygons
        )
    }
}
