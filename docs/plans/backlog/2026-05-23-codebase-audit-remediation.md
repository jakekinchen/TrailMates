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
- [x] Replace `ChangePhoneView` phone-change flow so it reauthenticates and updates the current Firebase Auth user's phone number instead of reusing login/signup `AuthViewModel.verifyCode()`
- [x] Ensure `ChangePhoneView` cannot sign into or switch to another existing account while changing the current user's phone number
- [x] Normalize phone numbers to E.164 with `PhoneNumberService.shared.format(_, for: .storage)` before `UserManager.createNewUser`, `UserManager.login`, and `UserManager.updatePhoneNumber`
- [x] Ensure `UserDataProvider.saveInitialUser` and `saveUser` only persist E.164 `phoneNumber` values
- [ ] Add regression tests for signup, login, and change-phone flows using differently formatted versions of the same phone number

### Broken Queries (EventDataProvider field name mismatches)
- [x] Fix `EventDataProvider.swift:102` — change `"creatorId"` to `"hostId"` (or add CodingKeys to Event mapping `hostId` → `creatorId`)
- [x] Fix `EventDataProvider.swift:121` — same `"creatorId"` → `"hostId"` mismatch
- [x] Fix `EventDataProvider.swift:177-178` — change `"startTime"` to `"dateTime"` (or add CodingKeys to Event)

### Atomic Writes / Lost Update Prevention
- [x] Replace event join/leave read-modify-write in `EventViewModel` + `EventDataProvider.updateEventStatus` with Firestore `FieldValue.arrayUnion` / `arrayRemove` or a transaction
- [x] Add provider APIs for atomic event attendance updates instead of overwriting full `Event` documents
- [x] Move `UserManager.attendEvent` / `leaveEvent` to atomic user array updates instead of full `saveProfile(updatedUser:)`
- [x] Move `UserManager.toggleDoNotDisturb`, privacy settings, notification settings, and phone updates to partial `updateUserFields` patches
- [ ] Add tests proving concurrent joins/leaves do not drop existing attendee IDs

### Firestore Rules / Server Authority Compatibility
- [x] Move bidirectional friend accept/remove writes out of the client provider or change Firestore rules so `FriendDataProvider.addFriend/removeFriend` can update both user documents safely
- [ ] Add Firebase Emulator tests for friend accept/remove against `firestore.rules`
- [x] Resolve denied client `/users` collection reads from `UserDataProvider.fetchAllUsers()` by removing the client query, adding a callable, or adding narrowly scoped rules
- [x] Resolve denied client hashed-phone queries from `UserDataProvider.fetchUser(byPhoneNumber:)` by routing through an authenticated callable or adding narrowly scoped rules
- [x] Add explicit Firestore rules for the `landmarks` collection used by `LandmarkDataProvider`
- [ ] Add tests that distinguish permission-denied/network failures from valid empty results

### Security
- [x] Wrap `LocationDataProvider.swift:58-63` debug prints in `#if DEBUG`
- [x] Wrap `LocationDataProvider.swift:88-91,94,98` debug prints in `#if DEBUG`
- [x] Add auth check to `checkUserExists` Cloud Function (`functions/index.js:292`)
- [x] Remove `phoneNumber` from `publicUserPayload` in `functions/index.js:68-85`
- [x] Rate-limit and App Check-protect user lookup callables (`checkUserExists`, `searchUsers`, `findUsersByPhoneNumbers`)
- [ ] Add a non-empty default pepper to `PhoneNumberHasher.swift:51` or require callers to pass one
- [x] Move user session storage from UserDefaults to Keychain (`UserManager.swift:250`)

### Bundle / Config Hygiene
- [x] Move signing private key and `.p12` files out of the repo checkout entirely; keep only setup docs and templates under `signing/`
- [x] Move generated `build/` archives, IPAs, and export logs out of the repo checkout
- [x] Exclude `TrailMates/App/GoogleService-Info.plist.template` from the signed app bundle
- [x] Confirm `TrailMates/Models/User.swift.cursorrules` is no longer present in the app source root or signed app bundle
- [x] Consolidate `GOOGLE_API_KEY` configuration so it is not duplicated between the shared scheme and project build settings
- [ ] Verify Firebase client keys are restricted in Google Cloud / Firebase Console before shipping

