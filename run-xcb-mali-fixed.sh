#!/bin/bash
# Belt Control System v3.5 - Ubuntu 24.04 apt-get Method
# Fixed version - Mali GPU hardware acceleration

sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

echo "=========================================="
echo "Belt Control System v3.5"
echo "Ubuntu 24.04 | XCB + Mali GPU acceleration"
echo "Data persistence enabled"
echo "=========================================="
echo ""

# Create persistent data directory if not exists (unified appdata)
mkdir -p /home/linaro/belt-control-data/appdata
mkdir -p /home/linaro/belt-control-data/audio

# Ensure X11 access
export DISPLAY=:0
xhost +local:docker 2>/dev/null || echo "⚠️ X11 not available"

echo "Starting application with Mali GPU hardware acceleration..."
echo "Qt Platform: xcb"
echo "GPU: Mali Valhall G610"

sudo docker run \
    --name belt-control-app \
    --privileged \
    --ipc=host \
    --net=host \
    -e DISPLAY=:0 \
    -e QT_QPA_PLATFORM=xcb \
    -e QT_XCB_GL_INTEGRATION=xcb_egl \
    -e LIBGL_ALWAYS_SOFTWARE=0 \
    -e LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu/mali:/app/lib:/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu \
    -e XDG_RUNTIME_DIR=/tmp \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v /dev:/dev \
    -v /dev/dri:/dev/dri \
    -v /sys:/sys \
    -v /run/udev:/run/udev:ro \
    -v /usr/share/fonts:/usr/share/fonts:ro \
    -v /usr/lib/aarch64-linux-gnu/mali:/usr/lib/aarch64-linux-gnu/mali:ro \
    -v /usr/lib/aarch64-linux-gnu/libmali.so.1:/usr/lib/aarch64-linux-gnu/libmali.so.1:ro \
    -v /usr/lib/aarch64-linux-gnu/libmali-hook.so.1:/usr/lib/aarch64-linux-gnu/libmali-hook.so.1:ro \
    -v /usr/lib/aarch64-linux-gnu/pulseaudio/libpulsecommon-13.99.so:/usr/lib/aarch64-linux-gnu/pulseaudio/libpulsecommon-13.99.so:ro \
    -v /etc/ld.so.conf.d/00-aarch64-mali.conf:/etc/ld.so.conf.d/00-aarch64-mali.conf:ro \
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
