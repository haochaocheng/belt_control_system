# 从设备151复制成功运行的环境到设备188
# 这个脚本会复制Docker镜像和配置

$ErrorActionPreference = "Stop"

$Device151 = "192.168.10.151"
$Device188 = "192.168.10.188"
$User = "linaro"
$Password = "linaro"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Copy Working Environment from 151 to 188" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: 导出设备151的Docker镜像
Write-Host "Step 1: Export Docker image from device 151..." -ForegroundColor Yellow

$exportCmd = @"
docker images --format '{{.Repository}}:{{.Tag}}' | grep belt-control | head -1
"@

Write-Host "  Finding belt-control image on 151..." -ForegroundColor Gray
$imageName = ssh "${User}@${Device151}" $exportCmd
if (-not $imageName) {
    Write-Host "  [ERROR] No belt-control image found on device 151" -ForegroundColor Red
    exit 1
}

$imageName = $imageName.Trim()
Write-Host "  Found image: $imageName" -ForegroundColor Green

# 导出镜像
Write-Host "  Exporting image from 151 (this may take a few minutes)..." -ForegroundColor Gray
ssh "${User}@${Device151}" "docker save $imageName | gzip > /tmp/belt-control-working.tar.gz"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Failed to export image" -ForegroundColor Red
    exit 1
}

# 检查文件大小
$sizeCmd = "du -h /tmp/belt-control-working.tar.gz | cut -f1"
$fileSize = ssh "${User}@${Device151}" $sizeCmd
Write-Host "  [OK] Exported image: $fileSize" -ForegroundColor Green
Write-Host ""

# Step 2: 传输到设备188
Write-Host "Step 2: Transfer image to device 188..." -ForegroundColor Yellow

# 先从151复制到本地
Write-Host "  Copying from 151 to local..." -ForegroundColor Gray
scp "${User}@${Device151}:/tmp/belt-control-working.tar.gz" "belt-control-working.tar.gz"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Failed to copy from 151" -ForegroundColor Red
    exit 1
}

# 再从本地复制到188
Write-Host "  Copying from local to 188..." -ForegroundColor Gray
scp "belt-control-working.tar.gz" "${User}@${Device188}:/tmp/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Failed to copy to 188" -ForegroundColor Red
    exit 1
}

Write-Host "  [OK] Transfer complete" -ForegroundColor Green
Write-Host ""

# Step 3: 在设备188上加载镜像
Write-Host "Step 3: Load image on device 188..." -ForegroundColor Yellow

ssh "${User}@${Device188}" @"
    echo 'Loading Docker image...' &&
    gunzip -c /tmp/belt-control-working.tar.gz | docker load &&
    rm /tmp/belt-control-working.tar.gz &&
    echo 'Image loaded successfully!' &&
    docker images | grep belt-control
"@

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Failed to load image on 188" -ForegroundColor Red
    exit 1
}

Write-Host "  [OK] Image loaded on 188" -ForegroundColor Green
Write-Host ""

# Step 4: 复制运行脚本和配置
Write-Host "Step 4: Copy run scripts and config..." -ForegroundColor Yellow

# 从151获取运行脚本
Write-Host "  Getting run script from 151..." -ForegroundColor Gray
ssh "${User}@${Device151}" "cat ~/run-belt-control.sh 2>/dev/null || cat ~/run-ubuntu24-apt.sh 2>/dev/null" > run-belt-control.sh

if ($LASTEXITCODE -eq 0 -and (Test-Path "run-belt-control.sh")) {
    # 复制到188
    scp "run-belt-control.sh" "${User}@${Device188}:/home/${User}/"
    ssh "${User}@${Device188}" "chmod +x /home/${User}/run-belt-control.sh"
    Write-Host "  [OK] Run script copied" -ForegroundColor Green
} else {
    Write-Host "  [!] No run script found, creating default..." -ForegroundColor Yellow

    # 创建默认运行脚本
    $runScript = @"
#!/bin/bash
# Belt Control System Run Script
# Copied from device 151

sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

echo "Starting Belt Control System..."
echo "Image: $imageName"

# Create data directories
mkdir -p /home/${User}/belt-control-data/appdata
mkdir -p /home/${User}/belt-control-data/audio

# Run container
sudo docker run \
    --name belt-control-app \
    --privileged \
    -e DISPLAY=:0 \
    -e QT_QPA_PLATFORM=eglfs \
    -e XDG_RUNTIME_DIR=/tmp \
    -v /dev:/dev \
    -v /sys:/sys \
    -v /run/udev:/run/udev:ro \
    -v /usr/share/fonts:/usr/share/fonts:ro \
    -v /home/${User}/belt-control-data/appdata:/app/appdata:rw \
    -v /home/${User}/belt-control-data/audio:/app/AUDIO:rw \
    $imageName

echo "Application exited with code: \$?"
"@

    $runScript | Out-File -Encoding UTF8 "run-belt-control.sh"
    scp "run-belt-control.sh" "${User}@${Device188}:/home/${User}/"
    ssh "${User}@${Device188}" "chmod +x /home/${User}/run-belt-control.sh"
    Write-Host "  [OK] Default run script created" -ForegroundColor Green
}

# 复制配置文件（如果存在）
Write-Host "  Copying configuration files..." -ForegroundColor Gray
ssh "${User}@${Device151}" @"
    if [ -d /home/${User}/belt-control-data ]; then
        tar czf /tmp/belt-control-data.tar.gz -C /home/${User} belt-control-data 2>/dev/null
        echo 'Config archived'
    fi
"@

if ($LASTEXITCODE -eq 0) {
    scp "${User}@${Device151}:/tmp/belt-control-data.tar.gz" "belt-control-data.tar.gz" 2>$null
    if (Test-Path "belt-control-data.tar.gz") {
        scp "belt-control-data.tar.gz" "${User}@${Device188}:/tmp/"
        ssh "${User}@${Device188}" "cd /home/${User} && tar xzf /tmp/belt-control-data.tar.gz && rm /tmp/belt-control-data.tar.gz"
        Write-Host "  [OK] Configuration copied" -ForegroundColor Green
    }
}

Write-Host ""

# Step 5: 清理临时文件
Write-Host "Step 5: Cleanup temporary files..." -ForegroundColor Yellow
Remove-Item "belt-control-working.tar.gz" -Force -ErrorAction SilentlyContinue
Remove-Item "run-belt-control.sh" -Force -ErrorAction SilentlyContinue
Remove-Item "belt-control-data.tar.gz" -Force -ErrorAction SilentlyContinue
ssh "${User}@${Device151}" "rm -f /tmp/belt-control-working.tar.gz /tmp/belt-control-data.tar.gz" 2>$null
Write-Host "  [OK] Cleanup complete" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Environment Copy Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "To run the application on 188:" -ForegroundColor Yellow
Write-Host "  ssh ${User}@${Device188} ./run-belt-control.sh" -ForegroundColor White
Write-Host ""
Write-Host "Test now? (y/n)" -ForegroundColor Yellow
$testNow = Read-Host

if ($testNow -eq 'y') {
    Write-Host ""
    Write-Host "Testing on device 188..." -ForegroundColor Cyan
    ssh "${User}@${Device188}" "./run-belt-control.sh"
}