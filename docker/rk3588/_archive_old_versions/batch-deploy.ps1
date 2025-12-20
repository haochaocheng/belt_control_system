# Batch Production Deployment Script
# Deploy to multiple RK3588 devices in production

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ========================================
# Configuration
# ========================================

# List of target devices (IP addresses)
# Modify this list for your production devices
$DeviceList = @(
    "192.168.10.170",
    "192.168.10.171",
    "192.168.10.172"
    # Add more device IPs here...
)

$RemoteUser = "pi"
$RemotePassword = "pi"  # Optional, if using sshpass
$ContainerName = "belt_control"
$ImageName = "belt-control-rk3588:runtime"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Batch Production Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total devices: $($DeviceList.Count)" -ForegroundColor Yellow
Write-Host ""

# ========================================
# Step 1: Build Docker image on first device (once)
# ========================================

Write-Host "Step 1: Building Docker image on first device..." -ForegroundColor Green
Write-Host "Device: $($DeviceList[0])" -ForegroundColor Gray
Write-Host ""

$firstDevice = $DeviceList[0]

# Run deploy-on-device.ps1 for the first device
$env:TARGET_DEVICE = $firstDevice
& "$ScriptDir\deploy-on-device.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to build on first device" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Image built successfully on first device!" -ForegroundColor Green
Write-Host ""

# ========================================
# Step 2: Export Docker image from first device
# ========================================

Write-Host "Step 2: Exporting Docker image from first device..." -ForegroundColor Green

$imageFile = "$env:TEMP\belt-control-runtime.tar"
if (Test-Path $imageFile) {
    Remove-Item $imageFile -Force
}

Write-Host "  Saving image on device..." -ForegroundColor Gray
ssh ${RemoteUser}@${firstDevice} "docker save $ImageName -o /tmp/belt-control-runtime.tar"

Write-Host "  Downloading image..." -ForegroundColor Gray
scp "${RemoteUser}@${firstDevice}:/tmp/belt-control-runtime.tar" $imageFile

if (Test-Path $imageFile) {
    $imageSize = [math]::Round((Get-Item $imageFile).Length / 1MB, 2)
    Write-Host "  OK Image downloaded ($imageSize MB)" -ForegroundColor Green
} else {
    Write-Host "  ERROR Failed to download image" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ========================================
# Step 3: Deploy to remaining devices
# ========================================

if ($DeviceList.Count -gt 1) {
    Write-Host "Step 3: Deploying to remaining devices..." -ForegroundColor Green
    Write-Host ""

    $remainingDevices = $DeviceList[1..($DeviceList.Count-1)]
    $successCount = 1  # First device already done
    $failCount = 0

    foreach ($device in $remainingDevices) {
        Write-Host "Deploying to: $device" -ForegroundColor Yellow

        try {
            # Upload image
            Write-Host "  Uploading image..." -ForegroundColor Gray
            scp $imageFile "${RemoteUser}@${device}:/tmp/belt-control-runtime.tar"

            # Load image
            Write-Host "  Loading image..." -ForegroundColor Gray
            ssh ${RemoteUser}@${device} "docker load -i /tmp/belt-control-runtime.tar"

            # Stop old container
            Write-Host "  Stopping old container..." -ForegroundColor Gray
            ssh ${RemoteUser}@${device} "docker stop $ContainerName 2>/dev/null || true"
            ssh ${RemoteUser}@${device} "docker rm $ContainerName 2>/dev/null || true"

            # Start new container
            Write-Host "  Starting container..." -ForegroundColor Gray
            ssh ${RemoteUser}@${device} "docker run -d --name $ContainerName --privileged --network host --restart unless-stopped -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 $ImageName"

            # Verify
            $status = ssh ${RemoteUser}@${device} "docker ps | grep $ContainerName"
            if ($status) {
                Write-Host "  OK Deployed successfully" -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "  WARNING Container may not be running" -ForegroundColor Yellow
            }

        } catch {
            Write-Host "  ERROR Deployment failed: $_" -ForegroundColor Red
            $failCount++
        }

        Write-Host ""
    }

    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Batch Deployment Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Yellow
    Write-Host "  Total devices:      $($DeviceList.Count)" -ForegroundColor White
    Write-Host "  Successful:         $successCount" -ForegroundColor Green
    Write-Host "  Failed:             $failCount" -ForegroundColor Red
    Write-Host ""

} else {
    Write-Host "Only one device in list. Deployment complete." -ForegroundColor Green
}

# Cleanup
Remove-Item $imageFile -Force -ErrorAction SilentlyContinue

Write-Host "Useful commands for all devices:" -ForegroundColor Yellow
Write-Host ""
foreach ($device in $DeviceList) {
    Write-Host "Device $device" -ForegroundColor Cyan
    Write-Host "  View logs:  ssh ${RemoteUser}@${device} 'docker logs -f $ContainerName'" -ForegroundColor White
    Write-Host "  Stop:       ssh ${RemoteUser}@${device} 'docker stop $ContainerName'" -ForegroundColor White
    Write-Host "  Start:      ssh ${RemoteUser}@${device} 'docker start $ContainerName'" -ForegroundColor White
    Write-Host "  Restart:    ssh ${RemoteUser}@${device} 'docker restart $ContainerName'" -ForegroundColor White
    Write-Host ""
}
