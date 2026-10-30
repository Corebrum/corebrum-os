# 0073. Corebrum Synapse clones into the home directory when the sibling is not writable

Date: 2026-10-27
Status: Accepted

## Context

Decision 0041 clones Corebrum Synapse beside the Corebrum checkout. The setup wizard runs that installer as the desktop user. On this machine `/usr/local/bin/corebrum` points at `/root/corebrum-os/scripts/corebrum.sh`, and `/root` is not traversable by that user. `readlink -f` fails, the script treats the checkout as `/usr/local`, and the clone target becomes `/usr/synapse`. The user cannot create that directory, so the wizard stops with `cannot clone Corebrum Synapse into /usr/synapse`.

## Decision

- A symlink at the `corebrum` command still names the checkout when the desktop user cannot follow it.
- When the directory beside that checkout is missing or not writable, the clone is `~/synapse`.
- A writable sibling, and `COREBRUM_SYNAPSE_ROOT`, stay the clone path. An existing checkout is still left in place.

## Consequences

The wizard and Super+Space can install Corebrum Synapse on a machine whose Corebrum tree is not writable by the desktop user. The recorded checkout is still `/etc/corebrum/synapse.root`. Updates keep using that path.
