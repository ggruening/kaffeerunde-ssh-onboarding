param(
    [Parameter(Position = 0)]
    [string]$HostName = "kaffeerunde-apps-01"
)

$ErrorActionPreference = "Stop"

Write-Host "INFO | opening interactive login shell on $HostName"
Write-Host "INFO | this uses: ssh -t $HostName bash -l"
Write-Host ""

& ssh.exe -t $HostName bash -l
exit $LASTEXITCODE
