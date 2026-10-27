# 0073. AgenticROS clones into the home directory when the sibling is not writable

Date: 2026-10-27
Status: Accepted

## Context

Decision 0041 clones AgenticROS beside the Corebrum checkout. The setup wizard runs that installer as the desktop user. On this machine `/usr/local/bin/corebrum` points at `/root/corebrum-os/scripts/corebrum.sh`, and `/root` is not traversable by that user. `readlink -f` fails, the script treats the checkout as `/usr/local`, and the clone target becomes `/usr/agenticros`. The user cannot create that directory, so the wizard stops with `cannot clone AgenticROS into /usr/agenticros`.

## Decision

- A symlink at the `corebrum` command still names the checkout when the desktop user cannot follow it.
- When the directory beside that checkout is missing or not writable, the clone is `~/agenticros`.
- A writable sibling, and `COREBRUM_AGENTICROS_ROOT`, stay the clone path. An existing checkout is still left in place.

## Consequences

The wizard and Super+Space can install AgenticROS on a machine whose Corebrum tree is not writable by the desktop user. The recorded checkout is still `/etc/corebrum/agenticros.root`. Updates keep using that path.
