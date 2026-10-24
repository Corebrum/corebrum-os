# 0039. The desktop profile installs GNOME Text Editor

Date: 2026-10-24
Status: Accepted

## Context

The operator asked for a graphical notepad in the desktop installation and in Super+Space. Ubuntu Server does not install one. The desktop profile already installs Thunar and Firefox.

On 2026-10-24 the Ubuntu archive published `gnome-text-editor` for both releases this installer supports. Noble's package is 46.3-0ubuntu2 in main. Resolute apt selected 50.1-0ubuntu0.1. Both packages install `/usr/bin/gnome-text-editor` and `/usr/share/applications/org.gnome.TextEditor.desktop`. That desktop file names the application Text Editor, lists `notepad` as a keyword, and does not set `OnlyShowIn`. The session sets `XDG_CURRENT_DESKTOP=Hyprland`. A desktop file limited to GNOME would stay out of Super+Space. This one is listed.

`gedit` 48.1-9build1 is also in the resolute archive and pulls the gedit library stack. `mousepad` 0.7.0-1 is in universe and names its row Mousepad. `gnome-text-editor` is the Ubuntu text editor, and a search for notepad matches its keyword.

## Decision

- `corebrum install desktop` installs the Ubuntu `gnome-text-editor` package with the rest of `manifests/packages/desktop.txt`.
- The installer does not add a repository. It does not install `gedit` or `mousepad`.
- Super+Space lists the package desktop file. The row is Text Editor. Typing notepad finds that row. The launcher does not write a second desktop file for it.
- Super+Shift+N runs `gnome-text-editor`. The Keybindings list includes that shortcut.

## Consequences

A desktop install can open Text Editor from Super+Space or with Super+Shift+N. Uninstall leaves the package in place, as it does for the other Ubuntu desktop packages. A machine that already installed the desktop profile needs that install again before the editor is present.
