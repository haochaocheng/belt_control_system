# RK3588 快速部署脚本 - 使用本地预构建镜像
# 无需工控机联网，所有依赖在本地Windows机器下载并构建

$ErrorActionPreference = "Stop"

Write-Host "=== RK3588 快速部署方案 ===`n" -ForegroundColor Green

# 配置
$LocalDockerDir = "e:\2025\3_gongkongji\belt_control_system\docker\rk3588"
$LocalBuildBinary = "e:\2025\3_gongkongji\belt_control_system\build_rk3588\bin_arm64\belt_control_system"
$LocalLibs = "$LocalDockerDir\rk3588-libs\lib"
$LocalQt6 = "$LocalDockerDir\qt-raspi"

# 目标设备配置（可修改）
$TargetDevice = "155"  # 可选: "155" 或 "170"

if ($TargetDevice -eq "155") {
    $DeviceIP = "192.168.10.155"
    $DeviceUser = "linaro"
    $DevicePass = "linaro"
} else {
    $DeviceIP = "192.168.10.170"
    $DeviceUser = "pi"
    $DevicePass = "pi"
}

Write-Host "目标设备: $DeviceIP ($DeviceUser)" -ForegroundColor Cyan
Write-Host ""

# ===== 步骤 1: 在本地构建ARM64镜像 =====
Write-Host "步骤 1/4: 在本地构建ARM64镜像..." -ForegroundColor Yellow
Write-Host "使用本地预构建基础镜像 belt-control-base:prebuilt" -ForegroundColor Gray

# 检查v1.1基础镜像是否存在（包含完整依赖）
$BaseImageExists = docker images -q belt-control-base:prebuilt-v1.1
if (-not $BaseImageExists) {
    Write-Host "v1.1基础镜像不存在，正在构建（包含libxcb-dri2和libpulsecommon）..." -ForegroundColor Gray
    docker buildx build --platform linux/arm64 -f "$LocalDockerDir\Dockerfile.base-prebuilt" -t belt-control-base:prebuilt-v1.1 --load "$LocalDockerDir"
    if ($LASTEXITCODE -ne 0) {
        throw "基础镜像构建失败"
    }
} else {
    Write-Host "✓ v1.1基础镜像已存在（136MB，含完整依赖）" -ForegroundColor Green
}

# 创建临时构建目录
$TempBuildDir = "$env:TEMP\belt-control-build-$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Force -Path $TempBuildDir | Out-Null
Write-Host "临时构建目录: $TempBuildDir" -ForegroundColor Gray

# 创建完整应用镜像的Dockerfile（基于预构建基础镜像）
$DockerfileContent = @"
# 使用本地预构建的ARM64基础镜像 v1.1（包含完整依赖）
FROM belt-control-base:prebuilt-v1.1

WORKDIR /app

# 复制应用程序
COPY belt_control_system /app/
RUN chmod +x /app/belt_control_system

# 复制系统库
COPY lib /app/libs

# 复制Qt6运行时
COPY qt6/lib /opt/qt6/lib
COPY qt6/plugins /opt/qt6/plugins
COPY qt6/qml /opt/qt6/qml

# 环境变量
ENV LD_LIBRARY_PATH=/app/libs:/opt/qt6/lib
ENV QT_PLUGIN_PATH=/opt/qt6/plugins
ENV QML2_IMPORT_PATH=/opt/qt6/qml
ENV QT_QPA_PLATFORM=eglfs
ENV QT_QPA_EGLFS_INTEGRATION=eglfs_kms

# 创建配置和数据目录
RUN mkdir -p /app/config /app/data

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD pgrep -f belt_control_system || exit 1

CMD ["/app/belt_control_system"]
"@

$DockerfileContent | Out-File -FilePath "$TempBuildDir\Dockerfile" -Encoding UTF8 -NoNewline

# 复制必要文件到构建目录
Write-Host "准备构建上下文..." -ForegroundColor Gray
Copy-Item $LocalBuildBinary -Destination "$TempBuildDir\belt_control_system"
Copy-Item -Recurse $LocalLibs -Destination "$TempBuildDir\lib"
Copy-Item -Recurse "$LocalQt6\lib" -Destination "$TempBuildDir\qt6\lib"
Copy-Item -Recurse "$LocalQt6\plugins" -Destination "$TempBuildDir\qt6\plugins"
Copy-Item -Recurse "$LocalQt6\qml" -Destination "$TempBuildDir\qt6\qml"

