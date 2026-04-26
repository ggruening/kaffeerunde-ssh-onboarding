$ErrorActionPreference = "Stop"

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

$KoProjectPrefix = if ($env:KO_PROJECT_PREFIX) { $env:KO_PROJECT_PREFIX } else { "kaffeerunde" }
$KoLocalAppData = Get-KoLocalAppData
$KoClientRoot = if ($env:KO_CLIENT_ROOT) { $env:KO_CLIENT_ROOT } else { Join-Path $KoLocalAppData "$KoProjectPrefix-ssh" }

Write-Host "INFO | cleanup target: $KoClientRoot"

if ([string]::IsNullOrWhiteSpace($KoClientRoot)) {
    Write-Host "FAIL | refusing empty cleanup target"
    exit 1
}

if (Test-Path $KoClientRoot) {
    Remove-Item -Recurse -Force -Path $KoClientRoot
    Write-Host "OK | removed Windows client state"
}
else {
    Write-Host "OK | nothing to remove"
}

Write-Host ""
Write-Host "== result =="
Write-Host "OK | Windows cleanup completed"
