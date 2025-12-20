# Build Base Image Only Script
# 单独构建基础依赖镜像（包含系统库）
# 使用场景：更新系统依赖时

$ErrorActionPreference = "Stop"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Building Base Image (System Dependencies)" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"
$BaseImageName = "belt-control-base"
$BaseImageTag = "ubuntu24"
$BaseCacheFile = "$ProjectRoot\.docker_base_cache.json"

Write-Host "========================================================" -ForegroundColor Yellow
Write-Host "  将下载约 200MB 系统依赖库 (About 200MB download)" -ForegroundColor Yellow
Write-Host "  预计耗时 5-10 分钟 (Estimated 5-10 minutes)" -ForegroundColor Yellow
Write-Host "  建议打开网络加速器 (Recommended: Enable VPN/proxy)" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "已打开加速器? 按任意键继续..." -ForegroundColor Cyan
Write-Host "VPN/proxy ready? Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host ""

Write-Host "Building base image..." -ForegroundColor Yellow
$buildStart = Get-Date

docker build --platform linux/arm64 --no-cache -f "$ProjectRoot\Dockerfile.ubuntu24-base" -t "${BaseImageName}:${BaseImageTag}" "$ProjectRoot"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Base image build failed" -ForegroundColor Red
    exit 1
}

$buildDuration = (Get-Date) - $buildStart
Write-Host ""
Write-Host "✅ Base image built successfully" -ForegroundColor Green
Write-Host "⏱️  Build time: $($buildDuration.Minutes) min $($buildDuration.Seconds) sec" -ForegroundColor Cyan
Write-Host ""

# Save base image hash
$baseDockerfilePath = "$ProjectRoot\Dockerfile.ubuntu24-base"
if (Test-Path $baseDockerfilePath) {
    $currentBaseHash = (Get-FileHash -Path $baseDockerfilePath -Algorithm MD5).Hash
    @{ hash = $currentBaseHash; timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") } | ConvertTo-Json | Set-Content $BaseCacheFile
    Write-Host "✅ Cache updated" -ForegroundColor Green
}

Write-Host ""
Write-Host "Base image ready: ${BaseImageName}:${BaseImageTag}" -ForegroundColor Cyan
Write-Host "You can now run: .\build-ubuntu24-apt.ps1 151" -ForegroundColor White
