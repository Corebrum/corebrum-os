Corebrum OS — Engineering Build Plan
The OS for Physical AI
Version: 0.1 Date: October 21, 2026 Status: Initial Engineering Plan Author: Chris Matthieu Website: corebrum.com
Progress — October 26, 2026
Phases 0–4 are shipped: the base profile, the Hyprland desktop, workstation services, and the corebrum command. Phase 5 is shipped for topics: on 2026-10-26 this machine at 192.168.8.100 and a ThinkPad at 192.168.8.193 exchanged a ROS 2 string through one Zenoh router. Both shells used client mode. The default peer session was not reachable from the other machine. See docs/decisions/0049-two-machine-zenoh.md. Phase 6 acceptance passed on the connected D435, serial 213622076118, firmware 5.17.3.10. Color and depth published at about 30 Hz, RViz showed the depth point cloud, and unplugging the camera left that same node streaming after it was plugged back in. Infrared, IMU, and a camera stream to the second machine were not part of this run. See docs/decisions/0050-realsense-acceptance.md. Phase 7 acceptance passed on 2026-10-26. AgenticROS 0.7.38 is in local mode on rmw_zenoh_cpp. Creep or Treat (@agenticros/halloween 0.2.2) ran against the D435, greeted one visitor from depth, and did not drive. Movement skills were not run. See docs/decisions/0051-agenticros-acceptance.md. AgenticROS, Skills, AI agents, RViz, Gazebo, Nav2, MoveIt, remote desktop, and Updates are Super+Space menus. corebrum status, camera list, agents list, and update status report those pieces and do not install them. Phase 9 speaks locally with espeak-ng. `corebrum voice hear` transcribes the default microphone with Ubuntu pocketsphinx after `corebrum voice hear --install`. The desktop profile does not install that recognizer. Super+H starts that transcription and the next press copies the words. If transcription is missing, Super+H asks before it installs. Wake word and ElevenLabs are not installed. See docs/decisions/0052-local-speech.md and docs/decisions/0054-local-speech-recognition.md. Phase 10 acceptance passed on 2026-10-26. The menu catalog is the supported agent list. `corebrum agents list` shows PATH and a version when the CLI prints one. `corebrum agents update` does not run the publisher installers. Cursor listed the approved Creep or Treat capability and called `list_topics` on rmw_zenoh_cpp. The camera node was not running, so that list was empty. mise, the Gemini CLI, and OpenCode are not installed. See docs/decisions/0056-agent-acceptance.md. Phase 11 acceptance passed on 2026-10-26. Headless Gazebo published /clock through ros_gz_bridge on rmw_zenoh_cpp. The operator opened Gazebo, Nav2, and MoveIt from Super+Space and each window came up. RViz, Gazebo, Nav2, and MoveIt stay on the ROS menu. See docs/decisions/0057-simulation-acceptance.md. Phase 12 acceptance passed the same day. OpenSSH is optional with --enable-ssh, the base profile installs tmux, and Remote desktop is wayvnc with a password. WebRTC and NAT traversal are not installed. See docs/decisions/0058-remote-access.md. Phase 13 is the Updates menu. corebrum update status lists the rows and does not upgrade. There is no signed package repository. See docs/decisions/0059-updates-acceptance.md. Phases 14 and 15 are still future work. Corebrum Mesh is not part of this plan. Later phase numbers are unchanged. See docs/decisions/0048-cli-catch-up.md.
1. Purpose
This document provides an actionable, phased engineering plan for building Corebrum OS using AI coding agents such as OpenAI Codex and Cursor.
Corebrum is an open-source, developer-first Linux environment for Physical AI, inspired by Omarchy's polished tiling desktop and opinionated developer experience.
The initial implementation will run on Ubuntu Server 24.04 LTS (x86-64) and integrate:
* Hyprland, Waybar, terminal tools, and essential desktop utilities
* ROS 2 Jazzy with Zenoh as the default RMW
* RealSense SDK and ROS 2 camera integration
* AgenticROS
* eSpeak NG and optional speech recognition
* Optional AI agents and development tools
* RViz, Gazebo, SSH, screen sharing, and WebRTC
* Independent update channels for the OS, desktop, robotics stack, and AI tools
The primary objective is a reliable, reproducible, modular operating environment—not a new Linux kernel or distribution built from scratch.

