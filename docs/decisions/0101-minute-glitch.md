# 0101. Glitch once a minute

Date: 2026-10-30
Status: Accepted

## Context

Decision 0100 starts the login and lock glitch at each minute and each half-minute of the local clock. On a desk of machines that is twice a minute, and the picture starts to feel like a timer.

## Decision

- The burst still lasts 1.2 seconds and still follows the local system clock. It starts when the seconds are zero. The half-minute is quiet.
- A screen that appears within 200 milliseconds of that minute joins the burst. Otherwise it waits for the next minute.
- Login and the gtklock module keep the same period, now 60 seconds.

## Consequences

After `sudo corebrum install desktop`, the next Super+Escape and the next greetd start glitch on the minute. Machines in the same time zone with synchronized clocks still glitch together. A lock or login that is already up keeps the previous timing until the next one.
