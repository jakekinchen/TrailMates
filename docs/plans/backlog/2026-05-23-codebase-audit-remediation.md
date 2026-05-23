---
title: Codebase Audit Remediation
created: 2026-05-23
priority: backlog
status: in-progress
tags: [code-quality, refactor, security, performance, dedup]
---

# Codebase Audit Remediation

Full audit performed 2026-05-23 across 101 source files (~18,600 LOC). Organized by priority and domain. Each checkbox is a single atomic change.

Related plans:
- `docs/plans/urgent/2026-01-27-user-state-value-refactor.md` — keep User value-semantics and Firestore patch-write work aligned with this remediation plan.
- `docs/plans/urgent/2026-01-27-project-audit-and-polish.md` — overlaps backend sanity, dead-file cleanup, and repo simplicity work.

---

## P0 — Broken / Security / Data Loss

### Auth / Phone Account Correctness
- [ ] Replace `ChangePhoneView` phone-change flow so it reauthenticates and updates the current Firebase Auth user's phone number instead of reusing login/signup `AuthViewModel.verifyCode()`
- [ ] Ensure `ChangePhoneView` cannot sign into or switch to another existing account while changing the current user's phone number
- [ ] Normalize phone numbers to E.164 with `PhoneNumberService.shared.format(_, for: .storage)` before `UserManager.createNewUser`, `UserManager.login`, and `UserManager.updatePhoneNumber`
- [ ] Ensure `UserDataProvider.saveInitialUser` and `saveUser` only persist E.164 `phoneNumber` values
- [ ] Add regression tests for signup, login, and change-phone flows using differently formatted versions of the same phone number

### Broken Queries (EventDataProvider field name mismatches)
- [ ] Fix `EventDataProvider.swift:102` — change `"creatorId"` to `"hostId"` (or add CodingKeys to Event mapping `hostId` → `creatorId`)
- [ ] Fix `EventDataProvider.swift:121` — same `"creatorId"` → `"hostId"` mismatch
- [ ] Fix `EventDataProvider.swift:177-178` — change `"startTime"` to `"dateTime"` (or add CodingKeys to Event)

### Atomic Writes / Lost Update Prevention
- [ ] Replace event join/leave read-modify-write in `EventViewModel` + `EventDataProvider.updateEventStatus` with Firestore `FieldValue.arrayUnion` / `arrayRemove` or a transaction
- [ ] Add provider APIs for atomic event attendance updates instead of overwriting full `Event` documents
- [ ] Move `UserManager.attendEvent` / `leaveEvent` to atomic user array updates instead of full `saveProfile(updatedUser:)`
- [ ] Move `UserManager.toggleDoNotDisturb`, privacy settings, notification settings, and phone updates to partial `updateUserFields` patches
- [ ] Add tests proving concurrent joins/leaves do not drop existing attendee IDs

### Firestore Rules / Server Authority Compatibility
- [ ] Move bidirectional friend accept/remove writes out of the client provider or change Firestore rules so `FriendDataProvider.addFriend/removeFriend` can update both user documents safely
- [ ] Add Firebase Emulator tests for friend accept/remove against `firestore.rules`
- [ ] Resolve denied client `/users` collection reads from `UserDataProvider.fetchAllUsers()` by removing the client query, adding a callable, or adding narrowly scoped rules
- [ ] Resolve denied client hashed-phone queries from `UserDataProvider.fetchUser(byPhoneNumber:)` by routing through an authenticated callable or adding narrowly scoped rules
- [ ] Add explicit Firestore rules for the `landmarks` collection used by `LandmarkDataProvider`
- [ ] Add tests that distinguish permission-denied/network failures from valid empty results

### Security
- [ ] Wrap `LocationDataProvider.swift:58-63` debug prints in `#if DEBUG`
- [ ] Wrap `LocationDataProvider.swift:88-91,94,98` debug prints in `#if DEBUG`
- [ ] Add auth check to `checkUserExists` Cloud Function (`functions/index.js:292`)
- [ ] Remove `phoneNumber` from `publicUserPayload` in `functions/index.js:68-85`
- [ ] Rate-limit and App Check-protect user lookup callables (`checkUserExists`, `searchUsers`, `findUsersByPhoneNumbers`)
- [ ] Add a non-empty default pepper to `PhoneNumberHasher.swift:51` or require callers to pass one
- [ ] Move user session storage from UserDefaults to Keychain (`UserManager.swift:250`)

