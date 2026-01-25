---
title: UI Patterns Standardization
created: 2025-01-25
priority: backlog
status: in-progress
tags: [swiftui, ui, patterns, design-system]
skill: swiftui-ui-patterns
---

# UI Patterns Standardization

## Objective
Establish consistent UI patterns and create a reusable component library for TrailMates.

## Current State
- Good existing components: BottomSheet, TransparentBlurView, SearchBar, TagButton
- Some inconsistency in navigation patterns
- Sheet handling varies across views
- No formal design system documentation

## Tasks

### Phase 1: Audit Existing Components
- [x] Catalog all reusable components in `/Components`
- [x] Document each component's API and usage
- [x] Identify inconsistent patterns
- [x] Note components that need refinement

**Component Catalog (completed 2025-01-25):**
| Component | Location | Purpose | Has Preview |
|-----------|----------|---------|-------------|
| BottomSheet | Overlays/ | Draggable sheet with 3 positions | Yes |
| TransparentBlurView | Overlays/ | Glass-morphism blur effect | Yes |
| SegmentedControl | Common/ | Pill-style segment picker | Yes |
| PermissionStatus | Common/ | Permission state enum | N/A |
| LoadingView | Common/ | Standard loading indicator | Yes |
| ErrorView | Common/ | Error display with retry | Yes |
| EmptyStateView | Common/ | Empty state with action | Yes |
| IllustrationView | Common/ | Animated bird decoration | No |
| PermissionCard | Cards/ | Permission request card | Yes |
| EventRowView | Cards/ | Event list row | No |
| EventDetailView | Cards/ | Full event details | No |
| FriendsListCard | Cards/ | Friends list display | No |
| ProfileHeader | Cards/ | User profile header | No |
| CustomPin | Map/ | Draggable map pin | Yes |
| AnnotationViews | Map/ | MKAnnotationView subclasses | No |
| MapAnnotations | Map/ | MKPointAnnotation subclasses | No |
| MapView+AnnotationManagement | Map/ | Map extension helpers | No |

### Phase 2: Navigation Standardization
- [x] Document navigation patterns (NavigationStack, sheets, full-screen covers)
- [x] Standardize sheet presentation (prefer `.sheet(item:)`)
- [x] Create navigation helper types if needed
- [ ] Update views to follow standard patterns

**Navigation Patterns Documentation (completed 2025-01-25):**

#### Current Navigation Structure
- **Root**: `ContentView` uses conditional rendering (no NavigationStack at root)
- **Tab Navigation**: `HomeView` uses `TabView` with 4 tabs (Map, Events, Friends, Profile)
- **Custom Nav Bar**: `NavigationBarModifier` provides consistent header with `.withDefaultNavigation()`

#### Sheet Presentation Patterns Found
| View | Pattern Used | Recommendation |
|------|--------------|----------------|
| EventsView | `.sheet(item:)` for details, `.sheet(isPresented:)` for create | Good - already using item pattern |
| MapView | Both patterns | Good - appropriate usage |
| FriendsView | `.sheet(isPresented:)` | Consider item pattern |
| ProfileView | `.sheet(isPresented:)` x2 | Could consolidate |
| ProfileSetupView | `.sheet(isPresented:)` x2 | Fine for simple cases |

#### NavigationStack vs NavigationView Usage
- `NavigationStack` (preferred): PermissionsView, AddFriendsView, CreateEventView
- `NavigationView` (legacy): SettingsView, NotificationsView, LocationPickerView, EventDetailView

### Phase 3: Component Library
- [x] Create `Components/` folder structure:
  ```
  Components/
  ├── Buttons/
  ├── Cards/
  ├── Common/
  ├── Forms/
  ├── Lists/
  ├── Map/
  └── Overlays/
  ```
- [x] Move existing components to appropriate folders
- [x] Create missing common components:
  - [x] `LoadingView` - standard loading indicator
  - [x] `ErrorView` - standard error display
  - [x] `EmptyStateView` - standard empty state
  - [x] `PrimaryButton` - main action button style
  - [x] `SecondaryButton` - secondary action style

**New Components Created (2025-01-25):**
| Component | Location | Purpose | Has Preview |
|-----------|----------|---------|-------------|
| PrimaryButton | Buttons/ | Main action button with loading state | Yes |
| SecondaryButton | Buttons/ | Secondary/cancel button styles | Yes |
| FormSection | Forms/ | Groups related form fields | Yes |
| FormField | Forms/ | Text input with floating label | Yes |
| ValidationError | Forms/ | Error message display | Yes |
| ListRowView | Lists/ | Reusable list row with icons | Yes |

