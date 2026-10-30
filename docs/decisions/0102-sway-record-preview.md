# 0102. Sway places the recording camera

Date: 2026-10-30
Status: Accepted

## Context

Super+Print records a selected area and can open a camera window inside it. Decision 0040 moved that window with `hyprctl`. Decision 0080 replaced the session with Sway. Sway floats `corebrum-camera` in the middle of the output. The recorder still asked `hyprctl` for the window, that command is not installed, and after a few seconds the recorder closed the preview and recorded the screen alone. The webcam picture never entered the selected rectangle, so it was absent from the `.mp4`.

`wf-recorder` records the rectangle from `slurp`. The camera is part of that file when its window sits inside the rectangle. Sway 1.9 accepts `move absolute position` in output coordinates, which are the same coordinates `slurp` prints.

## Decision

- When `swaymsg` is on `PATH`, the recorder moves `app_id="corebrum-camera"` to the bottom-right of the selection and sizes it to 320×180 before `wf-recorder` starts. Stop closes that window with `swaymsg kill`.
- The `hyprctl` move and close remain for a session that still has Hyprland and no `swaymsg`.

## Consequences

After the recorder script is installed, the next Super+Print puts the webcam or RealSense picture in the bottom-right of the selection, and that picture is in the `.mp4`. A recording that is already running keeps the previous placement.
