# 0016. AI Agents install from the Super+Space menu

Date: 2026-10-22
Status: Accepted

## Context

The desktop can already install ROS tools, RealSense, and Chromium from Super+Space. The operator asked for the same pattern for these agent CLIs. Gemini CLI was removed after an individual sign-in failed. On June 18, 2026 Google stopped serving Gemini CLI for Gemini Code Assist individuals, Google AI Pro, and Google AI Ultra. Antigravity CLI is the replacement. Gemini Code Assist Standard and Enterprise licenses still use the `gemini` command, and that path is not on this menu. None of them are Ubuntu archive packages. On 2026-10-22 their publishers documented these Linux installs:

| Menu name | Command | Install |
| --- | --- | --- |
| Antigravity CLI | `agy` | `https://antigravity.google/cli/install.sh` into `~/.local/bin` |
| Claude Code CLI | `claude` | `https://claude.ai/install.sh` as the user, not with sudo |
| Codex CLI | `codex` | `https://chatgpt.com/codex/install.sh` into `~/.local/bin` |
| Cursor CLI | `agent` | `https://cursor.com/install` into `~/.local/bin` |
| Grok CLI | `grok` | npm `@xai-official/grok` 1.0.67 |
| Hermes CLI | `hermes` | `https://hermes-agent.nousresearch.com/install.sh` into `~/.local/bin` |
| OpenClaw | `openclaw` | npm `openclaw` 2026.10.6, which requires Node 26.12.1 or another current Node 26 |

The system Node is 26.12.1 under `/usr/local/nvm`, and that prefix is root-owned. `~/.local/bin` is already on this user's PATH. Grok's shell installer also links `~/.local/bin/agent`, which is the Cursor CLI command. The npm package publishes `grok` only.

## Decision

- Super+Space shows `AI Agents`. The submenu lists these CLIs. A missing CLI is labeled `install`. Choosing it runs that publisher's installer in a terminal. Choosing an installed CLI launches it in a terminal.
- Script installers run as the logged-in user. npm installers use `sudo` with the system `npm` and `--allow-scripts` for that package. `sudo` does not keep the nvm directory on `PATH`, and `npm` starts with `#!/usr/bin/env node`, so the installer runs that `node` binary by path and puts its directory on `PATH` for the package scripts. Grok uses the npm package so its installer does not replace Cursor's `agent` command.
- Cursor counts as installed only when `agent` resolves to a `cursor-agent` binary. The desktop profile does not install any of these CLIs. The menu does not write `~/.config` itself. A vendor installer may still update that user's shell profile when its own script does so.

## Consequences

The first launch of an agent still asks that vendor for a login. A second desktop install does not remove CLIs that were installed from the menu. Uninstall removes the menu script and `/etc/corebrum/agents.conf`. It leaves `~/.local/bin` and the npm packages in place.
