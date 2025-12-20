#!/bin/bash
# GPU和渲染诊断脚本

echo "=========================================="
echo "GPU and Rendering Diagnostics"
echo "Device: $(hostname) - $(hostname -I | awk '{print $1}')"
echo "=========================================="
echo ""

echo "1. Display and X11 Status:"
echo "   DISPLAY: $DISPLAY"
ps aux | grep -i x11 | grep -v grep | head -3
echo ""

echo "2. DRI Devices:"
ls -l /dev/dri/
echo ""

echo "3. Mali GPU Driver:"
lsmod | grep mali
dmesg | grep -i mali | tail -5
echo ""

echo "4. OpenGL/EGL Info (from container):"
sudo docker run --rm --privileged \
    --ipc=host \
    -e DISPLAY=$DISPLAY \
    -v /dev/dri:/dev/dri \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    belt-control:v3.5-apt \
    bash -c "glxinfo 2>/dev/null | grep -i 'renderer\|version\|vendor' | head -5 || echo 'glxinfo not available'"
echo ""

echo "5. Qt Platform Plugin Status:"
sudo docker run --rm --privileged \
    --ipc=host \
    -e DISPLAY=$DISPLAY \
    -e QT_DEBUG_PLUGINS=1 \
    -e QT_QPA_PLATFORM=xcb \
    -v /dev/dri:/dev/dri \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    belt-control:v3.5-apt \
    /app/belt_control_system --help 2>&1 | grep -i "egl\|opengl\|render" | head -10
echo ""

echo "6. CPU Info:"
grep 'model name\|cpu cores' /proc/cpuinfo | head -4
echo ""

echo "7. Current CPU Usage (5 second sample):"
top -bn2 -d 5 | grep belt_control_system
echo ""

echo "=========================================="
echo "Diagnostics Complete"
echo "=========================================="