2. Instructions for AI Coding Agents
2.1 Engineering Rules
Codex and Cursor should follow these rules throughout development:
1. Work on one development phase at a time.
2. Never assume that an external package, CLI, API, or GitHub repository exists without verifying it.
3. Inspect the existing repository before creating or changing files.
4. Prefer official Ubuntu and ROS 2 packages when available.
5. Use idempotent installation scripts that can safely be run multiple times.
6. Never overwrite existing user configuration without backup or explicit permission.
7. Separate configuration, package installation, service management, and validation.
8. Do not execute destructive disk, network, or bootloader operations automatically.
9. Pin compatible robotics dependencies and document version constraints.
10. Run tests and document their results before marking a phase complete.
11. Do not begin the next phase until the current phase passes its acceptance criteria.
12. Record implementation decisions and deviations in docs/decisions/.
13. Never hardcode credentials, API keys, or secrets.
14. Support clean installation, upgrade, and removal wherever practical.
15. Prefer maintainable integrations over forks of upstream projects.
2.2 Development Workflow
For every phase:
Plan → Implement → Test → Document → Review → Commit
Each phase should produce:
* Working code and configuration
* Installation or upgrade scripts
* Automated validation
* Updated documentation
* Known limitations
* A reproducible Git commit
Use a dedicated feature branch for substantial work.
Do not claim success based only on an installation command exiting successfully. Validate the actual runtime behavior.
3. Initial Technical Baseline
Component	Initial choice
Operating system	Ubuntu Server 24.04 LTS
Architecture	x86-64
Display server	Wayland
Compositor	Hyprland
Status bar	Waybar
Terminal	Kitty initially; evaluate Ghostty
Terminal multiplexer	tmux
Additional terminal workflow	Evaluate herdr
Application launcher	Fuzzel initially
File manager	Thunar
Browser	Firefox
Network management	NetworkManager
Audio	PipeWire + WirePlumber
Login manager	greetd + tuigreet
ROS	ROS 2 Jazzy
ROS middleware	rmw_zenoh_cpp
Communication fabric	Zenoh
Perception	RealSense SDK
Agent integration	AgenticROS
Default TTS	eSpeak NG
Optional STT	faster-whisper
AI tool manager	mise
OS package manager	APT / dpkg
Init/service manager	systemd
Important: Pacman is not part of the Ubuntu-based Corebrum architecture. Ubuntu uses APT. We are adopting Omarchy's user experience and update philosophy, not its Arch Linux package manager.
4. Proposed Repository Structure
Create the following initial repository structure:
corebrum-os/
├── README.md
├── LICENSE
├── AGENTS.md
├── COREBRUM_BUILD_PLAN.md
├── Makefile
├── .github/
│   └── workflows/
├── config/
│   ├── hypr/
│   ├── waybar/
│   ├── fuzzel/
│   ├── kitty/
│   ├── tmux/
│   ├── network/
│   ├── zenoh/
│   └── systemd/
├── scripts/
│   ├── install.sh
│   ├── uninstall.sh
│   ├── lib/
│   ├── phases/
│   └── validate/
├── packages/
│   ├── base/
│   ├── desktop/
│   ├── robotics/
│   └── integrations/
├── apps/
│   ├── launcher/
│   ├── settings/
│   └── dashboard/
├── manifests/
│   ├── packages/
│   ├── versions/
│   └── hardware/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── smoke/
└── docs/
    ├── architecture/
    ├── installation/
    ├── development/
    ├── decisions/
    └── troubleshooting/
AGENTS.md should contain persistent coding-agent instructions.
The root installer should orchestrate modular phase scripts rather than contain all installation logic.
5. Development Phases
Phase 0 — Repository and Development Infrastructure
Priority: Critical Dependencies: None
Objective
Create the repository, development conventions, automated checks, and initial documentation before modifying an operating system.
Tasks
* Initialize Git repository.
* Create the proposed directory structure.
* Add MIT license for original Corebrum code, subject to license review.
* Create AGENTS.md.
* Create architecture decision records.
* Add ShellCheck and shell formatting checks.
* Add Python testing infrastructure if Python utilities are introduced.
* Create Makefile commands for validation.
* Establish GitHub Actions CI.
* Document development machine requirements.
* Define component manifests and version pinning conventions.
Deliverables
* Initialized repository
* CI validation workflow
* Initial engineering documentation
* Reusable script library
Acceptance Criteria
* Repository checks pass.
* No installation scripts modify the host during CI.
* New contributors can understand the project structure.

