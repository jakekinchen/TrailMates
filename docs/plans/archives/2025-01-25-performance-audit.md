---
title: SwiftUI Performance Audit
created: 2025-01-25
priority: backlog
status: complete
tags: [performance, swiftui, optimization]
skill: swiftui-performance-audit
---

# SwiftUI Performance Audit

## Objective
Identify and fix performance bottlenecks in TrailMates, focusing on rendering, memory, and battery efficiency.

## Known Issues (from codebase analysis)

### Timer/Location Updates
- MapView uses 30-second Timer for location updates (potential leak)
- LocationManager allows continuous background updates without throttling
- Battery drain risk from aggressive location sharing

### Image Handling
- No visible caching strategy beyond prefetch
- Multiple image downloads on profile views
- No memory warning handling for image caches

### View Invalidation
- UserManager has ~10 `@Published` properties (not 48 as initially noted)
- Complex `removeDuplicates` logic with 18 conditions
- Potential invalidation storms from broad state changes

### Firebase Listeners
- Listeners stored in dictionaries but cleanup may be incomplete
- Need to verify all paths call `removeAllListeners()` properly

## Tasks

### Phase 1: Code Review Audit
- [x] Profile MapView for timer leaks
- [x] Review image loading in FriendsViewModel
- [x] Check UserManager publisher chain efficiency
- [x] Audit Firebase listener lifecycle
- [x] Review `body` computations for heavy work

### Phase 2: Location Optimization
- [x] Replace Timer with AsyncSequence for location updates
- [x] Implement location update batching/throttling
- [x] Add distance-based update filtering
- [x] Review background location necessity (documented below)

### Phase 3: Image Performance
- [x] Implement proper image cache with size limits
- [x] Add memory warning handling (clear caches)
- [x] Use thumbnail URLs for list views (already implemented)
- [x] Lazy load full images only when needed (already implemented)

### Phase 4: State Management
- [x] Narrow UserManager `@Published` scope (reviewed - already well-scoped)
- [x] Split large observable into focused observables (reviewed - not beneficial, see analysis below)
- [x] Review removeDuplicates efficiency
- [x] Add `.equatable()` where beneficial

### Phase 5: Instruments Profiling
- [x] Document recommendations for Instruments profiling (see profiling guide below)
- [ ] Run SwiftUI template in Instruments (requires Xcode GUI)
- [ ] Capture Time Profiler data (requires Xcode GUI)
- [ ] Identify actual hot paths (requires Xcode GUI)
- [ ] Document before/after metrics (requires Xcode GUI)

### Phase 6: Memory Audit
- [x] Add memory pressure observer
- [x] Implement cache eviction policies
- [ ] Profile memory growth during use (requires Instruments Allocations tool)
- [x] Fix any retain cycles (audited - already using [weak self] appropriately)

## Files to Focus On
- `TrailMates/MapView.swift` - Timer management
- `TrailMates/ViewModels/UserManager.swift` - State invalidation
- `TrailMates/ViewModels/FriendsViewModel.swift` - Image prefetch
- `TrailMates/Utilities/FirebaseDataProvider.swift` - Listener cleanup
- `TrailMates/ViewModels/LocationManager.swift` - Update frequency

## Completed Changes (2025-01-25)

### 1. MapView Timer Fix
- **File**: `/Users/jakekinchen/Documents/TrailMates/TrailMates/MapView.swift`
- **Issue**: Timer.scheduledTimer could cause memory leaks and wasn't properly cancellable
- **Fix**: Replaced with Task-based async loop using `Task.sleep(for:)` that properly handles cancellation
- **Benefit**: No more timer leaks, proper cleanup on view disappear, weak reference to userManager

### 2. Firebase Listener Cleanup
- **File**: `/Users/jakekinchen/Documents/TrailMates/TrailMates/Utilities/FirebaseDataProvider.swift`
- **Issue**: `removeAllListeners()` didn't include `userListeners` dictionary
- **Fix**: Added cleanup for `userListeners` in `removeAllListeners()` method
- **Benefit**: All Firebase listeners now properly cleaned up, added listener tracking for debugging

### 3. Image Cache Improvements
- **File**: `/Users/jakekinchen/Documents/TrailMates/TrailMates/Utilities/FirebaseDataProvider.swift`
- **Issue**: NSCache had no limits configured, no memory warning handling
- **Fix**:
  - Added `countLimit: 50` (max 50 images)
  - Added `totalCostLimit: 50MB`
  - Added memory warning observer to clear cache under pressure
  - Added cost tracking when caching images
- **Benefit**: Prevents unbounded memory growth, responds to system memory pressure

