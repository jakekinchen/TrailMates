//
//  TrailMatesTests.swift
//  TrailMatesTests
//
//  Created by Jake Kinchen on 10/3/24.
//

import Testing
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
}
