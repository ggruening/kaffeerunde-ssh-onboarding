# Windows onboarding notes

## Target

The Windows path targets PowerShell with Windows OpenSSH, not PuTTY.

The default Windows implementation is agentless. It uses `step ssh certificate --no-agent` to write a short-lived SSH private key and matching certificate under `%LOCALAPPDATA%\kaffeerunde-ssh`. This avoids requiring administrator rights to start or configure the Windows `ssh-agent` service.

## Usage

```powershell
.\windows\install.ps1
.\windows\login.ps1
ssh kaffeerunde-apps-01
```

## Test

```powershell
.\windows\test-empty-profile.ps1
.\windows\test-ssh-aliases.ps1
```

## Client state

By default, generated client state is stored under:

```text
%LOCALAPPDATA%\kaffeerunde-ssh
```

The user OpenSSH config is:

```text
%USERPROFILE%\.ssh\config
```

The installer prepends an `Include` block and creates a timestamped backup.

## Integrity choices

The Windows config also uses:

```sshconfig
StrictHostKeyChecking yes
UpdateHostKeys no
UserKnownHostsFile <generated known_hosts path>
```

The pinned `known_hosts` file comes from the public repository.


## PowerShell Execution Policy

On many Windows systems, local `.ps1` scripts are blocked by the current Execution Policy.

For onboarding, prefer a process-local bypass in the current PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

This does not permanently loosen the user's or machine's policy. It only affects the current PowerShell process.

Alternative one-shot form:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\test-empty-profile.ps1
```

## Installing `step.exe`

If `step.exe` is missing and `winget` is available:

```powershell
winget install -e --id Smallstep.step
```

Then open a new PowerShell or verify PATH:

```powershell
step version
where.exe step
```

The onboarding scripts print these hints when prerequisites are missing.


## Agentless default

Default login:

```powershell
.\windows\login.ps1
```

This creates:

```text
%LOCALAPPDATA%\kaffeerunde-ssh\id_kaffeerunde_ops
%LOCALAPPDATA%\kaffeerunde-ssh\id_kaffeerunde_ops-cert.pub
```

The generated SSH config references those files with:

```sshconfig
IdentityFile <generated-key>
CertificateFile <generated-cert>
IdentitiesOnly yes
```

This mode does not require elevated rights and does not require the Windows `ssh-agent` service.

## Optional agent mode

Agent mode is available but not the default:

```powershell
.\windows\login.ps1 -UseAgent
```

It may require the Windows OpenSSH `ssh-agent` service to be enabled or started, which can require administrator rights depending on machine policy.

## Cleanup after foreign-machine use

```powershell
.\windows\cleanup.ps1
```

This removes `%LOCALAPPDATA%\kaffeerunde-ssh`.


## Required commands for default agentless mode

Default Windows onboarding requires these commands in `PATH`:

```text
ssh.exe
ssh-keygen.exe
step.exe
```

`ssh-add.exe` is only needed for optional agent mode:

```powershell
.\windows\login.ps1 -UseAgent
```


## Passphrase prompts with private hosts

The default Windows mode is agentless and stores a passphrase-protected private key plus a short-lived SSH certificate under:

```text
%LOCALAPPDATA%\kaffeerunde-ssh
```

For public hosts, SSH usually needs to unlock the private key once.

For private hosts reached through `ProxyJump`, native Windows OpenSSH starts one SSH connection to the jump host and another SSH connection to the private target. In agentless mode, both may need to unlock the same encrypted private key. This can result in two passphrase prompts.

This is expected.

Options:

1. Keep the secure default and enter the passphrase twice for private hosts.
2. Use optional agent mode if the Windows OpenSSH `ssh-agent` service is available:

```powershell
.\windows\login.ps1 -UseAgent
```

3. Use the ephemeral unencrypted test mode only for short-lived controlled sessions:

```powershell
.\windows\login.ps1 -UnencryptedEphemeralKey
```

Then clean up afterwards:

```powershell
.\windows\cleanup.ps1
```

Do not rely on unencrypted ephemeral mode as the default for foreign machines.

## Interactive shells

For a normal login shell, use:

```powershell
ssh kaffeerunde-apps-01
```

Do not use this as an interactive shell pattern:

```powershell
ssh kaffeerunde-apps-01 bash
```

When a remote command is supplied, SSH may not allocate an interactive TTY, which can lead to a black screen or a shell without a visible prompt.

If you explicitly want Bash as a login shell, use:

```powershell
ssh -t kaffeerunde-apps-01 bash -l
```

Or use the helper:

```powershell
.\windows\shell.ps1 kaffeerunde-apps-01
```

## Windows test script

The Windows alias test script defaults to interactive mode:

```powershell
.\windows\test-ssh-aliases.ps1
```

In the secure agentless default, this may prompt for the key passphrase, and private hosts may prompt twice.

Batch mode is only useful when no passphrase prompt is needed, for example with optional agent mode or deliberate ephemeral unencrypted test mode:

```powershell
.\windows\test-ssh-aliases.ps1 -Batch
```
