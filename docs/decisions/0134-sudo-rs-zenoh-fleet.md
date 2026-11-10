# 0134. Zenoh fleet sudoers without requiretty

Date: 2026-11-10
Status: Accepted

## Context

`corebrum install ros` installs `/etc/sudoers.d/corebrum-zenoh-fleet` so desktop users in `sudo` can run `sudo corebrum zenoh fleet sync` without a password. The snippet used OpenSSH sudo’s `Defaults!/usr/local/bin/corebrum !requiretty` so login-time fleet sync could run without a TTY.

Ubuntu 26.04 ships `sudo-rs`, which does not implement `requiretty`. Every `sudo corebrum zenoh fleet sync` printed a parse warning on line 2 even when the command succeeded.

## Decision

- Drop the `Defaults … !requiretty` line from `config/sudoers.d/corebrum-zenoh-fleet`.
- Keep the two `NOPASSWD` rules for `corebrum zenoh fleet sync` and `corebrum zenoh fleet sync *`.

`sudo-rs` does not require a TTY for the fleet sync commands. Ubuntu 24.04 still uses classic sudo; omitting `requiretty` remains safe because `NOPASSWD` is scoped to the full `corebrum` path and arguments.

## Consequences

Machines already on Corebrum OS pick up the change on the next `corebrum install ros` or when an operator replaces `/etc/sudoers.d/corebrum-zenoh-fleet` from the repository copy.
