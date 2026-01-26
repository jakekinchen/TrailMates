---
title: FirebaseDataProvider Refactoring
created: 2025-01-25
priority: backlog
status: complete
tags: [firebase, refactoring, architecture]
skill: swiftui-view-refactor
---

# FirebaseDataProvider Refactoring

## Objective
Split the monolithic FirebaseDataProvider (1,188 lines) into focused, single-responsibility providers.

## Current State
- Single singleton handles: users, events, images, landmarks, friends
- Mixed concerns make testing difficult
- Hard to reason about data flow
- Difficult to maintain and extend

## Proposed Architecture
```
FirebaseDataProvider (coordinator)
├── UserDataProvider
├── EventDataProvider
├── FriendDataProvider
├── ImageStorageProvider
├── LandmarkDataProvider
├── LocationDataProvider (added)
└── NotificationDataProvider (added)
```

## Tasks

### Phase 1: Analysis
- [x] Document all public methods in FirebaseDataProvider
- [x] Categorize methods by domain (user, event, friend, image, landmark)
- [x] Identify shared dependencies (Firestore, Functions, Storage)
- [x] Map current usage across ViewModels

### Phase 2: Create Base Infrastructure
- [x] Create `FirebaseProviderProtocol` with common interface
- [x] Create shared configuration/initialization
- [x] Set up dependency injection pattern

### Phase 3: Extract UserDataProvider
- [x] Move user CRUD operations
- [x] Move user query methods
- [x] Move phone number lookup methods
- [x] Update UserManager to use new provider

### Phase 4: Extract EventDataProvider
- [x] Move event CRUD operations
- [x] Move event query methods
- [x] Move attendance tracking methods
- [x] Update EventViewModel to use new provider

### Phase 5: Extract FriendDataProvider
- [x] Move friend relationship operations
- [x] Move friend request operations
- [x] Move friend query methods
- [x] Update FriendsViewModel to use new provider (delegates to UserManager)

### Phase 6: Extract ImageStorageProvider
- [x] Move profile image upload/download
- [x] Move thumbnail generation
- [x] Move prefetch logic
- [x] Add proper caching layer

### Phase 7: Extract LandmarkDataProvider
- [x] Move landmark CRUD operations
- [x] Move landmark query methods

### Phase 7b: Extract LocationDataProvider (New)
- [x] Move location update operations
- [x] Move location observation methods

### Phase 7c: Extract NotificationDataProvider (New)
- [x] Move notification send operations
- [x] Move notification observation methods
- [x] Move notification CRUD methods

### Phase 8: Update FirebaseDataProvider
- [x] Convert to coordinator/facade pattern
- [x] Compose individual providers
- [x] Maintain backward compatibility during transition
- [x] Deprecate direct methods in favor of sub-providers

### Phase 9: Testing
- [ ] Add unit tests for each provider
- [ ] Add mock implementations for testing
- [ ] Test integration between providers

## Completed Work (2025-01-25)

### Created Files
All files created in `TrailMates/Utilities/Firebase/`:

1. **UserDataProvider.swift** (415 lines)
   - User CRUD: fetchCurrentUser, fetchUser(by:), fetchAllUsers, saveInitialUser, saveUser
   - User queries: fetchFriends, fetchUsersByFacebookIds
   - Phone lookups: fetchUser(byPhoneNumber:), checkUserExists, findUsersByPhoneNumbers
   - Username operations: isUsernameTaken, isUsernameTakenCloudFunction
   - User observation: observeUser, stopObservingUser, stopObservingAllUsers

2. **EventDataProvider.swift** (120 lines)
   - Event CRUD: fetchAllEvents, fetchEvent, saveEvent, deleteEvent, updateEventStatus
   - Event queries: fetchUserEvents, fetchCircleEvents, fetchPublicEvents
   - Utilities: generateNewEventReference

3. **FriendDataProvider.swift** (210 lines)
   - Friend requests: sendFriendRequest, acceptFriendRequest, rejectFriendRequest
   - Friend relationships: addFriend, removeFriend
   - Friend observation: observeFriendRequests, updateFriendRequestStatus

4. **ImageStorageProvider.swift** (110 lines)
   - Upload: uploadProfileImage
   - Download: downloadProfileImage
   - Prefetch: prefetchProfileImages
   - Cache management: clearCache, removeFromCache

5. **LandmarkDataProvider.swift** (80 lines)
   - Queries: fetchTotalLandmarks, fetchAllLandmarks, fetchLandmark
   - User operations: markLandmarkVisited, unmarkLandmarkVisited, fetchVisitedLandmarks

