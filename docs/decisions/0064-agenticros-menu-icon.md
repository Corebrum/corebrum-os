# 0064. The AgenticROS menu row uses the AgenticROS mark

Date: 2026-10-26
Status: Accepted

## Context

Super+Space lists AgenticROS with the generic `applications-science` icon. The AgenticROS site publishes a square mark at `https://agenticros.com/agenticros-a.png`. Fuzzel already draws desktop icons.

## Decision

- The desktop profile copies that mark to `/usr/share/corebrum/agenticros.png`. The file in this checkout is `config/brand/agenticros.png`.
- The AgenticROS row and its search actions set `Icon` to that path. The desktop profile does not install AgenticROS itself.

## Consequences

The next Super+Space after the desktop files are copied shows the mark. Uninstall removes the file with the other Corebrum desktop files.
