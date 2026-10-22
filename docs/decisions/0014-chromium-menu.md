# 0014. Chromium is a Super+Space install

Firefox stays in the desktop package list. Ubuntu 24.04 and 26.04 do not publish a Chrome or Chromium deb. `chromium-browser` is a transitional package whose `/usr/bin/chromium-browser` wrapper requires Canonical's `chromium` snap. On 2026-10-22 noble's package is `2:1snap1-0ubuntu2` and resolute's is `2:1snap1-0ubuntu4`. `snap find` lists `chromium` from the publisher `canonical`.

Super+Space shows `Chromium   install` until `/snap/bin/chromium` exists. Choosing it installs `chromium-browser`, `snapd`, and `sudo snap install chromium`, then launches `/snap/bin/chromium` the next time. The desktop profile does not install Chromium, and the installer does not add Google's apt repository.
