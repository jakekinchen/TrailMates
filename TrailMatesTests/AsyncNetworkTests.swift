import Testing
import Foundation
import CoreLocation
@testable import TrailMatesATX

/// Tests for async operations, error recovery, and offline behavior simulation.
/// These tests verify that the app handles network failures and edge cases gracefully.
@Suite("Async Network Tests")
struct AsyncNetworkTests {

    // MARK: - Error Recovery Tests

    @Test("MockFirebaseDataProvider handles save failure gracefully")
    func testSaveFailureRecovery() async throws {
        let mockProvider = MockFirebaseDataProvider()
        await mockProvider.configure(shouldFailOnSave: true)

        let user = TestFixtures.sampleUser

        do {
            try await mockProvider.saveUser(user)
            #expect(Bool(false), "Expected save to fail")
        } catch {
            #expect(error is MockError)
            #expect(error.localizedDescription == "Mock save operation failed")
        }

        // Verify that after failure, we can recover by changing mock behavior
        await mockProvider.configure(shouldFailOnSave: false)
        try await mockProvider.saveUser(user)

        let savedUser = await mockProvider.fetchUser(by: user.id)
        #expect(savedUser != nil)
        #expect(savedUser?.id == user.id)
    }

    @Test("MockFirebaseDataProvider handles fetch failure gracefully")
    func testFetchFailureRecovery() async {
        let mockProvider = MockFirebaseDataProvider()
        await mockProvider.configure(shouldFailOnFetch: true)

        // Store a user first (without failure)
        await mockProvider.setUser(TestFixtures.sampleUser)

        // Fetch should return nil when failing
        let user = await mockProvider.fetchUser(by: TestFixtures.sampleUser.id)
        #expect(user == nil)

        // Recovery: disable failure mode
        await mockProvider.configure(shouldFailOnFetch: false)
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
        await mockProvider.configure(shouldFailOnSave: true)

        do {
            try await mockProvider.deleteEvent(event.id)
            #expect(Bool(false), "Expected delete to fail")
        } catch {
            #expect(error is MockError)
        }

        // Event should still exist
        await mockProvider.configure(shouldFailOnFetch: false)
        let stillExists = await mockProvider.fetchEvent(by: event.id)
        #expect(stillExists != nil)

        // Recovery
        await mockProvider.configure(shouldFailOnSave: false)
        try await mockProvider.deleteEvent(event.id)
        let deleted = await mockProvider.fetchEvent(by: event.id)
        #expect(deleted == nil)
    }

