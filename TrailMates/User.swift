import Foundation
import CoreLocation

struct User: Identifiable {
    let id: UUID
    var username: String
    var fullName: String
    var email: String
    var profileImageName: String
    var bio: String?
    var location: CLLocationCoordinate2D?
    var isActive: Bool
    var friends: [UUID] // List of friend user IDs
    // Add other properties as needed
}