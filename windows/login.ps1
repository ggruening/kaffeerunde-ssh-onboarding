param(
    [switch]$UseAgent,
    [switch]$UnencryptedEphemeralKey
)

$ErrorActionPreference = "Stop"

function Show-KoPrerequisiteHelp {
    param([string[]]$Missing)

    Write-Host ""
    Write-Host "== missing prerequisites =="
    foreach ($item in $Missing) {
        Write-Host "MISSING | $item"
    }

    Write-Host ""
    Write-Host "== install hints =="

    if ($Missing -contains "step.exe") {
        Write-Host ""
        Write-Host "Smallstep step CLI is missing."
        Write-Host "Recommended if winget is available:"
        Write-Host ""
        Write-Host "  winget install -e --id Smallstep.step"
        Write-Host ""
        Write-Host "Then open a new PowerShell or verify PATH with:"
        Write-Host ""
        Write-Host "  step version"
        Write-Host "  where.exe step"
    }

    if ($Missing -contains "ssh.exe" -or $Missing -contains "ssh-add.exe") {
        Write-Host ""
        Write-Host "Windows OpenSSH Client tools are missing."
        Write-Host "Install OpenSSH Client from Settings:"
        Write-Host ""
        Write-Host "  Settings -> Apps -> Optional Features -> Add an optional feature -> OpenSSH Client"
        Write-Host ""
        Write-Host "If you have administrator rights, you may also use:"
        Write-Host ""
        Write-Host "  Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0"
    }

    Write-Host ""
    Write-Host "After installing the missing prerequisites, run:"
    Write-Host ""
    Write-Host "  .\windows\login.ps1"
}

function Show-KoAgentHelp {
    Write-Host ""
    Write-Host "== ssh-agent help =="
    Write-Host "The optional Windows ssh-agent mode requires the Windows OpenSSH ssh-agent service."
    Write-Host "This may require administrator rights depending on the machine policy."
    Write-Host ""
    Write-Host "Agentless mode does not require this service:"
    Write-Host ""
    Write-Host "  .\windows\login.ps1"
    Write-Host ""
    Write-Host "Only use agent mode explicitly:"
    Write-Host ""
    Write-Host "  .\windows\login.ps1 -UseAgent"
}

function Get-KoRepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-KoHome {
    if ($env:KO_USER_HOME) {
        return $env:KO_USER_HOME
    }
    return $HOME
}

function Get-KoLocalAppData {
    if ($env:KO_LOCALAPPDATA) {
        return $env:KO_LOCALAPPDATA
    }
    if ($env:LOCALAPPDATA) {
        return $env:LOCALAPPDATA
    }
    return (Join-Path (Get-KoHome) "AppData\Local")
}

function Format-KoPublicPath {
    param([string]$Value)

    $homePath = [Regex]::Escape((Get-KoHome))
    $repoRoot = [Regex]::Escape((Get-KoRepoRoot))

    $out = $Value
    if ($homePath) {
        $out = $out -replace $homePath, "<home>"
    }
    if ($repoRoot) {
        $out = $out -replace $repoRoot, "<repo>"
    }
    return $out
}

$KoProjectPrefix = if ($env:KO_PROJECT_PREFIX) { $env:KO_PROJECT_PREFIX } else { "kaffeerunde" }
$KoAdminUser = if ($env:KO_ADMIN_USER) { $env:KO_ADMIN_USER } else { "ops" }

$KoStepCaUrl = if ($env:KO_STEP_CA_URL) { $env:KO_STEP_CA_URL } else { "https://serverauth.kaffeerunde.todopc.de" }
$KoStepCaFingerprint = if ($env:KO_STEP_CA_FINGERPRINT) { $env:KO_STEP_CA_FINGERPRINT } else { "96fdff658e0508991480ce131a8ed2d89f5e09aecfc41292d6592776c53022b6" }
$KoStepProvisioner = if ($env:KO_STEP_PROVISIONER) { $env:KO_STEP_PROVISIONER } else { "ops-ssh-jwk" }

$KoHome = Get-KoHome
$KoLocalAppData = Get-KoLocalAppData
$KoClientRoot = if ($env:KO_CLIENT_ROOT) { $env:KO_CLIENT_ROOT } else { Join-Path $KoLocalAppData "$KoProjectPrefix-ssh" }
$KoStepPath = if ($env:KO_STEPPATH) { $env:KO_STEPPATH } else { Join-Path $KoClientRoot "step" }
$KoIdentityFile = if ($env:KO_IDENTITY_FILE) { $env:KO_IDENTITY_FILE } else { Join-Path $KoClientRoot "id_kaffeerunde_ops" }
$KoCertificateFile = if ($env:KO_CERTIFICATE_FILE) { $env:KO_CERTIFICATE_FILE } else { "$KoIdentityFile-cert.pub" }

