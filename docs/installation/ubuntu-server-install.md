# Ubuntu Server Installation for Corebrum OS

This guide prepares an Ubuntu Server 24.04 LTS (Noble Numbat) or Ubuntu Server 26.04 LTS (Resolute) machine for Corebrum OS, from installation through repository access and optional Cursor CLI setup. The installation selections below apply to both releases.

## Before you begin

- Prepare a bootable USB with the Ubuntu Server 24.04 LTS or 26.04 LTS installer for your machine's architecture, available from [Ubuntu Server downloads](https://ubuntu.com/download/server).
- Connect a monitor, keyboard, and Ethernet cable to the server.
- Have a Mac on the same network and a GitHub account with access to the repository.
- Back up anything needed from the target disk: the entire-disk installation erases its existing contents.

Examples use `SERVER_USER` for the Ubuntu username and `SERVER_IP` for the server's address. Replace these placeholders with your own values before running commands. Run commands on the Ubuntu server unless a section explicitly says to use the Mac.

## 1. Install Ubuntu Server

Boot the server from the installation USB and start the Ubuntu Server installer for 24.04 or 26.04. The selections below are the same on both releases. Installer wording can vary slightly between those releases and between point releases.

| Screen | Selection |
| --- | --- |
| Language | English |
| Keyboard configuration | English (US), with the default US variant |
| Installation type | Ubuntu Server (minimized) |
| Network configuration | Use the connected Ethernet interface with automatic IPv4 configuration (DHCP) |
| Proxy configuration | Leave blank |
| Ubuntu archive mirror | Keep the default mirror; allow its connectivity check to finish |
| Guided storage | Use an entire disk; select the intended installation disk |
| LVM | Enable the option to set up the disk as an LVM group |
| Encryption | Leave LUKS encryption disabled |
| Storage summary | Review the selected disk and proposed layout, then choose Done and confirm installation |
| Profile setup | Enter a display name, server name, username, and strong password |
| Ubuntu Pro | Skip for now |
| SSH configuration | Install OpenSSH server and allow password authentication for the initial connection |
| Featured server snaps | Leave all selections unchecked |

Keep a record of the username and server name you choose. The username is used for SSH and administrative commands; it is separate from your GitHub username.

Wait until installation finishes, then select **Reboot Now**. When prompted, remove the installation USB and press Enter. Let the machine boot from its installed system, then log in with the account created during installation.

## 2. Update the operating system

At the Ubuntu console, refresh package information and install available updates:

```bash
sudo apt update
sudo apt upgrade -y
```

Install the tools needed for repository access and remote administration:

```bash
sudo apt install -y curl git ca-certificates openssh-server
```

Enable SSH at startup and start it now:

```bash
sudo systemctl enable --now ssh
sudo systemctl status ssh --no-pager
```

Ubuntu 24.04 and 26.04 can use socket activation for SSH, so also check the listening socket if the service is idle:

```bash
sudo systemctl status ssh.socket --no-pager
```

If updates request a restart, reboot and log in again:

```bash
sudo reboot
```

See Ubuntu's [OpenSSH server documentation](https://ubuntu.com/server/docs/how-to/security/openssh-server/) for service and configuration details.

## 3. Connect from your Mac

On the Ubuntu console, find the server's IP addresses:

```bash
ip -4 address
```

Use the IPv4 address shown for the connected Ethernet interface, excluding the `/prefix` suffix. Do not use the loopback address `127.0.0.1`. DHCP addresses may change; a router DHCP reservation can keep the address consistent.

On your **Mac**, open Terminal and connect:

```bash
ssh SERVER_USER@SERVER_IP
```

On the first connection, compare the displayed host fingerprint with the server's host key fingerprint, which you can display at its local console:

