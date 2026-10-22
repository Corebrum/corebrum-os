# 0012. Node.js 26.x through nvm

Date: 2026-10-22
Status: Accepted

## Context

The desktop needs Node.js 26.x, npm, and pnpm. On 2026-10-22 the Ubuntu 26.04 archive published `nodejs` 22.22.1 and did not publish 26.x. The Node.js distribution index listed `v26.12.1` (Current), and that build reports npm 11.20.0. nvm tag `v0.40.8` points at commit `a885b885fef16fac4bc544188fb25e9e37ae83e8`. The npm registry listed `pnpm` 12.15.0 with `engines.node` of `>=18`.

nvm's own installer clones into `~/.nvm` and appends to `~/.bashrc`. Corebrum does not edit home-directory shell startup files.

## Decision

- The desktop profile installs nvm at `/usr/local/nvm` by cloning the pinned tag. It checks the tag on GitHub and the commit after clone. It does not add an apt repository.
- Before installing Node, the installer checks that `https://nodejs.org/dist/index.json` still lists a `v26.` release. `nvm install 26` then installs the latest 26.x. npm is the npm shipped inside that Node build.
- When any Node 26.x is already installed, a later desktop install leaves that build in place. When `pnpm` is already beside that Node binary, it is left in place. Otherwise the installer runs `npm install -g --allow-scripts=pnpm pnpm@12.15.0` after checking that version on the npm registry. npm 11 does not run pnpm's install scripts unless that package is named in `--allow-scripts`.
- The checkout is marked with `/usr/local/nvm/.corebrum-managed`. An existing `/usr/local/nvm` without that marker is left untouched and the install stops.
- `/etc/profile.d/corebrum-node.sh` loads nvm for bash login shells. The desktop session and `corebrum-terminal` source that file, so the Hyprland session and new terminals have `node`, `npm`, and `pnpm` on `PATH`. Kitty uses `bash --login`, so the `nvm` function is available in a Corebrum terminal. `/etc/bash.bashrc` gains a marked block for interactive bash that sources the system bashrc. The installer does not write `~/.nvm` or `~/.bashrc`.
- Desktop uninstall removes `/usr/local/nvm` only when the marker is present, removes the bashrc block, and removes the profile script. It does not remove Ubuntu's `nodejs` package, because this profile does not install it.

## Consequences

`node`, `npm`, and `pnpm` are root-owned under `/usr/local/nvm`. Another user can run them. Installing a different Node version with `nvm install` needs root. A terminal that was already open before the install does not see the new `PATH` until it is started again.
