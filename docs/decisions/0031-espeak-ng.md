# 0031. The desktop profile installs eSpeak NG

Date: 2026-10-23
Status: Accepted

## Context

The operator asked for `espeak-ng` in the desktop installation. Phase 9 in the build plan is the speech service, including `corebrum speak`. That service is not this change.

On 2026-10-23 the Ubuntu archive published `espeak-ng` 1.51+dfsg-12build1 for noble and 1.52.0+dfsg-5build1 for resolute. The resolute package installs `/usr/bin/espeak-ng` and `/usr/bin/speak-ng`. It is in universe and depends on `libespeak-ng1`, `libpcaudio0`, and `libsonic0`.

## Decision

- `corebrum install desktop` installs the Ubuntu `espeak-ng` package with the rest of `manifests/packages/desktop.txt`.
- The installer does not add a repository. It does not install speech recognition, and it does not add a `corebrum speak` command.

## Consequences

A desktop machine can run `espeak-ng` after that install. Uninstall leaves the package in place, as it does for the other Ubuntu desktop packages. The speech service in the build plan is still unbuilt.
