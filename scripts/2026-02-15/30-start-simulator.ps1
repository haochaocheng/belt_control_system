#Requires -Version 5.1
<#
.SYNOPSIS
    启动RK3588模拟环境
.DESCRIPTION
    一键启动模拟环境，自动打开浏览器
.EXAMPLE
    .\30-start-simulator.ps1
.NOTES
    2026-02-15 19:30: 创建 - RK3588模拟环境启动脚本
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  启动 RK3588 模拟环境" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查Docker是否运行
Write-Host "[1/5] 检查Docker状态..." -ForegroundColor Yellow
$dockerRunning = docker ps 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Docker未运行，请先启动Docker Desktop" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Docker运行正常" -ForegroundColor Green
Write-Host ""

# 检查镜像是否存在
Write-Host "[2/5] 检查模拟器镜像..." -ForegroundColor Yellow
$imageExists = docker images -q belt-control-simulator:latest 2>$null

if (-not $imageExists) {
    Write-Host "  ⚠️  镜像不存在，开始构建..." -ForegroundColor Yellow
    Write-Host ""

    # 构建镜像
    docker build -t belt-control-simulator:latest -f docker/rk3588-simulator/Dockerfile .

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  ❌ 镜像构建失败" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "  ✅ 镜像构建成功" -ForegroundColor Green
} else {
    Write-Host "  ✅ 镜像已存在" -ForegroundColor Green
}
Write-Host ""

# 停止旧容器
Write-Host "[3/5] 清理旧容器..." -ForegroundColor Yellow
docker stop belt-control-sim 2>$null | Out-Null
docker rm belt-control-sim 2>$null | Out-Null
Write-Host "  ✅ 清理完成" -ForegroundColor Green
Write-Host ""

# 启动新容器
Write-Host "[4/5] 启动模拟环境..." -ForegroundColor Yellow

$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"

# 检查目录是否存在
$binDir = Join-Path $ProjectRoot "build_rk3588\bin_arm64"
$libDir = Join-Path $ProjectRoot "docker\rk3588\lib"
$configDir = Join-Path $ProjectRoot "config"

# 构建docker run命令
$dockerArgs = @(
    "run", "-d",
    "--name", "belt-control-sim",
    "-p", "6080:6080",
    "-p", "5901:5901"
)

# 挂载到/mnt目录，避免/app冲突
if (Test-Path $binDir) {
    $dockerArgs += "-v"
    $dockerArgs += "${binDir}:/mnt/app:ro"
} else {
    Write-Host "  ⚠️  应用程序目录不存在: $binDir" -ForegroundColor Yellow
}

if (Test-Path $libDir) {
    $dockerArgs += "-v"
    $dockerArgs += "${libDir}:/mnt/lib:ro"
} else {
    Write-Host "  ⚠️  库目录不存在: $libDir" -ForegroundColor Yellow
}

if (Test-Path $configDir) {
    $dockerArgs += "-v"
    $dockerArgs += "${configDir}:/mnt/config:ro"
} else {
    Write-Host "  ⚠️  配置目录不存在: $configDir" -ForegroundColor Yellow
}

# 挂载配置文件
$dockerArgs += "-v"
$dockerArgs += "${ProjectRoot}/docker/rk3588-simulator/supervisord.conf:/etc/supervisor/supervisord.conf:ro"
$dockerArgs += "-v"
$dockerArgs += "${ProjectRoot}/docker/rk3588-simulator/start.sh:/start.sh:ro"

# 镜像和启动命令
$dockerArgs += "belt-control-simulator:latest"
$dockerArgs += "/start.sh"

& docker @dockerArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "  ❌ 容器启动失败" -ForegroundColor Red
    exit 1
}

Write-Host "  ✅ 容器启动成功" -ForegroundColor Green
Write-Host ""

# 等待服务启动
Write-Host "[5/5] 等待服务启动..." -ForegroundColor Yellow
Start-Sleep -Seconds 8
Write-Host "  ✅ 服务已就绪" -ForegroundColor Green
Write-Host ""

# 显示访问信息
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 模拟环境已启动" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "📺 访问方式：" -ForegroundColor Yellow
Write-Host "   浏览器: http://localhost:6080" -ForegroundColor Cyan
Write-Host "   VNC客户端: localhost:5901 (密码: 123456)" -ForegroundColor Gray
Write-Host ""

Write-Host "📝 管理命令：" -ForegroundColor Yellow
Write-Host "   查看日志: docker logs -f belt-control-sim" -ForegroundColor Gray
Write-Host "   停止容器: docker stop belt-control-sim" -ForegroundColor Gray
Write-Host "   重启容器: docker restart belt-control-sim" -ForegroundColor Gray
Write-Host ""

# 自动打开浏览器
Write-Host "🌐 正在打开浏览器..." -ForegroundColor Cyan
Start-Sleep -Seconds 2
Start-Process "http://localhost:6080"

Write-Host ""
Write-Host "💡 提示: 如果界面未显示，请等待10-15秒后刷新浏览器" -ForegroundColor Yellow
Write-Host ""
