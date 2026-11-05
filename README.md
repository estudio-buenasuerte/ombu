# Ombú

A personal macOS terminal built on [libghostty](https://github.com/ghostty-org/ghostty). One workspace per project folder in the sidebar, each with its own tabs and splits, restored on relaunch. Tabs show what is running in them. Claude Code, Codex and OpenCode report their status as a dot, and a notification when they need you.

Forked from [Flow](https://github.com/thetinygoat/flow) (MIT), whose workspace model, agent hooks and Ghostty glue it keeps. The look follows [Enso](https://github.com/amanfromsolan/enso).

The terminal itself is configured by `~/.config/ghostty/config`, the same file Ghostty.app reads. Ombú only adds settings for its own chrome.

## Build

Needs Xcode 27, Zig 0.17 and xcodegen (`brew install zig xcodegen`).

```sh
git clone --recursive <this repo> && cd ombu
./scripts/build-ghosttykit.sh   # builds libghostty, slow, only needed once
xcodegen generate
xcodebuild -scheme ombu -configuration Debug build
```

`Vendor/ghostty` is a git submodule pinned to a Ghostty release. `Vendor/GhosttyKit.xcframework` and `Vendor/GhosttyResources` are build outputs and aren't committed.

## Keyboard

| Shortcut | Action |
| --- | --- |
| ⌘N | New workspace, below the current one |
| ⌘T | New tab in the current workspace's directory |
| ⌘D / ⇧⌘D | Split right / down |
| ⌘1–9 | Switch workspace |
| ⌘P | Go to tab or pane |
| ⌘I | Go to agent |
| ⌘, | Settings |

Ghostty keybinds from the config file work too. The `?` button in the title bar lists everything.

## License

MIT. Flow's copyright notice is kept in `LICENSE`; third-party licenses are in `THIRD_PARTY_LICENSES.md`.
