# Quick Verification Script for Application Layer Changes
# 快速验证脚本 - 用于应用层修改后的快速测试
#
# 使用方法:
#   .\build-ubuntu24-apt-quick.ps1          # 默认部署到 192.168.10.188
#   .\build-ubuntu24-apt-quick.ps1 151      # 部署到 192.168.10.151
#   .\build-ubuntu24-apt-quick.ps1 192.168.10.200  # 部署到自定义IP
#
# 功能：
#   - 只编译应用程序（不打包 Docker）
#   - 直接上传二进制到设备
#   - 智能检测容器状态并启动程序
#   - 适用于应用层代码快速迭代测试

param(
    [string]$Device = "188"  # 默认188设备
)

$ErrorActionPreference = "Stop"

# ============================================================
# 设备配置
# ============================================================
$DeviceUser = "linaro"
$DevicePassword = "linaro"

switch -Regex ($Device) {
    "^151$" {
        $DeviceIP = "192.168.10.151"
        Write-Host "[Device] Target: Device 151 ($DeviceIP)" -ForegroundColor Cyan
    }
    "^188$" {
        $DeviceIP = "192.168.10.188"
        Write-Host "[Device] Target: Device 188 ($DeviceIP)" -ForegroundColor Cyan
    }
    "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$" {
        $DeviceIP = $Device
        Write-Host "[Device] Target: Custom IP ($DeviceIP)" -ForegroundColor Cyan
    }
    default {
        Write-Host "[ERROR] Invalid device parameter: $Device" -ForegroundColor Red
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  .\build-ubuntu24-apt-quick.ps1              # Deploy to 192.168.10.188" -ForegroundColor White
        Write-Host "  .\build-ubuntu24-apt-quick.ps1 151          # Deploy to 192.168.10.151" -ForegroundColor White
        Write-Host "  .\build-ubuntu24-apt-quick.ps1 192.168.10.200  # Deploy to custom IP" -ForegroundColor White
        Write-Host ""
        exit 1
    }
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Quick Verification - Application Layer Test" -ForegroundColor Cyan
Write-Host "Fast compile → Upload → Smart deploy" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 路径配置
# ============================================================
$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"
$BuildDir = "$ProjectRoot\build_rk3588"
$BinaryFile = "$BuildDir\bin_arm64\belt_control_system"
$DeviceDeployDir = "/home/linaro/belt_test"

# ============================================================
# Step 1: 检查二进制文件是否存在
# ============================================================
Write-Host "Step 1: Checking binary file..." -ForegroundColor Cyan

if (-not (Test-Path $BinaryFile)) {
    Write-Host "  [!] Binary not found, need compilation" -ForegroundColor Yellow
    Write-Host "  Running cross-compilation in Docker container..." -ForegroundColor Yellow
    Write-Host ""

    # 使用 Docker 容器进行交叉编译（32线程）
    $dockerImage = "belt-control-fixed:latest"

    # 检查 Docker 镜像是否存在
    $imageCheck = docker images $dockerImage --format "{{.Repository}}:{{.Tag}}" 2>$null
    if (-not $imageCheck) {
        Write-Host "  [ERROR] Docker image not found: $dockerImage" -ForegroundColor Red
        Write-Host "  Please run full build first: .\build-ubuntu24-apt.ps1" -ForegroundColor Yellow
        exit 1
    }

    # 执行交叉编译
    docker run --rm `
        -v "${ProjectRoot}:/workspace" `
        -w /workspace `
        $dockerImage `
        bash -c "cmake -S. -Bbuild_rk3588 -DCMAKE_TOOLCHAIN_FILE=docker/rk3588/toolchain-fixed.cmake && make -C build_rk3588 -j32"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Compilation failed" -ForegroundColor Red
        exit 1
    }

    if (-not (Test-Path $BinaryFile)) {
        Write-Host "  [ERROR] Binary not found after compilation" -ForegroundColor Red
        exit 1
    }

    Write-Host "  [OK] Compilation completed" -ForegroundColor Green
} else {
    $binaryTime = (Get-Item $BinaryFile).LastWriteTime
    Write-Host "  [OK] Binary found (modified: $binaryTime)" -ForegroundColor Green
}

# ============================================================
# Step 2: 上传二进制到设备
# ============================================================
Write-Host ""
Write-Host "Step 2: Uploading binary to device..." -ForegroundColor Cyan

# 创建部署目录（使用 plink）
Write-Host "  Creating deploy directory on device..." -ForegroundColor Gray
& plink -batch -pw $DevicePassword "$DeviceUser@$DeviceIP" "mkdir -p $DeviceDeployDir" 2>$null