### Listener Memory Leaks
- [x] Store RTDB observer handle returned by `FriendDataProvider.observeFriendRequests` (line 229)
- [x] Add `stopObservingFriendRequests()` method to `FriendDataProvider`
- [x] Store RTDB observer handle returned by `NotificationDataProvider.observeNotifications` (line 61)
- [x] Add `stopObservingNotifications()` method to `NotificationDataProvider`
- [x] Fix `LocationDataProvider.stopObservingUserLocation` path mismatch (line 144 vs line 113)

### deinit Actor Isolation Violations
- [x] Fix `UserManager.deinit` (line 173) — capture `cancellables` and `currentUserId` into locals before accessing
- [x] Fix `FirebaseDataProvider.deinit` (line 99) — capture `memoryWarningObserver`/`authStateListener` before Task
- [x] Fix `UserDataProvider.deinit` (line 64) — don't access `userListeners` from nonisolated deinit
- [x] Fix `LocationDataProvider.deinit` (line 27) — replace `Task { [weak self] }` pattern (self is always nil)

---

## P1 — Dead Code Deletion

- [x] Delete `TrailMates/Models/Item.swift` (unused SwiftData template)
- [x] Remove `Item.self` from `ModelContainer` schema in `TrailMatesApp.swift:39`
- [x] Delete `TrailMates/Utilities/PhoneNumberUtility.swift` (deprecated, replaced by PhoneNumberService)
- [x] Delete legacy `FloatingLabelTextField` + `InputFormattingModifier` + `CustomTextFieldStyle` in `AuthView.swift:582-705`
- [x] Delete `UserManager.initializeUserIfNeeded()` (line 188, dead duplicate of `initializeIfNeeded`)
- [x] Delete `UserManager.ProfileImageSize` enum (line 912, duplicate of `ImageSize`)
- [x] Delete `UserManager.ProfileImageError` enum (line 917, duplicates `AppError`)
- [x] Delete `FirebaseDataProvider.functionURL` (line 46, unused hardcoded URL)
- [x] Delete `HomeView.configureTabBarAppearance()` (defined but never called)
- [x] Delete `UnmatchedContactRow` in `ContactsListView.swift:311` (private, never used)
- [x] Delete `FriendProfileView.handleFriendAction()` (line 95, defined but never called)
- [x] Delete `EventViewModel.cancellables` and empty `setupSubscriptions()` method
- [x] Remove identity map `friendIds.map { $0 }` in `EventDataProvider.swift:117`
- [x] Remove deprecated `dataProvider` reference in `UserManager.swift:39-40`

---

## P2 — Deduplication

### Phone Number Formatting → PhoneNumberService
- [x] Replace `AuthViewModel.formatPhoneNumber()` (line 154) with `PhoneNumberService.shared.format(_, for: .storage)`
- [x] Replace `ChangePhoneView.formatPhoneNumber()` (line 264) with `PhoneNumberService`
- [x] Refactor `PhoneNumberFormatter.swift` ViewModifier to delegate to `PhoneNumberService`
- [x] Remove `UserManager.normalizePhoneNumber()` (line 458) — callers use PhoneNumberService directly
- [x] Update test mocks (`MockUserManager`, `MockFirebaseDataProvider`, fixtures) to use `PhoneNumberService` instead of regex-only normalization

### Error Types → AppError
- [x] Delete `Models/ValidationError.swift` — replace usage in `ContactsListViewModel.swift:101` with `AppError`
- [x] Delete `FirebaseDataProvider.ValidationError` enum (line 397)
- [x] Delete `ProfileSetupView.ProfileValidationError` (line 6) — use `AppError.notAuthenticated()` etc.
- [x] Convert `EventViewModel.EventError` (line 211) throw sites to throw `AppError` directly

### Profile Image Loading → UserAvatarView
- [x] Create `Components/Common/UserAvatarView.swift` — encapsulates image loading, circular clip, initials fallback
- [x] Replace profile image code in `FriendsView.FriendRow` (lines 101-175) with `UserAvatarView`
- [x] Replace profile image code in `ContactsListView.MatchedUserRow` (lines 203-307) with `UserAvatarView`
- [x] Replace profile image code in `Components/Cards/ProfileHeader.swift` (lines 23-86) with `UserAvatarView`
- [x] Replace profile image code in `AddFriendsView.FriendLookupAvatar` (lines 461-506) with `UserAvatarView`
- [x] Replace profile image code in `MapView.FriendsSection` (lines 339-350) with `UserAvatarView`

