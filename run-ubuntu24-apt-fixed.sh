#!/bin/bash
# Belt Control System v3.5 - Ubuntu 24.04 apt-get Method
# Fixed version - correct variable escaping

sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

echo "=========================================="
echo "Belt Control System v3.5"
echo "Ubuntu 24.04 | apt-get native packages"
echo "Data persistence enabled"
echo "=========================================="
echo ""

# Create persistent data directory if not exists (unified appdata)
mkdir -p /home/linaro/belt-control-data/appdata
mkdir -p /home/linaro/belt-control-data/audio

# Auto-detect Qt platform based on X11 availability
if xhost +local:docker 2>/dev/null; then
    echo "✅ X11 detected - using XCB platform (windowed mode)"
    QT_PLATFORM=xcb
    DISPLAY_ARG="-e DISPLAY=:0"
    X11_VOLUME="-v /tmp/.X11-unix:/tmp/.X11-unix:rw"
else
    echo "✅ No X11 - using EGLFS platform (fullscreen mode)"
    QT_PLATFORM=eglfs
    DISPLAY_ARG=""
    X11_VOLUME=""
fi

echo "Starting application with persistent data..."
echo "Qt Platform: $QT_PLATFORM"

sudo docker run \
    --name belt-control-app \
    --privileged \
    --ipc=host \
    $DISPLAY_ARG \
    -e QT_QPA_PLATFORM=$QT_PLATFORM \
    -e XDG_RUNTIME_DIR=/tmp \
    $X11_VOLUME \
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
    sudo docker logs --tail 30 belt-control-app
fi
