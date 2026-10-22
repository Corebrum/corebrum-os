# 0004. Version pins

Date: 2026-10-22
Status: Accepted

## Context

Robotics stacks break when a desktop update changes middleware. Corebrum will eventually update the desktop, ROS 2, and AI tools on separate channels. Those channels need a place to record constraints before any of them are installed.

## Decision

Package names live in `manifests/packages/<component>.txt`. Constraints live in `manifests/versions/<component>.txt` as `key: value` records with `component`, `ubuntu`, `arch`, `source`, `packages`, and `pin`. The format is described in `manifests/versions/README.md`.

The base component is pinned to the Ubuntu 24.04 archive at install time. It does not add third-party repositories and does not freeze individual `.deb` versions. Later robotics manifests must name the repository and the distro pin, including Zenoh RMW, before their installer is written.

## Consequences

Phase 1 has a single versions file, `manifests/versions/base.txt`. Shell scripts read the package list, not the versions file. The versions file is the human-readable constraint record.