### Initials Computation → User Extension
- [x] Add `var initials: String` computed property to `User` model
- [x] Remove `initials` from `FriendsView.FriendRow` (line 104)
- [x] Remove `initials` from `AddFriendsView` (line 469)
- [x] Update `Friend.initials` (line 55) to use shared logic

### EventGroup Struct
- [x] Move `EventGroup` to `Models/` or `ViewModels/EventViewModel.swift`
- [x] Remove duplicate definition from `MapView.swift:134`
- [x] Remove duplicate definition from `EventsView.swift:21`

### Floating-Label TextField → Single Component
- [x] Create `Components/Forms/FloatingLabelTextField.swift` — configurable, replaces all 5 variants
- [x] Replace `AuthFloatingLabelTextField` in `AuthView.swift:405` with shared component
- [x] Replace `ProfileFloatingLabelTextField` in `ProfileSetupView.swift:430`
- [x] Replace `FriendLookupTextField` in `AddFriendsView.swift:358`
- [x] Replace `PhoneNumberInput`/`VerificationCodeInput` in `ChangePhoneView.swift:294`

### overlayColor / Background Pattern
- [x] Create a `.themedBackground()` view modifier encapsulating `ZStack { Color("beige").ignoresSafeArea() }` + `overlayColor`
- [x] Replace 7 duplicate `overlayColor` computed properties across settings views
- [x] Replace 16 instances of `Color("beige").ignoresSafeArea()` pattern

### Section Header
- [x] Create `Components/Common/SectionHeader.swift`
- [x] Replace `MapView.sectionHeader` (line 304)
- [x] Replace `EventsView.makeGroupHeader` (line 91)
- [x] Replace `FriendsView.FriendsSectionHeader` (line 178)
- [x] Replace `ContactsListView.SectionHeader` (line 181)

### Notification Duplicate
- [x] Remove `getTitleForNotificationType` from `FirebaseDataProvider.swift:367` (keep NotificationDataProvider version)

### DateFormatter Caching
- [x] Make `Event.formattedDate()` use a `static let` DateFormatter instead of creating new ones
- [x] Same for `EventDetailView.swift:306`
- [x] Same for `UserManager.swift:638`
- [x] Same for `EventViewModel.swift:78`

---

## P3 — Design System Adoption

### Replace Raw Color Literals with AppColors
- [x] Audit and replace `Color("pine")` (~100 occurrences) with `AppColors.pine`
- [x] Audit and replace `Color("beige")` (~50 occurrences) with `AppColors.beige`
- [x] Audit and replace `Color("pumpkin")` (~30 occurrences) with `AppColors.pumpkin`
- [x] Audit and replace `Color("sage")` (~15 occurrences) with `AppColors.sage`
- [x] Audit and replace `Color("alwaysBeige")`/`Color("alwaysPine")`/`Color("altBeige")` with `AppColors` constants (note: `altBeige` has no AppColors mapping — left as-is)

### Replace Inline Fonts with AppTypography
- [x] Replace `Font.custom("Magic Retro", size: 48)` in `AuthView.swift:118` with `AppTypography.displayLarge`
- [x] Replace `Font.custom("Magic Retro", size: 24)` in `NavigationBarModifier.swift:22` with `AppTypography.displaySmall`
- [x] Replace `Font.custom("SF Pro", size: ...)` instances in `ProfileSetupView.swift` and `ChangePhoneView.swift`
- [x] Audit remaining `.font(.system(size: X, weight: Y))` calls for consistency with `AppTypography`

### Adopt Existing Reusable Components
- [x] Replace inline pumpkin-button styling (~10 instances) with `PrimaryButton`
- [x] Replace inline empty states in `FriendsView`, `EventsView`, `ContactsListView` with `EmptyStateView`
- [x] Replace inline `ProgressView()` loading patterns with `LoadingView` where appropriate

---

## P4 — Architecture & Patterns

### ContentView AnyView Removal
- [x] Refactor `ContentView.swift` to use `@ViewBuilder` if/else instead of `AnyView` wrapping

### User State Source of Truth
- [x] Decide whether `User` remains a SwiftData `@Model` or becomes a value type; do not keep SwiftData annotations if persistence remains `UserDefaults` / Firebase-only
- [x] Confirm `Item.self` is already removed from `ModelContainer` after deleting the unused template model
- [x] Add a persisted user schema version and clear stale `UserDefaults` user data on decode/version mismatch
- [x] Ensure remote Firebase user fetch wins over stale local persisted user data immediately after login
- [x] Replace manual `objectWillChange.send()` around same-reference `User` mutations with explicit reassignment or value semantics

