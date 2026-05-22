---
title: App Issue Batch Fixes
created: 2026-05-22
priority: urgent
status: completed
tags: [calendar, friends, profile, auth, deep-links]
---

# App Issue Batch Fixes

## Objective
Resolve reported TrailMates app issues around exported event times, row tap targets, profile image editing, login keyboard layout, phone login contrast, friend discovery/invites, and clipped profile imagery.

## Tasks
- [x] Fix calendar event export so Apple/Google calendar times match the in-app event time
- [x] Make the "friends on the trail" row tappable, not just the icon
- [x] Show the current profile image when editing a profile
- [x] Keep the login background stationary when a text field is focused
- [x] Invert phone input and submit button text/background colors for the requested contrast
- [x] Redesign friend adding around username/phone lookup instead of contacts-first matching
- [x] Make invite links open the sender profile in-app and fall back to the App Store when needed
- [x] Fix the clipped sliver at the top of the profile photo circle
- [x] Build/test and verify the changed flows

## Notes
- Related archived contact consent work: `docs/plans/archives/2026-05-20-contact-upload-consent-review-fix.md`
- This is a multi-agent working tree; only files changed for this plan should be staged and committed.