Phase 1 — Ubuntu Server Foundation
Priority: Critical Dependencies: Phase 0
Objective
Produce a reproducible, minimal Ubuntu Server installation suitable for desktop and robotics development.
Tasks
* Target Ubuntu Server 24.04 LTS x86-64.
* Create a package manifest for base dependencies.
* Implement installation preflight checks.
* Verify architecture, Ubuntu release, disk space, and connectivity.
* Install required system utilities.
* Configure locales and time synchronization.
* Install OpenSSH server as an opt-in feature.
* Establish logging and diagnostic utilities.
* Implement safe package installation helpers.
* Establish backup and configuration ownership conventions.
* Create a VM-based test environment.
Proposed installer
sudo ./scripts/install.sh --profile base
The installer must support a dry-run mode before any changes are applied.
Acceptance Criteria
* Fresh Ubuntu Server installation succeeds.
* Installation can be rerun safely.
* Existing networking remains functional.
* Logs identify installed components and failures.
* Base installation passes validation after reboot.

Phase 2 — Hyprland Desktop Foundation
Priority: Critical Dependencies: Phase 1
Objective
Create a functional, lightweight, keyboard-driven graphical environment.
Components
* Hyprland
* Waybar
* Kitty
* Fuzzel
* greetd / tuigreet
* Thunar
* Firefox
* Mako
* Fonts and icon themes
Tasks
* Verify supported Hyprland packages for Ubuntu 24.04.
* Install and configure Wayland graphical dependencies.
* Configure user session startup.
* Configure Hyprland tiling behavior.
* Configure workspace switching.
* Configure fullscreen and floating window shortcuts.
* Configure Waybar.
* Create a Corebrum theme.
* Configure terminal and application launcher.
* Add a minimal graphical login.
* Test multi-monitor operation.
* Test graphical recovery after failed configuration.
Do not rely on unverified third-party package repositories or silently replace core graphical libraries.
Acceptance Criteria
* System boots to a working login.
* Hyprland starts successfully.
* Terminal opens with Super + Enter.
* Applications tile correctly.
* Workspaces and fullscreen work.
* Waybar displays system status.
* User can return to a text console if the graphical session fails.

Phase 3 — Essential Desktop Services
Priority: Critical Dependencies: Phase 2
Objective
Make Corebrum usable as a daily Linux workstation.
Components
* NetworkManager
* NetworkManager graphical tools
* Bluetooth utilities
* PipeWire / WirePlumber
* Display configuration tools
* Power management
* polkit authentication agent
* Removable-media mounting
* Clipboard utilities
* Screen capture utilities
* Desktop portals
Tasks
* Configure NetworkManager without breaking existing Netplan networking.
* Provide Wi-Fi and Ethernet configuration.
* Integrate network status into Waybar.
* Configure audio devices and microphone access.
* Configure Bluetooth.
* Enable graphical display settings.
* Add file manager integration.
* Configure notifications.
* Establish XDG portal support.
* Add graphical privilege prompts.
* Test suspend and resume where supported.
Acceptance Criteria
* Wi-Fi and Ethernet can be managed.
* Audio playback and recording work.
* USB drives appear in the file manager.
* Display settings work.
* Browser screen sharing works where supported.
* Corebrum is usable without ROS 2 installed.

Phase 4 — Corebrum Installer, Configuration and CLI
Priority: Critical Dependencies: Phases 1–3
Objective
Convert the working desktop into a reproducible, maintainable product installation.
Tasks
* Create a unified corebrum CLI.
* Implement install, status, doctor, and configuration commands.
* Define declarative component manifests.
* Create desktop and headless profiles.
* Implement optional feature selection.
* Add backup and configuration migration support.
* Create a branded application launcher menu.
* Add installation logging.
* Document removal and recovery procedures.
* Build integration tests using fresh Ubuntu VMs.
Proposed commands
corebrum status
corebrum doctor
corebrum install desktop
corebrum config
corebrum version
These are new commands to implement, not existing system utilities.
Acceptance Criteria
* Fresh Ubuntu Server can be converted into Corebrum Desktop using a documented command.
* The process is reproducible.
* A second installation run does not duplicate configuration.
* Failed installations report actionable diagnostics.
* User-specific configuration is preserved.
Milestone A: Corebrum Desktop Alpha
At this point, Corebrum is a usable Omarchy-inspired Ubuntu desktop without the robotics stack.

