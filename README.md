# PositronWatchers

A lightweight macOS menubar app that monitors developer processes via pattern matching.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-green)

## The Problem

Developers often have multiple instances of build watchers, language servers, and dev tools running simultaneously without realizing it. These duplicate processes cause system slowdowns, but checking Activity Monitor is cumbersome—it shows too much irrelevant information.

## The Solution

PositronWatchers lives in your menubar and shows only the processes you care about. Define glob patterns to match against command lines, and get instant visibility into what's running, grouped by project directory.

## Features

- **Pattern-based filtering** — Use glob patterns (e.g., `*gulp*watch*`) to monitor specific processes
- **Project grouping** — Processes are grouped by working directory so you can see what's running per project
- **Resource monitoring** — See CPU% and memory usage at a glance
- **Crash detection** — Visual indicator when a previously-running process disappears
- **Quick kill** — Click any process to copy `kill <PID>` to your clipboard
- **Launch at Login** — Start automatically when you log in

## Installation

1. Download `PositronWatchers.dmg` from the [latest release](https://github.com/nstrayer/PositronWatchers/releases)
2. Open the DMG and drag PositronWatchers to Applications
3. Launch from Applications (you may need to right-click → Open the first time)

## Usage

Click the menubar icon to see your matched processes. Open **Preferences** to:

- Add, edit, or remove glob patterns
- Enable/disable specific patterns
- Toggle Launch at Login

### Default Patterns

The app ships with patterns for Positron's gulp watchers:
- `*gulp*watch-client*`
- `*gulp*watch-extensions*`

Customize these in Preferences to match your own dev tools.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon (M1/M2/M3)

## Building from Source

```bash
xcodebuild -project PositronWatchers.xcodeproj -scheme PositronWatchers -configuration Release build
```

Or open `PositronWatchers.xcodeproj` in Xcode and press ⌘B.

## License

MIT
