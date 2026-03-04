# Phase 7.47.95 - 连接播放方式参数到后端 AlarmPlaybackService

## 日期
2026-03-04 21:00

## 问题描述
Phase 7.47.94 添加了"播放方式"UI 和数据库字段，但保护触发时实际只播放一遍。

**根因**：`MqttProtectionMonitor` 触发保护时直接调用 `CommonControl::playAudio(audioPath)`
— 只播放一次音频文件，完全没有使用已实现的 `AlarmPlaybackService`（支持按次数/按时长）。

## 调用链（修复前）
```
MqttProtectionMonitor::onBitChanged()
  → loadDigitalProtection()  // 只读取 use_text_to_speech
  → CommonControl::playAudio(audioPath)  // ❌ 只播放一遍！
```

## 调用链（修复后）
```
MqttProtectionMonitor::onBitChanged()
  → loadDigitalProtection()  // ✅ 读取 play_mode, play_count, play_duration, tts_text
  → AlarmPlaybackService::playAlarm(name, ttsText, audioPath, useTTS,
                                     playMode, playCount, playDuration)
    → handleNextPlayback()
      → playMode == "count": 播放 playCount 次后停止
      → playMode == "duration": 持续播放 playDuration 秒后停止
```

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| src/control/MqttProtectionMonitor.h | 添加 AlarmPlaybackService 前向声明、成员变量、setter |
| src/control/MqttProtectionMonitor.cpp | 读取 play_mode/play_count/play_duration，调用 playAlarm() |
| src/main/main.cpp | 注入 alarmPlayback 到 mqttProtectionMonitor |

## 兼容性
- 如果 AlarmPlaybackService 未注入（nullptr），回退到旧的 CommonControl::playAudio() 单次播放
- 数据库中无 play_mode 字段的旧记录，默认 "count" 模式、3次

## 验证方法
1. 编译通过
2. 设备设置 → 保护参数 → 播放方式选"按次数"，次数设为3 → 触发保护 → 确认播放3次
3. 播放方式选"按时长"，时长设为5秒 → 触发保护 → 确认持续播放约5秒后停止
4. 查看日志：`📋 [MqttProtectionMonitor] 保护 xxx 播放方式: count 次数: 3 时长: 5`
