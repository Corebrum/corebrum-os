# 0120. Skills Search installs from a picked marketplace ref

Date: 2026-11-04
Status: Accepted

## Context

Super+Space Corebrum Skills Search only ran `synapse skills search` in a terminal. Operators then chose Install and typed a display name or slug such as `surroundings-skill`. `synapse skills install` expects `owner/skill` or `@scope/name`. A bare name returns 404. The marketplace listing for a surroundings skill uses `codevinoo/surroundings-scan`.

## Decision

- Skills Search asks for a query, loads matches from `https://skills.corebrum.com/api/skills`, lists each as `display name (owner/skill)`, and installs the chosen marketplace ref. One match installs that ref after a short note. Several matches ask for a number, or accept a pasted `owner/skill`.
- Skills Install still accepts a pasted ref. A bare name without `/` or `@` is resolved through the same marketplace search before install. The prompt says that a display name alone 404s and points operators at Search.
- Refresh still does not install a skill. Post-install restart and stack hints from `0119` still run after a successful install from either path.

## Consequences

Operators can search for "surroundings", pick Surroundings Scan, and install `codevinoo/surroundings-scan` without retyping the ref. Decision `0047` still owns approval for agent-driven installs.
