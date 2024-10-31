import Foundation
import CoreLocation

struct Event: Codable, Identifiable {
    let id: UUID
    var title: String
    var description: String?
    var location: CLLocationCoordinate2D
    var date: Date
    var hostId: UUID
    var attendeeIds: [UUID]
    var isActive: Bool
    
    var isPrivate: Bool
}