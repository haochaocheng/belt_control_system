#!/bin/bash
# Belt Control System v3.5 - CPU Optimized Final Version
# Tested configuration: 50% CPU (vs 450% without optimization)

sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

echo "=========================================="
echo "Belt Control System v3.5"
echo "CPU-Optimized Software Rendering"
echo "=========================================="

mkdir -p /home/linaro/belt-control-data/appdata
mkdir -p /home/linaro/belt-control-data/audio

export DISPLAY=:0
xhost +local:docker 2>/dev/null

echo "Starting with optimized software rendering..."
echo "Target: 50% CPU (vs 450% hardware rendering attempt)"

sudo docker run \
    --name belt-control-app \
    --privileged \
    --ipc=host \
    --net=host \
    -e DISPLAY=:0 \
    -e QT_QPA_PLATFORM=xcb \
    -e QT_XCB_GL_INTEGRATION=none \
    -e QSG_RENDER_LOOP=basic \
    -e QSG_RHI_BACKEND=software \
    -e QT_QUICK_BACKEND=software \
    -e LIBGL_ALWAYS_SOFTWARE=1 \
    -e XDG_RUNTIME_DIR=/tmp \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v /dev:/dev \
    -v /sys:/sys \
    -v /run/udev:/run/udev:ro \
    -v /usr/share/fonts:/usr/share/fonts:ro \
    -v /home/linaro/belt-control-data/appdata:/app/appdata:rw \
    -v /home/linaro/belt-control-data/audio:/app/AUDIO:rw \
    belt-control:v3.5-apt

EXIT_CODE=$?
echo ""
echo "Application exited with code: $EXIT_CODE"

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "Last 30 lines of logs:"
    sudo docker logs --tail 30 belt-control-app
fi