# 上传二进制（使用 pscp）
Write-Host "  Uploading belt_control_system..." -ForegroundColor Gray
& pscp -batch -pw $DevicePassword "$BinaryFile" "${DeviceUser}@${DeviceIP}:${DeviceDeployDir}/belt_control_system"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Upload failed" -ForegroundColor Red
    Write-Host "  Please ensure PuTTY is installed (plink and pscp commands)" -ForegroundColor Yellow
    exit 1
}

# 设置可执行权限
& plink -batch -pw $DevicePassword "$DeviceUser@$DeviceIP" "chmod +x $DeviceDeployDir/belt_control_system"

Write-Host "  [OK] Binary uploaded successfully" -ForegroundColor Green

# ============================================================
# Step 3: 停止旧程序
# ============================================================
Write-Host ""
Write-Host "Step 3: Stopping old processes..." -ForegroundColor Cyan

# 停止容器内的程序
Write-Host "  Stopping container processes..." -ForegroundColor Gray
& plink -batch -pw $DevicePassword "$DeviceUser@$DeviceIP" "docker exec belt_control bash -c 'pkill -9 belt_control_system || true' 2>/dev/null || true"

# 停止宿主机的程序
Write-Host "  Stopping host processes..." -ForegroundColor Gray
& plink -batch -pw $DevicePassword "$DeviceUser@$DeviceIP" "pkill -9 belt_control_system || true"

Start-Sleep -Seconds 2
Write-Host "  [OK] Old processes stopped" -ForegroundColor Green

# ============================================================
# Step 4: 检测容器状态并启动程序
# ============================================================
Write-Host ""
Write-Host "Step 4: Starting application..." -ForegroundColor Cyan

# 检测容器是否运行
$containerStatus = & plink -batch -pw $DevicePassword "$DeviceUser@$DeviceIP" "docker ps --filter name=belt_control --format '{{.Names}}' 2>/dev/null"

if ($containerStatus -match "belt_control") {
    Write-Host "  [INFO] Container is running, starting inside container..." -ForegroundColor Yellow

    # 复制二进制到容器
    & plink -batch -pw $DevicePassword "$DeviceUser@$DeviceIP" "docker cp $DeviceDeployDir/belt_control_system belt_control:/app/belt_control_system"
    & plink -batch -pw $DevicePassword "$DeviceUser@$DeviceIP" "docker exec belt_control chmod +x /app/belt_control_system"

    # 在容器内后台启动
    Write-Host "  Starting in container..." -ForegroundColor Gray
    & plink -batch -pw $DevicePassword "$DeviceUser@$DeviceIP" "docker exec -d belt_control bash -c 'cd /app && nohup ./belt_control_system > /tmp/belt_control.log 2>&1 &'"

    Write-Host "  [OK] Application started in container" -ForegroundColor Green
    Write-Host ""
    Write-Host "  View logs:" -ForegroundColor Yellow
    Write-Host "    docker exec belt_control tail -f /tmp/belt_control.log" -ForegroundColor White

} else {
    Write-Host "  [INFO] Container not running, starting on host..." -ForegroundColor Yellow

    # 在宿主机后台启动（需要设置库路径）
    Write-Host "  Starting on host with LD_LIBRARY_PATH..." -ForegroundColor Gray
    & plink -batch -pw $DevicePassword "$DeviceUser@$DeviceIP" "cd $DeviceDeployDir && export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib/aarch64-linux-gnu:`$LD_LIBRARY_PATH && nohup ./belt_control_system > /tmp/belt_control.log 2>&1 &"

    Write-Host "  [OK] Application started on host" -ForegroundColor Green
    Write-Host ""
    Write-Host "  View logs:" -ForegroundColor Yellow
    Write-Host "    ssh $DeviceUser@$DeviceIP 'tail -f /tmp/belt_control.log'" -ForegroundColor White
}

# ============================================================
# Step 5: 验证程序运行状态
# ============================================================
Write-Host ""
Write-Host "Step 5: Verifying application status..." -ForegroundColor Cyan

Start-Sleep -Seconds 2

$processCheck = & plink -batch -pw $DevicePassword "$DeviceUser@$DeviceIP" "ps aux | grep belt_control_system | grep -v grep | wc -l"

if ([int]$processCheck -gt 0) {
    Write-Host "  [OK] Application is running ($processCheck process(es))" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] Application process not found, check logs" -ForegroundColor Red
}

# ============================================================
# 完成
# ============================================================
Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "Quick Verification Completed!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Check application logs" -ForegroundColor White
Write-Host "  2. Test video call functionality" -ForegroundColor White
Write-Host "  3. Monitor CPU usage (should be normal)" -ForegroundColor White
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Yellow
Write-Host "  ssh $DeviceUser@$DeviceIP" -ForegroundColor White
Write-Host "  ps aux | grep belt_control_system" -ForegroundColor White
Write-Host "  tail -f /tmp/belt_control.log" -ForegroundColor White
Write-Host ""