### SettingsView Decomposition
- [x] Extract `PrivacySettingsView` to its own file
- [x] Extract `NotificationSettingsView` to its own file
- [x] Extract `HelpCenterView` + `FAQDetailView` to their own file
- [x] Extract `AboutView` to its own file
- [x] Extract `AcknowledgmentsView` to its own file
- [x] Extract `SettingsRow` / `PreferenceToggleRow` to `Components/`

### Business Logic Out of Views
- [x] Move `MapView.getEventGroups()` (line 140) to `EventViewModel`
- [x] Move `MapView.getUserEvents()` (line 290) to `EventViewModel`
- [x] Move `ProfileSetupView.saveProfile/validateInputs/updateUserProfile` (line 288) to a `ProfileSetupViewModel`
- [x] Move `ProfileView.cacheStats/loadCachedStats` (line 107) to `UserManager`
- [x] Move `AuthView.handleLogin/handleSignup` (line 299) business logic to `AuthViewModel`
- [x] Move `EventDetailView` UIKit interop (lines 171-313) to `SharingService`

### NotificationsView ViewModel Extraction
- [x] Move `NotificationsViewModel` from `NotificationsView.swift` to `ViewModels/NotificationsViewModel.swift`
- [x] Remove per-row `NotificationRowViewModel` — handle tap in parent ViewModel
- [x] Move `UserStats` from `ProfileView.swift` to `Models/`

### Navigation Consistency
- [x] Wrap each tab's content in `HomeView` with `NavigationStack`
- [x] Replace `NavigationView` with `NavigationStack` in `EventsView.swift:169` sheet
- [x] Replace `NavigationView` with `NavigationStack` in `MapView.swift:68` sheet

### Deprecated API Migration
- [x] Replace `@Environment(\.presentationMode)` with `@Environment(\.dismiss)` in `ProfileSetupView.swift:25`
- [x] Replace `@Environment(\.presentationMode)` with `@Environment(\.dismiss)` in `ImageCropper.swift:6`
- [x] Replace `.actionSheet` with `.confirmationDialog` in `ProfileSetupView.swift:87`
- [x] Replace legacy `Alert` constructor in `ProfileSetupView.swift:80`

### ViewModel Ownership Consistency
- [x] Fix `@StateObject` wrapping of `EventViewModel.shared` singleton in `MapView.swift:11` and `HomeView.swift:6`
- [x] Resolve `AuthViewModel` ownership conflict — single source of truth via `@EnvironmentObject`
- [x] Remove separate `AuthViewModel()` instance creation in `ChangePhoneView.swift:24`

---

## P5 — Firebase & Networking

### Error Wrapping
- [x] Wrap RTDB errors in `AppError.from(error)` in `FriendDataProvider` (lines 62, 89, 111, 131)
- [x] Wrap RTDB errors in `AppError.from(error)` in `NotificationDataProvider` (lines 38, 109, 159, 175, 190)
- [x] Wrap RTDB errors in `AppError.from(error)` in `LocationDataProvider` (lines 92, 161)
- [x] Classify Firestore errors in `AppError.from()` so `withRetry` actually retries them
- [x] Stop converting provider permission/network failures into `nil`, `[]`, or `false`; surface `AppError` to callers that need retry/error UI
- [x] Re-throw `CancellationError` before wrapping errors in `AppError.from` / `withRetry`

### Query Efficiency
- [x] Add pagination/limit to `EventDataProvider.fetchAllEvents()`
- [x] Add pagination/limit to `UserDataProvider.fetchAllUsers()`
- [x] Replace `LandmarkDataProvider.fetchTotalLandmarks()` with Firestore `count()` aggregation
- [x] Batch `UserDataProvider.fetchFriends()` using `whereField("id", in:)` or `TaskGroup`
- [x] Decouple image downloading from `UserDataProvider.fetchUser(by:)` — make it lazy
- [x] Remove Firestore URL-deletion side effects from `UserDataProvider.fetchUser(by:)` image-download failure paths
- [x] Add chunking for `fetchCircleEvents` when friendIds exceeds Firestore `in` limit of 30

### Serialization Consistency
- [x] Unify `saveInitialUser` (manual dict) with `saveUser` (Firestore.Encoder) to use same path
- [x] Fix `callableUser(from:)` to populate all User fields (missing settings, hashed phone, etc.)
- [x] Fix `callableDate(from:)` silent fallback to `Date()` — log a warning or throw

