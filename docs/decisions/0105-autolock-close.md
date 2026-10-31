# 0105. Autolock closes after a choice

Date: 2026-10-31
Status: Accepted

## Context

Super+Space Autolock draws the timer list, saves the chosen row, then opens the list again so the `on` mark follows that row. Escape was the only way to leave. See `docs/decisions/0080-sway-session.md`.

## Decision

- Choosing Stay awake, 5 minutes, 10 minutes, 30 minutes, or 1 hour applies that setting and closes the list.
- Escape, or an empty choice, closes the list and leaves the timer unchanged.
- Choosing a time still leaves Stay awake on. The next time the list opens, the `on` mark follows the saved timer.

## Consequences

A notification still says which timer was saved, or that Stay awake is on. The operator opens Autolock again to see the mark.
