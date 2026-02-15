#!/bin/bash

echo "========================================="
echo "  RK3588 模拟环境启动中..."
echo "========================================="

# 创建软链接（如果挂载目录存在）
if [ -d "/mnt/app" ]; then
    ln -sf /mnt/app/* /app/ 2>/dev/null
fi

if [ -d "/mnt/lib" ]; then
    ln -sf /mnt/lib /app/lib 2>/dev/null
fi

if [ -d "/mnt/config" ]; then
    ln -sf /mnt/config /app/config 2>/dev/null
fi

# 创建日志目录
mkdir -p /var/log/supervisor

# 启动supervisor
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf &

# 等待服务启动
sleep 5

echo ""
echo "✅ 模拟环境已启动"
echo ""
echo "📺 访问方式："
echo "   浏览器: http://localhost:6080"
echo "   VNC客户端: localhost:5901 (密码: 123456)"
echo ""

# 检查应用程序是否存在
if [ -f "/app/belt_control_system" ]; then
    echo "🚀 启动应用程序..."
    supervisorctl start app
    echo ""
    echo "📝 日志位置："
    echo "   应用日志: /var/log/supervisor/app.log"
    echo "   错误日志: /var/log/supervisor/app_error.log"
    echo ""
    # 保持容器运行
    tail -f /var/log/supervisor/app.log
else
    echo "⚠️  应用程序未找到: /app/belt_control_system"
    echo "💡 请先编译应用程序，然后重启容器"
    echo ""
    echo "📝 VNC日志位置："
    echo "   Xvfb: /var/log/supervisor/xvfb.log"
    echo "   x11vnc: /var/log/supervisor/x11vnc.log"
    echo "   noVNC: /var/log/supervisor/novnc.log"
    echo ""
    # 保持容器运行
    tail -f /var/log/supervisor/novnc.log
fi
