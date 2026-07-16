---
name: verify
description: Build, test, and drive The Brief (SignalDaily) iOS app to verify changes end-to-end.
---

# Verifying The Brief (SignalDaily)

## Critical: do not build inside this folder
This repo lives in iCloud Drive. `xcodebuild` (and `xcodebuild -list`) hang
forever here waiting on NSFileCoordinator access claims. Always rsync to a
local shadow copy and build there:

```sh
rsync -a --delete --exclude build --exclude backend --exclude .git \
  "<repo>/" /tmp/SignalDaily-buildcheck/
cd /tmp/SignalDaily-buildcheck
xcodebuild build -project SignalDaily.xcodeproj -scheme SignalDaily \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO \
  SIGNAL_DAILY_USE_MOCKS=YES
xcodebuild test -project SignalDaily.xcodeproj -scheme SignalDaily \
  -destination 'platform=iOS Simulator,name=<any booted device>' \
  CODE_SIGNING_ALLOWED=NO
```

Plain file edits, git, and `xcodegen generate` work fine in place.
After adding/removing source files, run `xcodegen generate` (project.yml is
the source of truth), then rsync again.

## Running the app
- `SIGNAL_DAILY_USE_MOCKS=YES` builds against MockBriefingService (6 stories,
  updates on story_001/story_005, briefing date 2026-05-17).
- The built app is at DerivedData `.../Debug-iphonesimulator/SignalDaily.app`;
  `xcrun simctl install <udid> <app>` then `launch <udid> com.signaldaily.app`.
- Auth gate: tap "Developer access" on the auth screen — it signs in and
  switches to the LIVE API (real GDELT briefing, ~120 stories). For mock-only
  flows, inject defaults before launch:
  `simctl spawn <udid> defaults write com.signaldaily.app hasCompletedOnboarding -bool true`
  plus a JSON `SignalDaily.authSession` blob (see AuthSession model).
- Simulator prefs can survive uninstall within a boot (cfprefsd cache);
  don't trust "fresh install" for defaults-dependent tests.

## What to drive
Today deck: tap card bottom-left = Done, bottom-right = Comment, top = popup.
Completing all cards shows the seal card and increments calm mornings.
Kill + relaunch must restore read/sealed state (ReadingLedger in UserDefaults).
Library tab = persistent archive; Saved via popup bookmark.
