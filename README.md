# Filert

A macOS menu bar app that watches files and folders for changes and sends native notifications.

Filert runs silently in the menu bar and monitors any files or folders you add to its watchlist. When something changes, you get a notification with the exact time of the change and a button to open the file in Finder. It handles iCloud Drive files specifically well — even if your Mac was asleep when a change happened on another device, Filert catches it as soon as the Mac wakes up.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgray) ![Swift](https://img.shields.io/badge/swift-5.9-orange)

---

## What it does

Most file sync tools tell you *that* something changed — Filert tells you *when* and lets you act on it immediately. You add a folder or a specific file, and from that point on any modification, creation, or rename triggers a notification. The notification stays actionable: click it or hit the Open File button to jump straight to the file in Finder.

iCloud Drive adds a layer of complexity because changes can happen on a phone or another Mac while your laptop is closed. When iCloud syncs after wake, the usual file system events fire too late or not at all for files that weren't downloaded. Filert handles this by recording the last-seen modification date for every watched item before sleep and comparing it against current metadata after wake, using both the local file system and NSMetadataQuery for files that are still cloud-only.

## Features

- **Menu bar only** — no Dock icon, no window on launch; just a status item that stays out of the way
- **Real-time watching** — FSEvents stream with a 2-second coalescing window to avoid notification floods
- **iCloud aware** — NSMetadataQuery tracks iCloud Drive files and reports changes even before they are downloaded locally
- **Wake-from-sleep scan** — on wake, Filert compares stored modification dates against current metadata and notifies for anything that changed while asleep
- **Actionable notifications** — click the notification, or use the Open File / Close buttons to open in Finder or dismiss
- **Unread indicator** — the menu bar icon switches to a filled variant when there are unread changes, and back once you clear them
- **Persistent watchlist** — watched paths and last-seen dates survive restarts via UserDefaults

## Getting started

1. Launch Filert — a `doc.badge.clock` icon appears in the menu bar
2. Click the icon and open **Settings...** (`⌘,`)
3. Click **+** and choose one or more files or folders to watch
4. When prompted, allow notification permissions in **System Settings → Notifications → Filert**
5. Changes to any watched item now trigger a notification

Clicking a notification or its **Open File** button reveals the changed file in Finder. For folders, it opens the folder directly. The **Close** button dismisses without opening anything.

## Requirements

- macOS 13.0 Ventura or later
- Xcode 15 or later

## Building

```bash
git clone https://github.com/Phaskal/Filert.git
cd Filert
open Filert.xcodeproj
```

Build and run with **⌘R** in Xcode.

## Project structure

```
Filert/
├── FilertApp.swift              # @main — MenuBarExtra + Settings scene
├── AppDelegate.swift            # App lifecycle, service startup
├── Models/
│   ├── WatchedPath.swift        # Codable watched path model
│   └── ChangeRecord.swift       # Change event model with formatted timestamp
├── Services/
│   ├── FileWatcherService.swift  # FSEvents C API wrapper
│   ├── ICloudMonitor.swift       # NSMetadataQuery for iCloud Drive files
│   ├── SleepWakeMonitor.swift    # NSWorkspace wake observer
│   └── NotificationService.swift # UNUserNotificationCenter, category registration, action handling
├── Managers/
│   └── WatchlistManager.swift   # Watchlist state, event debouncing, wake scan, UserDefaults persistence
└── Views/
    ├── MenuBarMenuView.swift     # Menu bar dropdown content (SwiftUI)
    └── SettingsView.swift        # Watchlist editor (SwiftUI)
```

## Technical notes

**File watching** — `FileWatcherService` wraps the FSEvents C API using `kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer`. Events are dispatched to the main queue with a 2-second latency to coalesce bursts. Directory events and dotfiles are filtered out before reaching `WatchlistManager`. A 4-second per-path debounce window prevents duplicate notifications when multiple events fire for the same file in quick succession.

**iCloud** — `ICloudMonitor` runs an `NSMetadataQuery` scoped to `NSMetadataQueryUbiquitousDocumentsScope` and `NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope`. On live changes it fires through `NSMetadataQueryDidUpdateNotification`. On wake it exposes a `changedItemsSince(_:)` method that walks the current query results and compares `NSMetadataItemFSContentChangeDateKey` against stored dates — this catches changes to files that are still cloud-only and have never been downloaded to the current machine.

**Wake scan** — `SleepWakeMonitor` observes `NSWorkspace.didWakeNotification` and waits 3 seconds before triggering a scan. The delay gives iCloud time to refresh its metadata index after the network reconnects. The scan checks both local `attributesOfItem(atPath:)[.modificationDate]` and the iCloud metadata query, so it covers both downloaded and cloud-only files.

**Notifications** — `NotificationService` conforms to `UNUserNotificationCenterDelegate` and registers a `FILE_CHANGE` category with two actions (`OPEN_FILE`, `CLOSE`). The file path is stored in `userInfo` so the delegate can open the correct item when either the notification body or the Open File button is tapped. `willPresent` returns `.banner` so notifications appear even while the app is the active process.
