---
title: Code Cleanup and Consolidation
created: 2025-01-25
priority: backlog
status: mostly-complete
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
- [x] Create single `PhoneNumberService` with clear API
- [x] Update all callsites to use consolidated service
- [x] Remove redundant implementations

**Audit Completed 2025-01-25:**
Phone utilities analysis:
1. **`PhoneNumberFormatter.swift`** - UI ViewModifier for real-time formatting (used in AuthView)
2. **`PhoneNumberUtility.swift`** - Authoritative implementation using PhoneNumberKit for E.164 formatting (used in ContactsListViewModel, PhoneNumberHasher)
3. **`PhoneNumberHasher.swift`** - Secure hashing using PhoneNumberUtility (used in User model)
4. **`UserManager.normalizePhoneNumber()`** - Simple regex stripping (duplicate, basic)
5. **`FirebaseDataProvider.normalizePhoneNumber()`** - Same basic normalization (duplicate)

**Completed 2025-01-25:**
- Created `PhoneNumberService.swift` with unified API:
  - `format(for: .display)` - human-readable format
  - `format(for: .storage)` - E.164 for database
  - `format(for: .digitsOnly)` - strips non-digits
  - `validate()` - validation check
  - `cleanseSingleNumber()` / `cleansePhoneNumbers()` - batch processing
- Updated `ContactsListViewModel` to use `PhoneNumberService`
- Updated `PhoneNumberHasher` to use `PhoneNumberService`
- Updated `UserManager.normalizePhoneNumber()` to delegate to `PhoneNumberService`
- Removed unused `normalizePhoneNumber()` from `FirebaseDataProvider`
- Marked `PhoneNumberUtility` as deprecated

### Phase 3: Clean Up Unused Code
- [x] Run dead code analysis
- [x] Remove unused imports
- [x] Remove commented-out code blocks
- [x] Remove unused model properties

**Completed 2025-01-25:**
- Removed empty `LandmarkProvider.swift`
- Removed unused `showUnlinkFacebookAlert` state from SettingsView
- Removed `viewState`, `friendsSection`, `FacebookFriendsList`, `FacebookFriendRow` from AddFriendsView
- Removed `isFacebookLinked` property and related code from UserManager
- Note: `facebookId` in User model kept for database compatibility (existing users may have this field)

### Phase 4: Standardize Error Handling
- [x] Create `AppError` enum for consistent errors
- [ ] Replace generic error logging with typed errors
- [x] Add user-facing error messages
- [ ] Implement retry logic where appropriate

**Completed 2025-01-25:**
- Created `AppError.swift` with unified error types:
  - Authentication errors: `notAuthenticated`, `authenticationFailed`
  - Network errors: `networkError`, `serverError`
  - Validation errors: `invalidInput`, `emptyField`, `missingRequiredFields`, `invalidData`
  - Resource errors: `notFound`, `unauthorized`
  - Image errors: `invalidImageUrl`, `imageDownloadFailed`, `imageProcessingFailed`
  - General: `unknown`
- Added `title` property for alert titles
- Added `isRetryable` property for retry logic
- Note: Existing `ValidationError` enums kept for backward compatibility; migrate gradually

### Phase 5: Documentation
- [x] Add file headers where missing
- [x] Document public APIs
- [x] Add inline comments for complex logic
- [x] Update CLAUDE.md/AGENTS.md with patterns

**Completed 2025-01-25:**
- Added file headers to new files: `PhoneNumberService.swift`, `AppError.swift`
- Added file header and deprecation notice to `PhoneNumberUtility.swift`
- Updated file header for `PhoneNumberHasher.swift`

**Completed 2025-01-26:**
- Documented all Firebase provider protocols in `FirebaseProviderProtocol.swift`:
  - `UserDataProviding`, `EventDataProviding`, `FriendDataProviding`
  - `ImageStorageProviding`, `LandmarkDataProviding`, `LocationDataProviding`
  - `NotificationDataProviding`
- Added comprehensive inline comments to `PhoneNumberHasher.swift`:
  - Explained the hashing algorithm (normalize -> pepper -> SHA-256)
  - Documented security considerations (rainbow tables, entropy)
- Updated `CLAUDE.md` and `AGENTS.md` with pattern sections:
  - Error handling patterns (using `AppError`)
  - Phone number handling (using `PhoneNumberService`)
  - Firebase provider patterns (using protocol-based providers)

### Phase 6: Dependency Audit
- [x] Review Package.swift dependencies
- [x] Remove unused packages
- [x] Check for outdated packages (documented, not updated)
- [x] Document why each dependency exists

**Completed 2025-01-25:**
- Removed Facebook SDK from Package.swift dependencies

**Completed 2025-01-26:**
- Documented all dependencies in Package.swift with detailed comments
- Identified outdated packages:
  - Firebase iOS SDK: v11.5.0 installed, v12.8.0 available (requires Xcode 16.2+/Swift 6.0)
  - PhoneNumberKit: v3.8.0 installed, v4.0.0 available
- Documented Firebase products used: Core, Auth, Firestore, Database, Storage, Functions, Analytics
- Documented PhoneNumberKit usage: phone parsing, E.164 formatting, validation
- Listed all transitive dependencies for reference

## Files to Review
- ~~`TrailMates/Utilities/FacebookService.swift`~~ - DELETED
- `TrailMates/Utilities/PhoneNumberFormatter.swift` - Keep (UI formatting)
- `TrailMates/Utilities/PhoneNumberUtility.swift` - DEPRECATED (use PhoneNumberService)
- `TrailMates/Utilities/PhoneNumberService.swift` - NEW (unified phone utility)
- `TrailMates/Models/AppError.swift` - NEW (unified error handling)
- ~~Any file with large commented sections~~ - Cleaned

## Notes
- Create feature branch for cleanup work
- Test thoroughly after removing code
- Keep commits atomic and well-described
- Phone utility consolidation completed
