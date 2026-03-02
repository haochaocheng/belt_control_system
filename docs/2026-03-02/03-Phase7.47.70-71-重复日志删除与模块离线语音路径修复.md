# Phase 7.47.70-71 - 删除重复日志 & 修复模块离线语音路径

**日期**: 2026-03-02
**提交**: `0714bc95`（Phase 7.47.70）、`21dcc23b`（Phase 7.47.71）
**修改文件**: `MQTTAutoManager.cpp`, `AudioPathMapper.cpp`, `BatchAudioGenerator.cpp`

---

## 一、Phase 7.47.70：删除高频重复日志

### 问题

`onModuleMessageReceived()` 中的调试日志对**每一条 MQTT 消息**都打印一行，导致日志文件快速增长：

```
[DEBUG] 📩 [MQTTAutoManager] 模块 0 消息到达 | 主题: 'device/status/1' | 大小: 171 bytes | 更新健康状态: ❌否(VoIP/其他)
[DEBUG] 📩 [MQTTAutoManager] 模块 0 消息到达 | 主题: 'belt_control/di/module1/status' | 大小: 126 bytes | 更新健康状态: ✅是
```

**触发频率**：
- DI 轮询 100ms → 每秒 10 次
- AI 轮询 500ms → 每秒 2 次
- VoIP 心跳 → 持续叠加

### 修复

**文件**: `src/mqtt/MQTTAutoManager.cpp`

```cpp
// ✅ 2026-03-02 [Phase 7.47.70]: 注释掉高频调试日志（每条MQTT消息都打印，日志爆炸）
// qDebug() << "📩 [MQTTAutoManager] 模块" << moduleIndex
//          << "消息到达 | 主题:" << topic
//          << "| 大小:" << payload.size() << "bytes"
//          << "| 更新健康状态:" << (isHardwareTopic ? "✅是" : "❌否(VoIP/其他)");
```

同步检查结果：`MQTTController.cpp`、`DIDataManager.cpp`、`AIDataManager.cpp` 中的同类日志在之前版本（Phase 7.47.13/16）已删除，无重复。

---

## 二、Phase 7.47.71：修复模块离线语音路径不一致

### 问题根因

Phase 7.47.69 实现的两个静态方法路径与 BatchAudioGenerator 生成路径不一致：

| | 路径 |
|---|---|
| **BatchAudioGenerator 生成路径** | `{audioBaseDir}/{engine}-{model}-spk{id}/Status/{name}.wav` |
| **AudioPathMapper 查找路径（修复前）** | `{audioBaseDir}/Status/{name}.wav` |

缺少引擎子目录，`CommonControl::playAudio()` 内部调用 `QFile::exists()` 失败，**静默返回不播放**。

### 错误修复过程（已还原）

第一次尝试：将 `BatchAudioGenerator` 输出路径改为不含引擎子目录
→ **错误**：不同引擎/模型/说话人应产生不同语音文件，必须保留引擎子目录
→ 已还原

### 正确修复

**修改文件**: `src/control/AudioPathMapper.cpp`

新增辅助函数，读取 `TTSConfigManager::Test` 场景的当前配置，构造与 QML 端 `outputFolder` 完全一致的引擎子目录名：

```cpp
static QString buildStatusEngineFolder()
{
    TTSConfigManager *config = TTSConfigManager::instance();
    int modelIndex = config->modelIndex(TTSConfigManager::Test);
    QString modelName = config->modelName(modelIndex);
    int speakerId = config->speakerId(TTSConfigManager::Test);
    return QString("paddlespeech-%1-spk%2").arg(modelName).arg(speakerId);
}
```

路径构造与 `BatchSynthesisContent.qml` 的 `outputFolder` 逻辑一致：

```qml
// QML 端（BatchSynthesisContent.qml 第801行）
outputFolder: "paddlespeech-" + TTSConfig.modelName(TTSConfig.modelIndex(TTSConfig.Test))
              + "-spk" + TTSConfig.speakerId(TTSConfig.Test)
```

修复后两个方法：

```cpp
QString AudioPathMapper::getBrokerConnectionFailedPath()
{
    QString engineFolder = buildStatusEngineFolder();
    return DataPathConfig::getAudioBaseDirectory() + "/" + engineFolder + "/Status/连接服务器失败.wav";
}

QString AudioPathMapper::getModuleOfflinePath(int moduleIndex)
{
    // ... 越界判断 ...
    QString engineFolder = buildStatusEngineFolder();
    return DataPathConfig::getAudioBaseDirectory() + "/" + engineFolder + "/Status/" + NAMES[moduleIndex] + ".wav";
}
```

### 修复后路径对比

| | 路径示例（fastspeech2_csmsc, spk0） |
|---|---|
| BatchAudioGenerator 生成 | `/home/linaro/belt-control-data/audio/paddlespeech-fastspeech2_csmsc-spk0/Status/开关量模块一离线.wav` |
| AudioPathMapper 查找（修复后） | `/home/linaro/belt-control-data/audio/paddlespeech-fastspeech2_csmsc-spk0/Status/开关量模块一离线.wav` ✅ |

---

## 三、验证方案

1. `.\build-ubuntu24-apt.ps1 185` 重新编译部署
2. 在语音管理界面勾选"模块在线状态" → 重新批量合成（生成5个 `.wav` 到正确路径）
3. 断开开关量模块电源 → 等待约 6 秒（2秒超时 × 3次计数）→ 验证语音播放
4. 重新接通电源 → 确认语音不再重复（`offlineAlertSent` 重置）

---

## 四、文件修改清单

| 文件 | 修改内容 |
|------|---------|
| `src/mqtt/MQTTAutoManager.cpp` | 注释掉 `onModuleMessageReceived` 中的高频 qDebug 日志（4行）|
| `src/control/AudioPathMapper.cpp` | 新增 `buildStatusEngineFolder()` 辅助函数；修复 `getBrokerConnectionFailedPath()` 和 `getModuleOfflinePath()` 路径 |
| `src/control/BatchAudioGenerator.cpp` | 还原 `engine.outputFolder` 子目录（第一次修复为错误修复，已还原）|
