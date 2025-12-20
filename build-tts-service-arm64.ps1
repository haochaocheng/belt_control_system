# Build Sherpa-ONNX TTS Service for ARM64 Linux
# 使用交叉编译环境编译TTS服务

$ErrorActionPreference = "Stop"

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Build TTS Service for ARM64" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"
$BuildDir = "$ProjectRoot\build_tts_arm64"

# 清理旧构建目录
if (Test-Path $BuildDir) {
    Write-Host "Cleaning old build directory..." -ForegroundColor Yellow
    Remove-Item $BuildDir -Recurse -Force
}

Write-Host "Running CMake in Docker container..." -ForegroundColor Cyan
Write-Host ""

# 使用Docker容器进行交叉编译
docker run --rm `
  -v "e:/2025/3_gongkongji/belt_control_system:/workspace" `
  -v "e:/2025/3_gongkongji/belt_control_system/docker/rk3588/qt-host:/opt/qt-host:ro" `
  -v "e:/2025/3_gongkongji/belt_control_system/docker/rk3588/qt-raspi:/opt/qt-raspi:ro" `
  -v "e:/2025/3_gongkongji/belt_control_system/docker/rk3588/sysroot:/opt/sysroot:ro" `
  -v "e:/2025/3_gongkongji/belt_control_system/docker/rk3588/rk3588-libs:/opt/rk3588-libs:ro" `
  -e QT_HOST_PATH=/opt/qt-host `
  -e QT_TARGET_PATH=/opt/qt-raspi `
  -e SYSROOT=/opt/sysroot/pi-root `
  -w /workspace `
  belt-control-rk3588:latest bash -c 'mkdir -p build_tts_arm64 && cd build_tts_arm64 && cmake ../src/tts_service -DCMAKE_TOOLCHAIN_FILE=/opt/qt-raspi/lib/cmake/Qt6/qt.toolchain.cmake -DQT_CHAINLOAD_TOOLCHAIN_FILE=/workspace/docker/rk3588/toolchain-rk3588.cmake -DCMAKE_BUILD_TYPE=Release && cmake --build . --parallel && echo "TTS service built successfully"'

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Green
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""

$outputFile = "$ProjectRoot\build_tts_arm64\sherpa_tts_service"
if (Test-Path $outputFile) {
    $fileSize = [math]::Round((Get-Item $outputFile).Length / 1KB, 1)
    Write-Host "Output file: $outputFile" -ForegroundColor White
    Write-Host "Size: ${fileSize}KB" -ForegroundColor White
} else {
    Write-Host "WARNING: Output file not found" -ForegroundColor Yellow
}
