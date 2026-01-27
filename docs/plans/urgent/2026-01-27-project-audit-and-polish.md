---
title: Project Audit & Polish
created: 2026-01-27
priority: urgent
status: in-progress
tags: [audit, cleanup, docs, testing]
---

# Project Audit & Polish

## Objective
Ensure TrailMates is buildable/testable from a clean checkout, has the minimum required configuration committed (with secrets templated when needed), and stays simple while remaining fully capable for its core features.

## Tasks
- [x] Git hygiene
  - [x] Decide on `.git/hooks/post-commit` auto-push behavior (currently pushes `origin/main` after every commit)
  - [x] Commit current test-suite stability fixes (fixtures + UI test reliability + scheme settings)
- [x] Build & test verification
  - [x] Run `xcodebuild build -scheme TrailMatesATX` on a simulator destination
  - [x] Run `xcodebuild test -scheme TrailMatesATX` and confirm green
- [x] Repo completeness
  - [x] Confirm Info.plist strategy (`GENERATE_INFOPLIST_FILE` vs committed `Info.plist`) and ensure it’s reproducible for collaborators/CI
  - [x] Decide how to handle `GoogleService-Info.plist` (committed vs template + local setup steps)
  - [x] Update `README.md` to match current build/test setup (SwiftPM, schemes, destinations)
  - [x] Review `.gitignore` for overly broad rules (e.g., `*.plist`) that may hide required config
- [ ] Firebase / backend sanity
  - [x] Confirm Firestore/Storage rules files referenced in `firebase.json` are the intended ones
  - [x] Remove unused Firebase rules/config files if safe (e.g., `firestorage.rules`)
  - [ ] Review callable functions for user-enumeration risk and add mitigation (auth/App Check/rate limiting) as needed
- [ ] Simplicity pass
  - [ ] Identify dead files / duplicate schemes / unused targets and remove if safe
  - [ ] Validate naming + folder structure consistency across app, tests, and Firebase functions

## Notes
- A local `.git/hooks/post-commit` currently auto-pushes to `origin/main`. Disable/rename it if you want manual control over pushes.
