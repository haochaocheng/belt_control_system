@echo off
echo ========================================
echo Docker Image Download Commands
echo ========================================
echo.
echo Option 1: Direct pull (if network recovers)
echo ----------------------------------------
docker pull ubuntu:24.04
echo.
echo Option 2: Using proxy (if you have proxy)
echo ----------------------------------------
echo set HTTP_PROXY=http://your-proxy:port
echo set HTTPS_PROXY=http://your-proxy:port
echo docker pull ubuntu:24.04
echo.
echo Option 3: Using China mirrors
echo ----------------------------------------
docker pull registry.cn-hangzhou.aliyuncs.com/library/ubuntu:24.04
docker tag registry.cn-hangzhou.aliyuncs.com/library/ubuntu:24.04 ubuntu:24.04
echo.
echo Option 4: Manual download and import
echo ----------------------------------------
echo 1. Download from another machine:
echo    docker pull ubuntu:24.04
echo    docker save -o ubuntu-24.04.tar ubuntu:24.04
echo.
echo 2. Copy ubuntu-24.04.tar to this machine
echo.
echo 3. Import the image:
echo    docker load -i ubuntu-24.04.tar
echo.
pause