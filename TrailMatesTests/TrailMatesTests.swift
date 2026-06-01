//
//  TrailMatesTests.swift
//  TrailMatesTests
//
//  Created by Jake Kinchen on 10/3/24.
//

import Testing
import Contacts
@testable import TrailMatesATX

struct TrailMatesTests {

    @Test("User defaults are suitable for a new account")
    func newUserDefaults() {
        let user = User(
            id: "smoke-user-id",
            firstName: "Smoke",
            lastName: "Test",
            username: "smoketest",
            phoneNumber: "+15125551234"
        )

        #expect(user.initials == "ST")
        #expect(user.isActive)
        #expect(user.friends.isEmpty)
        #expect(user.attendingEventIds.isEmpty)
        #expect(user.receiveFriendRequests)
        #expect(user.shareLocationWithFriends)
    }

    @Test("AppError exposes user-facing validation messages")
    func appErrorValidationMessage() {
        let error = AppError.invalidInput("Phone number is invalid.")

        #expect(error.errorDescription == "Phone number is invalid.")
        #expect(error.isRetryable == false)
    }

    @Test("Invite links use the app scheme and App Store fallback, not trailmates.app")
    func inviteLinkUsesAppScheme() {
        let inviteURL = TrailMatesDeepLink.inviteURL(senderId: "sender-123")

        #expect(inviteURL.absoluteString == "trailmates://invite/sender-123")
        #expect(inviteURL.host == "invite")
        #expect(TrailMatesDeepLink.profileUserId(from: inviteURL) == "sender-123")
        #expect(AppConstants.appStoreURL == TrailMatesDeepLink.appStoreFallbackURL.absoluteString)
        #expect(AppConstants.supportEmail == "mailto:trailmates.atx@gmail.com")
        #expect(AppConstants.supportCenterURL == "https://trailmates-site.vercel.app")
        #expect(TrailMatesDeepLink.profileUserId(from: URL(string: "https://trailmates.app/invite/sender-123")!) == nil)
    }

    @MainActor
    @Test("Contact matches use matched phone hashes without exposing raw phone numbers")
    func contactMatchesUseReturnedPhoneHash() {
        let phoneNumber = "(512) 555-0199"
        let phoneHash = PhoneNumberHasher.shared.hashPhoneNumber(phoneNumber)
        let contact = CNMutableContact()
        contact.givenName = "Jess"
        contact.familyName = "Trail"
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phoneNumber))
        ]

        let user = User(
            id: "matched-user",
            firstName: "Jess",
            lastName: "Trail",
            username: "jess",
            phoneNumber: ""
        )
        user.matchedPhoneHash = phoneHash

        let matches = ContactsListViewModel.matchedContacts(from: [contact], matchedUsers: [user])

        #expect(matches.count == 1)
        #expect(matches.first?.user.id == "matched-user")
        #expect(matches.first?.contact.givenName == "Jess")
        #expect(matches.first?.user.phoneNumber.isEmpty == true)
    }
}
