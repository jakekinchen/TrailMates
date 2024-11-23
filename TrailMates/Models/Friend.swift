//
//  Friend.swift
//  TrailMates
//
//  Created by Jake Kinchen on 10/3/24.
//

import Foundation
import CoreLocation
import MapKit
import SwiftUI

// MARK: - Friend Protocol
protocol FriendRepresentable {
    var id: UUID { get }
    var firstName: String { get }
    var lastName: String { get }
    var username: String { get }
    var profileImageData: Data? { get }
    var profileImageUrl: String? { get }
    var profileThumbnailUrl: String? { get }
    var doNotDisturb: Bool { get }
    var phoneNumber: String { get }
    var isActive: Bool { get }
    var location: CLLocationCoordinate2D? { get }
}

// MARK: - User Extension for Friend Functionality
extension User: FriendRepresentable {

}

// MARK: - Friend View Model
struct FriendViewModel: Identifiable {
    private let friend: FriendRepresentable
    
    init(_ user: User) {
        self.friend = user
    }
    
    var id: UUID { friend.id }
    var firstName: String { friend.firstName }
    var lastName: String { friend.lastName }
    var fullName: String { "\(firstName) \(lastName)" }
    var username: String { friend.username }
    var profileImageData: Data? { friend.profileImageData }
    var profileImageUrl: String? { friend.profileImageUrl }
    var profileThumbnailUrl: String? { friend.profileThumbnailUrl }
    var doNotDisturb: Bool { friend.doNotDisturb }
    var phoneNumber: String { friend.phoneNumber }
    var isActive: Bool { friend.isActive }
    var location: CLLocationCoordinate2D? { friend.location }
    
    // Additional view-specific computed properties
    var initials: String {
        let firstInitial = firstName.prefix(1)
        let lastInitial = lastName.prefix(1)
        return "\(firstInitial)\(lastInitial)".uppercased()
    }
    
    var statusColor: Color {
        if doNotDisturb {
            return .gray
        } else if isActive {
            return Color("pine")
        } else {
            return .red
        }
    }
}