### 4. UserManager State Optimization
- **Files**:
  - `/Users/jakekinchen/Documents/TrailMates/TrailMates/ViewModels/UserManager.swift`
  - `/Users/jakekinchen/Documents/TrailMates/TrailMates/Models/User.swift`
- **Issue**: Complex 18-condition inline comparison in `removeDuplicates` closure
- **Fix**:
  - Added `hasOnlyLocationChanged(comparedTo:)` method to User model
  - Simplified UserManager's observer to use the new method
  - Removed unused `areCoordinatesEqual` helper
- **Benefit**: Cleaner code, centralized comparison logic, easier to maintain

## Completed Changes (2025-01-25 - Phase 2)

### 5. Location Update Throttling
- **File**: `/Users/jakekinchen/Documents/TrailMates/TrailMates/ViewModels/LocationManager.swift`
- **Issue**: Location updates were sent to Firebase on every GPS update, causing excessive network calls and battery drain
- **Fix**:
  - Added `minimumDistanceThreshold` (10 meters) - won't send update if user moved less than this
  - Added `minimumUpdateInterval` (5 seconds) - won't send updates faster than this interval
  - Added `shouldSendLocationUpdate()` method that checks both thresholds before sending to Firebase
  - Local `@Published var location` still updates immediately for UI responsiveness
- **Benefit**: Significantly reduced Firebase writes and battery consumption from GPS tracking

### 6. View Performance with Equatable
- **Files**:
  - `/Users/jakekinchen/Documents/TrailMates/TrailMates/ProfileView.swift`
- **Issue**: StatCard and StatsSection views were re-rendering even when their data hadn't changed
- **Fix**:
  - Made `UserStats` conform to `Equatable`
  - Made `StatCard` and `StatsSection` conform to `Equatable` with proper `==` implementations
  - Added `.equatable()` modifier to `StatsSection` in ProfileView
- **Benefit**: Prevents unnecessary view re-renders when parent state changes but stats data is unchanged

### 7. Body Computation Review
- **Files Reviewed**:
  - `/Users/jakekinchen/Documents/TrailMates/TrailMates/MapView.swift`
  - `/Users/jakekinchen/Documents/TrailMates/TrailMates/EventsView.swift`
- **Finding**: Event filtering (`getUserEvents`, `getFilteredEvents`) and grouping (`getEventGroups`, `groupEvents`) happen during body evaluation. However, these operations are:
  - Lightweight array filtering operations (O(n) with small n)
  - Only evaluated when the events tab is active
  - Already using efficient algorithms
- **Conclusion**: No changes needed - current implementation is performant for expected data sizes

### 8. Retain Cycle Audit
- **Files Audited**:
  - `/Users/jakekinchen/Documents/TrailMates/TrailMates/ViewModels/UserManager.swift`
  - `/Users/jakekinchen/Documents/TrailMates/TrailMates/MapView.swift`
  - `/Users/jakekinchen/Documents/TrailMates/TrailMates/Utilities/FirebaseDataProvider.swift`
- **Finding**: All closures properly use `[weak self]` or `[weak userManager]` where needed
- **Conclusion**: No retain cycle issues found

## Notes
- Use `swiftui-performance-audit` skill for detailed guidance
- Profile in Release builds for accurate metrics
- Focus on user-perceptible issues first
- Document baseline metrics before changes

## Completed Analysis (2025-01-25 - Phase 2, 4, 5)

### 9. Background Location Necessity Review

**File**: `/Users/jakekinchen/Documents/TrailMates/TrailMates/ViewModels/LocationManager.swift`

**Current Configuration**:
- `allowsBackgroundLocationUpdates = true`
- `pausesLocationUpdatesAutomatically = false`
- `desiredAccuracy = kCLLocationAccuracyBest`

**Info.plist Configuration**:
- `NSLocationAlwaysAndWhenInUseUsageDescription`: "TrailMates uses your location in the background to share your live position with friends while you're on the trail."
- `NSLocationWhenInUseUsageDescription`: "TrailMates uses your location to show nearby friends and trail events."
- `UIBackgroundModes`: includes `location`

**Findings**:
1. **Background location IS necessary** for this app's core functionality:
   - TrailMates is a social trail app where users share their live location with friends
   - Users need to see friends' positions on the map even when the app is backgrounded
   - The feature is clearly communicated in the usage description

2. **Current implementation is already optimized**:
   - Location updates are throttled (10m distance, 5s minimum interval) before sending to Firebase
   - Local `@Published var location` updates immediately for UI responsiveness
   - Firebase writes are minimized through `shouldSendLocationUpdate()` logic

3. **Recommendations for further battery optimization** (if needed in future):
   - Consider using `kCLLocationAccuracyHundredMeters` when app is backgrounded
   - Implement `pausesLocationUpdatesAutomatically = true` for better system optimization
   - Add user preference to disable background location sharing
   - Consider significant location changes API (`startMonitoringSignificantLocationChanges()`) for less frequent updates