6. **LocationDataProvider.swift** (150 lines)
   - Updates: updateUserLocation
   - Observation: observeUserLocation, stopObservingUserLocation, stopObservingAllLocations

7. **NotificationDataProvider.swift** (180 lines)
   - Send: sendNotification
   - Observe: observeNotifications
   - CRUD: fetchNotifications, markNotificationAsRead, deleteNotification

### Architecture Notes
- All providers follow singleton pattern for consistency with FirebaseDataProvider
- Each provider initializes its own Firestore/RTDB/Storage references
- ValidationError enum remains in FirebaseDataProvider and is referenced by sub-providers
- FirebaseDataProvider maintains backward compatibility - existing calls still work
- Sub-providers can be used directly for new code

## Completed Work (2025-01-25 - Phase 2)

### Updated ViewModels to use sub-providers

1. **UserManager.swift** - Updated to use:
   - `UserDataProvider.shared` for all user operations
   - `ImageStorageProvider.shared` for profile image upload/download
   - `LandmarkDataProvider.shared` for landmark operations
   - `LocationDataProvider.shared` for location updates
   - `FriendDataProvider.shared` for friend management

2. **EventViewModel.swift** - Updated to use:
   - `EventDataProvider.shared` for all event operations

3. **FriendsViewModel.swift** - No changes needed (already delegates to UserManager)

### Updated FirebaseDataProvider as Facade

- Added all sub-provider references as private properties
- All methods now delegate to appropriate sub-providers
- Added `@available(*, deprecated)` annotations with migration instructions
- Backward compatibility maintained - existing code continues to work
- Memory warning handler now uses ImageStorageProvider.clearCache()

## Completed Work (2025-01-25 - Phase 3: Protocols & DI)

### Created FirebaseProviderProtocol.swift

Created `TrailMates/Utilities/Firebase/FirebaseProviderProtocol.swift` containing:

1. **Protocol Definitions**:
   - `UserDataProviding` - Contract for user operations
   - `EventDataProviding` - Contract for event operations
   - `FriendDataProviding` - Contract for friend operations
   - `ImageStorageProviding` - Contract for image storage operations
   - `LandmarkDataProviding` - Contract for landmark operations
   - `LocationDataProviding` - Contract for location operations
   - `NotificationDataProviding` - Contract for notification operations

2. **Protocol Conformance Extensions**:
   - All concrete providers now conform to their respective protocols
   - Enables compile-time checking of protocol compliance

3. **FirebaseProviderContainer**:
   - Dependency injection container holding all provider dependencies
   - Singleton `.shared` for production use
   - Custom initializer for testing with mock providers
   - Enables proper dependency injection in ViewModels

### ViewModel to Provider Mapping

| ViewModel/Manager | Providers Used | Notes |
|------------------|----------------|-------|
| **UserManager** | UserDataProvider, ImageStorageProvider, LandmarkDataProvider, LocationDataProvider, FriendDataProvider | Central user management, delegates to specialized providers |
| **EventViewModel** | EventDataProvider | All event operations |
| **FriendsViewModel** | (via UserManager) | Delegates to UserManager for all operations |
| **AuthViewModel** | (via UserManager) | Uses UserManager for user creation/login |
| **LocationManager** | (via UserManager) | Delegates location updates to UserManager |
| **ContactsListViewModel** | (via UserManager) | Uses UserManager.findUsersByPhoneNumbers() |
| **LocationPickerViewModel** | None | No Firebase operations, uses CoreLocation only |
| **PermissionsViewModel** | None | No Firebase operations, manages system permissions |

### Provider Dependency Graph

```
FirebaseProviderContainer
├── UserDataProvider (Firestore, Functions, Auth)
├── EventDataProvider (Firestore)
├── FriendDataProvider (Firestore, RTDB, Auth)
├── ImageStorageProvider (Storage)
├── LandmarkDataProvider (Firestore)
├── LocationDataProvider (Firestore, RTDB, Auth)
└── NotificationDataProvider (RTDB, Auth)
```

## Next Steps (Future Work)
1. Add unit tests for each provider using protocols
2. Create mock protocol implementations for comprehensive testing
3. Test integration between providers
4. Gradually migrate remaining code that uses deprecated methods

## Notes
- Maintain singleton access during transition for compatibility
- Protocol-based abstraction enables proper testing
- Each provider is independently testable via its protocol
- Document migration path for existing code
- Deprecation warnings guide developers to use new providers
- FirebaseProviderContainer enables dependency injection for testing
