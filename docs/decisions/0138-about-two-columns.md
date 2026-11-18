# 0138. About in two columns

Date: 2026-11-17
Status: Accepted

## Context

`0110` opens About in a floating Kitty window that Sway sizes to 920×520. After `0123` added the banner, the card was about 33 rows in one column, and that window shows about 27 rows of Noto Sans Mono 12. The operator had to scroll to read the Update row.

## Decision

- The About window draws Hardware beside Software, with Age / Uptime / Update centered below both and the banner centered above. With Display and Swap present the card is 24 rows by 118 columns.
- `corebrum-about open` starts Kitty with `initial_window_width=120c`, `initial_window_height=26c`, and `remember_window_size=no`. Sway only floats and centers `org.corebrum.about`. A Sway `resize set` did not hold: Kitty reopens at the size saved in `~/.cache/kitty/main.json`, and Sway keeps a floating window at the size the client asks for. Sizing in cells also fits whatever the font measures. On the reference Jetson AGX Thor at 1920×1080 the window is about 1205×499.
- Every box is 58 columns, closed on the right. A value longer than the box is cut and ends with `…`.
- When the window is narrower than 118 columns, the one-column card is drawn. When the window is also too short for that card, the banner is dropped, so a 920×520 window (90 columns by 27 rows) shows every row without scrolling. The window redraws when its size changes. It does not read the machine again.
- A running session keeps the old `resize set 920 520` rule until Sway reloads `/etc/corebrum/sway/config`. That rule forces the old size, and the card then uses the fallback above.
- `corebrum about` keeps the one-column card. `corebrum-about columns` prints the two-column card for tests.

## Consequences

The About window no longer scrolls on a 1920×1080 display. On a display narrower than 120 cells, Sway shrinks the window, and the one-column card scrolls again. The About window does not change the size Kitty saves for other terminals. The `0123` note that the `0110` window size still fits no longer holds.
