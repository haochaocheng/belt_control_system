# RK3588 ARM64 交叉编译脚本 - 基于成功的方法
param(
    [int]$Threads = 32
)

$ErrorActionPreference = "Stop"
$ProjectRoot = "e:/2025/3_gongkongji/belt_control_system"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RK3588 Docker Cross-Compilation v3.3" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 使用已知成功的Docker镜像
$imageName = "belt-control-compiler:rk3588"

# 检查镜像是否存在
$imageExists = docker images -q $imageName
if (-not $imageExists) {
    Write-Host "编译镜像不存在，正在检查备用镜像..." -ForegroundColor Yellow

    # 检查其他可能的镜像名称
    $alternativeImages = @(
        "rk3588-compiler:latest",
        "belt-compiler:latest"
    )

    foreach ($altImage in $alternativeImages) {
        $exists = docker images -q $altImage
        if ($exists) {
            $imageName = $altImage
            Write-Host "  使用备用镜像: $imageName" -ForegroundColor Green
            break
        }
    }

    if (-not (docker images -q $imageName)) {
        Write-Error "未找到编译镜像，请先构建镜像"
        exit 1
    }
}

Write-Host "使用镜像: $imageName" -ForegroundColor Gray

# 准备构建目录
$buildDir = "$ProjectRoot/build_rk3588"
Write-Host "准备构建目录..." -ForegroundColor Yellow

# 运行编译
Write-Host "开始编译 (使用 $Threads 线程)..." -ForegroundColor Yellow

# 使用成功的编译命令
$cmakeCmd = "cmake -DCMAKE_TOOLCHAIN_FILE=/opt/qt-raspi/lib/cmake/Qt6/qt.toolchain.cmake -DQT_CHAINLOAD_TOOLCHAIN_FILE=/workspace/docker/rk3588/toolchain-rk3588.cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_SHERPA_ONNX=ON .."
$makeCmd = "make -j$Threads"

# 分两步执行，便于调试
Write-Host "  Step 1: 配置CMake..." -ForegroundColor Gray
docker run --rm `
    -v "${ProjectRoot}:/workspace" `
    -v "${ProjectRoot}/docker/rk3588/qt-host:/opt/qt-host:ro" `
    -v "${ProjectRoot}/docker/rk3588/qt-raspi:/opt/qt-raspi:ro" `
    -v "${ProjectRoot}/docker/rk3588/sysroot:/opt/sysroot:ro" `
    -v "${ProjectRoot}/docker/rk3588/rk3588-libs:/opt/rk3588-libs:ro" `
    -e QT_HOST_PATH=/opt/qt-host `
    -e QT_TARGET_PATH=/opt/qt-raspi `
    -e SYSROOT=/opt/sysroot/rk3588-root `
    -w /workspace/build_rk3588 `
    $imageName `
    bash -c "$cmakeCmd"

if ($LASTEXITCODE -ne 0) {
    Write-Error "CMake配置失败"
    exit 1
}

Write-Host "  Step 2: 编译..." -ForegroundColor Gray
docker run --rm `
    -v "${ProjectRoot}:/workspace" `
    -v "${ProjectRoot}/docker/rk3588/qt-host:/opt/qt-host:ro" `
    -v "${ProjectRoot}/docker/rk3588/qt-raspi:/opt/qt-raspi:ro" `
    -v "${ProjectRoot}/docker/rk3588/sysroot:/opt/sysroot:ro" `
    -v "${ProjectRoot}/docker/rk3588/rk3588-libs:/opt/rk3588-libs:ro" `
    -e QT_HOST_PATH=/opt/qt-host `
    -e QT_TARGET_PATH=/opt/qt-raspi `
    -e SYSROOT=/opt/sysroot/rk3588-root `
    -w /workspace/build_rk3588 `
    $imageName `
    bash -c "$makeCmd"

if ($LASTEXITCODE -eq 0) {
    $binary = "$ProjectRoot/build_rk3588/bin_arm64/belt_control_system"
    if (Test-Path $binary) {
        $size = (Get-Item $binary).Length / 1MB
        Write-Host "`n✅ 编译成功!" -ForegroundColor Green
        Write-Host "二进制文件: $binary" -ForegroundColor Gray
        Write-Host "文件大小: $([Math]::Round($size, 2)) MB" -ForegroundColor Gray
    } else {
        Write-Warning "编译似乎成功但未找到输出文件"
    }
} else {
    Write-Error "编译失败"
    exit 1
}

Write-Host "`n提示：使用简化部署脚本进行部署" -ForegroundColor Cyan
Write-Host "  .\build-deploy-workflow-simple.ps1" -ForegroundColor Gray