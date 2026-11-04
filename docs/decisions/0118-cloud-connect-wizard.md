# 0118. Corebrum Cloud opens a connect wizard

Date: 2026-11-04
Status: Accepted

## Context

Decision 0076 and 0079 made Super+Space Corebrum Cloud open https://cloud.corebrum.com in Firefox. Online presence on the robot still needs `synapse login`, then `synapse register`, then `synapse connect`. Browser sign-in alone does not store an API token. The Synapse submenu already offered Sign in, Connect, and Disconnect, but not Register, and the Waybar Cloud chip only offered Connect and Disconnect. Operators had to remember the CLI order from Getting Started.

## Decision

- Choosing Corebrum Cloud drills into Cloud actions in the GTK launcher (`Corebrum Cloud >`), or opens a Fuzzel list when Waybar Cloud is clicked or the Fuzzel fallback runs `open`.
- The Fuzzel list starts with a local Status line. It reports Synapse not installed, needs sign-in (no `API_TOKEN` in the Synapse configstore), signed in but not connected, or connected when `synapse status` shows `comms` running. It does not print the token. When Synapse is missing, Fuzzel also offers Install Corebrum Synapse.
- Set up opens a terminal and runs `synapse login`, then `synapse register`, then `synapse connect`, then `synapse whoami`.
- Open website still runs `firefox https://cloud.corebrum.com`. The row does not call `xdg-open` and does not install a browser.
- Super+Space search lists the Cloud actions as `Cloud: …` NoDisplay rows from `corebrum-arc-menu` (`Cloud: Set up`, and so on). The Synapse menu adds Cloud: Set up and Cloud: Register and keeps the other Cloud rows. Waybar Cloud click runs `corebrum-arc-menu open`.

## Consequences

The next Super+Space after the menu script is copied can finish Sign in → Register → Connect without typing the CLI from memory. Decision 0076 still names the row and icon. Decision 0079 still requires Firefox for the website action.
