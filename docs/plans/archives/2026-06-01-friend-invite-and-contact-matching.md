---
title: Friend Invite and Contact Matching Fix
created: 2026-06-01
priority: urgent
status: completed
tags: [friends, contacts, invites, deeplinks]
---

# Friend Invite and Contact Matching Fix

## Objective
Restore friend adding by username, contacts, and invite links without using the wrong public website domain.

## Tasks
- [x] Fix Add Friends username input so full usernames can be typed
- [x] Fix contact matching to map returned users back to local contacts by matched phone hash
- [x] Stop invite messages from using `trailmates.app` as the visible invite URL
- [x] Add focused tests for contact matching, invite URLs, and Cloud Function payloads
- [x] Build/test locally and deploy backend changes if needed
- [x] Commit only the related files

## Notes
Contact matching must keep raw phone numbers private. The app may send hashes and receive a matched hash, but should not expose another user's raw phone number through public lookup responses.
