# Upstream pins

What Ombú has last reviewed from each upstream. A weekly routine compares
these against the remotes and files a GitHub issue when something moved.
Update a line after incorporating (or deliberately skipping) a release.

| Upstream | Remote | Branch to watch | Last reviewed | Date |
|---|---|---|---|---|
| Ghostty | https://github.com/ghostty-org/ghostty | tags (`v*`) | v1.4.0 (83fb956) | 2026-11-05 |
| Enso | https://github.com/amanfromsolan/enso | `next` (prereleases) and `main` (stable) | v0.11.3-next.5 (d778881) | 2026-11-05 |

Ombú is a fork of Enso: `main` is Enso's `next` branch plus Ombú's own
commits, merged (never rebased) so the history stays shared. To take a new
Enso prerelease: `git fetch enso --tags && git merge vX.Y.Z-next.N`, resolve
conflicts in the files Ombú changes, build, then update the Enso row.

Ghostty is pinned as the `Vendor/ghostty` submodule; bumping it means moving
the submodule, rerunning `scripts/build-ghosttykit.sh` and rebuilding. Enso
itself tracks Ghostty's main branch, so check that every `ghostty_*` call in
`macos/Enso` exists in `Vendor/ghostty/include/ghostty.h` before bumping.

Flow (https://github.com/thetinygoat/flow) was the base of Ombú's first,
AppKit incarnation, kept on the `appkit` branch. It is no longer tracked.
