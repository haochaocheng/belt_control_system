# RK3588 依赖库编译脚本
# PowerShell 版本

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RK3588 依赖库交叉编译" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查Docker是否运行
Write-Host "检查 Docker 状态..." -ForegroundColor Yellow
try {
    docker ps | Out-Null
    Write-Host "✓ Docker 正在运行" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker 未运行，请启动 Docker Desktop" -ForegroundColor Red
    pause
    exit 1
}

# 检查镜像是否存在
Write-Host "检查 Docker 镜像..." -ForegroundColor Yellow
$imageExists = docker images belt-control-rk3588:latest -q
if ([string]::IsNullOrEmpty($imageExists)) {
    Write-Host "✗ 找不到 Docker 镜像 belt-control-rk3588:latest" -ForegroundColor Red
    Write-Host "  请先构建基础镜像" -ForegroundColor Red
    pause
    exit 1
}
Write-Host "✓ Docker 镜像已就绪" -ForegroundColor Green
Write-Host ""

# 获取项目目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent (Split-Path -Parent $scriptDir)

Write-Host "开始编译所有依赖库..." -ForegroundColor Cyan
Write-Host "目标平台: ARM64 (aarch64)" -ForegroundColor White
Write-Host "编译顺序:" -ForegroundColor White
Write-Host "  1. OpenSSL 3.3.2 (~5分钟)" -ForegroundColor Gray
Write-Host "  2. Opus 1.4 (~3分钟)" -ForegroundColor Gray
Write-Host "  3. x264 latest (~5分钟)" -ForegroundColor Gray
Write-Host "  4. FFmpeg 4.4.4 (~10分钟)" -ForegroundColor Gray
Write-Host "  5. SDL2 2.28.5 (~3分钟)" -ForegroundColor Gray
Write-Host "  6. PJSIP 2.15.1 (~8分钟)" -ForegroundColor Gray
Write-Host "预计总时间: 约34分钟" -ForegroundColor Yellow
Write-Host ""

# 构建Docker命令（不带参数就编译所有库）
$dockerCmd = @(
    "run", "--rm",
    "-v", "$projectDir`:/workspace/belt_control_system",
    "-v", "$scriptDir\qt-host:/opt/qt-host:ro",
    "-v", "$scriptDir\qt-raspi:/opt/qt-raspi:ro",
    "-v", "$scriptDir\sysroot:/opt/sysroot:ro",
    "-v", "$scriptDir\rk3588-libs:/opt/rk3588-libs",
    "belt-control-rk3588:latest",
    "bash", "/workspace/belt_control_system/docker/rk3588/build-dependencies.sh"
)

Write-Host "执行 Docker 容器..." -ForegroundColor Yellow
Write-Host ""

# 执行Docker命令
& docker $dockerCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✓ 编译完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "编译的库位于: $scriptDir\rk3588-libs\lib" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "查看编译结果:" -ForegroundColor White
    Get-ChildItem "$scriptDir\rk3588-libs\lib" -Filter *.so* | Select-Object -First 10 | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor Gray
    }
} else {
    Write-Host ""
    Write-Host "✗ 编译失败，请检查上方错误信息" -ForegroundColor Red
    pause
    exit 1
}