### Firestore Configuration
- [x] Configure `FirestoreSettings` + `PersistentCacheSettings` once globally, remove from 4 individual provider inits

### Collection/Function Name Constants
- [x] Create `FirestoreConstants.swift` with `static let` for collection names (`users`, `events`, `landmarks`, etc.)
- [x] Create constants for Cloud Function names (`checkUserExists`, `searchUsers`, etc.)
- [x] Replace all hardcoded string literals across providers

### Image Caching
- [x] Add disk-backed image cache to `ImageStorageProvider` (FileManager or URLCache)

### Auth Checks
- [x] Add `Auth.auth().currentUser` check to `NotificationDataProvider.sendNotification` (line 23)
- [x] Add ownership validation to `LandmarkDataProvider.markLandmarkVisited` (line 76)
- [x] Fix `checkUsernameTaken` Cloud Function to query `usernameSearchKey` not `username`
- [x] Ensure `searchUsers` and `fetchPublicUserProfile` never return raw phone numbers or private settings

### Provider Pattern Compliance
- [x] Replace direct provider access in `AuthViewModel.deleteAccount()` with `FirebaseProviderContainer.shared`
- [x] Replace direct `Auth.auth()` calls in `FriendDataProvider` with stored `auth` property (lines 45, 101, 123, 219)
- [x] Replace direct `Auth.auth()` calls in `NotificationDataProvider.swift:51`
- [x] Replace direct `Auth.auth()` calls in `LocationDataProvider.swift:46`
- [x] Replace direct `Auth.auth()` calls in `NotificationsView.swift:147,160,188`
- [x] Remove direct `ImageStorageProvider.shared` call in `UserDataProvider.swift:163` — inject via container

### Legacy Provider Removal
- [x] Remove all remaining callers of `FirebaseDataProvider.shared` (zero production callers — marked `@available(*, deprecated)`)
- [ ] Delete `FirebaseDataProvider.swift` (retained for test suite — migrate tests first)

---

## P6 — Swift Concurrency

### Data Race Fixes
- [x] Add `@MainActor` dispatch inside `UserDataProvider.observeUser` callback before calling `onChange`
- [x] Add `@MainActor` dispatch inside `NotificationDataProvider.observeNotifications` callback
- [x] Add `@MainActor` dispatch inside `LocationDataProvider.observeUserLocation` callback
- [x] Add `@MainActor` dispatch inside `FriendDataProvider.observeFriendRequests` callback
- [x] Mark observer `completion`/`onChange` closures as `@Sendable` in provider protocols

### User Model Sendability
- [x] Remove redundant explicit `@unchecked Sendable` from `User`; rely on SwiftData-generated conformance to avoid duplicate-conformance warnings
- [ ] (Alternative) Evaluate converting `User` to a struct if SwiftData allows

### Redundant MainActor.run Removal
- [x] Remove `await MainActor.run { }` calls inside `@MainActor`-isolated `UserManager` methods (8+ locations)
- [x] Remove `await MainActor.run { }` in `AuthViewModel.verifyCode()` (lines 119, 143)
- [x] Remove `await MainActor.run { }` in `AuthViewModel.deleteAccount()` (line 283)

### Task Parallelism Fix
- [x] Fix `ImageStorageProvider.prefetchProfileImages` — use `@Sendable` closure in `group.addTask` to avoid main-thread serialization

### Cancellation
- [x] Add `try Task.checkCancellation()` before each retry in `AppError.withRetry` (line 247)
- [x] Store and cancel the `MapView` startup task that calls `loadData()` before starting location polling
- [x] Replace `LocationPickerView` per-region-change geocoding tasks with one cancellable task and stale-coordinate checks
- [x] Add an in-flight guard to `LocationManager.requestLocationPermission()` so overlapping calls cannot overwrite a continuation
- [x] Add cancellation/stale-attempt handling to `AuthViewModel.sendCode()` continuation bridge
- [x] Convert contacts loading from `onAppear { Task { ... } }` to `.task` with cancellation-aware contact enumeration
- [x] Audit fire-and-forget `Task` blocks in `EventsView`, `EventDetailView`, `SettingsView`, and button actions so thrown errors are surfaced as `AppError`

### Build Settings
- [x] Plan Swift 6 / strict concurrency migration after the app has a green baseline build and test run — see `2026-05-25-swift-6-strict-concurrency-migration.md`
- [x] Remove broad warning suppression from Package/build settings before enabling stricter concurrency checks