Phase 5 — ROS 2 Jazzy and Zenoh RMW
Priority: Critical Dependencies: Phase 4
Objective
Establish the native Physical AI communication foundation.
Components
* ROS 2 Jazzy
* rmw_zenoh_cpp
* Zenoh router
* ROS 2 developer tools
* colcon
* rosdep
Tasks
* Configure the official ROS 2 package repository.
* Install ROS 2 Jazzy.
* Install the compatible Zenoh RMW implementation.
* Configure RMW_IMPLEMENTATION=rmw_zenoh_cpp.
* Establish a managed Zenoh router service.
* Verify supported router startup and shutdown behavior.
* Configure local discovery.
* Define network and namespace conventions.
* Test ROS topics, services, and actions.
* Test communication between two machines.
* Document router and middleware compatibility.
* Provide DDS fallback configuration.
Proposed commands
corebrum ros status
corebrum ros topics
corebrum zenoh status
corebrum zenoh peers
Acceptance Criteria
* ROS 2 nodes communicate using Zenoh RMW.
* Two machines can exchange ROS 2 messages over the configured network.
* Services and actions work.
* Router restart and failure behavior are documented.
* DDS fallback can be selected when needed.
* No duplicate or conflicting Zenoh router services are launched.

Phase 6 — RealSense Perception Integration
Priority: High Dependencies: Phase 5
Objective
Make RealSense cameras easy to discover, configure, visualize, and use through ROS 2.
Tasks
* Verify compatible librealsense packages.
* Install RealSense SDK and utilities.
* Install compatible RealSense ROS 2 wrapper.
* Configure camera device permissions.
* Implement camera discovery.
* Add application launcher entries.
* Add RViz installation option.
* Validate RGB, depth, infrared, and IMU where supported.
* Test camera reconnection.
* Test ROS 2 streams over Zenoh.
* Measure CPU, memory, and network performance.
* Document supported camera models and firmware.
Proposed commands
corebrum camera list
corebrum camera info
corebrum camera start
corebrum camera viewer
Acceptance Criteria
* A supported camera is detected.
* RGB and depth streams are available.
* Camera ROS topics appear.
* RViz can visualize depth data.
* Reconnecting the camera does not require reinstalling software.
Milestone B: Corebrum Physical AI Alpha
Corebrum now provides a working ROS 2, Zenoh, and perception environment.

Phase 7 — AgenticROS Integration
Priority: High Dependencies: Phases 5–6
Objective
Make AgenticROS a native robotics capability.
Tasks
* Inspect the actual AgenticROS CLI, installation process, and APIs.
* Implement a compatible installation module.
* Configure the AgenticROS runtime.
* Connect AgenticROS to local ROS 2.
* Verify Zenoh integration.
* Implement optional cloud authentication.
* Add application launcher integration.
* Support installation of AgenticROS skills.
* Test agent-driven camera perception.
* Establish explicit permissions for robot actions.
* Provide diagnostics for disconnected or unavailable services.
Acceptance Criteria
* AgenticROS can discover the configured ROS environment.
* A supported skill executes successfully.
* Camera data is accessible through the supported integration.
* Cloud features are optional.
* Local workflows function offline.

Phase 9 — Speech and Voice
Priority: Medium Dependencies: Phases 5 and 7
Objective
Provide a consistent voice interface for robotics applications.
Default Components
* eSpeak NG
* Audio output integration
Optional Components
* faster-whisper
* Vosk
* Silero VAD
* openWakeWord
* ElevenLabs
Tasks
* Install eSpeak NG by default.
* Create a speech synthesis service.
* Define ROS 2 speech topics/actions.
* Add optional STT installers.
* Support microphone selection.
* Add optional wake-word detection.
* Add ElevenLabs API configuration.
* Implement local TTS fallback.
* Support interruption and cancellation.
* Test speech latency and resource usage.
Proposed commands
corebrum speak "Hello world"
corebrum voice list
corebrum voice test
corebrum voice set espeak
Acceptance Criteria
* Offline speech synthesis works.
* Optional STT transcribes microphone input.
* Speech requests can be issued from ROS 2.
* Missing cloud credentials do not break local speech.
* Speech services can be disabled on headless deployments.

