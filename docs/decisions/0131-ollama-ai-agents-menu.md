# 0131. Ollama lives under AI Agents in Super+Space

Date: 2026-11-07
Status: Accepted

## Context

Grouped Super+Space put Ollama under Robot with ROS, Synapse, and skills. Ollama is a local LLM runtime like the publisher CLIs under AI Agents, not robotics middleware.

## Decision

- `config/menu/corebrum-menu.json` removes `corebrum-ollama` from the Robot group and adds it to the AI Agents node as a `children` leaf beside **`navigateAs`: `corebrum-agents`**.
- `corebrum-launcher.py` merges those extra `children` into the navigate list when a node has both `navigateAs` and `children`, keeping Super+A default rows first and sorting the rest by name.
- Robot group keywords no longer include `ollama`. AI Agents keywords add `ollama` and `local`.

## Consequences

- Typing `ollama` at the Super+Space root finds Ollama under AI Agents.
- Install and run behavior is unchanged. `corebrum-ollama-menu` still writes the same desktop entry.
