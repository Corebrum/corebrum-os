# 0103. Grok's home directory stays with the user

Date: 2026-10-30
Status: Accepted

## Context

Super+Space installs Grok with `sudo npm install -g @xai-official/grok` because the desktop Node tree under `/usr/local/nvm` is root-owned. See `docs/decisions/0016-agent-menu.md`. That package's install script writes `~/.grok` while it is root. The `grok` command later runs as the logged-in user. x.ai can authenticate the browser, and the CLI then fails with `failed to save credentials` and `permission denied (os error 13)`.

## Decision

- After a successful Grok npm install, the same command gives `~/.grok` to the user and group returned by `id -un` and `id -gn` when that directory exists.
- OpenClaw keeps the npm install without that ownership change. The other agent installers already run as the logged-in user.

## Consequences

The next Super+Space install or Updates run of Grok leaves `~/.grok` writable by the account that launched it. A directory already owned by root stays root-owned until that install runs again. The sign-in itself is still x.ai's.
