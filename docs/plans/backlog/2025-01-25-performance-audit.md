---
title: SwiftUI Performance Audit
created: 2025-01-25
priority: backlog
status: in-progress
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
- [ ] Review background location necessity

### Phase 3: Image Performance
- [x] Implement proper image cache with size limits
- [x] Add memory warning handling (clear caches)
- [x] Use thumbnail URLs for list views (already implemented)
- [x] Lazy load full images only when needed (already implemented)

### Phase 4: State Management
- [x] Narrow UserManager `@Published` scope (reviewed - already well-scoped)
- [ ] Split large observable into focused observables
- [x] Review removeDuplicates efficiency
- [x] Add `.equatable()` where beneficial

### Phase 5: Instruments Profiling
- [ ] Run SwiftUI template in Instruments
- [ ] Capture Time Profiler data
- [ ] Identify actual hot paths
- [ ] Document before/after metrics

### Phase 6: Memory Audit
- [x] Add memory pressure observer
- [x] Implement cache eviction policies
- [ ] Profile memory growth during use
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
