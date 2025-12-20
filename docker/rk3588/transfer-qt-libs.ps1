# Transfer Qt6 libraries to Ubuntu
$ErrorActionPreference = "Stop"

$QtLibDir = "e:\2025\3_gongkongji\belt_control_system\docker\rk3588\qt-raspi\lib"
$RemoteHost = "192.168.10.155"
$RemoteUser = "linaro"
$RemoteBuildDir = "/home/linaro/belt-control-build/libs"

Write-Host "Transferring Qt6 libraries..." -ForegroundColor Yellow

# Get all .so files (not symlinks)
$qtLibs = Get-ChildItem -Path $QtLibDir -File | Where-Object {
    ($_.Extension -match "\.so" -or $_.Name -match "\.so\.") -and
    (-not $_.LinkType)
}

Write-Host "Found $($qtLibs.Count) Qt6 library files" -ForegroundColor Gray

$count = 0
foreach ($lib in $qtLibs) {
    scp "$($lib.FullName)" "${RemoteUser}@${RemoteHost}:$RemoteBuildDir/" 2>$null
    $count++
    if ($count % 20 -eq 0) {
        Write-Host "  Transferred $count/$($qtLibs.Count) files..." -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Total Qt6 libraries transferred: $count" -ForegroundColor Green
