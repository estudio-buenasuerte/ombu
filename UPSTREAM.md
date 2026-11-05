# Upstream pins

What Ombú has last reviewed from each upstream. A weekly routine compares
these against the remotes and files a GitHub issue when something moved.
Update a line after incorporating (or deliberately skipping) a release.

| Upstream | Remote | Branch to watch | Last reviewed | Date |
|---|---|---|---|---|
| Ghostty | https://github.com/ghostty-org/ghostty | tags (`v*`) | v1.4.0 (83fb956) | 2026-11-05 |
| Flow | https://github.com/thetinygoat/flow | `main` and tags | 7e9c82e (v0.5.0-rc.3) | 2026-11-05 |
| Enso | https://github.com/amanfromsolan/enso | `next` (prereleases) and `main` (stable) | v0.11.3-next.5 (d778881) | 2026-11-05 |

Ghostty is also pinned as the `Vendor/ghostty` submodule; bumping it means
moving the submodule, rerunning `scripts/build-ghosttykit.sh` and rebuilding.
Flow and Enso are visual and behavioural references only (Enso is GPL-3:
port the look, never the code).
