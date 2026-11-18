# Build and publish a Corebrum App

Corebrum Apps are standalone tools that operators install and launch on
Corebrum OS. This guide takes a small terminal app from an executable
launcher to a published [Marketplace listing](https://marketplace.corebrum.com/apps).

## 1. Package your app

In your public GitHub repository, put the files you want to ship in a
staging directory. Include your license and an executable launcher. The
launcher starts from the extracted app directory and receives any arguments
the operator supplies after `corebrum apps run owner/app --`.

For a minimal example, put this launcher in `package/run` and copy your
repository's `LICENSE` into `package/`.

```sh
#!/usr/bin/env sh
printf 'Hello from Corebrum Apps.\n'
for arg in "$@"; do
  printf '%s\n' "$arg"
done
```

Build a gzip-compressed tar archive with the launcher at the archive root.

```sh
chmod +x package/run
cp LICENSE package/
tar -czf example-1.0.0-ubuntu24.04-arm64.tar.gz -C package .
sha256sum example-1.0.0-ubuntu24.04-arm64.tar.gz
```

Use regular files and directories. The installer reserves `.venv` and
`.corebrum.json` at the archive root. Document system, camera, ROS 2, CUDA,
or model prerequisites in your README and give operators an actionable
error if one is missing. The CLI checks declared commands on `PATH`.
Apps install and run with the operator's permissions.

For an app-local Python environment, put compatible wheels under
`wheelhouse/` and a fully pinned, hashed requirements file in the archive.
Set `requirementsFile` on the release to the path of that file. Use
wheel-only requirements and avoid direct URLs, recursive includes, and
index options. The host needs Ubuntu's `python3-venv` package. Verify that
you can redistribute anything you bundle, including models and wheels.

## 2. Describe and upload the release

Save an app record as `corebrum-app.json`. Replace the sample owner, repo,
license, tested hardware, and SHA-256 with your release's values. Use a
lowercase `owner/app` ID and a numeric `MAJOR.MINOR.PATCH` version. Each
target identifies the Ubuntu release and architecture. Verify every hardware
configuration you list.

```json
{
  "id": "owner/example",
  "title": "Example",
  "description": "A minimal terminal app for Corebrum OS.",
  "source": "https://github.com/owner/example",
  "license": "MIT",
  "interface": "terminal",
  "tags": ["Demo"],
  "releases": [
    {
      "version": "1.0.0",
      "entry": "run",
      "targets": [
        {
          "ubuntu": "24.04",
          "arch": "arm64",
          "hardware": ["Replace with your tested host"],
          "requirements": [],
          "commands": ["sh"],
          "url": "https://github.com/owner/example/releases/download/v1.0.0/example-1.0.0-ubuntu24.04-arm64.tar.gz",
          "sha256": "<paste the 64 lowercase hex characters from sha256sum>"
        }
      ]
    }
  ]
}
```

Create a public GitHub release for the tag in the URL and attach the archive
and `corebrum-app.json`. App targets can declare Ubuntu 24.04 or 26.04 and
`amd64` or `arm64`. Release archives may vary by target, with one target
record per Ubuntu and architecture pair. See the
[catalog format](../decisions/0139-apps-catalog.md) and the
[RealSense ASCII release](https://github.com/chrismatthieu/realsense-ascii/releases/tag/corebrum-app-v1.0.0)
for a published example.

## 3. Test the published archive on each target

Build a temporary catalog from the manifest and use it on a supported
Corebrum OS host. Run the commands as your regular user. Use a fresh
`XDG_DATA_HOME` to keep test installs separate from your normal app data.

```sh
(
  set -e
  test_dir="$(mktemp -d)"
  jq -n --slurpfile app corebrum-app.json \
    '{schemaVersion: 1, apps: $app}' > "$test_dir/catalog.json"
  export COREBRUM_APPS_CATALOG="$test_dir/catalog.json"
  export XDG_DATA_HOME="$test_dir/data"

  corebrum apps search example
  corebrum apps info owner/example
  corebrum apps install owner/example@1.0.0
  corebrum apps run owner/example -- hello
  corebrum apps remove owner/example
)
```

Check the real workload on the declared device and note the host, OS,
architecture, attached hardware, and runtime versions. For releases with
external prerequisites, check the launch error on a host where those are
missing.

## 4. Publish the listing

Open [Publish an app](https://marketplace.corebrum.com/publish/app), sign in
with GitHub, and paste the public release URL. The account must have push
access to the repository. The marketplace reads the manifest from that
release and verifies the archive URLs and GitHub-reported SHA-256 digests.
After those checks pass, the listing is immediately visible in the catalog.

To update an existing app, attach a manifest for one new
`MAJOR.MINOR.PATCH` version to its GitHub release. Keep the same app ID and
repository and submit the new release URL. Previously published versions
stay available. Signed-in users can star your app from its listing, and
operators can sort the catalog by stars.
