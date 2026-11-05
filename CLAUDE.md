# Ombú

A personal macOS terminal on libghostty, forked from Flow (MIT) with Enso's look. Swift and AppKit, no SwiftUI outside the Settings window. The Xcode project is generated: edit `project.yml`, never `ombu.xcodeproj`.

## Build

```sh
./scripts/build-ghosttykit.sh   # once per Ghostty bump: Zig build of Vendor/ghostty into Vendor/
xcodegen generate
xcodebuild -scheme ombu -configuration Debug build
xcodebuild test -scheme ombu -destination 'platform=macOS'
```

Ghostty is the `Vendor/ghostty` submodule, pinned to a release tag. To bump it: move the submodule to the new tag, rerun the build script, rebuild.

## Guidelines

1. A code comment explains why, never how. If it explains how, the code is too complicated.
2. Don't refer to local files or folders in comments.
3. Ghostty's config (`~/.config/ghostty/config`) is the source of truth for the terminal. Ombú never writes to it; Ombú's own settings live in the user defaults (`Preferences`).
4. Naming: in code, workspaces may be called trunks, tabs branches, and the agent-status indicator a leaf. UI copy stays plain: "Workspace", "Tab".
5. Every keyboard shortcut Ombú adds must be listed in `KeyboardShortcuts.all` (the ? button in the title bar).
6. After fixing something in the terminal, quit the old debug build and start a new one with an empty environment, the way the Dock does, so its shells don't inherit `CLAUDECODE`, `CLAUDE_CODE_*`, `OMBU_*` or `GHOSTTY_*` from your session:

   ```
   pkill -f "Debug/Ombu.app/Contents/MacOS/Ombu"
   env -i /usr/bin/open <BUILT_PRODUCTS_DIR>/Ombu.app
   ```

7. Enso (GPL-3) is a visual reference only. Port its look; never paste its code.
