# Ombú — Phase 1: Enso vs Flow, and the recommendation

Written 2026-11-05. References cloned into `references/` (Enso `a54e909`, Flow `7e9c82e`, both HEAD of main that night).

## Name check

- Homebrew: no formula or cask named `ombu`.
- Local Spotlight: no app or bundle id containing "ombu".
- Web: nothing notable. Nearest is "Ombud" (an enterprise RevOps web product). OmbuLabs (a Rails consultancy) uses the word but ships no macOS app.

`ombu` / `com.buenasuerte.ombu` is clear.

## What the installed apps actually ship

| | Enso 0.11.2 | Flow 0.4.1 |
|---|---|---|
| Bundle id | `com.amanchaudhary.enso` | `dev.thetinygoat.flow` |
| Min macOS | 15.0 | 14.0 |
| Built with | Xcode 26.0 (macOS 26.5 SDK) | Xcode 27.0 |
| GhosttyKit | Statically linked into the main binary (no GhosttyKit in `Frameworks/`, only Sparkle). Built from Ghostty source with Zig. | Same: static `ghostty-internal.a` in the binary, Sparkle is the only framework. Plus a `Helpers/flw` CLI. |
| Ghostty version | 1.3.1 (version string in the binary) | 1.4.0 (submodule pinned to tag `v1.4.0`, commit `83fb956`) |
| Ghostty resources | `Resources/ghostty/` (themes + shell-integration) and `Resources/terminfo/` | Same two, plus `Resources/shell-integration/` (Flow's own zsh/bash/fish hooks) and `Resources/agents/opencode/flow.js` |
| License | GPL-3.0 | MIT |

Neither ships a prebuilt xcframework or libghostty-spm. Both build GhosttyKit from a Ghostty checkout with `zig build -Demit-xcframework=true` and link the static archive.

## What each wrote to disk

**Enso** `~/Library/Application Support/Enso/`
- `state.json` — `{version, spaces: [{id, name, icon, pinnedItems, pinnedSessions, ephemeralSessions, pinnedFolders}], splitContainers, collapsedFolderIDs}`. A flat session list per "space"; splits are a separate list of containers that reference session ids.
- `shims/bin/{claude,codex,enso-hook-relay}` — bash wrappers installed on every launch, stamped by SHA in `.version`. These get prepended to PATH inside Enso tabs.
- Prefs (`com.amanchaudhary.enso`): only `sidebarVisible`, Sparkle keys, window frame.

**Flow** `~/Library/Application Support/flow/`
- `session.json` — `{windows: [{frame, selectedWorkspace, workspaces: [{id, customName, selectedTab, tabs: [{layout: terminal|split tree, zoomedPane}]}]}]}`. Working directory per terminal leaf. Terminals restart lazily when first viewed.
- `agent.<pid>.sock` — Unix socket while Flow runs (one per running instance).
- Prefs (`dev.thetinygoat.flow`): `SidebarHidden`, Sparkle keys.
- `~/.config/flow/config` — Flow copies your Ghostty config here on first launch and then reads **only** this file. (Not present on your machine yet, Flow created `session.json` only.)

Neither app uses a sandbox container.

## Agent hooks in your config

Nothing. `~/.claude/settings.json`, `~/.codex/config.toml` and `~/.config/opencode/opencode.jsonc` contain no Flow or Enso entries. Both apps attach without touching your files:

- **Flow:** shell integration (via `ZDOTDIR` for zsh, `XDG_DATA_DIRS` for fish) prepends a per-terminal shim dir to PATH. The `claude` shim execs `flw launch claude`, which resolves the real binary and adds `--settings '{"hooks": …}'` pointing every hook at `flw hook claude`. Codex gets `-c hooks.…` overrides; OpenCode gets a plugin dir via env. Hooks write one JSON line to the app's socket. Set `FLOW_AGENTS_DISABLED=1` to opt out per session.
- **Enso:** installs its own `claude`/`codex` wrapper scripts under Application Support and prepends that dir to PATH per tab (`ENSO_SHIM_DIR`). The wrapper mints a `--session-id`, injects `--settings` hooks that call `enso-hook-relay`, which appends to `agent-sessions/<tab>.jsonl`. The app tails those files with a 1 s poll.

Flow's design is cleaner: one helper binary, no scripts on disk, socket delivery, no polling.

## Per-app mapping

### a. Hosting the Ghostty surface

**Enso** (`macos/Enso/Ghostty/`): `GhosttyRuntime` singleton owns `ghostty_app_t`, loads config, coalesces wakeups into `ghostty_app_tick`. `GhosttySurfaceView: NSView, NSTextInputClient` does keyboard (through `interpretKeyEvents` for IME), mouse, scroll, drag-drop, cursor shape. `GhosttySurfaceManager` keeps one live view per session id so switching tabs reattaches rather than respawns. Hosted in SwiftUI through `GhosttyTerminalHostView: NSViewRepresentable` → `SplitLayoutHostView` (an AppKit container that lays out the split tree and draws pane cards and dividers; 2,186 lines with headers, tooltips, overflow menus).

The runtime handles only five actions: `SET_TITLE`, `PWD`, `QUIT`, `MOUSE_SHAPE`, `OPEN_URL`. Ghostty keybinds for new split, goto split, resize, zoom, reload config, search, color scheme, desktop notification are not routed. ⌘D splits are Enso's own SwiftUI commands.

**Flow** (`Sources/Ghostty/`): `GhosttyRuntime` (non-singleton, injected) with a `GhosttyRuntimeDelegate` protocol that the window implements. Handles the full action set: new tab/split/window, close tab modes, goto tab/split, resize/equalize/zoom, `CONFIG_CHANGE`, `RELOAD_CONFIG`, `OPEN_CONFIG`, color scheme (light/dark follows the system), search, secure input, desktop notifications, command-finished, scrollbar, hover link, progress. `TerminalSurfaceView` (1,076 lines) adds a scrollbar, search bar, link preview, dim overlay for unfocused panes, secure-input badge, and **deferred start** (`startImmediately: false`, so restored tabs spawn a shell only when viewed). Pure AppKit, no SwiftUI bridge for the terminal.

Flow's glue is the more complete one and is what Ghostty's own keybinds expect.

### b. Tabs, splits, workspaces

**Enso:** `TerminalSessionStore` (2,115 lines, `ObservableObject`). "Spaces" are curated collections: pinned sessions, nested folders, ephemeral sessions that expire after 24 h, sleep/wake, MRU recency, multi-select, drag-drop reordering. No notion of a project directory as the unit. Splits are `SplitContainer`s (a `SplitNode` tree over session ids) stored beside the sessions. Everything is `@Published` on one store; the sidebar re-renders on every change.

**Flow:** `Sources/Workspace/` is a small generic model: `WorkspaceStoreModel<Leaf>` → `WorkspaceModel` (one per directory; named after the git repo) → `TabModel` → `PaneTreeModel` (binary split tree with ratio, zoom, spatial neighbor navigation). Generic over `PaneLeaf` so 350+ lines of tests run without terminals. The window (`TerminalWindow`) owns a store; the sidebar lists workspaces; a tab bar appears when a workspace has more than one tab. Workspace order is draggable. ⌘1–9 switch workspaces.

Flow's model is exactly the one you asked for.

### c. Persistence

**Enso:** `state.json` saved from the store; sleeping tabs record their last `TabProcess`; agent conversations resume through the shim-recorded session ids. Three build identities keep separate folders (Dev / Next / stable).

**Flow:** `Session` is a `Codable` snapshot of windows → workspaces → tabs → layout tree with working directories; written on a utility queue, debounced 1 s, deduplicated. Restored terminals start when viewed. Debug builds use a `flow-debug` folder.

Both match what is on disk. Flow's is ~190 lines and tested.

### d. Building GhosttyKit

**Enso:** README-only. You clone Ghostty beside the repo, run `zig build -Doptimize=ReleaseFast -Demit-macos-app=false`, and symlink `macos/GhosttyKit.xcframework` into the Xcode project. The pbxproj references the xcframework. No version pin in the repo.

**Flow:** `Vendor/ghostty` is a git submodule pinned to a tag. `scripts/build-ghosttykit.sh` runs the Zig build (`-Dapp-runtime=none -Demit-xcframework=true -Dsentry=false -Di18n=false`), copies the xcframework, terminfo and `share/ghostty` into `Vendor/`, runs `ranlib`, and writes a stamp with the commit. `project.yml` (xcodegen) links `Vendor/GhosttyKit.xcframework`. A Ghostty bump is: move the submodule, rerun the script, rebuild. The Xcode project is generated, so there is no pbxproj to hand-edit.

Flow's is the "no surgery" path you asked for.

### e. Ghostty version

Enso 1.3.1 (unpinned; the binary's string). Flow 1.4.0 (pinned). Ghostty.app on your Mac is 1.4.0.

### f. Flow's agent detection and notifications, end to end

1. `AppDelegate` starts `AgentSocketListener` on `~/Library/Application Support/flow/agent.<pid>.sock`.
2. Every surface spawns with `FLOW_SURFACE_ID`, `FLOW_WORKSPACE_ID`, `FLOW_SOCKET`, `FLOW_FLW` (path to the helper inside the bundle), `FLOW_SHIMS` (temp dir). `ShellIntegration` sets `ZDOTDIR` / `XDG_DATA_DIRS` at the app level so libghostty's own integration still runs.
3. At the first prompt, the shell integration runs `flw shims <dir>` which writes `claude`, `codex`, `opencode` scripts into a per-terminal dir and prepends it to PATH.
4. Typing `claude` runs the shim → `flw launch claude` → `AgentLauncher` finds the real binary past the shim dir and execs it with `--settings` JSON adding hooks (`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Notification`, `Stop`, `StopFailure`, `SessionEnd`) that each run `flw hook claude`. A user `--settings` is merged, not shadowed.
5. Each hook invocation reads the JSON on stdin, `ClaudeCode.translate` maps it to an `AgentEvent` (`sessionStarted`, `turnStarted`, `working`, `needsInput`, `turnEnded`, `sessionEnded`, `attention`), and `flw` writes one line to the socket with a 300 ms deadline so a dead app never blocks the agent.
6. `AgentSessionStore.apply` folds events into a per-surface `Session` (`idle | working | waiting | ended`, plus `finishedUnseen`), ordered by timestamp since hooks race. `AgentIndicator` reduces to `working` (blue pulsing) / `waiting` (yellow) / `done` (green, cleared when you look).
7. `AppDelegate.notify` posts a `UNUserNotification` when the terminal is not in view (click focuses it) and plays a configurable sound. Looking at the terminal (`markSeenIfInView`) clears the dot and removes delivered notifications.

Codex uses `-c` overrides and OSC 9 notifications for "waiting" (Codex's own hook can't tell). OpenCode gets a bundled plugin. All three adapters live in `Sources/Agent/Shared/Adapters/` and are unit tested.

## Enso: what is visual, what is logic

- **Tab process icon** — logic, two sources. (1) `TabProcess.detect(after:title:)` is a pure 150-line function over shell-integration title events: first word of the title against a command table (claude, codex, vim, ssh, git, node, docker…), path-shaped titles mean idle. (2) `ForegroundProcessResolver` (307 lines) walks the process table from a per-tab env marker, finds the shell pid, reads its foreground process group and unwraps interpreters and wrapper scripts. This is the ground truth that sees through aliases. Both are standalone and portable; neither depends on Enso's store.
- **Agent icons** — assets (Claude, Codex, Gemini, Ollama, OpenCode SVGs in light/dark/tinted variants) plus a `RowProcessBadge` view. Portable, but the Claude/Codex marks are their owners' trademarks; Flow ships its own set in `Assets.xcassets/Agents/`.
- **Command palette** (`CommandCenter`, 1,194 lines) — mostly view and a fuzzy-search model over tabs, spaces and commands. Flow has a smaller palette (places / agents modes with pane-layout previews). The look is portable; the content comes from whichever model you keep.
- **Sidebar** (2,702 lines SwiftUI) — almost entirely view, tied to Enso's spaces/folders/pin model. The *look* (frosted sidebar, inset terminal card with concentric corner radius, hover washes, `Theme.ink` light/dark tokens, pane cards with headers) is what you want; the structure is not.
- **Tab switcher** (⌃Tab HUD), **auto-naming** (`TabAutoNamer` reads screen text), **sleep/wake**, **24 h expiry**, **agent resume via session ids** — all logic you said you don't need.
- **AppTheme** (204 lines) — a clean set of dynamic light/dark tokens worth reproducing.

## Recommendation: **(B) fork Flow, port Enso's chrome**

| | A. Fork Enso, port Flow's model | **B. Fork Flow, port Enso's chrome** | C. Fresh on libghostty-spm |
|---|---|---|---|
| Already satisfies | Look, palette, process icons, ⌘D splits | Workspaces per directory, git branch, persistence, lazy restore, agent dots + notifications for Claude/Codex/OpenCode, full Ghostty action routing, macOS 14, Ghostty 1.4.0, scripted bump path, tests | Nothing; the spm packages (Lakr233, moreboxed) lag Ghostty (moreboxed is on 1.3.1) and you still own all the glue |
| Must add or change | Replace the spaces/pin/folder/sleep store (2.1 k lines) and the sidebar built on it (2.7 k lines) with a directory model; add git branch; route Ghostty actions the runtime ignores; drop macOS 15 → 14 (it uses macOS 26 scroll-pocket workarounds); bump Ghostty 1.3.1 → 1.4.0 | Read `~/.config/ghostty/config` instead of `~/.config/flow/config` (one function); port `TabProcess` title detection and optionally the process resolver; show icon + name on tab bar and sidebar rows; re-skin the AppKit sidebar, tab bar and terminal area to Enso's inset-card look; palette polish; new icon | Workspace/pane model, persistence, agent pipeline, all input plumbing, search, scrollbar, secure input |
| Effort (me building, you reviewing) | 5–8 sessions | **2–4 sessions** to a daily-driver, polish ongoing | 8+ sessions |
| Main risk | The model swap touches every file; easy to end up with neither app's coherence. GPL on the result. | Enso's chrome is SwiftUI; Flow's is AppKit. Matching the look means either careful AppKit styling or hosting SwiftUI rows in `NSTableView`, and hover/drag/rename interactions need re-testing. Upstream Flow merges get harder as chrome diverges (acceptable for a personal fork). | Reinventing tested code; spm package churn at every Ghostty release |
| License direction | GPL base; stays GPL | **MIT base. Porting Enso's *look* is fine; copying Enso *code* in would make a published Ombú GPL-3.** I'll rewrite rather than paste. | Clean |

Flow already is 80% of the requirement list. The gap is visual, and that is the part you'd want to own anyway. The one thing in Flow that contradicts your requirements (its own config file) is a small, deliberate change.

### What I'd keep from each

- From Flow: everything under `Sources/Workspace`, `Sources/Agent`, `Sources/Ghostty`, the session format, `scripts/build-ghosttykit.sh`, xcodegen, tests.
- From Enso: the inset terminal card on a frosted window, pane headers with process icon + title + cwd, `Theme`-style light/dark tokens, `TabProcess` detection (rewritten), the palette's row design.
- Drop from Flow for Ombú: Sparkle (no updates for a personal build), the Settings window's config writer (Ghostty's config is the source of truth; Ombú only needs a few prefs of its own).

### Your two UI notes, mapped

- ⌘T = new tab in the current workspace's directory, ⌘N = new workspace listed below the current one: Flow already does exactly this (`newTab` inherits the focused pane's cwd; `addWorkspace` inserts after the selected one).
- Drag a workspace or tab out of the sidebar into its own window: Flow supports multiple windows and workspace drag-reorder within the table, but not drag-out. It is a Phase 2 addition on top of `NSTableView` dragging (`draggingSession(_:endedAt:operation:)` outside the window → `makeWindow` + move the model). Medium effort, no architectural blocker.

## Open decisions for you (I've picked defaults for the first pass)

1. **Env var and helper names.** Flow's shells see `FLOW_SURFACE_ID`, `FLOW_FLW`, etc. and the helper is `flw`. Default: rename to `OMBU_*` and `ombu-helper` in one commit so nothing collides with a running Flow. Reversible.
2. **Keep OpenCode and Codex adapters?** Default: keep; they're small and tested.
3. **Settings window.** Default: keep a stripped version (notification sounds, sidebar) and remove the Ghostty-config editing tabs.
