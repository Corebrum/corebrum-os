# 0061. ROS 2 adds a missing Ubuntu updates pocket beside ubuntu.sources

Date: 2026-10-26
Status: Accepted

## Context

Decision 0009 stops `corebrum install ros` when `noble-updates` or `universe` is missing, and it does not edit `/etc/apt/sources.list.d/ubuntu.sources`. The same check on Ubuntu 26.04 looks for `resolute-updates`.

The Ubuntu 26.04 Raspberry Pi image on this machine lists `resolute` and `resolute-security` in `ubuntu.sources`, with components `main restricted universe multiverse`. It does not list `resolute-updates`. The setup wizard stopped with that message before it downloaded ROS 2. `universe` is already enabled. `packages.ros.org` publishes the Resolute `binary-arm64` index, and `eclipse-zenoh` 1.9.0 publishes a `manylinux_2_28_aarch64` wheel.

An x86-64 Ubuntu install that already lists `<codename>-updates` does not need another source entry.

## Decision

- The installer still does not edit `/etc/apt/sources.list.d/ubuntu.sources`, and it still does not run `apt upgrade`.
- `universe` must already appear in the apt source files. If it does not, the install stops.
- When `<codename>-updates` is already present in `/etc/apt/sources.list` or `/etc/apt/sources.list.d`, the installer does not add a source.
- When that pocket is missing, the installer writes `/etc/apt/sources.list.d/corebrum-ubuntu-updates.sources`. The URI, components, and `Signed-By` are copied from the deb822 stanza whose `Suites` entry is the exact Ubuntu codename. The suite in the new file is `<codename>-updates`.
- ROS uninstall removes that Corebrum file. It leaves `ubuntu.sources` and the ROS packages in place.

## Consequences

A machine that already has the updates pocket installs ROS 2 as it did before. The Raspberry Pi image gains the updates pocket without a change to `ubuntu.sources`. Later `apt-get install` of the ROS packages can pull dependency versions from that pocket. That is not an `apt upgrade` of every installed package.
