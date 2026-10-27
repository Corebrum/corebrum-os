# 0068. Zenoh fleet and Zenoh network use the Zenoh mark

Date: 2026-10-26
Status: Accepted

## Context

Super+Space lists Zenoh fleet and Zenoh network with the generic `network-workgroup` icon. A Zenoh mark is published at `https://zettascale.tech/wp-content/uploads/2024/09/Zenoh-logo.png`. Fuzzel already draws desktop icons.

## Decision

- The desktop profile copies that mark to `/usr/share/corebrum/zenoh.png`. The file in this checkout is `config/brand/zenoh.png`.
- Zenoh fleet and Zenoh network set `Icon` to that path.

## Consequences

The next Super+Space after those desktop files are copied shows the mark on both rows. Uninstall removes the file with the other Corebrum desktop files.
