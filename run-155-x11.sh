#!/bin/bash
# Belt Control System v3.3 - Device 155 using X11
# Full binary with all QML fixes compiled in

# Stop and remove old container
docker stop belt-control-app 2>/dev/null
docker rm belt-control-app 2>/dev/null

echo "=========================================="
echo "Belt Control System v3.3 - Device 155"
echo "X11 Mode with Fullscreen Support"
echo "=========================================="
echo ""

# Grant X11 access to Docker
xhost +local:docker 2>/dev/null || echo "xhost not available, trying anyway..."

# Apply xrandr rotation before starting app
DISPLAY=:0 xrandr --output DSI-1 --rotate left 2>/dev/null

echo "Starting application..."

docker run \
    --name belt-control-app \
    --privileged \
    -e DISPLAY=:0 \
    -e QT_QPA_PLATFORM=xcb \
    -e XDG_RUNTIME_DIR=/tmp \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v /dev:/dev \
    -v /sys:/sys \
    -v /run/udev:/run/udev:ro \
    -v /usr/share/fonts:/usr/share/fonts:ro \
    belt-control:v3.3-fullscreen

EXIT_CODE=$?
echo ""
echo "Application exited with code: $EXIT_CODE"

# Show last logs if exited with error
if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "Last 30 lines of logs:"
    docker logs --tail 30 belt-control-app
fi
