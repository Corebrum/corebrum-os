# 0121. Skills List can remove a picked registered skill

Date: 2026-11-04
Status: Accepted

## Context

Skills Search and Install already resolve marketplace `owner/skill` refs. Remove still asked the operator to type an exact registered id. `synapse skills list` shows friendly lines, but `synapse skills remove` needs that id. Operators who only remembered a display name hit the same 404-style failure as bare Install names.

## Decision

- Skills List loads registered skills from `synapse skills list --json`, prints each as `id (packageName)`, and asks for a number to remove or Enter to close.
- Choosing a number runs `synapse skills remove --yes <id>`. Typing a listed id also works. After a successful remove, the terminal reminds the operator to restart AI agents if old tools still appear.
- Skills Remove uses the same picker, so operators do not need a separate List step.
- Refresh still does not install or remove a skill.

## Consequences

List is both an inventory and a remove path. Decision `0120` still covers Search → install. Approval for agent-driven installs stays on `0047`.
