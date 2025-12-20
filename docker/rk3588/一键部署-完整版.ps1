# Belt Control System - 一键 Docker 部署脚本
# 适用于任何 aarch64 + Docker 环境
# 版本: 1.0
# 最后更新: 2025-12-15

param(
    [Parameter(Mandatory=$false)]
    [string]$TargetHost = "",

    [Parameter(Mandatory=$false)]
    [string]$TargetUser = "",

    [Parameter(Mandatory=$false)]
    [switch]$SkipSSHSetup = $false,

    [Parameter(Mandatory=$false)]
    [switch]$AutoRun = $false
)

$ErrorActionPreference = "Stop"

# ============== 配置区域 ==============
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$BuildRoot = "$ProjectRoot\build_rk3588_new"
$RK3588Libs = "$ScriptDir\rk3588-libs"
$QtLibs = "$ScriptDir\qt-raspi\lib"
$DebianImageTar = "$ScriptDir\debian-bookworm-arm64.tar"

# 如果没有提供参数,交互式询问
if ([string]::IsNullOrEmpty($TargetHost)) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Belt Control System Docker 部署" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    $TargetHost = Read-Host "请输入目标设备 IP 地址"
}

if ([string]::IsNullOrEmpty($TargetUser)) {
    $TargetUser = Read-Host "请输入目标设备用户名"
}

$RemoteBuildDir = "/home/$TargetUser/belt-control-build"

Write-Host ""
Write-Host "部署目标: ${TargetUser}@${TargetHost}" -ForegroundColor Green
Write-Host "远程目录: $RemoteBuildDir" -ForegroundColor Gray
Write-Host ""

# ============== 步骤 1: SSH 免密登录配置 ==============
if (-not $SkipSSHSetup) {
    Write-Host "[1/9] 配置 SSH 免密登录..." -ForegroundColor Yellow

    $sshKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
    $sshPubKeyPath = "$env:USERPROFILE\.ssh\id_rsa.pub"

    if (!(Test-Path $sshKeyPath)) {
        Write-Host "  生成 SSH 密钥..." -ForegroundColor Gray
        & ssh-keygen -t rsa -b 2048 -f $sshKeyPath -N '""'
    }

    Write-Host "  上传公钥到目标设备..." -ForegroundColor Gray
    Write-Host "  (可能需要输入一次密码)" -ForegroundColor DarkGray

    $pubKey = Get-Content $sshPubKeyPath -Raw
    $setupCmd = "mkdir -p ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh && echo 'SSH key configured'"

    ssh ${TargetUser}@${TargetHost} $setupCmd 2>&1 | Out-Null

    # 测试免密登录
    $testResult = ssh ${TargetUser}@${TargetHost} "echo 'OK'" 2>&1
    if ($testResult -eq "OK") {
        Write-Host "  ✅ SSH 免密登录配置成功" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ SSH 配置可能失败,但继续部署" -ForegroundColor Yellow
    }
} else {
    Write-Host "[1/9] 跳过 SSH 配置" -ForegroundColor Gray
}
Write-Host ""

# ============== 步骤 2: 检查设备环境 ==============
Write-Host "[2/9] 检查目标设备环境..." -ForegroundColor Yellow

$deviceInfo = ssh ${TargetUser}@${TargetHost} "uname -m && docker --version 2>&1" 2>&1
Write-Host "  架构: $($deviceInfo[0])" -ForegroundColor Gray

if ($deviceInfo[1] -match "Docker version") {
    Write-Host "  Docker: $($deviceInfo[1])" -ForegroundColor Gray
    Write-Host "  ✅ 环境检查通过" -ForegroundColor Green
} else {
    Write-Host "  ❌ Docker 未安装或无权限" -ForegroundColor Red
    Write-Host ""
    Write-Host "请先安装 Docker:" -ForegroundColor Yellow
    Write-Host "  curl -fsSL https://get.docker.com -o get-docker.sh" -ForegroundColor White
    Write-Host "  sudo sh get-docker.sh" -ForegroundColor White
    Write-Host "  sudo usermod -aG docker $TargetUser" -ForegroundColor White
    exit 1
}
Write-Host ""

# ============== 步骤 3: 准备远程目录 ==============
Write-Host "[3/9] 准备远程目录..." -ForegroundColor Yellow
ssh ${TargetUser}@${TargetHost} "rm -rf $RemoteBuildDir && mkdir -p $RemoteBuildDir/libs"
Write-Host "  ✅ 目录已准备" -ForegroundColor Green
Write-Host ""

