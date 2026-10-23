# 0031. The desktop profile installs eSpeak NG

Date: 2026-10-23
Status: Accepted

## Context

The operator asked for `espeak-ng` in the desktop installation, then asked to install `espeak-ng-espeak` instead. Phase 9 in the build plan is the speech service, including `corebrum speak`. That service is not this change.

On 2026-10-23 Launchpad published `espeak-ng-espeak` 1.51+dfsg-12build1 for noble. It is in universe and is architecture-independent. Resolute apt selected 1.52.0+dfsg-5build1. The package depends on `espeak-ng` and installs `/usr/bin/espeak` and `/usr/bin/speak`. On resolute those paths link to `espeak-ng`. The `espeak-ng` package still installs `/usr/bin/espeak-ng` and `/usr/bin/speak-ng`, and it depends on `libespeak-ng1`, `libpcaudio0`, and `libsonic0`.

## Decision

- `corebrum install desktop` installs the Ubuntu `espeak-ng-espeak` package with the rest of `manifests/packages/desktop.txt`.
- Apt also installs `espeak-ng` because `espeak-ng-espeak` depends on it. The manifest does not list `espeak-ng` on its own.
- The installer does not add a repository. It does not install speech recognition, and it does not add a `corebrum speak` command.

## Consequences

A desktop machine can run `espeak` and `espeak-ng` after that install. Uninstall leaves the package in place, as it does for the other Ubuntu desktop packages. The speech service in the build plan is still unbuilt.
