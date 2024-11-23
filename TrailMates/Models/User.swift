import Foundation
import CoreLocation
import MapKit
import UIKit

struct User: Codable, Identifiable, Equatable {
    let id: UUID
    var firstName: String
    var lastName: String
    var username: String
    var profileImage: UIImage?
    var profileImageData: Data?
    var profileImageUrl: String?
    var profileThumbnailUrl: String?
    var isActive: Bool
    var friends: [UUID]
    var doNotDisturb: Bool
    var phoneNumber: String
    var createdEventIds: [UUID]
    var attendingEventIds: [UUID]
    let joinDate: Date
    var visitedLandmarkIds: [UUID]
    
    // Notification Settings
    var receiveFriendRequests: Bool
    var receiveFriendEvents: Bool
    var receiveEventUpdates: Bool
    
    // Privacy Settings
    var shareLocationWithFriends: Bool
    var shareLocationWithEventHost: Bool
    var shareLocationWithEventGroup: Bool
    var allowFriendsToInviteOthers: Bool
    
    // Facebook ID
    var facebookId: String?
    
    // Location handled by LocationManager
    var location: CLLocationCoordinate2D?
    
    // Essential computed properties only
    var friendCount: Int {
        friends.count
    }
    
    var isActiveBasedOnLocation: Bool {
        guard let location = self.location else { return false }
        let outerPolygon = MKPolygon(coordinates: TrailData.outerCoordinates, count: TrailData.outerCoordinates.count)
        let friendPoint = MKMapPoint(location)
        
        guard outerPolygon.contains(friendPoint) else { return false }
        
        for innerCoordinates in TrailData.innerCoordinatesList {
            let innerPolygon = MKPolygon(coordinates: innerCoordinates, count: innerCoordinates.count)
            if innerPolygon.contains(friendPoint) {
                return true
            }
        }
        return false
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, username, profileImageData, profileImageUrl, profileThumbnailUrl
        case isActive, friends, doNotDisturb, phoneNumber, createdEventIds, attendingEventIds
        case joinDate, visitedLandmarkIds, receiveFriendRequests, receiveFriendEvents
        case receiveEventUpdates, shareLocationWithFriends, shareLocationWithEventHost
        case shareLocationWithEventGroup, allowFriendsToInviteOthers, facebookId
        case location, latitude, longitude
    }
    
    // Custom initializer with default values
    init(id: UUID,
         firstName: String,
         lastName: String,
         username: String,
         profileImage: UIImage? = nil,
         profileImageData: Data? = nil,
         profileImageUrl: String? = nil,
         profileThumbnailUrl: String? = nil,
         isActive: Bool = true,
         friends: [UUID] = [],
         doNotDisturb: Bool = false,
         phoneNumber: String,
         createdEventIds: [UUID] = [],
         attendingEventIds: [UUID] = [],
         joinDate: Date,
         visitedLandmarkIds: [UUID] = [],
         receiveFriendRequests: Bool = true,
         receiveFriendEvents: Bool = true,
         receiveEventUpdates: Bool = true,
         shareLocationWithFriends: Bool = true,
         shareLocationWithEventHost: Bool = true,
         shareLocationWithEventGroup: Bool = false,
         allowFriendsToInviteOthers: Bool = true,
         location: CLLocationCoordinate2D? = nil) {
        
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.profileImage = profileImage
        self.profileImageData = profileImageData
        self.profileImageUrl = profileImageUrl
        self.profileThumbnailUrl = profileThumbnailUrl
        self.isActive = isActive
        self.friends = friends
        self.doNotDisturb = doNotDisturb
        self.phoneNumber = phoneNumber
        self.createdEventIds = createdEventIds
        self.attendingEventIds = attendingEventIds
        self.joinDate = joinDate
        self.visitedLandmarkIds = visitedLandmarkIds
        self.receiveFriendRequests = receiveFriendRequests
        self.receiveFriendEvents = receiveFriendEvents
        self.receiveEventUpdates = receiveEventUpdates
        self.shareLocationWithFriends = shareLocationWithFriends
        self.shareLocationWithEventHost = shareLocationWithEventHost
        self.shareLocationWithEventGroup = shareLocationWithEventGroup
        self.allowFriendsToInviteOthers = allowFriendsToInviteOthers
        self.location = location
    }
    
    // Implement custom decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode required properties
        id = try container.decode(UUID.self, forKey: .id)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        username = try container.decode(String.self, forKey: .username)
        profileImageData = try container.decodeIfPresent(Data.self, forKey: .profileImageData)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        profileThumbnailUrl = try container.decodeIfPresent(String.self, forKey: .profileThumbnailUrl)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        friends = try container.decode([UUID].self, forKey: .friends)
        doNotDisturb = try container.decode(Bool.self, forKey: .doNotDisturb)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        createdEventIds = try container.decode([UUID].self, forKey: .createdEventIds)
        attendingEventIds = try container.decode([UUID].self, forKey: .attendingEventIds)
        joinDate = try container.decode(Date.self, forKey: .joinDate)
        visitedLandmarkIds = try container.decode([UUID].self, forKey: .visitedLandmarkIds)
        