Phase 10 — Optional AI Agents and Development Tools
Status: Accepted on 2026-10-26. The menu catalog replaced mise, the Gemini CLI, and OpenCode. See docs/decisions/0056-agent-acceptance.md.
Priority: Medium Dependencies: Phase 4; integration tests use Phase 7
Objective
Replicate Omarchy's curated AI agent installation experience.
Components
* mise
* Claude Code
* Codex
* Gemini CLI
* OpenCode
* Grok integrations
* OpenClaw
Tasks
* Install and configure mise.
* Build an optional AI agent installer.
* Verify each agent's supported installation method.
* Support independent tool updates.
* Implement version display.
* Add authentication instructions.
* Add application launcher entries.
* Integrate supported agents with AgenticROS.
* Add safe execution boundaries for robot commands.
Proposed commands
corebrum app install claude
corebrum app install codex
corebrum app install opencode
corebrum agents list
corebrum agents update
Acceptance Criteria
* Each supported agent can be installed independently.
* Agent installation does not alter ROS 2 middleware versions.
* Updates use supported vendor mechanisms.
* Credentials are not stored in plaintext project files.
* An agent can invoke an approved AgenticROS capability.
Milestone C: Corebrum AI Developer Preview
A developer can connect a camera, inspect ROS data, and use an AI agent to interact with supported robotics capabilities.

Phase 11 — Simulation and Developer Applications
Status: Accepted on 2026-10-26. Headless Gazebo published /clock, and the operator opened Gazebo, Nav2, and MoveIt. The tools stay on the ROS menu. See docs/decisions/0057-simulation-acceptance.md.
Priority: Medium Dependencies: Phases 5 and 4
Objective
Provide optional robotics simulation and visualization tools.
Components
* RViz2
* Gazebo
* MoveIt 2
* Additional optional tools
Tasks
* Build a curated application manifest.
* Implement application installation and removal.
* Create launcher entries.
* Test tiling and fullscreen behavior.
* Add simulation workspace templates.
* Validate ROS 2 integration.
* Document hardware requirements.
* Avoid installing heavyweight simulation packages by default.
Acceptance Criteria
* RViz runs from the launcher.
* Gazebo runs on supported hardware.
* Simulated ROS topics can be inspected.
* Applications integrate with Hyprland workspaces.

Phase 12 — Remote Access and Telepresence
Status: Accepted on 2026-10-26. SSH is optional, tmux is in the base profile, and remote desktop is wayvnc. See docs/decisions/0058-remote-access.md.
Priority: Medium Dependencies: Phases 3 and 7
Objective
Enable reliable remote development and robot access.
Tasks
* Harden SSH configuration.
* Integrate tmux session workflows.
* Evaluate Wayland-compatible remote desktop tools.
* Configure portal-based screen sharing.
* Test remote graphical access.
* Integrate AgenticROS WebRTC connectivity.
* Test NAT traversal where supported.
* Define user consent and remote control policies.
* Add connection diagnostics.
* Validate operation over unreliable networks.
Acceptance Criteria
* Remote SSH access works securely.
* tmux sessions survive disconnects.
* Supported desktop screen sharing works.
* AgenticROS remote connectivity functions.
* Unauthorized remote control is prevented.

Phase 13 — Independent Software Update System
Status: Accepted on 2026-10-26. Updates stay on the Super+Space menu. There is no signed repository. See docs/decisions/0059-updates-acceptance.md.
Priority: Critical before public beta Dependencies: Phases 4–7
Objective
Deliver independent, compatibility-aware updates.
Tasks
* Establish signed Corebrum APT repository.
* Package Corebrum desktop and integration components.
* Create Stable, Beta, and Edge release channels.
* Build automated package publication.
* Implement component version manifests.
* Validate ROS 2/Zenoh compatibility.
* Separate AI agent updates from robotics runtime updates.
* Implement update status reporting.
* Add rollback and recovery mechanisms.
* Test interrupted updates.
* Test offline operation.
* Require approval for disruptive robot runtime changes.
Proposed commands
corebrum update status
corebrum update system
corebrum update desktop
corebrum update robotics
corebrum update agents
Acceptance Criteria
* Desktop packages update without reinstalling Ubuntu.
* AI tools update independently.
* Robotics dependencies remain compatible.
* Packages are signed and verified.
* Failed updates have a documented recovery path.
* Running robots are not unexpectedly disrupted.

Phase 14 — ARM64 and Embedded Hardware
Priority: After stable x86-64 development preview Dependencies: Phases 5–13
Objective
Expand Corebrum to embedded Physical AI hardware.
Platforms
* NVIDIA Jetson
* Raspberry Pi
* Selected ARM64 development boards
Tasks
* Create architecture-specific package manifests.
* Implement hardware detection.
* Preserve JetPack-managed drivers and libraries.
* Test ARM64 ROS 2 and Zenoh packages.
* Validate RealSense camera connectivity.
* Test AgenticROS runtime.
* Benchmark resource usage.
* Create headless profiles.
* Build supported hardware installation documentation.
Acceptance Criteria
* Supported ARM64 devices can install Corebrum components.
* ROS 2/Zenoh works.
* Hardware drivers remain functional.
* Headless operation works reliably.
* Resource consumption is documented.

