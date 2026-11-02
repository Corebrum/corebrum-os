# 0109. Install every node-datachannel native copy

Date: 2026-11-02
Status: Accepted

## Context

`corebrum-synapse-install.sh` runs after `pnpm install --ignore-scripts` and downloads the `node-datachannel` prebuild so `synapse connect` can open WebRTC. pnpm kept more than one version under `node_modules/.pnpm` (0.12 beside 0.25). The installer used `find … -print -quit`, saw the older copy that already had a `.node`, and skipped the download. `comms.js` loads the 0.25 package, crashed immediately, and Corebrum Cloud presence stayed offline after a Synapse update.

## Decision

Walk every `node_modules/node-datachannel/package.json` under the Synapse checkout. For each copy that fails `require('node-datachannel')`, run `prebuild-install -r napi` and confirm the native binary loads. Do not stop at the first package.

## Consequences

Updates that rebuild Synapse repair every broken native copy. A unit test builds a fake pnpm tree with a healthy 0.12 and a broken 0.25 and checks that 0.25 gets a binary.
