# kaffeerunde SSH Onboarding

Public SSH client onboarding for the `kaffeerunde` Hetzner stack.

This repository contains only non-secret client material and scripts for setting up SSH access via Smallstep SSH certificates.

## Goal

After onboarding and login:

```sh
ssh kaffeerunde-mgmt-01
ssh kaffeerunde-egress-01
ssh kaffeerunde-auth-01
ssh kaffeerunde-ingress-01
ssh kaffeerunde-apps-01
ssh kaffeerunde-apps-02-ext
ssh kaffeerunde-mail-01-ext

# after using a foreign machine
.\windows\cleanup.ps1
```

Private hosts are reached via `kaffeerunde-mgmt-01` as `ProxyJump`. `kaffeerunde-mail-01-ext` uses the public mail hostname with strict host-key pinning.

## Unix usage

```sh
git clone <repo-url>
cd kaffeerunde-ssh-onboarding

./unix/install.sh
./unix/login.sh

ssh kaffeerunde-apps-01
```

`./unix/login.sh` asks for the Smallstep provisioner password. Do not pipe this command through log sanitizers, because password prompts may become unusable.

## Windows usage

PowerShell with Windows OpenSSH:

```powershell
git clone <repo-url>
cd kaffeerunde-ssh-onboarding

.\windows\install.ps1
.\windows\login.ps1

ssh kaffeerunde-apps-01
```

The Windows path targets Windows OpenSSH, not PuTTY. Windows default is agentless and does not require the Windows `ssh-agent` service.


For an interactive Windows shell helper:

```powershell
.\windows\shell.ps1 kaffeerunde-apps-01
```

For private hosts behind `ProxyJump`, the default agentless Windows mode may ask for the key passphrase twice. This is expected and avoids requiring administrator rights for the Windows `ssh-agent` service.


### Windows prerequisites

If PowerShell blocks scripts, use a process-local bypass in the current session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

If `step.exe` is missing and `winget` is available:

```powershell
winget install -e --id Smallstep.step
```

Then verify:

```powershell
step version
where.exe step
```


## What install does

`./unix/install.sh`:

- creates `~/.config/kaffeerunde-ssh`
- renders OpenSSH client config
- installs pinned `known_hosts`
- prepends an `Include` block to `~/.ssh/config`
- keeps a timestamped backup of the previous SSH config

The generated SSH config uses:

- project-prefixed aliases
- `User ops`
- `ProxyJump kaffeerunde-mgmt-01` for private hosts
- a dedicated `IdentityAgent`
- `IdentityFile none`
- public-key-only auth
- `StrictHostKeyChecking yes`
- `UpdateHostKeys no`
- a repository-provided `known_hosts` file

## What login does

`./unix/login.sh`:

- uses an isolated `STEPPATH`
- starts or reuses a dedicated `ssh-agent`
- runs `step ca bootstrap` if needed
- runs `step ssh login ops --provisioner ops-ssh-jwk`
- loads the resulting short-lived SSH certificate into the dedicated agent

## Test

```sh
./scripts/test-ssh-aliases.sh
```

## Cleanup

```sh
./unix/cleanup.sh
```

This removes the generated client state under `~/.config/kaffeerunde-ssh` and tries to stop the dedicated agent. It does not edit `~/.ssh/config` yet.

## Public repository policy

Allowed:

- public SSH client configuration
- public host aliases
- public CA URL
- CA root fingerprint
- root CA certificate / public trust anchors
- SSH `known_hosts` material
- install/login/cleanup scripts

Forbidden:

- private SSH keys
- breakglass material
- provisioner passwords
- tokens
- backup credentials
- migration host details
- Ansible inventory dumps
- local absolute paths
- operational recovery details

Run before commit or publish:

```sh
./tests/empty-home-unix.sh
./scripts/audit-public-repo.sh

# On Windows PowerShell:
.\windows\test-empty-profile.ps1
```

<!-- apps-02-ext-ssh-healthcheck -->

## apps-02-ext SSH path check

`apps-02-ext` is intentionally reached over the private admin path, not by public-direct SSH:

```text
local client -> kaffeerunde-mgmt-01 -> ingress-01 private IP -> apps-02-ext WireGuard IP
```

Run this after onboarding or after unlocking the local SSH agent:

```sh
./scripts/check-apps02-ssh-path.sh
```

If the first hop fails, unlock or repair the local SSH agent before changing host routing or inventory. If only the final alias fails, inspect the apps-02-ext host key or authorized key state.