### Bundle / Config Hygiene
- [ ] Move signing private key and `.p12` files out of the repo checkout entirely; keep only setup docs and templates under `signing/`
- [ ] Move generated `build/` archives, IPAs, and export logs out of the repo checkout
- [ ] Exclude `TrailMates/App/GoogleService-Info.plist.template` from the signed app bundle
- [ ] Exclude `TrailMates/Models/User.swift.cursorrules` from the signed app bundle or move it out of the app source root
- [ ] Consolidate `GOOGLE_API_KEY` configuration so it is not duplicated between the shared scheme and project build settings
- [ ] Verify Firebase client keys are restricted in Google Cloud / Firebase Console before shipping

### Listener Memory Leaks
- [ ] Store RTDB observer handle returned by `FriendDataProvider.observeFriendRequests` (line 229)
- [ ] Add `stopObservingFriendRequests()` method to `FriendDataProvider`
- [ ] Store RTDB observer handle returned by `NotificationDataProvider.observeNotifications` (line 61)
- [ ] Add `stopObservingNotifications()` method to `NotificationDataProvider`
- [ ] Fix `LocationDataProvider.stopObservingUserLocation` path mismatch (line 144 vs line 113)

### deinit Actor Isolation Violations
- [ ] Fix `UserManager.deinit` (line 173) — capture `cancellables` and `currentUserId` into locals before accessing
- [ ] Fix `FirebaseDataProvider.deinit` (line 99) — capture `memoryWarningObserver`/`authStateListener` before Task
- [ ] Fix `UserDataProvider.deinit` (line 64) — don't access `userListeners` from nonisolated deinit
- [ ] Fix `LocationDataProvider.deinit` (line 27) — replace `Task { [weak self] }` pattern (self is always nil)

---

## P1 — Dead Code Deletion

- [ ] Delete `TrailMates/Models/Item.swift` (unused SwiftData template)
- [ ] Remove `Item.self` from `ModelContainer` schema in `TrailMatesApp.swift:39`
- [ ] Delete `TrailMates/Utilities/PhoneNumberUtility.swift` (deprecated, replaced by PhoneNumberService)
- [ ] Delete legacy `FloatingLabelTextField` + `InputFormattingModifier` + `CustomTextFieldStyle` in `AuthView.swift:582-705`
- [ ] Delete `UserManager.initializeUserIfNeeded()` (line 188, dead duplicate of `initializeIfNeeded`)
- [ ] Delete `UserManager.ProfileImageSize` enum (line 912, duplicate of `ImageSize`)
- [ ] Delete `UserManager.ProfileImageError` enum (line 917, duplicates `AppError`)
- [ ] Delete `FirebaseDataProvider.functionURL` (line 46, unused hardcoded URL)
- [ ] Delete `HomeView.configureTabBarAppearance()` (defined but never called)
- [ ] Delete `UnmatchedContactRow` in `ContactsListView.swift:311` (private, never used)
- [ ] Delete `FriendProfileView.handleFriendAction()` (line 95, defined but never called)
- [ ] Delete `EventViewModel.cancellables` and empty `setupSubscriptions()` method
- [ ] Remove identity map `friendIds.map { $0 }` in `EventDataProvider.swift:117`
- [ ] Remove deprecated `dataProvider` reference in `UserManager.swift:39-40`

---

## P2 — Deduplication

### Phone Number Formatting → PhoneNumberService
- [ ] Replace `AuthViewModel.formatPhoneNumber()` (line 154) with `PhoneNumberService.shared.format(_, for: .storage)`
- [ ] Replace `ChangePhoneView.formatPhoneNumber()` (line 264) with `PhoneNumberService`
- [ ] Refactor `PhoneNumberFormatter.swift` ViewModifier to delegate to `PhoneNumberService`
- [ ] Remove `UserManager.normalizePhoneNumber()` (line 458) — callers use PhoneNumberService directly
- [ ] Update test mocks (`MockUserManager`, `MockFirebaseDataProvider`, fixtures) to use `PhoneNumberService` instead of regex-only normalization

### Error Types → AppError
- [ ] Delete `Models/ValidationError.swift` — replace usage in `ContactsListViewModel.swift:101` with `AppError`
- [ ] Delete `FirebaseDataProvider.ValidationError` enum (line 397)
- [ ] Delete `ProfileSetupView.ProfileValidationError` (line 6) — use `AppError.notAuthenticated()` etc.
- [ ] Convert `EventViewModel.EventError` (line 211) throw sites to throw `AppError` directly

