# ✅ 2026-01-09 11:10 [快速验证] PJSIP 代码修改后的快速验证流程
# 目的：只编译 PJSIP + 应用，跳过 Docker 镜像构建，直接替换容器内二进制
# 优势：从 10 分钟缩短到 2-3 分钟
# 适用：仅修改 PJSIP 源码（ffmpeg_vid_codecs.c）时使用

# PowerShell 7 UTF-8 强制配置
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

param(
    [string]$Device = "188"
)

$ProjectRoot = $PSScriptRoot | Split-Path | Split-Path

# 设备配置（2026-01-09 更新）
$DeviceUser = "linaro"
$DevicePassword = "linaro"

switch -Regex ($Device) {
    "^188$" { $DeviceIP = "192.168.10.188" }
    "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$" { $DeviceIP = $Device }
    default {
        Write-Host "[错误] 无效的设备参数: $Device" -ForegroundColor Red
        Write-Host "使用方法: .\03-quick-verify-pjsip.ps1 188" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "PJSIP 快速验证流程" -ForegroundColor Cyan
Write-Host "目标设备: $DeviceIP" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$SourceFile = "$ProjectRoot\cross-compile\src\pjproject-2.16\pjmedia\src\pjmedia-codec\ffmpeg_vid_codecs.c"
$pjsipLibFile = "$ProjectRoot\docker\rk3588\rk3588-libs\lib\libpjmedia-codec-aarch64-unknown-linux-gnu.a"

# ============================================================
# Step 1: 更新源文件时间戳（强制重新编译）
# ============================================================
Write-Host "[1/5] 更新源文件时间戳..." -ForegroundColor Green

if (-not (Test-Path $SourceFile)) {
    Write-Host "  ❌ 源文件不存在: $SourceFile" -ForegroundColor Red
    exit 1
}

$oldTimestamp = (Get-Item $SourceFile).LastWriteTime
(Get-Item $SourceFile).LastWriteTime = Get-Date
$newTimestamp = (Get-Item $SourceFile).LastWriteTime

Write-Host "  旧时间戳: $($oldTimestamp.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host "  新时间戳: $($newTimestamp.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green

# ============================================================
# Step 2: 重新编译 PJSIP 静态库（增量编译）
# ============================================================
Write-Host ""
Write-Host "[2/5] 重新编译 PJSIP 静态库（约1分钟）..." -ForegroundColor Green

$pjsipContainerName = "pjsip-builder-persistent"
$containerExists = docker ps -a --filter "name=^${pjsipContainerName}$" --format "{{.Names}}"

if (-not $containerExists) {
    Write-Host "  ❌ PJSIP 编译容器不存在，请先运行完整编译：" -ForegroundColor Red
    Write-Host "     .\build-ubuntu24-apt.ps1 $Device" -ForegroundColor Yellow
    exit 1
}

# 启动容器
$containerRunning = docker ps --filter "name=^${pjsipContainerName}$" --format "{{.Names}}"
if (-not $containerRunning) {
    Write-Host "  启动 PJSIP 编译容器..." -ForegroundColor Gray
    docker start $pjsipContainerName | Out-Null
}

# 同步修改的源文件
Write-Host "  同步源文件..." -ForegroundColor Gray
docker cp $SourceFile "${pjsipContainerName}:/workspace/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c"

# 增量编译（只编译修改的文件）
Write-Host "  增量编译..." -ForegroundColor Gray
$compileScript = @'
#!/bin/bash
cd /workspace
export CC=aarch64-linux-gnu-gcc
export CXX=aarch64-linux-gnu-g++
export AR=aarch64-linux-gnu-ar
export RANLIB=aarch64-linux-gnu-ranlib
FFMPEG_ROCKCHIP_INCLUDE="/opt/ffmpeg-rockchip/include"
export CFLAGS="-fPIC -O2 -I$FFMPEG_ROCKCHIP_INCLUDE -I/opt/rk3588-sysroot/usr/include"
export CXXFLAGS="-fPIC -O2 -I$FFMPEG_ROCKCHIP_INCLUDE -I/opt/rk3588-sysroot/usr/include"

# 只编译 pjmedia-codec 库（16核并行）
cd pjmedia/build
make -j16 lib 2>&1 | tail -20
'@

$compileScript | docker exec -i $pjsipContainerName bash

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ PJSIP 编译失败" -ForegroundColor Red
    exit 1
}

# 复制静态库
Write-Host "  复制静态库..." -ForegroundColor Gray
docker exec $pjsipContainerName bash -c "find /workspace -name 'libpjmedia-codec-*.a' -exec cp {} /output/lib/ \;"

Write-Host "  ✓ PJSIP 静态库编译完成" -ForegroundColor Green

# ============================================================
# Step 3: 重新编译应用程序
# ============================================================
Write-Host ""
Write-Host "[3/5] 重新编译应用程序（约30秒）..." -ForegroundColor Green

$buildDir = "$ProjectRoot\build_rk3588"
$cpuCores = $env:NUMBER_OF_PROCESSORS
if (-not $cpuCores) { $cpuCores = 4 }

Write-Host "  使用 $cpuCores 个 CPU 核心并行编译..." -ForegroundColor Gray

docker run --rm `
  -v "${ProjectRoot}:/workspace" `
  -v "${ProjectRoot}\docker\rk3588\rk3588-libs:/opt/rk3588-libs" `
  -w /workspace `
  belt-control-compiler:latest `
  bash -c "cd build_rk3588 && make -j$cpuCores 2>&1 | tail -20"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ 应用程序编译失败" -ForegroundColor Red
    exit 1
}

$binaryPath = "$buildDir\bin_arm64\belt_control_system"
if (-not (Test-Path $binaryPath)) {
    Write-Host "  ❌ 二进制文件不存在: $binaryPath" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ 应用程序编译完成" -ForegroundColor Green
Write-Host "    二进制大小: $([Math]::Round((Get-Item $binaryPath).Length / 1MB, 2)) MB" -ForegroundColor Gray

# ============================================================
# Step 4: 直接替换容器内二进制并重启
# ============================================================
Write-Host ""
Write-Host "[4/5] 替换容器内二进制并重启..." -ForegroundColor Green

# 上传二进制到设备
Write-Host "  上传二进制..." -ForegroundColor Gray
scp -o StrictHostKeyChecking=no $binaryPath "${DeviceUser}@${DeviceIP}:/tmp/belt_control_system_new"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ 上传失败" -ForegroundColor Red
    exit 1
}

# 替换并重启容器
Write-Host "  重启容器..." -ForegroundColor Gray
$restartScript = @"
# 停止容器
docker stop belt-control-latest 2>/dev/null || true

# 复制新二进制到容器
CONTAINER_ID=`$(docker ps -a --filter name=belt-control-latest --format '{{.ID}}')
if [ -n "`$CONTAINER_ID" ]; then
    docker cp /tmp/belt_control_system_new `$CONTAINER_ID:/app/belt_control_system
    docker start belt-control-latest
    echo '✓ 容器已重启'
else
    echo '❌ 容器不存在'
    exit 1
fi

# 清理临时文件
rm -f /tmp/belt_control_system_new
"@

ssh -o StrictHostKeyChecking=no "${DeviceUser}@${DeviceIP}" $restartScript

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ 重启失败" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ 容器已重启" -ForegroundColor Green

# ============================================================
# Step 5: 自动查看日志验证版本号
# ============================================================
Write-Host ""
Write-Host "[5/5] 查看启动日志验证版本号..." -ForegroundColor Green
Write-Host ""

Start-Sleep -Seconds 2

# 查看最近的启动日志
$logCommand = @"
docker logs belt-control-latest 2>&1 | grep -A 3 'STARTUP-VERSION' | tail -10
"@

Write-Host "===============================================" -ForegroundColor Yellow
Write-Host "启动日志（版本验证）" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow

ssh -o StrictHostKeyChecking=no "${DeviceUser}@${DeviceIP}" $logCommand

Write-Host "===============================================" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# 完成
# ============================================================
Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "快速验证完成！" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "下一步:" -ForegroundColor Yellow
Write-Host "  1. 查看完整日志: ssh ${DeviceUser}@${DeviceIP} 'docker logs -f belt-control-latest'" -ForegroundColor White
Write-Host "  2. 开始视频通话测试" -ForegroundColor White
Write-Host "  3. 如果崩溃，使用 GDB 调试: .\scripts\2026-01-09\02-gdb-debug-in-container.ps1 $Device" -ForegroundColor White
Write-Host ""