        // Decode notification settings with default values if not present
        receiveFriendRequests = try container.decodeIfPresent(Bool.self, forKey: .receiveFriendRequests) ?? true
        receiveFriendEvents = try container.decodeIfPresent(Bool.self, forKey: .receiveFriendEvents) ?? true
        receiveEventUpdates = try container.decodeIfPresent(Bool.self, forKey: .receiveEventUpdates) ?? true
        
        // Decode privacy settings with default values if not present
        shareLocationWithFriends = try container.decodeIfPresent(Bool.self, forKey: .shareLocationWithFriends) ?? true
        shareLocationWithEventHost = try container.decodeIfPresent(Bool.self, forKey: .shareLocationWithEventHost) ?? true
        shareLocationWithEventGroup = try container.decodeIfPresent(Bool.self, forKey: .shareLocationWithEventGroup) ?? false
        allowFriendsToInviteOthers = try container.decodeIfPresent(Bool.self, forKey: .allowFriendsToInviteOthers) ?? true
        
        // Handle location decoding
        if let latitude = try container.decodeIfPresent(Double.self, forKey: .latitude),
           let longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) {
            location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            location = nil
        }
        
        facebookId = try container.decodeIfPresent(String.self, forKey: .facebookId)
        
        if let imageData = profileImageData {
            profileImage = UIImage(data: imageData)
        }
    }
    
    // Implement custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(username, forKey: .username)
        try container.encode(profileImageData, forKey: .profileImageData)
        try container.encode(profileImageUrl, forKey: .profileImageUrl)
        try container.encode(profileThumbnailUrl, forKey: .profileThumbnailUrl)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(friends, forKey: .friends)
        try container.encode(doNotDisturb, forKey: .doNotDisturb)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encode(createdEventIds, forKey: .createdEventIds)
        try container.encode(attendingEventIds, forKey: .attendingEventIds)
        try container.encode(joinDate, forKey: .joinDate)
        try container.encode(visitedLandmarkIds, forKey: .visitedLandmarkIds)
        
        // Encode notification settings
        try container.encode(receiveFriendRequests, forKey: .receiveFriendRequests)
        try container.encode(receiveFriendEvents, forKey: .receiveFriendEvents)
        try container.encode(receiveEventUpdates, forKey: .receiveEventUpdates)
        
        // Encode privacy settings
        try container.encode(shareLocationWithFriends, forKey: .shareLocationWithFriends)
        try container.encode(shareLocationWithEventHost, forKey: .shareLocationWithEventHost)
        try container.encode(shareLocationWithEventGroup, forKey: .shareLocationWithEventGroup)
        try container.encode(allowFriendsToInviteOthers, forKey: .allowFriendsToInviteOthers)
        
        // Encode location if present
        if let location = location {
            try container.encode(location.latitude, forKey: .latitude)
            try container.encode(location.longitude, forKey: .longitude)
        }
        
        try container.encodeIfPresent(facebookId, forKey: .facebookId)
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        // Add all relevant properties for comparison
        lhs.id == rhs.id &&
        lhs.firstName == rhs.firstName &&
        lhs.lastName == rhs.lastName &&
        lhs.username == rhs.username &&
        lhs.isActive == rhs.isActive &&
        lhs.friends == rhs.friends &&
        lhs.doNotDisturb == rhs.doNotDisturb &&
        lhs.phoneNumber == rhs.phoneNumber &&
        lhs.createdEventIds == rhs.createdEventIds &&
        lhs.attendingEventIds == rhs.attendingEventIds &&
        lhs.visitedLandmarkIds == rhs.visitedLandmarkIds &&
        lhs.receiveFriendRequests == rhs.receiveFriendRequests &&
        lhs.receiveFriendEvents == rhs.receiveFriendEvents &&
        lhs.receiveEventUpdates == rhs.receiveEventUpdates &&
        lhs.shareLocationWithFriends == rhs.shareLocationWithFriends &&
        lhs.shareLocationWithEventHost == rhs.shareLocationWithEventHost &&
        lhs.shareLocationWithEventGroup == rhs.shareLocationWithEventGroup &&
        lhs.allowFriendsToInviteOthers == rhs.allowFriendsToInviteOthers
    }
}

// MARK: - MKPolygon Extension
extension MKPolygon {
    func contains(_ point: MKMapPoint) -> Bool {
        let renderer = MKPolygonRenderer(polygon: self)
        let mapPoint = renderer.point(for: point)
        return renderer.path.contains(CGPoint(x: mapPoint.x, y: mapPoint.y))
    }
}
