$ErrorActionPreference = "Stop"

function Get-KoRepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Convert-ToOpenSshPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ($Path -replace "\\", "/")
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

    if ($Missing -contains "ssh.exe" -or $Missing -contains "ssh-keygen.exe" -or $Missing -contains "ssh-add.exe") {
        Write-Host ""
        Write-Host "Windows OpenSSH Client tools are missing."
        Write-Host "On recent Windows versions, install OpenSSH Client from Settings:"
        Write-Host ""
        Write-Host "  Settings -> Apps -> Optional Features -> Add an optional feature -> OpenSSH Client"
        Write-Host ""
        Write-Host "Or try PowerShell as Administrator:"
        Write-Host ""
        Write-Host "  Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0"
        Write-Host ""
        Write-Host "Then verify:"
        Write-Host ""
        Write-Host "  ssh -V"
        Write-Host "  where.exe ssh"
    }

    Write-Host ""
    Write-Host "After installing the missing prerequisites, run this again:"
    Write-Host ""
    Write-Host "  .\windows\install.ps1"
}

function Test-KoCommand {
    param([Parameter(Mandatory = $true)][string]$Name)

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        Write-Host "FAIL | missing $Name"
        return $false
    }

    Write-Host "OK | $Name"
    return $true
}

$RepoRoot = Get-KoRepoRoot

$KoProjectPrefix = if ($env:KO_PROJECT_PREFIX) { $env:KO_PROJECT_PREFIX } else { "kaffeerunde" }
$KoAdminUser = if ($env:KO_ADMIN_USER) { $env:KO_ADMIN_USER } else { "ops" }

$KoStepCaUrl = if ($env:KO_STEP_CA_URL) { $env:KO_STEP_CA_URL } else { "https://serverauth.kaffeerunde.todopc.de" }
$KoStepCaFingerprint = if ($env:KO_STEP_CA_FINGERPRINT) { $env:KO_STEP_CA_FINGERPRINT } else { "96fdff658e0508991480ce131a8ed2d89f5e09aecfc41292d6592776c53022b6" }
$KoStepProvisioner = if ($env:KO_STEP_PROVISIONER) { $env:KO_STEP_PROVISIONER } else { "ops-ssh-jwk" }

$KoMgmtPublicEntry = if ($env:KO_MGMT_PUBLIC_ENTRY) { $env:KO_MGMT_PUBLIC_ENTRY } else { "mgmt.kaffeerunde.todopc.de" }
$KoEgressPublicEntry = if ($env:KO_EGRESS_PUBLIC_ENTRY) { $env:KO_EGRESS_PUBLIC_ENTRY } else { "egress.kaffeerunde.todopc.de" }
$KoMail01ExtPublicEntry = if ($env:KO_MAIL_01_EXT_PUBLIC_ENTRY) { $env:KO_MAIL_01_EXT_PUBLIC_ENTRY } else { "mail.gruening.cloud" }

$KoAuth01PrivateIp = if ($env:KO_AUTH_01_PRIVATE_IP) { $env:KO_AUTH_01_PRIVATE_IP } else { "10.42.0.3" }
$KoIngress01PrivateIp = if ($env:KO_INGRESS_01_PRIVATE_IP) { $env:KO_INGRESS_01_PRIVATE_IP } else { "10.42.0.6" }
$KoApps01PrivateIp = if ($env:KO_APPS_01_PRIVATE_IP) { $env:KO_APPS_01_PRIVATE_IP } else { "10.42.0.8" }
$KoApps02ExtWgIp = if ($env:KO_APPS_02_EXT_WG_IP) { $env:KO_APPS_02_EXT_WG_IP } else { "10.44.0.2" }

$KoHome = Get-KoHome
$KoLocalAppData = Get-KoLocalAppData
$KoClientRoot = if ($env:KO_CLIENT_ROOT) { $env:KO_CLIENT_ROOT } else { Join-Path $KoLocalAppData "$KoProjectPrefix-ssh" }
$KoStepPath = if ($env:KO_STEPPATH) { $env:KO_STEPPATH } else { Join-Path $KoClientRoot "step" }
$KoSshConfig = if ($env:KO_SSH_CONFIG) { $env:KO_SSH_CONFIG } else { Join-Path $KoClientRoot "config" }
$KoKnownHosts = if ($env:KO_KNOWN_HOSTS) { $env:KO_KNOWN_HOSTS } else { Join-Path $KoClientRoot "known_hosts" }
$KoIdentityFile = if ($env:KO_IDENTITY_FILE) { $env:KO_IDENTITY_FILE } else { Join-Path $KoClientRoot "id_kaffeerunde_ops" }
$KoCertificateFile = if ($env:KO_CERTIFICATE_FILE) { $env:KO_CERTIFICATE_FILE } else { "$KoIdentityFile-cert.pub" }

$UserSshDir = Join-Path $KoHome ".ssh"
$UserSshConfig = Join-Path $UserSshDir "config"

Write-Host ""
Write-Host "== prerequisite check =="

$missingPrereqs = New-Object System.Collections.Generic.List[string]

foreach ($bin in @("ssh.exe", "ssh-keygen.exe", "step.exe")) {
    if (-not (Test-KoCommand $bin)) {
        $missingPrereqs.Add($bin)
    }
}

