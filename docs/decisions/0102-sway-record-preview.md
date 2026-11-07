# 0102. Sway places the recording camera

Date: 2026-10-30
Status: Accepted

## Context

Super+Print records a selected area and can open a camera window inside it. Decision 0040 moved that window with `hyprctl`. Decision 0080 replaced the session with Sway. Sway floats `corebrum-camera` in the middle of the output. The recorder still asked `hyprctl` for the window, that command is not installed, and after a few seconds the recorder closed the preview and recorded the screen alone. The webcam picture never entered the selected rectangle, so it was absent from the `.mp4`.

`wf-recorder` records the rectangle from `slurp`. The camera is part of that file when its window sits inside the rectangle. Sway 1.9 accepts `move absolute position` in output coordinates, which are the same coordinates `slurp` prints.

## Decision

- When `swaymsg` is on `PATH`, the recorder moves `app_id="org.corebrum.camera"` to the bottom-right of the selection and sizes it to 320×180 before `wf-recorder` starts. The GTK preview uses `Gtk.Application(application_id="org.corebrum.camera")` so Sway's `app_id` criteria match. Placement retries until `get_tree` finds the `Camera` window at the selection corner (sticky is applied but is not required to pass the check). If the preview process is still running and the window is visible, recording continues instead of closing the preview. Stop closes that window with `swaymsg kill`.
- The `hyprctl` move and close remain for a session that still has Hyprland and no `swaymsg`.

## Consequences

After the recorder script is installed, the next Super+Print puts the webcam or RealSense picture in the bottom-right of the selection, and that picture is in the `.mp4`. A recording that is already running keeps the previous placement.

Super+Shift+Print runs `corebrum-record stop`, which touches a stop-request file, sends `SIGUSR1` to the blocking `corebrum-record start` process, and sends `SIGINT` to `wf-recorder`. That start process finalizes the file and shows **Recording saved in Videos.** A stop pressed while fuzzel, slurp, or the camera is still starting is **queued** until `wf-recorder` is running or setup aborts; it must not clear the flag early. Mako shows **Recording. Press Super+Alt+Shift+P to stop.** when capture actually starts (Super+Option+Shift+P on a Mac keyboard). A stop chord pressed before that message is ignored so setup is not cancelled. **Super+Alt+P while `wf-recorder` is already running** also stops. Super+Print and Super+Shift+Print remain alternate bindings. Opening the `.mp4` before the saved toast can show an unsupported MIME type in Firefox because the `moov` atom is still being written. A missing overlay is reported after save, not at record start.