# ============== 步骤 4: 传输应用二进制 ==============
Write-Host "[4/9] 传输应用二进制..." -ForegroundColor Yellow
$binaryPath = "$BuildRoot\bin_arm64\belt_control_system"
if (Test-Path $binaryPath) {
    scp "$binaryPath" "${TargetUser}@${TargetHost}:$RemoteBuildDir/" 2>$null
    $binarySize = (Get-Item $binaryPath).Length / 1MB
    Write-Host "  ✅ 二进制文件已传输 ($([math]::Round($binarySize, 1)) MB)" -ForegroundColor Green
} else {
    Write-Host "  ❌ 找不到二进制文件: $binaryPath" -ForegroundColor Red
    exit 1
}
Write-Host ""

# ============== 步骤 5: 传输 RK3588 库 ==============
Write-Host "[5/9] 传输 RK3588 库文件..." -ForegroundColor Yellow
$rk3588LibFiles = Get-ChildItem -Path "$RK3588Libs\lib" -File | Where-Object {
    ($_.Extension -match "\.so" -or $_.Name -match "\.so\.") -and
    ($_.Name -notmatch "librknn_api|v4l1compat|v4l2convert") -and
    (-not $_.LinkType)
}

$count = 0
foreach ($lib in $rk3588LibFiles) {
    scp "$($lib.FullName)" "${TargetUser}@${TargetHost}:$RemoteBuildDir/libs/" 2>$null
    $count++
    if ($count % 20 -eq 0) {
        Write-Host "    已传输 $count/$($rk3588LibFiles.Count) 文件..." -ForegroundColor DarkGray
    }
}
Write-Host "  ✅ RK3588 库已传输 ($count 个文件)" -ForegroundColor Green
Write-Host ""

# ============== 步骤 6: 传输 Qt6 库 ==============
Write-Host "[6/9] 传输 Qt6 库文件..." -ForegroundColor Yellow
$qtLibFiles = Get-ChildItem -Path $QtLibs -File | Where-Object {
    ($_.Extension -match "\.so" -or $_.Name -match "\.so\.") -and
    (-not $_.LinkType)
}

$count = 0
foreach ($lib in $qtLibFiles) {
    scp "$($lib.FullName)" "${TargetUser}@${TargetHost}:$RemoteBuildDir/libs/" 2>$null
    $count++
    if ($count % 50 -eq 0) {
        Write-Host "    已传输 $count/$($qtLibFiles.Count) 文件..." -ForegroundColor DarkGray
    }
}
Write-Host "  ✅ Qt6 库已传输 ($count 个文件)" -ForegroundColor Green
Write-Host ""

# ============== 步骤 7: 复制设备系统库 ==============
Write-Host "[7/9] 复制设备系统库..." -ForegroundColor Yellow
$copySystemLibs = @"
if [ -f /usr/lib/librknnrt.so ]; then
    cp /usr/lib/librknnrt.so* $RemoteBuildDir/libs/ 2>/dev/null || true
    echo 'librknnrt copied'
fi
"@
ssh ${TargetUser}@${TargetHost} $copySystemLibs 2>&1 | Out-Null
Write-Host "  ✅ 系统库已复制" -ForegroundColor Green
Write-Host ""

# ============== 步骤 8: 创建 Dockerfile ==============
Write-Host "[8/9] 创建 Dockerfile..." -ForegroundColor Yellow

