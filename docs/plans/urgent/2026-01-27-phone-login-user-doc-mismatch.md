---
title: Fix phone login "User document not found" for existing accounts
created: 2026-01-27
priority: urgent
status: blocked
tags: [auth, firebase, firestore, phone-number]
---

# Fix phone login "User document not found" for existing accounts

## Objective
Unblock users who can authenticate via phone number but fail login because their Firestore `/users/{uid}` document is missing/mismatched, while signup is blocked as "account already exists".

## Tasks
- [x] Identify the source of the mismatch (Auth UID vs Firestore doc id)
- [x] Add a server-side callable to ensure/migrate the current user document
  - [x] Bind migration to the authenticated user's phone number
  - [x] Copy legacy doc data into `/users/{uid}` when needed
- [x] Update iOS login flow to call the ensure/migration path when `/users/{uid}` is missing
- [x] Add/extend Cloud Function tests for the new callable
- [x] Unblock Cloud Functions v2 deploy (Pub/Sub + Eventarc service identities)
- [x] Deploy `ensureUserDocument` Cloud Function to production
- [ ] Verify phone login works end-to-end (existing account)
- [x] Run tests/builds (functions + iOS)
- [ ] Archive this plan when complete

## Notes
- Firestore rules require `/users/{userId}` where `userId == request.auth.uid`, so legacy user docs with other ids will be unreadable by their owner.
- The migration/ensure callable must not accept arbitrary phone numbers/hashes without verification; it should derive the phone number from the authenticated Firebase Auth user record.
- Local validations:
  - `functions` tests pass (`npm test`)
  - iOS build succeeds (`xcodebuild build`); `xcodebuild test` currently fails due to an unrelated pre-existing `UserManagerTests/testUserEquality` fixture issue.
- Deployment blocker:
  - `firebase deploy` fails with “Error generating the service identity for pubsub.googleapis.com / eventarc.googleapis.com”.
  - Resolve by granting sufficient IAM permissions (e.g., `Owner`, or `Service Usage Admin` + `Service Account Admin`) and retry deploy.
