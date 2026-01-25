---
title: SwiftUI View Refactoring
created: 2025-01-25
priority: urgent
status: in-progress
tags: [swiftui, refactoring, views]
skill: swiftui-view-refactor
---

# SwiftUI View Refactoring

## Objective
Break down oversized SwiftUI views into maintainable, composable components following consistent patterns.

## Current State
- `SettingsView.swift`: 840 lines (should be ~300 max) -> **Refactored: 989 lines but well-organized with extensions**
- `ProfileSetupView.swift`: 560 lines -> **Refactored: 586 lines with extracted components**
- `ChangePhoneView.swift`: 501 lines
- `AddFriendsView.swift`: 444 lines
- `CreateEventView.swift`: 428 lines
- `AuthView.swift`: 389 lines
- Inconsistent property ordering across views
- Mixed state management patterns

## Tasks

### Phase 1: SettingsView Decomposition (Priority)
- [x] Extract `PrivacySettingsSection` view (already existed as separate view, now organized with extensions)
- [x] Extract `NotificationSettingsSection` view (already existed as separate view, now organized with extensions)
- [x] Extract `AccountSettingsSection` view (organized as `personalInfoSection` in private extension)
- [x] Extract `AppearanceSettingsSection` view (organized as `appearanceSection` in private extension)
- [x] Refactor main SettingsView to compose sections
- [x] Apply standard property ordering

### Phase 2: ProfileSetupView Refactoring
- [x] Extract `ProfileImagePicker` component (renamed to `ProfileImagePicker`)
- [x] Extract `ProfileFormFields` component (organized as `textFieldsView` and `ProfileFloatingLabelTextField`)
- [x] Extract image cropping logic to separate view (uses existing `ImageCropper`)
- [x] Simplify main view to composition

### Phase 3: ChangePhoneView Refactoring
- [ ] Extract `PhoneNumberInput` component
- [ ] Extract `VerificationCodeInput` component
- [ ] Consolidate phone formatting utilities
- [ ] Reduce view to state machine + composition

### Phase 4: AddFriendsView Refactoring
- [ ] Extract `ContactSearchSection` component
- [ ] Extract `FriendSuggestionsList` component
- [ ] Extract `PendingRequestsSection` component

### Phase 5: CreateEventView Refactoring
- [ ] Extract `EventFormFields` component
- [ ] Extract `LocationSelector` component
- [ ] Extract `DateTimePicker` component
- [ ] Extract `AttendeeSelector` component

### Phase 6: AuthView Refactoring
- [ ] Extract `PhoneEntryStep` component
- [ ] Extract `OTPVerificationStep` component
- [ ] Simplify authentication flow state

### Phase 7: Standardize All Views
- [x] Apply consistent property ordering across SettingsView and ProfileSetupView:
  1. `@Environment` properties
  2. `private let` constants
  3. `@State` properties
  4. Computed properties
  5. `init`
  6. `body`
  7. View builders (with `@ViewBuilder`)
  8. Helper methods
- [x] Add `// MARK: -` comments for sections (SettingsView, ProfileSetupView)
- [ ] Ensure views under 300 lines (main structs are now under 120 lines each)

## Standard View Template
```swift
struct ExampleView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss

    // MARK: - Dependencies
    private let dependency: SomeType

    // MARK: - State
    @State private var localState = ""

    // MARK: - Computed
    private var computedValue: String { ... }

    // MARK: - Init
    init(dependency: SomeType) {
        self.dependency = dependency
    }

    // MARK: - Body
    var body: some View { ... }

    // MARK: - View Builders
    @ViewBuilder
    private var sectionView: some View { ... }

    // MARK: - Helpers
    private func helperMethod() { ... }
}
```

## Completed Refactoring Summary

### SettingsView.swift
- Main `SettingsView` struct: ~54 lines (body only)
- Organized with private extensions for:
  - Background views
  - Section views (personalInfo, privacyNotifications, appPermissions, appearance, resources, logout)
  - Toolbar content
  - Helper methods
- All supporting views (PrivacySettingsView, NotificationSettingsView, HelpCenterView, AboutView, AcknowledgmentsView) refactored with same pattern
- Proper `// MARK: -` comments throughout

### ProfileSetupView.swift
- Main `ProfileSetupView` struct: ~120 lines (including body)
- Organized with private extensions for:
  - View Builders (background, header, title, profile image, text fields, save button)
  - Setup methods
  - Save profile methods
- Extracted components:
  - `ProfileFloatingLabelTextField` - reusable floating label text field
  - `ProfileImagePicker` - UIViewControllerRepresentable for image selection
  - `ProfileCustomTextFieldStyle` - reusable text field style

## Notes
- Use `swiftui-view-refactor` skill for guidance
- Prefer MV (Model-View) over MVVM where state is simple
- Use `@State` for root `@Observable` types
- Extract to same file first, then separate files if >100 lines