# 构建完整应用镜像
Write-Host "开始构建完整应用镜像..." -ForegroundColor Gray
docker buildx build --platform linux/arm64 -f "$TempBuildDir\Dockerfile" -t belt-control:local-build --load "$TempBuildDir"

if ($LASTEXITCODE -ne 0) {
    throw "应用镜像构建失败"
}

Write-Host "✓ 镜像构建完成" -ForegroundColor Green
Write-Host ""

# ===== 步骤 2: 导出镜像为tar文件 =====
Write-Host "步骤 2/4: 导出镜像..." -ForegroundColor Yellow
$ImageTarPath = "$env:TEMP\belt-control-local-$(Get-Date -Format 'yyyyMMdd-HHmmss').tar"
Write-Host "导出路径: $ImageTarPath" -ForegroundColor Gray

docker save belt-control:local-build -o $ImageTarPath

if ($LASTEXITCODE -ne 0) {
    throw "镜像导出失败"
}

$ImageSizeMB = [math]::Round((Get-Item $ImageTarPath).Length / 1MB, 2)
Write-Host "✓ 镜像已导出 ($ImageSizeMB MB)" -ForegroundColor Green
Write-Host ""

# ===== 步骤 3: 传输到目标设备 =====
Write-Host "步骤 3/4: 传输镜像到 $DeviceIP..." -ForegroundColor Yellow
Write-Host "预计传输时间: $(([math]::Round($ImageSizeMB / 10, 1))) 分钟 (假设10MB/s)" -ForegroundColor Gray

scp $ImageTarPath "${DeviceUser}@${DeviceIP}:/tmp/belt-control.tar"

if ($LASTEXITCODE -ne 0) {
    throw "镜像传输失败"
}

Write-Host "✓ 镜像传输完成" -ForegroundColor Green
Write-Host ""

# ===== 步骤 4: 在目标设备加载并运行 =====
Write-Host "步骤 4/4: 在目标设备加载并测试镜像..." -ForegroundColor Yellow

# 加载镜像
Write-Host "加载镜像..." -ForegroundColor Gray
ssh "${DeviceUser}@${DeviceIP}" "docker load -i /tmp/belt-control.tar && rm /tmp/belt-control.tar"

if ($LASTEXITCODE -ne 0) {
    throw "镜像加载失败"
}

# 测试运行
Write-Host "测试运行..." -ForegroundColor Gray
ssh "${DeviceUser}@${DeviceIP}" "docker run --rm belt-control:local-build --help 2>&1 | head -n 5"

Write-Host ""
Write-Host "=== 部署完成 ===`n" -ForegroundColor Green

# 清理临时文件
Write-Host "清理临时文件..." -ForegroundColor Gray
Remove-Item -Recurse -Force $TempBuildDir
Remove-Item -Force $ImageTarPath

Write-Host ""
Write-Host "后续操作:" -ForegroundColor Yellow
Write-Host "1. 在 $DeviceIP 上运行测试:"
Write-Host "   docker run --rm --security-opt apparmor=unconfined belt-control:local-build"
Write-Host ""
Write-Host "2. 持久化运行:"
Write-Host "   docker run -d --name belt-control-app --restart unless-stopped \"
Write-Host "     --security-opt apparmor=unconfined \"
Write-Host "     -v /app/config:/app/config \"
Write-Host "     -v /app/data:/app/data \"
Write-Host "     belt-control:local-build"
Write-Host ""
Write-Host "3. 查看日志:"
Write-Host "   docker logs -f belt-control-app"
Write-Host ""
Write-Host "4. 分发到其他设备:"
Write-Host "   在155上运行: scp ${DeviceUser}@${DeviceIP}:/tmp/belt-control.tar ."
Write-Host "   传到其他设备: scp belt-control.tar pi@192.168.10.XXX:/tmp/"
Write-Host "   加载: docker load -i /tmp/belt-control.tar"
Write-Host ""