```bash
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Accept the host key after confirming the match, then enter your Ubuntu account password. Password input is not displayed while you type. Commands entered in this SSH session now run on Ubuntu.

If the connection fails, confirm the address, network connectivity, and SSH status. If a firewall is already enabled, ensure it allows SSH. Initial password authentication is intended for setup on a trusted network; configure and test key-based access before disabling password access later.

## 4. Create a GitHub SSH key on Ubuntu

Generate this key on the **Ubuntu server**, because the server will clone the repository. It is separate from any key used to log in from your Mac.

Check for existing keys first:

```bash
ls -la ~/.ssh
```

If `id_ed25519` already exists, reuse the appropriate existing key or choose a different filename and adjust the following commands. Do not overwrite a key you still need.

Create an Ed25519 key with a generic comment:

```bash
ssh-keygen -t ed25519 -C "corebrum-os-server"
```

Accept the default path (`~/.ssh/id_ed25519`) if it is unused. Choose a passphrase when prompted. The comment labels the key and does not need to be an email address.

Start an SSH agent for this shell and load the key:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

You may need to load the key again after opening a new session or rebooting. Display its public half:

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy the entire single line beginning with `ssh-ed25519`. Keep the private file, `~/.ssh/id_ed25519`, on the Ubuntu server; only the `.pub` file is shared.

## 5. Add the public key to GitHub

In your **Mac browser**:

1. Sign in to GitHub.
2. Open **Settings → SSH and GPG keys → New SSH key**.
3. Enter a descriptive title, such as `Corebrum OS server`.
4. Select **Authentication Key** as the key type.
5. Paste the public key copied from Ubuntu and save it.
6. Complete any account confirmation GitHub requests.

If the repository belongs to an organization using SSO, authorize the key for that organization when required. See GitHub's [instructions for adding an SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account).

Back in the **Ubuntu SSH session**, test access:

```bash
ssh -T git@github.com
```

On first use, compare the presented fingerprint with [GitHub's published SSH fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints) before accepting it.

Success produces a greeting containing your GitHub username and confirms authentication. GitHub does not provide an interactive shell, and this successful test normally exits with status `1`. See [GitHub's SSH connection test documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection).

## 6. Clone the Corebrum OS repository

On Ubuntu, create a workspace:

```bash
mkdir -p ~/projects
cd ~/projects
```

Replace `OWNER` and `REPOSITORY` with the values from the repository's **Code → SSH** clone URL. The repository may be named `corebrum-os`; its owner is intentionally left unspecified here.

```bash
git clone git@github.com:OWNER/REPOSITORY.git corebrum-os
cd corebrum-os
git remote -v
```

Your GitHub account must have access to the repository. If cloning fails after the authentication test succeeds, check the owner, repository name, organization authorization, and repository permissions.

Continue with the repository's README and setup instructions for installing Corebrum OS. This guide prepares the host and retrieves the source; application-specific setup belongs to the repository's own instructions.

## 7. Optional: Install Cursor CLI on the server

Cursor CLI runs an AI coding agent in the Ubuntu terminal. Install it on **Ubuntu**, within the SSH session, as your normal user. This is separate from installing the Cursor desktop application on your Mac.

The official installer command is:

```bash
curl https://cursor.com/install -fsS | bash
```

Follow any PATH instructions printed by the installer. If needed, make its default user-local binary directory available in the current shell:

```bash
export PATH="$HOME/.local/bin:$PATH"
agent --version
```

For future Bash sessions, add that export to `~/.bashrc` once if the installer has not already configured the PATH. Current documentation uses `agent`; older releases use `cursor-agent`. If only `cursor-agent` is installed, use that command in place of `agent` below or follow the current installation instructions to update.

Source: [Cursor CLI installation](https://cursor.com/docs/cli/installation).

### Authenticate using your Mac browser

In the **Ubuntu SSH session**, start the browser login flow without attempting to launch a browser on the server:

```bash
NO_OPEN_BROWSER=1 agent login
```

Keep this command running. Copy the login URL it prints, open it in your **Mac browser**, and complete authentication with your Cursor account. Return to the Ubuntu terminal and confirm that login completes:

```bash
agent status
```

The CLI stores its credentials on Ubuntu; signing in to Cursor on your Mac alone does not authenticate the server. Account access and available features depend on your Cursor account and plan.

Current Cursor documentation supports printing the login URL with `NO_OPEN_BROWSER=1`. Login behavior can differ between releases. If the browser redirects to `localhost` or `127.0.0.1` and fails, that address refers to the Mac when opened there, not the Ubuntu server. Do not assume the Mac can reach a callback listener on Ubuntu. Use the instructions printed by your installed CLI; if they explicitly require a local callback port, forward that exact port over SSH, or use the documented API-key method below. Do not guess a port or copy a credential file between machines.

### API-key alternative

If browser login cannot complete remotely, create a user API key in your [Cursor dashboard](https://cursor.com/dashboard), under API Keys. In the Ubuntu Bash session, enter it without placing the value directly in shell history:

```bash
read -rsp "Cursor API key: " CURSOR_API_KEY
printf '\n'
export CURSOR_API_KEY
```

The variable applies to this shell and its child processes. Avoid placing the key in the repository or a shared shell configuration. Clear it when finished:

```bash
unset CURSOR_API_KEY
```

Source: [Cursor CLI authentication](https://cursor.com/docs/cli/reference/authentication).

### Start Cursor in the repository

With browser authentication complete, or while `CURSOR_API_KEY` is set, run:

```bash
cd ~/projects/corebrum-os
agent
```

The agent operates on files in the server's working directory using the server account's permissions. Review proposed actions and changes before accepting them. A graphical remote editing workflow from Cursor on the Mac requires a separate remote SSH setup; installing this CLI does not configure that workflow.

## NVIDIA Jetson

NVIDIA's desktop interface has to be turned off before the Corebrum OS desktop can use the display. This applies to every Jetson, including AGX Orin, Orin Nano, and Thor. Run:

```bash
sudo systemctl set-default multi-user.target
sudo reboot
```

Log in again after the reboot, then continue below. Ubuntu Server 24.04 and 26.04 on x86-64 and on other ARM machines keep their existing boot target.

## Ready for Corebrum OS setup

Ubuntu Server is installed and updated, SSH access from the Mac works, GitHub authentication is configured on Ubuntu, and the repository is available at `~/projects/corebrum-os`. Follow the project's README for the next steps.
