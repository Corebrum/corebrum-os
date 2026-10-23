# 0035. One Chromium row, with browser logos

Date: 2026-10-23
Status: Accepted

## Context

Super+Space listed both `Chromium` and `Chromium Web Browser`. `0014` writes `NoDisplay=true` copies of `chromium_chromium.desktop` and `chromium_daemon.desktop` into the runtime applications directory, which is first on `XDG_DATA_DIRS`. Fuzzel treats that first file as the winner. The GTK window skipped a `NoDisplay` file without recording its id, then loaded the snap's later file and showed it again.

The Chromium row used the generic `web-browser` icon. Firefox's snap desktop file points `Icon` at `/snap/firefox/current/default256.png`. The window only asked the icon theme for a name, so that path drew nothing.

## Decision

- The first desktop file for an id wins in the Super+Space window. A hidden or `OnlyShowIn` file claims that id. Submenu files with `NoDisplay=true` stay searchable by name.
- The Chromium row uses `/snap/chromium/current/chromium.png` when that file exists, and the Papirus `chromium` icon otherwise.
- An `Icon` value that is a file path is drawn from that file. Firefox keeps the snap's icon path, so the Firefox logo is shown on that row.

## Consequences

The snap desktop files remain the MIME handlers. A desktop install that already ran needs the updated window and Chromium menu script before the extra row disappears.
