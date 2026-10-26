# 0052. Local speech uses espeak-ng

Date: 2026-10-26
Status: Accepted

## Context

The desktop profile already installs Ubuntu `espeak-ng-espeak`. On this machine `espeak hello` is audible. Phase 9 in the build plan also asks for a speech command, a ROS 2 request path, a way to turn speech off on a headless machine, and local speech that still works when no cloud key is set.

Speech recognition, a wake word, microphone selection, and ElevenLabs are later work. This change does not add them.

## Decision

- `corebrum speak "text"` runs `espeak-ng`, or `espeak` when `espeak-ng` is not on `PATH`. It does not read an API key and it does not call a network tool.
- `corebrum voice list` prints `espeak-ng --voices`. `corebrum voice test` says “Hello from Corebrum.” `corebrum voice set espeak` stores that engine under the user state directory. An optional second argument stores one voice name from that list.
- `corebrum voice disable` writes `enabled=0` in that same file and later `corebrum speak` prints `speech is disabled` without starting espeak. `corebrum voice enable` turns it back on. The file is `${XDG_STATE_HOME:-~/.local/state}/corebrum/speech.conf`. The command does not write `~/.config`.
- A second `corebrum speak` stops the espeak process started by the previous one.
- `corebrum speak listen` reads `std_msgs/String` messages on `/corebrum/say` and says each one. `--once` stops after one message. The listener needs the ROS 2 setup file. It does not install ROS 2.
- `corebrum status` prints `speech: espeak`, `speech: disabled`, or `speech: not installed`. A missing espeak install does not fail `corebrum doctor`.
- `corebrum voice set` rejects any engine other than `espeak`.

## Consequences

A desktop machine can say text from the shell and from a ROS 2 publisher without a cloud account. A headless machine can turn that off. Wake word, microphone selection, and ElevenLabs remain unbuilt. Local speech recognition is `docs/decisions/0054-local-speech-recognition.md`. The desktop package list is unchanged.
