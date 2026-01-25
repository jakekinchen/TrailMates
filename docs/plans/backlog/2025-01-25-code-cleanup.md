---
title: Code Cleanup and Consolidation
created: 2025-01-25
priority: backlog
status: in-progress
tags: [cleanup, technical-debt, refactoring]
---

# Code Cleanup and Consolidation

## Objective
Remove dead code, consolidate duplicate utilities, and clean up technical debt.

## Tasks

### Phase 1: Remove Facebook Integration
- [x] Delete `FacebookService.swift` if unused
- [x] Remove commented Facebook code from views
- [x] Remove Facebook SDK dependencies if present
- [x] Clean up any Facebook-related configuration

**Completed 2025-01-25:**
- Deleted `TrailMates/Utilities/FacebookService.swift`
- Removed Facebook code from `UserManager.swift`, `AddFriendsView.swift`, `SettingsView.swift`
- Removed `fetchUsersByFacebookIds` from `FirebaseDataProvider.swift` and `UserDataProvider.swift`
- Removed Facebook SDK from `Package.swift` and `Podfile`
- Cleaned up `Config.xcconfig` and `suppress_warnings.sh`
- Updated Help Center FAQ to remove Facebook reference
- Note: Kept `facebookId` field in `User.swift` for database compatibility

### Phase 2: Consolidate Phone Utilities
- [x] Audit all phone number utilities:
  - `PhoneNumberFormatter`
  - `PhoneNumberUtility`
  - `normalizePhoneNumber` functions
- [ ] Create single `PhoneNumberService` with clear API
- [ ] Update all callsites to use consolidated service
- [ ] Remove redundant implementations

**Audit Completed 2025-01-25:**
Phone utilities analysis:
1. **`PhoneNumberFormatter.swift`** - UI ViewModifier for real-time formatting (used in AuthView)
2. **`PhoneNumberUtility.swift`** - Authoritative implementation using PhoneNumberKit for E.164 formatting (used in ContactsListViewModel, PhoneNumberHasher)
3. **`PhoneNumberHasher.swift`** - Secure hashing using PhoneNumberUtility (used in User model)
4. **`UserManager.normalizePhoneNumber()`** - Simple regex stripping (duplicate, basic)
5. **`FirebaseDataProvider.normalizePhoneNumber()`** - Same basic normalization (duplicate)

**Recommendation:** Consolidate into a single `PhoneNumberService` that wraps PhoneNumberUtility and provides:
- `format(for: .display)` - human-readable format
- `format(for: .storage)` - E.164 for database
- `validate()` - validation check
This is a complex refactoring - defer to separate PR.

### Phase 3: Clean Up Unused Code
- [x] Run dead code analysis
- [x] Remove unused imports
- [x] Remove commented-out code blocks
- [ ] Remove unused model properties

**Completed 2025-01-25:**
- Removed empty `LandmarkProvider.swift`
- Removed unused `showUnlinkFacebookAlert` state from SettingsView
- Removed `viewState`, `friendsSection`, `FacebookFriendsList`, `FacebookFriendRow` from AddFriendsView
- Removed `isFacebookLinked` property and related code from UserManager

### Phase 4: Standardize Error Handling
- [ ] Create `AppError` enum for consistent errors
- [ ] Replace generic error logging with typed errors
- [ ] Add user-facing error messages
- [ ] Implement retry logic where appropriate

### Phase 5: Documentation
- [ ] Add file headers where missing
- [ ] Document public APIs
- [ ] Add inline comments for complex logic
- [ ] Update CLAUDE.md/AGENTS.md with patterns

### Phase 6: Dependency Audit
- [x] Review Package.swift dependencies
- [x] Remove unused packages
- [ ] Update outdated packages
- [ ] Document why each dependency exists

**Completed 2025-01-25:**
- Removed Facebook SDK from Package.swift dependencies

## Files to Review
- ~~`TrailMates/Utilities/FacebookService.swift`~~ - DELETED
- `TrailMates/Utilities/PhoneNumberFormatter.swift` - Keep (UI formatting)
- `TrailMates/Utilities/PhoneNumberUtility.swift` - Keep (authoritative)
- ~~Any file with large commented sections~~ - Cleaned

## Notes
- Create feature branch for cleanup work
- Test thoroughly after removing code
- Keep commits atomic and well-described
- Phone utility consolidation deferred to separate PR due to complexity
