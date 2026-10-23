# 0033. Zenoh fleet is a Super+Space install

Date: 2026-10-23
Status: Accepted

## Context

The operator asked to add the Zenoh network configuration tool from `https://github.com/agenticros/zenoh-fleet`. That repository publishes the npm package `@agenticros/zenoh-fleet`. On 2026-10-23 the registry listed 0.1.4 as the current version. The package needs Node.js 20 or newer, which the desktop profile already installs. Its command is `zenoh-fleet`. With no arguments it runs an enter-to-accept wizard and writes fleet files in the current directory. It does not install `zenohd` and it does not edit the running router.

`corebrum install ros` still runs one `rmw_zenohd` on `tcp/[::]:7447`. A hub file from this wizard is `zenohd.json5` for Eclipse `zenohd`, which this OS does not install. A member file can include `rmw-zenoh-session.json5` when that integration is selected. Neither file is applied by the menu.

## Decision

- Super+Space shows `Zenoh fleet   install` until `zenoh-fleet` is on `PATH`. The desktop profile does not install the package.
- Choosing it runs `npm install -g --allow-scripts=@agenticros/zenoh-fleet @agenticros/zenoh-fleet@0.1.4` with the desktop Node.js. sudo does not see nvm, so the command names that `node` and `npm` the same way the agent menu does.
- After the command is present, the same entry runs `zenoh-fleet` in a terminal whose working directory is the home directory. The default output is `~/local-fleet/`. The terminal stays open so the deploy notes remain readable.
- The menu does not restart `corebrum-zenoh-router.service`, write `/etc/corebrum`, or install `zenohd`. `Zenoh network` still runs `zenoh network` against the existing router.
- Uninstalling Corebrum removes the menu command and leaves the npm package and any fleet directory in place.

## Consequences

- A later desktop install is required before Super+Space shows the entry.
- Generated hub instructions tell the operator to start `zenohd`. Doing that beside `rmw_zenohd` would be a second router. The existing router stays the one ROS uses.
