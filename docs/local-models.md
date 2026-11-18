# Local AI models

Corebrum OS can run AI models on the robot's own computer with Ollama. A local model works without a cloud API key, and it keeps camera frames and prompts on the machine. The same Ollama server works for the AI agent CLIs, for Corebrum Synapse, and for `ollama run` in a terminal.

## Install Ollama

Super+Space **AI Agents** lists Ollama with the publisher CLIs. Typing `ollama` at the Super+Space prompt finds the same row. The row says `install` until the `ollama` command is present. Choosing it installs Ubuntu `zstd` when that command is missing, then runs the official installer from `https://ollama.com/install.sh`. The installer adds the `ollama` systemd service. The desktop profile does not install Ollama. See `docs/decisions/0032-ollama-menu.md` and `docs/decisions/0131-ollama-ai-agents-menu.md`.

On a headless server, run the same official installer in a terminal:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

## Pull a model

After the install, the Ollama row lists the models already pulled and runs the chosen one with `ollama run`. **Run another model** asks for a model name. In a terminal:

```bash
ollama pull qwen3-vl:8b-instruct     # chat, tools, and camera vision
ollama list                          # models on this machine
curl -s http://localhost:11434/api/tags   # the server answers on port 11434
```

Pick a model the computer can hold in memory:

| Computer | Starting model | Notes |
|----------|----------------|-------|
| NVIDIA Jetson Orin, or x86-64 with an NVIDIA GPU | `qwen3-vl:8b-instruct` | One model for driving, missions, and camera questions. |
| Raspberry Pi, or x86-64 without a GPU | `qwen3-vl:2b` | Smaller and slower to call tools. Expect slow replies on a CPU. |
| Another machine on the LAN | Any model that machine can hold | Point the agent at `http://<host>:11434` instead of `localhost`. |

Use an `-instruct` tag for tool calling. The bare `qwen3-vl:8b` tag is a thinking build that can spend its whole reply on hidden reasoning and return no tool calls.

Agent CLIs send long prompts. Ollama's integration docs recommend a context window of at least 64,000 tokens for coding agents. Set it on the service, then restart it:

```bash
sudo systemctl edit ollama
# add:
# [Service]
# Environment="OLLAMA_CONTEXT_LENGTH=64000"
sudo systemctl restart ollama
```

A larger context needs more memory. On a Jetson Orin Nano or a Raspberry Pi, use a smaller model with that larger context.

## Point an AI agent at Ollama

Each CLI from Super+Space AI Agents keeps its Corebrum Synapse config when it uses Ollama, so the ROS 2 tools stay the same. Only the model changes.

| CLI | Local models |
|-----|--------------|
| Claude Code CLI | Yes, through Ollama's Anthropic-compatible API |
| Codex CLI | Yes, with `--oss` |
| Hermes CLI | Yes |
| OpenClaw | Yes |
| Antigravity CLI, Cursor CLI, Grok CLI | No. These use their publisher's cloud and sign-in. |

Ollama's own docs for each integration are at `https://docs.ollama.com/integrations`. The commands below follow those docs and each publisher's docs. Check `--help` on the installed version when a flag is refused.

### Claude Code CLI

```bash
ollama launch claude
```

`ollama launch` asks for a model, sets Claude Code to use the local server, and starts it. `ollama launch claude --model qwen3-vl:8b-instruct --yes` skips the questions.

### Codex CLI

```bash
ollama launch codex
# or, without ollama launch:
codex --oss -m qwen3-vl:8b-instruct
```

`ollama launch codex --config` writes the setting without starting Codex.

### Hermes CLI

```bash
hermes model
```

Choose Ollama, or a custom OpenAI-compatible endpoint at `http://127.0.0.1:11434/v1`, then pick the model. The choice is saved in `~/.hermes/config.yaml`. `synapse hermes setup` keeps the Corebrum Synapse MCP server in that same file.

### OpenClaw

```bash
openclaw onboard
openclaw models list --provider ollama
```

Choose Ollama, then **Local only**. Onboarding asks for the Ollama address, lists the models on that server, and pulls the chosen model when it is missing. For a robot that describes the camera, the model's input must list `text+image`. The Corebrum Synapse guide below covers that check.

## Drive the robot with a local model

Corebrum Synapse runs the robot control loop: ROS 2 tools, safety limits, and skills. With OpenClaw or Hermes on Ollama, that loop needs no OpenAI, Anthropic, or Google key. `synapse init` asks for an OpenAI key, and that step can be skipped.

The Corebrum Synapse guide covers model picks for tool calling and vision, the multimodal check in OpenClaw, the in-plugin describer for a text-only model, the Follow Me skill on Ollama, local memory embeddings, and troubleshooting:

https://github.com/Corebrum/corebrum-synapse/blob/main/docs/local-vlm.md

## What is not done

The desktop profile does not install Ollama or pull a model. The OS does not change an agent's model provider on its own. Antigravity CLI, Cursor CLI, and Grok CLI still sign in with their publisher on first launch.
