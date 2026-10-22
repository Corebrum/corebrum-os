# AGENTS.md

Instructions for coding agents working on Corebrum OS.

Corebrum OS is an open-source Ubuntu Server 24.04 environment for Physical AI. It is inspired by [Omarchy](https://github.com/omacom/omarchy) (Hyprland tiling, Quickshell menu, and app grid) and implemented with APT, not Arch or pacman. Read `COREBRUM_BUILD_PLAN.md` and `docs/decisions/` before changing the system.

## Engineering rules

1. Work on one development phase at a time. Do not start the next phase until the current phase passes its acceptance criteria.
2. Never assume that an external package, CLI, API, or GitHub repository exists without verifying it.
3. Inspect the existing repository before creating or changing files.
4. Prefer official Ubuntu and ROS 2 packages when available.
5. Use idempotent installation scripts that can safely be run multiple times.
6. Never overwrite existing user configuration without a backup or explicit permission.
7. Separate configuration, package installation, service management, and validation.
8. Do not execute destructive disk, network, or bootloader operations automatically.
9. Pin compatible robotics dependencies and document version constraints in `manifests/versions/`.
10. Run tests and document their results before marking a phase complete.
11. Record implementation decisions and deviations in `docs/decisions/`.
12. Never hardcode credentials, API keys, or secrets.
13. Support clean installation, upgrade, and removal wherever practical.
14. Prefer maintainable integrations over forks of upstream projects. Do not vendor Omarchy.
15. Do not claim success only because an installer exited successfully. Validate runtime behavior.

## Workflow

Plan, implement, test, document, review, then commit.

The root installer (`scripts/install.sh`) orchestrates phase scripts. It must support `--dry-run` before any system change. CI may run lint, unit tests, and `--dry-run` only. CI must not install Corebrum profiles onto the runner.

## Current boundary

Phase 2 is in progress: the Hyprland desktop profile. Phase 1 was reported accepted by the operator after install, validation, and reboot.

The desktop session is Hyprland dwindle tiling, Waybar, Fuzzel, and a Corebrum app grid, plus a scratchpad for an agent terminal. Quickshell is not in the Ubuntu 24.04 archive. Hyprland is installed from `ppa:cppiber/hyprland` when the Ubuntu archive has no `hyprland` package. That archive is pinned so only Hyprland and the libraries it requires come from it. See `docs/decisions/0006-hyprland-ppa.md`. Do not add any other third-party repository.

Do not install ROS 2, Zenoh, RViz, Gazebo, RealSense, AgenticROS, or Corebrum Mesh until a later phase is explicitly approved.
