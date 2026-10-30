# 0058. Phase 12 remote access is SSH, tmux, and wayvnc

Date: 2026-10-26
Status: Accepted

## Context

Phase 12 asks for SSH, a session that survives a disconnect, Wayland remote desktop, and Corebrum Synapse connectivity from another network. The desktop already has a Remote desktop menu. See `docs/decisions/0027-vnc-menu.md`.

## Decision

- OpenSSH is not in the base package list. `corebrum install` with `--enable-ssh` installs `openssh-server` and runs `systemctl enable --now ssh`. Corebrum does not rewrite `sshd_config`. On 2026-10-26 the `ssh` service on this machine was active.
- The base profile installs Ubuntu `tmux`. A detached tmux session keeps running when the SSH client disconnects. Corebrum does not add a separate session manager.
- Graphical access is Super+Space Remote desktop. `wayvnc` is not preinstalled and does not start at login. Start listens on port 5900 only after the operator chooses it. `corebrum-vnc-proxy` checks the session password before a client reaches the desktop. The server was not started during this close.
- Screen capture for `synapse desktop` stays on `xdg-desktop-portal-wlr`. That portal is not a remote-control service.
- Corebrum Synapse stays in local mode on this machine. WebRTC and NAT traversal are not part of this phase.

## Consequences

A viewer uses the address and password the menu prints. Nothing listens on port 5900 until Start. A VNC client that does not have the password does not reach the desktop.
