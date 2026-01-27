---
title: Value-Based User State & Firestore Patch Refactor
created: 2026-01-27
priority: urgent
status: in-progress
tags: [refactor, user, firestore, persistence, swiftui, reliability]
---

# Value-Based User State & Firestore Patch Refactor

## Objective
Eliminate “it looked saved but wasn’t” bugs caused by reference-type `User` mutations and whole-document overwrites, by:
1) making the in-app `User` state value-based (so changes require explicit reassignment), and  
2) writing user changes to Firestore using explicit field patches / atomic ops (so unrelated fields are never wiped and concurrent updates are safer).

This refactor is intended to prevent repeats of the “profile setup repeats after logout/login” issue and similar persistence bugs.

## Scope / Non‑Goals
- In scope:
  - `User` model representation used by UI + persistence.
  - `UserManager` update flows and how user changes are persisted locally + remotely.
  - Firestore write strategy for user updates (patch vs whole document), including atomic array ops.
  - Tests proving the persistence behavior (especially: “log out → log back in → no re-prompt”).
- Explicitly out of scope for this plan:
  - Full app-wide migration to `@Observable` (can be a separate plan).
  - Reworking onboarding UX/flow logic beyond what’s required for correctness.
  - Re-architecting Firebase Functions / rules (except where required to support the patch strategy).

## Current Known Failure Pattern (Must Not Regress)
- `User` is currently a reference type in many flows (class semantics / in-place mutation).
- Some flows compute “did anything change?” by comparing a `User` to itself after in-place mutation (always looks unchanged).
- Some Firestore writes overwrite an entire doc and can wipe fields not encoded (e.g., `hashedPhoneNumber`), or clobber concurrent updates.

## Definitions (Use These Exact Names)
- **UserRecord**: The value type the UI reads from and writes to (Codable, Identifiable, Equatable).
- **UserPatch**: A dictionary of Firestore fields to update (only changed keys).
- **AtomicArrayOp**: Firestore `FieldValue.arrayUnion` / `FieldValue.arrayRemove` operations for arrays that can change concurrently.

## Tasks

### 0) Preflight Safety (do these first)
- [ ] Create a working branch
  - [ ] Run `git status --porcelain=v1` and confirm it is empty before starting
  - [ ] Run `git switch -c chore/user-state-value-refactor`