**Conclusion**: Background location is justified for the app's social trail-sharing feature. The existing throttling (10m/5s) already mitigates battery concerns.

### 10. Observable Splitting Analysis

**File**: `/Users/jakekinchen/Documents/TrailMates/TrailMates/ViewModels/UserManager.swift`

**Current `@Published` Properties** (7 total):
1. `currentUser: User?` - Core user data
2. `isLoggedIn: Bool` - Authentication state
3. `isOnboardingComplete: Bool` - Onboarding flow
4. `isWelcomeComplete: Bool` - Welcome flow
5. `isPermissionsGranted: Bool` - Permissions flow
6. `hasAddedFriends: Bool` - Friends flow
7. `isRefreshing: Bool` - Refresh state

**Analysis**:
1. **Splitting is NOT recommended** for several reasons:
   - Only 7 `@Published` properties (not excessive)
   - Properties are logically cohesive (user state + onboarding flow)
   - Properties are already grouped by purpose (auth, onboarding, friends)
   - `removeDuplicates` with `hasOnlyLocationChanged()` already filters unnecessary updates
   - Views that observe `UserManager` typically need multiple related properties

2. **Why splitting would add complexity without benefit**:
   - Would require additional dependency injection
   - Would add coordinator patterns for state synchronization
   - Small number of properties doesn't justify overhead
   - SwiftUI's automatic diffing handles this efficiently

3. **If splitting becomes necessary in future**, consider:
   - `AuthenticationManager` - `isLoggedIn`, `currentUser`
   - `OnboardingManager` - `isWelcomeComplete`, `isPermissionsGranted`, `isOnboardingComplete`
   - Keep `UserManager` as coordinator injecting both

**Conclusion**: Current UserManager structure is appropriately scoped. The 7 published properties are manageable and logically related.

---

## Instruments Profiling Guide

Since Instruments requires the Xcode GUI and cannot be run from CLI, here are the recommended profiling steps when you have access to Xcode:

### Priority 1: SwiftUI View Profiling

**Template**: SwiftUI (or Core Animation)
**Focus Areas**:
- `MapView.swift` - Check for excessive redraws during location updates
- `ProfileView.swift` - Verify `StatsSection` equatable optimization
- `EventsView.swift` - Check event filtering performance
- `FriendsView.swift` - Image loading and list performance

**What to Look For**:
- View body computations taking > 16ms (causes frame drops)
- Unnecessary view invalidations
- Off-main-thread UI updates (should see no warnings with `@MainActor`)

### Priority 2: Time Profiler

**Template**: Time Profiler
**Focus Areas**:
- Firebase listener callbacks in `FirebaseDataProvider.swift`
- `removeDuplicates` closure in `UserManager.setupObservers()`
- Location update processing in `LocationManager.didUpdateLocations`
- Image encoding/decoding in `ImageStorageProvider`

**Recording Steps**:
1. Build for Release configuration (not Debug)
2. Profile on physical device (not simulator)
3. Run typical user flows: login, view map, browse friends, view profile
4. Look for functions consuming > 1% of total time

### Priority 3: Allocations

**Template**: Allocations
**Focus Areas**:
- Image cache growth (`FirebaseDataProvider.imageCache`)
- Firebase listener accumulation
- Combine publisher subscriptions (`cancellables`)

**What to Look For**:
- Memory growth during navigation (memory leaks)
- Large allocations from image processing
- Retained objects that should be released

### Priority 4: Energy Log

**Template**: Energy Log
**Focus Areas**:
- GPS usage frequency and accuracy
- Network requests from Firebase operations
- Background activity when app is suspended

**Baseline Metrics to Capture**:
- CPU usage during idle (should be < 1%)
- CPU usage during active map viewing
- Memory footprint at startup vs after 10 minutes of use
- Network bytes sent/received per minute during active use
- GPS energy impact rating

### Suggested Test Scenarios

1. **Cold Start**: Launch app from terminated state, measure time to interactive
2. **Map Browsing**: Pan/zoom map for 2 minutes, check for frame drops
3. **Friends List Scroll**: Scroll friends list with 50+ friends, check image loading
4. **Background Location**: Run app in background for 10 minutes, check energy log
5. **Event Creation**: Create event with image, profile memory allocation
6. **Extended Use**: Use app actively for 30 minutes, check for memory growth

### Expected Results After Optimizations

- Map view: No timer leaks, smooth 60fps scrolling
- Image loading: < 50MB cache, graceful memory pressure handling
- Location updates: < 12 Firebase writes per minute during movement
- View invalidations: Minimal redraws when only location changes
