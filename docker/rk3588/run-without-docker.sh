#!/bin/bash
# Run belt_control_system without Docker

APP_DIR="/home/pi/belt-control-app"
export LD_LIBRARY_PATH="$APP_DIR/libs:/usr/local/lib:/usr/lib/aarch64-linux-gnu"
export QT_QPA_PLATFORM=eglfs
export LANG=zh_CN.UTF-8

cd "$APP_DIR"
exec ./belt_control_system "$@"
