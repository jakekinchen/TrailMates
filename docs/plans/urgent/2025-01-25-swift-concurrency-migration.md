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
- [ ] Add `@MainActor` to `UserManager` class
- [ ] Add `@MainActor` to `AuthViewModel` class
- [ ] Add `@MainActor` to `EventViewModel` class
- [ ] Add `@MainActor` to `FriendsViewModel` class
- [ ] Add `@MainActor` to `LocationManager` class
- [ ] Add `@MainActor` to `PermissionsViewModel` class
- [ ] Add `@MainActor` to `ContactsViewModel` class
- [ ] Review and fix any resulting isolation errors

### Phase 3: Replace DispatchQueue with async/await
- [ ] Replace `DispatchQueue.main.async` calls in ViewModels
- [ ] Replace `DispatchQueue.main.asyncAfter` with `Task.sleep`
- [ ] Convert Timer-based patterns to AsyncSequence
  - [ ] MapView location update timer
  - [ ] Any debounce timers

### Phase 4: Sendable Compliance
- [ ] Make `User` model Sendable-compliant
- [ ] Make `Event` model Sendable-compliant
- [ ] Review `FirebaseDataProvider` for Sendable issues
- [ ] Mark appropriate closures with `@Sendable`

### Phase 5: Combine to async/await Migration
- [ ] Identify Combine publishers that can become async sequences
- [ ] Convert simple `.sink` patterns to `for await` loops
- [ ] Preserve complex Combine chains where appropriate
- [ ] Remove unnecessary cancellable management

### Phase 6: Validation
- [ ] Build with strict concurrency - zero warnings
- [ ] Run existing tests
- [ ] Manual testing of key flows (auth, location, events)

## Files to Modify
- `TrailMates/ViewModels/UserManager.swift` (920 lines)
- `TrailMates/ViewModels/AuthViewModel.swift`
- `TrailMates/ViewModels/EventViewModel.swift`
- `TrailMates/ViewModels/FriendsViewModel.swift`
- `TrailMates/ViewModels/LocationManager.swift`
- `TrailMates/ViewModels/PermissionsViewModel.swift`
- `TrailMates/ViewModels/ContactsViewModel.swift`
- `TrailMates/MapView.swift`
- `TrailMates/Utilities/FirebaseDataProvider.swift`

## Notes
- Use `swift-concurrency-expert` skill for guidance on specific patterns
- Prefer `@MainActor` class annotation over per-method annotation
- Avoid `@unchecked Sendable` - fix properly or document why needed
- Keep backward compatibility with iOS 18 deployment target
