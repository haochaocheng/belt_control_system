@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo =========================================
echo 构建 RK3588 运行时 Docker 镜像
echo =========================================
echo.

cd /d %~dp0

echo 步骤 1: 准备运行时依赖库...
echo.

REM 执行准备脚本
docker run --rm ^
  -v "e:/2025/3_gongkongji/belt_control_system:/workspace/belt_control_system" ^
  -v "%~dp0rk3588-libs:/opt/rk3588-libs:ro" ^
  belt-control-rk3588:latest ^
  bash /workspace/belt_control_system/docker/rk3588/prepare-runtime.sh

if %ERRORLEVEL% NEQ 0 (
    echo ❌ 准备依赖失败
    pause
    exit /b 1
)

echo.
echo 步骤 2: 构建简化版运行时镜像（不依赖builder）...
echo.

REM 创建简化版 Dockerfile
echo FROM arm64v8/debian:bullseye-slim> Dockerfile.runtime.simple
echo.>> Dockerfile.runtime.simple
echo ENV DEBIAN_FRONTEND=noninteractive \>> Dockerfile.runtime.simple
echo     QT_QPA_PLATFORM=eglfs \>> Dockerfile.runtime.simple
echo     QT_QPA_EGLFS_ALWAYS_SET_MODE=1 \>> Dockerfile.runtime.simple
echo     LD_LIBRARY_PATH=/opt/app/lib:/usr/local/lib:/usr/lib/aarch64-linux-gnu \>> Dockerfile.runtime.simple
echo     LANG=zh_CN.UTF-8 \>> Dockerfile.runtime.simple
echo     LC_ALL=zh_CN.UTF-8>> Dockerfile.runtime.simple
echo.>> Dockerfile.runtime.simple
echo RUN apt-get update ^&^& apt-get install -y --no-install-recommends \>> Dockerfile.runtime.simple
echo     libc6 libstdc++6 libgcc-s1 \>> Dockerfile.runtime.simple
echo     libx11-6 libxcb1 libxkbcommon0 libinput10 \>> Dockerfile.runtime.simple
echo     libegl1 libgles2 libdrm2 libgbm1 \>> Dockerfile.runtime.simple
echo     libfreetype6 libfontconfig1 libharfbuzz0b \>> Dockerfile.runtime.simple
echo     libglib2.0-0 libdbus-1-3 libicu67 \>> Dockerfile.runtime.simple
echo     libpulse0 libasound2 libsndfile1 \>> Dockerfile.runtime.simple
echo     libv4l-0 libsdl2-2.0-0 libssl1.1 \>> Dockerfile.runtime.simple
echo     fonts-noto-cjk fonts-noto-cjk-extra \>> Dockerfile.runtime.simple
echo     ^&^& apt-get clean ^&^& rm -rf /var/lib/apt/lists/*>> Dockerfile.runtime.simple
echo.>> Dockerfile.runtime.simple
echo RUN mkdir -p /opt/app/bin /opt/app/lib /opt/app/config /opt/app/data>> Dockerfile.runtime.simple
echo.>> Dockerfile.runtime.simple
echo COPY bin_arm64/belt_control_system /opt/app/bin/>> Dockerfile.runtime.simple
echo COPY runtime-libs/*.so* /opt/app/lib/>> Dockerfile.runtime.simple
echo COPY config.ini.example /opt/app/config/>> Dockerfile.runtime.simple
echo COPY tts_models /opt/app/tts_models/>> Dockerfile.runtime.simple
echo COPY AUDIO /opt/app/AUDIO/>> Dockerfile.runtime.simple
echo.>> Dockerfile.runtime.simple
echo RUN chmod +x /opt/app/bin/belt_control_system>> Dockerfile.runtime.simple
echo.>> Dockerfile.runtime.simple
echo WORKDIR /opt/app/bin>> Dockerfile.runtime.simple
echo CMD ["/opt/app/bin/belt_control_system"]>> Dockerfile.runtime.simple

REM 构建镜像
docker build -f Dockerfile.runtime.simple -t belt-control-rk3588:runtime .

if %ERRORLEVEL% EQU 0 (
    echo.
    echo =========================================
    echo ✅ 运行时镜像构建成功！
    echo =========================================
    echo.
    echo 镜像名称: belt-control-rk3588:runtime
    echo.
    echo 下一步:
    echo   1. 保存镜像: docker save belt-control-rk3588:runtime -o belt-control-runtime.tar
    echo   2. 传输到工控机: scp belt-control-runtime.tar pi@192.168.10.170:/tmp/
    echo   3. 加载镜像: docker load -i /tmp/belt-control-runtime.tar
    echo   4. 运行容器: docker-compose up -d
    echo.
) else (
    echo.
    echo ❌ 镜像构建失败
    echo.
)

pause
