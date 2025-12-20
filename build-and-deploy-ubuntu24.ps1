# Ubuntu 24.04 完整构建和部署脚本
# 从编译到部署的一站式解决方案

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("build", "deploy", "all")]
    [string]$Mode = "all",

    [Parameter(Mandatory=$false)]
    [string]$TargetDevice = "192.168.10.188",

    [switch]$SkipBuild = $false,
    [switch]$SkipDeploy = $false,
    [switch]$Interactive = $false
)

$ErrorActionPreference = "Stop"
$script:StartTime = Get-Date

# 配置
$ProjectRoot = "e:/2025/3_gongkongji/belt_control_system"
$DockerDir = "$ProjectRoot/docker/ubuntu24-fresh"
$BuildOutputDir = "$ProjectRoot/build_ubuntu24_output"
$BuildImageName = "belt-control-build:ubuntu24"
$RuntimeImageName = "belt-control-runtime:ubuntu24"
$ContainerName = "belt-control-app"

function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "`n========================================" -ForegroundColor $Color
    Write-Host $Message -ForegroundColor $Color
    Write-Host "========================================" -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# ========== 构建阶段 ==========
function Build-Application {
    Write-Step "[1/4] 构建Docker编译环境" "Yellow"

    # 构建编译镜像
    Write-Host "构建编译镜像: $BuildImageName"
    docker build -f "$DockerDir/Dockerfile.build" -t $BuildImageName $DockerDir

    if ($LASTEXITCODE -ne 0) {
        Write-Error "编译镜像构建失败"
        exit 1
    }
    Write-Success "编译镜像构建成功"

    Write-Step "[2/4] 编译应用程序" "Yellow"

    # 准备输出目录
    if (Test-Path $BuildOutputDir) {
        Remove-Item -Recurse -Force $BuildOutputDir
    }
    New-Item -ItemType Directory -Path $BuildOutputDir -Force | Out-Null

    # 运行编译
    if ($Interactive) {
        Write-Host "进入交互式编译环境..."
        docker run -it --rm `
            -v "${ProjectRoot}:/workspace" `
            -v "${BuildOutputDir}:/output" `
            $BuildImageName `
            /bin/bash
    } else {
        Write-Host "开始自动编译..."
        docker run --rm `
            -v "${ProjectRoot}:/workspace" `
            -v "${BuildOutputDir}:/output" `
            $BuildImageName
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "编译失败"
        exit 1
    }

    # 验证输出
    if (Test-Path "$BuildOutputDir/belt_control_system") {
        $fileInfo = Get-Item "$BuildOutputDir/belt_control_system"
        Write-Success "编译成功: belt_control_system ($('{0:N2}' -f ($fileInfo.Length/1MB)) MB)"
    } else {
        Write-Error "未找到编译输出文件"
        exit 1
    }
}

# ========== 打包阶段 ==========
function Package-Runtime {
    Write-Step "[3/4] 构建运行时Docker镜像" "Yellow"

    # 创建临时构建上下文
    $tempContext = "$ProjectRoot/docker_build_context_temp"
    if (Test-Path $tempContext) {
        Remove-Item -Recurse -Force $tempContext
    }
    New-Item -ItemType Directory -Path $tempContext -Force | Out-Null

    try {
        # 复制必要文件到构建上下文
        Copy-Item "$DockerDir/Dockerfile.runtime" "$tempContext/Dockerfile"
        Copy-Item "$BuildOutputDir/belt_control_system" "$tempContext/" -ErrorAction SilentlyContinue

        # 复制配置和资源
        if (Test-Path "$ProjectRoot/config") {
            Copy-Item -Recurse "$ProjectRoot/config" "$tempContext/"
        }
        if (Test-Path "$ProjectRoot/libs/tts_models") {
            New-Item -ItemType Directory -Path "$tempContext/libs" -Force | Out-Null
            Copy-Item -Recurse "$ProjectRoot/libs/tts_models" "$tempContext/libs/"
        }

        # 构建运行时镜像
        Write-Host "构建运行时镜像: $RuntimeImageName"
        docker build -t $RuntimeImageName $tempContext

        if ($LASTEXITCODE -ne 0) {
            Write-Error "运行时镜像构建失败"
            exit 1
        }
        Write-Success "运行时镜像构建成功"

        # 显示镜像信息
        $imageInfo = docker images $RuntimeImageName --format "Size: {{.Size}}"
        Write-Host "镜像信息: $imageInfo" -ForegroundColor Gray
    }
    finally {
        # 清理临时目录
        if (Test-Path $tempContext) {
            Remove-Item -Recurse -Force $tempContext
        }
    }
}

# ========== 部署阶段 ==========
function Deploy-ToDevice {
    Write-Step "[4/4] 部署到目标设备 ($TargetDevice)" "Yellow"

    # 检查目标设备连接
    Write-Host "检查设备连接..."
    $testConnection = Test-NetConnection -ComputerName $TargetDevice -Port 22 -InformationLevel Quiet

    if (-not $testConnection) {
        Write-Error "无法连接到设备 $TargetDevice:22"
        exit 1
    }
    Write-Success "设备连接正常"

    # 导出Docker镜像
    Write-Host "导出Docker镜像..."
    $exportFile = "$ProjectRoot/belt-control-runtime-ubuntu24.tar"
    docker save -o $exportFile $RuntimeImageName

    if ($LASTEXITCODE -ne 0) {
        Write-Error "镜像导出失败"
        exit 1
    }

    $fileSize = (Get-Item $exportFile).Length / 1MB
    Write-Success "镜像导出成功 ($('{0:N2}' -f $fileSize) MB)"

    # 传输到目标设备
    Write-Host "传输镜像到设备..."
    scp $exportFile "pi@${TargetDevice}:/tmp/"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "镜像传输失败"
        Remove-Item $exportFile
        exit 1
    }
    Write-Success "镜像传输成功"

    # 在目标设备上加载并运行
    Write-Host "在目标设备上部署..."

    $deployScript = @"
#!/bin/bash
echo '加载Docker镜像...'
sudo docker load -i /tmp/belt-control-runtime-ubuntu24.tar

echo '停止旧容器（如果存在）...'
sudo docker stop $ContainerName 2>/dev/null || true
sudo docker rm $ContainerName 2>/dev/null || true

echo '启动新容器...'
sudo docker run -d \
    --name $ContainerName \
    --restart unless-stopped \
    --privileged \
    -v /dev:/dev \
    -v /sys:/sys \
    -e QT_QPA_PLATFORM=eglfs \
    -e SCREEN_WIDTH=1920 \
    -e SCREEN_HEIGHT=1080 \
    $RuntimeImageName

echo '清理临时文件...'
rm -f /tmp/belt-control-runtime-ubuntu24.tar

echo '检查容器状态...'
sudo docker ps | grep $ContainerName

echo '部署完成！'
"@

    $deployScript | ssh "pi@${TargetDevice}" "bash -s"

    if ($LASTEXITCODE -eq 0) {
        Write-Success "部署成功完成！"

        # 清理本地导出文件
        Remove-Item $exportFile -ErrorAction SilentlyContinue

        # 显示访问信息
        Write-Host "`n访问信息:" -ForegroundColor Cyan
        Write-Host "  设备地址: $TargetDevice" -ForegroundColor Gray
        Write-Host "  容器名称: $ContainerName" -ForegroundColor Gray
        Write-Host "  查看日志: ssh pi@$TargetDevice 'sudo docker logs -f $ContainerName'" -ForegroundColor Gray
        Write-Host "  进入容器: ssh pi@$TargetDevice 'sudo docker exec -it $ContainerName /bin/bash'" -ForegroundColor Gray
    } else {
        Write-Error "部署失败"
        Remove-Item $exportFile -ErrorAction SilentlyContinue
        exit 1
    }
}

# ========== 主流程 ==========
Write-Step "Ubuntu 24.04 构建和部署系统" "Cyan"
Write-Host "模式: $Mode" -ForegroundColor Gray
Write-Host "目标设备: $TargetDevice" -ForegroundColor Gray

try {
    switch ($Mode) {
        "build" {
            Build-Application
            Package-Runtime
        }
        "deploy" {
            if (-not (docker images -q $RuntimeImageName)) {
                Write-Error "未找到运行时镜像，请先执行构建"
                exit 1
            }
            Deploy-ToDevice
        }
        "all" {
            if (-not $SkipBuild) {
                Build-Application
                Package-Runtime
            }
            if (-not $SkipDeploy) {
                Deploy-ToDevice
            }
        }
    }

    $duration = (Get-Date) - $script:StartTime
    Write-Step "✓ 所有操作完成！" "Green"
    Write-Host "总用时: $('{0:N2}' -f $duration.TotalMinutes) 分钟" -ForegroundColor Cyan
}
catch {
    Write-Error "发生错误: $_"
    exit 1
}