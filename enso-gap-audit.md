# Ombú vs Enso 0.11.3-next.5: gap audit

Written 2026-11-05 from a read of both codebases: Enso at tag `v0.11.3-next.5`
(the `next` branch, where Enso's real development happens; `main` has sat at
0.11.2 since 2026-09-02) and Ombú `main` at `ce868dc` plus the uncommitted
Diatype swap. Nothing here comes from running either app. Both Enso 0.11.2 and
Enso Next 0.11.3-next.5 are installed under /Applications for side-by-side
comparison.

Enso is GPL-3 and a visual reference only: port the look and the behaviour,
never the code.

## How to read this

**Status**

- **have**: Ombú does this, equivalently or better.
- **partial**: Ombú has a version of it that falls short of Enso's.
- **missing**: Enso has it, Ombú does not.
- **decide**: tied to Enso's spaces-and-folders model, which Ombú deliberately
  replaced with Flow's workspaces-with-child-tabs. Needs a yes or no from Lucas
  before it counts as a gap.
- **skip**: not wanted (dev tooling, or contradicts Ombú's rules).

**Priority** is my read of what moves Ombú toward "as polished as Enso":
P1 is what a user feels in the first minute, P2 in the first day, P3 later.

## The one structural difference

Enso shows one *space* at a time and swipes between them; inside a space, tabs
live in a tree of nested folders split into a pinned zone and a temporary zone.
Ombú shows every *workspace* at once with its tabs listed under it, Flow's
model, which Lucas has said is the thing to keep. So Enso's spaces pill,
swipe pager, Core Animation slide, folders tree, pinned/temporary zones, tab
expiry and sleeping tabs are not gaps by default. They are listed in section 8
as decisions.

Everything else in Enso sits on top of either model and is fair game.

## 1. Window and terminal card

| Area | Enso next.5 | Ombú | Status | Pri |
|---|---|---|---|---|
| Frost | `.sidebar` material behind-window plus wash | Same | have | |
| Card inset | 6pt from window, flush to sidebar | 10pt, flush to sidebar | have (deliberate 10) | |
| Card radius | Window radius minus 6, read live from the window (10 on macOS 26, 6 earlier) | Fixed 10 continuous | partial | P3 |
| Card hairline and shadow | Comments promise them, nothing draws them | 1pt ink 0.09 border, soft shadow | have (Ombú is the one that ships it) | |
| Top gutter drags window | 6pt band above the card | Not a drag handle | missing | P3 |
| Traffic lights | Lowered via empty toolbar, fade 0.15s out / 0.2s in when sidebar hidden, removed in full screen | Standard, no fade | partial | P3 |
| Title bar sidebar toggle | A "fourth light" after zoom: 13pt glyph, 26×22, 0.4 → 0.8 hover, tooltip with ⌘B | 32×28 `sidebar.left`, secondary colour, leading edge, no hover state | partial | P2 |
| Sidebar toggle animation | Slides from leading edge with opacity, spring 0.28s bounce 0.12 | None; terminal column jumps | missing | P1 |
| Sidebar edge peek | Hidden sidebar reveals on a 12pt left strip after 0.15s dwell, spring 0.24s | None | missing | P2 |
| Sidebar resize handle | 6pt grab strip, 3pt capsule ink 0.22 on hover, double-click resets to 248 | 6pt handle with cursor only | partial | P2 |
| Inactive-window dim | Chrome drops to saturation 0, opacity 0.6 when window is not key | None | missing | P2 |
| Header strip | 40pt, collapses under 80pt pane height; compact variant under 500pt wide | 46pt fixed, one variant | partial | P3 |
| Header badge | Agents 24pt art, tools SF 13 medium ink 0.6, idle glyph ink 0.5 | 20×20 icon, symbol 14 medium, text 0.6 | have | |
| Breadcrumb | `house.fill` root, chevron separators, collapses over 3 components to "… › a › b", ink 0.28 / 0.42 last / 0.18 chevrons | `~ › Developer › ombu` plain text, text 0.5, no collapse | partial | P2 |
| Header controls | Split Right, Split Down, Close Pane buttons; idle fade to 0.12 after 1.8s; `⋯` overflow when narrow | None; header is not clickable | missing | P2 |
| Header control tooltips | Custom panel with keycaps, 0.4s delay, instant neighbour swap | n/a | missing (with the above) | P3 |
| Header rename | Double-click title renames inline | Only via ⌘T Rename Tab | missing | P2 |
| Per-pane headers in splits | Each pane is its own card with its own header | One header per tab; panes dim instead | missing (already on the known list) | P2 |
| Focused pane ring | Accent ring at 0.7, 6pt | None | missing | P2 |
| Unfocused panes | Scrim at 0.25 in theme background, header faded to 0.55, 0.1s transitions | Dim from Ghostty's `unfocused-split-opacity`, no transition | have (different source, same effect) | |
| Split divider | 8pt gap, three-dot hover affordance, accent seam, double-click to 50/50, min pane 160 | Thin NSSplitView divider, white 12% overlay even on light themes, min 80 | partial | P2 |
| Empty state | "No Tabs" with "Press ⌘T to open a new tab." (forced dark) | Same copy, follows appearance | have | |
| Find bar | Per pane, material radius 8, 22pt circle buttons, "N of M", debounce 300ms under 3 chars | Per pane, `windowBackgroundColor` radius 10, 24×26 buttons, "n/total", same debounce | have (restyle to Enso's look is P3) | P3 |
| Ctrl-Tab dim | Terminal dims black 0.35 under the HUD | n/a | missing (with Ctrl-Tab) | |

## 2. Sidebar rows and chrome

| Area | Enso next.5 | Ombú | Status | Pri |
|---|---|---|---|---|
| Width | 248 default, 200–360, persisted | 248 default, 200–400, persisted | have | |
| Row size | 24pt content box, 32pt row, 4pt gap above each | Workspace 50, tab 32, no gap | have | |
| Row title | 13 regular, tracking 0.25, 0.95 / 0.62 | 14 regular, 0.95 / 0.62 (14 medium for workspace) | have (Lucas chose 14 in ce868dc) | |
| Selected row | Radius 7; light: solid white; dark: white 0.14 with two soft shadows | Radius 7, ink 0.10 pill | partial | P2 |
| Hover row | ink 0.05 | ink 0.06 | have | |
| Press feedback | Scale 0.98 while pressed, snappy 0.12s | None | missing | P1 |
| Badge slot | 16pt: sleeping moon / process badge / dormant moon / naming spinner / idle glyph | Agent art, tool symbol, or `terminal` | have (sleep and naming states are model decisions) | |
| Process badge | Agents 16pt art 1 / 0.8; tools SF 10 semibold 0.8 / 0.55; unknown live process blue idle glyph | Agents art; tools SF 11 medium ink 0.85 / 0.4; unknown shows `terminal` | partial: no "unknown live process" state | P3 |
| Attention dot | Orange 6pt, 5pt trailing, hidden on hover | 8pt blue / yellow / green with pulse, hidden on hover | have (Ombú's three-state dot is richer) | |
| Hover button | 24pt, glyph 10 bold, tint 0.5, wash 0.09; − for sleep, × for close | 9pt xmark, secondary colour, no wash | partial | P2 |
| Workspace row hover | n/a (spaces are a pill) | + and × at trailing | have | |
| Double-click rename | On title text, tabs and folders | None (⇧⌘R, menu, or ⌘T) | missing | P1 |
| Inline rename | Return commits, Esc cancels, click-away commits, focus back to terminal | Same | have | |
| Click modifiers | ⌘-click multi-select, ⇧-click range | None | decide (bulk actions need multi-select) | P3 |
| Tab context menu | New Folder with N Tabs, Move to Folder, Move to Space, Pin, Rename, Sleep, Wake, Close | Close Tab only | partial: add Rename Tab, Move to Workspace, Duplicate, Close Others | P1 |
| Keyboard navigation | None in the sidebar either | None | have (parity) | |
| Structure animation | Snappy 0.22s on add / remove / reorder | Explicitly not animated | missing | P1 |
| Drag preview | Translucent pill 0.45, "N tabs" | Vector snapshot on a card (workspace), default image (tab) | partial | P3 |
| Drop indicator | 7pt accent ring plus 2pt line, inset 4, at target depth | None drawn; drop is top-half / bottom-half only | missing | P2 |
| Edge auto-scroll while dragging | 24pt zone, speed by depth | None | missing | P3 |
| Cancelled drag detection | Mouse-button poll | n/a | skip | |
| Tab drag across workspaces | Any tab drops anywhere | Clamped to its own workspace; ⌘T "Move Tab to…" instead | missing | P1 |
| Tab detach to new window | n/a (Enso has no multi-window) | Workspaces detach, tabs do not | have for workspaces; tab detach is Ombú's own idea | P3 |
| New Terminal row | Plus 11 semibold, label 13, 0.45 → 0.7 on hover, hover wash | Hairline, plus 11 medium, label 14 at 0.45, pill on hover | have | |
| Scroll edge effect | Hidden | Default | partial | P3 |
| Bottom bar | Liquid glass spaces pill plus 32pt plus button | n/a | decide (spaces model) | |
| Space name button and menu | Semibold 13, chevron, menu with spaces / New / Rename / Edit Icon / Delete | n/a; workspaces are rows | decide | |
| Space icons and editor | 84pt icon disc, shuffle, 185 symbols + 1,870 emoji, modal with spring pop | None; workspaces have no icon | decide: a workspace icon is cheap and would carry over | P3 |

## 3. Palettes

| Area | Enso next.5 | Ombú ⌘T | Ombú ⌘P / ⌘I | Status | Pri |
|---|---|---|---|---|---|
| Surface | `.hudWindow` blur, radius 14, gradient card, two shadows, hollow 3pt ring, back slab | Solid panel, radius 14, ink 0.15 border, one shadow | `.popover` blur, radius 14, `separatorColor` border | partial: two different looks in one app | P1 |
| Width | 560 | 600 | 720 | partial | P2 |
| Placement | Centred on terminal column, fixed top | Centred on terminal column, top 18% | Centred on window, top 72 | partial | P2 |
| Backdrop | Invisible scrim | Black 20% | None | partial | P2 |
| Field | 16 regular ink 0.92, 14pt glyph ink 0.4, padding 20×15 | 18, 17pt glyph | 20, 18pt glyph | partial | P2 |
| Row | Title 14 at 0.98 / 0.85, kind label 0.28, context 12 at 0.5 / 0.38, radius 7 highlight ink 0.1 | Title 16, detail 15, row 46, pill radius 11 ink 0.10 | Title 14 medium, mono 11 detail, row 50, edge-to-edge `labelColor` 0.1 | partial | P2 |
| Section header | 12 ink 0.38 | 13.5 text 0.38 | none | have | |
| Light-mode weight bump | One step heavier for all palette text | None | None | missing | P2 |
| Tracking | 0.25 throughout chrome | None | None | decide (Diatype may not want it) | P3 |
| Search | Fuzzy subsequence with word-start and consecutive bonuses; `>` prefix = commands only | All words must match, title outranks detail | Whole / prefix / substring / in-order scores | have (different, both good) | |
| ⌘1–9 runs row N | Yes | No | No | missing | P2 |
| Esc backs out of submenu / rename before closing | Yes | n/a | n/a | missing (with submenus) | P3 |
| Keys swallowed until keyUp so TUIs don't get the release | Yes | Unknown | Unknown | check | P2 |
| Recent tabs section | Up to 4 by recency | All tabs, no recency | n/a | partial | P3 |
| Commands: appearance | Toggle Light/Dark, Change Appearance submenu | None | n/a | missing | P2 |
| Commands: New Folder / New Space | Yes | New Workspace | n/a | have | |
| Commands: Auto Rename Tab | Yes | n/a | n/a | decide (needs TabAutoNamer) | |
| Commands: Pin / Sleep / Wake | Yes | n/a | n/a | decide (sleep model) | |
| Commands: Check for Updates, What's New | Yes | n/a | n/a | decide (Ombú dropped Sparkle) | |
| Palette modes | Rename inline inside the palette with "↵ Rename · esc Cancel" hint | Rename happens in the sidebar row | have (different, fine) | |
| Press-again to step | n/a | No | Yes (⌘P P, ⌘I I) | have (Ombú's own) | |
| Live preview while stepping | No | No | Yes | Ombú better | |
| Open / close animation | Modal pop: scale 0.8, blur 10, spring (0.18, bounce 0.24); scrim fade 0.16s / 0.07s | None | None | missing | P1 |

## 4. Behaviours

| Area | Enso next.5 | Ombú | Status | Pri |
|---|---|---|---|---|
| Ctrl-Tab MRU switcher | Quick tap flips to last tab; hold 0.15s shows a HUD of up to 9 by recency; split is one stop; Esc restores | None | missing | P1 |
| Shell titles | Path-shaped titles collapse to the deepest folder; home shows "Terminal"; rename pins | Full title, abbreviated cwd fallback; known truncation in narrow sidebar | partial (already on the known list) | P1 |
| Foreground process detection | `ENSO_TAB_ID` per surface, process table walk 0.5s after title events, unwraps interpreters and wrappers | Title first word, plus hook-reported agent | partial (already on the known list: catches aliases like `c` for `claude`) | P2 |
| LLM tab naming | Names a tab once, 6s after activity, via `claude -p --model haiku` / Codex / Gemini; redacts secrets; never overrides a rename | None | decide (costs tokens; Lucas's call) | P3 |
| Agent detection | Shims in App Support, hooks via `--settings`, JSONL tail at 1s | Per-terminal shims, hooks via `--settings` and `-c`, Unix socket, no polling | Ombú better | |
| Agent states | Attention (needs input / finished) | Working, waiting, done, idle, ended | Ombú better | |
| Agent notifications | One banner per tab, click reveals, default sound, "only when unfocused" toggle | One per terminal per kind, click reveals, own sounds with picker, in-view terminals silent | have | |
| Attention clears on | Selecting the tab; app activation clears selected | Key press in view, activation, focus | have | |
| Quit guard | Alert names session count; ⌘Q again confirms | "Quit Ombú?" when libghostty says something runs | have (add ⌘Q-again: P3) | P3 |
| Close confirmation | Only with something to lose; names the agent; "Don't ask me again" | Only when a pane needs confirmation; no agent name; no suppression | partial | P2 |
| Sleep confirmation | When an agent looks busy | n/a | decide (sleep model) | |
| Agent session resume | Claude `--session-id` resume unless ended cleanly; Codex quit-snapshot gating; wake policy with budget | None; restored tabs spawn a fresh shell | decide (big feature, big value: Lucas's call) | P2 |
| Sparkle updates, update card, What's New sheet, release notes parser | Full own-UI pipeline | None (Flow's Sparkle removed) | decide: a personal build does not need it | |
| Multi-window | No | Yes, with workspace detach | Ombú better | |
| Session restore | state.json, lazy wake | session.json, lazy start, off-screen refit | have | |
| Finder service | "New Enso Terminal Here" | "New Ombú Workspace Here" and "… Window Here" | have | |
| Dock menu, folders on Dock | None | New Window; folders open as workspaces | Ombú better | |
| Appearance pinning | System / Light / Dark via `NSApp.appearance`, Toggle command | Follows terminal background luminance | partial | P2 |
| Font smoothing setting | `AppleFontSmoothing` 0 / 2, forced off once | None | decide (Diatype may want it off) | P3 |
| Reduce Motion | Honoured on thumb and slide | Honoured on the agent dot pulse | have (keep honouring it as motion is added) | |

## 5. Ghostty integration

| Area | Enso next.5 | Ombú | Status | Pri |
|---|---|---|---|---|
| Actions handled | 9 (title, pwd, quit, mouse shape, open url, search ×4) | ~35 including splits, tabs, config reload, notifications, secure input, scrollbar, command finish | Ombú better | |
| Occlusion | `ghostty_surface_set_occlusion` on window enter / leave / occlusion change / creation; hidden surfaces free GPU buffers; ~70% less memory with 64 tabs | "Hidden surfaces stop rendering" (TerminalSurfaceView.swift:293-299) | check: confirm Ombú calls `set_occlusion` for off-screen tabs and occluded windows, not only hidden views | P1 |
| Surface reuse | One live surface per session, reattached on switch | One surface per terminal, lives in the pane tree | have | |
| Deferred start | Sleeping panes mount nothing | `defersStart`, "Starts when chosen" | have | |
| Config | Reads user config, retries with defaults if broken | Reads the same files Ghostty.app does, lists problems in Settings | Ombú better | |
| Environment hygiene | Unsets `CLAUDECODE`, `CODEX_SANDBOX`, own vars | Sets `OMBU_*`; unknown whether it unsets inherited `CLAUDECODE` and `GHOSTTY_*` | check | P2 |
| Precise scroll multiplier | 2× with momentum bits | Default | check | P3 |
| Clipboard confirmation | Auto-confirmed | Asks (SwiftUI sheet) | Ombú safer | |
| Theme following | n/a | `ghostty_app_set_color_scheme` | have | |

## 6. Settings

| Setting | Enso | Ombú | Status |
|---|---|---|---|
| Confirm before closing tabs | yes, default on | always on, no toggle | partial (P3) |
| Agent notifications on / only when unfocused | yes | per-kind toggles, sounds | have |
| Automatic updates | Sparkle | n/a | decide |
| Theme System / Light / Dark | yes | no | partial (P2, with appearance pinning) |
| Font smoothing | yes | no | decide |
| Tab naming | yes | no | decide |
| Close unpinned tabs after N hours | yes | no | decide (model) |
| Resume agents / wake policy / recent count | yes | no | decide |
| Keyboard pane | read-only list, stale | Keyboard Shortcuts window, accurate | Ombú better |
| Restore previous session, New tabs open in | saved, never read | n/a | skip (dead in Enso) |

## 7. Keyboard shortcuts worth adopting

| Enso | Ombú today | Note |
|---|---|---|
| Ctrl-Tab / Ctrl-⇧-Tab | none | with the MRU switcher |
| ⌘R rename tab | none (⇧⌘R renames workspace) | ⌘R is free in Ombú |
| ⇧⌘P palette in command mode | none | cheap: ⌘T with a `>` prefix |
| ⇧⌘F hide find bar | Esc only | cheap |
| ⌘1–9 inside the palette | none | cheap |
| ⌘S toggle sidebar | ⌘B | keep ⌘B |

Everything Ombú adds must be listed in `KeyboardShortcuts.all` (CLAUDE.md rule 5).

## 8. Decisions for Lucas (model-dependent)

These are Enso's biggest next.5 features. Each either conflicts with the
Flow model or is a sizeable feature in its own right.

1. **Folders inside a workspace** (nested, drag right to nest, collapse). Would
   sit under a workspace row in Ombú's list. Enso's headline redesign.
2. **Pinned vs temporary tabs with expiry** (24h default). A keep/throw-away
   distinction inside each workspace.
3. **Sleeping tabs** that free the shell but keep the row, with agent
   conversation resume on wake. Needs the Claude `--session-id` and Codex
   quit-snapshot machinery.
4. **Active view**: a flat list of tabs needing attention, then running ones,
   toggled from the top-right capsule. In Ombú this could be a filter on the
   existing list, or ⌘I already covers most of it.
5. **LLM tab naming.** Spends Haiku tokens on every new tab.
6. **Workspace icons** (symbol or emoji) and an editor modal. Cheap, visual.
7. **Space switching by swipe with a Core Animation pager.** Does not map onto
   a list of all workspaces; skip unless the model changes.
8. **Sparkle / What's New.** Not needed for a personal build.

## 9. Ombú's own debts (from the Ombú inventory, not Enso)

- `ClipboardConfirmation.swift` is SwiftUI outside Settings, against the repo
  rule. Port to AppKit.
- CLAUDE.md rule 5 refers to a title-bar ? button that no longer exists; the
  Keyboard Shortcuts window is reachable only from ⌘T. Fix the rule or add a
  menu item under Help.
- Split divider paints white at 12% on every theme (PaneTreeView.swift:105);
  use `Theme.ink`.
- ⌘T and ⌘P / ⌘I are two different palettes visually (section 3). Pick one
  surface and apply it to both.
- Dead code: `onNewWorkspace`, `TerminalWindow.newTab(nextTo:)`,
  `GhosttyConfig.palette`, `GhosttyConfig.backgroundBlur`.
- Leftover "Flow" names: data folder `~/Library/Application Support/flow`,
  socket names, `flow-pasted-images`, logger category, shell functions
  `__flow_agents_init` and `_flow_file`, the OpenCode plugin export `Flow`,
  "no Flow is running" in the helper, ~150 comments. Renaming the data folder
  needs a one-time migration of session.json.
- Unused bundled assets: `gemini` and `ollama` agent art; Gemini uses the SF
  `sparkle` symbol, nothing detects ollama.
- General settings footer hardcodes `~/.config/ghostty/config` while the real
  lookup honours `XDG_CONFIG_HOME`.
- Empty-state copy says ⌘T opens a new tab; it opens the command center
  (Enso has the same wording bug).
- No Help menu.
- Negative `background-blur` glass styles are unsupported.

## 10. Proposed worklist, in order

Each line is one brief for the router. Visual ones end with a screenshot for
Lucas.

**P1: the first minute**

1. Motion pass on the sidebar: press scale 0.98 (snappy 0.12s), structure
   changes animate (0.22s), sidebar toggle slides (spring 0.28s, bounce 0.12),
   all honouring Reduce Motion.
2. Palette unification: one surface for ⌘T / ⌘P / ⌘I (Enso's `.hudWindow`
   blur, radius 14, ink 0.1 highlight, 560 wide, fixed top), open/close pop
   (scale 0.8, blur 10, spring 0.18 bounce 0.24, scrim 0.16s / 0.07s).
3. Tab row context menu: Rename Tab, Duplicate, Close Others, Move to
   Workspace, Copy Working Directory, Open in Finder. Double-click to rename.
4. Tab drag across workspaces, with Enso's ring-and-line drop indicator.
5. Ctrl-Tab MRU switcher with HUD and terminal dim.
6. Shell title collapsing (deepest folder; home shows "Terminal").
7. Occlusion check: confirm `ghostty_surface_set_occlusion` is sent for
   non-visible tabs and occluded windows.

**P2: the first day**

8. Pane headers: per-pane cards in splits, Split Right / Split Down / Close
   buttons with idle fade and tooltips, focused ring, double-click rename.
9. Breadcrumb with root glyph, chevron separators and "…" collapse.
10. Split divider: 8pt gap, hover dots, double-click to 50/50, theme-aware
    colour.
11. Inactive-window dim; sidebar edge peek; resize handle capsule with
    double-click reset.
12. Appearance: System / Light / Dark setting, Toggle command, light-mode
    weight bump for chrome text.
13. Selected row: Enso's white 0.14 (dark) / solid white (light) with soft
    shadows; hover button 24pt with wash.
14. Close confirmation names the agent and offers "Don't ask again".
15. Environment hygiene check (`CLAUDECODE`, `GHOSTTY_*` unset in child
    shells).
16. ⇧⌘P command mode, ⌘1–9 in the palette, ⇧⌘F hide find bar, ⌘R rename tab.

**P3: later**

17. Card radius read from the window; traffic-light fade; top-gutter drag.
18. Header compact variant and collapse under 80pt.
19. Find bar restyle; scroll edge effect hidden; drag preview pill.
20. Workspace icons (if decided).
21. The debts in section 9, starting with the SwiftUI sheet and the Flow
    leftovers.

## Not audited

Enso's dev-only tooling (Perf Bar, Space Switch Test, Swipe Tuner), its
website and lab experiments, and its channel/icon plumbing (Dev / Next /
stable App Support folders).