- [ ] Record a baseline test run (must be green before edits)
  - [ ] Run `xcodebuild test -workspace TrailMatesATX.xcworkspace -scheme TrailMatesATX -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
  - [ ] Save the `.xcresult` path in this plan under **Notes**
- [ ] Confirm baseline prerequisites already exist (fix them if missing)
  - [ ] Open `TrailMates/Utilities/Firebase/UserDataProvider.swift`
    - [ ] Search for `setData(data)` in `saveUser(_:)`
    - [ ] If it is not `setData(data, merge: true)`, change it to use merge
  - [ ] Open `TrailMates/Models/User.swift`
    - [ ] Ensure Firestore encoding includes `hashedPhoneNumber`
    - [ ] If missing, add `hashedPhoneNumber` to CodingKeys + encode it

### 1) Create Value-Based User Types (no reference semantics)
- [ ] Replace the current `User` reference semantics with a value type
  - [ ] Edit `TrailMates/Models/User.swift`
    - [ ] Remove SwiftData annotations from the user model:
      - [ ] Remove `@Model`
      - [ ] Remove `@Attribute(.externalStorage)`
      - [ ] Remove `import SwiftData` (and any unused SwiftData imports)
    - [ ] Convert `User` to a struct:
      - [ ] `struct User: Codable, Identifiable, Equatable { ... }`
      - [ ] Keep the same public field names used throughout the app:
        - [ ] `id: String`
        - [ ] `firstName: String`
        - [ ] `lastName: String`
        - [ ] `username: String`
        - [ ] `phoneNumber: String`
        - [ ] `joinDate: Date`
        - [ ] `profileImageUrl: String?`
        - [ ] `profileThumbnailUrl: String?`
        - [ ] `isActive: Bool`
        - [ ] `friends: [String]`
        - [ ] `doNotDisturb: Bool`
        - [ ] `createdEventIds: [String]`
        - [ ] `attendingEventIds: [String]`
        - [ ] `visitedLandmarkIds: [String]`
        - [ ] `receiveFriendRequests: Bool`
        - [ ] `receiveFriendEvents: Bool`
        - [ ] `receiveEventUpdates: Bool`
        - [ ] `shareLocationWithFriends: Bool`
        - [ ] `shareLocationWithEventHost: Bool`
        - [ ] `shareLocationWithEventGroup: Bool`
        - [ ] `allowFriendsToInviteOthers: Bool`
        - [ ] `facebookId: String?`
        - [ ] `location: CLLocationCoordinate2D?` (local-only; not stored in Firestore)
      - [ ] Keep `hashedPhoneNumber` as a computed property:
        - [ ] `var hashedPhoneNumber: String { PhoneNumberHasher.shared.hashPhoneNumber(phoneNumber) }`
      - [ ] Keep `profileImage` as a computed property backed by `profileImageData` (local-only):
        - [ ] Add `var profileImageData: Data?` (not encoded to Firestore)
        - [ ] Add computed `var profileImage: UIImage?` getter/setter using `profileImageData`
    - [ ] Keep Codable behavior explicitly:
      - [ ] Ensure `CodingKeys` includes only Firestore-stored fields (exclude `profileImageData`, `profileImage`, `location`)
      - [ ] Include `hashedPhoneNumber` in `CodingKeys` and encode it
      - [ ] In `init(from:)`, decode `hashedPhoneNumber` (if present) but do not store it (computed); decoding should not throw if missing
  - [ ] Fix compilation fallout in files that relied on class/reference behavior
    - [ ] Search repo for `objectWillChange.send()` and remove usages related to user mutation
    - [ ] Search repo for identity checks like `currentUser !== updatedUser` and replace with value equality checks where needed

### 2) Introduce Explicit Firestore Patch Writes (no whole-doc overwrites for routine updates)
- [ ] Add patch update APIs to the user provider
  - [ ] Edit `TrailMates/Utilities/Firebase/UserDataProvider.swift`
    - [ ] Add method `updateUserFields(userId: String, fields: [String: Any]) async throws`
      - [ ] Must call `db.collection("users").document(userId).updateData(fields)`
      - [ ] Must wrap the call in `withRetry(maxAttempts: 3)`
      - [ ] Must convert any thrown error via `AppError.from(error)`
    - [ ] Add helper methods for common atomic operations (exact method names):
      - [ ] `addAttendingEvent(userId:eventId:)` uses `FieldValue.arrayUnion([eventId])`
      - [ ] `removeAttendingEvent(userId:eventId:)` uses `FieldValue.arrayRemove([eventId])`
    - [ ] Keep `saveUser(_:)` only for “full record upsert” situations:
      - [ ] Ensure it uses `setData(data, merge: true)`
      - [ ] Add a comment: “Prefer updateUserFields for partial updates”
  - [ ] Update `TrailMates/Utilities/Firebase/FirebaseProviderProtocol.swift`
    - [ ] Add to `UserDataProviding`:
      - [ ] `func updateUserFields(userId: String, fields: [String: Any]) async throws`
      - [ ] `func addAttendingEvent(userId: String, eventId: String) async throws`
      - [ ] `func removeAttendingEvent(userId: String, eventId: String) async throws`
    - [ ] Ensure `UserDataProvider` conforms to the updated protocol

### 3) Refactor UserManager to Value Semantics + Patch Application
- [ ] Make `UserManager` never mutate `currentUser` in-place without reassignment
  - [ ] Edit `TrailMates/ViewModels/UserManager.swift`
    - [ ] Ensure `currentUser` remains `@Published var currentUser: User?`
    - [ ] Remove any publisher/observer that attempted to auto-save user on mutation (value types require explicit saves)
    - [ ] Add a single, explicit helper to apply patches locally:
      - [ ] `private func applyLocalUserUpdate(_ mutate: (inout User) -> Void)`
      - [ ] Implementation:
        - [ ] Guard that `currentUser` is non-nil
        - [ ] Copy `var user = currentUser`
        - [ ] Run `mutate(&user)`
        - [ ] Assign `self.currentUser = user`
        - [ ] Call `persistUserSession()`
- [ ] Replace “saveProfile(updatedUser:)” with field-patch writes
  - [ ] In `UserManager.saveProfile(updatedUser:)`:
    - [ ] Remove any “did it change?” logic (do not compare users)
    - [ ] Replace with:
      - [ ] Compute a `fields` dictionary containing ONLY:
        - [ ] `firstName`, `lastName`, `username`
        - [ ] `profileImageUrl`, `profileThumbnailUrl` (if changed)
        - [ ] `doNotDisturb` (if this method is used for it; otherwise separate)
        - [ ] `receiveFriendRequests`, `receiveFriendEvents`, `receiveEventUpdates`
        - [ ] `shareLocationWithFriends`, `shareLocationWithEventHost`, `shareLocationWithEventGroup`, `allowFriendsToInviteOthers`
        - [ ] `hashedPhoneNumber` (always include to prevent accidental loss)
      - [ ] Call `userProvider.updateUserFields(userId: updatedUser.id, fields: fields)`
      - [ ] Update local `currentUser` by assigning `updatedUser` (value type)
      - [ ] Call `persistUserSession()`
    - [ ] Ensure errors are surfaced as `AppError`
- [ ] Convert existing UserManager actions to patch strategy
  - [ ] `toggleDoNotDisturb()`
    - [ ] Use `applyLocalUserUpdate` to flip the flag locally
    - [ ] Call `userProvider.updateUserFields(userId: userId, fields: ["doNotDisturb": newValue])`
  - [ ] `attendEvent(_:)` / `leaveEvent(_:)`
    - [ ] Update Firestore using `userProvider.addAttendingEvent(...)` / `removeAttendingEvent(...)`
    - [ ] Update local user arrays via `applyLocalUserUpdate`
    - [ ] Do NOT call `saveUser(_:)` for this
  - [ ] `updatePrivacySettings(...)` / `updateNotificationSettings(...)`
    - [ ] Call `userProvider.updateUserFields(...)` with only the changed booleans
    - [ ] Apply the same values locally via `applyLocalUserUpdate`
  - [ ] `updatePhoneNumber(_:)`
    - [ ] Normalize with `PhoneNumberService.shared.format(..., for: .storage)` (E.164)
    - [ ] Recompute hash (computed property) and include `hashedPhoneNumber` in the Firestore patch
    - [ ] Apply changes locally and call `persistUserSession()`
  - [ ] `updateUserLocation(_:)`
    - [ ] Remove any call that writes location to Firestore user doc
    - [ ] Keep location updates in RTDB only via `LocationDataProvider`

### 4) Refactor Profile Setup Flow to Use a Single “Update Profile” API
- [ ] Add a dedicated API in `UserManager` for profile setup
  - [ ] Create method `updateProfile(firstName:lastName:username:profileImage:) async throws`
    - [ ] Validate required fields (non-empty)
    - [ ] Validate username format (existing regex)
    - [ ] Check username availability via `isUsernameTaken`
    - [ ] If `profileImage` exists, upload via `ImageStorageProvider` then include URLs in patch
    - [ ] Call `userProvider.updateUserFields(...)` with `firstName/lastName/username/(urls)/hashedPhoneNumber`
    - [ ] Apply changes locally via `applyLocalUserUpdate`
- [ ] Update `TrailMates/ProfileSetupView.swift`
  - [ ] Remove direct mutation of the user model (`user.firstName = ...` etc.)
  - [ ] On save:
    - [ ] Call `try await userManager.updateProfile(firstName:lastName:username:profileImage:)`
    - [ ] If not edit mode, call `userManager.persistUserSession()` after success

### 5) Ensure On-Device Persistence Matches Remote Source of Truth
- [ ] Make local persistence resilient to schema changes
  - [ ] Open `TrailMates/ViewModels/UserManager.swift`
    - [ ] In `checkPersistedUser()` decode path, ensure decode failure clears persisted user data safely
    - [ ] Add a `currentUserSchemaVersion` integer stored in UserDefaults:
      - [ ] Key name: `currentUserSchemaVersion`
      - [ ] Set to `2` when saving user after this refactor
      - [ ] When loading, if version mismatches, clear and force a remote fetch
- [ ] Ensure remote fetch always wins over stale local state
  - [ ] After successful login in `UserManager.login(...)`:
    - [ ] Immediately fetch `/users/{uid}` from Firestore and set `currentUser` to that result
    - [ ] Only then call `persistUserSession()`

### 6) Add Tests That Would Have Caught This Class of Bug
- [ ] Add a new mock provider that captures patch writes
  - [ ] Create `TrailMatesTests/Mocks/MockUserDataProvider.swift`
    - [ ] Conform to `UserDataProviding`
    - [ ] Store:
      - [ ] `var storedUsers: [String: User]`
      - [ ] `var lastUpdateFields: [String: Any]?`
    - [ ] Implement `updateUserFields` to:
      - [ ] Save `lastUpdateFields = fields`
      - [ ] Apply fields into `storedUsers[userId]` (explicitly map each key)
- [ ] Add unit test: “Profile persists after logout/login”
  - [ ] Create `TrailMatesTests/ViewModels/UserPersistenceTests.swift`
    - [ ] Arrange: set mock provider user with empty profile fields
    - [ ] Act:
      - [ ] Call `userManager.updateProfile(firstName:lastName:username:profileImage:nil)`
      - [ ] Call `userManager.signOut()`
      - [ ] Simulate login and fetch current user from mock provider
    - [ ] Assert:
      - [ ] Loaded user has non-empty `firstName/lastName/username`
      - [ ] UI gate in `ContentView` would not route back to ProfileSetup (validate via conditions)
- [ ] Add unit test: “Patch writes do not drop hashedPhoneNumber”
  - [ ] In `UserPersistenceTests`:
    - [ ] After any profile update, assert `mock.lastUpdateFields` contains `"hashedPhoneNumber"`
- [ ] Add unit test: “Attend event uses atomic ops”
  - [ ] Confirm `UserManager.attendEvent` calls provider `addAttendingEvent` (track via mock counters)
- [ ] Run all tests
  - [ ] `xcodebuild test -workspace TrailMatesATX.xcworkspace -scheme TrailMatesATX -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

### 7) Cleanup / Consistency Pass
- [ ] Remove redundant/obsolete APIs that encourage whole-object saves
  - [ ] Remove or restrict any UI code calling `saveUser(_:)` directly
  - [ ] Add doc comment in `UserDataProvider.saveUser` stating: “Prefer updateUserFields”
- [ ] Update documentation
  - [ ] Add a short “User persistence rules” section to `README.md`:
    - [ ] “User updates must go through UserManager APIs”
    - [ ] “Firestore updates are patches; avoid whole-doc setData without merge”
- [ ] Commit workflow (do exactly this)
  - [ ] Commit in small chunks; for each chunk:
    - [ ] Stage only files touched by the chunk (no `git add .`)
    - [ ] Use commit message referencing this plan: `docs/plans/urgent/2026-01-27-user-state-value-refactor.md`

## Notes
- Related:
  - `docs/plans/urgent/2026-01-27-phone-login-user-doc-mismatch.md`
  - `docs/plans/urgent/2026-01-27-project-audit-and-polish.md`
- Add baseline `.xcresult` path here once recorded:
  - (paste path)
