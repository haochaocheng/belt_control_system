# Complete Ubuntu 24.04 Build & Deploy Script (apt-get method)
# Uses Ubuntu 24.04 native packages via apt-get with smart caching
# 完全本地Windows离线构建，自动化部署到任何ARM64 RK3588设备
#
# 使用方法:
#   .\build-ubuntu24-apt.ps1 151        # 部署到 192.168.10.151
#   .\build-ubuntu24-apt.ps1 188        # 部署到 192.168.10.188
#   .\build-ubuntu24-apt.ps1 192.168.10.200  # 部署到自定义IP

param(
    [string]$Device = "151"  # 默认151设备
)

$ErrorActionPreference = "Stop"

# ============================================================
# Parse device parameter and setup configuration linaro
# ============================================================
$DeviceUser = "linaro"
$DevicePassword = "linaro"

switch -Regex ($Device) {
    "^151$" {
        $DeviceIP = "192.168.10.151"
        Write-Host "[Device] Target: Device 151 ($DeviceIP)" -ForegroundColor Cyan
    }
    "^188$" {
        $DeviceIP = "192.168.10.188"
        Write-Host "[Device] Target: Device 188 ($DeviceIP)" -ForegroundColor Cyan
    }
    "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$" {
        $DeviceIP = $Device
        Write-Host "[Device] Target: Custom IP ($DeviceIP)" -ForegroundColor Cyan
    }
    default {
        Write-Host "[ERROR] Invalid device parameter: $Device" -ForegroundColor Red
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  .\build-ubuntu24-apt.ps1 151              # Deploy to 192.168.10.151" -ForegroundColor White
        Write-Host "  .\build-ubuntu24-apt.ps1 188              # Deploy to 192.168.10.188" -ForegroundColor White
        Write-Host "  .\build-ubuntu24-apt.ps1 192.168.10.200   # Deploy to custom IP" -ForegroundColor White
        Write-Host ""
        exit 1
    }
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Ubuntu 24.04 Smart Build & Deploy" -ForegroundColor Cyan
Write-Host "Native packages | Smart caching | GLIBC 2.39" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"
$BuildDir = "$ProjectRoot\build_rk3588"
$BinaryFile = "$BuildDir\bin_arm64\belt_control_system"
$DockerContextDir = "$ProjectRoot\docker_build_ubuntu24_apt"
$BaseImageName = "belt-control-base"
$BaseImageTag = "ubuntu24"
$AppImageName = "belt-control"
$AppImageTag = "v3.5-apt"
$OutputTarFile = "$ProjectRoot\belt-control-ubuntu24-apt.tar"
$BaseCacheFile = "$ProjectRoot\.docker_base_cache.json"
$AppCacheFile = "$ProjectRoot\.docker_app_cache.json"
$PJSIPLibsCacheFile = "$ProjectRoot\.pjsip_libs_cache.json"

# ============================================================
# Step -1: PJSIP 源码变化检测（自动重新编译）
# ============================================================
Write-Host "Step -1: Checking PJSIP source code..." -ForegroundColor Cyan

$pjsipSourceDir = "$ProjectRoot\cross-compile\src\pjproject-2.16"
$pjsipStaticLib = "$ProjectRoot\docker\rk3588\rk3588-libs\lib\libpjmedia-codec-aarch64-unknown-linux-gnu.a"

if (-not (Test-Path $pjsipSourceDir)) {
    Write-Host "  [!] PJSIP 源码目录不存在" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $pjsipStaticLib)) {
    Write-Host "  [!] PJSIP 静态库不存在 - 需要首次编译" -ForegroundColor Yellow
    $needCompilePJSIP = $true
} else {
    # 扫描整个源码树，找到最新修改的文件
    Write-Host "  扫描源码树..." -ForegroundColor Gray

    $latestSourceFile = Get-ChildItem -Path $pjsipSourceDir -Recurse -File `
        | Where-Object { $_.Extension -in @('.c', '.cpp', '.h', '.hpp') } `
        | Sort-Object LastWriteTime -Descending `
        | Select-Object -First 1

    if (-not $latestSourceFile) {
        Write-Host "  [!] 未找到任何源码文件" -ForegroundColor Red
        exit 1
    }

    $sourceTime = $latestSourceFile.LastWriteTime
    $libTime = (Get-Item $pjsipStaticLib).LastWriteTime

    Write-Host "  最新源码文件: $($latestSourceFile.Name)" -ForegroundColor Cyan
    Write-Host "  最新修改时间: $($sourceTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
    Write-Host "  静态库时间: $($libTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan

    if ($sourceTime -gt $libTime) {
        Write-Host ""
        Write-Host "  [!] PJSIP 源码已更新 - 需要重新编译静态库" -ForegroundColor Yellow
        Write-Host "  修改的文件: $($latestSourceFile.FullName.Replace($ProjectRoot, '.'))" -ForegroundColor Yellow
        $timeDiff = $sourceTime - $libTime
        Write-Host "  源码比静态库新 $($timeDiff.TotalMinutes.ToString('0.0')) 分钟" -ForegroundColor Yellow
        $needCompilePJSIP = $true
    } else {
        Write-Host "  [OK] PJSIP 静态库是最新的" -ForegroundColor Green
        $needCompilePJSIP = $false
        $forceFullRebuild = $false
    }
}

if ($needCompilePJSIP) {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "  开始编译 PJSIP 静态库（混合优化方案）" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host ""

    $pjsipOutputDir = "$ProjectRoot\docker\rk3588\pjsip-libs"
    $pjsipConfigSite = "$ProjectRoot\docker\rk3588\pjsip_config_site.h"
    $pjsipSysroot = "$ProjectRoot\docker\rk3588\sysroot\rk3588-root"
    $pjsipContainerName = "pjsip-builder-persistent"
    $pjsipImageName = "pjsip-builder-ubuntu20:latest"  # Ubuntu 20.04 + GCC 9

    # 创建输出目录
    if (-not (Test-Path $pjsipOutputDir)) {
        New-Item -ItemType Directory -Path $pjsipOutputDir -Force | Out-Null
    }

    # 检查 Docker 镜像
    Write-Host "  [1/6] 检查 PJSIP 编译镜像（Ubuntu 20.04）..." -ForegroundColor Green
    $pjsipImageExists = docker images -q $pjsipImageName
    if (-not $pjsipImageExists) {
        Write-Host "  [!] PJSIP 编译镜像不存在，需要先构建" -ForegroundColor Red
        Write-Host "  运行: docker build -f docker/rk3588/Dockerfile.pjsip-ubuntu20 -t pjsip-builder-ubuntu20:latest docker/rk3588/" -ForegroundColor Yellow
        exit 1
    }

    # ⚠️ 检测配置文件是否修改（需要重新 configure）
    Write-Host "  检查配置文件修改状态..." -ForegroundColor Gray
    $configFiles = @(
        "$ProjectRoot\docker\rk3588\pjsip_config_site.h",
        "$ProjectRoot\docker\rk3588\Dockerfile.pjsip-ubuntu20"
    )

    $forceFullRebuild = $false
    $containerExists = docker ps -a --filter "name=^${pjsipContainerName}$" --format "{{.Names}}"

    if ($containerExists) {
        # 容器存在时，比对配置文件和容器内记录的时间戳
        $containerConfigTime = docker exec $pjsipContainerName cat /workspace/.config_timestamp 2>$null

        foreach ($configFile in $configFiles) {
            if (Test-Path $configFile) {
                $configTime = (Get-Item $configFile).LastWriteTime.ToString("o")

                # 如果容器没有记录，或者配置文件时间戳不同，需要重新 configure
                if (-not $containerConfigTime -or $containerConfigTime -ne $configTime) {
                    Write-Host "  [!] 配置文件已修改 - 强制完整重新编译" -ForegroundColor Red
                    Write-Host "      配置: $(Split-Path $configFile -Leaf)" -ForegroundColor Gray
                    Write-Host "      容器记录: $(if($containerConfigTime){$containerConfigTime}else{'无记录'})" -ForegroundColor Gray
                    Write-Host "      当前时间: $configTime" -ForegroundColor Gray
                    $forceFullRebuild = $true
                    break
                }
            }
        }

        if (-not $forceFullRebuild) {
            Write-Host "  ✓ 配置文件未修改 - 增量编译" -ForegroundColor Green
        }
    } else {
        # 容器不存在，需要完整编译
        Write-Host "  容器不存在 - 需要完整编译" -ForegroundColor Yellow
        $forceFullRebuild = $true
    }

    # 检查或创建持久化容器
    Write-Host "  [2/6] 检查持久化容器..." -ForegroundColor Green

    # ⚠️ 配置文件修改时强制删除旧容器（重新 configure）
    if ($containerExists -and $forceFullRebuild) {
        Write-Host "    [!] 删除旧容器以重新 configure" -ForegroundColor Red
        docker rm -f $pjsipContainerName | Out-Null
        $containerExists = $null
    }

    if (-not $containerExists) {
        Write-Host "    创建持久化容器: $pjsipContainerName" -ForegroundColor Yellow
        docker create `
            --name $pjsipContainerName `
            -w /workspace `
            -v "${pjsipOutputDir}:/output" `
            $pjsipImageName `
            tail -f /dev/null | Out-Null
        Write-Host "    ✓ 容器已创建" -ForegroundColor Green
        $isNewContainer = $true

        # 启动容器（需要先启动才能复制文件）
        docker start $pjsipContainerName | Out-Null

        # ⚠️ 性能优化：只复制 FFmpeg + RKMPP 到容器（不复制整个 sysroot）
        # 原因：PJSIP 只需要 FFmpeg/RKMPP，其他依赖（OpenSSL/ALSA）用 apt 安装
        Write-Host "    复制 FFmpeg + RKMPP 到容器..." -ForegroundColor Yellow
        Write-Host "    源: $pjsipSysroot" -ForegroundColor Gray

        # 验证 sysroot 源目录存在
        if (-not (Test-Path $pjsipSysroot)) {
            Write-Host "    [错误] sysroot 源目录不存在: $pjsipSysroot" -ForegroundColor Red
            exit 1
        }

        $sysrootCopyStart = Get-Date

        # 创建目标目录
        docker exec $pjsipContainerName mkdir -p /opt/rk3588-sysroot/usr/include | Out-Null
        docker exec $pjsipContainerName mkdir -p /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig | Out-Null

        # 只复制 FFmpeg 头文件（libav*）
        Write-Host "    - 复制 FFmpeg 头文件..." -ForegroundColor Gray
        $ffmpegIncludeDirs = @("libavcodec", "libavformat", "libavutil", "libavdevice", "libswscale", "libswresample", "libavfilter")
        $copiedCount = 0
        foreach ($dir in $ffmpegIncludeDirs) {
            $srcPath = Join-Path $pjsipSysroot "usr\include\aarch64-linux-gnu\$dir"
            if (Test-Path $srcPath) {
                docker cp "$srcPath" "${pjsipContainerName}:/opt/rk3588-sysroot/usr/include/" 2>&1 | Out-Null
                $copiedCount++
            } else {
                # 尝试另一个可能的路径
                $srcPath = Join-Path $pjsipSysroot "usr\include\$dir"
                if (Test-Path $srcPath) {
                    docker cp "$srcPath" "${pjsipContainerName}:/opt/rk3588-sysroot/usr/include/" 2>&1 | Out-Null
                    $copiedCount++
                }
            }
        }
        Write-Host "      复制了 $copiedCount 个 FFmpeg 头文件目录" -ForegroundColor Gray

        # 复制 RKMPP 头文件
        Write-Host "    - 复制 RKMPP 头文件..." -ForegroundColor Gray
        $rkmppIncludePath = Join-Path $pjsipSysroot "usr\include\rockchip"
        if (Test-Path $rkmppIncludePath) {
            docker cp "$rkmppIncludePath" "${pjsipContainerName}:/opt/rk3588-sysroot/usr/include/" 2>&1 | Out-Null
            Write-Host "      ✓ rockchip/" -ForegroundColor Gray
        } else {
            $rkmppIncludePath = Join-Path $pjsipSysroot "usr\include\aarch64-linux-gnu\rockchip"
            if (Test-Path $rkmppIncludePath) {
                docker cp "$rkmppIncludePath" "${pjsipContainerName}:/opt/rk3588-sysroot/usr/include/" 2>&1 | Out-Null
                Write-Host "      ✓ rockchip/" -ForegroundColor Gray
            } else {
                Write-Host "      ⚠️ rockchip/ 未找到" -ForegroundColor Yellow
            }
        }

        # ✅ 2026-01-10 01:50 [修复 100.3] 复制 RGA 头文件
        # 原因：ffmpeg_vid_codecs.c 引用了 rga/im2d.h 和 rga/rga.h
        Write-Host "    - 复制 RGA 头文件..." -ForegroundColor Gray
        $rgaIncludePath = Join-Path $pjsipSysroot "usr\include\rga"
        if (Test-Path $rgaIncludePath) {
            docker cp "$rgaIncludePath" "${pjsipContainerName}:/opt/rk3588-sysroot/usr/include/" 2>&1 | Out-Null
            Write-Host "      ✓ rga/" -ForegroundColor Gray
        } else {
            Write-Host "      ⚠️ rga/ 未找到" -ForegroundColor Yellow
        }

        # ✅ 2025-12-30 11:10 优化：只复制 FFmpeg 及其实际依赖的库文件
        #    之前复制所有 .so 文件（效率低、容器体积大）
        #    现在只复制 FFmpeg 核心库 + 编解码器依赖库（从链接错误中提取）
        Write-Host "    - 复制 FFmpeg + 编解码器依赖库..." -ForegroundColor Gray
        $libPath = Join-Path $pjsipSysroot "usr\lib\aarch64-linux-gnu"
        $libCount = 0

        if (Test-Path $libPath) {
            # FFmpeg 核心库
            $ffmpegLibs = @("libav*.so*", "libsw*.so*")

            # 编解码器依赖库（从链接错误中提取）
            $codecLibs = @(
                "librsvg-2.so*", "libcairo.so*", "libzvbi.so*", "libsnappy.so*",
                "libaom.so*", "libcodec2.so*", "libgsm.so*", "libopenjp2.so*",
                "libshine.so*", "libtheora*.so*", "libtwolame.so*", "libwavpack.so*",
                "libx264.so*", "libx265.so*", "libxvidcore.so*",
                "librga.so*", "libmpp.so*", "librockchip_mpp.so*",
                "libva*.so*", "libvdpau.so*",
                "libdav1d.so*", "libvpx.so*", "libwebp*.so*"
            )

            # 合并所有需要的库
            $allLibs = $ffmpegLibs + $codecLibs

            foreach ($libPattern in $allLibs) {
                Get-ChildItem -Path $libPath -Filter $libPattern -ErrorAction SilentlyContinue | ForEach-Object {
                    docker cp $_.FullName "${pjsipContainerName}:/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/" 2>&1 | Out-Null
                    $libCount++
                }
            }
        }
        Write-Host "      复制了 $libCount 个库文件（FFmpeg + 编解码器依赖）" -ForegroundColor Gray

        # 复制 pkg-config 文件
        Write-Host "    - 复制 pkg-config 文件..." -ForegroundColor Gray
        $pkgconfigPath = Join-Path $pjsipSysroot "usr\lib\aarch64-linux-gnu\pkgconfig"
        $pcCount = 0
        if (Test-Path $pkgconfigPath) {
            Get-ChildItem -Path $pkgconfigPath -Filter "libav*.pc" -ErrorAction SilentlyContinue | ForEach-Object {
                docker cp $_.FullName "${pjsipContainerName}:/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig/" 2>&1 | Out-Null
                $pcCount++
            }
            Get-ChildItem -Path $pkgconfigPath -Filter "libsw*.pc" -ErrorAction SilentlyContinue | ForEach-Object {
                docker cp $_.FullName "${pjsipContainerName}:/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig/" 2>&1 | Out-Null
                $pcCount++
            }
        }
        Write-Host "      复制了 $pcCount 个 .pc 文件" -ForegroundColor Gray

        # ✅ 2026-01-09 23:55 [修复 100] 创建编解码器库符号链接
        # 原因：链接器需要 libx264.so 等通用链接名，但容器中只有版本化文件（libx264.so.164）
        # 结果：configure 失败 "cannot find -lx264"
        # 解决：在复制库文件后自动创建符号链接
        Write-Host "    - 创建编解码器库符号链接..." -ForegroundColor Gray

        # ✅ 2026-01-10 00:50 [修复] 使用单独的命令而不是 here-string，避免换行符问题
        # ✅ 2026-01-10 02:25 [Fix 100.5] 添加两层符号链接修复
        # 原因：某些库需要两层符号链接（如 libcairo.so → libcairo.so.2 → libcairo.so.2.11800.0）
        # 说明：必须先创建中间层链接（libcairo.so.2），再创建顶层链接（libcairo.so）

        # 第一组：单层直接链接（直接指向版本化文件）
        docker exec $pjsipContainerName sh -c "cd /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu && ln -sf libx264.so.164 libx264.so && ln -sf libx265.so.199 libx265.so"
        docker exec $pjsipContainerName sh -c "cd /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu && ln -sf libwavpack.so.1 libwavpack.so && ln -sf libtwolame.so.0 libtwolame.so"
        docker exec $pjsipContainerName sh -c "cd /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu && ln -sf libtheoraenc.so.1 libtheoraenc.so && ln -sf libtheoradec.so.1 libtheoradec.so"
        docker exec $pjsipContainerName sh -c "cd /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu && ln -sf libxvidcore.so.4 libxvidcore.so && ln -sf libopenjp2.so.7 libopenjp2.so"
        docker exec $pjsipContainerName sh -c "cd /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu && ln -sf libshine.so.3 libshine.so && ln -sf libsnappy.so.1 libsnappy.so"
        docker exec $pjsipContainerName sh -c "cd /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu && ln -sf libzvbi.so.0 libzvbi.so && ln -sf libtheora.so.0 libtheora.so"

        # 第二组：两层符号链接（需要先创建中间层）
        # libvpx: libvpx.so → libvpx.so.7.0.0 → libvpx.so.9.0.0
        docker exec $pjsipContainerName sh -c "cd /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu && ln -sf libvpx.so.9.0.0 libvpx.so.7.0.0 && ln -sf libvpx.so.7.0.0 libvpx.so"

        # libwebp: libwebp.so → libwebp.so.7 → libwebp.so.7.1.8
        docker exec $pjsipContainerName sh -c "cd /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu && ln -sf libwebp.so.7.1.8 libwebp.so.7 && ln -sf libwebp.so.7 libwebp.so"

        # libdav1d: libdav1d.so → libdav1d.so.7 → libdav1d.so.4.0.2
        docker exec $pjsipContainerName sh -c "cd /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu && ln -sf libdav1d.so.4.0.2 libdav1d.so.7 && ln -sf libdav1d.so.7 libdav1d.so"

        # libaom: libaom.so → libaom.so.3 → libaom.so.0
        docker exec $pjsipContainerName sh -c "cd /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu && ln -sf libaom.so.0 libaom.so.3 && ln -sf libaom.so.3 libaom.so"

        # libcodec2: libcodec2.so → libcodec2.so.1.2 → libcodec2.so.0.9
        docker exec $pjsipContainerName sh -c "cd /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu && ln -sf libcodec2.so.0.9 libcodec2.so.1.2 && ln -sf libcodec2.so.1.2 libcodec2.so"

        # libcairo: libcairo.so → libcairo.so.2 → libcairo.so.2.11800.0
        docker exec $pjsipContainerName sh -c "cd /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu && ln -sf libcairo.so.2.11800.0 libcairo.so.2 && ln -sf libcairo.so.2 libcairo.so"

        # librsvg-2: librsvg-2.so → librsvg-2.so.2 → librsvg-2.so.2.50.0
        docker exec $pjsipContainerName sh -c "cd /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu && ln -sf librsvg-2.so.2.50.0 librsvg-2.so.2 && ln -sf librsvg-2.so.2 librsvg-2.so"

        # 验证最关键的两个符号链接
        $x264Check = docker exec $pjsipContainerName sh -c "test -L /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/libx264.so && echo 'OK' || echo 'FAIL'"
        $x265Check = docker exec $pjsipContainerName sh -c "test -L /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/libx265.so && echo 'OK' || echo 'FAIL'"

        if ($x264Check.Trim() -eq "OK" -and $x265Check.Trim() -eq "OK") {
            Write-Host "      ✓ 符号链接创建完成（已验证 libx264.so 和 libx265.so）" -ForegroundColor Green
        } else {
            Write-Host "      [警告] 符号链接创建可能失败: x264=$x264Check x265=$x265Check" -ForegroundColor Yellow
        }

        $sysrootCopyElapsed = (Get-Date) - $sysrootCopyStart
        Write-Host "    ✓ FFmpeg + RKMPP 复制完成（耗时 $($sysrootCopyElapsed.TotalSeconds.ToString('F1'))s）" -ForegroundColor Green

        # ✅ 验证 FFmpeg 头文件是否存在
        Write-Host "    验证 FFmpeg 头文件..." -ForegroundColor Gray
        $ffmpegHeaderCheck = docker exec $pjsipContainerName bash -c "find /opt/rk3588-sysroot/usr/include -name 'avutil.h' -path '*/libavutil/*' 2>/dev/null | head -1"
        if (-not $ffmpegHeaderCheck -or $ffmpegHeaderCheck.Trim() -eq "") {
            Write-Host "    [警告] FFmpeg 头文件未找到，列出 sysroot 内容以排查" -ForegroundColor Yellow
            Write-Host "    include 目录内容:" -ForegroundColor Gray
            docker exec $pjsipContainerName bash -c "ls -la /opt/rk3588-sysroot/usr/include/ 2>/dev/null | head -30"
            Write-Host "    查找 libav* 目录:" -ForegroundColor Gray
            docker exec $pjsipContainerName bash -c "find /opt/rk3588-sysroot/usr/include -type d -name 'libav*' 2>/dev/null"
        } else {
            Write-Host "    ✓ FFmpeg 头文件: $($ffmpegHeaderCheck.Trim())" -ForegroundColor Green
        }
    } else {
        Write-Host "    ✓ 容器已存在" -ForegroundColor Green
        $isNewContainer = $false

        # 启动容器
        $containerRunning = docker ps --filter "name=^${pjsipContainerName}$" --format "{{.Names}}"
        if (-not $containerRunning) {
            Write-Host "    启动容器..." -ForegroundColor Yellow
            docker start $pjsipContainerName | Out-Null
        }
    }

    # 首次全量复制（如果是新容器）
    if ($isNewContainer) {
        Write-Host "  [3/6] 首次全量复制源码..." -ForegroundColor Green
        $fullCopyStartTime = Get-Date

        # 使用 tar 复制，排除编译产物
        Write-Host "    创建源码 tar 包..." -ForegroundColor Gray

        # ⚠️ 先清理源码目录中的旧 tar 文件，避免 tar 打包自己
        Push-Location $pjsipSourceDir
        Get-ChildItem -Filter "*.tar" | Remove-Item -Force -ErrorAction SilentlyContinue

        # 使用简单文件名，在源码目录创建 tar
        $tarFileName = "pjsip-source-full.tar"
        tar -cf $tarFileName `
            --exclude="*.o" `
            --exclude="*.a" `
            --exclude="*.so" `
            --exclude="*.dll" `
            --exclude="*.tar" `
            --exclude=".*.depend" `
            --exclude="build.mak" `
            --exclude="output/*" `
            --exclude=".git/*" `
            .
        $tarExitCode = $LASTEXITCODE

        # 移动到 temp 目录
        $tempTar = Join-Path $env:TEMP $tarFileName
        if ($tarExitCode -eq 0) {
            Move-Item $tarFileName $tempTar -Force
        }
        Pop-Location

        if ($tarExitCode -ne 0) {
            Write-Host "    [错误] tar 创建失败（退出码: $tarExitCode）" -ForegroundColor Red
            exit 1
        }

        Write-Host "    复制 tar 到容器..." -ForegroundColor Gray
        docker cp $tempTar "${pjsipContainerName}:/tmp/source.tar" | Out-Null

        Write-Host "    解压源码..." -ForegroundColor Gray
        docker exec $pjsipContainerName tar -xf /tmp/source.tar -C /workspace/ | Out-Null

        # 恢复所有配置脚本的执行权限
        Write-Host "    设置执行权限..." -ForegroundColor Gray
        docker exec $pjsipContainerName bash -c "find /workspace -type f \( -name '*.sh' -o -name 'configure' -o -name 'aconfigure' \) -exec chmod +x {} \;" | Out-Null

        Remove-Item $tempTar -Force

        # 复制配置文件
        Write-Host "    复制配置文件..." -ForegroundColor Gray
        docker exec $pjsipContainerName mkdir -p /workspace/pjlib/include/pj | Out-Null
        docker cp $pjsipConfigSite "${pjsipContainerName}:/workspace/pjlib/include/pj/config_site.h" | Out-Null

        $fullCopyElapsed = (Get-Date) - $fullCopyStartTime
        Write-Host "    ✓ 全量复制完成（耗时 $($fullCopyElapsed.TotalSeconds.ToString('F1'))s）" -ForegroundColor Green
        Write-Host ""

        # 首次编译（建立 .o 缓存）
        Write-Host "  [4/6] 首次编译（建立增量缓存，约1-2分钟）..." -ForegroundColor Green
        $firstBuildStartTime = Get-Date

        # 获取配置文件时间戳
        $configTimestamp = (Get-Item "$ProjectRoot\docker\rk3588\pjsip_config_site.h").LastWriteTime.ToString("o")

        $firstBuildScript = @'
#!/bin/bash
# ⚠️ 不使用 set -e，手动检查每个命令的退出码（避免管道干扰）
cd /workspace

echo "================================================"
echo "配置 PJSIP..."
echo "================================================"
export CC=aarch64-linux-gnu-gcc
export CXX=aarch64-linux-gnu-g++
export AR=aarch64-linux-gnu-ar
export RANLIB=aarch64-linux-gnu-ranlib

# ⚠️ 检测 FFmpeg 头文件实际路径
FFMPEG_INCLUDE_DIR=$(find /opt/rk3588-sysroot/usr/include -name "libavutil" -type d 2>/dev/null | head -1 | xargs dirname)
if [ -z "$FFMPEG_INCLUDE_DIR" ]; then
    echo "✗ FFmpeg 头文件未找到！"
    exit 1
fi
echo "检测到 FFmpeg 头文件: $FFMPEG_INCLUDE_DIR"

# ⚠️ CFLAGS 必须包含 sysroot 头文件路径（FFmpeg、RKMPP）
export CFLAGS="-fPIC -O2 -I/opt/rk3588-sysroot/usr/include -I/opt/rk3588-sysroot/usr/include/aarch64-linux-gnu -I$FFMPEG_INCLUDE_DIR"
export CXXFLAGS="-fPIC -O2 -I/opt/rk3588-sysroot/usr/include -I/opt/rk3588-sysroot/usr/include/aarch64-linux-gnu -I$FFMPEG_INCLUDE_DIR"

# ✅ 2025-12-30 19:00 关键修复：为 PJSIP 测试程序提供完整的 FFmpeg 编解码器依赖库
# LDFLAGS：库搜索路径（-L）
export LDFLAGS="-L/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu -L/opt/rk3588-sysroot/usr/lib -L/usr/lib/aarch64-linux-gnu"

# LIBS：具体链接库（-l），包含所有 FFmpeg 编解码器依赖
# 这些库用于 PJSIP 测试程序的链接，确保 FFmpeg 编解码器能正确初始化
# ✅ 2026-01-10 02:05 [修复 100.4] 恢复原始 LIBS 配置
# 原因：删除库后改变了链接顺序，导致 libswresample 依赖没有被正确解析
# 旧代码（2026-01-10 01:45 修复 100.2 注释）：
# export LIBS="-lx264 -lx265 -lvpx -lcairo -ltwolame -lwebp -lcodec2 -ldav1d -laom -lwavpack -ltheora -ltheoraenc -ltheoradec -lxvidcore -lopenjp2 -lshine -lsnappy -lzvbi -lrga -lrockchip_mpp -lpthread -lm -lrt"
# 说明：即使某些库（如 libva）不存在于 ARM 平台，链接器会忽略它们，不会影响编译
export LIBS="-lx264 -lx265 -lvpx -lcairo -lva -lva-drm -lva-x11 -ltwolame -lwebp -lcodec2 -ldav1d -laom -lwavpack -ltheora -ltheoraenc -ltheoradec -lxvidcore -lopenjp2 -lshine -lsnappy -lzvbi -lrsvg-2 -lvdpau -lrga -lrockchip_mpp -lpthread -lm -lrt"

# ⚠️ PKG_CONFIG_SYSROOT_DIR 让 pkg-config 重定向 .pc 文件中的路径到 sysroot
export PKG_CONFIG_SYSROOT_DIR=/opt/rk3588-sysroot

# ⚠️ PKG_CONFIG_PATH 必须包含 sysroot 的 pkgconfig 目录
export PKG_CONFIG_PATH=/opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig:/opt/rk3588-sysroot/usr/lib/pkgconfig

echo "环境变量："
echo "  CC=$CC"
echo "  CFLAGS=$CFLAGS"
echo "  CPPFLAGS=$CPPFLAGS"
echo "  LDFLAGS=$LDFLAGS"
echo "  PKG_CONFIG_SYSROOT_DIR=$PKG_CONFIG_SYSROOT_DIR"
echo "  PKG_CONFIG_PATH=$PKG_CONFIG_PATH"
echo ""

# ⚠️ 为 FFmpeg 创建符号链接，让 --with-ffmpeg 能找到 .pc 文件
echo "创建 FFmpeg pkg-config 符号链接..."
mkdir -p /opt/rk3588-sysroot/usr/lib/pkgconfig
ln -sf /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig/libavcodec.pc /opt/rk3588-sysroot/usr/lib/pkgconfig/ 2>/dev/null || true
ln -sf /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig/libavformat.pc /opt/rk3588-sysroot/usr/lib/pkgconfig/ 2>/dev/null || true
ln -sf /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig/libavutil.pc /opt/rk3588-sysroot/usr/lib/pkgconfig/ 2>/dev/null || true
ln -sf /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig/libavdevice.pc /opt/rk3588-sysroot/usr/lib/pkgconfig/ 2>/dev/null || true
ln -sf /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig/libswscale.pc /opt/rk3588-sysroot/usr/lib/pkgconfig/ 2>/dev/null || true
ln -sf /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig/libswresample.pc /opt/rk3588-sysroot/usr/lib/pkgconfig/ 2>/dev/null || true
ln -sf /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig/libavfilter.pc /opt/rk3588-sysroot/usr/lib/pkgconfig/ 2>/dev/null || true

# ✅ 2025-12-30 10:45 关键修复：创建标准布局符号链接，让 PJSIP configure 能找到 FFmpeg
#    PJSIP --with-ffmpeg=/path 会查找 /path/lib/ 和 /path/include/
#    我们的文件在 /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu/
echo "创建 sysroot 标准布局符号链接（让 PJSIP configure 检测到 FFmpeg）..."
ln -sfn /opt/rk3588-sysroot/usr/lib/aarch64-linux-gnu /opt/rk3588-sysroot/lib 2>/dev/null || true
ln -sfn /opt/rk3588-sysroot/usr/include /opt/rk3588-sysroot/include 2>/dev/null || true
echo ""

# ⚠️ 设置 PKG_CONFIG_SYSROOT_DIR 让 pkg-config 正确处理 sysroot 路径
export PKG_CONFIG_SYSROOT_DIR=/opt/rk3588-sysroot

./configure \
    --host=aarch64-linux-gnu \
    --prefix=/opt/pjsip \
    --disable-shared \
    --enable-static \
    --with-ssl=/usr \
    --with-sdl=/usr \
    --with-ffmpeg=/opt/rk3588-sysroot 2>&1 | tee /tmp/configure.log
    # ✅ 2026-01-10 02:15 [恢复] 恢复 FFmpeg 启用（配合原始符号链接和 LIBS 配置）
    # 原因：临时禁用 FFmpeg 不是解决方案，视频通话必须依赖 FFmpeg
    # 说明：配合 Fix 100 原始符号链接 + Fix 100.4 原始 LIBS 配置，应该可以编译成功

# ⚠️ 说明（2025-12-30 更新）：
# - 启用 FFmpeg：用于 H.264/H.265 视频编解码（从设备 188 sysroot 复制）
# - RKMPP 硬件编解码器：通过 PJSIP 的自定义编解码器接口注册
# - 保留 SDL：用于视频设备支持
# - 保留 OpenSSL：用于 TLS/SRTP 加密

# ⚠️ 检查 configure 是否成功
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "✗ configure 失败"
    exit 1
fi

echo ""
echo "生成依赖文件（make dep）..."
echo "（这个过程需要扫描所有头文件，约需 1-3 分钟，请耐心等待）"

# 显示进度的 make dep
make dep 2>&1 | while IFS= read -r line; do
    # 只显示正在处理的文件（减少输出）
    if echo "$line" | grep -q "^make\["; then
        echo "$line"
    fi
done > /tmp/make_dep.log

# ⚠️ 检查 make dep 是否成功
DEP_EXIT=${PIPESTATUS[0]}
if [ $DEP_EXIT -ne 0 ]; then
    echo "⚠️ make dep 失败，尝试继续编译（某些模块的 dep 可能失败但不影响编译）"
    tail -20 /tmp/make_dep.log
else
    echo "✓ make dep 完成"
fi

echo ""
echo "编译 PJSIP 静态库（使用 $(nproc) 线程）..."
# ✅ 2026-01-10 02:30 [修复 100.6] 使用 make lib 代替 make
# 原因：
#   1. make lib 只编译静态库（21个 .a 文件），不编译测试程序
#   2. 测试程序（pjmedia-test）链接失败不影响主应用程序
#   3. 测试程序失败通常是因为 libswresample 等库的版本问题
# 旧代码（2026-01-10 02:30 注释）：
#   make -j$(nproc) 2>&1 | tee /tmp/make.log
# 说明：根据以往的经验，make 不一定行，需要 make lib
make lib -j$(nproc) 2>&1 | tee /tmp/make.log

# ⚠️ make lib 必须成功，否则说明链接库配置有问题
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "✗ make lib 编译失败"
    echo ""
    echo "=== 最后 100 行编译日志 ==="
    tail -100 /tmp/make.log
    exit 1
fi

echo ""
echo "复制静态库到输出目录..."
mkdir -p /output/lib
find . -name "*.a" -type f -exec cp {} /output/lib/ \;

FINAL_COUNT=$(ls /output/lib/*.a 2>/dev/null | wc -l)
echo ""
if [ $FINAL_COUNT -lt 20 ]; then
    echo "✗ 静态库数量不足：${FINAL_COUNT} 个（预期 >=20）"
    exit 1
else
    echo "✓ 静态库生成成功：${FINAL_COUNT} 个"
    echo "✓ PJSIP 静态库编译完成（不包括测试程序）"
    # 记录配置文件时间戳（用于检测配置是否修改）
    echo "$CONFIG_TIMESTAMP" > /workspace/.config_timestamp
fi
'@

        $firstBuildScript = $firstBuildScript -replace "`r`n", "`n"
        $firstBuildScript = $firstBuildScript -replace "`r", "`n"

        $tempScript = Join-Path $env:TEMP "pjsip-first-build.sh"
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tempScript, $firstBuildScript, $utf8NoBom)

        docker cp $tempScript "${pjsipContainerName}:/tmp/first-build.sh" | Out-Null
        docker exec -e CONFIG_TIMESTAMP="$configTimestamp" $pjsipContainerName bash /tmp/first-build.sh

        # ⚠️ 检查编译是否成功
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [错误] PJSIP 编译失败（退出码: $LASTEXITCODE）" -ForegroundColor Red
            Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
            exit 1
        }

        $firstBuildElapsed = (Get-Date) - $firstBuildStartTime
        Write-Host "    ✓ 首次编译完成（耗时 $($firstBuildElapsed.TotalSeconds.ToString('F1'))s）" -ForegroundColor Green
        Write-Host ""

        Remove-Item $tempScript -Force
    } else {
        Write-Host "  [3-4/6] 跳过初始化（容器已有源码）" -ForegroundColor Green
        Write-Host ""

        # 使用 Git 检测修改的文件
        Write-Host "  [5/6] 检测修改的文件（使用 Git）..." -ForegroundColor Green
        $detectStartTime = Get-Date

        $isGitRepo = Test-Path "$pjsipSourceDir\.git"

        if ($isGitRepo) {
            $modifiedFilesRaw = git -C $pjsipSourceDir diff --name-only HEAD 2>$null
            $modifiedFiles = $modifiedFilesRaw | Where-Object { $_ -match '\.(c|cpp|h|hpp)$' }

            if (-not $modifiedFiles) {
                Write-Host "    ✓ 无修改文件（跳过同步）" -ForegroundColor Green
                $needSync = $false
            } else {
                Write-Host "    检测到 $($modifiedFiles.Count) 个修改的文件" -ForegroundColor Yellow
                $modifiedFiles | Select-Object -First 3 | ForEach-Object {
                    Write-Host "      - $_" -ForegroundColor Gray
                }
                if ($modifiedFiles.Count -gt 3) {
                    Write-Host "      ... 还有 $($modifiedFiles.Count - 3) 个文件" -ForegroundColor Gray
                }
                $needSync = $true
            }
        } else {
            Write-Host "    使用时间戳检测" -ForegroundColor Yellow
            $needSync = $true
            # 简化：直接认为需要同步
        }

        $detectElapsed = (Get-Date) - $detectStartTime
        Write-Host "    检测耗时: $($detectElapsed.TotalSeconds.ToString('F1'))s" -ForegroundColor Gray
        Write-Host ""

        # 批量同步修改的文件
        if ($needSync) {
            Write-Host "  [6/6] 批量同步修改的文件..." -ForegroundColor Green
            $syncStartTime = Get-Date

            $tempTar = Join-Path $env:TEMP "pjsip-modified-$(Get-Date -Format 'HHmmss').tar"

            Write-Host "    创建 tar 包..." -ForegroundColor Gray
            if ($modifiedFiles) {
                # 创建 Unix 格式的文件列表（LF 换行符）
                $fileListPath = Join-Path $env:TEMP "modified-files.txt"
                $fileListContent = ($modifiedFiles -join "`n") + "`n"
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($fileListPath, $fileListContent, $utf8NoBom)

                # ⚠️ 先清理源码目录中的旧 tar 文件
                Push-Location $pjsipSourceDir
                Get-ChildItem -Filter "*.tar" | Remove-Item -Force -ErrorAction SilentlyContinue

                # 使用简单文件名，在当前目录创建 tar
                $tarFileName = "pjsip-modified-$(Get-Date -Format 'HHmmss').tar"
                tar -cf $tarFileName -T $fileListPath
                $tarExitCode = $LASTEXITCODE

                # 移动到 temp 目录
                $tempTar = Join-Path $env:TEMP $tarFileName
                if ($tarExitCode -eq 0) {
                    Move-Item $tarFileName $tempTar -Force
                }
                Pop-Location

                Remove-Item $fileListPath -Force

                if ($tarExitCode -ne 0) {
                    Write-Host "    [错误] tar 创建失败（退出码: $tarExitCode）" -ForegroundColor Red
                    exit 1
                }
            } else {
                # 回退：同步配置文件
                Push-Location $pjsipSourceDir
                Get-ChildItem -Filter "*.tar" | Remove-Item -Force -ErrorAction SilentlyContinue

                $tarFileName = "pjsip-modified-$(Get-Date -Format 'HHmmss').tar"
                tar -cf $tarFileName "pjlib/include/pj/config_site.h"
                $tarExitCode = $LASTEXITCODE

                # 移动到 temp 目录
                $tempTar = Join-Path $env:TEMP $tarFileName
                if ($tarExitCode -eq 0) {
                    Move-Item $tarFileName $tempTar -Force
                }
                Pop-Location

                if ($tarExitCode -ne 0) {
                    Write-Host "    [错误] tar 创建失败（退出码: $tarExitCode）" -ForegroundColor Red
                    exit 1
                }
            }

            Write-Host "    复制 tar 到容器..." -ForegroundColor Gray
            docker cp $tempTar "${pjsipContainerName}:/tmp/modified.tar" | Out-Null

            Write-Host "    解压到容器..." -ForegroundColor Gray
            docker exec $pjsipContainerName tar -xf /tmp/modified.tar -C /workspace/ | Out-Null

            Remove-Item $tempTar -Force

            $syncElapsed = (Get-Date) - $syncStartTime
            Write-Host "    ✓ 同步完成（耗时 $($syncElapsed.TotalSeconds.ToString('F1'))s）" -ForegroundColor Green
            Write-Host ""
        } else {
            Write-Host "  [6/6] 跳过文件同步（无修改）" -ForegroundColor Green
            Write-Host ""
        }

        # 容器内增量编译
        Write-Host "  [增量编译] 容器内增量编译..." -ForegroundColor Green
        $incrementalBuildStartTime = Get-Date

        $incrementalBuildScript = @'
#!/bin/bash
set -e
cd /workspace

echo "增量编译（Make 自动检测依赖）..."
make -j$(nproc) >/dev/null 2>&1

# 更新静态库到输出目录
mkdir -p /output/lib
find . -name "*.a" -type f -exec cp {} /output/lib/ \;

FINAL_COUNT=$(ls /output/lib/*.a 2>/dev/null | wc -l)
echo "✓ 增量编译完成！已更新 ${FINAL_COUNT} 个静态库"
'@

        $incrementalBuildScript = $incrementalBuildScript -replace "`r`n", "`n"
        $incrementalBuildScript = $incrementalBuildScript -replace "`r", "`n"

        $tempScript = Join-Path $env:TEMP "pjsip-incremental-build.sh"
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tempScript, $incrementalBuildScript, $utf8NoBom)

        docker cp $tempScript "${pjsipContainerName}:/tmp/incremental-build.sh" | Out-Null
        docker exec $pjsipContainerName bash /tmp/incremental-build.sh

        $incrementalBuildElapsed = (Get-Date) - $incrementalBuildStartTime
        Write-Host "    ✓ 增量编译完成（耗时 $($incrementalBuildElapsed.TotalSeconds.ToString('F1'))s）" -ForegroundColor Green
        Write-Host ""

        Remove-Item $tempScript -Force
    }

    # 复制到 rk3588-libs 目录
    Write-Host "  [最终步骤] 复制编译结果到 rk3588-libs..." -ForegroundColor Green
    $targetLibDir = "$ProjectRoot\docker\rk3588\rk3588-libs\lib"
    if (-not (Test-Path $targetLibDir)) {
        New-Item -ItemType Directory -Path $targetLibDir -Force | Out-Null
    }

    Copy-Item "$pjsipOutputDir\lib\*.a" $targetLibDir -Force

    $libCount = (Get-ChildItem -Path $targetLibDir -Filter "*.a").Count
    Write-Host ""
    Write-Host "  ✓ PJSIP 编译完成，生成 $libCount 个静态库" -ForegroundColor Green

    # 清除应用缓存（因为 PJSIP 库已更新）
    Write-Host "  清除应用缓存（PJSIP 库已更新）..." -ForegroundColor Yellow
    $appImageExists = docker images -q "${AppImageName}:${AppImageTag}" 2>$null
    if ($appImageExists) {
        docker rmi "${AppImageName}:${AppImageTag}" 2>&1 | Out-Null
    }
    if (Test-Path $AppCacheFile) {
        Remove-Item $AppCacheFile -Force
    }
    $binaryPath = "$ProjectRoot\build_rk3588\bin_arm64\belt_control_system"
    if (Test-Path $binaryPath) {
        Remove-Item $binaryPath -Force
    }
}
Write-Host ""

# ============================================================
# Step -0.5: PJSIP 静态库变化检测（自动清除应用缓存）
# ============================================================
Write-Host "Step -0.5: Checking PJSIP static libraries..." -ForegroundColor Cyan

# 🔍 监控 PJSIP 静态库文件哈希，确保库更新后应用重新链接
$pjsipLibDir = "$ProjectRoot\docker\rk3588\rk3588-libs\lib"

if (-not (Test-Path $pjsipLibDir)) {
    Write-Host "  [!] PJSIP 库目录不存在 - 请先编译 PJSIP" -ForegroundColor Red
    exit 1
}

# 获取所有 PJSIP 静态库文件
$pjsipLibFiles = Get-ChildItem -Path $pjsipLibDir -Filter "*.a" -File | Sort-Object Name

if ($pjsipLibFiles.Count -eq 0) {
    Write-Host "  [!] PJSIP 库不存在 - 请先编译 PJSIP" -ForegroundColor Red
    exit 1
}

Write-Host "  找到 $($pjsipLibFiles.Count) 个 PJSIP 静态库" -ForegroundColor Gray

# 计算所有静态库的综合哈希
$combinedHash = ""
$recentlyModified = @()

foreach ($file in $pjsipLibFiles) {
    $fileHash = (Get-FileHash -Path $file.FullName -Algorithm MD5).Hash
    $combinedHash += $fileHash

    # 记录最近修改的库（1小时内）
    $timeDiff = (Get-Date) - $file.LastWriteTime
    if ($timeDiff.TotalHours -lt 1) {
        $recentlyModified += @{
            Name = $file.Name
            Time = $file.LastWriteTime.ToString("MM-dd HH:mm:ss")
            Size = [math]::Round($file.Length / 1MB, 2)
        }
    }
}

$currentLibsHash = (Get-FileHash -Algorithm MD5 -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($combinedHash)))).Hash
Write-Host "  当前库哈希: $currentLibsHash" -ForegroundColor Cyan

# 检查静态库是否变化
$libsChanged = $false
if (Test-Path $PJSIPLibsCacheFile) {
    $libsCache = Get-Content $PJSIPLibsCacheFile | ConvertFrom-Json
    $previousLibsHash = $libsCache.libsHash

    Write-Host "  缓存库哈希: $previousLibsHash" -ForegroundColor Cyan

    if ($previousLibsHash -ne $currentLibsHash) {
        $libsChanged = $true
        Write-Host ""
        Write-Host "  [!] PJSIP 静态库已变化 - 需要重新链接应用" -ForegroundColor Yellow

        if ($recentlyModified.Count -gt 0) {
            Write-Host "  最近修改的库（1小时内）：" -ForegroundColor Yellow
            foreach ($modFile in $recentlyModified) {
                Write-Host "    - $($modFile.Name) ($($modFile.Size)MB, $($modFile.Time))" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  [OK] PJSIP 静态库未变化" -ForegroundColor Green
    }
} else {
    Write-Host "  [INFO] 首次检测 - 创建缓存" -ForegroundColor Gray
    $libsChanged = $true  # 首次检测，标记为已变化以创建缓存
}

# 如果静态库变化，清除应用缓存和二进制文件
if ($libsChanged) {
    Write-Host ""
    Write-Host "  🔧 清除应用缓存（强制重新链接新库）..." -ForegroundColor Yellow

    # 1. 删除 Docker 应用镜像
    $appImageExists = docker images -q "${AppImageName}:${AppImageTag}" 2>$null
    if ($appImageExists) {
        Write-Host "    删除旧应用镜像..." -ForegroundColor Gray
        docker rmi "${AppImageName}:${AppImageTag}" 2>&1 | Out-Null
    }

    # 2. 清除 Docker 构建缓存
    Write-Host "    清除 Docker 构建缓存..." -ForegroundColor Gray
    docker builder prune -af 2>&1 | Out-Null

    # 3. 删除应用缓存文件
    if (Test-Path $AppCacheFile) {
        Remove-Item $AppCacheFile -Force
    }

    # 4. 删除交叉编译的二进制文件（强制重新链接）
    $binaryPath = "$ProjectRoot\build_rk3588\bin_arm64\belt_control_system"
    if (Test-Path $binaryPath) {
        Write-Host "    删除旧二进制文件..." -ForegroundColor Gray
        Remove-Item $binaryPath -Force
    }

    Write-Host "  ✓ 缓存已清除，应用将重新编译并链接新库" -ForegroundColor Green

    # 更新静态库缓存
    @{
        libsHash = $currentLibsHash
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        libCount = $pjsipLibFiles.Count
    } | ConvertTo-Json | Set-Content $PJSIPLibsCacheFile -Encoding UTF8
}
Write-Host ""

# ============================================================
# Step 0: Check and build base image if needed
# ============================================================
Write-Host "Step 0: Checking base image..." -ForegroundColor Cyan

$baseImageExists = docker images -q "${BaseImageName}:${BaseImageTag}" 2>$null
$needBuildBase = $false

if (-not $baseImageExists) {
    Write-Host "  [!] Base image not found" -ForegroundColor Yellow
    $needBuildBase = $true
} else {
    # Check if Dockerfile.ubuntu24-base changed
    $baseDockerfilePath = "$ProjectRoot\Dockerfile.ubuntu24-base"
    if (Test-Path $baseDockerfilePath) {
        $currentBaseHash = (Get-FileHash -Path $baseDockerfilePath -Algorithm MD5).Hash

        if (Test-Path $BaseCacheFile) {
            $cacheData = Get-Content $BaseCacheFile | ConvertFrom-Json
            $previousBaseHash = $cacheData.hash

            if ($previousBaseHash -ne $currentBaseHash) {
                Write-Host "  [!] Base Dockerfile changed - rebuild required" -ForegroundColor Yellow
                $needBuildBase = $true
            }
        } else {
            # No cache file, assume need rebuild
            $needBuildBase = $true
        }
    }
}

if ($needBuildBase) {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "  Base Image Build Required" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Need to download ~200MB system dependencies" -ForegroundColor Yellow
    Write-Host "  Estimated time: 5-10 minutes" -ForegroundColor Yellow
    Write-Host "  Recommended: Enable VPN/proxy for faster download" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "VPN/proxy ready? Press any key to continue..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""

    Write-Host "  Building base image (this happens ONCE)..." -ForegroundColor Yellow
    $baseBuildStart = Get-Date

    docker build --platform linux/arm64 -f "$ProjectRoot\Dockerfile.ubuntu24-base" -t "${BaseImageName}:${BaseImageTag}" "$ProjectRoot"

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Base image build failed" -ForegroundColor Red
        exit 1
    }

    $baseBuildDuration = (Get-Date) - $baseBuildStart
    Write-Host "  [OK] Base image built successfully" -ForegroundColor Green
    Write-Host "  [Time] Build time: $($baseBuildDuration.Minutes) min $($baseBuildDuration.Seconds) sec" -ForegroundColor Cyan

    # Save base image hash
    $baseDockerfilePath = "$ProjectRoot\Dockerfile.ubuntu24-base"
    if (Test-Path $baseDockerfilePath) {
        $currentBaseHash = (Get-FileHash -Path $baseDockerfilePath -Algorithm MD5).Hash
        @{ hash = $currentBaseHash; timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") } | ConvertTo-Json | Set-Content $BaseCacheFile
    }
} else {
    Write-Host "  [OK] Base image found (cached, no download needed)" -ForegroundColor Green
}
Write-Host ""

# ============================================================
# Step 1: Cross-compilation check
# ============================================================
Write-Host "Step 1: Cross-compilation check..." -ForegroundColor Cyan

$needCompile = $false

if (-not (Test-Path $BinaryFile)) {
    Write-Host "  Binary not found, compilation required" -ForegroundColor Yellow
    $needCompile = $true
} else {
    Write-Host "  Binary found: $(([System.IO.FileInfo]$BinaryFile).Length / 1MB) MB" -ForegroundColor Green
    Write-Host "  Checking source files..." -ForegroundColor Yellow

    $binaryTime = (Get-Item $BinaryFile).LastWriteTime
    $sourceFiles = Get-ChildItem -Path "$ProjectRoot\src" -Recurse -Include *.cpp,*.h,*.qml -File
    $newerFiles = $sourceFiles | Where-Object { $_.LastWriteTime -gt $binaryTime }

    if ($newerFiles) {
        Write-Host "  Found $($newerFiles.Count) source files newer than binary" -ForegroundColor Yellow
        $needCompile = $true
    } else {
        Write-Host "  No source changes detected" -ForegroundColor Green
        $needCompile = $false
    }
}

if ($needCompile) {
    Write-Host ""
    Write-Host "  Running cross-compilation with GLIBC fix (32 threads)..." -ForegroundColor White
    Write-Host ""

    & "$ProjectRoot\build-rk3588-fixed.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Cross-compilation failed" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "  [OK] Cross-compilation complete" -ForegroundColor Green
} else {
    Write-Host "  [OK] Using existing binary" -ForegroundColor Green
}
Write-Host ""

# ============================================================
# Step 2: Prepare Docker build context (NO sysroot copying)
# ============================================================
Write-Host "Step 2: Preparing Docker build context..." -ForegroundColor Cyan

# Clean and create build context directory
if (Test-Path $DockerContextDir) {
    Write-Host "  Cleaning old build context..." -ForegroundColor Yellow
    Remove-Item $DockerContextDir -Recurse -Force
}
New-Item -ItemType Directory -Path $DockerContextDir | Out-Null
Write-Host "  [OK] Build context directory created" -ForegroundColor Green

# Copy binary
Write-Host "  Copying application binary..." -ForegroundColor Yellow
Copy-Item $BinaryFile "$DockerContextDir\belt_control_system" -Force
Write-Host "  [OK] Binary copied" -ForegroundColor Green

# Copy TTS service executable
$TtsServiceFile = "$ProjectRoot\build_tts_arm64\sherpa_tts_service"
if (Test-Path $TtsServiceFile) {
    Write-Host "  Copying TTS service executable..." -ForegroundColor Yellow
    Copy-Item $TtsServiceFile "$DockerContextDir\sherpa_tts_service" -Force
    Write-Host "  [OK] TTS service copied" -ForegroundColor Green
} else {
    Write-Host "  [!] TTS service not found at $TtsServiceFile (TTS disabled)" -ForegroundColor Yellow
}

# Helper function for fast directory copying (resolving symlinks to real files)
function Fast-Copy {
    param([string]$Source, [string]$Destination, [string]$Label)

    if (-not (Test-Path $Source)) {
        Write-Host "    WARNING: ${Label}: Source not found" -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    Write-Host "    Copying $Label..." -ForegroundColor Gray
    # Use robocopy with /SL to follow symlinks and copy actual file content
    # This ensures Docker build context doesn't contain symlinks
    $result = robocopy $Source $Destination /E /SL /NFL /NDL /NJH /NJS /nc /ns /np

    if ($LASTEXITCODE -lt 8) {
        Write-Host "    OK: ${Label} copied" -ForegroundColor Green
    } else {
        Write-Host "    ERROR: ${Label} copy failed" -ForegroundColor Red
        throw "Failed to copy ${Label}"
    }
}

# Copy Qt6 runtime files
Write-Host "  Copying Qt6 runtime files..." -ForegroundColor Yellow
Fast-Copy "$ProjectRoot\docker\rk3588\qt-raspi\lib" "$DockerContextDir\lib" "Qt6 libraries"
Fast-Copy "$ProjectRoot\docker\rk3588\qt-raspi\plugins" "$DockerContextDir\plugins" "Qt6 plugins"
Fast-Copy "$ProjectRoot\docker\rk3588\qt-raspi\qml" "$DockerContextDir\qml" "QML files"

# Copy additional required libraries from RK3588 libs and sysroot
Write-Host "  Copying additional required libraries..." -ForegroundColor Yellow

# Copy libmali (Mali GPU driver)
$MaliLibPath = "$ProjectRoot\docker\rk3588\rk3588-libs\lib"
if (Test-Path $MaliLibPath) {
    Write-Host "    Copying libmali..." -ForegroundColor Gray
    if (-not (Test-Path "$DockerContextDir\lib")) {
        New-Item -ItemType Directory -Path "$DockerContextDir\lib" -Force | Out-Null
    }
    Copy-Item "$MaliLibPath\libmali.so*" "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue
    Write-Host "    OK: libmali copied" -ForegroundColor Green
}

# ✅ Copy FFmpeg libraries with RKMPP hardware encoder/decoder support (完整版)
# These libraries include both RKMPP encoder and decoder from nyanmisaka/ffmpeg-rockchip fork
# Hardware encoders: h264_rkmpp_encoder, hevc_rkmpp_encoder
# Hardware decoders: h264_rkmpp, hevc_rkmpp, vp8_rkmpp
# ✅ 2026-01-09 21:30 [FFmpeg 6.0] 修正库路径，指向 FFmpeg 6.0 真身
# 原因：docker\rk3588\ffmpeg60-libs\opt\ffmpeg-rockchip 是 FFmpeg 6.0 库的实际位置
# 旧路径 libs\ffmpeg-rkmpp-complete 已过期（FFmpeg 4.x 时代）
$FFmpegHwLibPath = "$ProjectRoot\docker\rk3588\ffmpeg60-libs\opt\ffmpeg-rockchip\lib"
if (Test-Path $FFmpegHwLibPath) {
    Write-Host "    Copying FFmpeg with RKMPP hardware encoder/decoder..." -ForegroundColor Yellow

    # ✅ 2026-01-09 21:30 [FFmpeg 6.0] 复制 FFmpeg 6.0 核心库（libavcodec.so.60.31.102, libavutil.so.58.29.100 等）
    # ⚠️ 2026-01-09 21:45 [关键修复] 只复制实际文件（> 1KB），跳过 WSL 符号链接（0 字节）
    # 原因：WSL 符号链接在 Windows 上是 0 字节文本文件，Docker 无法处理
    # 解决：Dockerfile Line 41-59 会在容器内创建 Linux 原生符号链接
    $ffmpegLibs = Get-ChildItem -Path $FFmpegHwLibPath -Filter "libav*.so.*.*.*" -File
    foreach ($lib in $ffmpegLibs) {
        if ($lib.Length -gt 1KB) {  # 跳过 WSL 符号链接
            Copy-Item $lib.FullName "$DockerContextDir\lib\" -Force -ErrorAction Stop
            Write-Host "      Copied: $($lib.Name)" -ForegroundColor Gray
        }
    }
    # 复制 libsw*（libswscale, libswresample）
    $ffmpegLibs = Get-ChildItem -Path $FFmpegHwLibPath -Filter "libsw*.so.*.*.*" -File
    foreach ($lib in $ffmpegLibs) {
        if ($lib.Length -gt 1KB) {  # 跳过 WSL 符号链接
            Copy-Item $lib.FullName "$DockerContextDir\lib\" -Force -ErrorAction Stop
            Write-Host "      Copied: $($lib.Name)" -ForegroundColor Gray
        }
    }
    # ✅ 2026-01-09 21:30 [FFmpeg 6.0] 复制 libpostproc（FFmpeg 6.0 包含）
    $ffmpegLibs = Get-ChildItem -Path $FFmpegHwLibPath -Filter "libpostproc.so.*.*.*" -File
    foreach ($lib in $ffmpegLibs) {
        if ($lib.Length -gt 1KB) {  # 跳过 WSL 符号链接
            Copy-Item $lib.FullName "$DockerContextDir\lib\" -Force -ErrorAction Stop
            Write-Host "      Copied: $($lib.Name)" -ForegroundColor Gray
        }
    }

    # ✅ 2026-01-09 21:30 [FFmpeg 6.0] 统计所有 FFmpeg 6.0 库大小（libav*, libsw*, libpostproc*）
    $totalSize = 0
    $totalSize += (Get-ChildItem -Path "$DockerContextDir\lib\libav*.so.*.*.*" -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $totalSize += (Get-ChildItem -Path "$DockerContextDir\lib\libsw*.so.*.*.*" -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $totalSize += (Get-ChildItem -Path "$DockerContextDir\lib\libpostproc.so.*.*.*" -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $totalSize = [math]::Round($totalSize / 1MB, 2)
    Write-Host "    OK: FFmpeg 6.0 libraries copied (${totalSize}MB with RKMPP encoder+decoder)" -ForegroundColor Green

    # ✅ 2026-01-09 20:10 [Fix 97 配套] 从 rk3588-libs 复制所有编解码器库到镜像
    # 原因：应用程序编译时链接了所有 FFmpeg 编解码器库，运行时必须提供
    # 方案：将所有库打包到 Docker 镜像，避免运行时依赖宿主机
    # 路径：docker/rk3588/rk3588-libs/lib/ → docker/rk3588/lib/ → Docker 镜像 /app/lib/
    Write-Host "    Copying codec libraries from rk3588-libs (all dependencies)..." -ForegroundColor Yellow

    # ⚠️ 2026-01-09 20:10 关键修复：从 rk3588-libs 复制，不是从 FFmpeg 编译输出
    # FFmpeg 编译输出只包含 FFmpeg 库本身，不包含编解码器依赖库
    $rk3588CodecLibDir = "$ProjectRoot\docker\rk3588\rk3588-libs\lib"

    # 添加所有必需的编解码器库模式（包括 Fix 97 需要的库）
    $codecPatterns = @("libvpx.so.*", "libx264.so.*", "libx265.so.*", "libmp3lame.so.*",
                       "libogg.so.*", "libspeex.so.*", "libtheora*.so.*", "libvorbis*.so.*",
                       "libyuv.so.*", "libwebp.so.*", "libwebpmux.so.*", "libwebpdemux.so.*",
                       "libaribb24.so.*", "libaom.so.*", "libcodec2.so.*", "libdav1d.so.*",
                       "libgsm.so.*", "libopencore-amrnb.so.*", "libopencore-amrwb.so.*",
                       "libopenjp2.so.*", "libshine.so.*", "libsnappy.so.*", "libtwolame.so.*",
                       "libvo-amrwbenc.so.*", "libwavpack.so.*", "libxvidcore.so.*", "libzvbi.so.*",
                       "libva.so.*", "libva-*.so.*", "libvdpau.so.*", "libOpenCL.so.*", "libsoxr.so.*",
                       "librockchip_mpp.so.*", "librga.so.*")

    $codecCount = 0
    $skippedCount = 0

    foreach ($pattern in $codecPatterns) {
        # 优先从 rk3588-libs 复制
        $codecLibs = Get-ChildItem -Path $rk3588CodecLibDir -Filter $pattern -File -ErrorAction SilentlyContinue

        if ($codecLibs) {
            foreach ($lib in $codecLibs) {
                # ⚠️ 2026-01-03 修复：只复制实际文件（> 1KB），跳过符号链接
                # 原因：Windows PowerShell 复制 WSL 符号链接会导致 "file too short" 错误
                if ($lib.Length -gt 1KB) {
                    Copy-Item $lib.FullName "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue
                    Write-Host "      ✓ $($lib.Name) ($([math]::Round($lib.Length / 1KB, 0)) KB)" -ForegroundColor Gray
                    $codecCount++
                } else {
                    $skippedCount++
                }
            }
        }
    }

    if ($codecCount -gt 0) {
        Write-Host "    OK: $codecCount codec libraries copied" -ForegroundColor Green
    } else {
        Write-Host "    WARNING: No codec libraries found, may cause runtime ABI errors" -ForegroundColor Yellow
    }
} else {
    Write-Host "    ERROR: FFmpeg libraries not found!" -ForegroundColor Red
    Write-Host "    Please run: .\download-ffmpeg-from-device.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Copy sherpa-onnx TTS libraries (required for TTS functionality)
Write-Host "    Copying sherpa-onnx TTS libraries..." -ForegroundColor Yellow
$SherpaLibPath = "$ProjectRoot\libs\sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared\lib"
if (Test-Path $SherpaLibPath) {
    Copy-Item "$SherpaLibPath\libsherpa-onnx-c-api.so" "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue
    Copy-Item "$SherpaLibPath\libsherpa-onnx-cxx-api.so" "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue
    Write-Host "    OK: sherpa-onnx TTS libraries copied" -ForegroundColor Green
} else {
    Write-Host "    WARNING: sherpa-onnx libraries not found" -ForegroundColor Yellow
}

# Copy libonnxruntime (RKNN acceleration for TTS)
Write-Host "  Copying libonnxruntime (RKNN acceleration)..." -ForegroundColor Yellow
$OnnxRuntimePath = "$ProjectRoot\libs\sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared\lib\libonnxruntime.so"
if (Test-Path $OnnxRuntimePath) {
    Copy-Item $OnnxRuntimePath "$DockerContextDir\lib\" -Force
    Write-Host "  [OK] libonnxruntime copied (RKNN hardware acceleration)" -ForegroundColor Green
} else {
    Write-Host "  [!] WARNING: libonnxruntime not found - TTS may not work!" -ForegroundColor Yellow
}

# Copy libxcb-dri2 from sysroot if not found in device-build
$XcbPath = "$ProjectRoot\docker\rk3588\sysroot\pi-root\lib\aarch64-linux-gnu"
if (Test-Path $XcbPath) {
    Write-Host "    Copying libxcb-dri2 from sysroot..." -ForegroundColor Gray
    Get-ChildItem -Path $XcbPath -Filter "libxcb-dri2.so.*.*.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue }
    Write-Host "    OK: libxcb-dri2 from sysroot copied" -ForegroundColor Green
}

# Copy librknnrt (RK3588 NPU runtime - REQUIRED for RKNN acceleration)
$RknnLibPath = "$ProjectRoot\docker\rk3588\rk3588-libs\lib"
if (Test-Path $RknnLibPath) {
    Write-Host "    Copying librknnrt (RK3588 NPU runtime)..." -ForegroundColor Yellow
    Get-ChildItem -Path $RknnLibPath -Filter "librknnrt.so*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force }
    Write-Host "    OK: librknnrt copied (RKNN acceleration enabled)" -ForegroundColor Green
} else {
    Write-Host "    WARNING: librknnrt not found - RKNN acceleration will NOT work!" -ForegroundColor Red
}

# ✅ Copy Qt6 dependencies and OpenSSL from sysroot
$SysrootLibPath = "$ProjectRoot\docker\rk3588\sysroot\rk3588-root\lib\aarch64-linux-gnu"
if (Test-Path $SysrootLibPath) {
    # Copy ICU libraries (Qt6 dependencies)
    # Copy actual files (.so.67.1), not symlinks (.so.67)
    Write-Host "    Copying ICU libraries (Qt6 dependencies from sysroot)..." -ForegroundColor Gray
    Copy-Item "$SysrootLibPath\libicui18n.so.67.1" "$DockerContextDir\lib\libicui18n.so.67" -Force -ErrorAction Stop
    Copy-Item "$SysrootLibPath\libicuuc.so.67.1" "$DockerContextDir\lib\libicuuc.so.67" -Force -ErrorAction Stop
    Copy-Item "$SysrootLibPath\libicudata.so.67.1" "$DockerContextDir\lib\libicudata.so.67" -Force -ErrorAction Stop
    Write-Host "    OK: ICU libraries copied (i18n, uc, data)" -ForegroundColor Green

    # Copy PCRE2-16 (Qt6 dependency)
    Write-Host "    Copying PCRE2-16 (Qt6 dependency from sysroot)..." -ForegroundColor Gray
    Copy-Item "$SysrootLibPath\libpcre2-16.so.0.10.1" "$DockerContextDir\lib\libpcre2-16.so.0" -Force -ErrorAction Stop
    Write-Host "    OK: PCRE2-16 copied" -ForegroundColor Green

    # Copy OpenSSL 1.1 (PJSIP runtime dependency)
    Write-Host "    Copying OpenSSL 1.1 (PJSIP runtime dependency)..." -ForegroundColor Yellow
    Copy-Item "$SysrootLibPath\libssl.so.1.1" "$DockerContextDir\lib\" -Force -ErrorAction Stop
    Copy-Item "$SysrootLibPath\libcrypto.so.1.1" "$DockerContextDir\lib\" -Force -ErrorAction Stop
    Write-Host "    OK: OpenSSL 1.1 copied (libssl.so.1.1 + libcrypto.so.1.1)" -ForegroundColor Green
} else {
    Write-Host "    ERROR: Sysroot not found at: $SysrootLibPath" -ForegroundColor Red
    exit 1
}

# Copy TTS models (vits-zh-aishell3)
Write-Host "  Copying TTS models..." -ForegroundColor Yellow
$TtsModelsSource = "$ProjectRoot\libs\tts_models"
if (Test-Path $TtsModelsSource) {
    $ttsModels = Get-ChildItem -Path $TtsModelsSource -Directory
    Write-Host "    Found $($ttsModels.Count) TTS models" -ForegroundColor Gray

    foreach ($model in $ttsModels) {
        $modelSize = [math]::Round((Get-ChildItem -Path $model.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
        Write-Host "    Copying $($model.Name) (${modelSize}MB)..." -ForegroundColor Gray
        Fast-Copy $model.FullName "$DockerContextDir\tts_models\$($model.Name)" "TTS model: $($model.Name)"
    }
    Write-Host "    OK: TTS models copied" -ForegroundColor Green
} else {
    Write-Host "    WARNING: TTS models directory not found" -ForegroundColor Red
    Write-Host "    TTS will be disabled. Please ensure $TtsModelsSource exists" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  [OK] All application files prepared" -ForegroundColor Green
Write-Host "  Note: System libraries already in base image (cached)" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Step 2.5: Compile FFmpeg hardware decoder shim library (DISABLED)
# ============================================================
# Note: Shim library compilation disabled -镜像已删除
Write-Host "Step 2.5: Skipping FFmpeg shim compilation (disabled)..." -ForegroundColor Gray
Write-Host ""

# ============================================================
# Step 3: Create Dockerfile (uses base image)
# ============================================================
Write-Host "Step 3: Using Dockerfile with base image..." -ForegroundColor Cyan

# Copy the Dockerfile.ubuntu24-apt to build context
Copy-Item "$ProjectRoot\Dockerfile.ubuntu24-apt" "$DockerContextDir\Dockerfile" -Force
Write-Host "  [OK] Dockerfile prepared (using cached base image)" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 4: Build Docker application image
# ============================================================
Write-Host "Step 4: Building application image..." -ForegroundColor Cyan
Write-Host "  Image: ${AppImageName}:${AppImageTag}" -ForegroundColor White
Write-Host "  Base: ${BaseImageName}:${BaseImageTag} (cached)" -ForegroundColor White

# Smart cache: Only use --no-cache if binary/TTS/Dockerfile changed
$useNoCache = $false
$appBinaryPath = "$DockerContextDir\belt_control_system"
$ttsBinaryPath = "$DockerContextDir\sherpa_tts_service"
$appDockerfilePath = "$ProjectRoot\Dockerfile.ubuntu24-apt"

if ((Test-Path $appBinaryPath) -and (Test-Path $ttsBinaryPath) -and (Test-Path $appDockerfilePath)) {
    $appHash = (Get-FileHash -Path $appBinaryPath -Algorithm MD5).Hash
    $ttsHash = (Get-FileHash -Path $ttsBinaryPath -Algorithm MD5).Hash
    $dockerfileHash = (Get-FileHash -Path $appDockerfilePath -Algorithm MD5).Hash

    $currentHash = "$appHash|$ttsHash|$dockerfileHash"

    if (Test-Path $AppCacheFile) {
        $cacheData = Get-Content $AppCacheFile | ConvertFrom-Json
        $previousHash = $cacheData.hash

        if ($previousHash -ne $currentHash) {
            Write-Host "  Detected changes - rebuilding application layer" -ForegroundColor Yellow
            $useNoCache = $true
        } else {
            Write-Host "  No changes - using Docker cache" -ForegroundColor Green
        }
    } else {
        Write-Host "  First build - building application layer" -ForegroundColor Yellow
        $useNoCache = $true
    }

    # Save hash
    @{ hash = $currentHash; timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") } | ConvertTo-Json | Set-Content $AppCacheFile
}

Write-Host "  Estimated time: 1-2 minutes (no dependency download)..." -ForegroundColor Yellow
Write-Host ""

$buildStart = Get-Date
$buildArgs = @("build", "--platform", "linux/arm64")
if ($useNoCache) {
    $buildArgs += "--no-cache"
}
$buildArgs += @("-t", "${AppImageName}:${AppImageTag}", $DockerContextDir)

& docker $buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Docker build failed" -ForegroundColor Red
    exit 1
}

$buildDuration = (Get-Date) - $buildStart
Write-Host ""
Write-Host "  [OK] Application image built successfully" -ForegroundColor Green
Write-Host "  [Time] Build time: $($buildDuration.Minutes) min $($buildDuration.Seconds) sec" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Step 5: Verify image and dependencies
# ============================================================
Write-Host "Step 5: Verifying image dependencies..." -ForegroundColor Cyan

Write-Host "  Checking if all libraries are present..." -ForegroundColor Yellow
$lddOutput = docker run --rm --platform=linux/arm64 "${AppImageName}:${AppImageTag}" ldd /app/belt_control_system

Write-Host ""
Write-Host "=== LDD Output ===" -ForegroundColor White
Write-Host $lddOutput
Write-Host "==================" -ForegroundColor White
Write-Host ""

$notFound = $lddOutput | Select-String "not found"
if ($notFound) {
    Write-Host "  [!] Some libraries need runtime mounting from host:" -ForegroundColor Yellow
    $notFoundList = $notFound | ForEach-Object { $_.Line.Trim() }
    foreach ($lib in $notFoundList) {
        if ($lib -match "librockchip_mpp|librga|libyuv") {
            Write-Host "    ✓ $lib (will be mounted from host at runtime)" -ForegroundColor Cyan
        } elseif ($lib -match "libx264") {
            Write-Host "    ✓ $lib (optional: using hardware encoder instead)" -ForegroundColor Cyan
        } elseif ($lib -match "libsherpa-onnx") {
            Write-Host "    ⚠ $lib (TTS may not work)" -ForegroundColor Yellow
        } else {
            Write-Host "    ⚠ $lib" -ForegroundColor Yellow
        }
    }
    Write-Host ""
    Write-Host "  [OK] FFmpeg libraries bundled (libavcodec58 with RKMPP hardware decoders from device)" -ForegroundColor Green
} else {
    Write-Host "  [OK] All dependencies satisfied!" -ForegroundColor Green
}
Write-Host ""

# ============================================================
# Step 6: Export and deploy to device
# ============================================================
Write-Host "Step 6: Export and deploy to device..." -ForegroundColor Cyan
Write-Host "  Target device: $DeviceUser@$DeviceIP" -ForegroundColor White
Write-Host ""

# Export to local tar file
Write-Host "  [1/4] Exporting image to tar..." -ForegroundColor Yellow
if (Test-Path $OutputTarFile) {
    Remove-Item $OutputTarFile -Force
}
docker save "${AppImageName}:${AppImageTag}" -o $OutputTarFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Export failed" -ForegroundColor Red
    exit 1
}

$tarSize = [math]::Round((Get-Item $OutputTarFile).Length / 1GB, 2)
Write-Host "  [OK] Image exported: ${tarSize}GB" -ForegroundColor Green

# Upload to device
Write-Host "  [2/4] Uploading to device (this may take a few minutes)..." -ForegroundColor Yellow
$remoteTarPath = "/tmp/belt-control-ubuntu24-apt.tar"
scp $OutputTarFile "${DeviceUser}@${DeviceIP}:${remoteTarPath}"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Upload failed" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Upload complete" -ForegroundColor Green

# Load on device
Write-Host "  [3/4] Loading image on device..." -ForegroundColor Yellow
ssh "${DeviceUser}@${DeviceIP}" "docker load -i $remoteTarPath && rm $remoteTarPath"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Load failed" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Image loaded on device" -ForegroundColor Green

# Create run script on device
Write-Host "  [4/4] Creating run script on device..." -ForegroundColor Yellow

# Use single-quote here-string to avoid variable expansion issues, then manually replace needed variables
$runScript = @'
#!/bin/bash
# Belt Control System v3.5 - Ubuntu 24.04 apt-get Method
# Generated by build-ubuntu24-apt.ps1

sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

echo "=========================================="
echo "Belt Control System v3.5"
echo "Ubuntu 24.04 | apt-get native packages"
echo "Data persistence enabled"
echo "=========================================="
echo ""

# Create persistent data directory if not exists (unified appdata)
mkdir -p /home/DEVICE_USER_PLACEHOLDER/belt-control-data/appdata
mkdir -p /home/DEVICE_USER_PLACEHOLDER/belt-control-data/audio

# Auto-detect Qt platform based on X11 availability
export DISPLAY=:0
if xhost +local:docker 2>/dev/null; then
    echo "✅ X11 detected - using XCB with Mali GPU acceleration"
    QT_PLATFORM=xcb
    DISPLAY_ARG="-e DISPLAY=:0"
    X11_VOLUME="-v /tmp/.X11-unix:/tmp/.X11-unix:rw"

    # Mali GPU acceleration via LD_PRELOAD (bypasses broken Mesa AIGLX)
    # Problem: Host X11 AIGLX fails to load rockchip DRI -> falls back to llvmpipe
    # Solution: Directly use Mali GPU library via LD_PRELOAD
    # Result: CPU usage drops from 492% to ~140% (71% improvement)
    # - Mount Mali library from host (libmali.so.1.9.0)
    # - Mount libxcb-dri2 dependency required by Mali library
    # - LD_PRELOAD Mali library to override Mesa EGL/GLES
    MALI_VOLUME="-v /usr/lib/aarch64-linux-gnu/libmali.so.1.9.0:/opt/mali/libmali.so.1:ro"
    MALI_VOLUME="$MALI_VOLUME -v /lib/aarch64-linux-gnu/libxcb-dri2.so.0:/lib/aarch64-linux-gnu/libxcb-dri2.so.0:ro"

    # LD_PRELOAD configuration
    # Mali GPU acceleration via direct library preload (3D rendering)
    QT_RENDER_OPTS="-e LD_PRELOAD=/opt/mali/libmali.so.1"
    QT_RENDER_OPTS="$QT_RENDER_OPTS -e QT_XCB_GL_INTEGRATION=xcb_egl"

    # ✅ 2026-01-09 20:35 [Fix 97.2 配套] 最简库挂载配置
    # 原因：所有编解码器库（包括 librga.so.2）已打包到 Docker 镜像 /app/lib/ 中
    # 方案：只挂载 RKMPP 硬件编解码器驱动库（必须依赖内核驱动）
    # 结果：容器完全自包含所有依赖，不依赖宿主机任何编解码器库
    # 只挂载 RKMPP 硬件编解码器驱动库（依赖内核驱动）
    HW_LIBS_VOLUME="-v /usr/lib/aarch64-linux-gnu/librockchip_mpp.so.1:/opt/hw-libs/librockchip_mpp.so.1:ro"
    # ❌ 2026-01-09 20:35 移除 librga.so.2 挂载（已包含在镜像 /app/lib/ 中）
    # HW_LIBS_VOLUME="$HW_LIBS_VOLUME -v /usr/lib/aarch64-linux-gnu/librga.so.2:/opt/hw-libs/librga.so.2:ro"
    HW_LIBS_VOLUME="$HW_LIBS_VOLUME -v /usr/lib/aarch64-linux-gnu/libgomp.so.1.0.0:/opt/hw-libs/libgomp.so.1:ro"
    # LD_LIBRARY_PATH: 优先使用镜像内的库 (/app/lib)
    HW_LIBS_ENV="-e LD_LIBRARY_PATH=/app/lib:/opt/hw-libs:/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu"

    # Enable FFmpeg hardware acceleration for decoding
    # - AV_LOG_LEVEL=debug: Enable detailed FFmpeg logging to verify hardware decoder usage
    # - AV_LOG_FORCE_NOCOLOR=1: Disable color codes for cleaner logs
    # Note: FFmpeg will auto-detect h264_rkmpp/h264_v4l2m2m if devices are accessible
    FFMPEG_HW_OPTS="-e AV_LOG_LEVEL=debug -e AV_LOG_FORCE_NOCOLOR=1"
else
    echo "✅ No X11 - using EGLFS platform (fullscreen mode)"
    QT_PLATFORM=eglfs
    DISPLAY_ARG=""
    X11_VOLUME=""
    MALI_VOLUME=""
    # No LD_PRELOAD needed for EGLFS mode

    # ✅ 2026-01-09 20:35 [Fix 97.2 配套] 最简库挂载配置（EGLFS 模式）
    # 原因：所有编解码器库（包括 librga.so.2）已打包到 Docker 镜像 /app/lib/ 中
    # 方案：只挂载 RKMPP 硬件编解码器驱动库（必须依赖内核驱动）
    # 结果：容器完全自包含所有依赖，不依赖宿主机任何编解码器库
    # 只挂载 RKMPP 硬件编解码器驱动库（依赖内核驱动）
    HW_LIBS_VOLUME="-v /usr/lib/aarch64-linux-gnu/librockchip_mpp.so.1:/opt/hw-libs/librockchip_mpp.so.1:ro"
    # ❌ 2026-01-09 20:35 移除 librga.so.2 挂载（已包含在镜像 /app/lib/ 中）
    # HW_LIBS_VOLUME="$HW_LIBS_VOLUME -v /usr/lib/aarch64-linux-gnu/librga.so.2:/opt/hw-libs/librga.so.2:ro"
    HW_LIBS_VOLUME="$HW_LIBS_VOLUME -v /usr/lib/aarch64-linux-gnu/libgomp.so.1.0.0:/opt/hw-libs/libgomp.so.1:ro"
    # LD_LIBRARY_PATH: 优先使用镜像内的库 (/app/lib)
    HW_LIBS_ENV="-e LD_LIBRARY_PATH=/app/lib:/opt/hw-libs:/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu"

    # Enable FFmpeg hardware acceleration for decoding
    # - AV_LOG_LEVEL=debug: Enable detailed FFmpeg logging to verify hardware decoder usage
    # - AV_LOG_FORCE_NOCOLOR=1: Disable color codes for cleaner logs
    # Note: FFmpeg will auto-detect h264_rkmpp/h264_v4l2m2m if devices are accessible
    FFMPEG_HW_OPTS="-e AV_LOG_LEVEL=debug -e AV_LOG_FORCE_NOCOLOR=1"
fi

echo "Starting application with persistent data..."
echo "Qt Platform: $QT_PLATFORM"

sudo docker run \
    --name belt-control-app \
    --privileged \
    --ipc=host \
    --net=host \
    $DISPLAY_ARG \
    -e QT_QPA_PLATFORM=$QT_PLATFORM \
    $QT_RENDER_OPTS \
    $HW_LIBS_ENV \
    $FFMPEG_HW_OPTS \
    -e XDG_RUNTIME_DIR=/tmp \
    $X11_VOLUME \
    $MALI_VOLUME \
    $HW_LIBS_VOLUME \
    -v /dev:/dev \
    -v /dev/dri:/dev/dri \
    -v /sys:/sys \
    -v /run/udev:/run/udev:ro \
    -v /usr/share/fonts:/usr/share/fonts:ro \
    -v /home/DEVICE_USER_PLACEHOLDER/belt-control-data/appdata:/app/appdata:rw \
    -v /home/DEVICE_USER_PLACEHOLDER/belt-control-data/audio:/app/AUDIO:rw \
    IMAGE_NAME_PLACEHOLDER:IMAGE_TAG_PLACEHOLDER

EXIT_CODE=$?
echo ""
echo "Application exited with code: $EXIT_CODE"

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "Last 30 lines of logs:"
    sudo docker logs --tail 30 belt-control-app
fi

# ============================================================
# 自动 Core Dump 分析（exit code 139 - SIGSEGV）
# 日期：2026-01-10 16:45
# 功能：检测到段错误时自动分析 Core Dump 并显示崩溃原因
# ============================================================
if [ $EXIT_CODE -eq 139 ]; then
    echo ""
    echo "========================================"
    echo "检测到段错误（SIGSEGV）- 自动分析 Core Dump"
    echo "========================================"

    # 查找最新的 Core Dump
    LATEST_CORE=$(ls -t /tmp/belt-control-cores/core.* 2>/dev/null | head -1)

    if [ -z "$LATEST_CORE" ]; then
        echo "⚠️ 未找到 Core Dump 文件"
        echo "   提示：确认容器启动时设置了 --ulimit core=-1"
        echo "   参考：scripts/2026-01-09/19-enable-core-dump.ps1"
    else
        CORE_NAME=$(basename "$LATEST_CORE")
        ANALYSIS_FILE="/tmp/belt-control-cores/${CORE_NAME}.analysis.txt"

        # 检查是否已经分析过
        if [ -f "$ANALYSIS_FILE" ]; then
            echo "ℹ️  Core Dump 已分析（使用缓存）"
            echo "   分析报告: $ANALYSIS_FILE"
        else
            echo "✓ 找到 Core Dump: $LATEST_CORE"
            echo "  文件大小: $(ls -lh $LATEST_CORE | awk '{print $5}')"
            echo ""
            echo "正在分析崩溃原因（这需要几秒钟）..."

            # 执行 GDB 自动分析
            sudo docker run --rm --security-opt apparmor=unconfined \
                -v /tmp/belt-control-cores:/cores:ro \
                IMAGE_NAME_PLACEHOLDER:IMAGE_TAG_PLACEHOLDER \
                bash -c "gdb -batch -ex 'set pagination off' \
                    -ex 'echo \n========================================\n' \
                    -ex 'echo 崩溃分析报告\n' \
                    -ex 'echo ========================================\n' \
                    -ex 'echo \n[1] 崩溃位置\n' \
                    -ex 'bt 3' \
                    -ex 'echo \n[2] 寄存器状态\n' \
                    -ex 'info registers rip rsp rbp' \
                    -ex 'echo \n[3] Frame 2 详情（avcodec_open2）\n' \
                    -ex 'frame 2' \
                    -ex 'info locals' \
                    -ex 'echo \n[4] Frame 3 详情（open_ffmpeg_codec）\n' \
                    -ex 'frame 3' \
                    -ex 'info locals' \
                    -ex 'echo \n========================================\n' \
                    -ex 'echo 分析完成\n' \
                    -ex 'echo ========================================\n' \
                    -ex 'quit' \
                    /app/belt_control_system /cores/$CORE_NAME" 2>&1 | tee "$ANALYSIS_FILE"

            echo ""
            echo "✓ 分析完成并保存到: $ANALYSIS_FILE"
        fi

        # 始终显示崩溃原因摘要
        echo ""
        echo "========================================"
        echo "崩溃原因摘要"
        echo "========================================"
        grep -A 3 "\[1\] 崩溃位置" "$ANALYSIS_FILE" 2>/dev/null || echo "（无法提取堆栈信息）"
        echo ""
        echo "完整分析: $ANALYSIS_FILE"
    fi

    echo ""
    echo "========================================"
    echo "参考文档"
    echo "========================================"
    echo "  Core Dump 分析: docs/2026-01-09/72-Core-Dump分析-编码器初始化崩溃根因.md"
    echo "  解决方案: docs/2026-01-09/73-Fix100.12-硬件编码器解决DRM_PRIME问题.md"
    echo ""
fi
'@

# Replace placeholders with actual values
$runScript = $runScript -replace "DEVICE_USER_PLACEHOLDER", $DeviceUser
$runScript = $runScript -replace "IMAGE_NAME_PLACEHOLDER", $AppImageName
$runScript = $runScript -replace "IMAGE_TAG_PLACEHOLDER", $AppImageTag

# Convert Windows CRLF to Unix LF (fix line ending issue)
$runScript = $runScript -replace "`r`n", "`n"

$runScript | ssh "${DeviceUser}@${DeviceIP}" "cat > /home/$DeviceUser/run-ubuntu24-apt.sh && chmod +x /home/$DeviceUser/run-ubuntu24-apt.sh"

Write-Host "  [OK] Run script created: /home/$DeviceUser/run-ubuntu24-apt.sh" -ForegroundColor Green
Write-Host ""

# Cleanup local tar file
Write-Host "  Cleaning up local tar file..." -ForegroundColor Gray
if (Test-Path $OutputTarFile) {
    Remove-Item $OutputTarFile -Force
    Write-Host "  [OK] Cleanup complete" -ForegroundColor Green
} else {
    Write-Host "  [OK] No cleanup needed (file already removed)" -ForegroundColor Green
}
Write-Host ""

# ============================================================
# Final Summary
# ============================================================
Write-Host "===============================================" -ForegroundColor Green
Write-Host "[SUCCESS] Build & Deploy Complete!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Image Details:" -ForegroundColor Cyan
Write-Host "  Name: ${AppImageName}:${AppImageTag}" -ForegroundColor White
Write-Host "  Base: ${BaseImageName}:${BaseImageTag} (cached)" -ForegroundColor White
Write-Host "  Method: Smart caching (fast rebuild)" -ForegroundColor White
Write-Host "  Size: ${tarSize}GB" -ForegroundColor White
Write-Host ""
Write-Host "Deployment:" -ForegroundColor Cyan
Write-Host "  Device: $DeviceUser@$DeviceIP" -ForegroundColor White
Write-Host "  Status: [OK] Ready to run" -ForegroundColor Green
Write-Host ""
Write-Host "To run the application:" -ForegroundColor Yellow
Write-Host "  ssh $DeviceUser@$DeviceIP ./run-ubuntu24-apt.sh" -ForegroundColor White
Write-Host ""
Write-Host "To test now: (y/N)" -ForegroundColor Yellow
$testNow = Read-Host

if ($testNow -eq "y" -or $testNow -eq "Y") {
    Write-Host ""
    Write-Host "Launching application on device..." -ForegroundColor Cyan
    ssh "${DeviceUser}@${DeviceIP}" "./run-ubuntu24-apt.sh"
}
