# 0119. Skills install reminds the operator to restart agents

Date: 2026-11-04
Status: Accepted

## Context

Decision 0047 keeps skill install operator-approved and notes that a skill installed in the current agent session is visible after that agent is started again. A skill that needs Nav2, MoveIt, OpenNav, RTAB-Map, a follow node, or a detection publisher says so and does not start that stack. Super+Space Corebrum Skills only opened a terminal for `synapse skills install` and then closed, so operators often missed both the restart step and the stack dependency.

## Decision

- After a successful Skills menu install, the terminal prints that AI agents must be started again before new skill tools load, and `notify-send` shows the same reminder when available.
- The terminal then offers Open AI Agents, and Open ROS when the skill ref or marketplace listing text matches Nav2, MoveIt, OpenNav, RTAB-Map, navigate, dock, slam, mapping, wander, explore, or pick_object. Done closes the chooser. Choosing Open AI Agents or Open ROS launches that existing menu. The skill still does not start those stacks.
- Marketplace listing text is a best-effort `GET` to `https://skills.corebrum.com/api/skills/<owner>/<skill>` with a short timeout. A missing or failed fetch still uses the install ref alone for keyword hints.
- Refresh still does not install a skill. Approval stays on `corebrum-skills-approve` before install. `--yes` is still not a grant.

## Consequences

Operators who install from Super+Space Corebrum Skills get an explicit restart path and a ROS deep-link when the skill looks stack-dependent. Agent-driven install already returns the restart sentence from Synapse; Getting Started now states both paths. Decision 0047 still owns approval and the no-auto-start rule.
