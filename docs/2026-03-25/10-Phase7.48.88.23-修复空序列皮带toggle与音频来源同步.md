# Phase 7.48.88.23 - 修复空序列皮带toggle与音频来源同步

## 日期
2026-03-25

## 问题描述

### 问题1：皮带预警音频来源不正确
用户在界面中设置皮带预警音频来源为TTS合成，但实际播放时使用的是默认预制音频文件。

**根本原因**：
- `SystemConfig.m_beltAudioSource` 默认值为 0（预制音频），从 `config.ini` 加载
- QML `BasicConfigPage` 默认值为 1（TTS），用户在界面保存后写入 SQLite
- 启动同步代码（Phase 7.48.88.19）只同步了 `machineNumber` 和 `localDeviceName`，**遗漏了 `beltAudioSource`**
- 结果：C++ 层 `beltAudioSource()` 返回 0 → `getAudioPath()` 走预制音频路径

### 问题2：4-8号皮带数字键toggle始终为启动
按1-3可正常启停切换，但按4-8始终执行启动操作，无法停止。

**根本原因**：
- 4-8号皮带在数据库中**未配置启动序列**（`startup_sequence` 为空）
- `startDeviceSequence()` 检测到序列为空后直接 `return`，**跳过了 `m_beltRunning[N] = true`**
- `isBeltRunning(N)` 始终返回 `false` → QML toggle 永远走 `startBelt`
- 同理 `stopDeviceSequence()` 序列为空时跳过 `m_beltRunning[N] = false`

## 修复方案

### 修复1：启动时同步 beltAudioSource（main.cpp）
在 Phase 7.48.88.19 的启动同步代码中，增加 `beltAudioSource` 从 SQLite 同步到 SystemConfig。

### 修复2：空序列时仍更新运行状态（CommonControl.cpp）
- `startDeviceSequence()`：序列为空时设置 `m_beltRunning[N] = true` + 发出 `beltRunningChanged` 信号
- `stopDeviceSequence()`：序列为空时设置 `m_beltRunning[N] = false` + 发出 `beltRunningChanged` 信号

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/main/main.cpp` | 启动同步增加 beltAudioSource |
| `src/control/CommonControl.cpp` | startDeviceSequence/stopDeviceSequence 空序列时更新 m_beltRunning |

## 验证方法
1. 设置音频来源为TTS → 重启 → 确认日志显示"使用TTS音频"
2. 4-8号皮带按键启动 → 再按一次 → 确认播放停车音频并标记为停止
3. 1-3号皮带正常启停不受影响