### Phase 4: Form Patterns
- [x] Create `FormSection` component
- [x] Create `FormField` component (text, phone, email variants)
- [x] Standardize validation display
- [ ] Create keyboard handling utilities

### Phase 5: List Patterns
- [x] Create `ListRowView` base component
- [x] Standardize swipe actions (via `listSwipeActions` modifier)
- [ ] Create section header style
- [ ] Add pull-to-refresh helper

### Phase 6: Theming
- [x] Create `AppColors` with semantic colors
- [x] Create `AppTypography` with text styles
- [x] Create `AppSpacing` with consistent spacing
- [ ] Document in design system guide

**Theme System Created (2025-01-25):**
Located in `/Theme/`:
- `AppColors.swift` - Semantic color definitions (brand, text, background, status)
- `AppTypography.swift` - Font scale with text style modifiers
- `AppSpacing.swift` - Spacing scale with layout helpers

### Phase 7: Accessibility
- [ ] Audit existing accessibility labels
- [ ] Add missing labels to interactive elements
- [ ] Test with VoiceOver
- [ ] Add Dynamic Type support check

## Component Template
```swift
/// Brief description of component
///
/// Usage:
/// ```swift
/// ExampleComponent(title: "Hello")
/// ```
struct ExampleComponent: View {
    // Public configuration
    let title: String
    var style: Style = .default

    enum Style {
        case `default`, prominent
    }

    var body: some View {
        // Implementation
    }
}

#Preview {
    ExampleComponent(title: "Preview")
}
```

## Audit Findings (2025-01-25)

### Inconsistencies Identified
1. **Documentation**: Many components lacked file header documentation explaining usage
2. **Previews**: UIKit-based components (AnnotationViews, MapAnnotations) don't have previews
3. **Color usage**: Some components use hardcoded colors instead of semantic color assets
4. **App name**: File headers still reference "TrailMatesATX" instead of "TrailMates"

### Components Needing Refinement
- `EventDetailView`: Very large (300+ lines), could be broken into smaller components
- `EventRowView`: Missing preview, complex nested structure
- `FriendsListCard`: Depends on external `FriendsSection` component
- `ProfileHeader`: Uses `AnyView` for action button, could use generics instead
- `IllustrationView`: Uses Timer which may cause memory issues if not cleaned up

### Positive Patterns Found
- `BottomSheet`: Good use of generics and @ViewBuilder
- `TransparentBlurView`: Clean UIViewRepresentable implementation
- `SegmentedControl`: Good animation handling
- `PermissionCard`: Clear status visualization

## New Component Locations Summary
```
TrailMates/
├── Components/
│   ├── Buttons/
│   │   ├── PrimaryButton.swift
│   │   └── SecondaryButton.swift
│   ├── Cards/
│   │   ├── EventDetailView.swift
│   │   ├── EventRowView.swift
│   │   ├── FriendsListCard.swift
│   │   ├── PermissionCard.swift
│   │   └── ProfileHeader.swift
│   ├── Common/
│   │   ├── EmptyStateView.swift
│   │   ├── ErrorView.swift
│   │   ├── IllustrationView.swift
│   │   ├── LoadingView.swift
│   │   ├── PermissionStatus.swift
│   │   └── SegmentedControl.swift
│   ├── Forms/
│   │   ├── FormField.swift
│   │   ├── FormSection.swift
│   │   └── ValidationError.swift
│   ├── Lists/
│   │   └── ListRowView.swift
│   ├── Map/
│   │   ├── AnnotationViews.swift
│   │   ├── CustomPin.swift
│   │   ├── MapAnnotations.swift
│   │   └── MapView+AnnotationManagement.swift
│   └── Overlays/
│       ├── BottomSheet.swift
│       └── TransparentBlurView.swift
└── Theme/
    ├── AppColors.swift
    ├── AppSpacing.swift
    └── AppTypography.swift
```

## Notes
- Use `swiftui-ui-patterns` skill for component guidance
- Each component should have a Preview
- Document usage in component file header
- Consider extracting to separate package eventually
- Xcode project uses PBXFileSystemSynchronizedRootGroup - folder changes auto-sync
