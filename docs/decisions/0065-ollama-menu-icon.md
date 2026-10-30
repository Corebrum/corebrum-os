# 0065. The Ollama menu row uses the Ollama mark

Date: 2026-10-26
Status: Accepted

## Context

Super+Space lists Ollama with the generic `applications-science` icon. A square white Ollama mark is published at `https://corebrum.com/synapse/ollama-white.png`. Fuzzel already draws desktop icons.

## Decision

- The desktop profile copies that mark to `/usr/share/corebrum/ollama.png`. The file in this checkout is `config/brand/ollama.png`.
- The Ollama row sets `Icon` to that path. The desktop profile does not install Ollama.

## Consequences

The next Super+Space after the desktop files are copied shows the mark. Uninstall removes the file with the other Corebrum desktop files.
