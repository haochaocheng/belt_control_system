# Phase 7.47.68-69 - 超时参数拆分 & 8模块离线语音提示

**日期**: 2026-03-02
**提交**: `待提交`
**修改文件**: `MQTTController.h/.cpp`, `MQTTAutoManager.h/.cpp`, `AudioPathMapper.h/.cpp`, `BatchAudioGenerator.h/.cpp`, `BatchSynthesisContent.qml`, `SwitchInputPage.qml`, `main.cpp`

---

## 一、需求背景

### 问题1：超时参数只有一个
当前只有"数据超时"（`m_dataTimeoutThreshold`，2秒），没有独立的 broker 连接超时参数。
运维人员无法区分：是程序没连上服务器，还是硬件模块没发数据。

### 问题2：模块离线无语音提示
8个硬件模块离线时，界面有颜色变化（黄色），但无语音提醒。
工业现场监控人员可能不在屏幕前，需要语音广播。

---

## 二、Phase 7.47.68：超时参数拆分

### 两个独立参数

| 参数 | 含义 | 默认值 | 范围 | 持久化 |
|------|------|--------|------|--------|
| `m_dataTimeoutThreshold` | 硬件数据超时：N秒内无硬件状态消息则视为离线 | 2秒 | 1-60秒 | ✅ QSettings |
| `m_brokerConnectTimeout` | 连接超时：程序连接 EMQX 服务器超过N秒未成功则报警 | 30秒 | 5-120秒 | ✅ QSettings |

### MQTTController 新增 isModuleConnecting()

```cpp
// 检查模块是否处于 Connecting 状态（已调用 connectToHost 但尚未成功）
bool MQTTController::isModuleConnecting(int moduleIndex) const {
#ifdef MQTT_ENABLED
    int idx = getValidModuleIndex(moduleIndex);
    if (idx >= 0 && idx < m_clients.size() && m_clients[idx])
        return m_clients[idx]->state() == QMqttClient::Connecting;
#endif
    return false;
}
```

### MQTTAutoManager 新增 checkBrokerConnections()

```
触发条件：
  任意1个 MQTT 客户端（共8个）处于 Connecting 状态 且
  已等待时间 > m_brokerConnectTimeout（30秒）

去重策略：
  5分钟内只触发一次语音警报（m_lastBrokerAlertTime 时间戳）

重置时机：
  模块从 Connecting 变为其他状态时，重置该模块的 connectingStartTime
```

### ModuleHealthStatus 新增字段

```cpp
struct ModuleHealthStatus {
    // ... 原有字段 ...
    qint64 connectingStartTime = 0;  // 开始 Connecting 的时间戳（0=未追踪）
    bool offlineAlertSent = false;   // 模块离线语音是否已播放（防重复）
};
```

### UI 变化（SwitchInputPage.qml Row 5-6）

**修改前 Row5**：`[超时时间: | SpinBox | 模块状态指示器]`

**修改后**：
- Row5：`[数据超时: | SpinBox(1-60s) | 模块状态指示器]`（标签重命名）
- Row6：`[连接超时: | SpinBox(5-120s) | (空白)]`（新行）

---

## 三、Phase 7.47.69：8模块离线语音提示

### 新增批量合成分类：模块在线状态（moduleStatus）

| 文件名 | TTS 合成文本 | 存储路径 |
|--------|-------------|----------|
| `连接服务器失败.wav` | 连接MQTT服务器失败，请检查网络连接 | `Status/连接服务器失败.wav` |
| `开关量模块一离线.wav` | 开关量输入模块一离线，请检查设备连接 | `Status/开关量模块一离线.wav` |
| `开关量模块二离线.wav` | 开关量输入模块二离线，请检查设备连接 | `Status/开关量模块二离线.wav` |
| `模拟量模块一离线.wav` | 模拟量输入模块一离线，请检查设备连接 | `Status/模拟量模块一离线.wav` |
| `模拟量模块二离线.wav` | 模拟量输入模块二离线，请检查设备连接 | `Status/模拟量模块二离线.wav` |

### 触发逻辑

```
模块离线触发（仅一次）：
  status == "数据超时" && !offlineAlertSent
  → offlineAlertSent = true
  → emit voiceAlertRequested(AudioPathMapper::getModuleOfflinePath(moduleIndex))

模块恢复重置：
  status == "正常"
  → offlineAlertSent = false

连接服务器失败触发（5分钟去重）：
  任意模块 isModuleConnecting() == true
  && connectingStartTime > 0
  && (now - connectingStartTime) > m_brokerConnectTimeout
  && (now - m_lastBrokerAlertTime) > 300
  → m_lastBrokerAlertTime = now
  → emit voiceAlertRequested(AudioPathMapper::getBrokerConnectionFailedPath())
```

### 信号路由

```
MQTTAutoManager::voiceAlertRequested(audioPath)
    ↓ （main.cpp QObject::connect）
CommonControl::playAudio(audioPath)
    ↓
GStreamer/Qt Multimedia 播放
```

### AudioPathMapper 新增静态方法

```cpp
// 路径：{audioBaseDir}/Status/连接服务器失败.wav
static QString getBrokerConnectionFailedPath();

// 路径：{audioBaseDir}/Status/{模块名称}.wav
// moduleIndex: 0=开关量模块一, 1=开关量模块二, 2=模拟量模块一, 3=模拟量模块二
static QString getModuleOfflinePath(int moduleIndex);
```

---

## 四、与现有代码的关系

| 现有功能 | 本次修改影响 |
|---------|------------|
| Phase 7.47.65 主题过滤 | 不变，仍然只有硬件主题更新 lastDataTime |
| Phase 7.47.67 数据超时可设置 | 保留，Row5 标签改为"数据超时:" |
| Phase 7.47.66 双层状态指示器 | 不变，移到 Row5 Col2-3 |
| BatchSynthesisContent 现有9个分类 | 新增第10个"模块在线状态" |
| MqttProtectionMonitor 保护触发语音 | 不变，完全独立逻辑 |

---

## 五、验证方案

1. **编译验证**：`.\build-ubuntu24-apt.ps1 185` 无错误
2. **数据超时测试**：拔掉开关量模块电源 → 4秒内状态变黄 → 语音播放"开关量模块一离线"
3. **恢复测试**：重新上电 → 语音停止重复，下次离线再次播放
4. **连接超时测试**：关闭 EMQX 服务 → 30秒后语音播放"连接服务器失败"
5. **去重测试**：连续触发 → 5分钟内只播放一次"连接服务器失败"
6. **批量合成测试**：勾选"模块在线状态" → 生成5个语音文件到 `Status/` 目录
