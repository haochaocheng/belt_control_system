# RK3588 本地快速部署到155设备
# 所有依赖在本地下载，无需工控机联网

$ErrorActionPreference = "Stop"

Write-Host "=== 本地构建并部署到155设备 ===" -ForegroundColor Green
Write-Host ""

# 配置
$LocalDockerDir = "e:\2025\3_gongkongji\belt_control_system\docker\rk3588"
$LocalBuildBinary = "e:\2025\3_gongkongji\belt_control_system\build_rk3588\bin_arm64\belt_control_system"
$LocalLibs = "$LocalDockerDir\rk3588-libs\lib"
$LocalQt6 = "$LocalDockerDir\qt-raspi"

# 目标设备
$DeviceIP = "192.168.10.155"
$DeviceUser = "linaro"
$DevicePass = "linaro"

Write-Host "目标设备: $DeviceIP ($DeviceUser)" -ForegroundColor Cyan
Write-Host ""

# 步骤 1: 检查v1.1基础镜像
Write-Host "步骤 1/5: 检查基础镜像..." -ForegroundColor Yellow
$BaseImageExists = docker images -q belt-control-base:prebuilt-v1.1
if (-not $BaseImageExists) {
    Write-Host "ERROR: v1.1基础镜像不存在" -ForegroundColor Red
    Write-Host "请先运行构建基础镜像" -ForegroundColor Red
    exit 1
}
Write-Host "✓ v1.1基础镜像已存在" -ForegroundColor Green
Write-Host ""

# 步骤 2: 创建临时构建目录
Write-Host "步骤 2/5: 准备构建上下文..." -ForegroundColor Yellow
$TempBuildDir = "$env:TEMP\belt-control-build-$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Force -Path $TempBuildDir | Out-Null
New-Item -ItemType Directory -Force -Path "$TempBuildDir\qt6" | Out-Null
Write-Host "临时目录: $TempBuildDir" -ForegroundColor Gray

# 创建Dockerfile
$DockerfileContent = @'
FROM belt-control-base:prebuilt-v1.1

WORKDIR /app

COPY belt_control_system /app/
RUN chmod +x /app/belt_control_system

COPY lib /app/libs
COPY qt6/lib /opt/qt6/lib
COPY qt6/plugins /opt/qt6/plugins
COPY qt6/qml /opt/qt6/qml

ENV LD_LIBRARY_PATH=/app/libs:/opt/qt6/lib
ENV QT_PLUGIN_PATH=/opt/qt6/plugins
ENV QML2_IMPORT_PATH=/opt/qt6/qml
ENV QT_QPA_PLATFORM=eglfs
ENV QT_QPA_EGLFS_INTEGRATION=eglfs_kms

RUN mkdir -p /app/config /app/data

CMD ["/app/belt_control_system"]
'@

$DockerfileContent | Out-File -FilePath "$TempBuildDir\Dockerfile" -Encoding ASCII

# 复制文件
Write-Host "复制应用程序和依赖..." -ForegroundColor Gray
Copy-Item $LocalBuildBinary -Destination "$TempBuildDir\belt_control_system"
Copy-Item -Recurse $LocalLibs -Destination "$TempBuildDir\lib"
Copy-Item -Recurse "$LocalQt6\lib" -Destination "$TempBuildDir\qt6\lib"
Copy-Item -Recurse "$LocalQt6\plugins" -Destination "$TempBuildDir\qt6\plugins"
Copy-Item -Recurse "$LocalQt6\qml" -Destination "$TempBuildDir\qt6\qml"

Write-Host "✓ 构建上下文准备完成" -ForegroundColor Green
Write-Host ""

# 步骤 3: 构建完整应用镜像
Write-Host "步骤 3/5: 构建完整应用镜像..." -ForegroundColor Yellow
docker buildx build --platform linux/arm64 -f "$TempBuildDir\Dockerfile" -t belt-control:local-build --load "$TempBuildDir"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: 镜像构建失败" -ForegroundColor Red
    exit 1
}

Write-Host "✓ 镜像构建完成" -ForegroundColor Green
Write-Host ""

# 步骤 4: 导出镜像
Write-Host "步骤 4/5: 导出镜像..." -ForegroundColor Yellow
$ImageTarPath = "$env:TEMP\belt-control-155-$(Get-Date -Format 'yyyyMMdd-HHmmss').tar"
docker save belt-control:local-build -o $ImageTarPath

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: 镜像导出失败" -ForegroundColor Red
    exit 1
}

$ImageSizeMB = [math]::Round((Get-Item $ImageTarPath).Length / 1MB, 2)
Write-Host "✓ 镜像已导出: $ImageSizeMB MB" -ForegroundColor Green
Write-Host ""

# 步骤 5: 传输并加载到155
Write-Host "步骤 5/5: 传输并加载到155..." -ForegroundColor Yellow
Write-Host "传输镜像到155设备..." -ForegroundColor Gray
scp $ImageTarPath "${DeviceUser}@${DeviceIP}:/tmp/belt-control.tar"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: 镜像传输失败" -ForegroundColor Red
    exit 1
}

Write-Host "加载镜像..." -ForegroundColor Gray
ssh "${DeviceUser}@${DeviceIP}" "docker load -i /tmp/belt-control.tar"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: 镜像加载失败" -ForegroundColor Red
    exit 1
}

Write-Host "✓ 镜像已加载到155设备" -ForegroundColor Green
Write-Host ""

# 测试库依赖
Write-Host "验证库依赖..." -ForegroundColor Gray
ssh "${DeviceUser}@${DeviceIP}" "docker run --rm --entrypoint ldd belt-control:local-build /app/belt_control_system | grep 'not found'" | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "WARNING: 发现缺失的库" -ForegroundColor Yellow
    ssh "${DeviceUser}@${DeviceIP}" "docker run --rm --entrypoint ldd belt-control:local-build /app/belt_control_system | grep 'not found'"
} else {
    Write-Host "✓ 所有库依赖完整" -ForegroundColor Green
}

# 清理
Write-Host ""
Write-Host "清理临时文件..." -ForegroundColor Gray
Remove-Item -Recurse -Force $TempBuildDir
Remove-Item -Force $ImageTarPath
ssh "${DeviceUser}@${DeviceIP}" "rm -f /tmp/belt-control.tar"

Write-Host ""
Write-Host "=== 部署完成 ===" -ForegroundColor Green
Write-Host ""
Write-Host "在155设备上测试运行:" -ForegroundColor Yellow
Write-Host "  ssh $DeviceUser@$DeviceIP" -ForegroundColor Gray
Write-Host "  docker run --rm --security-opt apparmor=unconfined belt-control:local-build" -ForegroundColor Gray
Write-Host ""
