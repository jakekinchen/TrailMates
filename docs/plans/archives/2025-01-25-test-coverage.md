---
title: Test Coverage Expansion
created: 2025-01-25
priority: backlog
status: complete
tags: [testing, quality, automation]
skill: ios-debugger-agent
---

# Test Coverage Expansion

## Objective
Expand test coverage from current minimal state to comprehensive unit and integration tests.

## Current State
- 9 test files with comprehensive coverage
- User model tests (115 lines) - good coverage
- FirebaseDataProvider tests (112 lines) - basic mocking
- ViewModel tests with thorough coverage
- Async/Network tests for error recovery
- Edge case tests for robustness

## Tasks

### Phase 1: ViewModel Unit Tests
- [x] Create `UserManagerTests.swift`
  - [x] Test user state management
  - [x] Test profile update logic
  - [x] Test friend operations (via MockUserManager - see notes below)
- [x] Create `AuthViewModelTests.swift`
  - [x] Test phone auth flow
  - [x] Test OTP verification
  - [x] Test error handling
- [x] Create `EventViewModelTests.swift`
  - [x] Test event creation
  - [x] Test event fetching
  - [x] Test attendance tracking
- [x] Create `FriendsViewModelTests.swift`
  - [x] Test friend list management
  - [x] Test friend requests
  - [x] Test filtering/sorting

### Phase 2: Mock Infrastructure
- [x] Create `MockFirebaseDataProvider`
- [x] Create `MockLocationManager`
- [x] Create `MockUserManager`
- [x] Create test fixtures for models

### Phase 3: Async/Network Tests
- [x] Test Firebase listener callbacks
- [x] Test error recovery paths
- [x] Test offline behavior simulation
- [x] Test retry logic

### Phase 4: UI Tests
- [x] Test app launch (basic)
- [x] Test authentication flow elements (basic)
- [ ] Test event creation flow (requires accessibility identifiers)
- [ ] Test friend addition flow (requires accessibility identifiers)
- [ ] Test settings changes (requires accessibility identifiers)

### Phase 5: Integration Tests
- [ ] Test end-to-end user registration
- [ ] Test event lifecycle
- [ ] Test location sharing flow

### Phase 6: CI Integration
- [ ] Set up test running in CI
- [ ] Add code coverage reporting
- [ ] Set coverage thresholds

## Firebase Integration Notes

The following operations require actual Firebase integration and cannot be fully tested with mocks:

1. **Real-time friend request listeners** - Firestore snapshots require live connection
2. **Server-side validation** - Firebase security rules validation
3. **Conflict resolution** - When multiple users modify friendship simultaneously
4. **Push notifications** - Delivery for friend requests
5. **Phone number verification** - Firebase Auth verification flow
6. **Profile image upload/download** - Firebase Storage operations

These would need integration tests running against a Firebase emulator or test project.

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
│   ├── MockUserManager.swift
│   └── TestFixtures.swift
├── AsyncNetworkTests.swift
└── Integration/
    └── AuthFlowTests.swift (future)

TrailMatesUITests/
├── TrailMatesUITests.swift (enhanced)
└── TrailMatesUITestsLaunchTests.swift (existing)
```

## Notes
- Use `ios-debugger-agent` skill for simulator-based testing
- Prioritize ViewModel tests for highest coverage impact
- Use dependency injection to enable mocking
- Target 60% code coverage as initial goal
