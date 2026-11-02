# 0107. Remote desktop viewers show Corebrum

Date: 2026-11-02
Status: Accepted

## Context

macOS Screen Sharing and other VNC clients show the RFB desktop name in the window title. Ubuntu `wayvnc` 0.7.2 and 0.9.1 hardcode that name as `WayVNC`. Upstream `--name` arrived in wayvnc 0.10, which is not in the Ubuntu 24.04 or 26.04 archives Corebrum uses. Remote desktop already routes every client through `corebrum-vnc-proxy`.

## Decision

After the password handshake, the proxy reads wayvnc's ServerInit and rewrites the desktop name to `Corebrum` before the viewer sees it. It does not depend on a newer wayvnc package.

## Consequences

A Mac Screen Sharing window title says Corebrum instead of WayVNC. TigerVNC and Remmina show the same name. Restart Remote desktop after installing this change so the running proxy picks it up.
