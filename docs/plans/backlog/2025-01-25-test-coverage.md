---
title: Test Coverage Expansion
created: 2025-01-25
priority: backlog
status: pending
tags: [testing, quality, automation]
skill: ios-debugger-agent
---

# Test Coverage Expansion

## Objective
Expand test coverage from current minimal state to comprehensive unit and integration tests.

## Current State
- 4 test files exist
- User model tests (115 lines) - good coverage
- FirebaseDataProvider tests (112 lines) - basic mocking
- No ViewModel tests
- No UI integration tests
- No async operation tests

## Tasks

### Phase 1: ViewModel Unit Tests
- [ ] Create `UserManagerTests.swift`
  - [ ] Test user state management
  - [ ] Test profile update logic
  - [ ] Test friend operations
- [ ] Create `AuthViewModelTests.swift`
  - [ ] Test phone auth flow
  - [ ] Test OTP verification
  - [ ] Test error handling
- [ ] Create `EventViewModelTests.swift`
  - [ ] Test event creation
  - [ ] Test event fetching
  - [ ] Test attendance tracking
- [ ] Create `FriendsViewModelTests.swift`
  - [ ] Test friend list management
  - [ ] Test friend requests
  - [ ] Test contact sync

### Phase 2: Mock Infrastructure
- [ ] Create `MockFirebaseDataProvider`
- [ ] Create `MockLocationManager`
- [ ] Create `MockUserManager`
- [ ] Create test fixtures for models

### Phase 3: Async/Network Tests
- [ ] Test Firebase listener callbacks
- [ ] Test error recovery paths
- [ ] Test offline behavior
- [ ] Test retry logic

### Phase 4: UI Tests
- [ ] Test authentication flow
- [ ] Test event creation flow
- [ ] Test friend addition flow
- [ ] Test settings changes

### Phase 5: Integration Tests
- [ ] Test end-to-end user registration
- [ ] Test event lifecycle
- [ ] Test location sharing flow

### Phase 6: CI Integration
- [ ] Set up test running in CI
- [ ] Add code coverage reporting
- [ ] Set coverage thresholds

## Test Structure
```
TrailMatesTests/
├── Models/
│   └── UserModelTests.swift (existing)
├── ViewModels/
│   ├── UserManagerTests.swift
│   ├── AuthViewModelTests.swift
│   ├── EventViewModelTests.swift
│   └── FriendsViewModelTests.swift
├── Utilities/
│   └── FirebaseDataProviderTests.swift (existing)
├── Mocks/
│   ├── MockFirebaseDataProvider.swift
│   ├── MockLocationManager.swift
│   └── TestFixtures.swift
└── Integration/
    └── AuthFlowTests.swift
```

## Notes
- Use `ios-debugger-agent` skill for simulator-based testing
- Prioritize ViewModel tests for highest coverage impact
- Use dependency injection to enable mocking
- Target 60% code coverage as initial goal
