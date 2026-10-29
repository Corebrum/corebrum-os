# 0093. Request Gdk 3 so Jetson search still finds submenu items

Date: 2026-10-29
Status: Accepted

## Context

Super+Space opens a GTK 3 window. An empty box lists parent menus. Typing `grok` or `gazebo` adds the matching hidden desktop file. If that window cannot start, the launcher exits 2 and Fuzzel opens instead. Fuzzel skips `NoDisplay=true` files, so those submenu names stay out of the search box. See `docs/decisions/0030-menu-search-submenus.md`.

This NVIDIA Jetson AGX Orin image ships GNOME's typelibs beside the Corebrum desktop packages: `Gdk-3.0.typelib` and `Gdk-4.0.typelib` are both installed. PyGObject loads Gdk 4 when the import does not name a version. The menu required Gtk 3 and then imported Gdk in the same statement, so Gdk 4 loaded first. Gtk 3 then failed with `Requiring namespace 'Gdk' version '3.0', but '4.0' is already loaded`. The launcher exited 2. x86 and Raspberry Pi installs from Ubuntu Server have Gdk 3 only, so the same import loads Gdk 3 and the search window starts. The login logo script imported Gdk the same way.

## Decision

- `corebrum-launcher.py` calls `gi.require_version("Gdk", "3.0")` before it imports Gdk and Gtk.
- `corebrum-login-logo.py` does the same before it imports Gdk.
- Search matching is unchanged. Fuzzel remains the fallback when GTK still cannot start.

## Consequences

On this Orin the menu imports Gdk 3 with Gtk 3. Typing in that window lists the hidden submenu rows. A machine with only Gdk 3 keeps the same window. The unit tests check that the version request comes before the import. They do not open the window.
