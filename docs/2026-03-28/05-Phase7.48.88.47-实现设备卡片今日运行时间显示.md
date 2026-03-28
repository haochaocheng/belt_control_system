# Phase 7.48.88.47 - 实现设备卡片今日运行时间显示

## 日期
2026-03-28

## 问题描述

设备监控卡片底部"今日"后面始终显示"--"，运行时间功能未实现。

## 实现方案

**文件**：`src/qml/Input1/Input1Content/Screen01.qml`

1. 在 `Component.onCompleted` 初始化时从 `runtimeTracker.dailyRuntime` 读取当前值设置到本机卡片
2. 监听 `runtimeTracker.dailyRuntimeChanged` 信号实时更新（后改为Timer轮询，见Phase 7.48.88.48修复）

### 数据来源

- `DeviceRuntimeTracker` 内部有1秒定时器，运行时每秒更新 `m_dailyRuntime`（格式 HH:MM:SS）
- `startRunning()` 由电机1启动触发，`stopRunning()` 由停止/故障触发
- `m_dailySeconds` 记录累计秒数，`currentRunSeconds` 为当前运行时长

## 影响范围

- 本机卡片底部显示今日累计运行时间
- 非本机卡片保持"--"（无数据源）

## 提交
- `972801f`
