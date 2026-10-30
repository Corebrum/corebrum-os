# 0077. Getting Started is the Firefox homepage

Date: 2026-10-27
Status: Accepted

## Context

An operator opening Firefox should land on a short guide to Corebrum OS: Physical AI, the desktop, ROS 2, Zenoh, RealSense, Corebrum Synapse, the AI agents, keybindings, and the `corebrum` and `synapse` commands. Firefox is the desktop browser. The desktop profile already installs it, and Super+Shift+Return launches it. Chromium stays the optional Super+Space install.

The Firefox snap cannot open `/usr/share/corebrum` as a `file://` page. It can read `/etc/firefox` for policy, and it can open a page on `127.0.0.1`. The desktop profile already installs Node.js 26.x under `/usr/local/nvm`.

## Decision

- Getting Started is one HTML file per section under `config/getting-started/`, copied to `/usr/share/corebrum/getting-started/`. The sidebar lives in `nav.html`. The Node server inserts it and marks the current page. The sidebar shows `/usr/share/corebrum/logo.png`. ROS, Zenoh, RealSense, Corebrum Synapse, AI Agents, and Ollama use the marks already installed beside that logo. The welcome page lists the agent marks from corebrum.com under those tool marks. Ollama stays in the tool row. Those files live in `config/brand/agents/` and are copied to `/usr/share/corebrum/agents/`.
- `corebrum-getting-started.service` listens on `127.0.0.1:8765` and serves `/usr/share/corebrum`. The server is Node's `http` module. It does not install an npm package. The unit runs as `nobody` and finds Node 26 through `corebrum-node-path.sh`. The desktop phase starts it after Node is installed.
- `/etc/firefox/policies/policies.json` sets the homepage to `http://127.0.0.1:8765/getting-started/` with `Locked` false and `StartPage` `homepage`. Firefox settings can replace it. Super+Shift+Return stays `firefox` with no URL.
- This change does not install Chromium and does not write a Chromium policy.
- The pages do not include a chat panel.
- A change that adds or changes an operator-facing desktop feature, a shortcut in `scripts/desktop/corebrum-keys-menu.sh`, or a `corebrum` or `synapse` command the operator runs, updates the matching page in that same change. A new section also adds its link to `nav.html`.

## Consequences

The next desktop install copies the pages, writes the Firefox policy, and starts the loopback server. A later desktop install refreshes those Corebrum-owned files. An existing Firefox homepage is replaced once by the unlocked policy; a homepage the operator sets after that stays. Opening Firefox on a desktop machine shows the welcome page, and Firefox settings can point the homepage somewhere else. The unit tests in this checkout do not launch the Firefox snap.
