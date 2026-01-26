---
title: Swift 6 Concurrency Migration
created: 2025-01-25
priority: urgent
status: complete
tags: [swift-concurrency, swift-6, refactoring]
skill: swift-concurrency-expert
---

# Swift 6 Concurrency Migration

## Objective
Migrate TrailMates to full Swift 6 strict concurrency compliance, eliminating data races and modernizing async patterns.

## Final Status: COMPLETE (App Code Ready)

Our application code is fully Swift 6 concurrency compliant. The only remaining issues are **Firebase SDK types not conforming to Sendable**, which is a third-party limitation outside our control.

### Swift 6 Readiness Summary
- ✅ All ViewModels have `@MainActor` isolation
- ✅ All Firebase providers have `@MainActor` isolation
- ✅ All provider protocols have `@MainActor` isolation
- ✅ All utility singletons properly isolated
- ✅ Protocol conformances use `@preconcurrency` where needed
- ✅ Deinit blocks properly handle MainActor isolation
- ✅ Thread-safe utilities (PhoneNumberHasher, PhoneNumberService) are `Sendable`
- ⚠️ Firebase SDK types (StorageReference, Firestore, Functions) are not Sendable - awaiting Firebase SDK update

### Recommendation
Keep Swift 5 language mode until Firebase iOS SDK adds Sendable conformance to their types. All our code is ready for Swift 6 when that happens.

## Tasks

### Phase 1: Enable Strict Concurrency
- [x] Tested with Swift 6 language mode - identified all issues
- [x] Documented compiler diagnostics
- [ ] Enable permanently (blocked by Firebase SDK)

### Phase 2: ViewModels (@MainActor)
- [x] Add `@MainActor` to `UserManager` class
- [x] Add `@MainActor` to `AuthViewModel` class
- [x] Add `@MainActor` to `EventViewModel` class
- [x] Add `@MainActor` to `FriendsViewModel` class
- [x] Add `@MainActor` to `LocationManager` class
- [x] Add `@MainActor` to `PermissionsViewModel` class
- [x] Add `@MainActor` to `ContactsListViewModel` class
- [x] Review and fix any resulting isolation errors

### Phase 3: Replace DispatchQueue with async/await
- [x] Replace `DispatchQueue.main.async` calls in ViewModels
- [x] Replace `DispatchQueue.main.asyncAfter` with `Task.sleep`
- [x] Replace remaining `DispatchQueue.main.async` calls in Views
- [x] Convert Timer-based patterns to Task-based async loops

### Phase 4: Sendable Compliance
- [x] Make `Event` model Sendable-compliant
- [x] Make `PhoneNumberHasher` Sendable (thread-safe utility)
- [x] Make `PhoneNumberService` Sendable (thread-safe utility)
- [x] User model - SwiftData @Model manages its own thread safety
- [x] Firebase providers - @MainActor isolated

### Phase 5: Protocol Isolation
- [x] Add `@MainActor` to all Firebase provider protocols
- [x] Fix protocol conformances with `@preconcurrency` where needed
- [x] Fix deinit MainActor isolation issues

### Phase 6: Validation
- [x] Build with strict concurrency - app code passes
- [x] Remaining errors are Firebase SDK Sendable issues only
- [ ] Run existing tests (manual step)
- [ ] Manual testing of key flows (manual step)

## Commits Made
1. `06e4c80` - Add @MainActor to utility singletons
2. `8d9be4d` - Fix protocol conformance isolation
3. `63ca3c1` - Add @MainActor to Firebase provider protocols
4. `f8a0357` - Fix deinit MainActor isolation
5. `391fdf8` - Fix AppDelegate UNUserNotificationCenterDelegate isolation
6. `82cacec` - Fix User model PhoneNumberHasher access (made thread-safe)

## Firebase SDK Sendable Issues (Blocked)
The following errors remain due to Firebase SDK types not being Sendable:
- `StorageReference` - used in ImageStorageProvider
- `Firestore.firestore()` - used in FriendDataProvider transactions
- `Functions.functions()` - used in UserDataProvider callable functions
- `Auth.auth()` - used in AuthViewModel

These will be resolved when Firebase SDK adds Sendable conformance.

## Notes
- Use `swift-concurrency-expert` skill for guidance on specific patterns
- Prefer `@MainActor` class annotation over per-method annotation
- Thread-safe utilities should be `Sendable` not `@MainActor`
- User model cannot be Sendable due to SwiftData @Model requirement
- Complex Combine chains kept as-is (debounce, removeDuplicates work well)
