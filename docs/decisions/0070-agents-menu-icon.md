# 0070. The AI Agents menu row uses the AI Agents mark

Date: 2026-10-26
Status: Accepted

## Context

Super+Space lists AI Agents with the generic `utilities-terminal` icon. A square mark is published at `https://static.thenounproject.com/png/7278712-200.png`. Fuzzel already draws desktop icons.

## Decision

- The desktop profile copies that mark to `/usr/share/corebrum/agents.png`. The file in this checkout is `config/brand/agents.png`. The published mark is black. The Super+Space background is dark, so the shipped file keeps the same drawing in white.
- The AI Agents row and each CLI search entry set `Icon` to that path. The desktop profile does not install the CLIs.

## Consequences

The next Super+Space after the desktop files are copied shows the mark. Uninstall removes the file with the other Corebrum desktop files.
