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
```

Private hosts are reached via `kaffeerunde-mgmt-01` as `ProxyJump`.

## Unix usage

```sh
git clone <repo-url>
cd kaffeerunde-ssh-onboarding

./unix/install.sh
./unix/login.sh

ssh kaffeerunde-apps-01
```

`./unix/login.sh` asks for the Smallstep provisioner password. Do not pipe this command through log sanitizers, because password prompts may become unusable.

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
```
