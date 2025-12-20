# Deploy v3.3 to Multiple RK3588 Devices - Quick Deployment Script
# This script copies the compiled binary and starts the application directly

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy v3.3 to RK3588 Devices" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$BinaryPath = "e:\2025\3_gongkongji\belt_control_system\build_rk3588\bin_arm64\belt_control_system"
$AudioPath = "e:\2025\3_gongkongji\belt_control_system\AUDIO"

# Device configurations
$Devices = @(
    @{
        Name = "Device 155 (800x1280 Portrait)"
        IP = "192.168.10.155"
        User = "linaro"
        Pass = "linaro"
        Description = "Testing rotation fix"
    },
    @{
        Name = "Device 151 (1920x1080 Landscape)"
        IP = "192.168.10.151"
        User = "linaro"
        Pass = "linaro"
        Description = "Testing normal display"
    }
)

# Check if binary exists
if (-not (Test-Path $BinaryPath)) {
    Write-Host "ERROR: Binary not found at: $BinaryPath" -ForegroundColor Red
    Write-Host "Please run build-rk3588.ps1 first" -ForegroundColor Yellow
    exit 1
}

Write-Host "Binary found: $BinaryPath" -ForegroundColor Green
$BinarySize = [math]::Round((Get-Item $BinaryPath).Length / 1MB, 2)
Write-Host "Size: $BinarySize MB" -ForegroundColor Green
Write-Host ""

# Deploy to each device
foreach ($Device in $Devices) {
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Deploying to: $($Device.Name)" -ForegroundColor Yellow
    Write-Host "IP: $($Device.IP) | User: $($Device.User)" -ForegroundColor Gray
    Write-Host "Purpose: $($Device.Description)" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""

    $DeviceIP = $Device.IP
    $DeviceUser = $Device.User
    $RemoteAppDir = "/home/$DeviceUser/belt-control-v3.3"

    # Step 1: Test SSH connection
    Write-Host "Step 1/5: Testing SSH connection..." -ForegroundColor Cyan
    $sshTest = ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${DeviceUser}@${DeviceIP}" "echo ok" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Cannot connect to $DeviceIP" -ForegroundColor Red
        Write-Host "  $sshTest" -ForegroundColor Red
        Write-Host "  Skipping this device..." -ForegroundColor Yellow
        Write-Host ""
        continue
    }
    Write-Host "  Connected successfully" -ForegroundColor Green
    Write-Host ""

    # Step 2: Check system info
    Write-Host "Step 2/5: Checking device info..." -ForegroundColor Cyan
    $systemInfo = ssh "${DeviceUser}@${DeviceIP}" "uname -m && cat /etc/os-release | grep PRETTY_NAME"
    Write-Host "  $systemInfo" -ForegroundColor Gray
    Write-Host ""

    # Step 3: Create remote directory
    Write-Host "Step 3/5: Preparing remote directory..." -ForegroundColor Cyan
    ssh "${DeviceUser}@${DeviceIP}" "mkdir -p $RemoteAppDir/AUDIO && rm -f $RemoteAppDir/belt_control_system"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to create directory" -ForegroundColor Red
        continue
    }
    Write-Host "  Directory ready: $RemoteAppDir" -ForegroundColor Green
    Write-Host ""

    # Step 4: Copy binary and AUDIO files
    Write-Host "Step 4/5: Transferring files..." -ForegroundColor Cyan
    Write-Host "  Copying binary..." -ForegroundColor Gray
    scp -o StrictHostKeyChecking=no $BinaryPath "${DeviceUser}@${DeviceIP}:${RemoteAppDir}/belt_control_system"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to copy binary" -ForegroundColor Red
        continue
    }

    if (Test-Path $AudioPath) {
        Write-Host "  Copying AUDIO folder..." -ForegroundColor Gray
        scp -r -o StrictHostKeyChecking=no $AudioPath "${DeviceUser}@${DeviceIP}:${RemoteAppDir}/"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  WARNING: Failed to copy AUDIO folder" -ForegroundColor Yellow
        }
    }

    Write-Host "  Files transferred successfully" -ForegroundColor Green
    Write-Host ""

    # Step 5: Set permissions and verify
    Write-Host "Step 5/5: Setting permissions..." -ForegroundColor Cyan
    ssh "${DeviceUser}@${DeviceIP}" "chmod +x $RemoteAppDir/belt_control_system"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to set permissions" -ForegroundColor Red
        continue
    }

    # Verify binary architecture
    Write-Host "  Verifying binary architecture..." -ForegroundColor Gray
    $archCheck = ssh "${DeviceUser}@${DeviceIP}" "file $RemoteAppDir/belt_control_system"
    Write-Host "  $archCheck" -ForegroundColor Gray

    Write-Host ""
    Write-Host "Deployment to $($Device.Name) completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To run the application on this device:" -ForegroundColor Yellow
    Write-Host "  ssh ${DeviceUser}@${DeviceIP}" -ForegroundColor White
    Write-Host "  cd $RemoteAppDir" -ForegroundColor White
    Write-Host "  export QT_QPA_PLATFORM=eglfs" -ForegroundColor White
    Write-Host "  export QT_QPA_EGLFS_INTEGRATION=eglfs_kms" -ForegroundColor White
    Write-Host "  ./belt_control_system" -ForegroundColor White
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Green
    Write-Host ""
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "All Deployments Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. SSH to each device and run the application" -ForegroundColor White
Write-Host "2. Test the v3.3 rotation fix on Device 155 (800x1280)" -ForegroundColor White
Write-Host "3. Verify normal display on Device 151 (1920x1080)" -ForegroundColor White
Write-Host ""
Write-Host "Quick start script for each device:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Device 155:" -ForegroundColor Cyan
Write-Host "  ssh linaro@192.168.10.155" -ForegroundColor White
Write-Host "  cd /home/linaro/belt-control-v3.3" -ForegroundColor White
Write-Host "  export QT_QPA_PLATFORM=eglfs && export QT_QPA_EGLFS_INTEGRATION=eglfs_kms && ./belt_control_system" -ForegroundColor White
Write-Host ""
Write-Host "Device 151:" -ForegroundColor Cyan
Write-Host "  ssh linaro@192.168.10.151" -ForegroundColor White
Write-Host "  cd /home/linaro/belt-control-v3.3" -ForegroundColor White
Write-Host "  export QT_QPA_PLATFORM=eglfs && export QT_QPA_EGLFS_INTEGRATION=eglfs_kms && ./belt_control_system" -ForegroundColor White
Write-Host ""
