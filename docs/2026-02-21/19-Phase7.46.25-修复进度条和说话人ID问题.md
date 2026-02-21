# Phase 7.46.25 - 修复进度条和说话人ID问题

**时间**: 2026-02-21 22:10
**问题**:
1. 初始化进度条没有显示在界面上
2. 4个模型的说话人ID都不对（都是 0-0）

**状态**: 🔧 调试中

## 问题1：初始化进度条没有显示

### 现象
从日志可以看到：
```
[DEBUG] ⏳ [PaddleSpeech] "正在加载 PaddleSpeech 模型... 1% (10/600 秒)"
[DEBUG] ⏳ [PaddleSpeech] "正在加载 PaddleSpeech 模型... 3% (20/600 秒)"
[DEBUG] ⏳ [PaddleSpeech] "正在加载 PaddleSpeech 模型... 6% (40/600 秒)"
```

进度信息只在日志中输出，但界面上没有显示进度条。

### 原因分析
1. **C++ 端发出了信号**：
   - PaddleSpeechAdapter 在初始化时发出 `initializationProgress` 信号
   - 代码位置：[PaddleSpeechAdapter.cpp:87](src/control/tts/PaddleSpeechAdapter.cpp#L87)

2. **QML 端没有连接信号**：
   - TTSConfigSection.qml 没有连接 `initializationProgress` 信号
   - 所以进度信息无法显示在界面上

### 解决方案
在 QML 界面添加进度条，并连接 `initializationProgress` 信号。

## 问题2：说话人ID范围不正确

### 现象
从日志可以看到：
```
[DEBUG] ✅ 说话人ID范围已更新: 0 - 0
```

所有模型的说话人ID范围都是 0-0，但正确的应该是：
- fastspeech2_csmsc: 0-0（单说话人）✅
- fastspeech2_aishell3: 0-173（174个说话人）❌
- fastspeech2_ljspeech: 0-0（单说话人）✅
- fastspeech2_vctk: 0-107（108个说话人）❌

### 原因分析

需要检查以下几个地方：

1. **PaddleSpeechAdapter::getMaxSpeakerId 实现**：
   ```cpp
   int PaddleSpeechAdapter::getMaxSpeakerId(int modelIndex) const
   {
       QStringList models = QStringList()
           << "fastspeech2_csmsc"
           << "fastspeech2_aishell3"
           << "fastspeech2_ljspeech"
           << "fastspeech2_vctk";

       if (modelIndex < 0 || modelIndex >= models.size()) {
           return 0;
       }

       QString modelName = models[modelIndex];
       return MODEL_SPEAKER_COUNTS.value(modelName, 0);
   }
   ```

2. **MODEL_SPEAKER_COUNTS 定义**：
   ```cpp
   const QMap<QString, int> PaddleSpeechAdapter::MODEL_SPEAKER_COUNTS = {
       {"fastspeech2_csmsc", 0},       // 单说话人（女声）
       {"fastspeech2_aishell3", 173},  // 174 个说话人
       {"fastspeech2_ljspeech", 0},    // 单说话人（英文女声）
       {"fastspeech2_vctk", 107}       // 108 个说话人（英文）
   };
   ```

3. **QML 调用时机**：
   ```javascript
   onCurrentIndexChanged: {
       var success = commonControl.switchTTSModel(currentIndex)
       if (success) {
           // 更新说话人ID范围
           updateSpeakerIdRange()
       }
   }
   ```

### 可能的原因

1. **引擎切换时机问题**：
   - 当 QML 调用 `updateSpeakerIdRange()` 时，后端可能还没有切换到 PaddleSpeech 引擎
   - 所以调用的是旧引擎（Sherpa-ONNX）的 `getMaxSpeakerId` 方法
   - Sherpa-ONNX 的所有模型都是单说话人，所以返回 0

2. **modelIndex 传递错误**：
   - QML 传递的 `modelComboBox.currentIndex` 可能不正确
   - 或者索引超出范围

3. **静态成员初始化问题**：
   - MODEL_SPEAKER_COUNTS 可能没有正确初始化

## 调试方案

### 已添加的调试日志

1. **CommonControl::getMaxSpeakerId**：
   ```cpp
   qDebug() << "🔍 [CommonControl] getMaxSpeakerId - 模型索引:" << modelIndex
            << "当前引擎:" << m_ttsEngineManager->currentEngine();
   int maxSpeakerId = m_ttsEngineManager->getMaxSpeakerId(modelIndex);
   qDebug() << "   返回最大说话人ID:" << maxSpeakerId;
   ```

2. **PaddleSpeechAdapter::getMaxSpeakerId**：
   ```cpp
   qDebug() << "🔍 [PaddleSpeech] getMaxSpeakerId - 模型索引:" << modelIndex;
   QString modelName = models[modelIndex];
   int maxSpeakerId = MODEL_SPEAKER_COUNTS.value(modelName, 0);
   qDebug() << "   模型名称:" << modelName;
   qDebug() << "   最大说话人ID:" << maxSpeakerId;
   qDebug() << "   MODEL_SPEAKER_COUNTS 内容:" << MODEL_SPEAKER_COUNTS;
   ```

### 下一步

1. 重新编译并部署到设备
2. 测试模型切换功能
3. 查看调试日志，确认：
   - 调用 `getMaxSpeakerId` 时的当前引擎
   - 传递的 modelIndex 值
   - 查找到的 modelName
   - MODEL_SPEAKER_COUNTS 的内容
4. 根据日志分析问题原因
5. 修复问题

## 修改文件

1. [src/control/CommonControl.cpp](src/control/CommonControl.cpp#L1381) - 添加调试日志
2. [src/control/tts/PaddleSpeechAdapter.cpp](src/control/tts/PaddleSpeechAdapter.cpp#L176) - 添加调试日志