    @Test("MockFirebaseDataProvider handles friend request failure")
    func testFriendRequestFailureRecovery() async throws {
        let mockProvider = MockFirebaseDataProvider()
        await mockProvider.configure(shouldFailOnSave: true)

        do {
            try await mockProvider.sendFriendRequest(fromUserId: "user-1", to: "user-2")
            #expect(Bool(false), "Expected friend request to fail")
        } catch {
            #expect(error is MockError)
        }

        // Recovery
        await mockProvider.configure(shouldFailOnSave: false)
        try await mockProvider.sendFriendRequest(fromUserId: "user-1", to: "user-2")

        let callCount = await mockProvider.getSendFriendRequestCallCount()
        #expect(callCount == 2)
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
        await mockProvider.setUser(TestFixtures.sampleUser)
        await mockProvider.setEvent(TestFixtures.sampleWalkEvent)

        // Go "offline"
        await mockProvider.configure(shouldFailOnSave: true, shouldFailOnFetch: true)

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
        let testUser = TestFixtures.createUser(id: "user-1", firstName: "Test")
        await mockProvider.setUser(testUser)

        // Go offline
        await mockProvider.configure(shouldFailOnSave: true, shouldFailOnFetch: true)

        let offlineResult = await mockProvider.fetchUser(by: "user-1")
        #expect(offlineResult == nil)

        // Reconnect
        await mockProvider.configure(shouldFailOnSave: false, shouldFailOnFetch: false)

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

        // Retry logic with simulated intermittent failure
        var succeeded = false
        for attempt in 1...maxAttempts {
            attemptCount += 1
            // Configure failure mode based on attempt number
            if attempt < maxAttempts {
                await mockProvider.configure(shouldFailOnSave: true)
            } else {
                await mockProvider.configure(shouldFailOnSave: false)
            }
            do {
                try await mockProvider.saveUser(TestFixtures.sampleUser)
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
        await mockProvider.configure(shouldFailOnSave: true)

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
        await mockProvider.setUser(testUser)

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
        let usersCount = await mockProvider.getUsersCount()
        #expect(usersCount == 3)
        let savedUser1 = await mockProvider.getUser("user-1")
        let savedUser2 = await mockProvider.getUser("user-2")
        let savedUser3 = await mockProvider.getUser("user-3")
        #expect(savedUser1 != nil)
        #expect(savedUser2 != nil)
        #expect(savedUser3 != nil)
    }

    // MARK: - Custom Error Tests

    @Test("Custom mock error is propagated correctly")
    func testCustomMockError() async {
        let mockProvider = MockFirebaseDataProvider()
        let customError = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Custom test error"])
        await mockProvider.configure(shouldFailOnSave: true, mockError: customError)

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
        await mockProvider.configure(mockCurrentUserId: "test-user")
        await mockProvider.setUser(TestFixtures.sampleUser)

        // Perform various operations
        _ = await mockProvider.fetchCurrentUser()
        _ = await mockProvider.fetchCurrentUser()
        _ = await mockProvider.fetchUser(by: "test-user")
        try await mockProvider.saveUser(TestFixtures.sampleUser)
        try await mockProvider.saveUser(TestFixtures.sampleUser)
        try await mockProvider.saveUser(TestFixtures.sampleUser)

        let fetchCurrentUserCount = await mockProvider.getFetchCurrentUserCallCount()
        let fetchUserByIdCount = await mockProvider.getFetchUserByIdCallCount()
        let saveUserCount = await mockProvider.getSaveUserCallCount()
        #expect(fetchCurrentUserCount == 2)
        #expect(fetchUserByIdCount == 1)
        #expect(saveUserCount == 3)
    }

    @Test("MockFirebaseDataProvider reset clears call counts")
    func testResetClearsCallCounts() async throws {
        let mockProvider = MockFirebaseDataProvider()

        // Perform some operations
        _ = await mockProvider.fetchAllEvents()
        try await mockProvider.saveEvent(TestFixtures.sampleWalkEvent)

        var fetchAllEventsCount = await mockProvider.getFetchAllEventsCallCount()
        var saveEventCount = await mockProvider.getSaveEventCallCount()
        #expect(fetchAllEventsCount == 1)
        #expect(saveEventCount == 1)

        // Reset
        await mockProvider.reset()

        fetchAllEventsCount = await mockProvider.getFetchAllEventsCallCount()
        saveEventCount = await mockProvider.getSaveEventCallCount()
        let usersCount = await mockProvider.getUsersCount()
        let eventsCount = await mockProvider.getEventsCount()
        #expect(fetchAllEventsCount == 0)
        #expect(saveEventCount == 0)
        #expect(usersCount == 0)
        #expect(eventsCount == 0)
    }

    // MARK: - Timeout Simulation Tests

    @Test("Simulated delay does not affect mock behavior")
    func testSimulatedDelay() async throws {
        let mockProvider = MockFirebaseDataProvider()
        let testUser = TestFixtures.createUser(id: "user-1", firstName: "Test")
        await mockProvider.setUser(testUser)

        // Measure time
        let start = Date()

        // Perform operation (should be instant in mock)
        let user = await mockProvider.fetchUser(by: "user-1")

        let elapsed = Date().timeIntervalSince(start)

        #expect(user != nil)
        #expect(elapsed < 0.1) // Should be nearly instant
    }
}