$dockerfileContent = @"
# Runtime Dockerfile with system dependencies
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \\
    libpulse0 \\
    libgles2 \\
    libegl1 \\
    libfontconfig1 \\
    libglib2.0-0 \\
    libxkbcommon0 \\
    libpng16-16 \\
    libharfbuzz0b \\
    libfreetype6 \\
    libicu72 \\
    libpcre2-16-0 \\
    libbrotli1 \\
    libdbus-1-3 \\
    libx11-6 \\
    libx11-xcb1 \\
    libxcb1 \\
    && rm -rf /var/lib/apt/lists/*

# Set environment
ENV LD_LIBRARY_PATH=/opt/app/lib:/usr/local/lib:/usr/lib/aarch64-linux-gnu \\
    QT_QPA_PLATFORM=eglfs \\
    LANG=zh_CN.UTF-8

# Create app directories
RUN mkdir -p /opt/app/bin /opt/app/lib

# Copy application binary and libraries
COPY belt_control_system /opt/app/bin/
COPY libs/*.so* /opt/app/lib/

# Set permissions
RUN chmod +x /opt/app/bin/belt_control_system

WORKDIR /opt/app/bin
CMD ["/opt/app/bin/belt_control_system"]
"@

$dockerfileContent | ssh ${TargetUser}@${TargetHost} "cat > $RemoteBuildDir/Dockerfile"
Write-Host "  ✅ Dockerfile 已创建" -ForegroundColor Green
Write-Host ""

# ============== 步骤 9: 检查网络并处理基础镜像 ==============
Write-Host "[9/9] 检查网络连接..." -ForegroundColor Yellow
$networkTest = ssh ${TargetUser}@${TargetHost} "timeout 5 curl -s -o /dev/null -w '%{http_code}' https://registry-1.docker.io 2>&1 || echo 'timeout'"

if ($networkTest -eq "timeout" -or $networkTest -match "error") {
    Write-Host "  ⚠️ 设备无法访问 Docker Hub" -ForegroundColor Yellow

    if (Test-Path $DebianImageTar) {
        Write-Host "  正在传输 Debian 基础镜像..." -ForegroundColor Gray
        scp "$DebianImageTar" "${TargetUser}@${TargetHost}:/tmp/" 2>$null
        ssh ${TargetUser}@${TargetHost} "docker load -i /tmp/debian-bookworm-arm64.tar && docker tag arm64v8/debian:bookworm-slim debian:bookworm-slim"
        Write-Host "  ✅ 基础镜像已加载" -ForegroundColor Green
    } else {
        Write-Host "  ❌ 找不到离线镜像文件" -ForegroundColor Red
        Write-Host "  请先导出基础镜像:" -ForegroundColor Yellow
        Write-Host "    docker pull arm64v8/debian:bookworm-slim" -ForegroundColor White
        Write-Host "    docker save arm64v8/debian:bookworm-slim -o debian-bookworm-arm64.tar" -ForegroundColor White
        exit 1
    }
} else {
    Write-Host "  ✅ 网络连接正常,将从互联网下载依赖" -ForegroundColor Green
}
Write-Host ""

# ============== 汇总信息 ==============
Write-Host "========================================" -ForegroundColor Green
Write-Host "文件传输完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$totalLibs = ssh ${TargetUser}@${TargetHost} "ls $RemoteBuildDir/libs/ | wc -l"
Write-Host "传输总结:" -ForegroundColor Cyan
Write-Host "  • 二进制文件: 1 个" -ForegroundColor White
Write-Host "  • 依赖库: $totalLibs 个" -ForegroundColor White
Write-Host "  • Dockerfile: 已创建" -ForegroundColor White
Write-Host ""

# ============== 构建和运行 ==============
if ($AutoRun) {
    $buildChoice = 'y'
} else {
    $buildChoice = Read-Host "是否立即构建并运行 Docker 容器? (y/n)"
}

if ($buildChoice -eq 'y' -or $buildChoice -eq 'Y') {
    Write-Host ""
    Write-Host "正在构建 Docker 镜像..." -ForegroundColor Yellow
    Write-Host "(这可能需要 5-10 分钟,请耐心等待)" -ForegroundColor Gray
    Write-Host ""

    ssh ${TargetUser}@${TargetHost} "cd $RemoteBuildDir && docker build -t belt-control:latest ."

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "正在启动容器..." -ForegroundColor Yellow

        ssh ${TargetUser}@${TargetHost} @"
            docker stop belt_control 2>/dev/null || true
            docker rm belt_control 2>/dev/null || true
            docker run -d --name belt_control --privileged --network host --restart unless-stopped \
                -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 \
                belt-control:latest
"@

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "部署完成!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "容器状态:" -ForegroundColor Cyan
            ssh ${TargetUser}@${TargetHost} "docker ps | grep belt_control"
            Write-Host ""
            Write-Host "查看日志:" -ForegroundColor Cyan
            Write-Host "  ssh ${TargetUser}@${TargetHost} 'docker logs -f belt_control'" -ForegroundColor White
        } else {
            Write-Host "❌ 容器启动失败" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Docker 构建失败" -ForegroundColor Red
    }
} else {
    Write-Host ""
    Write-Host "手动构建命令:" -ForegroundColor Cyan
    Write-Host "  ssh ${TargetUser}@${TargetHost}" -ForegroundColor White
    Write-Host "  cd $RemoteBuildDir" -ForegroundColor White
    Write-Host "  docker build -t belt-control:latest ." -ForegroundColor White
    Write-Host "  docker run -d --name belt_control --privileged --network host belt-control:latest" -ForegroundColor White
    Write-Host ""
}
