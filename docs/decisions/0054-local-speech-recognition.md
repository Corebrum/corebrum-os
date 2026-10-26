# 0054. Optional speech recognition uses pocketsphinx

Date: 2026-10-26
Status: Accepted

## Context

Phase 9 accepts local speech that still works without a cloud key, and an optional recognizer that can transcribe the microphone. The build plan names faster-whisper and Vosk. On 2026-10-26 neither name is an Ubuntu package on noble or resolute. `python3-whisper` is a database engine, not a speech recognizer. Resolute publishes `whisper.cpp` 1.8.3+dfsg-2 without a speech model. Both releases publish `pocketsphinx` and `pocketsphinx-en-us`. Noble's recognizer is 0.8.0+real5prealpha+1-15ubuntu5 and its command is `pocketsphinx_continuous`. Resolute's recognizer is 5.0.4-3ubuntu1 and its command is `pocketsphinx`. The English model is installed at `/usr/share/pocketsphinx/model/en-us`.

The desktop profile already records the default microphone with PipeWire. `pw-record --rate 16000 --channels 1 --format s16 -n N` writes a 16 kHz mono WAV and exits 1 after the sample count. The file is still valid. This machine's quiet recording produced an empty transcript from the resolute `pocketsphinx` binary. An eSpeak sample at 22050 Hz was the wrong rate for that model.

ElevenLabs and a wake word stay out of this change.

## Decision

- `corebrum voice hear` records the default microphone with `pw-record` for 5 seconds, or for the given number of seconds from 1 through 30, and prints the transcript.
- The recognizer is Ubuntu `pocketsphinx`. Resolute uses `pocketsphinx single` and reads the JSON `t` field. Noble uses `pocketsphinx_continuous`. Both pass the `pocketsphinx-en-us` acoustic model, language model, and dictionary.
- `corebrum voice hear` does not install packages. `corebrum voice hear --install` installs `pocketsphinx` and `pocketsphinx-en-us` from the Ubuntu archive when those candidates exist, then records. The desktop profile does not install them.
- A missing recognizer does not change `corebrum speak` and does not fail `corebrum doctor`.
- The command does not call a cloud speech API, does not download a model, and does not add a repository.

## Consequences

An operator can transcribe the default microphone after choosing the install. `corebrum speak` keeps working when that install is absent. Wake word, a choice of microphone, and ElevenLabs remain unbuilt. A quiet recording reports that no speech was recognized.
