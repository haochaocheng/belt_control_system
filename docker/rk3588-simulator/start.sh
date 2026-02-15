#!/bin/bash

echo "========================================="
echo "  RK3588 模拟环境启动中..."
echo "========================================="

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
echo "📝 日志位置："
echo "   应用日志: /var/log/supervisor/app.log"
echo "   错误日志: /var/log/supervisor/app_error.log"
echo ""

# 保持容器运行
tail -f /var/log/supervisor/app.log
