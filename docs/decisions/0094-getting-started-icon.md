# 0094. Getting Started uses the Corebrum icon

Date: 2026-10-29
Status: Accepted

## Context

Super+Space lists Getting Started and opens the local guide in Firefox. Decision 0078 set that row's icon to `/usr/share/corebrum/logo.png`. That file is the 1104×320 circuit wordmark used on login and lock. The square Corebrum mark is the profile image at `https://pbs.twimg.com/profile_images/2015857352084488196/sYJRRxCn_400x400.jpg`. It is 400×400, with the white circuit brain on a near-black field.

## Decision

- The desktop profile copies `config/brand/icon.png` to `/usr/share/corebrum/icon.png`. The file is that 400×400 mark saved as a PNG. The menu does not download it.
- The Getting Started row sets `Icon` to `/usr/share/corebrum/icon.png`.
- Login and lock keep `/usr/share/corebrum/logo.png`.
- Uninstall removes `/usr/share/corebrum/icon.png` with the other Corebrum marks.

## Consequences

The next Super+Space after the desktop files are copied shows the square mark on Getting Started. A desktop install that already ran needs those two files copied again before the row changes. Login and lock stay on the wordmark.
