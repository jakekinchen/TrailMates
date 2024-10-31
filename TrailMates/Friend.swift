import Foundation
import CoreLocation // To use CLLocationCoordinate2D

struct Friend: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let profileImageName: String
    let isActive: Bool // Add any other relevant properties
}