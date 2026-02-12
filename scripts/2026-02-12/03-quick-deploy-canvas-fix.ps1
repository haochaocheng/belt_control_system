#!/usr/bin/env pwsh
# ========================================
# Phase 7.45.29 - 快速编译部署脚本
# ========================================
# 创建时间: 2026-02-12
# 用途: 快速编译并部署 Canvas 修复到设备 188
# ========================================

# UTF-8 强制配置
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Phase 7.45.29 - Canvas 修复快速部署" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n📋 修复内容:" -ForegroundColor Yellow
Write-Host "  ✅ App.qml - 背景网格 Canvas (添加 Timer)" -ForegroundColor Green
Write-Host "  ✅ IndustrialContainer.qml - 4 个装饰 Canvas (添加 Timer)" -ForegroundColor Green
Write-Host "  ✅ 所有 Canvas 添加 available 和尺寸检查" -ForegroundColor Green
Write-Host "  ✅ Input1Page.qml - 修复 SwipeView 尺寸正反馈" -ForegroundColor Green

Write-Host "`n🎯 预期效果:" -ForegroundColor Yellow
Write-Host "  ✅ QPainter 警告: 从 205,032 条减少到 0 条" -ForegroundColor Green
Write-Host "  ✅ 程序不再卡住，内存不再指数级增长" -ForegroundColor Green
Write-Host "  ✅ 界面正常显示" -ForegroundColor Green

Write-Host "`n⚠️  重要提示:" -ForegroundColor Red
Write-Host "  - 确保在正确的设备上测试（192.168.10.188）" -ForegroundColor Yellow
Write-Host "  - 编译时间约 5-10 分钟" -ForegroundColor Yellow
Write-Host "  - 部署后需要重启容器" -ForegroundColor Yellow

Write-Host "`n🚀 开始编译部署..." -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 执行编译部署
& ".\build-ubuntu24-apt.ps1" 188

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✅ 编译部署完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n📝 验证步骤:" -ForegroundColor Yellow
Write-Host "  1. SSH 到设备: ssh linaro@192.168.10.188" -ForegroundColor White
Write-Host "  2. 查看日志: tail -f /tmp/voip.log" -ForegroundColor White
Write-Host "  3. 搜索 QPainter: grep QPainter /tmp/voip.log | wc -l" -ForegroundColor White
Write-Host "  4. 应该看到: 0 (没有 QPainter 警告)" -ForegroundColor Green

Write-Host "`n🔍 调试信息:" -ForegroundColor Yellow
Write-Host "  - 不应再看到: 🔄 [Input1Page] 尺寸变化: 3937500 x 1019" -ForegroundColor White
Write-Host "  - 应该看到: xScale (宽度缩放): 0.667" -ForegroundColor White
Write-Host "  - 应该看到: yScale (高度缩放): 0.741" -ForegroundColor White

Write-Host "`n✅ 完成！" -ForegroundColor Green
