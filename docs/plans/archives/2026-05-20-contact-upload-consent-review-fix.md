---
title: Contact Upload Consent Review Fix
created: 2026-05-20
priority: urgent
status: completed
tags: [app-review, privacy, contacts]
---

# Contact Upload Consent Review Fix

## Objective
Resolve App Review Guideline 5.1.2 feedback by clearly disclosing contact-derived server matching and obtaining user consent before any contact phone hashes are sent to Firebase.

## Tasks
- [x] Audit contact matching flow and prior App Review response
- [x] Add explicit in-app consent before requesting contacts and matching on the server
- [x] Update contacts permission purpose text to disclose server-side matching
- [x] Bump build number for resubmission
- [x] Validate simulator build and generated Info.plist
- [x] Run full test suite and record unrelated failure
  - Unit tests passed: 163 tests in 8 suites
  - UI test suite has one existing performance-threshold failure: `testAppResponsivenessAfterLaunch` measured 2.58s against a 2.0s threshold
- [x] Archive/upload a corrected build and prepare App Review response
- [x] Reply in Resolution Center and resubmit build 1.0 (10) to App Review

## Notes
Related archived plan: `docs/plans/archives/2026-01-29-app-store-review-fixes.md`
Submitted to App Review on 2026-05-20 at 4:13 PM Central. App Store Connect shows the item as Waiting for Review.
