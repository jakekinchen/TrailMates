---
title: Fix login phone input keyboard dismissal
created: 2026-01-29
priority: urgent
status: completed
tags: [auth, ui, keyboard, phone-number]
---

# Fix login phone input keyboard dismissal

## Objective
Prevent the phone number keyboard from dismissing mid-entry in the login/signup flow, while still allowing an optional auto-dismiss when the user finishes entering a valid US number.

## Tasks
- [x] Reproduce the keyboard dismissal issue on login
- [x] Fix the underlying focus/dismiss logic in `AuthView`
- [x] Confirm phone entry still formats and caps input correctly (US)
- [x] Add a regression test (UI or unit, whichever is practical)
- [x] Build and run relevant tests
- [x] Archive this plan when complete

## Notes
- Keep dismissal logic based on digit count, not formatted string length.
- Prefer `PhoneNumberService` for normalization/validation, but avoid aggressive parsing that breaks partial entry.
