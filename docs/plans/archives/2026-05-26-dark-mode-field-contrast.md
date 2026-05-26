---
title: Fix Dark Mode Field Contrast
created: 2026-05-26
priority: urgent
status: completed
tags: [auth, friends, forms, ui]
---

# Fix Dark Mode Field Contrast

## Objective
Fix beige-on-beige text in form fields and Friends rows when the app is running in dark mode.

## Tasks
- [x] Inspect the shared floating-label field color and layering implementation
- [x] Patch inverted form fields to use fixed pine text on fixed beige backgrounds
- [x] Keep the floating label above the native text input layer
- [x] Patch Friends search and row text to use fixed pine on fixed beige surfaces
- [x] Build and capture auth/Friends comparison screenshots

## Notes
`AppColors.pine` adapts to beige in dark mode. It should not be used as foreground text on `AppColors.alwaysBeige` surfaces; use `AppColors.alwaysPine` there.
