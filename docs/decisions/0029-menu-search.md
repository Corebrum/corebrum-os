# 0029. Super+Space search includes submenu items

Date: 2026-10-23
Status: Superseded by 0030

## Context

Super+Space is Fuzzel. It searches desktop entries written under the user runtime directory before it starts. AI Agents, ROS, RealSense, and AgenticROS each wrote one parent entry. The names inside those menus, such as Grok CLI and Gazebo, existed only in a second Fuzzel process that started after the parent was chosen. Typing `grok` or `gazebo` at the top prompt therefore matched nothing.

## Decision

- Refresh writes one desktop entry for each item the submenu would list. The parent entry stays, so the submenu can still be opened.
- Grok and the other agent CLIs are listed whenever AI Agents is listed. A missing CLI keeps the `install` mark. Choosing the search row installs or launches that CLI.
- RViz, Gazebo, Nav2, and MoveIt are listed after `ros-<distro>-ros-base` is installed, which is when the ROS submenu lists them. Choosing the row installs or launches that tool.
- RealSense Viewer and RealSense ROS are listed after RealSense is installed. AgenticROS actions are listed after AgenticROS is initialized. Choosing a row runs that action.
- A removed catalog id deletes its desktop file on the next refresh, so an old name does not stay in the menu.
- Fuzzel matches the desktop file name, the visible name, the generic name, keywords, and the comment. The file name contains the short id, so `grok` matches `corebrum-agent-grok.desktop` and `gazebo` matches `corebrum-ros-tool-gazebo.desktop`.
- Wallpaper images, autolock timers, the keybinding list, and Remote desktop start and stop stay inside their parent menus.

## Consequences

An empty Super+Space prompt lists those submenu items beside their parents. The install and launch commands are the same ones the submenu already runs. The entries live in the runtime directory, not in `~/.config`.
