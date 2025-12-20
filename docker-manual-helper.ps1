# Docker镜像手动下载助手
# 当Docker Desktop无法直接下载时使用此脚本

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("download", "import", "build", "all")]
    [string]$Action = "all"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Docker镜像手动下载和导入助手" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$ProjectRoot = "e:/2025/3_gongkongji/belt_control_system"
$ImagesDir = "$ProjectRoot/docker_images_manual"

# 创建镜像存放目录
if (-not (Test-Path $ImagesDir)) {
    New-Item -ItemType Directory -Path $ImagesDir | Out-Null
}

function Download-Image {
    Write-Host "`n请按以下步骤手动下载Docker镜像:" -ForegroundColor Yellow

    Write-Host @"

1. 使用浏览器或其他工具下载以下镜像:

   选项A: 从Docker Hub下载 (需要代理或VPN)
   ----------------------------------------
   URL: https://hub.docker.com/_/ubuntu/tags
   选择: ubuntu:24.04
   架构: linux/amd64

   选项B: 从国内镜像源下载
   ----------------------------------------
   阿里云: registry.cn-hangzhou.aliyuncs.com/library/ubuntu:24.04
   腾讯云: ccr.ccs.tencentyun.com/library/ubuntu:24.04
   华为云: swr.cn-north-4.myhuaweicloud.com/library/ubuntu:24.04

2. 下载方式:

   方式1: 使用其他机器拉取并导出
   ----------------------------------------
   # 在能访问的机器上执行:
   docker pull ubuntu:24.04
   docker save -o ubuntu-24.04.tar ubuntu:24.04
   # 然后将 ubuntu-24.04.tar 复制到本机

   方式2: 使用代理
   ----------------------------------------
   # 配置Docker代理 (如果有代理服务器)
   # 编辑 ~/.docker/config.json 添加:
   {
     "proxies": {
       "default": {
         "httpProxy": "http://proxy.example.com:8080",
         "httpsProxy": "http://proxy.example.com:8080"
       }
     }
   }

3. 将下载的文件放到以下目录:
   $ImagesDir\ubuntu-24.04.tar

"@ -ForegroundColor Gray

    Write-Host "等待文件..." -ForegroundColor Yellow
    $imagePath = "$ImagesDir\ubuntu-24.04.tar"

    # 等待用户放置文件
    while (-not (Test-Path $imagePath)) {
        Write-Host "请将 ubuntu-24.04.tar 文件放到: $ImagesDir" -ForegroundColor Cyan
        Write-Host "按任意键检查文件是否已放置..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }

    $fileSize = (Get-Item $imagePath).Length / 1MB
    Write-Host "[OK] 找到镜像文件 (Size: $([Math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
    return $imagePath
}

function Import-Image {
    param([string]$ImagePath)

    if (-not $ImagePath) {
        $ImagePath = "$ImagesDir\ubuntu-24.04.tar"
    }

    if (-not (Test-Path $ImagePath)) {
        Write-Host "[ERROR] 镜像文件不存在: $ImagePath" -ForegroundColor Red
        return $false
    }

    Write-Host "`n导入Docker镜像..." -ForegroundColor Yellow
    docker load -i $ImagePath

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] 镜像导入成功!" -ForegroundColor Green

        # 验证镜像
        Write-Host "`n验证镜像..." -ForegroundColor Yellow
        docker images ubuntu:24.04

        return $true
    } else {
        Write-Host "[ERROR] 镜像导入失败" -ForegroundColor Red
        return $false
    }
}

function Build-Application {
    Write-Host "`n构建应用程序..." -ForegroundColor Yellow

    # 创建简单的本地Dockerfile（不需要FROM ubuntu:24.04）
    $localDockerfile = @'
# 使用已导入的ubuntu:24.04镜像
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# 安装编译工具
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# 创建交叉编译脚本
RUN echo '#!/bin/bash' > /build.sh && \
    echo 'cd /workspace' >> /build.sh && \
    echo 'mkdir -p build && cd build' >> /build.sh && \
    echo 'cmake -G Ninja -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ -DCMAKE_BUILD_TYPE=Release ..' >> /build.sh && \
    echo 'ninja' >> /build.sh && \
    chmod +x /build.sh

CMD ["/build.sh"]
'@

    # 保存Dockerfile
    $dockerfilePath = "$ImagesDir\Dockerfile.local"
    $localDockerfile | Out-File -Encoding UTF8 $dockerfilePath

    # 构建镜像
    Write-Host "构建编译镜像..." -ForegroundColor Yellow
    docker build -f $dockerfilePath -t belt-control-build:local $ImagesDir

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] 编译镜像构建成功" -ForegroundColor Green

        # 运行编译
        Write-Host "`n运行编译..." -ForegroundColor Yellow

        # 使用已有的Qt和库
        docker run --rm `
            -v "${ProjectRoot}:/workspace" `
            -v "${ProjectRoot}/docker/rk3588/qt-host:/opt/qt-host:ro" `
            -v "${ProjectRoot}/docker/rk3588/qt-raspi:/opt/qt-raspi:ro" `
            -v "${ProjectRoot}/docker/rk3588/rk3588-libs:/opt/libs:ro" `
            -e QT_HOST_PATH=/opt/qt-host `
            -e QT_TARGET_PATH=/opt/qt-raspi `
            belt-control-build:local

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] 编译完成!" -ForegroundColor Green
        }
    }
}

# 主流程
switch ($Action) {
    "download" {
        Download-Image
    }
    "import" {
        Import-Image
    }
    "build" {
        if (Import-Image) {
            Build-Application
        }
    }
    "all" {
        $imagePath = Download-Image
        if (Import-Image -ImagePath $imagePath) {
            Build-Application
        }
    }
}

Write-Host "`n完成!" -ForegroundColor Green
Write-Host @"

下一步操作:
1. 如果导入成功，运行: docker images
2. 查看镜像是否存在: ubuntu:24.04
3. 运行构建: .\build-ubuntu24-clean.ps1

"@ -ForegroundColor Cyan