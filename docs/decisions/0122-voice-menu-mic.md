# 0122. Setup Voice picks a microphone and keeps pocketsphinx

Date: 2026-11-04
Status: Accepted

## Context

Phase 9 and `0054` leave transcription on Ubuntu `pocketsphinx` and the PipeWire default source. Operators with Bluetooth headsets or multiple USB mics often get an empty recording and no clear next step. Control+Space already points at Setup → Voice in unfinished work, but that menu did not exist. On 2026-11-04, noble arm64 still has no `vosk` or Whisper speech package. Archive speech names are `pocketsphinx`, `julius`, and Speech Dispatcher synthesizers. `julius` needs its own models and wiring. Resolute still lacks a ready Whisper model package that Corebrum can install without a download.

## Decision

- Super+Space Setup lists Voice after Password. The row is dynamic. Choosing it opens a Fuzzel list: Test speak, Hear once, Microphone, Install recognition, Enable speech, and Disable speech.
- Microphone lists PipeWire `Audio/Source` nodes (or `wpctl` Sources) plus PipeWire default. A choice runs `corebrum voice mic set`. Default clears the stored target.
- `corebrum voice mic list|set|clear` stores `mic=` under `speech.conf` in the user state directory. Empty means the PipeWire default. `corebrum voice hear` and Control+Space pass `pw-record --target` when that value is set.
- Empty or silent recordings tell the operator to check the microphone under Setup → Voice.
- Speech recognition stays Ubuntu `pocketsphinx` and `pocketsphinx-en-us`. No new apt repository, no cloud STT, no wake word, and no ElevenLabs.
- Recording uses `pw-record -n <samples>` when that option exists (PipeWire 1.2+). On Ubuntu 24.04 PipeWire 1.0.5, `-n` is absent, so fixed-length hear uses `timeout`, and Control+Space runs `pw-record` as a child of the owner script with a 60s watchdog. Control+Space stop signals the owner session (not only its process group) so the recorder actually ends and finish can notify.

## Consequences

Typing voice or microphone at Super+Space finds the Voice row. Hear once and Install recognition open a terminal through `corebrum-terminal`. Operators can fix a wrong default mic without learning `pw-dump`. Accuracy remains pocketsphinx-limited until Ubuntu ships a stronger on-device recognizer. On noble, an earlier `-n`-only recorder produced empty WAVs and looked like a missing mic; the timeout path fixes that.
