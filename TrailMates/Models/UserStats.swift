import Foundation

struct UserStats: Codable, Equatable {
    let joinDate: String
    let landmarkCompletion: Int
    let friendCount: Int
    let hostedEventCount: Int
    let attendedEventCount: Int

    enum CodingKeys: String, CodingKey {
        case joinDate
        case landmarkCompletion
        case friendCount
        case hostedEventCount
        case attendedEventCount
    }
}
