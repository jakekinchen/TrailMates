# TrailMates - Agent Instructions

## Project Overview
TrailMates is an iOS app built with SwiftUI and Firebase.

## Planning Workflow

All agents must follow this planning system:

### Plan Locations
- `docs/plans/urgent/` - High-priority plans requiring immediate attention
- `docs/plans/backlog/` - Plans for future work, lower priority
- `docs/plans/archives/` - Completed plans (100% done)

### Plan Format
Plans must be markdown files with:
- Descriptive filename: `YYYY-MM-DD-brief-description.md`
- YAML frontmatter with metadata
- Actionable checkbox items

```markdown
---
title: Plan Title
created: YYYY-MM-DD
priority: urgent | backlog
status: in-progress | blocked | completed
tags: [tag1, tag2]
---

# Plan Title

## Objective
Brief description of what this plan accomplishes.

## Tasks
- [ ] Task 1
  - [ ] Subtask 1.1
  - [ ] Subtask 1.2
- [ ] Task 2
- [ ] Task 3

## Notes
Additional context, constraints, or considerations.
```

### Plan Lifecycle
1. **Create** - New plans go in `urgent/` or `backlog/` based on priority
2. **Update** - Check off tasks as completed, update status in frontmatter
3. **Archive** - When all checkboxes are checked (100%), move to `archives/`

### When Creating Plans
- Always check existing plans first to avoid duplicates
- Link related plans if they exist
- Break large initiatives into smaller, actionable plans

## Available Skills
The following iOS/Swift development skills are installed at `$CODEX_HOME/skills/public/dimillian-skills/`:
- `app-store-changelog` - Generate App Store release notes
- `gh-issue-fix-flow` - Resolve GitHub issues end-to-end
- `ios-debugger-agent` - Build/run/debug on simulators
- `swift-concurrency-expert` - Fix Swift 6.2+ concurrency issues
- `swiftui-liquid-glass` - iOS 26+ Liquid Glass API
- `swiftui-performance-audit` - SwiftUI performance review
- `swiftui-ui-patterns` - SwiftUI component patterns
- `swiftui-view-refactor` - Refactor SwiftUI views
- `macos-spm-app-packaging` - Package macOS apps without Xcode

Invoke skills with `$skill-name` or via the `/skills` command.

## Multi-Agent Commit Workflow

This is a multi-agent working tree. Multiple agents may be working simultaneously on different tasks.

### When You Complete Your Task
1. **Commit only your changes** - Stage and commit only the files you modified
2. **Ignore other changes** - There may be unstaged changes from other agents; leave them alone
3. **Use descriptive commit messages** - Reference the plan or task you completed

### Commit Process
```bash
# Stage only your specific files
git add path/to/your/changed/files

# Commit with descriptive message
git commit -m "$(cat <<'EOF'
Brief description of changes

- Bullet points of what was done
- Reference plan: docs/plans/[priority]/[plan-name].md
EOF
)"
```

### Important Rules
- **DO NOT** use `git add .` or `git add -A` (this would stage other agents' work)
- **DO NOT** worry about untracked/modified files you didn't touch
- **DO** commit frequently as you complete logical chunks of work
- **DO** update the plan file checkboxes before committing

## Code Style
- Follow existing patterns in the codebase
- Use SwiftUI best practices
- Prefer @Observable over ObservableObject for new code
- Keep views lightweight and composable

## Build Commands
- Build: `xcodebuild -scheme TrailMates -destination 'platform=iOS Simulator,name=iPhone 15'`
- Test: `xcodebuild test -scheme TrailMates -destination 'platform=iOS Simulator,name=iPhone 15'`
