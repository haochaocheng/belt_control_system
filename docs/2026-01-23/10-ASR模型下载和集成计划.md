# ASR 模型下载和集成计划

**日期**: 2026-01-23
**版本**: FIX 100.299 - Phase 5
**状态**: ⏳ 进行中

---

## 📋 概述

完成 TTS 模型下载后，现在开始 STT（Speech-to-Text）功能集成，使用 Sherpa-ONNX ASR 模型实现语音识别。

---

## 🎤 ASR 模型选择

### 官方推荐模型

| 模型名称 | 类型 | 大小 | 语言 | 特点 | 推荐度 |
|---------|------|------|------|------|--------|
| **sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20** | 流式 | ~200MB | 中英双语 | 实时识别，中英混合 | ⭐⭐⭐⭐⭐ |
| **sherpa-onnx-conformer-zh-stateless2-2023-05-23** | 流式 | ~150MB | 纯中文 | 准确度高 | ⭐⭐⭐⭐ |
| **sherpa-onnx-paraformer-zh-2023-03-28** | 非流式 | ~220MB | 纯中文 | 离线识别，高准确度 | ⭐⭐⭐⭐ |

### 推荐方案

**优先使用**: `sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20`

**原因**:
1. ✅ 支持中英文混合识别（适合工业场景）
2. ✅ 流式识别，适合实时场景
3. ✅ 模型较新（2023-02），准确度高
4. ✅ 与 TTS 模型配套使用

---

## 📥 下载步骤

### 1. 执行下载脚本

```powershell
.\scripts\2026-01-23\download-asr-models.ps1
```

### 2. 脚本功能

- ✅ 自动下载 3 个推荐 ASR 模型
- ✅ 自动解压到 `libs/asr_models/`
- ✅ 自动清理压缩包
- ✅ 支持断点续传（已存在则跳过）
- ✅ 双重下载方法（curl + Invoke-WebRequest）

### 3. 预期结果

下载完成后，目录结构：

```
libs/asr_models/
├── sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20/
│   ├── encoder-epoch-99-avg-1.onnx
│   ├── decoder-epoch-99-avg-1.onnx
│   ├── joiner-epoch-99-avg-1.onnx
│   ├── tokens.txt
│   └── ...
├── sherpa-onnx-conformer-zh-stateless2-2023-05-23/
│   └── ...
└── sherpa-onnx-paraformer-zh-2023-03-28/
    └── ...
```

---

## 🔧 集成计划

### Phase 5.1: 创建 SherpaOnnxASR 类

**文件**: `src/control/SherpaOnnxASR.h` / `SherpaOnnxASR.cpp`

**功能**:
```cpp
class SherpaOnnxASR : public QObject {
    Q_OBJECT
public:
    // 初始化 ASR 引擎
    bool initialize(const QString& modelPath);

    // 识别音频文件
    QString recognizeFile(const QString& audioPath);

    // 流式识别（实时）
    void startStreaming();
    void feedAudio(const QByteArray& audioData);
    QString getPartialResult();
    QString getFinalResult();
    void stopStreaming();

signals:
    void recognitionStarted();
    void partialResultReady(const QString& text);
    void finalResultReady(const QString& text);
    void recognitionError(const QString& error);
};
```

### Phase 5.2: 集成到 AudioManagementController

**修改**: `src/control/AudioManagementController.cpp`

**当前占位实现**:
```cpp
QString AudioManagementController::recognizeAudio(const QString& audioPath) {
    // TODO: 实现真实的语音识别
    return "识别结果占位符";
}
```

**替换为真实实现**:
```cpp
QString AudioManagementController::recognizeAudio(const QString& audioPath) {
    if (!m_asr) {
        qWarning() << "ASR 引擎未初始化";
        return "";
    }

    QString result = m_asr->recognizeFile(audioPath);
    return result;
}
```

### Phase 5.3: 添加 ASR 配置管理

**类似 TTSConfigManager**，创建 `ASRConfigManager`:

```cpp
class ASRConfigManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(int modelIndex READ modelIndex WRITE setModelIndex NOTIFY modelIndexChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)

public:
    enum ModelType {
        BilingualZhEn,    // 中英双语
        ChineseOnly,      // 纯中文
        Paraformer        // 离线识别
    };
    Q_ENUM(ModelType)

    // 单例模式
    static ASRConfigManager* instance();

    // 模型选择
    int modelIndex() const;
    void setModelIndex(int index);

    // 语言设置
    QString language() const;
    void setLanguage(const QString& lang);

signals:
    void modelIndexChanged();
    void languageChanged();
};
```

### Phase 5.4: UI 集成

**添加 ASR 配置区域到 VoiceManagement.qml**:

```qml
// ASR 配置区域
ColumnLayout {
    Text {
        text: "🎤 ASR 模型配置"
        font.pixelSize: 18
        font.bold: true
        color: "#00d4ff"
    }

    ComboBox {
        model: [
            "中英双语 (推荐)",
            "纯中文",
            "离线识别"
        ]
        onCurrentIndexChanged: {
            ASRConfig.setModelIndex(currentIndex)
        }
    }
}
```

---

## 📝 实施步骤

### Step 1: 下载 ASR 模型 ⏳

```powershell
.\scripts\2026-01-23\download-asr-models.ps1
```

**预计时间**: 5-10 分钟（取决于网络速度）

### Step 2: 创建 SherpaOnnxASR 类

**文件**:
- `src/control/SherpaOnnxASR.h`
- `src/control/SherpaOnnxASR.cpp`

**参考**: `SherpaOnnxTTS` 类的实现

### Step 3: 创建 ASRConfigManager 类

**文件**:
- `src/control/ASRConfigManager.h`
- `src/control/ASRConfigManager.cpp`

**参考**: `TTSConfigManager` 类的实现

### Step 4: 集成到 AudioManagementController

**修改**:
- `src/control/AudioManagementController.h` - 添加 ASR 引擎成员
- `src/control/AudioManagementController.cpp` - 实现真实识别

### Step 5: 注册到 QML

**修改**: `src/main/main.cpp`

```cpp
// 注册 ASRConfigManager 为 QML 单例
qmlRegisterSingletonType<ASRConfigManager>("com.belt.control", 1, 0, "ASRConfig",
    [](QQmlEngine *engine, QJSEngine *scriptEngine) -> QObject * {
        Q_UNUSED(engine)
        Q_UNUSED(scriptEngine)
        return ASRConfigManager::instance();
    });
```

### Step 6: UI 集成

**修改**: `src/qml/pages/VoiceManagement.qml`

添加 ASR 配置区域

### Step 7: 测试

1. 扫描音频文件目录
2. 批量识别音频文件
3. 查看识别结果
4. 批量生成 TTS 文件

---

## 🎯 预期效果

完成后，语音管理功能将支持：

1. ✅ **TTS 模型配置** - 7 个模型可选
2. ✅ **ASR 模型配置** - 3 个模型可选
3. ✅ **音频文件扫描** - 自动扫描目录
4. ✅ **批量语音识别** - 真实 ASR 识别
5. ✅ **批量 TTS 生成** - 根据识别结果生成
6. ✅ **进度显示** - 实时进度更新

---

## 📚 相关文档

- [Phase 1 完成总结](06-FIX100.299-Phase1完成-TTS后端支持.md)
- [Phase 2 完成总结](07-FIX100.299-Phase2完成-AudioManagementController.md)
- [Phase 3 完成总结](08-FIX100.299-Phase3完成-语音管理界面QML.md)
- [Phase 4 完成总结](09-FIX100.299-Phase4完成-后端集成.md)
- [TTS 模型下载脚本](../../scripts/2026-01-23/download-tts-models.ps1)
- [ASR 模型下载脚本](../../scripts/2026-01-23/download-asr-models.ps1)

---

## 🚀 下一步操作

**立即执行**:

```powershell
# 1. 下载 ASR 模型
.\scripts\2026-01-23\download-asr-models.ps1

# 2. 等待下载完成后，开始创建 SherpaOnnxASR 类
```

**预计完成时间**: 2-3 小时（包括下载、编码、测试）