### Profile Image Loading → UserAvatarView
- [ ] Create `Components/Common/UserAvatarView.swift` — encapsulates image loading, circular clip, initials fallback
- [ ] Replace profile image code in `FriendsView.FriendRow` (lines 101-175) with `UserAvatarView`
- [ ] Replace profile image code in `ContactsListView.MatchedUserRow` (lines 203-307) with `UserAvatarView`
- [ ] Replace profile image code in `Components/Cards/ProfileHeader.swift` (lines 23-86) with `UserAvatarView`
- [ ] Replace profile image code in `AddFriendsView.FriendLookupAvatar` (lines 461-506) with `UserAvatarView`
- [ ] Replace profile image code in `MapView.FriendsSection` (lines 339-350) with `UserAvatarView`

### Initials Computation → User Extension
- [ ] Add `var initials: String` computed property to `User` model
- [ ] Remove `initials` from `FriendsView.FriendRow` (line 104)
- [ ] Remove `initials` from `AddFriendsView` (line 469)
- [ ] Update `Friend.initials` (line 55) to use shared logic

### EventGroup Struct
- [ ] Move `EventGroup` to `Models/` or `ViewModels/EventViewModel.swift`
- [ ] Remove duplicate definition from `MapView.swift:134`
- [ ] Remove duplicate definition from `EventsView.swift:21`

### Floating-Label TextField → Single Component
- [ ] Create `Components/Forms/FloatingLabelTextField.swift` — configurable, replaces all 5 variants
- [ ] Replace `AuthFloatingLabelTextField` in `AuthView.swift:405` with shared component
- [ ] Replace `ProfileFloatingLabelTextField` in `ProfileSetupView.swift:430`
- [ ] Replace `FriendLookupTextField` in `AddFriendsView.swift:358`
- [ ] Replace `PhoneNumberInput`/`VerificationCodeInput` in `ChangePhoneView.swift:294`

### overlayColor / Background Pattern
- [ ] Create a `.themedBackground()` view modifier encapsulating `ZStack { Color("beige").ignoresSafeArea() }` + `overlayColor`
- [ ] Replace 7 duplicate `overlayColor` computed properties across settings views
- [ ] Replace 16 instances of `Color("beige").ignoresSafeArea()` pattern

### Section Header
- [ ] Create `Components/Common/SectionHeader.swift`
- [ ] Replace `MapView.sectionHeader` (line 304)
- [ ] Replace `EventsView.makeGroupHeader` (line 91)
- [ ] Replace `FriendsView.FriendsSectionHeader` (line 178)
- [ ] Replace `ContactsListView.SectionHeader` (line 181)

### Notification Duplicate
- [ ] Remove `getTitleForNotificationType` from `FirebaseDataProvider.swift:367` (keep NotificationDataProvider version)

### DateFormatter Caching
- [ ] Make `Event.formattedDate()` use a `static let` DateFormatter instead of creating new ones
- [ ] Same for `EventDetailView.swift:306`
- [ ] Same for `UserManager.swift:638`
- [ ] Same for `EventViewModel.swift:78`

---

## P3 — Design System Adoption

### Replace Raw Color Literals with AppColors
- [ ] Audit and replace `Color("pine")` (~100 occurrences) with `AppColors.textPrimary` / appropriate semantic constant
- [ ] Audit and replace `Color("beige")` (~50 occurrences) with `AppColors.backgroundPrimary`
- [ ] Audit and replace `Color("pumpkin")` (~30 occurrences) with `AppColors.buttonPrimary`
- [ ] Audit and replace `Color("sage")` (~15 occurrences) with appropriate `AppColors` constant
- [ ] Audit and replace `Color("alwaysBeige")`/`Color("alwaysPine")`/`Color("altBeige")` with `AppColors` constants

### Replace Inline Fonts with AppTypography
- [ ] Replace `Font.custom("Magic Retro", size: 48)` in `AuthView.swift:118` with `AppTypography.displayLarge`
- [ ] Replace `Font.custom("Magic Retro", size: 24)` in `NavigationBarModifier.swift:22` with `AppTypography.displaySmall`
- [ ] Replace `Font.custom("SF Pro", size: ...)` instances in `ProfileSetupView.swift` and `ChangePhoneView.swift`
- [ ] Audit remaining `.font(.system(size: X, weight: Y))` calls for consistency with `AppTypography`

### Adopt Existing Reusable Components
- [ ] Replace inline pumpkin-button styling (~10 instances) with `PrimaryButton`
- [ ] Replace inline empty states in `FriendsView`, `EventsView`, `ContactsListView` with `EmptyStateView`
- [ ] Replace inline `ProgressView()` loading patterns with `LoadingView` where appropriate

