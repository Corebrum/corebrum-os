# 0111. Right arrow opens a Super+Space submenu

Date: 2026-11-02
Status: Accepted

## Context

`0108` opens a group with Enter and goes up with Backspace or Left when the search box is empty. Operators also expect Right to move into a submenu the same way Left moves out.

## Decision

- With an empty search box, Right or keypad Right on a navigable row opens that submenu in the same window.
- Right does not launch a leaf. Enter still opens a submenu or launches the selected leaf.
- A non-empty search box leaves Right to the text field so the caret can move.

## Consequences

Left and Right are a pair for menu depth. Getting Started and the keybindings list mention Right with Enter.
