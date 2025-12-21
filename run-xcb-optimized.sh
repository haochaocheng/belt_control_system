#!/bin/bash
# Belt Control System v3.5 - Ubuntu 24.04 apt-get Method
# CPU Optimization Version - Qt Quick rendering optimizations

sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

echo "=========================================="
echo "Belt Control System v3.5"
echo "Ubuntu 24.04 | XCB + Qt Quick Optimizations"
echo "Data persistence enabled"
echo "=========================================="
echo ""

# Create persistent data directory if not exists (unified appdata)
mkdir -p /home/linaro/belt-control-data/appdata
mkdir -p /home/linaro/belt-control-data/audio

# Ensure X11 access
export DISPLAY=:0
xhost +local:docker 2>/dev/null || echo "⚠️ X11 not available"

echo "Starting application with Qt Quick optimizations..."
echo "Qt Platform: xcb"
echo "Render loop: basic (single-threaded)"

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
