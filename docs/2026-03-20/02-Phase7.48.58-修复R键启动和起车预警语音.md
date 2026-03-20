# Phase 7.48.58 - 修复R键启动无响应和起车预警语音

## 时间
2026-03-20

## 问题描述

测试逻辑控制面板后发现两个问题：
1. **R键无法启动**：按 R 键后日志提示 `❌ MaintenanceControl: CommonControl未设置`，设备完全无法启动
2. **起车预警无语音**：即使修复连接后，起车预警也不播放任何声音，导致 `onPlaybackFinished` 永不触发，设备序列永不执行

---

## 根本原因分析

### 问题1：R/S 键无响应

**文件**：`src/main/main.cpp`（第285-286行）

`MaintenanceControl` 和 `LocalControl` 创建后，**从未调用** `setCommonControl()` 和 `setSystemConfig()`。

```cpp
// 旧代码（有问题）
MaintenanceControl maintenanceControl(hal);
LocalControl localControl(hal);
// ← 缺少 setCommonControl / setSystemConfig 调用
```

导致 `handleStart()` / `handleStop()` 内部检查 `m_commonControl == nullptr` 直接返回。

### 问题2：起车预警无语音（设备序列卡死）

**文件**：`src/control/CommonControl.cpp`，函数 `playWarningOnce()`

2026-02-15 重构 TTS 时，旧的 `SherpaOnnxTTS` 调用被注释，**但没有替换为新的 `m_ttsEngineManager`**：

```cpp
// 旧代码（TTS 代码被注释，音频文件又不存在）
/*
if (m_tts && m_tts->state() == SherpaOnnxTTS::Ready) {
    m_tts->sayToNetwork(warningText, true);
} else
*/
if (!m_currentAudioPath.isEmpty()) {
    playAudio(m_currentAudioPath);  // 文件不存在，不播放
} else {
    qWarning() << "❌ 音频文件不可用，无法播放预警";
    // ← 既不播放，也不调用 startDeviceSequence，永远卡在这里
}
```

**连锁效应**：
- `playWarningOnce()` → 无声音 → `onPlaybackFinished()` 永不触发
- `onPlaybackFinished()` → 不调用 `startDeviceSequence()`
- → 设备序列永不执行 → 按 R 键"没有任何反应"

### 问题3：设备名称不匹配

**文件**：`src/control/CommonControl.cpp`，函数 `getDeviceChannel()`

逻辑控制面板（LogicControlPanel）使用新名称 `"张紧控制"`、`"1号制动器"`，但通道映射表只有旧名称 `"张紧"`、`"抱闸"`，导致 `getDeviceChannel()` 返回 -1，设备控制指令无法发出。

---

## 修复方案

### 修复1：main.cpp - 添加缺失连接

```cpp
// ✅ 2026-03-20 [Phase 7.48.58]
MaintenanceControl maintenanceControl(hal);
maintenanceControl.setCommonControl(&commonControl);
maintenanceControl.setSystemConfig(&systemConfig);
LocalControl localControl(hal);
localControl.setCommonControl(&commonControl);
localControl.setSystemConfig(&systemConfig);
```

### 修复2：playWarningOnce() - TTS起车预警

新逻辑（三级降级）：

```
① 优先：预制音频文件（批量生成的）
② 次选：TTS 实时合成 → 文本 = "本机名称 + 准备启动，注意安全"
③ 兜底：无音频时直接执行设备序列（保证启动不卡死）
```

TTS 文本规则：
- 有本机名称（基本参数设置中配置）：`"1号皮带准备启动，注意安全"`
- 无本机名称：`"一号皮带准备启动，注意安全"`（中文数字）

TTS 文件路径：`/tmp/startup_warning_{皮带号}.wav`（固定路径，同一次预警重复播放时直接复用，避免重复合成）

### 修复3：getDeviceChannel() - 名称别名

```cpp
// ✅ 新增逻辑控制面板设备池名称别名
{"张紧控制", 0},    // = 张紧（通道0）
{"1号制动器", 1}    // = 抱闸（通道1）
```

---

## 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `src/main/main.cpp` | 添加 MaintenanceControl/LocalControl 的 setCommonControl/setSystemConfig 调用 |
| `src/control/CommonControl.cpp` | 重写 playWarningOnce()：三级降级（预制文件→TTS→直接启动） |
| `src/control/CommonControl.cpp` | getDeviceChannel() 新增"张紧控制"和"1号制动器"别名 |

---

## 关联说明

- **起车预警文本配置位置**：参数设置 → 基本参数设置 → 本机名称
- **批量生成**：语音管理 → 批量生成 → "皮带操作状态" 可生成预制启动预警音频
- **音频优先级**：批量生成的预制文件（需放到正确目录）> TTS 实时合成 > 直接启动
