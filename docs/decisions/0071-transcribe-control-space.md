# 0071. Control+Space transcribes the microphone

Date: 2026-10-26
Status: Accepted

## Context

Super+H started and stopped microphone transcription. See `docs/decisions/0055-transcribe-key.md`. The operator asked for that same action on Control+Space.

## Decision

- Control+Space runs `corebrum voice hear toggle`. Super+H is not bound.
- The first press listens for up to 60 seconds. The next press stops, copies the words, and shows them.
- When `pocketsphinx` is missing, Control+Space asks Yes or No before it installs. The prompts name Control+Space.
- The Keybindings list includes Control+Space.

## Consequences

A running session uses the new binding after Hyprland loads the updated config. The Keybindings list shows the row after its installed script is updated. The desktop profile still does not install `pocketsphinx`.
