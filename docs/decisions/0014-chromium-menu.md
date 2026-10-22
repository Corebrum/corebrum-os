# 0014. Chromium is a Super+Space install

Firefox stays in the desktop package list. Ubuntu 24.04 and 26.04 do not publish a Chrome or Chromium deb. `chromium-browser` is a transitional package whose `/usr/bin/chromium-browser` wrapper requires Canonical's `chromium` snap. On 2026-10-22 noble's package is `2:1snap1-0ubuntu2` and resolute's is `2:1snap1-0ubuntu4`. `snap find` lists `chromium` from the publisher `canonical`.

Super+Space shows `Chromium   install` until `/snap/bin/chromium` exists. Choosing it installs `chromium-browser`, `snapd`, and `sudo snap install chromium`, then launches `/snap/bin/chromium` the next time. The desktop profile does not install Chromium, and the installer does not add Google's apt repository.

After that snap is installed it publishes two desktop files, both named `Chromium Web Browser`: `chromium_chromium.desktop` launches `/snap/bin/chromium`, and `chromium_daemon.desktop` is `OnlyShowIn=UbuntuFrame` and runs `/usr/bin/false`. The transitional `chromium-browser` package adds a third file with the same name and `NoDisplay=true`. Fuzzel already hides `NoDisplay`. It does not apply `OnlyShowIn` unless `filter-desktop` is on, so the daemon entry was listed beside Corebrum's `Chromium` and the snap's real browser entry.

Super+Space sets `filter-desktop=yes`. Each refresh also writes `NoDisplay=true` copies of those two snap desktop IDs into the runtime applications directory that is placed first on `XDG_DATA_DIRS` for that Fuzzel process. The menu keeps the single Corebrum entry. The session's own application directories are unchanged, so the snap file remains the MIME handler.
