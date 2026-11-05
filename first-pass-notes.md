# Ombú — first pass, 2026-11-05

Built overnight on the recommendation in `phase-1-comparison.md` (option B: fork Flow, port Enso's look). Four commits on `main`, each described in its message. `upstream` points at Flow so you can `git fetch upstream` later.

## Run it

```sh
xcodegen generate            # ombu.xcodeproj is generated and ignored
xcodebuild -scheme ombu -configuration Debug build
open "$(xcodebuild -scheme ombu -configuration Debug -showBuildSettings | awk '/ BUILT_PRODUCTS_DIR =/{print $3}')/Ombu.app"
```

Or open `ombu.xcodeproj` in Xcode and press Run. GhosttyKit is already built under `Vendor/` (Ghostty 1.4.0). To rebuild it after a Ghostty bump, run `./scripts/build-ghosttykit.sh`.

A debug build is a separate app from a release build (`com.buenasuerte.ombu.debug`, state in `~/Library/Application Support/ombu-debug/`).

## What is verified

- Debug build compiles and signs with your Apple Development certificate (team 8WA5YWTZ2F).
- The full test suite passes (Flow's tests, minus the ones for removed code).
- The app launched, read your Ghostty config (the first workspace opened in `~/Developer`, which is your `working-directory` setting), and saved `session.json`.

## What is not verified

I could not take a screenshot (this process has no screen-recording permission), so **the chrome is unreviewed visually**. Things to look at first:

1. The frosted window and the inset terminal card: does the card's corner clipping hold with your `background-opacity = 0.78` and blur?
2. Sidebar rows: workspace rows (name, `branch · ~/path`) with tab rows under them. Hover shows `+` and `×`.
3. Run `vim`, `claude`, `git log` in a tab and watch the icon change. Agents show their brand mark.
4. Light mode. The window follows the terminal background's luminance (Flow's rule), so with `#121212` it stays dark.

## Decisions I made for you

- **Tabs live in the sidebar, not in a strip above the terminal.** That is Enso's layout and it makes the per-tab icon and dot the sidebar's job. Flow's tab bar is deleted (`git show bbffc05~1:Sources/UI/TabBarView.swift` if you want it back).
- **Sparkle removed.** Personal build, no updates.
- **Settings reduced** to secure keyboard entry, agent notifications and sounds, and a Ghostty pane that opens `~/.config/ghostty/config` and lists config problems. Everything about the terminal is Ghostty's file.
- **Env vars and helper renamed** (`OMBU_SURFACE_ID`, `OMBU_SOCKET`, `OMBU_HELPER`, `Contents/Helpers/ombu-helper`) so a running Flow and Ombú never confuse each other's shells. Swift type names like `FlwCommand` kept their spelling to keep the diff reviewable.
- **Icon**: `assets/icon-art.txt` is the ASCII; `swift scripts/make-icon.swift assets/icon.png --art assets/icon-art.txt --set Resources/Assets.xcassets/AppIcon.appiconset` regenerates every size. Edit the text file and rerun to try another tree.

## Not done yet (in rough priority)

1. **Drag a workspace or tab out into a new window.** Workspaces can be reordered by drag; dropping outside the window isn't handled. The hook is `tableView(_:draggingSession:endedAt:operation:)` in `SidebarViewController` plus `AppDelegate.openWorkspace(in:newWindow:)`.
2. **Per-pane headers in splits** (Enso shows icon + title + cwd above each pane). Flow dims unfocused panes instead; the sidebar row shows the focused pane's process.
3. **Command palette styling.** Flow's palette works (⌘P places, ⌘I agents) but still looks like Flow's.
4. **Process detection by process table.** Titles cover `claude`, `vim`, `ssh`, etc. typed directly; an alias like `c` for `claude` is only caught when the agent's hooks report in. Enso's proc-table walk would close that gap.
5. Workspace rows don't show an aggregate agent dot when the window is narrow; only tab rows carry dots.

## Swift idioms worth knowing in this codebase

- `final class … : NSView` with `override func draw(_:)` is AppKit's equivalent of a custom component; `wantsUpdateLayer` + `updateLayer()` is the cheaper path when a view is just a colored layer (used for the wash and the card border).
- `NSColor(name:dynamicProvider:)` makes a color that resolves per light/dark appearance. Layers can't take those, so `Theme.ink(0.1).cgColor(in: effectiveAppearance)` resolves one explicitly.
- `weak var delegate` + a protocol is the usual AppKit way to send events up; closures (`onClose`, `agentIndicator`) are used where a one-off callback is simpler.
- `guard case .tab(let workspace, let tab)? = clickedRow else { return }` pattern-matches an optional enum in one line.
- `lazy var` in a view controller delays construction until first use (Settings window, About window).
- `@MainActor` closures in the sidebar: the agent store is main-actor isolated, so anything reading it is marked too.
