# Phase 7.47.97 - 修复 AlarmPlaybackService 未启动导致无声音

## 日期
2026-03-04 22:00

## 问题描述
Phase 7.47.95 将 `MqttProtectionMonitor` 改为通过 `AlarmPlaybackService::playAlarm()` 播放，
但运行后完全没有声音，日志反复出现：
```
❌ AlarmPlaybackService: 播放服务未启动
```

## 根因
`main.cpp` 中创建了 `AlarmPlaybackService alarmPlayback` 并注入到 `mqttProtectionMonitor`，
但**从未调用 `alarmPlayback.start()`**！

`AlarmPlaybackService::playAlarm()` 第136行检查 `m_isRunning`，未启动直接 return：
```cpp
if (!m_isRunning) {
    qWarning() << "❌ AlarmPlaybackService: 播放服务未启动";
    return;
}
```

## 修复
在 `main.cpp` 中，注入 AlarmPlaybackService 之后立即调用 `start()`：
```cpp
mqttProtectionMonitor.setAlarmPlaybackService(&alarmPlayback);
alarmPlayback.start();  // ← 修复：启动服务
```

## 修改文件

| 文件 | 修改内容 |
|------|----------|
| src/main/main.cpp | 添加 `alarmPlayback.start()` 调用 |

## 验证方法
1. 编译部署后，查看日志出现 `🚀 AlarmPlaybackService: 启动报警播放服务`
2. 触发保护后，不再出现"播放服务未启动"
3. 声音正常播放
