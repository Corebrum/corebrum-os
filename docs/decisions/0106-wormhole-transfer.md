# 0106. Wormhole sends a file between Corebrum machines

Date: 2026-11-01
Status: Accepted

## Context

Corebrum machines on one desk need a way to hand a file from one to another. Ubuntu 24.04 and Ubuntu 26.04 both publish `magic-wormhole` as an architecture-independent package, so arm64 and amd64 install the same package for that release. Ubuntu 24.04 publishes 0.12.0-1.1. Ubuntu 26.04 publishes 0.18.0-1build1. Both releases provide `wormhole send` and `wormhole receive`.

## Decision

- Super+Space lists Wormhole. The row says install until `wormhole` is on `PATH`.
- Choosing it installs `magic-wormhole` from the running Ubuntu archive. A missing candidate is reported and does not add a repository.
- Send asks for a file or folder and runs `wormhole send`. The terminal keeps the short code on screen until Enter.
- Receive asks for that code, changes to `~/Downloads` when that directory exists, and runs `wormhole receive`. Wormhole still asks before it writes the file.
- The desktop profile does not preinstall the package.

## Consequences

The mailbox that carries the code can use the public relay. The file bytes go directly when the two machines can see each other. Uninstall removes the menu script and leaves the Ubuntu package installed.
