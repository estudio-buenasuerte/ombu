# Ombú

A personal macOS terminal on libghostty. Ombú is a fork of Enso (GPL-3): `main` is
Enso's `next` branch plus Ombú's own commits. Swift and SwiftUI, Xcode project
at `macos/Enso.xcodeproj`, scheme `Enso`. The first, AppKit incarnation (a Flow
fork) lives on the `appkit` branch for reference.

## Build

The product is named `Ombu` (ASCII) and only the display name carries the accent: codesign fails on an accented executable name.

```sh
./scripts/build-ghosttykit.sh      # once per Ghostty bump: Zig build of Vendor/ghostty, linked into macos/
xcodebuild -project macos/Enso.xcodeproj -scheme Enso -configuration Debug -derivedDataPath build/DerivedData build
xcodebuild test -project macos/Enso.xcodeproj -scheme Enso -destination 'platform=macOS'
```

Ghostty is the `Vendor/ghostty` submodule, pinned to a release tag. `UPSTREAM.md`
records the Ghostty and Enso versions Ombú is on and how to take a new one.

## Guidelines

1. Keep Ombú's changes small and local. Every file Ombú touches is a merge
   conflict the next time Enso's `next` moves, so prefer adding over rewriting,
   and leave Enso's internal names (`ENSO_*` environment variables, type names,
   file names) alone. Only user-facing identity changes: app name, bundle id,
   icon, fonts, support folder.
2. A code comment explains why, never how. Don't refer to local files or folders
   in comments.
3. Ghostty's config (`~/.config/ghostty/config`) is the source of truth for the
   terminal. Ombú never writes to it.
4. UI copy stays plain: "Workspace", "Tab". Enso calls a workspace a folder in
   code; Ombú keeps that name in code.
5. After fixing something in the terminal, quit the old debug build and start a
   new one with an empty environment, the way the Dock does, so its shells don't
   inherit `CLAUDECODE`, `CLAUDE_CODE_*`, `ENSO_*` or `GHOSTTY_*` from your session:

   ```
   pkill -f "Debug/Ombu Dev.app/Contents/MacOS/Ombu Dev"
   env -i /usr/bin/open "build/DerivedData/Build/Products/Debug/Ombu Dev.app"
   ```

6. Taking an Enso release: `git fetch enso --tags`, `git merge <tag>`, resolve,
   build, run the tests, update `UPSTREAM.md`. Never rebase `main`.
