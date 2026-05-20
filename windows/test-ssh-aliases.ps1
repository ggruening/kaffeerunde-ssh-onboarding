param(
    [switch]$Batch
)

$ErrorActionPreference = "Continue"

function Get-KoRepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-KoHome {
    if ($env:KO_USER_HOME) {
        return $env:KO_USER_HOME
    }
    return $HOME
}

function Format-KoPublicText {
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
    $out = $out -replace '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+', '<redacted-email>'
    return $out
}

function Invoke-KoSshSimple {
    param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][string]$RemoteCommand
    )

    $sshArgs = New-Object System.Collections.Generic.List[string]

    if ($Batch) {
        $sshArgs.Add("-o")
        $sshArgs.Add("BatchMode=yes")
    }

    $sshArgs.Add($HostName)
    $sshArgs.Add($RemoteCommand)

    $output = & ssh.exe @sshArgs 2>&1
    $sshRc = $LASTEXITCODE

    foreach ($line in $output) {
        Write-Host (Format-KoPublicText ([string]$line))
    }

    return $sshRc
}

$ProjectPrefix = if ($env:KO_PROJECT_PREFIX) { $env:KO_PROJECT_PREFIX } else { "kaffeerunde" }

$hosts = @(
    "$ProjectPrefix-mgmt-01",
    "$ProjectPrefix-egress-01",
    "$ProjectPrefix-auth-01",
    "$ProjectPrefix-ingress-01",
    "$ProjectPrefix-apps-01",
    "$ProjectPrefix-apps-02-ext"
)

$cmdRc = 0

Write-Host ""
Write-Host "== Windows SSH alias test mode =="
if ($Batch) {
    Write-Host "INFO | Batch mode enabled; this only works when no key passphrase prompt is needed."
}
else {
    Write-Host "INFO | Interactive mode enabled; encrypted file keys may prompt for a passphrase."
    Write-Host "INFO | Private hosts behind ProxyJump may prompt twice: once for the jump host and once for the target host."
}

foreach ($hostName in $hosts) {
    Write-Host ""
    Write-Host "== ssh test: $hostName =="

    $hostOut = Invoke-KoSshSimple -HostName $hostName -RemoteCommand "hostname"
    if ($hostOut -ne 0) {
        Write-Host "FAIL | $hostName hostname failed with rc=$hostOut"
        $cmdRc = 1
        continue
    }

    $userOut = Invoke-KoSshSimple -HostName $hostName -RemoteCommand "whoami"
    if ($userOut -ne 0) {
        Write-Host "FAIL | $hostName whoami failed with rc=$userOut"
        $cmdRc = 1
        continue
    }

    Write-Host "OK | $hostName reachable"
}

Write-Host ""
Write-Host "== result =="
if ($cmdRc -eq 0) {
    Write-Host "OK | all Windows onboarding SSH aliases work"
}
else {
    Write-Host "FAIL | at least one Windows onboarding SSH alias failed"
}

exit $cmdRc
