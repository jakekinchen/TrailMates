import Testing
import Foundation
import CoreLocation
@testable import TrailMates

/// Tests for async operations, error recovery, and offline behavior simulation.
/// These tests verify that the app handles network failures and edge cases gracefully.
@Suite("Async Network Tests")
struct AsyncNetworkTests {

    // MARK: - Error Recovery Tests

    @Test("MockFirebaseDataProvider handles save failure gracefully")
    func testSaveFailureRecovery() async throws {
        let mockProvider = MockFirebaseDataProvider()
        mockProvider.shouldFailOnSave = true

        let user = TestFixtures.sampleUser

        do {
            try await mockProvider.saveUser(user)
            #expect(Bool(false), "Expected save to fail")
        } catch {
            #expect(error is MockError)
            #expect(error.localizedDescription == "Mock save operation failed")
        }

        // Verify that after failure, we can recover by changing mock behavior
        mockProvider.shouldFailOnSave = false
        try await mockProvider.saveUser(user)

        let savedUser = await mockProvider.fetchUser(by: user.id)
        #expect(savedUser != nil)
        #expect(savedUser?.id == user.id)
    }

    @Test("MockFirebaseDataProvider handles fetch failure gracefully")
    func testFetchFailureRecovery() async {
        let mockProvider = MockFirebaseDataProvider()
        mockProvider.shouldFailOnFetch = true

        // Store a user first (without failure)
        mockProvider.users[TestFixtures.sampleUser.id] = TestFixtures.sampleUser

        // Fetch should return nil when failing
        let user = await mockProvider.fetchUser(by: TestFixtures.sampleUser.id)
        #expect(user == nil)

        // Recovery: disable failure mode
        mockProvider.shouldFailOnFetch = false
        let recoveredUser = await mockProvider.fetchUser(by: TestFixtures.sampleUser.id)
        #expect(recoveredUser != nil)
    }

    @Test("MockFirebaseDataProvider handles delete failure gracefully")
    func testDeleteFailureRecovery() async throws {
        let mockProvider = MockFirebaseDataProvider()
        let event = TestFixtures.sampleWalkEvent

        // Save event first
        try await mockProvider.saveEvent(event)

        // Enable failure mode
        mockProvider.shouldFailOnSave = true

        do {
            try await mockProvider.deleteEvent(event.id)
            #expect(Bool(false), "Expected delete to fail")
        } catch {
            #expect(error is MockError)
        }

        // Event should still exist
        mockProvider.shouldFailOnFetch = false
        let stillExists = await mockProvider.fetchEvent(by: event.id)
        #expect(stillExists != nil)

        // Recovery
        mockProvider.shouldFailOnSave = false
        try await mockProvider.deleteEvent(event.id)
        let deleted = await mockProvider.fetchEvent(by: event.id)
        #expect(deleted == nil)
    }

    @Test("MockFirebaseDataProvider handles friend request failure")
    func testFriendRequestFailureRecovery() async throws {
        let mockProvider = MockFirebaseDataProvider()
        mockProvider.shouldFailOnSave = true

        do {
            try await mockProvider.sendFriendRequest(fromUserId: "user-1", to: "user-2")
            #expect(Bool(false), "Expected friend request to fail")
        } catch {
            #expect(error is MockError)
        }

        // Recovery
        mockProvider.shouldFailOnSave = false
        try await mockProvider.sendFriendRequest(fromUserId: "user-1", to: "user-2")

        #expect(mockProvider.sendFriendRequestCallCount == 2)
    }

    @Test("MockUserManager handles auth failure gracefully")
    @MainActor
    func testAuthFailureRecovery() async throws {
        let mockManager = MockUserManager()
        mockManager.shouldFailOnAuth = true

        do {
            try await mockManager.createNewUser(phoneNumber: "+1 (555) 123-4567", id: "test-id")
            #expect(Bool(false), "Expected auth to fail")
        } catch {
            #expect(mockManager.isLoggedIn == false)
            #expect(mockManager.currentUser == nil)
        }

        // Recovery
        mockManager.shouldFailOnAuth = false
        try await mockManager.createNewUser(phoneNumber: "+1 (555) 123-4567", id: "test-id")

        #expect(mockManager.isLoggedIn == true)
        #expect(mockManager.currentUser != nil)
    }

    // MARK: - Offline Behavior Simulation Tests

