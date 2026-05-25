---
title: Fix Auth Entry Safe Area Background
created: 2026-05-25
priority: urgent
status: completed
tags: [auth, swiftui, safe-area]
---

# Fix Auth Entry Safe Area Background

## Objective
Remove the black unpainted space at the bottom of the logged-out auth entry screen by correcting the SwiftUI safe-area behavior without changing the visual composition.

## Tasks
- [x] Inspect the current auth entry layout and confirm the root cause
- [x] Patch the auth screen to paint the full container safe area
- [x] Build and visually verify the auth entry screen
- [x] Commit and push only the auth safe-area fix

## Notes
The worktree contains unrelated changes from other agents. Stage only this plan and the safe-area hunk in `TrailMates/AuthView.swift`.
