# TTS 语音合成与保护报警功能进度分析报告

**创建时间**: 2026-02-26 13:00
**分析类型**: 功能完成度评估
**状态**: 📊 分析完成

---

## 📋 任务概述

### 目标
1. 批量合成语音文件（约 2112 个）
2. 适配 SwitchInputPage.qml、AnalogInputPage.qml 等页面
3. 实现电机、张力等保护语音播放接口
4. 测试语音文件（触发通道 → 报警 → 记录）
5. 实现实时合成与批量合成路径统一

---

## 🔍 现有功能分析

### 1. TTS 引擎状态

| 组件 | 状态 | 说明 |
|------|------|------|
| TTSEngineManager | ✅ 已实现 | 管理多引擎切换 |
| PaddleSpeechAdapter | ✅ 已实现 | PaddleSpeech 适配器 |
| BatchAudioGenerator | ✅ 已实现 | 批量生成器（Phase 7.47.3） |
| 模型路径检测 | ✅ 已修复 | Phase 7.47.8 修复路径不一致 |

### 2. 保护监控服务

| 组件 | 状态 | 说明 |
|------|------|------|
| ProtectionMonitorService | ✅ 已实现 | 监控寄存器值，检测保护触发 |
| AlarmPlaybackService | ✅ 已实现 | 播放报警音频（文件 + TTS） |
| ProtectionConfigManager | ✅ 已实现 | 管理保护配置 |

### 3. QML 页面

| 页面 | 状态 | 说明 |
|------|------|------|
| SwitchInputPage.qml | ✅ 已实现 | 8 种开关量保护配置 |
| AnalogInputPage.qml | ✅ 已实现 | 5 种模拟量保护配置 |
| VoiceManagement.qml | ✅ 已实现 | TTS 配置界面 |
| BatchSynthesisDialog.qml | ✅ 已实现 | 批量合成对话框 |

### 4. 现有音频文件

| 类别 | 数量 | 说明 |
|------|------|------|
| 皮带通讯失败 | 9 | 1-8号皮带 + 未知皮带 |
| 护网保护 | 8 | 1-8号皮带 |
| 低速打滑 | 1 | 仅2号皮带 |
| 系统提示音 | 63+ | 共计X台、搜索等 |
| **总计** | ~81 | 远少于需求的 2112 个 |

---

## ⚠️ 待完成工作

### 第一阶段：TTS 合成验证（当前）

| 任务 | 状态 | 优先级 |
|------|------|--------|
| 修复 PaddleSpeech 模型路径 | ✅ 已完成 | 高 |
| 验证 TTS 合成功能 | 🔄 待测试 | 高 |
| 批量合成功能测试 | ⏳ 待开始 | 高 |

### 第二阶段：语音文件生成

| 任务 | 状态 | 文件数 |
|------|------|--------|
| 开关量保护语音 | ⏳ 待生成 | 64 |
| 模拟量保护语音 | ⏳ 待生成 | 64 |
| 电机保护语音 | ⏳ 待生成 | 288 |
| 制动器保护语音 | ⏳ 待生成 | 96 |
| 张紧控制保护语音 | ⏳ 待生成 | 48 |
| 沿线点位保护语音 | ⏳ 待生成 | 1536 |
| 系统提示音 | ⏳ 待生成 | 16 |
| **总计** | | **2112** |

### 第三阶段：保护报警集成

| 任务 | 状态 | 说明 |
|------|------|------|
| 音频文件路径映射 | ⏳ 待实现 | 保护名称 → 音频文件路径 |
| 实时合成回退机制 | ⏳ 待实现 | 文件不存在时实时合成 |
| 报警记录功能 | ✅ 已实现 | ProtectionMonitorService |

### 第四阶段：测试验证

| 任务 | 状态 | 说明 |
|------|------|------|
| 开关量保护触发测试 | ⏳ 待测试 | 8 种保护 |
| 模拟量保护触发测试 | ⏳ 待测试 | 5 种保护 |
| 电机保护触发测试 | ⏳ 待测试 | 9 种保护 |
| 报警记录验证 | ⏳ 待测试 | 检查日志记录 |


---

## 📊 关键代码分析

### 1. 保护触发流程

```
寄存器值变化 → ProtectionMonitorService.onRegisterValueReceived()
    ↓
检测保护条件 → checkDigitalProtection() / checkAnalogProtection()
    ↓
触发报警 → emit alarmTriggered(protectionName, ttsText, audioFile, ...)
    ↓
播放服务 → AlarmPlaybackService.onAlarmTriggered()
    ↓
播放音频 → playAudioFile() 或 playTtsText()
```

### 2. 音频文件路径规则

**现有结构**：
```
AUDIO/
├── 1#PD/           # 1号皮带
│   ├── 1号皮带通讯失败.wav
│   └── 护网.wav
├── 2#PD/           # 2号皮带
│   ├── 2号皮带通讯失败.wav
│   ├── 2号皮带低速打滑.wav
│   └── 护网.wav
└── Sounds/         # 系统提示音
    ├── 共计1台.wav
    └── ...
```

**建议结构**（与批量合成统一）：
```
AUDIO/
├── protection/     # 保护语音
│   ├── switch/     # 开关量保护
│   │   ├── 1号皮带沿线急停保护.wav
│   │   └── ...
│   ├── analog/     # 模拟量保护
│   │   ├── 1号皮带速度超速保护.wav
│   │   └── ...
│   ├── motor/      # 电机保护
│   │   ├── 1号皮带1号电机电流过载保护.wav
│   │   └── ...
│   └── tension/    # 张紧保护
│       └── ...
└── system/         # 系统提示音
    └── ...
```

### 3. 实时合成与批量合成统一

**方案**：
1. AlarmPlaybackService 优先查找预生成的音频文件
2. 如果文件不存在，调用 TTS 实时合成
3. 实时合成的文件保存到相同路径，下次直接使用

```cpp
// AlarmPlaybackService.cpp 伪代码
void AlarmPlaybackService::playAlarm(const QString &audioFile, const QString &ttsText) {
    if (QFile::exists(audioFile)) {
        // 使用预生成的音频文件
        playAudioFile(audioFile);
    } else {
        // 实时合成并保存
        QString generatedFile = synthesizeAndSave(ttsText, audioFile);
        playAudioFile(generatedFile);
    }
}
```

---

## 🎯 执行计划

### 今晚（夜间批量合成）

1. **验证 TTS 合成** - 确认 Phase 7.47.8 修复有效
2. **启动批量合成** - 生成 2112 个语音文件
3. **预计耗时** - 约 2-3 秒/文件 × 2112 = 约 2 小时

### 明天

1. **同步音频文件** - 将生成的文件同步到设备
2. **实现路径映射** - 保护名称 → 音频文件路径
3. **实现回退机制** - 文件不存在时实时合成
4. **测试验证** - 触发各类保护，验证语音播放

---

## 📁 相关文件

| 文件 | 说明 |
|------|------|
| `docs/2026-02-24/01-TTS语音文件批量生成清单.md` | 完整的语音文件清单 |
| `src/control/AlarmPlaybackService.cpp` | 报警播放服务 |
| `src/control/ProtectionMonitorService.cpp` | 保护监控服务 |
| `src/control/BatchAudioGenerator.cpp` | 批量音频生成器 |
| `src/qml/pages/VoiceManagement.qml` | 语音管理界面 |
| `src/qml/components/device_info/pages/SwitchInputPage.qml` | 开关量保护配置 |
| `src/qml/components/device_info/pages/AnalogInputPage.qml` | 模拟量保护配置 |

---

**文档版本**: v1.0
**最后更新**: 2026-02-26 13:00
