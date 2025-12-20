#!/bin/bash
# Belt Control System v3.5 - Device 188 Optimized
# Force XCB mode with GPU acceleration (EGLFS has rotation issue on 188)

sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

echo "=========================================="
echo "Belt Control System v3.5 - Device 188"
echo "Force XCB mode with GPU optimization"
echo "=========================================="
echo ""

# Create persistent data directories
mkdir -p /home/linaro/belt-control-data/appdata
mkdir -p /home/linaro/belt-control-data/audio

# Force X11/XCB configuration (Device 188 requires XCB, not EGLFS)
export DISPLAY=${DISPLAY:-:0}
echo "Using DISPLAY=$DISPLAY"

# Allow Docker to access X11
xhost +local:docker 2>/dev/null || xhost +local:root 2>/dev/null || true

echo "Starting application in XCB mode with GPU acceleration..."

sudo docker run \
    --name belt-control-app \
    --privileged \
    --ipc=host \
    --net=host \
    -e DISPLAY=$DISPLAY \
    -e QT_QPA_PLATFORM=xcb \
    -e QT_XCB_GL_INTEGRATION=xcb_egl \
    -e LIBGL_ALWAYS_SOFTWARE=0 \
    -e QT_LOGGING_RULES="qt.qpa.gl=true" \
    -e XDG_RUNTIME_DIR=/tmp \
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
    echo "Last 30 lines of logs:"
    sudo docker logs --tail 30 belt-control-app 2>&1 | grep -E "EGL|OpenGL|DRI|error|warning"
fi
