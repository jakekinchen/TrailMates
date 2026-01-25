import Foundation
import FirebaseFirestore

/// Represents a landmark/point of interest that users can visit
struct Landmark: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var description: String?
    var latitude: Double
    var longitude: Double
    var imageURL: String?
    var category: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case latitude
        case longitude
        case imageURL
        case category
        case createdAt
    }
}
