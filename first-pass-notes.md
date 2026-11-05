# Ombú — notes for the morning, 2026-11-05

Built overnight on the recommendation in `phase-1-comparison.md` (option B: fork Flow, port Enso's look). Everything is on `main`, one described commit per step. `upstream` points at Flow.

## Run it

The debug build should already be open. Otherwise:

```sh
xcodegen generate            # ombu.xcodeproj is generated and ignored
xcodebuild -scheme ombu -configuration Debug build
open "$(xcodebuild -scheme ombu -configuration Debug -showBuildSettings | awk '/ BUILT_PRODUCTS_DIR =/{print $3}')/Ombu.app"
```

Or open `ombu.xcodeproj` in Xcode and press Run. GhosttyKit is built under `Vendor/` (Ghostty 1.4.0). A debug build is a separate app from a release build (`com.buenasuerte.ombu.debug`, state in `~/Library/Application Support/ombu-debug/`).

## What is in

- **Enso's chrome.** Frosted window edge to edge, the terminal in a rounded card that rises beside the traffic lights, a header strip inside the card (what the tab runs, title, path), a hairline and a soft shadow.
- **Sidebar.** Each workspace (name, `branch · ~/path`, one dot for all its terminals) with its tabs listed under it (process icon, title, per-tab agent dot). Hover a workspace for `+` and `×`, a tab for `×`. A "+ New Terminal" row closes the list. Workspaces and tabs drag up and down (tabs stay in their workspace).
- **Empty state.** A workspace keeps its place with no tabs and shows "No Tabs / Press ⌘T"; the next tab opens in the directory it was in. ⌘W on an empty workspace closes it.
- **⌘T command center.** Enso's panel: Suggestions (New Tab, so ⌘T ↩ is still a new tab), every tab in the window (searchable by title, what it runs, workspace), and the commands with their shortcuts. With a tab selected it also lists Rename Tab (edits the row in the sidebar; the name survives relaunch and shows in the header), Duplicate Tab, Close Other Tabs, Copy Working Directory, Open in Finder, and Move Tab to <workspace> once per other workspace. Ghostty's own `new_tab` keybind opens it too. ⌘P (places) and ⌘I (agents) are Flow's palettes, unchanged.
- **Icons.** Enso's full-colour agent marks (the pixel Claude, Codex, Gemini, Ollama, OpenCode); SF Symbols for vim, ssh, git, node, docker, top, make, less and friends; the terminal glyph for an idle shell.
- **Ghostty config is the source of truth.** `~/.config/ghostty/config` is read the way Ghostty.app reads it. Settings keeps only Ombú's own options plus a pane that opens that file and lists its problems.
- **App icon.** A placeholder `>_` on a blue tile. The ASCII tree is parked; `scripts/make-icon.swift` renders whatever is in `assets/icon-art.txt` when you want to try again.

## Verified

Build, signing with your Apple Development certificate, and the full test suite (319 tests before tonight's additions, all green after). The app launched and read your Ghostty config. I cannot screenshot from here, so the look is yours to judge.

## Not done

1. Drag a tab or workspace out into its own window.
2. Per-pane headers in splits (one header per card for now; split panes dim instead).
3. Process detection through the process table, so an alias like `c` for `claude` is caught before its hooks report in.
4. The command center and sidebar in light mode: untested visually.

## Swift idioms worth knowing in this codebase

- `final class … : NSView` with `override func draw(_:)` is AppKit's custom component; `wantsUpdateLayer` + `updateLayer()` is the cheaper path for a view that is just a coloured layer (the wash, the card border, the hairlines).
- `NSColor(name:dynamicProvider:)` makes a colour that resolves per light/dark appearance. Layers can't take those, so `Theme.ink(0.1).cgColor(in: effectiveAppearance)` resolves one explicitly.
- `weak var delegate` + a protocol sends events up; closures (`onClose`, `indicator`, `tabProcess`) are used where a one-off callback is simpler.
- `guard case .tab(let workspace, let tab)? = clickedRow else { return }` pattern-matches an optional enum in one line.
- `@MainActor` closures: the agent store is main-actor isolated, so anything reading it is marked too.
- `#selector(name)` must be unambiguous: two overloads of a method make the selector fail to compile, hence `openCommandCenter(in:)` beside `showCommandCenter()`.
