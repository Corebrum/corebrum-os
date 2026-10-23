# 0032. Ollama is a Super+Space install

Date: 2026-10-23
Status: Accepted

## Context

The operator asked for Ollama as an optional menu install so a user can run local inference models, and named the official command `curl -fsSL https://ollama.com/install.sh | sh`.

On 2026-10-23 `apt-cache policy ollama` on resolute had no candidate. The Ubuntu archive does not publish an `ollama` package for this install to use. The script at `https://ollama.com/install.sh` was fetched and read the same day. On Linux it downloads `ollama-linux-<arch>` from `https://ollama.com/download`, installs the binary and libraries under `/usr/local` or `/usr`, creates an `ollama` system user, and installs `/etc/systemd/system/ollama.service` running `ollama serve` on `127.0.0.1:11434`. It does not add an Ollama apt repository. Current downloads are `.tar.zst`, and the script stops if `zstd` is missing. Ubuntu publishes `zstd` (`1.5.5+dfsg2-2build1.1` in noble updates, `1.5.7+dfsg-3` on this resolute machine).

If that script finds an NVIDIA GPU and `nvidia-smi` does not report a CUDA version, it adds NVIDIA's CUDA apt repository and installs `cuda-drivers`. That is the upstream script, and it runs only after the user chooses Ollama. Corebrum does not add that repository itself. A machine with no NVIDIA or AMD GPU, or with a working NVIDIA driver, skips that step. AMD machines get an extra Ollama ROCm archive from the same download host.

## Decision

- Super+Space shows `Ollama   install` until the `ollama` command is on `PATH`.
- Choosing it installs Ubuntu `zstd` when that command is missing, then runs `curl -fsSL https://ollama.com/install.sh | sh` as the user. The script asks for sudo itself.
- After `ollama` is present, the same entry lists models from `ollama list` and a `Run another model` row. Choosing a name runs `ollama run <name>` in a terminal. A name may contain letters, numbers, and `.`, `_`, `:`, `/`, `-`.
- The desktop profile does not install Ollama. Uninstalling Corebrum removes the menu command and leaves the Ollama binary, user, and service in place.

## Consequences

- A later desktop install is required before Super+Space shows the entry.
- On an NVIDIA machine without a driver, the official script can add NVIDIA's CUDA apt repository. That is outside the Hyprland PPA and the ROS apt repository, and it happens only because the user chose this installer.
- The menu does not pull a model during install. The first `ollama run` downloads the model the user named.