Phase 15 — Corebrum Store and Ecosystem
Priority: Future Dependencies: Stable package/update infrastructure
Objective
Create a curated software and robotics skills catalog.
Potential Features
* Application discovery
* One-click installation
* AgenticROS skills marketplace
* Hardware integration packages
* Community-maintained apps
* Commercial applications
* Ratings and compatibility metadata
* Publisher verification
Acceptance Criteria
To be defined in a separate product specification.
The marketplace must not delay the initial operating system release.
6. Build and Release Milestones
Milestone	Required phases	Deliverable
A — Desktop Alpha	0–4	Functional Ubuntu + Hyprland Corebrum desktop
B — Physical AI Alpha	5–6	ROS 2 + Zenoh + RealSense
C — AI Developer Preview	7, 9–10	AgenticROS, speech, optional AI agents
E — Public Beta	11–13	Simulation, remote access, independent updates
F — Hardware Expansion	14	Jetson and Raspberry Pi support
G — Ecosystem	15	App and skills catalog
Phases 9–12 may proceed in parallel after their prerequisites are stable.
7. Testing Strategy
Unit Tests
Test CLI parsing, configuration generation, package manifests, version comparison, and utility functions.
Installation Tests
Use clean Ubuntu Server VMs to validate fresh installation and repeated installation.
Integration Tests
Test systemd services, networking, graphical session startup, ROS 2/Zenoh messaging, and optional integrations.
Hardware Tests
Maintain separate physical hardware validation for RealSense, Jetson, Raspberry Pi, microphones, and GPUs.
Upgrade Tests
Test updates from previous Corebrum releases, including service restarts, configuration migration, and recovery.
Security Tests
Validate package signatures, service permissions, SSH access, credential storage, and remote robot authorization.
8. Non-Goals for the Initial Release
Corebrum v0.1 will not:
* Build a custom Linux kernel.
* Replace Ubuntu's package manager.
* Fork ROS 2 or Hyprland.
* Require a cloud account.
* Require paid AI services.
* Provide a production-ready fleet management platform.
* Guarantee support for every robotics device.
* Build a complete custom desktop environment.
* Implement a commercial application marketplace.
* Replace existing robot safety controllers.
9. Immediate Engineering Sprint
Sprint 1 — Build the Foundation
The first Codex/Cursor assignment should focus exclusively on Phases 0 and 1.
Tasks
1. Create the repository structure.
2. Write AGENTS.md.
3. Implement host preflight checks.
4. Create a base package manifest.
5. Implement an idempotent base installer.
6. Add dry-run support.
7. Implement logging and error handling.
8. Add a base validation script.
9. Add ShellCheck and GitHub Actions.
10. Document how to test using a fresh Ubuntu Server 24.04 VM.
Required Deliverables
AGENTS.md
README.md
scripts/install.sh
scripts/lib/
scripts/phases/01-base.sh
scripts/validate/base.sh
manifests/packages/base.txt
.github/workflows/ci.yml
docs/installation/ubuntu-server.md
Definition of Done
The repository passes CI, and the base installer succeeds twice on a clean Ubuntu Server 24.04 VM without breaking networking or changing unrelated user configuration.
Do not begin installing Hyprland, ROS 2, Zenoh, RealSense, or AgenticROS during Sprint 1.
10. Initial Prompt for Codex or Cursor
Use the following as the first engineering instruction:
You are the lead engineer for Corebrum OS, an open-source Ubuntu-based operating environment for Physical AI.
Read COREBRUM_BUILD_PLAN.md and follow its engineering rules.
Begin with Phase 0 and Phase 1 only.
Inspect the repository, create the proposed project structure, implement the initial Ubuntu Server 24.04 x86-64 base installer, add dry-run support, host preflight checks, package manifests, validation scripts, and GitHub Actions CI.
Do not install the graphical desktop or robotics software yet.
Prefer official Ubuntu packages, avoid destructive system changes, preserve existing user configuration, and make all installation scripts idempotent.
Document all architectural decisions and assumptions.
Run the available tests, report their results, and summarize remaining work.
Stop after completing Phase 1 and wait for approval before proceeding.

Corebrum OS — The OS for Physical AI
Perceive. Reason. Act.
Chris Matthieu — 2026
