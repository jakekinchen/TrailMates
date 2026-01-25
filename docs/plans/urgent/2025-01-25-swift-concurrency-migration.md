---
title: Swift 6 Concurrency Migration
created: 2025-01-25
priority: urgent
status: in-progress
tags: [swift-concurrency, swift-6, refactoring]
skill: swift-concurrency-expert
---

# Swift 6 Concurrency Migration

## Objective
Migrate TrailMates to full Swift 6 strict concurrency compliance, eliminating data races and modernizing async patterns.

## Current State
- Only 19 instances of `@MainActor`, `isolated`, `nonisolated`, `sending`
- 18 instances of `DispatchQueue.main.async` that should use async/await
- Heavy use of Combine with 1,843 `[weak self]` captures
- Timer-based patterns that should use AsyncSequence
- Mixed Combine/async-await approaches causing maintenance issues

## Tasks

### Phase 1: Enable Strict Concurrency
- [ ] Update project settings to Swift 6 language mode
- [ ] Enable strict concurrency checking
- [ ] Document initial compiler diagnostics count

### Phase 2: ViewModels (@MainActor)
- [x] Add `@MainActor` to `UserManager` class (already present)
- [x] Add `@MainActor` to `AuthViewModel` class (already present)
- [x] Add `@MainActor` to `EventViewModel` class (already present)
- [x] Add `@MainActor` to `FriendsViewModel` class (already present)
- [x] Add `@MainActor` to `LocationManager` class
- [x] Add `@MainActor` to `PermissionsViewModel` class (already present)
- [x] Add `@MainActor` to `ContactsListViewModel` class (note: file is ContactsListViewModel.swift)
- [x] Review and fix any resulting isolation errors

### Phase 3: Replace DispatchQueue with async/await
- [x] Replace `DispatchQueue.main.async` calls in ViewModels (ContactsListViewModel converted to async/await)
- [x] Replace `DispatchQueue.main.asyncAfter` with `Task.sleep`
  - [x] LocationPickerView.swift - converted dismiss delay
  - [x] IllustrationView.swift - converted animation delay
  - [x] UnifiedMapView.swift - converted annotation deselect delay
- [x] Replace remaining `DispatchQueue.main.async` calls in Views
  - [x] PermissionsView.swift - converted notification settings check and alert buttons
  - [x] AddFriendsView.swift - converted contacts request
  - [x] TrailMatesApp.swift - converted notification authorization
  - [x] SettingsView.swift - removed unnecessary dispatches (already on main)
  - [x] ContactsListView.swift - removed unnecessary dispatch
  - [x] MapView.swift - removed unnecessary dispatch (already in async context)
  - [x] CreateEventView.swift - removed unnecessary dispatches
  - [x] EventDetailView.swift - converted calendar/maps actions
  - [x] UnifiedMapView.swift - converted region change handlers
  - [x] WelcomeMapCoordinator.swift - added @MainActor
- [x] Convert Timer-based patterns to Task-based async loops
  - [x] MapView location update timer (already using Task.sleep pattern)
  - [x] IllustrationView.swift - converted Timer.scheduledTimer to async loop

### Phase 4: Sendable Compliance
- [x] Make `Event` model Sendable-compliant (struct with Sendable properties)
- [ ] Review `User` model - Note: Cannot be Sendable as it uses @Model (SwiftData) which manages its own thread safety
- [ ] Review `FirebaseDataProvider` for Sendable issues
- [ ] Mark appropriate closures with `@Sendable`

### Phase 5: Combine to async/await Migration
- [x] Identify Combine publishers that can become async sequences
  - UserManager has 2 .sink patterns for debounced auto-save and state observation
  - These are complex publisher chains better left as Combine
- [x] Preserve complex Combine chains where appropriate
  - Debounced publishers with removeDuplicates and CombineLatest are ideal for Combine
- [ ] Convert simple `.sink` patterns to `for await` loops (none identified as simple enough)
- [ ] Remove unnecessary cancellable management

### Phase 6: Validation
- [ ] Build with strict concurrency - zero warnings
- [ ] Run existing tests
- [ ] Manual testing of key flows (auth, location, events)

## Files Modified
- `TrailMates/PermissionsView.swift` - Converted DispatchQueue patterns to async/await
- `TrailMates/AddFriendsView.swift` - Converted contacts access to async/await
- `TrailMates/App/TrailMatesApp.swift` - Converted notification request to async/await
- `TrailMates/SettingsView.swift` - Removed unnecessary DispatchQueue wrappers
- `TrailMates/ContactsListView.swift` - Removed unnecessary DispatchQueue wrapper
- `TrailMates/LocationPickerView.swift` - Converted asyncAfter to Task.sleep
- `TrailMates/MapView.swift` - Removed unnecessary DispatchQueue wrapper
- `TrailMates/CreateEventView.swift` - Removed unnecessary DispatchQueue wrappers
- `TrailMates/Components/Cards/EventDetailView.swift` - Converted calendar/maps to async patterns
- `TrailMates/Utilities/UnifiedMapView.swift` - Converted DispatchQueue to Task patterns
- `TrailMates/Components/Common/IllustrationView.swift` - Converted Timer to async loop
- `TrailMates/Utilities/WelcomeMapCoordinator.swift` - Added @MainActor
- `TrailMates/Models/Event.swift` - Added Sendable conformance

## Notes
- Use `swift-concurrency-expert` skill for guidance on specific patterns
- Prefer `@MainActor` class annotation over per-method annotation
- Avoid `@unchecked Sendable` - fix properly or document why needed
- Keep backward compatibility with iOS 18 deployment target
- User model cannot be Sendable due to SwiftData @Model requirement
- Complex Combine chains (debounce, removeDuplicates, CombineLatest) kept as-is
