# RK3588 Simple Deploy Script
# PowerShell version - no encoding issues

$ErrorActionPreference = "Stop"

$RemoteHost = "192.168.10.170"
$RemoteUser = "pi"
$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"
$BinaryPath = "$ProjectRoot\build_rk3588_new\bin_arm64\belt_control_system"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RK3588 Simple Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check binary
Write-Host "Step 1: Checking compiled binary..." -ForegroundColor Yellow
if (-not (Test-Path $BinaryPath)) {
    Write-Host "ERROR: Binary not found at $BinaryPath" -ForegroundColor Red
    Write-Host "Please compile first!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
$fileSize = (Get-Item $BinaryPath).Length / 1MB
Write-Host "OK: Binary found (${fileSize} MB)" -ForegroundColor Green
Write-Host ""

# Step 2: Test connection
Write-Host "Step 2: Testing connection to $RemoteHost..." -ForegroundColor Yellow
$pingResult = Test-Connection -ComputerName $RemoteHost -Count 1 -Quiet
if (-not $pingResult) {
    Write-Host "ERROR: Cannot ping $RemoteHost" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "OK: Network connection working" -ForegroundColor Green
Write-Host ""

# Step 3: Check remote Docker
Write-Host "Step 3: Checking Docker on remote machine..." -ForegroundColor Yellow
try {
    $dockerVersion = ssh ${RemoteUser}@${RemoteHost} "docker --version" 2>&1
    Write-Host "OK: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Docker not found on remote" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

# Step 4: Transfer binary for testing
Write-Host "Step 4: Transferring binary to remote..." -ForegroundColor Yellow
scp $BinaryPath ${RemoteUser}@${RemoteHost}:/tmp/belt_control_system
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: Binary transferred" -ForegroundColor Green
} else {
    Write-Host "ERROR: Transfer failed" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

# Step 5: Test binary on remote
Write-Host "Step 5: Testing binary on remote..." -ForegroundColor Yellow
$testResult = ssh ${RemoteUser}@${RemoteHost} "chmod +x /tmp/belt_control_system && file /tmp/belt_control_system" 2>&1
Write-Host $testResult
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "All checks passed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Binary is now at: /tmp/belt_control_system on remote machine" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps for Docker deployment:"
Write-Host "  1. Create Dockerfile on remote"
Write-Host "  2. Build Docker image"
Write-Host "  3. Run container"
Write-Host ""

Read-Host "Press Enter to continue"
