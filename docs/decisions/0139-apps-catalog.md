# Corebrum Apps catalog v1

Corebrum OS owns the app lifecycle. The marketplace serves the reviewed
catalog at `/apps/v1/catalog.json`. Synapse on Thor resolves to
`/home/nvidia/synapse` via `/etc/corebrum/synapse.root` and retains its Skills
integration.

A developer attaches `corebrum-app.json` and the target archives to a public
GitHub release. Open a pull request against
[`Corebrum/corebrum-skills`](https://github.com/Corebrum/corebrum-skills) with the
release URL and test results. Add the manifest's app record to
`public/apps/v1/catalog.json`. The maintainer reviews the source, artifacts,
license, dependencies, and compatibility evidence before merging.

```json
{
  "schemaVersion": 1,
  "apps": [
    {
      "id": "owner/example",
      "title": "Example",
      "description": "Example depth viewer",
      "source": "https://github.com/owner/example",
      "license": "MIT",
      "interface": "terminal",
      "tags": ["RealSense"],
      "releases": [
        {
          "version": "1.0.0",
          "entry": "run",
          "targets": [
            {
              "ubuntu": "24.04",
              "arch": "arm64",
              "hardware": ["Tested camera and host"],
              "requirements": ["Host runtime requirements"],
              "commands": ["python3"],
              "url": "https://github.com/owner/example/releases/download/v1.0.0/example.tar.gz",
              "sha256": "<64 lowercase hex characters>"
            }
          ]
        }
      ]
    }
  ]
}
```

Release archives are gzip-compressed tar files with regular files and directories.
The entry point is executable and runs from the extracted app directory. An
optional release-level `requirementsFile` points to pinned, hashed Python
requirements bundled with a `wheelhouse` directory. Use wheel requirements
without direct URLs, recursive includes, or index options. The host needs the
Ubuntu `python3-venv` package for this format. List additional prerequisites in
the target and have the launch script report hardware or runtime failures.

The CLI verifies the catalog-selected SHA-256 before extraction and activates
the release after setup. Data lives under
`${XDG_DATA_HOME:-$HOME/.local/share}/corebrum/apps`. Removing an app removes all
of its installed releases. Set `COREBRUM_APPS_CATALOG` to a local absolute JSON
path or an HTTPS catalog URL when testing. Installed apps run with the
operator's account permissions.

Hardware compatibility requires a tested release on the named Ubuntu,
architecture, and device combination.

Before merging, run the marketplace build and exercise the proposed catalog
on each declared host. Point `COREBRUM_APPS_CATALOG` at the local candidate
catalog and use `corebrum apps search`, `info`, `install`, `run`, and `remove`
to check the release.

## Verification

The Apps unit tests exercise compatibility selection, archive path validation,
install, reinstall, update, rollback on a corrupt artifact or missing entry
point, offline launch, and removal. The existing CLI unit and smoke checks
and production builds for the marketplace and website passed on Thor.
Synapse's local Skills listing also ran.

The catalog starts empty. The source code for `realsense-ascii`, `boxes`, and
`realsense-vlm` uses the same MIT license as Corebrum OS. Third-party models
and dependencies retain their own terms. Pilot acceptance still requires
versioned release artifacts and testing on each declared target. Boxes needs
its model and CUDA Python stack packaged or documented as host requirements.
The CUDA VLM also needs the Jetson-specific PyTorch and zero-copy RealSense
builds.
