# 0056. Phase 10 uses the agent menu and one AgenticROS call

Date: 2026-10-26
Status: Accepted

## Context

Phase 10 asks for optional AI agents that install on their own, update through each publisher, show a version, explain sign-in, and let one agent call an approved AgenticROS capability. The desktop already installs agents from Super+Space, and AgenticROS already points those agents at this machine's ROS graph. The plan also names mise, the Gemini CLI, and OpenCode. Those are not in the menu catalog.

## Decision

- The supported agents are the catalog in `manifests/packages/agents.conf`: Antigravity, Claude Code, Codex, Cursor, Grok, Hermes, and OpenClaw. Super+Space installs or launches one row at a time. The desktop profile does not preinstall them. mise, the Gemini CLI, and OpenCode stay out. Gemini was already removed in `docs/decisions/0016-agent-menu.md`.
- `corebrum agents list` reports whether each catalog command is on `PATH`. When `command --version` prints one short line within two seconds, that line is the version. A command that opens a session instead is reported as installed with no version.
- `corebrum agents update` does not run an installer. Super+Space Updates, AI Agents, runs each installed publisher's installer again. That is the vendor update.
- The first launch of a CLI asks that publisher to sign in. The installer scripts and this repository do not store the token. Agent install does not write `/etc/corebrum/ros/rmw`.
- On 2026-10-26 the Cursor agent, through the AgenticROS tools on this machine, listed capabilities and called `list_topics`. The approved Creep or Treat skill was present as `host_trick_or_treat` from `@agenticros/halloween` 0.2.2. `list_topics` returned an empty graph. A camera snapshot timed out because the RealSense node was not running. `/etc/corebrum/ros/rmw` was `rmw_zenoh_cpp`. The haunt was not started again.

## Consequences

`corebrum app install` is not a command. The menu is the installer. A later phase can add mise or OpenCode only when that phase is explicitly approved. Wake word and ElevenLabs stay out.