---

## P4 — Architecture & Patterns

### ContentView AnyView Removal
- [ ] Refactor `ContentView.swift` to use `@ViewBuilder` if/else instead of `AnyView` wrapping

### User State Source of Truth
- [ ] Decide whether `User` remains a SwiftData `@Model` or becomes a value type; do not keep SwiftData annotations if persistence remains `UserDefaults` / Firebase-only
- [ ] Remove `Item.self` from `ModelContainer` after deleting the unused template model
- [ ] Add a persisted user schema version and clear stale `UserDefaults` user data on decode/version mismatch
- [ ] Ensure remote Firebase user fetch wins over stale local persisted user data immediately after login
- [ ] Replace manual `objectWillChange.send()` around same-reference `User` mutations with explicit reassignment or value semantics

### SettingsView Decomposition
- [ ] Extract `PrivacySettingsView` to its own file
- [ ] Extract `NotificationSettingsView` to its own file
- [ ] Extract `HelpCenterView` + `FAQDetailView` to their own file
- [ ] Extract `AboutView` to its own file
- [ ] Extract `AcknowledgmentsView` to its own file
- [ ] Extract `SettingsRow` / `PreferenceToggleRow` to `Components/`

### Business Logic Out of Views
- [ ] Move `MapView.getEventGroups()` (line 140) to `EventViewModel`
- [ ] Move `MapView.getUserEvents()` (line 290) to `EventViewModel`
- [ ] Move `ProfileSetupView.saveProfile/validateInputs/updateUserProfile` (line 288) to a `ProfileSetupViewModel`
- [ ] Move `ProfileView.cacheStats/loadCachedStats` (line 107) to `UserManager`
- [ ] Move `AuthView.handleLogin/handleSignup` (line 299) business logic to `AuthViewModel`
- [ ] Move `EventDetailView` UIKit interop (lines 171-313) to a service or use `.confirmationDialog`

### NotificationsView ViewModel Extraction
- [ ] Move `NotificationsViewModel` from `NotificationsView.swift` to `ViewModels/NotificationsViewModel.swift`
- [ ] Remove per-row `NotificationRowViewModel` — handle tap in parent ViewModel
- [ ] Move `UserStats` from `ProfileView.swift` to `Models/`

### Navigation Consistency
- [ ] Wrap each tab's content in `HomeView` with `NavigationStack`
- [ ] Replace `NavigationView` with `NavigationStack` in `EventsView.swift:169` sheet
- [ ] Replace `NavigationView` with `NavigationStack` in `MapView.swift:68` sheet

### Deprecated API Migration
- [ ] Replace `@Environment(\.presentationMode)` with `@Environment(\.dismiss)` in `ProfileSetupView.swift:25`
- [ ] Replace `@Environment(\.presentationMode)` with `@Environment(\.dismiss)` in `ImageCropper.swift:6`
- [ ] Replace `.actionSheet` with `.confirmationDialog` in `ProfileSetupView.swift:87`
- [ ] Replace legacy `Alert` constructor in `ProfileSetupView.swift:80`

### ViewModel Ownership Consistency
- [ ] Fix `@StateObject` wrapping of `EventViewModel.shared` singleton in `MapView.swift:11` and `HomeView.swift:6`
- [ ] Resolve `AuthViewModel` ownership conflict — single source of truth via `@EnvironmentObject`
- [ ] Remove separate `AuthViewModel()` instance creation in `ChangePhoneView.swift:24`

---

## P5 — Firebase & Networking

### Error Wrapping
- [ ] Wrap RTDB errors in `AppError.from(error)` in `FriendDataProvider` (lines 62, 89, 111, 131)
- [ ] Wrap RTDB errors in `AppError.from(error)` in `NotificationDataProvider` (lines 38, 109, 159, 175, 190)
- [ ] Wrap RTDB errors in `AppError.from(error)` in `LocationDataProvider` (lines 92, 161)
- [ ] Classify Firestore errors in `AppError.from()` so `withRetry` actually retries them
- [ ] Stop converting provider permission/network failures into `nil`, `[]`, or `false`; surface `AppError` to callers that need retry/error UI
- [ ] Re-throw `CancellationError` before wrapping errors in `AppError.from` / `withRetry`

