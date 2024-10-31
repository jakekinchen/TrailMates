import Foundation
import CoreLocation

struct User: Codable, Identifiable {
    let id: UUID
    var firstName: String
    var lastName: String
    var bio: String?
    var profileImageData: Data?
    var location: CLLocationCoordinate2D?
    var isActive: Bool
    var friends: [UUID]
    var doNotDisturb: Bool
    let phoneNumber: String
    var createdEventIds: [UUID] = []
    var attendingEventIds: [UUID] = []
}
