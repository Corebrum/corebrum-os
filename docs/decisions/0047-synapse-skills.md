# 0047. Corebrum Synapse skills stay operator-approved

Date: 2026-10-26
Status: Accepted

## Context

Corebrum Synapse skills are robot packages listed at https://skills.corebrum.com. An agent can already see popular skills as discoverable capabilities. A rare skill never reached that list, because the catalog query stopped at the first page. Installing from a non-interactive agent also skipped the person at the keyboard.

## Decision

- The marketplace `GET /skills?capability=` matches a denormalized `capabilityIds` list and still scans older listings that do not have that field. Clients keep calling `https://skills.corebrum.com/api`.
- `ros2_install_skill` and `ros2_create_skill` are the agent tools. Install uses a marketplace or npm ref. Create writes a skill under `~/.synapse/skills-local` and does not publish it.
- Approval is `corebrum-skills-approve` when that helper is installed. Yes continues. Anything else, including no answer, cancels. `--yes` is not a grant. A non-interactive caller with no helper and no grant exits 1. `SYNAPSE_SKILL_GRANT=1` means the dialog already happened.
- The helper shows the skill name, author, and summary. It does not run npm or git.
- Super+Space lists Skills only after Corebrum Synapse is installed. The idle menu is one row. Refresh writes that row and does not install a skill. The row shells out to `synapse skills` list, search, install, and remove.
- The desktop profile does not preinstall skills. A skill that needs Nav2, MoveIt, OpenNav, RTAB-Map, an on-robot follow node, or a detection publisher says so and does not start that stack.

## Consequences

The live catalog serves capability search after the marketplace functions are deployed. A skill installed in the current agent session is visible after that agent is started again. `synapse mcp setup` rewrites the standing instruction that tells agents to use these tools.
