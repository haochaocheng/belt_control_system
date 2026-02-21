# Phase 7.46.26 - 修复两个问题：重复添加语言后缀 + 进度条显示

**时间**: 2026-02-21 22:55
**问题**:
1. PaddleSpeech 合成失败，模型名称重复添加语言后缀
2. 初始化进度条没有显示在界面上

**状态**: ✅ 已修复

## 问题1：重复添加语言后缀

### 错误信息
从日志第677行可以看到：
```
❌ 合成失败: Can't find "fastspeech2_csmsc-zh-zh" in resource.
Model name must be one of ['fastspeech2_csmsc-zh', ...]
```

### 根本原因

**模型名称重复添加了 `-zh` 后缀**：
- 应该是：`fastspeech2_csmsc-zh`
- 实际是：`fastspeech2_csmsc-zh-zh`（多了一个 `-zh`）

**为什么会重复？**

在 `synthesize_speech` 函数中，我们的逻辑是：
```python
if 'csmsc' in current_model:
    am_name = f"{current_model}-zh"  # 添加 -zh 后缀
```

如果 `current_model` 已经是 `fastspeech2_csmsc-zh`（包含后缀），它仍然包含 `'csmsc'`，所以会再次添加 `-zh`。

### 解决方案

在添加后缀之前，先检查 `current_model` 是否已经包含了语言后缀。

**文件**: `docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py`

```python
# ✅ 2026-02-21 22:30: 修复重复添加语言后缀的问题
# 检查是否已经包含语言后缀
if current_model.endswith('-zh') or current_model.endswith('-en') or current_model.endswith('-mix') or current_model.endswith('-canton'):
    # 已经包含后缀，直接使用
    am_name = current_model
    logger.info(f"📝 模型名称已包含语言后缀: {am_name}")
else:
    # 根据模型名称确定语言和添加后缀
    if 'csmsc' in current_model or 'aishell3' in current_model:
        am_name = f"{current_model}-zh"
    elif 'canton' in current_model:
        am_name = f"{current_model}-canton"
    elif 'ljspeech' in current_model or 'vctk' in current_model:
        am_name = f"{current_model}-en"
    elif 'mix' in current_model:
        am_name = f"{current_model}-mix"
    else:
        am_name = f"{current_model}-zh"
    logger.info(f"📝 添加语言后缀: {current_model} → {am_name}")
```

## 问题2：进度条没有显示

### 现象
从日志可以看到：
```
[DEBUG] ⏳ [PaddleSpeech] "正在加载 PaddleSpeech 模型... 1% (10/600 秒)"
[DEBUG] ⏳ [PaddleSpeech] "正在加载 PaddleSpeech 模型... 3% (20/600 秒)"
```

进度信息只在日志中输出，界面上没有显示。

### 根本原因

1. **C++ 端发出了信号**：PaddleSpeechAdapter → TTSEngineManager → `initializationProgress` 信号
2. **CommonControl 没有转发信号**：TTSEngineManager 的信号没有转发到 QML
3. **QML 端没有连接信号**：TTSConfigSection.qml 没有监听进度信号

### 解决方案

#### 1. 添加 QML 进度条组件

**文件**: `src/qml/components/voice_management/TTSConfigSection.qml`

在引擎状态指示器下方添加进度条：
```qml
// ✅ 2026-02-21 22:40: 添加初始化进度条
ColumnLayout {
    id: initProgressContainer
    Layout.fillWidth: true
    spacing: 5
    visible: false  // 默认隐藏

    Text {
        id: initProgressText
        text: "正在初始化..."
        font.pixelSize: 12
        color: "#00d4ff"
    }

    ProgressBar {
        id: initProgressBar
        Layout.fillWidth: true
        Layout.preferredHeight: 8
        from: 0
        to: 100
        value: 0
        // ... 样式定义
    }
}
```

#### 2. 添加 CommonControl 信号

**文件**: `src/control/CommonControl.h`

```cpp
signals:
    // ✅ 2026-02-21 22:45: 添加 TTS 初始化进度信号
    void ttsInitializationProgress(const QString &message);
```

#### 3. 连接信号转发

**文件**: `src/control/CommonControl.cpp`

在构造函数中：
```cpp
// ✅ 2026-02-21 22:50: 连接 TTS 初始化进度信号
connect(m_ttsEngineManager, &TTSEngineManager::initializationProgress,
        this, &CommonControl::ttsInitializationProgress);
```

#### 4. QML 监听信号

**文件**: `src/qml/components/voice_management/TTSConfigSection.qml`

```qml
// ✅ 2026-02-21 22:55: 连接 TTS 初始化进度信号
Connections {
    target: commonControl

    function onTtsInitializationProgress(message) {
        // 显示进度条
        initProgressContainer.visible = true
        // 更新进度文本
        initProgressText.text = message
        // 解析进度百分比
        var percentMatch = message.match(/(\d+)%/)
        if (percentMatch) {
            initProgressBar.value = parseInt(percentMatch[1])
        }
        // 初始化完成后隐藏进度条
        if (message.includes("初始化完成")) {
            hideProgressTimer.start()
        }
    }
}
```

## 说话人ID问题（已验证正常）

从调试日志（第657-662行）可以看到：
```
[DEBUG] 🔍 [CommonControl] getMaxSpeakerId - 模型索引: 0 当前引擎: "PaddleSpeech"
[DEBUG] 🔍 [PaddleSpeech] getMaxSpeakerId - 模型索引: 0
[DEBUG]    模型名称: "fastspeech2_csmsc"
[DEBUG]    最大说话人ID: 0
[DEBUG]    MODEL_SPEAKER_COUNTS 内容: QMap(("fastspeech2_aishell3", 173)("fastspeech2_csmsc", 0)("fastspeech2_ljspeech", 0)("fastspeech2_vctk", 107))
```

**说话人ID功能正常**：
- ✅ 当前引擎是 PaddleSpeech
- ✅ 模型索引 0 对应 `fastspeech2_csmsc`
- ✅ MODEL_SPEAKER_COUNTS 包含正确的数据
- ✅ 返回的最大说话人ID是 0（正确，因为 fastspeech2_csmsc 是单说话人模型）

**其他模型的说话人ID**：
- fastspeech2_csmsc (索引0): 0-0 ✅
- fastspeech2_aishell3 (索引1): 0-173 ✅
- fastspeech2_ljspeech (索引2): 0-0 ✅
- fastspeech2_vctk (索引3): 0-107 ✅

## 修改文件

1. [docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py](docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py#L95) - 修复重复添加语言后缀
2. [src/qml/components/voice_management/TTSConfigSection.qml](src/qml/components/voice_management/TTSConfigSection.qml#L163) - 添加进度条组件
3. [src/control/CommonControl.h](src/control/CommonControl.h#L165) - 添加进度信号
4. [src/control/CommonControl.cpp](src/control/CommonControl.cpp#L217) - 连接信号转发
5. [src/qml/components/voice_management/TTSConfigSection.qml](src/qml/components/voice_management/TTSConfigSection.qml#L666) - 监听进度信号

## 预期效果

修复后：
1. ✅ 模型名称不会重复添加后缀：`fastspeech2_csmsc` → `fastspeech2_csmsc-zh`
2. ✅ TTS 合成成功
3. ✅ 初始化时显示进度条和百分比
4. ✅ 初始化完成后自动隐藏进度条
5. ✅ 说话人ID范围正确显示

## 下一步

1. 重新构建 Docker 镜像
2. 部署到设备测试
3. 验证 TTS 合成功能
4. 验证进度条显示
5. 测试其他模型的说话人ID范围

