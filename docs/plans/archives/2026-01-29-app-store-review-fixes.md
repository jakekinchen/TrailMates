---
title: App Store Review Fixes (Permissions + iPad Layout)
created: 2026-01-29
priority: urgent
status: completed
tags: [app-review, permissions, privacy, ipad, ui]
---

# App Store Review Fixes (Permissions + iPad Layout)

## Objective
Resolve App Review feedback for:
- Guideline 5.1.1 (location permission pre-prompt)
- Guideline 2.1 (contacts upload clarification)
- Guideline 4.0 (iPad layout cropping)

## Tasks
- [x] Update permissions onboarding flow
  - [x] Replace “Enable Permissions” CTA wording with “Continue”
  - [x] Remove “Set Up Later” option from the pre-permission screen
  - [x] Ensure the system permission prompt is shown immediately after the pre-permission screen
- [x] Confirm contacts behavior + prepare App Review response
  - [x] Verify contacts are read on-device only
  - [x] Verify only hashed phone numbers are sent for contact matching (no names / full contact list upload)
- [x] Fix iPad layout issues
  - [x] Make Profile screen scrollable to avoid bottom cropping
  - [x] Make Edit Profile screen scrollable to avoid action button cropping
- [x] Validate
  - [x] Build for iPad simulator destination
  - [x] Run automated tests

## Notes
Suggested Resolution Center replies:

### Guideline 2.1 (Contacts)
- Contacts are not uploaded as a contact list (no names, no full contact objects).
- For “Find Friends”, the app reads contacts on-device and hashes phone numbers on-device (SHA-256). Only the hashed phone numbers are sent to a server to find matching registered users.

### Guideline 5.1.1 (Location)
- The pre-permission screen no longer uses “Enable Permissions” wording and no longer provides a “Set Up Later” option.
- The system permission prompt appears immediately after the user taps “Continue”.

### Guideline 4.0 (iPad Layout)
- Updated Profile and Edit Profile screens to use scrollable layouts so content/buttons are not cropped on iPad.
