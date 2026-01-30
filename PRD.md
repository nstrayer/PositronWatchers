---
type: prd
title: "Process Watcher Menubar App"
created: 2026-01-30
updated: 2026-01-30
status: ready
---

# Process Watcher Menubar App PRD

## Overview

A lightweight macOS menubar application that monitors developer tools and processes via pattern matching, providing at-a-glance awareness of running processes and their resource consumption. Built with Swift/AppKit for minimal memory footprint and native macOS integration.

## Problem Statement

Developers often have multiple instances of the same build watchers, language servers, and development tools running simultaneously without realizing it, leading to system slowdowns. Checking Activity Monitor is cumbersome and shows too much irrelevant information. Developers need a focused, lightweight way to maintain awareness of their development processes.

## Goals & Objectives

- Provide instant visibility into running developer processes
- Help developers identify duplicate process instances that cause slowdowns
- Offer a lighter-weight alternative to Activity Monitor for routine checks
- Maintain minimal resource footprint while providing continuous monitoring

## User Personas

**Primary User**: Software developers working on macOS who:
- Run multiple development tools simultaneously (bundlers, language servers, file watchers)
- Experience system slowdowns from runaway or duplicate processes
- Want passive awareness of what's consuming resources
- Prefer lightweight, focused tools over heavy system monitors

## User Stories

- As a developer, I want to see all instances of my development processes so that I can identify when duplicates are running
- As a developer, I want to check process status from the menubar so that I don't need to open Activity Monitor
- As a developer, I want to define patterns for processes to watch so that I only see relevant information
- As a developer, I want to copy kill commands so that I can safely terminate processes when needed

## Requirements

### Functional Requirements

#### Pattern Matching
- Support glob pattern matching (e.g., `*gulp*watch-client*`) to define which processes to monitor
- Match patterns against full command line (process name + arguments), not just process name
- Persist pattern configuration between app restarts via Preferences window
- Ship with default patterns: `*gulp*watch-client*` and `*gulp*watch-extensions*`

#### Process Display
- Group matched processes by working directory (project folder)
- Display menubar badge showing count of active project "pairs" (working directories with matched processes)
- Show visual indicator on menubar icon when a process has crashed (was running, now missing)
- Each process entry shows: name, CPU%, memory usage (absolute MB)
- Poll process status every 5 seconds

#### User Interaction
- Preferences window with GUI list editor for adding/removing/editing patterns
- Click-to-copy kill command for each process (format: `kill <PID>`)
- Empty state shows helpful message with link to open Preferences
- Display information in standard macOS menubar dropdown

### Nice-to-Have

- High CPU threshold warnings (flag processes exceeding sustained high CPU)

### Non-Functional Requirements

- **Performance**: Minimal CPU impact, polling efficiency, <5MB memory footprint for the app itself
- **Reliability**: Graceful handling of process query failures, accurate process information
- **Native feel**: Standard macOS menubar behavior, system-consistent UI
- **Fast startup**: Launch at login without noticeable delay

## Acceptance Criteria

- [ ] Glob patterns match against full command line (name + arguments)
- [ ] Processes are grouped by working directory in the menu
- [ ] Menubar icon shows badge with count of active project pairs
- [ ] Menubar icon indicates when a previously-running process is now missing
- [ ] Pattern configuration via Preferences window persists between restarts
- [ ] Process information updates within 5 seconds of changes
- [ ] App memory usage stays under 5MB during normal operation
- [ ] Each process entry shows: name, CPU%, memory (MB)
- [ ] Clicking a process copies `kill <PID>` to clipboard
- [ ] Empty state shows helpful message with link to Preferences
- [ ] Default patterns (`*gulp*watch-client*`, `*gulp*watch-extensions*`) are pre-configured
- [ ] "Launch at Login" toggle in Preferences uses SMAppService and persists correctly

## Distribution & Packaging

| Aspect | Decision |
|--------|----------|
| Distribution method | Direct download via GitHub releases |
| Packaging format | DMG with drag-to-Applications |
| Code signing | Signed and notarized with Apple Developer ID |
| Minimum macOS | macOS 14 Sonoma |
| Architecture | Apple Silicon only (arm64) |
| Sandboxing | Not sandboxed (required for process monitoring APIs) |
| Launch at Login | SMAppService API with in-app toggle in Preferences |
| Updates | Manual download initially; architecture supports future in-app updates |

## Technical Considerations

### Constraints
- macOS only (no cross-platform requirements)
- macOS 14 Sonoma minimum deployment target
- Apple Silicon (arm64) only
- Must work without admin privileges or sudo access
- Minimal dependencies (pure Swift/AppKit implementation)
- Use system process APIs rather than shell commands where possible
- Not sandboxed (to allow full process monitoring access)

### Architecture Notes
- NSStatusItem for menubar integration with dynamic badge
- Process monitoring via `sysctl` or `proc_pidinfo` APIs
- Use `proc_pidinfo` with `PROC_PIDVNODEPATHINFO` to get process working directory
- Glob pattern matching against full command line
- Configuration stored in user defaults (accessed via Preferences window)
- Track process state over time to detect "crashed" (missing) processes
- SMAppService for "Launch at Login" functionality
- Version info stored in Info.plist to support future update checking

## Out of Scope

- Process launching or restarting capabilities
- Log viewing (stdout/stderr output)
- Remote process monitoring
- System processes (focus only on developer tools)
- Process history or historical resource usage
- Automated killing of processes
- Integration with other monitoring tools
- Pause/resume monitoring (user can quit app if not needed)
- Regex pattern matching (glob only)
- Config file editing (Preferences window only)
- Intel Mac support (Apple Silicon only)

## Success Metrics

- **Time saved**: Faster to check than opening Activity Monitor (target: <2 seconds to view process status)
- **Adoption**: Developer uses the app multiple times per day
- **Problem prevention**: Successfully identifies duplicate processes before they cause noticeable slowdowns
- **Resource efficiency**: Consistently uses less memory than a single Chrome tab

## Failure Indicators

- Shows too many irrelevant processes (noise overwhelms signal)
- Inaccurate process information or missed processes
- The watcher itself becomes a resource hog
- Developer abandons the tool within a week of installation

## Resolved Decisions

| Question | Decision |
|----------|----------|
| Menubar icon indicator | Badge shows count of active project pairs; visual indicator when process crashed |
| Default patterns | `*gulp*watch-client*` and `*gulp*watch-extensions*` |
| Pause monitoring | Not needed—user can quit the app |
| Pattern conflicts/overlaps | Allowed—a process can match multiple patterns |
| Pattern format | Glob only (simpler syntax) |
| Match target | Full command line (name + arguments) |
| Process grouping | By working directory (automatic) |
| Crash detection | Missing expected process (was running, now gone) |
| Kill command format | `kill <PID>` (graceful SIGTERM) |
| Memory display | Absolute MB |
| Configuration UX | Preferences window with GUI list editor |