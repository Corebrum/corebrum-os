# 0001. Ubuntu Server and APT

Date: 2026-10-22
Status: Accepted

## Context

Corebrum OS needs a reproducible host for a Physical AI workstation. Omarchy, the interaction model we are following, is an Arch Linux distribution installed from an ISO and updated with pacman.

## Decision

Corebrum OS installs onto Ubuntu Server 24.04 LTS x86-64 and uses APT. It does not replace the kernel, the bootloader, or the package manager. Pacman, the AUR, Limine, and an ISO-only install path are out of scope.

The base profile installs only packages from the official Ubuntu archive. OpenSSH is optional. Networking configuration is left untouched in Phase 1.

## Consequences

Desktop and robotics packages must be available for Ubuntu 24.04, or their absence must be recorded before a phase adopts them. Arch-only Omarchy install scripts are not reused.
