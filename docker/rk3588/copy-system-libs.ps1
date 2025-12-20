# 从 sysroot 复制兼容的 FFmpeg 和 SDL2 库
# 这些库来自 NanoPi-R6C，已经是兼容 glibc 2.36 的版本

$SysrootLibs = "F:\0\tool\nanopi-sysroot\lib\aarch64-linux-gnu"
$TargetDir = "e:\2025\3_gongkongji\belt_control_system\docker\rk3588\rk3588-libs\lib"

Write-Host "从 sysroot 复制 FFmpeg 和 SDL2 库..." -ForegroundColor Yellow
Write-Host ""

# FFmpeg 库
$ffmpegLibs = @(
    "libavcodec.so.58.91.100",
    "libavdevice.so.58.10.100",
    "libavfilter.so.7.85.100",
    "libavformat.so.58.45.100",
    "libavutil.so.56.51.100",
    "libavresample.so.4.0.0",
    "libswresample.so.3.7.100",
    "libswscale.so.5.7.100",
    "libpostproc.so.55.7.100"
)

# SDL2 库
$sdl2Libs = @(
    "libSDL2-2.0.so.0.14.0"
)

$allLibs = $ffmpegLibs + $sdl2Libs

$copied = 0
$notFound = 0

foreach ($lib in $allLibs) {
    $srcPath = Join-Path $SysrootLibs $lib
    if (Test-Path $srcPath) {
        Copy-Item $srcPath $TargetDir -Force
        Write-Host "  ✅ $lib" -ForegroundColor Green
        $copied++
    } else {
        Write-Host "  ⚠️  未找到: $lib" -ForegroundColor Yellow
        $notFound++
    }
}

Write-Host ""
Write-Host "复制完成: $copied 个库" -ForegroundColor Green
if ($notFound -gt 0) {
    Write-Host "未找到: $notFound 个库" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "检查 glibc 版本..." -ForegroundColor Yellow

# 使用 strings 检查 glibc 版本（需要在 Docker 容器中执行）
$checkCmd = @"
docker run --rm -v 'e:/2025/3_gongkongji/belt_control_system/docker/rk3588/rk3588-libs:/opt/rk3588-libs:ro' belt-control-rk3588:latest bash -c 'strings /opt/rk3588-libs/lib/libavutil.so.56.51.100 | grep GLIBC_ | sort -Vu | tail -5'
"@

Write-Host "libavutil.so glibc 依赖:" -ForegroundColor Gray
Invoke-Expression "powershell.exe -Command `"$checkCmd`""

Write-Host ""
Write-Host "完成！" -ForegroundColor Green