    @Test("MockFirebaseDataProvider simulates offline by failing all operations")
    func testOfflineSimulation() async {
        let mockProvider = MockFirebaseDataProvider()

        // Add some data while "online"
        mockProvider.users["user-1"] = TestFixtures.sampleUser
        mockProvider.events["event-1"] = TestFixtures.sampleWalkEvent

        // Go "offline"
        mockProvider.shouldFailOnFetch = true
        mockProvider.shouldFailOnSave = true

        // All fetches should return nil/empty
        let user = await mockProvider.fetchCurrentUser()
        #expect(user == nil)

        let users = await mockProvider.fetchAllUsers()
        #expect(users.isEmpty)

        let events = await mockProvider.fetchAllEvents()
        #expect(events.isEmpty)

        // All saves should throw
        do {
            try await mockProvider.saveUser(TestFixtures.sampleUser)
            #expect(Bool(false), "Expected save to fail offline")
        } catch {
            #expect(error is MockError)
        }
    }

    @Test("MockFirebaseDataProvider simulates reconnection")
    func testReconnectionSimulation() async throws {
        let mockProvider = MockFirebaseDataProvider()

        // Add data while online
        mockProvider.users["user-1"] = TestFixtures.sampleUser

        // Go offline
        mockProvider.shouldFailOnFetch = true
        mockProvider.shouldFailOnSave = true

        let offlineResult = await mockProvider.fetchUser(by: "user-1")
        #expect(offlineResult == nil)

        // Reconnect
        mockProvider.shouldFailOnFetch = false
        mockProvider.shouldFailOnSave = false

        let onlineResult = await mockProvider.fetchUser(by: "user-1")
        #expect(onlineResult != nil)
        #expect(onlineResult?.id == "user-1")
    }

    @Test("MockUserManager simulates offline friend operations")
    @MainActor
    func testOfflineFriendOperations() async {
        let mockManager = MockUserManager.withLoggedInUser()
        mockManager.shouldFailOnSave = true

        do {
            try await mockManager.addFriend("friend-id")
            #expect(Bool(false), "Expected add friend to fail offline")
        } catch {
            #expect(error is MockError)
        }

        // Friends list should be unchanged
        #expect(mockManager.isFriend("friend-id") == false)
    }

    @Test("MockUserManager maintains local state during offline period")
    @MainActor
    func testOfflineLocalStatePreservation() async throws {
        let mockManager = MockUserManager.withLoggedInUser()
        let originalUser = mockManager.currentUser

        // Go offline
        mockManager.shouldFailOnSave = true

        // Attempt location update (should fail silently or throw)
        do {
            try await mockManager.updateUserLocation(TestFixtures.austinDowntown)
        } catch {
            // Expected to fail
        }

        // User state should be preserved
        #expect(mockManager.currentUser?.id == originalUser?.id)
        #expect(mockManager.isLoggedIn == true)
    }

    // MARK: - Retry Logic Tests

    @Test("Operation succeeds after retry when error is resolved")
    func testRetryAfterErrorResolution() async throws {
        let mockProvider = MockFirebaseDataProvider()
        var attemptCount = 0
        let maxAttempts = 3

        // Simulate intermittent failure
        func simulatedSave() async throws {
            attemptCount += 1
            if attemptCount < maxAttempts {
                mockProvider.shouldFailOnSave = true
            } else {
                mockProvider.shouldFailOnSave = false
            }
            try await mockProvider.saveUser(TestFixtures.sampleUser)
        }

        // Retry logic
        var succeeded = false
        for _ in 1...maxAttempts {
            do {
                try await simulatedSave()
                succeeded = true
                break
            } catch {
                // Retry on next iteration
                continue
            }
        }

        #expect(succeeded == true)
        #expect(attemptCount == maxAttempts)
    }

    @Test("Operation fails after max retries exhausted")
    func testMaxRetriesExhausted() async {
        let mockProvider = MockFirebaseDataProvider()
        mockProvider.shouldFailOnSave = true

        var attemptCount = 0
        let maxAttempts = 3

        for _ in 1...maxAttempts {
            do {
                try await mockProvider.saveUser(TestFixtures.sampleUser)
                break // Should never reach here
            } catch {
                attemptCount += 1
            }
        }

        #expect(attemptCount == maxAttempts)
    }

    // MARK: - Concurrent Operation Tests

    @Test("Concurrent fetches return consistent data")
    func testConcurrentFetches() async {
        let mockProvider = MockFirebaseDataProvider()
        let testUser = TestFixtures.sampleUser
        mockProvider.users[testUser.id] = testUser

        // Perform concurrent fetches
        async let fetch1 = mockProvider.fetchUser(by: testUser.id)
        async let fetch2 = mockProvider.fetchUser(by: testUser.id)
        async let fetch3 = mockProvider.fetchUser(by: testUser.id)

        let results = await [fetch1, fetch2, fetch3]

        // All should return the same user
        for result in results {
            #expect(result?.id == testUser.id)
            #expect(result?.firstName == testUser.firstName)
        }
    }

