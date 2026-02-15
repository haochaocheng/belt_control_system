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
sleep 8

echo ""
echo "✅ 模拟环境已启动"
echo ""
echo "📺 访问方式："
echo "   浏览器: http://localhost:6080"
echo "   VNC客户端: localhost:5901 (密码: 123456)"
echo ""

# 检查应用程序是否存在
if [ -f "/app/belt_control_system" ]; then
    echo "🚀 应用程序已找到，正在启动..."
    supervisorctl start app 2>/dev/null || echo "⚠️  应用启动失败，但VNC环境可用"
else
    echo "💡 应用程序未编译，仅VNC环境可用"
    echo "   编译后重启容器即可运行应用"
fi

echo ""
echo "📝 容器保持运行中..."
echo ""

# 保持容器运行（无限循环）
while true; do
    sleep 3600
done