### Query Efficiency
- [ ] Add pagination/limit to `EventDataProvider.fetchAllEvents()`
- [ ] Add pagination/limit to `UserDataProvider.fetchAllUsers()`
- [ ] Replace `LandmarkDataProvider.fetchTotalLandmarks()` with Firestore `count()` aggregation
- [ ] Batch `UserDataProvider.fetchFriends()` using `whereField("id", in:)` or `TaskGroup`
- [ ] Decouple image downloading from `UserDataProvider.fetchUser(by:)` — make it lazy
- [ ] Remove Firestore URL-deletion side effects from `UserDataProvider.fetchUser(by:)` image-download failure paths
- [ ] Add chunking for `fetchCircleEvents` when friendIds exceeds Firestore `in` limit of 30

### Serialization Consistency
- [ ] Unify `saveInitialUser` (manual dict) with `saveUser` (Firestore.Encoder) to use same path
- [ ] Fix `callableUser(from:)` to populate all User fields (missing settings, hashed phone, etc.)
- [ ] Fix `callableDate(from:)` silent fallback to `Date()` — log a warning or throw

### Firestore Configuration
- [ ] Configure `FirestoreSettings` + `PersistentCacheSettings` once globally, remove from 4 individual provider inits

### Collection/Function Name Constants
- [ ] Create `FirestoreConstants.swift` with `static let` for collection names (`users`, `events`, `landmarks`, etc.)
- [ ] Create constants for Cloud Function names (`checkUserExists`, `searchUsers`, etc.)
- [ ] Replace all hardcoded string literals across providers

### Image Caching
- [ ] Add disk-backed image cache to `ImageStorageProvider` (FileManager or URLCache)

### Auth Checks
- [ ] Add `Auth.auth().currentUser` check to `NotificationDataProvider.sendNotification` (line 23)
- [ ] Add ownership validation to `LandmarkDataProvider.markLandmarkVisited` (line 76)
- [ ] Fix `checkUsernameTaken` Cloud Function to query `usernameSearchKey` not `username`
- [ ] Ensure `searchUsers` and `fetchPublicUserProfile` never return raw phone numbers or private settings

### Provider Pattern Compliance
- [ ] Replace direct provider access in `AuthViewModel.deleteAccount()` with `FirebaseProviderContainer.shared`
- [ ] Replace direct `Auth.auth()` calls in `FriendDataProvider` with stored `auth` property (lines 45, 101, 123, 219)
- [ ] Replace direct `Auth.auth()` calls in `NotificationDataProvider.swift:51`
- [ ] Replace direct `Auth.auth()` calls in `LocationDataProvider.swift:46`
- [ ] Replace direct `Auth.auth()` calls in `NotificationsView.swift:147,160,188`
- [ ] Remove direct `ImageStorageProvider.shared` call in `UserDataProvider.swift:163` — inject via container

### Legacy Provider Removal
- [ ] Remove all remaining callers of `FirebaseDataProvider.shared`
- [ ] Delete `FirebaseDataProvider.swift` (444 lines, entirely deprecated pass-through)

---

## P6 — Swift Concurrency

### Data Race Fixes
- [ ] Add `@MainActor` dispatch inside `UserDataProvider.observeUser` callback before calling `onChange`
- [ ] Add `@MainActor` dispatch inside `NotificationDataProvider.observeNotifications` callback
- [ ] Add `@MainActor` dispatch inside `LocationDataProvider.observeUserLocation` callback
- [ ] Add `@MainActor` dispatch inside `FriendDataProvider.observeFriendRequests` callback
- [ ] Mark observer `completion`/`onChange` closures as `@Sendable` in provider protocols

### User Model Sendability
- [ ] Add `@unchecked Sendable` to `User` class with documentation that access is confined to `@MainActor`
- [ ] (Alternative) Evaluate converting `User` to a struct if SwiftData allows

### Redundant MainActor.run Removal
- [ ] Remove `await MainActor.run { }` calls inside `@MainActor`-isolated `UserManager` methods (8+ locations)
- [ ] Remove `await MainActor.run { }` in `AuthViewModel.verifyCode()` (lines 119, 143)
- [ ] Remove `await MainActor.run { }` in `AuthViewModel.deleteAccount()` (line 283)

### Task Parallelism Fix
- [ ] Fix `ImageStorageProvider.prefetchProfileImages` — use `@Sendable` closure in `group.addTask` to avoid main-thread serialization