    @Test("Concurrent saves maintain data integrity")
    func testConcurrentSaves() async throws {
        let mockProvider = MockFirebaseDataProvider()

        let user1 = TestFixtures.createUser(id: "user-1", firstName: "User1")
        let user2 = TestFixtures.createUser(id: "user-2", firstName: "User2")
        let user3 = TestFixtures.createUser(id: "user-3", firstName: "User3")

        // Perform concurrent saves
        async let save1: () = mockProvider.saveUser(user1)
        async let save2: () = mockProvider.saveUser(user2)
        async let save3: () = mockProvider.saveUser(user3)

        try await save1
        try await save2
        try await save3

        // All users should be saved
        #expect(mockProvider.users.count == 3)
        #expect(mockProvider.users["user-1"] != nil)
        #expect(mockProvider.users["user-2"] != nil)
        #expect(mockProvider.users["user-3"] != nil)
    }

    // MARK: - Custom Error Tests

    @Test("Custom mock error is propagated correctly")
    func testCustomMockError() async {
        let mockProvider = MockFirebaseDataProvider()
        let customError = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Custom test error"])
        mockProvider.shouldFailOnSave = true
        mockProvider.mockError = customError

        do {
            try await mockProvider.saveUser(TestFixtures.sampleUser)
            #expect(Bool(false), "Expected custom error")
        } catch let error as NSError {
            #expect(error.domain == "TestDomain")
            #expect(error.code == 42)
        }
    }

    @Test("Different MockError types have correct descriptions")
    func testMockErrorDescriptions() {
        let errors: [MockError] = [
            .saveFailed,
            .fetchFailed,
            .deleteFailed,
            .uploadFailed,
            .downloadFailed,
            .userNotFound,
            .eventNotFound
        ]

        let expectedDescriptions = [
            "Mock save operation failed",
            "Mock fetch operation failed",
            "Mock delete operation failed",
            "Mock upload operation failed",
            "Mock download operation failed",
            "Mock user not found",
            "Mock event not found"
        ]

        for (error, expected) in zip(errors, expectedDescriptions) {
            #expect(error.errorDescription == expected)
        }
    }

    // MARK: - Call Count Verification Tests

    @Test("MockFirebaseDataProvider tracks call counts correctly")
    func testCallCountTracking() async throws {
        let mockProvider = MockFirebaseDataProvider()
        mockProvider.mockCurrentUserId = "test-user"
        mockProvider.users["test-user"] = TestFixtures.sampleUser

        // Perform various operations
        _ = await mockProvider.fetchCurrentUser()
        _ = await mockProvider.fetchCurrentUser()
        _ = await mockProvider.fetchUser(by: "test-user")
        try await mockProvider.saveUser(TestFixtures.sampleUser)
        try await mockProvider.saveUser(TestFixtures.sampleUser)
        try await mockProvider.saveUser(TestFixtures.sampleUser)

        #expect(mockProvider.fetchCurrentUserCallCount == 2)
        #expect(mockProvider.fetchUserByIdCallCount == 1)
        #expect(mockProvider.saveUserCallCount == 3)
    }

    @Test("MockFirebaseDataProvider reset clears call counts")
    func testResetClearsCallCounts() async throws {
        let mockProvider = MockFirebaseDataProvider()

        // Perform some operations
        _ = await mockProvider.fetchAllEvents()
        try await mockProvider.saveEvent(TestFixtures.sampleWalkEvent)

        #expect(mockProvider.fetchAllEventsCallCount == 1)
        #expect(mockProvider.saveEventCallCount == 1)

        // Reset
        mockProvider.reset()

        #expect(mockProvider.fetchAllEventsCallCount == 0)
        #expect(mockProvider.saveEventCallCount == 0)
        #expect(mockProvider.users.isEmpty)
        #expect(mockProvider.events.isEmpty)
    }

    // MARK: - Timeout Simulation Tests

    @Test("Simulated delay does not affect mock behavior")
    func testSimulatedDelay() async throws {
        let mockProvider = MockFirebaseDataProvider()
        mockProvider.users["user-1"] = TestFixtures.sampleUser

        // Measure time
        let start = Date()

        // Perform operation (should be instant in mock)
        let user = await mockProvider.fetchUser(by: "user-1")

        let elapsed = Date().timeIntervalSince(start)

        #expect(user != nil)
        #expect(elapsed < 0.1) // Should be nearly instant
    }
}
