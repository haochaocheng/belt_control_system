# ✅ 2026-01-09 16:40 验证 GStreamer 是否安装
# 问题：Fix 96 添加了 GStreamer 包，但日志仍显示 "could not load multimedia backend"
# 目的：检查容器中 GStreamer 库是否真的安装成功

$deviceIp = "192.168.10.188"
$userName = "linaro"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "验证 GStreamer 安装（Fix 96）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n📋 Step 1: 检查 GStreamer 版本..." -ForegroundColor Yellow
ssh ${userName}@${deviceIp} "docker exec belt-control-app gst-inspect-1.0 --version"

Write-Host "`n📋 Step 2: 检查 GStreamer 库文件..." -ForegroundColor Yellow
ssh ${userName}@${deviceIp} "docker exec belt-control-app ls -l /usr/lib/aarch64-linux-gnu/libgstreamer*.so*"

Write-Host "`n📋 Step 3: 检查 Qt Multimedia 插件依赖..." -ForegroundColor Yellow
ssh ${userName}@${deviceIp} "docker exec belt-control-app ldd /app/plugins/multimedia/libgstreamermediaplugin.so | grep -E 'gst|not found'"

Write-Host "`n📋 Step 4: 检查 FFmpeg 插件依赖..." -ForegroundColor Yellow
ssh ${userName}@${deviceIp} "docker exec belt-control-app ldd /app/plugins/multimedia/libffmpegmediaplugin.so | grep -E 'avcodec|avformat|not found'"

Write-Host "`n✅ 验证完成！" -ForegroundColor Green
Write-Host "预期结果：" -ForegroundColor White
Write-Host "  - gst-inspect-1.0 应该输出版本号（1.24.x）" -ForegroundColor White
Write-Host "  - libgstreamer*.so 应该存在" -ForegroundColor White
Write-Host "  - libgstreamermediaplugin.so 所有依赖都应 found" -ForegroundColor White
Write-Host "  - libffmpegmediaplugin.so 可能仍然 not found（版本不匹配）" -ForegroundColor White
