$ErrorActionPreference = "Stop"

function Get-KoRepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Convert-ToOpenSshPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ($Path -replace "\\", "/")
}

function Format-KoPublicText {
    param([string]$Value)

    $repoRoot = [Regex]::Escape((Get-KoRepoRoot))
    $out = $Value
    if ($repoRoot) {
        $out = $out -replace $repoRoot, "<repo>"
    }
    $out = $out -replace '[A-Za-z]:[/\\][^ ]+', '<path>'
    $out = $out -replace '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+', '<redacted-email>'
    return $out
}

$RepoRoot = Get-KoRepoRoot
$TestRoot = Join-Path $env:TEMP ("kaffeerunde-ssh-onboarding-empty-profile-" + [Guid]::NewGuid().ToString("N"))
$TestHome = Join-Path $TestRoot "home"
$TestLocalAppData = Join-Path $TestRoot "LocalAppData"
$TestClientRoot = Join-Path $TestLocalAppData "kaffeerunde-ssh"
$TestSshConfig = Join-Path $TestClientRoot "config"
$TestKnownHosts = Join-Path $TestClientRoot "known_hosts"
$TestIdentityFile = Join-Path $TestClientRoot "id_kaffeerunde_ops"
$TestCertificateFile = "$TestIdentityFile-cert.pub"

New-Item -ItemType Directory -Force -Path $TestHome | Out-Null
New-Item -ItemType Directory -Force -Path $TestLocalAppData | Out-Null

Write-Host "TEST_HOME=$(Format-KoPublicText $TestHome)"

$env:KO_USER_HOME = $TestHome
$env:KO_LOCALAPPDATA = $TestLocalAppData
$env:KO_CLIENT_ROOT = $TestClientRoot
$env:KO_SSH_CONFIG = $TestSshConfig
$env:KO_KNOWN_HOSTS = $TestKnownHosts
$env:KO_IDENTITY_FILE = $TestIdentityFile
$env:KO_CERTIFICATE_FILE = $TestCertificateFile

try {
    $installScript = Join-Path $RepoRoot "windows\install.ps1"
    $powershellExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source

    if (-not $powershellExe) {
        throw "powershell.exe not found"
    }

    & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $installScript
    $installRc = $LASTEXITCODE

    if ($installRc -ne 0) {
        throw "install failed with rc=$installRc"
    }

    Write-Host ""
    Write-Host "== generated files =="
    Get-ChildItem -Path $TestRoot -Recurse -File | ForEach-Object {
        Write-Host (Format-KoPublicText $_.FullName)
    }

    Write-Host ""
    Write-Host "== rendered config placeholder check =="

    $renderedConfig = Get-Content -Raw -Path $TestSshConfig
    $unresolved = [Regex]::Matches($renderedConfig, '\$\{KO_[A-Z0-9_]+\}') | ForEach-Object { $_.Value } | Sort-Object -Unique

    if ($unresolved.Count -eq 0) {
        Write-Host "OK | no unresolved KO_* placeholders in rendered config"
    }
    else {
        foreach ($item in $unresolved) {
            Write-Host "FAIL | unresolved placeholder remains: $item"
        }
        throw "unresolved placeholders in rendered config"
    }

    Write-Host ""
    Write-Host "== ssh -G check =="

    $sshConfig = Join-Path $TestHome ".ssh\config"
    $sshG = & ssh.exe -F $sshConfig -G kaffeerunde-apps-01 2>$null

    $checks = @{
        "user ops" = "uses onboarding user"
        "hostname 10.42.0.8" = "uses apps private IP"
        "stricthostkeychecking true" = "uses strict hostkey checking"
        "updatehostkeys false" = "disables hostkey auto-update"
        "identitiesonly yes" = "uses only configured identity files"
        "preferredauthentications publickey" = "uses publickey-only preferred auth"
        "certificatefile " = "has certificate file directive"
        "passwordauthentication no" = "disables password auth"
        "kbdinteractiveauthentication no" = "disables keyboard-interactive auth"
    }

    $cmdRc = 0
    foreach ($key in $checks.Keys) {
        if ($key.EndsWith(" ")) {
            $found = $false
            foreach ($line in $sshG) {
                if ($line.StartsWith($key)) {
                    $found = $true
                    break
                }
            }
            if ($found) {
                Write-Host "OK | ssh -G $($checks[$key])"
            }
            else {
                Write-Host "FAIL | ssh -G does not show prefix: $key"
                $cmdRc = 1
            }
        }
        elseif ($sshG -contains $key) {
            Write-Host "OK | ssh -G $($checks[$key])"
        }
        else {
            Write-Host "FAIL | ssh -G does not show: $key"
            $cmdRc = 1
        }
    }

    if (Test-Path $TestKnownHosts) {
        Write-Host "OK | isolated known_hosts exists"
    }
    else {
        Write-Host "FAIL | isolated known_hosts missing"
        $cmdRc = 1
    }

    if ($cmdRc -eq 0) {
        Write-Host ""
        Write-Host "== result =="
        Write-Host "OK | Windows empty-profile install/render test completed"
    }
    else {
        throw "Windows empty-profile test failed"
    }
}
finally {
    Remove-Item -Recurse -Force -Path $TestRoot -ErrorAction SilentlyContinue
    Remove-Item Env:\KO_USER_HOME -ErrorAction SilentlyContinue
    Remove-Item Env:\KO_LOCALAPPDATA -ErrorAction SilentlyContinue
    Remove-Item Env:\KO_CLIENT_ROOT -ErrorAction SilentlyContinue
    Remove-Item Env:\KO_SSH_CONFIG -ErrorAction SilentlyContinue
    Remove-Item Env:\KO_KNOWN_HOSTS -ErrorAction SilentlyContinue
    Remove-Item Env:\KO_IDENTITY_FILE -ErrorAction SilentlyContinue
    Remove-Item Env:\KO_CERTIFICATE_FILE -ErrorAction SilentlyContinue
}
