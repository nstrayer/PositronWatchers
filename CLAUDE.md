# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the project
xcodebuild -project PositronWatchers.xcodeproj -scheme PositronWatchers -configuration Debug build

# Run tests
xcodebuild -project PositronWatchers.xcodeproj -scheme PositronWatchers test

# Clean build
xcodebuild -project PositronWatchers.xcodeproj -scheme PositronWatchers clean
```

Alternatively, open `PositronWatchers.xcodeproj` in Xcode and use Cmd+B to build, Cmd+U to test.

## Architecture

This is a macOS menubar app that monitors developer processes via pattern matching. It uses pure Swift/AppKit (no third-party dependencies).

### Layer Structure

- **App/** - Entry point and lifecycle (`PositronWatchersApp`, `AppDelegate`, `ServiceContainer`)
- **Domain/Models/** - Data models (`WatchedProcess`, `ProcessPattern`, `ProcessGroup`, `MissingProcess`)
- **Domain/Services/** - Business logic (`ProcessMonitor`, `GlobMatcher`, `CrashDetector`)
- **Infrastructure/Process/** - System-level process APIs (`ProcessInfoFetcher`)
- **Infrastructure/Persistence/** - UserDefaults storage (`SettingsStorage`)
- **Infrastructure/MenuBar/** - NSStatusItem management (`MenuBarController`)
- **Presentation/** - SwiftUI views for menu and preferences

### Key Components

**ServiceContainer** (singleton) wires up all dependencies:
- `ProcessMonitor` orchestrates polling, matching, and crash detection
- `ProcessInfoFetcher` uses Darwin APIs (`proc_pidinfo`, `sysctl`) to get process info
- `GlobMatcher` converts glob patterns to regex for matching against command lines
- `CrashDetector` tracks previously-seen processes to detect when they disappear
- `SettingsStorage` persists patterns and launch-at-login preference

**Data Flow**:
1. `ProcessMonitor.poll()` runs every 5 seconds
2. `ProcessInfoFetcher` queries all system processes
3. `GlobMatcher` filters to processes matching enabled patterns
4. Results grouped by working directory into `ProcessGroup`s
5. `MenuBarController` observes `@Published` properties and rebuilds menu

### Process Information APIs

The app uses low-level Darwin APIs (not sandboxed):
- `proc_listallpids()` - enumerate all PIDs
- `proc_pidinfo()` with `PROC_PIDTASKALLINFO` - get task info (CPU, memory)
- `proc_pidinfo()` with `PROC_PIDVNODEPATHINFO` - get working directory
- `sysctl()` with `KERN_PROCARGS2` - get full command line arguments

## Key Implementation Details

- Patterns use glob syntax (`*gulp*watch-client*`), converted to regex internally
- Matching is case-insensitive against full command line (process + args)
- Click on process item copies `kill <PID>` to clipboard
- Launch at Login uses `SMAppService.mainApp.register()`
- Default patterns: `*gulp*watch-client*`, `*gulp*watch-extensions*`

## Scripts

- **`scripts/regenerate-menubar-icon.sh`** - Regenerates menubar icon assets from `Positron Watcher Icon.png` at project root. Run this after updating the source icon file.
