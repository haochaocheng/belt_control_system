# 清理和整理 docker/rk3588 目录
# 将过时和不推荐的文件移到 _archive_old_versions 目录

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ArchiveDir = "$ScriptDir\_archive_old_versions"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "清理和整理 RK3588 Docker 目录" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 创建归档目录
if (-not (Test-Path $ArchiveDir)) {
    New-Item -ItemType Directory -Path $ArchiveDir | Out-Null
    Write-Host "✅ 创建归档目录: _archive_old_versions" -ForegroundColor Green
}

# 需要归档的文件列表(过时的部署脚本和Dockerfile)
$FilesToArchive = @(
    # 旧的部署脚本
    "batch-deploy.ps1",
    "deploy-all.bat",
    "deploy-from-155-to-170.ps1",
    "deploy-on-device.ps1",
    "deploy-qt6-complete.ps1",
    "deploy-reliable.ps1",
    "deploy-simple.ps1",
    "deploy-ubuntu-final.ps1",
    "deploy-ubuntu-simple.ps1",
    "deploy-ubuntu.ps1",
    "deploy.sh",
    "deploy-to-rk3588.bat",
    "full-deploy.ps1",
    "simple-deploy.ps1",
    "test-deploy.bat",
    "quick-deploy-from-local-155.ps1",

    # 旧的构建脚本
    "build-all.ps1",
    "build-docker-image.ps1",
    "build-ffmpeg-sdl-fixed.sh",
    "build-ffmpeg.sh",
    "build-local.bat",
    "build-rk3588.bat",
    "build-runtime.bat",
    "install-and-deploy.bat",
    "prepare-docker-build.ps1",
    "prepare-runtime.sh",

    # 旧的Dockerfile (不是基础镜像的)
    "Dockerfile.complete",
    "Dockerfile.device",
    "Dockerfile.minimal",
    "Dockerfile.runtime",
    "Dockerfile.runtime.simple",
    "Dockerfile.simple",

    # 旧的依赖构建脚本
    "build-dependencies-local.sh",
    "build-dependencies.bat",
    "build-dependencies.sh",
    "copy-missing-libs.sh",
    "copy-system-libs.ps1",
    "create-symlinks.sh",
    "fix-lib-symlinks.sh",
    "install-egl-headers.sh",
    "transfer-qt-libs.ps1",
    "transfer-system-libs.ps1",

    # 旧的文档(已有新版本)
    "README-һ������.md",
    "README_DEPLOY.md",
    "һ��������.md",
    "һ������-������.ps1",
    "һ������.bat",
    "Ա�������ֲ�.md",
    "���ٿ�ʼ.md",
    "��������ָ��.md",
    "DOCKER���ս������.md",
    "DOCKER����GLIBC�������.md",
    "DOCKER����������������.md",
    "DOCKER_REGISTRY_FIX.md",

    # 其他工具脚本
    "docker-compose.yml",
    "fix-docker-registry.ps1",
    "fix-glibc-compat.h",
    "glibc-compat.lds",
    "install-docker.sh",
    "run-without-docker.sh",
    "setup-ssh-key.bat",
    "setup-ssh-key.ps1",
    "setup-ubuntu-ssh.ps1",
    "verify-setup.bat",
    "view-logs.bat",
    "view-status.bat",

    # 旧的tar包(太大了)
    "base-v1.1.tar",
    "belt-control-v2.tar",
    "debian-bookworm-arm64.tar"
)

Write-Host "开始归档过时文件..." -ForegroundColor Yellow
Write-Host ""

$movedCount = 0
foreach ($file in $FilesToArchive) {
    $sourcePath = Join-Path $ScriptDir $file
    if (Test-Path $sourcePath) {
        $destPath = Join-Path $ArchiveDir $file
        Move-Item -Path $sourcePath -Destination $destPath -Force
        Write-Host "  ✓ 已归档: $file" -ForegroundColor Gray
        $movedCount++
    }
}

Write-Host ""
Write-Host "✅ 归档完成! 共移动 $movedCount 个文件" -ForegroundColor Green
Write-Host ""

# 显示当前目录下的主要文件
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "当前可用的文件 (推荐使用)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "【交叉编译环境】" -ForegroundColor Yellow
Write-Host "  Dockerfile                  - 交叉编译环境镜像(Ubuntu 22.04 + Qt6)" -ForegroundColor White
Write-Host "  entrypoint.sh               - Docker入口脚本" -ForegroundColor White
Write-Host "  toolchain-rk3588.cmake      - CMake交叉编译工具链配置" -ForegroundColor White
Write-Host ""

Write-Host "【基础运行时镜像 - 设备上使用】" -ForegroundColor Yellow
Write-Host "  Dockerfile.base-trixie-noglib  - Debian Trixie基础(推荐,解决GLib)" -ForegroundColor White
Write-Host "  Dockerfile.base-ubuntu20       - Ubuntu 20.04基础" -ForegroundColor White
Write-Host "  Dockerfile.base-debian11       - Debian 11基础" -ForegroundColor White
Write-Host "  Dockerfile.base-prebuilt       - 预构建基础镜像" -ForegroundColor White
Write-Host ""

Write-Host "【部署脚本 - Windows使用】" -ForegroundColor Yellow
Write-Host "  deploy-local-to-155.ps1     - 部署到155设备(最新)" -ForegroundColor White
Write-Host "  quick-deploy-from-local.ps1 - 快速部署脚本" -ForegroundColor White
Write-Host ""

Write-Host "【V3.3新脚本 - 带旋转修复】" -ForegroundColor Yellow
Write-Host "  build_and_deploy_v3.3.ps1   - 完整构建+部署v3.3" -ForegroundColor White
Write-Host "  build_on_device_v3.3.sh     - 设备本地编译v3.3" -ForegroundColor White
Write-Host ""

Write-Host "【预编译资源】" -ForegroundColor Yellow
Write-Host "  qt-raspi/ 目录              - Qt6 ARM64交叉编译版本" -ForegroundColor White
Write-Host "  qt-host/ 目录               - Qt6 主机工具" -ForegroundColor White
Write-Host "  sysroot/ 目录               - RK3588 sysroot" -ForegroundColor White
Write-Host "  rk3588-libs/ 目录           - RK3588系统库" -ForegroundColor White
Write-Host ""

Write-Host "【文档】" -ForegroundColor Yellow
Write-Host "  DOCKER_DEPLOYMENT_GUIDE.md  - Docker部署指南" -ForegroundColor White
Write-Host "  DOCKER_DEPLOYMENT_STATUS.md - 部署状态说明" -ForegroundColor White
Write-Host "  DEPENDENCIES.md             - 依赖说明" -ForegroundColor White
Write-Host "  VERSION_INFO.md             - 版本信息" -ForegroundColor White
Write-Host ""

Write-Host "归档的文件在: _archive_old_versions/" -ForegroundColor Gray
Write-Host ""