---

## P7 — Low Priority / Polish

### Debug Print Cleanup
- [x] Wrap `ProfileSetupView.swift` ~30 print statements in `#if DEBUG`
- [x] Wrap `AuthView.swift` print statements (lines 303-318) in `#if DEBUG`
- [x] Wrap `CreateEventView.swift` print statements (lines 79, 232-291) in `#if DEBUG`
- [x] Wrap `UserManager.persistUserSession()` prints (lines 243-266) in `#if DEBUG`
- [x] Wrap `SettingsView.swift:164` print in `#if DEBUG`

### Hardcoded URL Constants
- [x] Replace placeholder App Store ID in `SettingsView.swift:192` (TODO left for real ID)
- [x] Move support/social URLs in `SettingsView.swift` (lines 691, 699, 846-870) to `AppConstants.swift`

### Accessibility
- [x] Add accessibility label to profile image picker in `ProfileSetupView.swift:164`
- [x] Add accessibility labels to `EventRowView` rows
- [x] Add accessibility label to map preview tap in `EventDetailView.swift:100`
- [x] Add accessibility support to `ImageCropper.swift`
- [x] Add `.accessibilityElement(children: .combine)` to `StatCard` in `ProfileView.swift`
- [x] Add accessibility labels to `NotificationRow` (title + message + read status)
- [x] Add accessibility hint to "Get Started" button in `WelcomeView.swift:87`

### File Organization
- [x] Move `NavigationBarModifier.swift` to `Components/Modifiers/`
- [x] Move `ImageCropper.swift` to `Components/` (rename to `ImageCropperView.swift`)
- [x] Delete or archive `User.swift.cursorrules`
- [x] Remove unused `auth` lazy property from `FriendDataProvider.swift:17` (if replacing with direct calls) or use it consistently

### MapCoordinator Isolation
- [x] Add `@MainActor` annotation to `MapCoordinator` in `UnifiedMapView.swift:104`

---

## P8 — Tests / Build / Planning Hygiene

### Test Coverage
- [x] Replace placeholder default tests in `TrailMatesTests.swift` with meaningful smoke coverage
- [x] Add unit tests for phone normalization and hash consistency across signup, login, search, and change-phone paths
- [ ] Add Firebase Emulator tests for callable privacy, Firestore rules, friend accept/remove, and event attendance atomic writes
- [ ] Replace manually mutated auth tests with tests that exercise `AuthViewModel` state transitions through its public async methods
- [ ] Add UI tests for the auth route, onboarding gate, friend search, event join/leave, and settings account deletion entry point

### Build Configuration
- [x] Change shared scheme `LaunchAction` back to `Debug` unless there is a documented reason to launch Release locally
- [x] Remove duplicate API-key injection from the shared scheme or project settings after choosing one source of truth
- [x] Wire `Config.xcconfig` intentionally or delete it if it is stale
- [x] Remove unsafe `-suppress-warnings` flags from `Package.swift` if the package is only documentation for Xcode-managed dependencies

### Repo Hygiene
- [x] Remove empty root `package-lock.json` if there is no root `package.json`
- [x] Consolidate duplicate `Package.resolved` files under the project/workspace
- [x] Remove duplicate Preview Content asset catalogs if only one is used by the target
- [x] Clean ignored `.DS_Store`, `.build/`, `functions/node_modules/`, and derived artifacts from local repo-adjacent folders

### Plan Lifecycle
- [x] Normalize archived plan frontmatter from `status: complete` to `status: completed`
- [x] Review archived plans with unchecked boxes and either complete the work, move leftovers to backlog, or correct the archive status

## Release Handoff
- 2026-05-25: Bumped TrailMates ATX to `1.0.4` / build `14`, exported `build/export-1.0.4-14/TrailMatesATX.ipa`, uploaded it to App Store Connect, and confirmed delivery status `VALID` for delivery UUID `54d10952-5f54-471d-86d9-ed353fee4016`.
- 2026-05-26: Associated ASC build `14` (`54d10952-5f54-471d-86d9-ed353fee4016`) with version `1.0.4`, added `en-US` What's New text, and submitted review submission `10a5a522-9778-4b90-a689-ffe91aa1bcc0`.
- App Store Connect confirmed the review submission state as `WAITING_FOR_REVIEW` at `2026-05-26T11:54:33.88Z`.
