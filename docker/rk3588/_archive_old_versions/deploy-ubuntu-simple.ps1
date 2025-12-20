# Simple Ubuntu Deploy - One tar transfer
# Minimizes password prompts

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$BuildRoot = "$ProjectRoot\build_rk3588_new"
$RK3588Libs = "$ScriptDir\rk3588-libs"

$RemoteHost = "192.168.10.155"
$RemoteUser = "linaro"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Ubuntu Deploy - Simple" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create local package
Write-Host "Step 1/4: Creating deployment package..." -ForegroundColor Yellow
$TempDir = "$env:TEMP\belt-control-ubuntu"
if (Test-Path $TempDir) {
    Remove-Item -Recurse -Force $TempDir
}
New-Item -ItemType Directory -Path "$TempDir\libs" | Out-Null

# Copy binary
Copy-Item "$BuildRoot\bin_arm64\belt_control_system" "$TempDir\"
Write-Host "  Binary copied" -ForegroundColor Green

# Copy Dockerfile
Copy-Item "$ScriptDir\Dockerfile.minimal" "$TempDir\Dockerfile"
Write-Host "  Dockerfile copied" -ForegroundColor Green

# Copy libraries
$libFiles = Get-ChildItem -Path "$RK3588Libs\lib" -File | Where-Object {
    ($_.Extension -match "\.so" -or $_.Name -match "\.so\.") -and
    ($_.Name -notmatch "librknn_api|v4l1compat|v4l2convert") -and
    (-not $_.LinkType)
}
foreach ($lib in $libFiles) {
    Copy-Item $lib.FullName "$TempDir\libs\"
}
Write-Host "  $($libFiles.Count) libraries copied" -ForegroundColor Green
Write-Host ""

# Step 2: Create archive (using PowerShell, not tar)
Write-Host "Step 2/4: Creating archive..." -ForegroundColor Yellow
$ArchivePath = "$env:TEMP\belt-control-ubuntu.zip"
if (Test-Path $ArchivePath) { Remove-Item $ArchivePath }
Compress-Archive -Path "$TempDir\*" -DestinationPath $ArchivePath -CompressionLevel Optimal
$archiveSize = (Get-Item $ArchivePath).Length / 1MB
Write-Host "  Archive created: $([math]::Round($archiveSize, 1)) MB" -ForegroundColor Green
Write-Host ""

# Step 3: Transfer archive (only one password prompt)
Write-Host "Step 3/4: Transferring to Ubuntu..." -ForegroundColor Yellow
Write-Host "  You may need to enter password: linaro" -ForegroundColor Gray
scp "$ArchivePath" "${RemoteUser}@${RemoteHost}:/tmp/"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Transfer complete" -ForegroundColor Green
} else {
    Write-Host "  Transfer failed" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 4: Extract and setup on device
Write-Host "Step 4/4: Setting up on device..." -ForegroundColor Yellow
ssh ${RemoteUser}@${RemoteHost} @"
    rm -rf /home/linaro/belt-control-build &&
    mkdir -p /home/linaro/belt-control-build &&
    cd /home/linaro/belt-control-build &&
    unzip -q /tmp/belt-control-ubuntu.zip &&
    chmod +x belt_control_system &&
    ls -lh | head -10
"@
Write-Host "  Setup complete" -ForegroundColor Green
Write-Host ""

# Cleanup
Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
Remove-Item $ArchivePath -ErrorAction SilentlyContinue

Write-Host "======================================" -ForegroundColor Green
Write-Host "Files ready on Ubuntu!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Build and run Docker" -ForegroundColor Yellow
Write-Host ""
Write-Host "Manual commands:" -ForegroundColor Cyan
Write-Host "  ssh linaro@192.168.10.155" -ForegroundColor White
Write-Host "  cd /home/linaro/belt-control-build" -ForegroundColor White
Write-Host "  docker build -t belt-control:latest ." -ForegroundColor White
Write-Host "  docker run -d --name belt_control --privileged --network host belt-control:latest" -ForegroundColor White
Write-Host ""
