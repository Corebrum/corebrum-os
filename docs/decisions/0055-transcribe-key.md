# 0055. Super+H transcribes the microphone

Date: 2026-10-26
Status: Accepted

## Context

`corebrum voice hear` transcribes the default microphone for a fixed number of seconds and prints the words in the terminal. The operator asked for that action on Super+H. Super+H, Super+J, and Super+L no longer move focus. Super+K clears the terminal. See `docs/decisions/0053-terminal-clear.md` and `docs/decisions/0054-local-speech-recognition.md`.

A shortcut has no terminal to print into. The words need to reach the clipboard, and the operator needs to see them.

## Decision

- Super+H runs `corebrum voice hear toggle`.
- The first press records the default microphone for up to 60 seconds and shows a listening notification. The next press stops the recording.
- When the recording stops, on a second press or at 60 seconds, the command transcribes it with the installed `pocketsphinx`, copies the words, and shows them.
- The Keybindings list includes Super+H. `corebrum voice hear 8` still records for a fixed time and prints the words.
- When `pocketsphinx` is missing, Super+H asks Yes or No. Yes opens a terminal and installs `pocketsphinx` and `pocketsphinx-en-us`. No leaves speech recognition uninstalled. The shortcut does not install a package without that answer.

## Consequences

Super+H listens and then copies the transcript. The desktop profile still does not install `pocketsphinx`. A running session uses the new binding after Hyprland loads the updated config. The Keybindings list shows the row after its installed script is updated. The shortcut later moved to Control+Space. See `docs/decisions/0071-transcribe-control-space.md`.
