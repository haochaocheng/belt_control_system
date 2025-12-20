#!/bin/bash
# Belt Control System v3.5 - Device 188 Optimized (XCB with GPU acceleration)

sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

echo "=========================================="
echo "Belt Control System v3.5 - Device 188"
echo "XCB mode with GPU optimization"
echo "=========================================="
echo ""

# Create persistent data directories
mkdir -p /home/linaro/belt-control-data/appdata
mkdir -p /home/linaro/belt-control-data/audio

# Ensure X11 is accessible
export DISPLAY=:0
xhost +local:docker 2>/dev/null || true

echo "Starting application with GPU acceleration..."

sudo docker run \
    --name belt-control-app \
    --privileged \
    --ipc=host \
    -e DISPLAY=:0 \
    -e QT_QPA_PLATFORM=xcb \
    -e QT_XCB_GL_INTEGRATION=xcb_egl \
    -e LIBGL_ALWAYS_SOFTWARE=0 \
    -e MESA_LOADER_DRIVER_OVERRIDE=panfrost \
    -e XDG_RUNTIME_DIR=/tmp \
    -e QT_LOGGING_RULES="qt.qpa.*=true" \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v /dev:/dev \
    -v /dev/dri:/dev/dri \
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
    echo "Last 50 lines of logs (check for rendering issues):"
    sudo docker logs --tail 50 belt-control-app 2>&1 | grep -i "render\|egl\|opengl\|gpu"
fi
