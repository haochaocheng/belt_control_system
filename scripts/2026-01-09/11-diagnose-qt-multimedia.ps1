# ✅ 2026-01-09 17:10 检查 Qt Multimedia 配置
# 问题：添加 QT_MULTIMEDIA_PREFERRED_PLUGINS 后仍无效
# 目的：验证环境变量是否生效，以及 Qt 插件加载机制

$deviceIp = "192.168.10.188"
$userName = "linaro"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Qt Multimedia 配置诊断" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n📋 Step 1: 检查容器环境变量..." -ForegroundColor Yellow
ssh ${userName}@${deviceIp} "docker exec belt-control-app env | grep -i 'QT_MULTIMEDIA\|QT_PLUGIN'"

Write-Host "`n📋 Step 2: 检查 Qt 插件目录内容..." -ForegroundColor Yellow
ssh ${userName}@${deviceIp} "docker exec belt-control-app ls -lh /app/plugins/multimedia/"

Write-Host "`n📋 Step 3: 检查 Qt 插件元数据..." -ForegroundColor Yellow
ssh ${userName}@${deviceIp} "docker exec belt-control-app strings /app/plugins/multimedia/libgstreamermediaplugin.so | grep -i 'gstreamer\|metadata\|IID'"

Write-Host "`n📋 Step 4: 检查 Qt 调试环境变量..." -ForegroundColor Yellow
Write-Host "尝试启用 Qt 插件调试..." -ForegroundColor White
ssh ${userName}@${deviceIp} "docker exec -e QT_DEBUG_PLUGINS=1 belt-control-app env | grep QT_DEBUG"

Write-Host "`n📋 Step 5: 测试 GStreamer 命令行..." -ForegroundColor Yellow
ssh ${userName}@${deviceIp} "docker exec belt-control-app gst-launch-1.0 videotestsrc num-buffers=1 ! fakesink"

Write-Host "`n✅ 诊断完成！" -ForegroundColor Green