### Cancellation
- [ ] Add `try Task.checkCancellation()` before each retry in `AppError.withRetry` (line 247)
- [ ] Store and cancel the `MapView` startup task that calls `loadData()` before starting location polling
- [ ] Replace `LocationPickerView` per-region-change geocoding tasks with one cancellable task and stale-coordinate checks
- [ ] Add an in-flight guard to `LocationManager.requestLocationPermission()` so overlapping calls cannot overwrite a continuation
- [ ] Add cancellation/stale-attempt handling to `AuthViewModel.sendCode()` continuation bridge
- [ ] Convert contacts loading from `onAppear { Task { ... } }` to `.task` with cancellation-aware contact enumeration
- [ ] Audit fire-and-forget `Task` blocks in `EventsView`, `EventDetailView`, `SettingsView`, and button actions so thrown errors are surfaced as `AppError`

### Build Settings
- [ ] Plan Swift 6 / strict concurrency migration after the app has a green baseline build and test run
- [ ] Remove broad warning suppression from Package/build settings before enabling stricter concurrency checks

---

## P7 — Low Priority / Polish

### Debug Print Cleanup
- [ ] Wrap `ProfileSetupView.swift` ~30 print statements in `#if DEBUG`
- [ ] Wrap `AuthView.swift` print statements (lines 303-318) in `#if DEBUG`
- [ ] Wrap `CreateEventView.swift` print statements (lines 79, 232-291) in `#if DEBUG`
- [ ] Wrap `UserManager.persistUserSession()` prints (lines 243-266) in `#if DEBUG`
- [ ] Wrap `SettingsView.swift:164` print in `#if DEBUG`

### Hardcoded URL Constants
- [ ] Replace placeholder App Store ID in `SettingsView.swift:192`
- [ ] Move support/social URLs in `SettingsView.swift` (lines 691, 699, 846-870) to a constants file

### Accessibility
- [ ] Add accessibility label to profile image picker in `ProfileSetupView.swift:164`
- [ ] Add accessibility labels to `EventRowView` rows
- [ ] Add accessibility label to map preview tap in `EventDetailView.swift:100`
- [ ] Add accessibility support to `ImageCropper.swift`
- [ ] Add `.accessibilityElement(children: .combine)` to `StatCard` in `ProfileView.swift`
- [ ] Add accessibility labels to `NotificationRow` (title + message + read status)
- [ ] Add accessibility hint to "Get Started" button in `WelcomeView.swift:87`

### File Organization
- [ ] Move `NavigationBarModifier.swift` to `Components/Modifiers/`
- [ ] Move `ImageCropper.swift` to `Components/` (rename to `ImageCropperView.swift`)
- [ ] Delete or archive `User.swift.cursorrules`
- [ ] Remove unused `auth` lazy property from `FriendDataProvider.swift:17` (if replacing with direct calls) or use it consistently

### MapCoordinator Isolation
- [ ] Add `@MainActor` annotation to `MapCoordinator` in `UnifiedMapView.swift:104`

---

## P8 — Tests / Build / Planning Hygiene

### Test Coverage
- [ ] Replace placeholder default tests in `TrailMatesTests.swift` with meaningful smoke coverage
- [ ] Add unit tests for phone normalization and hash consistency across signup, login, search, and change-phone paths
- [ ] Add Firebase Emulator tests for callable privacy, Firestore rules, friend accept/remove, and event attendance atomic writes
- [ ] Replace manually mutated auth tests with tests that exercise `AuthViewModel` state transitions through its public async methods
- [ ] Add UI tests for the auth route, onboarding gate, friend search, event join/leave, and settings account deletion entry point

### Build Configuration
- [ ] Change shared scheme `LaunchAction` back to `Debug` unless there is a documented reason to launch Release locally
- [ ] Remove duplicate API-key injection from the shared scheme or project settings after choosing one source of truth
- [ ] Wire `Config.xcconfig` intentionally or delete it if it is stale
- [ ] Remove unsafe `-suppress-warnings` flags from `Package.swift` if the package is only documentation for Xcode-managed dependencies

### Repo Hygiene
- [ ] Remove empty root `package-lock.json` if there is no root `package.json`
- [ ] Consolidate duplicate `Package.resolved` files under the project/workspace
- [ ] Remove duplicate Preview Content asset catalogs if only one is used by the target
- [ ] Clean ignored `.DS_Store`, `.build/`, `functions/node_modules/`, and derived artifacts from local repo-adjacent folders

### Plan Lifecycle
- [ ] Normalize archived plan frontmatter from `status: complete` to `status: completed`
- [ ] Review archived plans with unchecked boxes and either complete the work, move leftovers to backlog, or correct the archive status
