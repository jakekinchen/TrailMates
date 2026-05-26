---
title: Swift 6 Strict Concurrency Migration
created: 2026-05-25
priority: backlog
status: in-progress
tags: [swift, concurrency, build-settings]
---

# Swift 6 Strict Concurrency Migration

## Objective
Move TrailMates toward Swift 6 strict concurrency after the current green baseline build and test run, without reintroducing broad warning suppression.

## Related Plans
- `docs/plans/backlog/2026-05-23-codebase-audit-remediation.md`

## Tasks
- [ ] Capture the current baseline build and test logs before changing concurrency language settings
- [ ] Enable targeted concurrency diagnostics in Debug first
- [ ] Audit remaining `@unchecked Sendable` types and document actor ownership for each one
- [ ] Replace fire-and-forget UI tasks with cancellable task ownership where user-visible errors can occur
- [ ] Run the app build and test suite with stricter concurrency diagnostics enabled
- [ ] Promote the setting to Release only after Debug is warning-free

## Notes
- Keep warnings visible during this migration; do not restore package-level or project-level warning suppression.
- Prefer small follow-up patches so concurrency fixes remain reviewable.
