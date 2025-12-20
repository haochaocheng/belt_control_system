# 部署完整Qt6环境到155设备并构建Docker镜像
# 包含 Qt6 lib, plugins, qml + 系统库 + 应用程序

$ErrorActionPreference = "Stop"

Write-Host "=== RK3588 完整Qt6环境部署 ===" -ForegroundColor Green
Write-Host ""

# 配置
$DeviceIP = "192.168.10.155"
$DeviceUser = "linaro"
$BuildDir = "/home/linaro/belt-control-qt6"
$LocalBuildBinary = "e:\2025\3_gongkongji\belt_control_system\build_rk3588\bin_arm64\belt_control_system"
$LocalLibs = "e:\2025\3_gongkongji\belt_control_system\docker\rk3588\rk3588-libs\lib"
$LocalQt6 = "e:\2025\3_gongkongji\belt_control_system\docker\rk3588\qt-raspi"

Write-Host "1. 创建远程构建目录..." -ForegroundColor Yellow
ssh "$DeviceUser@$DeviceIP" "rm -rf $BuildDir && mkdir -p $BuildDir/qt6"

Write-Host ""
Write-Host "2. 传输应用程序二进制文件 (8 MB)..." -ForegroundColor Yellow
scp "$LocalBuildBinary" "${DeviceUser}@${DeviceIP}:$BuildDir/"

Write-Host ""
Write-Host "3. 传输系统库 (225 MB)..." -ForegroundColor Yellow
ssh "$DeviceUser@$DeviceIP" "mkdir -p $BuildDir/libs"
# 使用tar压缩传输以加快速度
tar -czf "$env:TEMP\libs.tar.gz" -C "$LocalLibs\.." (Split-Path -Leaf $LocalLibs)
scp "$env:TEMP\libs.tar.gz" "${DeviceUser}@${DeviceIP}:/tmp/"
ssh "$DeviceUser@$DeviceIP" "cd $BuildDir && tar -xzf /tmp/libs.tar.gz && rm /tmp/libs.tar.gz"

Write-Host ""
Write-Host "4. 传输Qt6完整环境..." -ForegroundColor Yellow
Write-Host "   - Qt6 lib目录..." -ForegroundColor Gray
ssh "$DeviceUser@$DeviceIP" "mkdir -p $BuildDir/qt6/lib $BuildDir/qt6/plugins $BuildDir/qt6/qml"

# Qt6 lib (约900MB)
Write-Host "   正在打包Qt6库..." -ForegroundColor Gray
tar -czf "$env:TEMP\qt6-lib.tar.gz" -C "$LocalQt6" "lib"
Write-Host "   传输Qt6库..." -ForegroundColor Gray
scp "$env:TEMP\qt6-lib.tar.gz" "${DeviceUser}@${DeviceIP}:/tmp/"
ssh "$DeviceUser@$DeviceIP" "cd $BuildDir/qt6 && tar -xzf /tmp/qt6-lib.tar.gz && rm /tmp/qt6-lib.tar.gz"

# Qt6 plugins (包括xcbglintegrations)
Write-Host "   - Qt6 plugins目录 (含xcbglintegrations)..." -ForegroundColor Gray
tar -czf "$env:TEMP\qt6-plugins.tar.gz" -C "$LocalQt6" "plugins"
scp "$env:TEMP\qt6-plugins.tar.gz" "${DeviceUser}@${DeviceIP}:/tmp/"
ssh "$DeviceUser@$DeviceIP" "cd $BuildDir/qt6 && tar -xzf /tmp/qt6-plugins.tar.gz && rm /tmp/qt6-plugins.tar.gz"

# Qt6 qml
Write-Host "   - Qt6 qml目录..." -ForegroundColor Gray
tar -czf "$env:TEMP\qt6-qml.tar.gz" -C "$LocalQt6" "qml"
scp "$env:TEMP\qt6-qml.tar.gz" "${DeviceUser}@${DeviceIP}:/tmp/"
ssh "$DeviceUser@$DeviceIP" "cd $BuildDir/qt6 && tar -xzf /tmp/qt6-qml.tar.gz && rm /tmp/qt6-qml.tar.gz"

Write-Host ""
Write-Host "5. 创建Dockerfile..." -ForegroundColor Yellow

$DockerfileContent = @"
FROM debian:bookworm-slim

# 安装系统运行时依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpulse0 libgles2 libegl1 libgl1 libxkbcommon0 \
    libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 \
    libxcb-render-util0 libxcb-shape0 libxcb-xinerama0 \
    libxcb-xfixes0 libxcb-sync1 libdbus-1-3 \
    libfontconfig1 libfreetype6 libx11-6 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

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

RUN mkdir -p /app/config /app/data

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD pgrep -f belt_control_system || exit 1

CMD ["/app/belt_control_system"]
"@

$DockerfileContent | Out-File -FilePath "$env:TEMP\Dockerfile" -Encoding UTF8 -NoNewline
scp "$env:TEMP\Dockerfile" "${DeviceUser}@${DeviceIP}:$BuildDir/"

Write-Host ""
Write-Host "6. 开始构建Docker镜像..." -ForegroundColor Yellow
Write-Host "   (预计需要10-15分钟,镜像大小约1.5GB)" -ForegroundColor Gray
Write-Host ""

ssh "$DeviceUser@$DeviceIP" "cd $BuildDir && docker build -t belt-control:qt6-complete . 2>&1"

Write-Host ""
Write-Host "=== 构建完成 ===" -ForegroundColor Green
Write-Host ""
Write-Host "下一步操作:" -ForegroundColor Yellow
Write-Host "1. 导出镜像: docker save belt-control:qt6-complete -o /tmp/belt-control-qt6.tar"
Write-Host "2. 传回本机: scp linaro@192.168.10.155:/tmp/belt-control-qt6.tar ."
Write-Host "3. 分发到其他工控机: scp belt-control-qt6.tar pi@192.168.10.170:/tmp/"
Write-Host "4. 加载镜像: docker load -i /tmp/belt-control-qt6.tar"
Write-Host "5. 运行测试: docker run --rm --security-opt apparmor=unconfined belt-control:qt6-complete --help"
Write-Host ""