if ($missingPrereqs.Count -gt 0) {
    Show-KoPrerequisiteHelp -Missing $missingPrereqs.ToArray()
    Write-Host ""
    Write-Host "== result =="
    Write-Host "FAIL | Windows install cannot continue until prerequisites are installed"
    exit 1
}

New-Item -ItemType Directory -Force -Path $KoClientRoot | Out-Null
New-Item -ItemType Directory -Force -Path $KoStepPath | Out-Null
New-Item -ItemType Directory -Force -Path $UserSshDir | Out-Null

$templatePath = Join-Path $RepoRoot "common\ssh_config.windows.template"
$knownHostsSource = Join-Path $RepoRoot "common\known_hosts"

if (-not (Test-Path $templatePath)) {
    throw "Missing template: $templatePath"
}
if (-not (Test-Path $knownHostsSource)) {
    throw "Missing known_hosts: $knownHostsSource"
}

$knownHostsOpenSsh = Convert-ToOpenSshPath $KoKnownHosts
$identityFileOpenSsh = Convert-ToOpenSshPath $KoIdentityFile
$certificateFileOpenSsh = Convert-ToOpenSshPath $KoCertificateFile

$config = Get-Content -Raw -Path $templatePath
$config = $config.Replace('${KO_PROJECT_PREFIX}', $KoProjectPrefix)
$config = $config.Replace('${KO_ADMIN_USER}', $KoAdminUser)
$config = $config.Replace('${KO_MGMT_PUBLIC_ENTRY}', $KoMgmtPublicEntry)
$config = $config.Replace('${KO_EGRESS_PUBLIC_ENTRY}', $KoEgressPublicEntry)
$config = $config.Replace('${KO_MAIL_01_EXT_PUBLIC_ENTRY}', $KoMail01ExtPublicEntry)
$config = $config.Replace('${KO_AUTH_01_PRIVATE_IP}', $KoAuth01PrivateIp)
$config = $config.Replace('${KO_INGRESS_01_PRIVATE_IP}', $KoIngress01PrivateIp)
$config = $config.Replace('${KO_APPS_01_PRIVATE_IP}', $KoApps01PrivateIp)
$config = $config.Replace('${KO_APPS_02_EXT_WG_IP}', $KoApps02ExtWgIp)
$config = $config.Replace('${KO_KNOWN_HOSTS}', $knownHostsOpenSsh)
$config = $config.Replace('${KO_IDENTITY_FILE}', $identityFileOpenSsh)
$config = $config.Replace('${KO_CERTIFICATE_FILE}', $certificateFileOpenSsh)

if ($config -match '\$\{KO_[A-Z0-9_]+\}') {
    Write-Host "FAIL | unresolved KO_* placeholder remains in rendered SSH config"
    $matches = [Regex]::Matches($config, '\$\{KO_[A-Z0-9_]+\}') | ForEach-Object { $_.Value } | Sort-Object -Unique
    foreach ($item in $matches) {
        Write-Host "UNRESOLVED | $item"
    }
    Write-Host ""
    Write-Host "== result =="
    Write-Host "FAIL | Windows install failed while rendering SSH config"
    exit 1
}

Set-Content -Path $KoSshConfig -Value $config -Encoding ascii
Copy-Item -Force -Path $knownHostsSource -Destination $KoKnownHosts

Write-Host "OK | rendered SSH config: $(Format-KoPublicPath $KoSshConfig)"
Write-Host "OK | installed known_hosts: $(Format-KoPublicPath $KoKnownHosts)"
Write-Host "OK | configured identity file: $(Format-KoPublicPath $KoIdentityFile)"
Write-Host "OK | configured certificate file: $(Format-KoPublicPath $KoCertificateFile)"

Write-Host ""
Write-Host "== ssh include =="

$includePath = Convert-ToOpenSshPath $KoSshConfig
$includeLine = "Include $includePath"
$beginMarker = "# BEGIN kaffeerunde SSH onboarding"
$endMarker = "# END kaffeerunde SSH onboarding"

$backupPath = "$UserSshConfig.bak.$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))"

if (Test-Path $UserSshConfig) {
    Copy-Item -Force -Path $UserSshConfig -Destination $backupPath
    $oldLines = Get-Content -Path $UserSshConfig
}
else {
    New-Item -ItemType File -Force -Path $backupPath | Out-Null
    $oldLines = @()
}

$newLines = New-Object System.Collections.Generic.List[string]
$newLines.Add($beginMarker)
$newLines.Add($includeLine)
$newLines.Add($endMarker)
$newLines.Add("")

$inBlock = $false
foreach ($line in $oldLines) {
    if ($line -eq $beginMarker) {
        $inBlock = $true
        continue
    }
    if ($line -eq $endMarker) {
        $inBlock = $false
        continue
    }
    if ($inBlock) {
        continue
    }
    if ($line -eq $includeLine) {
        continue
    }
    if ($line -eq "# kaffeerunde SSH onboarding") {
        continue
    }
    $newLines.Add($line)
}

Set-Content -Path $UserSshConfig -Value $newLines -Encoding ascii

Write-Host "OK | prepended include to user ssh config"
Write-Host "OK | backup created: $(Format-KoPublicPath $backupPath)"

Write-Host ""
Write-Host "== result =="
Write-Host "OK | Windows install completed"
Write-Host "NEXT | run: .\windows\login.ps1"
