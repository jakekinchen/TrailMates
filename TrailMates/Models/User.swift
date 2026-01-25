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
    private(set) var phoneNumber: String
    var joinDate: Date
    
    // Computed property for hashed phone number
    var hashedPhoneNumber: String {
        PhoneNumberHasher.shared.hashPhoneNumber(phoneNumber)
    }
    
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
    
    // MARK: - Initialization
    init(id: String,
         firstName: String = "",
         lastName: String = "",
         username: String = "",
         phoneNumber: String,
         joinDate: Date = Date()) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.phoneNumber = phoneNumber
        self.joinDate = joinDate
        self.isActive = true
        self.friends = []
        self.doNotDisturb = false
        self.createdEventIds = []
        self.attendingEventIds = []
        self.visitedLandmarkIds = []
        self.receiveFriendRequests = true
        self.receiveFriendEvents = true
        self.receiveEventUpdates = true
        self.shareLocationWithFriends = true
        self.shareLocationWithEventHost = true
        self.shareLocationWithEventGroup = true
        self.allowFriendsToInviteOthers = true
    }
    
    // MARK: - Methods
    func updatePhoneNumber(_ newPhoneNumber: String) {
        self.phoneNumber = newPhoneNumber
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, username, phoneNumber, joinDate
        case profileImageUrl, profileThumbnailUrl, isActive, friends, doNotDisturb
        case createdEventIds, attendingEventIds, visitedLandmarkIds
        case receiveFriendRequests, receiveFriendEvents, receiveEventUpdates
        case shareLocationWithFriends, shareLocationWithEventHost, shareLocationWithEventGroup
        case allowFriendsToInviteOthers, facebookId
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        username = try container.decode(String.self, forKey: .username)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        joinDate = try container.decode(Date.self, forKey: .joinDate)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        profileThumbnailUrl = try container.decodeIfPresent(String.self, forKey: .profileThumbnailUrl)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        friends = try container.decodeIfPresent([String].self, forKey: .friends) ?? []
        doNotDisturb = try container.decodeIfPresent(Bool.self, forKey: .doNotDisturb) ?? false
        createdEventIds = try container.decodeIfPresent([String].self, forKey: .createdEventIds) ?? []
        attendingEventIds = try container.decodeIfPresent([String].self, forKey: .attendingEventIds) ?? []
        visitedLandmarkIds = try container.decodeIfPresent([String].self, forKey: .visitedLandmarkIds) ?? []
        receiveFriendRequests = try container.decodeIfPresent(Bool.self, forKey: .receiveFriendRequests) ?? true
        receiveFriendEvents = try container.decodeIfPresent(Bool.self, forKey: .receiveFriendEvents) ?? true
        receiveEventUpdates = try container.decodeIfPresent(Bool.self, forKey: .receiveEventUpdates) ?? true
        shareLocationWithFriends = try container.decodeIfPresent(Bool.self, forKey: .shareLocationWithFriends) ?? true
        shareLocationWithEventHost = try container.decodeIfPresent(Bool.self, forKey: .shareLocationWithEventHost) ?? true
        shareLocationWithEventGroup = try container.decodeIfPresent(Bool.self, forKey: .shareLocationWithEventGroup) ?? true
        allowFriendsToInviteOthers = try container.decodeIfPresent(Bool.self, forKey: .allowFriendsToInviteOthers) ?? true
        facebookId = try container.decodeIfPresent(String.self, forKey: .facebookId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(username, forKey: .username)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encode(joinDate, forKey: .joinDate)
        try container.encodeIfPresent(profileImageUrl, forKey: .profileImageUrl)
        try container.encodeIfPresent(profileThumbnailUrl, forKey: .profileThumbnailUrl)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(friends, forKey: .friends)
        try container.encode(doNotDisturb, forKey: .doNotDisturb)
        try container.encode(createdEventIds, forKey: .createdEventIds)
        try container.encode(attendingEventIds, forKey: .attendingEventIds)
        try container.encode(visitedLandmarkIds, forKey: .visitedLandmarkIds)
        try container.encode(receiveFriendRequests, forKey: .receiveFriendRequests)
        try container.encode(receiveFriendEvents, forKey: .receiveFriendEvents)
        try container.encode(receiveEventUpdates, forKey: .receiveEventUpdates)
        try container.encode(shareLocationWithFriends, forKey: .shareLocationWithFriends)
        try container.encode(shareLocationWithEventHost, forKey: .shareLocationWithEventHost)
        try container.encode(shareLocationWithEventGroup, forKey: .shareLocationWithEventGroup)
        try container.encode(allowFriendsToInviteOthers, forKey: .allowFriendsToInviteOthers)
        try container.encodeIfPresent(facebookId, forKey: .facebookId)
    }
    
    // MARK: - Equatable
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id &&
        lhs.firstName == rhs.firstName &&
        lhs.lastName == rhs.lastName &&
        lhs.username == rhs.username &&
        lhs.phoneNumber == rhs.phoneNumber &&
        lhs.joinDate == rhs.joinDate &&
        lhs.profileImageUrl == rhs.profileImageUrl &&
        lhs.profileThumbnailUrl == rhs.profileThumbnailUrl &&
        lhs.isActive == rhs.isActive &&
        lhs.friends == rhs.friends &&
        lhs.doNotDisturb == rhs.doNotDisturb &&
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
        lhs.facebookId == rhs.facebookId
    }

    /// Checks if only the location property differs between two users.
    /// Used to avoid unnecessary saves when only location changes.
    func hasOnlyLocationChanged(comparedTo other: User) -> Bool {
        // If the users are fully equal, nothing changed
        guard self != other else { return false }

        // Check if all non-location properties are equal
        return self.id == other.id &&
            self.firstName == other.firstName &&
            self.lastName == other.lastName &&
            self.username == other.username &&
            self.profileImageUrl == other.profileImageUrl &&
            self.profileThumbnailUrl == other.profileThumbnailUrl &&
            self.friends == other.friends &&
            self.createdEventIds == other.createdEventIds &&
            self.attendingEventIds == other.attendingEventIds &&
            self.visitedLandmarkIds == other.visitedLandmarkIds &&
            self.isActive == other.isActive &&
            self.doNotDisturb == other.doNotDisturb &&
            self.receiveFriendRequests == other.receiveFriendRequests &&
            self.receiveFriendEvents == other.receiveFriendEvents &&
            self.receiveEventUpdates == other.receiveEventUpdates &&
            self.shareLocationWithFriends == other.shareLocationWithFriends &&
            self.shareLocationWithEventHost == other.shareLocationWithEventHost &&
            self.shareLocationWithEventGroup == other.shareLocationWithEventGroup &&
            self.allowFriendsToInviteOthers == other.allowFriendsToInviteOthers
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