$missingPrereqs = New-Object System.Collections.Generic.List[string]
foreach ($bin in @("ssh.exe", "step.exe")) {
    if ($null -eq (Get-Command $bin -ErrorAction SilentlyContinue)) {
        $missingPrereqs.Add($bin)
    }
}
if ($UseAgent -and $null -eq (Get-Command "ssh-add.exe" -ErrorAction SilentlyContinue)) {
    $missingPrereqs.Add("ssh-add.exe")
}

if ($missingPrereqs.Count -gt 0) {
    Show-KoPrerequisiteHelp -Missing $missingPrereqs.ToArray()
    Write-Host ""
    Write-Host "== result =="
    Write-Host "FAIL | Windows login cannot continue until prerequisites are installed"
    exit 1
}

New-Item -ItemType Directory -Force -Path $KoClientRoot | Out-Null
New-Item -ItemType Directory -Force -Path $KoStepPath | Out-Null

$env:STEPPATH = $KoStepPath

Write-Host ""
Write-Host "== step bootstrap =="

$defaultsPath = Join-Path $KoStepPath "config\defaults.json"
if (-not (Test-Path $defaultsPath)) {
    step ca bootstrap --ca-url $KoStepCaUrl --fingerprint $KoStepCaFingerprint
}
else {
    Write-Host "OK | step defaults already present"
}

if ($UseAgent) {
    Write-Host ""
    Write-Host "== ssh-agent service =="

    $agentService = Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
    if ($null -eq $agentService) {
        Write-Host "FAIL | Windows OpenSSH ssh-agent service not found"
        Show-KoAgentHelp
        Write-Host ""
        Write-Host "== result =="
        Write-Host "FAIL | Windows login cannot continue in agent mode"
        exit 1
    }

    if ($agentService.Status -ne "Running") {
        try {
            Start-Service -Name "ssh-agent"
            Write-Host "OK | started ssh-agent service"
        }
        catch {
            Write-Host "FAIL | could not start ssh-agent service"
            Show-KoAgentHelp
            Write-Host ""
            Write-Host "== result =="
            Write-Host "FAIL | Windows login cannot continue in agent mode"
            exit 1
        }
    }
    else {
        Write-Host "OK | ssh-agent service already running"
    }

    Write-Host ""
    Write-Host "== step ssh login =="
    step ssh login $KoAdminUser --provisioner $KoStepProvisioner

    Write-Host ""
    Write-Host "== loaded identities in Windows ssh-agent =="
    ssh-add -l

    Write-Host ""
    Write-Host "== result =="
    Write-Host "OK | Windows login completed in agent mode"
    Write-Host "NEXT | ssh $KoProjectPrefix-apps-01"
    exit 0
}

Write-Host ""
Write-Host "== step ssh certificate file mode =="
Write-Host "INFO | default Windows mode does not require the Windows ssh-agent service"
Write-Host "INFO | identity file: $(Format-KoPublicPath $KoIdentityFile)"
Write-Host "INFO | certificate file: $(Format-KoPublicPath $KoCertificateFile)"

$stepArgs = @(
    "ssh",
    "certificate",
    $KoAdminUser,
    $KoIdentityFile,
    "--provisioner",
    $KoStepProvisioner,
    "--no-agent",
    "--force",
    "--kty",
    "OKP",
    "--curve",
    "Ed25519"
)

if ($UnencryptedEphemeralKey) {
    Write-Host ""
    Write-Host "WARN | using unencrypted ephemeral private key because -UnencryptedEphemeralKey was set"
    Write-Host "WARN | use only on trusted short-lived sessions and run .\windows\cleanup.ps1 afterwards"
    $stepArgs += @("--no-password", "--insecure")
}

& step @stepArgs

if (-not (Test-Path $KoIdentityFile)) {
    Write-Host "FAIL | identity file was not created: $(Format-KoPublicPath $KoIdentityFile)"
    exit 1
}
if (-not (Test-Path $KoCertificateFile)) {
    Write-Host "FAIL | certificate file was not created: $(Format-KoPublicPath $KoCertificateFile)"
    exit 1
}

Write-Host ""
Write-Host "== generated SSH certificate files =="
Write-Host "OK | identity file exists: $(Format-KoPublicPath $KoIdentityFile)"
Write-Host "OK | certificate file exists: $(Format-KoPublicPath $KoCertificateFile)"

Write-Host ""
Write-Host "== result =="
Write-Host "OK | Windows login completed in agentless file mode"
Write-Host "NEXT | ssh $KoProjectPrefix-apps-01"
