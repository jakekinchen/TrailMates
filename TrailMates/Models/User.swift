import Foundation
import CoreLocation
import MapKit
import UIKit
import SwiftData

/// A user model that represents a TrailMates user with both local and remote data storage capabilities.
/// The model uses SwiftData for local persistence and Firebase for remote storage.
@Model
final class User: Codable, Identifiable, Equatable {
    var id: String
    var firstName: String
    var lastName: String
    var username: String
    var phoneNumber: String
    var joinDate: Date
    
    // Profile Image properties
    @Attribute(.externalStorage) var profileImageData: Data?
    var profileImageUrl: String?
    var profileThumbnailUrl: String?
    var profileImage: UIImage? {
        get {
            if let data = profileImageData {
                return UIImage(data: data)
            }
            return nil
        }
        set {
            profileImageData = newValue?.jpegData(compressionQuality: 0.8)
        }
    }
    
    var isActive: Bool
    var friends: [String]
    var doNotDisturb: Bool
    var createdEventIds: [String]
    var attendingEventIds: [String]
    var visitedLandmarkIds: [String]
    
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
        case id, firstName, lastName, username, phoneNumber, joinDate
        case profileImageUrl, profileThumbnailUrl, profileImageData
        case isActive, friends, doNotDisturb, createdEventIds, attendingEventIds
        case visitedLandmarkIds, receiveFriendRequests, receiveFriendEvents
        case receiveEventUpdates, shareLocationWithFriends, shareLocationWithEventHost
        case shareLocationWithEventGroup, allowFriendsToInviteOthers
        case latitude, longitude, facebookId
    }
    
    init(id: String,
         firstName: String = "",
         lastName: String = "",
         username: String = "",
         phoneNumber: String,
         joinDate: Date = Date(),
         profileImage: UIImage? = nil,
         profileImageUrl: String? = nil,
         profileThumbnailUrl: String? = nil,
         isActive: Bool = true,
         friends: [String] = [],
         doNotDisturb: Bool = false,
         createdEventIds: [String] = [],
         attendingEventIds: [String] = [],
         visitedLandmarkIds: [String] = [],
         receiveFriendRequests: Bool = true,
         receiveFriendEvents: Bool = true,
         receiveEventUpdates: Bool = true,
         shareLocationWithFriends: Bool = true,
         shareLocationWithEventHost: Bool = true,
         shareLocationWithEventGroup: Bool = false,
         allowFriendsToInviteOthers: Bool = true,
         location: CLLocationCoordinate2D? = nil) {
        
        // Initialize all stored properties first
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.phoneNumber = phoneNumber
        self.joinDate = joinDate
        
        // Initialize profile image data directly
        self.profileImageData = profileImage?.jpegData(compressionQuality: 0.8)
        self.profileImageUrl = profileImageUrl
        self.profileThumbnailUrl = profileThumbnailUrl
        
        // Initialize arrays
        self.friends = friends
        self.createdEventIds = createdEventIds
        self.attendingEventIds = attendingEventIds
        self.visitedLandmarkIds = visitedLandmarkIds
        
        // Initialize boolean flags
        self.isActive = isActive
        self.doNotDisturb = doNotDisturb
        
        // Initialize notification settings
        self.receiveFriendRequests = receiveFriendRequests
        self.receiveFriendEvents = receiveFriendEvents
        self.receiveEventUpdates = receiveEventUpdates
        
        // Initialize privacy settings
        self.shareLocationWithFriends = shareLocationWithFriends
        self.shareLocationWithEventHost = shareLocationWithEventHost
        self.shareLocationWithEventGroup = shareLocationWithEventGroup
        self.allowFriendsToInviteOthers = allowFriendsToInviteOthers
        
        // Initialize optional properties
        self.facebookId = nil
        self.location = location
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode required properties
        id = try container.decode(String.self, forKey: .id)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        username = try container.decode(String.self, forKey: .username)
        
        // Handle profile image data with SwiftData external storage
        profileImageData = try container.decodeIfPresent(Data.self, forKey: .profileImageData)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        profileThumbnailUrl = try container.decodeIfPresent(String.self, forKey: .profileThumbnailUrl)
        
        isActive = try container.decode(Bool.self, forKey: .isActive)
        friends = try container.decode([String].self, forKey: .friends)
        doNotDisturb = try container.decode(Bool.self, forKey: .doNotDisturb)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        createdEventIds = try container.decode([String].self, forKey: .createdEventIds)
        attendingEventIds = try container.decode([String].self, forKey: .attendingEventIds)
        joinDate = try container.decode(Date.self, forKey: .joinDate)
        visitedLandmarkIds = try container.decode([String].self, forKey: .visitedLandmarkIds)
        
        // Decode notification settings with default values if not present
        receiveFriendRequests = try container.decodeIfPresent(Bool.self, forKey: .receiveFriendRequests) ?? true
        receiveFriendEvents = try container.decodeIfPresent(Bool.self, forKey: .receiveFriendEvents) ?? true
        receiveEventUpdates = try container.decodeIfPresent(Bool.self, forKey: .receiveEventUpdates) ?? true
        
        // Decode privacy settings with default values if not present
        shareLocationWithFriends = try container.decodeIfPresent(Bool.self, forKey: .shareLocationWithFriends) ?? true
        shareLocationWithEventHost = try container.decodeIfPresent(Bool.self, forKey: .shareLocationWithEventHost) ?? true
        shareLocationWithEventGroup = try container.decodeIfPresent(Bool.self, forKey: .shareLocationWithEventGroup) ?? false
        allowFriendsToInviteOthers = try container.decodeIfPresent(Bool.self, forKey: .allowFriendsToInviteOthers) ?? true
        
        // Handle location decoding with validation
        let latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        let longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        
        // Ensure both latitude and longitude are present or neither is present
        switch (latitude, longitude) {
        case let (lat?, lon?):
            location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        case (nil, nil):
            location = nil
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Latitude and longitude must both be present or both be absent"
                )
            )
        }
        
        facebookId = try container.decodeIfPresent(String.self, forKey: .facebookId)
    }
    
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
        // Compare all properties including optional ones
        lhs.id == rhs.id &&
        lhs.firstName == rhs.firstName &&
        lhs.lastName == rhs.lastName &&
        lhs.username == rhs.username &&
        lhs.profileImageData == rhs.profileImageData &&
        lhs.profileImageUrl == rhs.profileImageUrl &&
        lhs.profileThumbnailUrl == rhs.profileThumbnailUrl &&
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
        lhs.allowFriendsToInviteOthers == rhs.allowFriendsToInviteOthers &&
        lhs.facebookId == rhs.facebookId &&
        lhs.location?.latitude == rhs.location?.latitude &&
        lhs.location?.longitude == rhs.location?.longitude
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
