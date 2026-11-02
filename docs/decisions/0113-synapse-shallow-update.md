# 0113. Synapse Updates must not fetch with depth 1

Date: 2026-11-02
Status: Accepted

## Context

The Synapse installer clones with `--depth 1`. Updates then ran `git fetch --depth 1 origin main` and `git merge --ff-only FETCH_HEAD`. On this machine that failed with `fatal: refusing to merge unrelated histories` even though `origin/main` was one commit ahead of local `main`. A depth-1 fetch marks the new tip as a shallow root, so Git no longer sees the previous tip as an ancestor. The same failure had already happened once before.

## Decision

- Corebrum Synapse Updates fetches `origin main` without `--depth 1`.
- When `HEAD` and `origin/main` still lack a merge base and the checkout is shallow, Updates deepens (then unshallows if needed) until they share history, then fast-forwards to `origin/main`.
- Unrelated histories after that still stop the step. Dirty checkouts still stop the step. The clone path stays `--depth 1`.

## Consequences

Operators can run Super+Space Updates → Corebrum Synapse on a shallow install after `main` moves. The first update after this change may deepen the checkout. Decision `0045` describes the same fetch without a depth-1 fetch.
