---
title: Fix Date/Time Picker Digit Overlap
created: 2026-01-29
priority: urgent
status: completed
tags: [ui, datepicker, create-event]
---

# Fix Date/Time Picker Digit Overlap

## Objective
Eliminate overlapping/garbled digits in the compact date/time control on the Create Event screen across iPhone and iPad.

## Tasks
- [x] Reproduce and document conditions
  - [x] Confirm affected devices (iPhone + iPad) and iOS versions
  - [x] Identify whether Dynamic Type / localization affects it
- [x] Identify root cause in layout or font configuration
  - [x] Inspect `CreateEventView` DateTimePicker layout + constraints
  - [x] Check for global UIAppearance/font overrides impacting `UIDatePicker`
- [x] Implement a robust layout fix
  - [x] Adjust priorities/sizing so compact picker isn’t horizontally compressed
  - [x] Add fallback UI (separate Date + Time pickers) when width is constrained
- [x] Validate
  - [x] Build app
  - [x] Smoke-test Create Event on iPhone + iPad simulators

## Notes
- The current implementation uses a `UIViewRepresentable` bridge to `UIDatePicker` (`.compact`) to support `minuteInterval`.
- If overlap is caused by width compression, prioritizing the picker (or falling back to separate pickers) should eliminate the artifact.
