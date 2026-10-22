# 0003. Configuration ownership

Date: 2026-10-22
Status: Accepted

## Context

Installers that copy dotfiles over an existing home directory destroy user changes. Omarchy can resync a home directory back to shipped defaults. Corebrum needs the opposite default for machines that already have users.

## Decision

- System state that Corebrum owns lives under `/etc/corebrum`.
- Install logs and file backups live under `/var/log/corebrum`.
- User configuration lives under `~/.config/corebrum` once a desktop phase exists.
- Before a script modifies an existing file, it copies that file into `/var/log/corebrum/backups`.
- Phase 1 does not write user dotfiles. It generates the `en_US.UTF-8` locale without removing other locales, and it sets `LANG` only when `/etc/default/locale` has no `LANG`.
- There is no command that resets a home directory to factory defaults.

## Consequences

A second base install is a no-op when the locale is already generated, NTP is already on, and the packages are already installed. Removal of the base profile is intentionally unsupported: those packages belong to Ubuntu. `scripts/uninstall.sh` refuses to remove them.
