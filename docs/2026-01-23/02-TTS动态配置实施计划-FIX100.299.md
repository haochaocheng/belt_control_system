# TTS动态配置实施计划 - FIX 100.299

**日期**: 2026-01-23
**版本**: VERSION 2026-01-23-02:00
**状态**: 实施中

---

## 📋 实施概述

根据技术决策文档，实施TTS模型动态配置功能，允许用户在UI界面灵活选择和测试不同的TTS模型和参数。

**技术决策文档**: [TTS模型动态配置UI方案](../技术决策/TTS模型动态配置UI方案.md)

---

## ✅ 用户确认的方案

1. **模型预装策略**: A - 预装所有7个模型（800MB）
2. **说话人ID展示**: C - 数字输入框 + 试听按钮
3. **模型切换时机**: A - 立即切换
4. **测试文本**: B - 可编辑测试文本
5. **配置作用域**: B - 场景配置（起车预警、故障报警分别配置）

---

## 🎯 实施阶段

### Phase 1: 后端支持（C++）⏳

#### 1.1 修改 SherpaOnnxTTS 类

**文件**: `src/control/SherpaOnnxTTS.h`

**新增成员变量**:
```cpp
private:
    int m_speakerId;        // 说话人ID
    int m_maxSpeakerId;     // 当前模型最大说话人ID
    QString m_sceneName;    // 场景名称（"startup_warning"/"fault_alarm"/"test"）
```

**新增公共方法**:
```cpp
public:
    // 设置说话人ID
    void setSpeakerId(int speakerId);
    int speakerId() const { return m_speakerId; }

    // 动态切换模型
    bool switchModel(const QString &modelDir);

    // 获取当前模型信息
    QString currentModel() const { return m_modelDir; }
    int maxSpeakerId() const { return m_maxSpeakerId; }

    // 设置场景名称
    void setSceneName(const QString &sceneName);
    QString sceneName() const { return m_sceneName; }

    // 测试TTS（用于UI测试按钮）
    void testTTS(const QString &text);

signals:
    // 模型切换完成信号
    void modelSwitched(bool success, const QString &modelName);

    // 模型加载进度信号
    void modelLoadingProgress(const QString &message);
```

**修改位置**:
- Line 101-103: 在现有的 setRate/setPitch/setVolume 后面添加新方法
- Line 135-165: 在 private 区域添加新成员变量

#### 1.2 实现 SherpaOnnxTTS 方法

**文件**: `src/control/SherpaOnnxTTS.cpp`

**实现代码**:
```cpp
// ✅ 2026-01-23 02:00 [FIX 100.299] 设置说话人ID
void SherpaOnnxTTS::setSpeakerId(int speakerId)
{
    m_speakerId = qBound(0, speakerId, m_maxSpeakerId);
    qDebug() << "🎤 [TTS]" << m_sceneName << "设置说话人ID:" << m_speakerId;
}

// ✅ 2026-01-23 02:00 [FIX 100.299] 动态切换模型
bool SherpaOnnxTTS::switchModel(const QString &modelDir)
{
    qDebug() << "🔄 [TTS]" << m_sceneName << "切换模型:" << modelDir;

    emit modelLoadingProgress("正在停止当前TTS服务...");

    // 停止当前TTS服务
    if (m_ttsProcess->state() != QProcess::NotRunning) {
        stop();
        QThread::msleep(500);  // 等待进程完全停止
    }

    emit modelLoadingProgress("正在加载新模型...");

    // 重新初始化
    bool success = initialize(modelDir);

    if (success) {
        emit modelLoadingProgress("模型加载成功");
        emit modelSwitched(true, modelDir);
    } else {
        emit modelLoadingProgress("模型加载失败");
        emit modelSwitched(false, modelDir);
    }

    return success;
}

// ✅ 2026-01-23 02:00 [FIX 100.299] 设置场景名称
void SherpaOnnxTTS::setSceneName(const QString &sceneName)
{
    m_sceneName = sceneName;
    qDebug() << "🏷️  [TTS] 设置场景名称:" << m_sceneName;
}

// ✅ 2026-01-23 02:00 [FIX 100.299] 测试TTS
void SherpaOnnxTTS::testTTS(const QString &text)
{
    qDebug() << "🔊 [TTS]" << m_sceneName << "测试语音:" << text;
    say(text);
}

// ✅ 2026-01-23 02:00 [FIX 100.299] 修改 synthesize() 使用 m_speakerId
bool SherpaOnnxTTS::synthesize(const QString &text, const QString &outputPath)
{
    // ... 现有代码 ...

    // 修改这一行（原来是硬编码 0）
    synthCmd["speaker_id"] = m_speakerId;  // 使用可配置的说话人ID

    // ... 现有代码 ...
}

// ✅ 2026-01-23 02:00 [FIX 100.299] 构造函数初始化
SherpaOnnxTTS::SherpaOnnxTTS(QObject *parent)
    : QObject(parent)
    , m_speakerId(0)           // 默认说话人0
    , m_maxSpeakerId(173)      // 默认aishell3的最大值
    , m_sceneName("unknown")   // 默认场景名
    // ... 其他初始化 ...
{
    // ... 现有代码 ...
}
```

**修改位置**:
- Line 324-325: 修改 synthesize() 中的 speaker_id 设置
- Line 10-22: 修改构造函数，添加新成员变量初始化
- 文件末尾: 添加新方法实现

#### 1.3 创建 TTSConfigManager 类

**文件**: `src/control/TTSConfigManager.h`（新建）

```cpp
#ifndef TTSCONFIGMANAGER_H
#define TTSCONFIGMANAGER_H

#include <QObject>
#include <QSettings>
#include <QString>

/**
 * @brief TTS配置管理器（场景配置模式）
 *
 * 支持三种场景的独立配置：
 * 1. startup_warning - 起车预警
 * 2. fault_alarm - 故障报警
 * 3. test - 测试（参数设置界面）
 */
class TTSConfigManager : public QObject
{
    Q_OBJECT

public:
    // 场景枚举
    enum Scene {
        StartupWarning = 0,  // 起车预警
        FaultAlarm = 1,      // 故障报警
        Test = 2             // 测试
    };
    Q_ENUM(Scene)

    // 单例模式
    static TTSConfigManager* instance();

    // 加载/保存配置
    void loadConfig();
    void saveConfig();

    // 获取/设置配置（指定场景）
    int modelIndex(Scene scene) const;
    void setModelIndex(Scene scene, int index);

    QString modelPath(Scene scene) const;
    void setModelPath(Scene scene, const QString &path);

    int speakerId(Scene scene) const;
    void setSpeakerId(Scene scene, int id);

    double rate(Scene scene) const;
    void setRate(Scene scene, double rate);

    double volume(Scene scene) const;
    void setVolume(Scene scene, double volume);

    // 获取模型信息
    QString modelName(int index) const;
    int maxSpeakerId(int modelIndex) const;

signals:
    void configChanged(Scene scene);

private:
    explicit TTSConfigManager(QObject *parent = nullptr);

    QString sceneKey(Scene scene) const;

    QSettings *m_settings;

    // 场景配置缓存
    struct SceneConfig {
        int modelIndex;
        QString modelPath;
        int speakerId;
        double rate;
        double volume;
    };

    QMap<Scene, SceneConfig> m_configs;
};

#endif // TTSCONFIGMANAGER_H
```

**文件**: `src/control/TTSConfigManager.cpp`（新建）

```cpp
#include "TTSConfigManager.h"
#include <QDebug>

// 模型信息表
static const QMap<int, QString> MODEL_NAMES = {
    {0, "vits-zh-aishell3"},
    {1, "vits-zh-hf-fanchen-wnj"},
    {2, "vits-zh-hf-fanchen-C"},
    {3, "vits-zh-hf-theresa"},
    {4, "vits-zh-hf-eula"},
    {5, "sherpa-onnx-vits-zh-ll"},
    {6, "vits-melo-tts-zh_en"}
};

static const QMap<int, QString> MODEL_PATHS = {
    {0, "/app/tts_models/vits-zh-aishell3"},
    {1, "/app/tts_models/vits-zh-hf-fanchen-wnj"},
    {2, "/app/tts_models/vits-zh-hf-fanchen-C"},
    {3, "/app/tts_models/vits-zh-hf-theresa"},
    {4, "/app/tts_models/vits-zh-hf-eula"},
    {5, "/app/tts_models/sherpa-onnx-vits-zh-ll"},
    {6, "/app/tts_models/vits-melo-tts-zh_en"}
};

static const QMap<int, int> MODEL_MAX_SPEAKER_IDS = {
    {0, 173},   // aishell3: 174 speakers (0-173)
    {1, 0},     // fanchen-wnj: 1 speaker (0)
    {2, 186},   // fanchen-C: 187 speakers (0-186)
    {3, 803},   // theresa: 804 speakers (0-803)
    {4, 803},   // eula: 804 speakers (0-803)
    {5, 4},     // zh-ll: 5 speakers (0-4)
    {6, 0}      // melo-tts: 1 speaker (0)
};

TTSConfigManager* TTSConfigManager::instance()
{
    static TTSConfigManager *inst = new TTSConfigManager();
    return inst;
}

TTSConfigManager::TTSConfigManager(QObject *parent)
    : QObject(parent)
    , m_settings(new QSettings("BeltControlSystem", "TTS", this))
{
    qDebug() << "📋 [TTSConfig] 初始化TTS配置管理器";
    loadConfig();
}

void TTSConfigManager::loadConfig()
{
    qDebug() << "📂 [TTSConfig] 加载TTS配置";

    // 加载三个场景的配置
    for (int i = StartupWarning; i <= Test; ++i) {
        Scene scene = static_cast<Scene>(i);
        QString key = sceneKey(scene);

        SceneConfig config;
        config.modelIndex = m_settings->value(key + "/modelIndex", 0).toInt();
        config.modelPath = m_settings->value(key + "/modelPath", MODEL_PATHS[0]).toString();
        config.speakerId = m_settings->value(key + "/speakerId", 0).toInt();
        config.rate = m_settings->value(key + "/rate", 1.0).toDouble();
        config.volume = m_settings->value(key + "/volume", 0.8).toDouble();

        m_configs[scene] = config;

        qDebug() << "  -" << key << ": model=" << config.modelIndex
                 << ", speaker=" << config.speakerId
                 << ", rate=" << config.rate;
    }
}

void TTSConfigManager::saveConfig()
{
    qDebug() << "💾 [TTSConfig] 保存TTS配置";

    for (auto it = m_configs.begin(); it != m_configs.end(); ++it) {
        Scene scene = it.key();
        const SceneConfig &config = it.value();
        QString key = sceneKey(scene);

        m_settings->setValue(key + "/modelIndex", config.modelIndex);
        m_settings->setValue(key + "/modelPath", config.modelPath);
        m_settings->setValue(key + "/speakerId", config.speakerId);
        m_settings->setValue(key + "/rate", config.rate);
        m_settings->setValue(key + "/volume", config.volume);
    }

    m_settings->sync();
}

QString TTSConfigManager::sceneKey(Scene scene) const
{
    switch (scene) {
    case StartupWarning: return "startup_warning";
    case FaultAlarm: return "fault_alarm";
    case Test: return "test";
    default: return "unknown";
    }
}

int TTSConfigManager::modelIndex(Scene scene) const
{
    return m_configs.value(scene).modelIndex;
}

void TTSConfigManager::setModelIndex(Scene scene, int index)
{
    if (m_configs[scene].modelIndex != index) {
        m_configs[scene].modelIndex = index;
        m_configs[scene].modelPath = MODEL_PATHS[index];
        emit configChanged(scene);
    }
}

QString TTSConfigManager::modelPath(Scene scene) const
{
    return m_configs.value(scene).modelPath;
}

void TTSConfigManager::setModelPath(Scene scene, const QString &path)
{
    if (m_configs[scene].modelPath != path) {
        m_configs[scene].modelPath = path;
        emit configChanged(scene);
    }
}

int TTSConfigManager::speakerId(Scene scene) const
{
    return m_configs.value(scene).speakerId;
}

void TTSConfigManager::setSpeakerId(Scene scene, int id)
{
    if (m_configs[scene].speakerId != id) {
        m_configs[scene].speakerId = id;
        emit configChanged(scene);
    }
}

double TTSConfigManager::rate(Scene scene) const
{
    return m_configs.value(scene).rate;
}

void TTSConfigManager::setRate(Scene scene, double rate)
{
    if (m_configs[scene].rate != rate) {
        m_configs[scene].rate = rate;
        emit configChanged(scene);
    }
}

double TTSConfigManager::volume(Scene scene) const
{
    return m_configs.value(scene).volume;
}

void TTSConfigManager::setVolume(Scene scene, double volume)
{
    if (m_configs[scene].volume != volume) {
        m_configs[scene].volume = volume;
        emit configChanged(scene);
    }
}

QString TTSConfigManager::modelName(int index) const
{
    return MODEL_NAMES.value(index, "unknown");
}

int TTSConfigManager::maxSpeakerId(int modelIndex) const
{
    return MODEL_MAX_SPEAKER_IDS.value(modelIndex, 0);
}
```

#### 1.4 修改 CMakeLists.txt

**文件**: `src/control/CMakeLists.txt`

添加新文件：
```cmake
target_sources(control PRIVATE
    # ... 现有文件 ...
    TTSConfigManager.h
    TTSConfigManager.cpp
)
```

---

### Phase 2: 模型部署 ⏳

#### 2.1 下载所有TTS模型

**脚本**: `scripts/2026-01-23/01-download-all-tts-models.ps1`（新建）

```powershell
# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "📦 下载所有TTS模型..." -ForegroundColor Cyan

$models = @(
    @{Name="vits-zh-aishell3"; Url="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-icefall-zh-aishell3.tar.bz2"},
    @{Name="vits-zh-hf-fanchen-wnj"; Url="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-hf-fanchen-wnj.tar.bz2"},
    @{Name="vits-zh-hf-fanchen-C"; Url="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-hf-fanchen-C.tar.bz2"},
    @{Name="vits-zh-hf-theresa"; Url="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-hf-theresa.tar.bz2"},
    @{Name="vits-zh-hf-eula"; Url="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-hf-eula.tar.bz2"},
    @{Name="sherpa-onnx-vits-zh-ll"; Url="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-vits-zh-ll.tar.bz2"},
    @{Name="vits-melo-tts-zh_en"; Url="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-melo-tts-zh_en.tar.bz2"}
)

$downloadDir = "docker/rk3588/tts_models"
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

foreach ($model in $models) {
    $fileName = Split-Path $model.Url -Leaf
    $filePath = Join-Path $downloadDir $fileName

    if (Test-Path $filePath) {
        Write-Host "  ✅ $($model.Name) 已存在，跳过下载" -ForegroundColor Green
        continue
    }

    Write-Host "  📥 下载 $($model.Name)..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $model.Url -OutFile $filePath -UseBasicParsing
        Write-Host "  ✅ $($model.Name) 下载完成" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ $($model.Name) 下载失败: $_" -ForegroundColor Red
    }
}

Write-Host "`n📦 解压所有模型..." -ForegroundColor Cyan

foreach ($model in $models) {
    $fileName = Split-Path $model.Url -Leaf
    $filePath = Join-Path $downloadDir $fileName
    $extractDir = Join-Path $downloadDir $model.Name

    if (Test-Path $extractDir) {
        Write-Host "  ✅ $($model.Name) 已解压，跳过" -ForegroundColor Green
        continue
    }

    if (Test-Path $filePath) {
        Write-Host "  📂 解压 $($model.Name)..." -ForegroundColor Yellow
        tar -xjf $filePath -C $downloadDir
        Write-Host "  ✅ $($model.Name) 解压完成" -ForegroundColor Green
    }
}

Write-Host "`n✅ 所有模型准备完成！" -ForegroundColor Green
```

#### 2.2 更新 Dockerfile

**文件**: `Dockerfile.ubuntu24-apt`

添加模型复制：
```dockerfile
# 复制所有TTS模型
COPY docker/rk3588/tts_models/vits-zh-aishell3 /app/tts_models/vits-zh-aishell3
COPY docker/rk3588/tts_models/vits-zh-hf-fanchen-wnj /app/tts_models/vits-zh-hf-fanchen-wnj
COPY docker/rk3588/tts_models/vits-zh-hf-fanchen-C /app/tts_models/vits-zh-hf-fanchen-C
COPY docker/rk3588/tts_models/vits-zh-hf-theresa /app/tts_models/vits-zh-hf-theresa
COPY docker/rk3588/tts_models/vits-zh-hf-eula /app/tts_models/vits-zh-hf-eula
COPY docker/rk3588/tts_models/sherpa-onnx-vits-zh-ll /app/tts_models/sherpa-onnx-vits-zh-ll
COPY docker/rk3588/tts_models/vits-melo-tts-zh_en /app/tts_models/vits-melo-tts-zh_en
```

---

### Phase 3: UI实现（QML） ⏳

#### 3.1 创建 ParameterComboBox 组件

**文件**: `src/qml/components/parameter_settings/ParameterComboBox.qml`（新建）

```qml
import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

RowLayout {
    id: root

    property string label: ""
    property var model: []
    property int currentIndex: 0

    signal currentIndexChanged(int index)

    Layout.fillWidth: true
    spacing: 10

    Text {
        text: label + "："
        font.pixelSize: 16
        color: "#95a5a6"
        Layout.preferredWidth: 130
    }

    ComboBox {
        id: combo
        model: root.model
        currentIndex: root.currentIndex
        Layout.fillWidth: true
        Layout.preferredHeight: 36

        onCurrentIndexChanged: {
            root.currentIndexChanged(currentIndex)
        }

        background: Rectangle {
            color: "transparent"
            border.color: combo.activeFocus ? "#00d4ff" : "#34495e"
            border.width: 1
            radius: 5
        }

        contentItem: Text {
            text: combo.displayText
            font.pixelSize: 14
            color: "#ecf0f1"
            verticalAlignment: Text.AlignVCenter
            leftPadding: 10
        }

        delegate: ItemDelegate {
            width: combo.width
            contentItem: Text {
                text: modelData
                color: "#ecf0f1"
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }
            highlighted: combo.highlightedIndex === index
            background: Rectangle {
                color: highlighted ? "#00d4ff" : "transparent"
                opacity: highlighted ? 0.3 : 1.0
            }
        }

        popup: Popup {
            y: combo.height
            width: combo.width
            implicitHeight: contentItem.implicitHeight
            padding: 1

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex

                ScrollIndicator.vertical: ScrollIndicator { }
            }

            background: Rectangle {
                color: "#2c3e50"
                border.color: "#00d4ff"
                border.width: 1
                radius: 5
            }
        }
    }
}
```

#### 3.2 创建 ParameterSlider 组件

**文件**: `src/qml/components/parameter_settings/ParameterSlider.qml`（新建）

```qml
import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

RowLayout {
    id: root

    property string label: ""
    property real from: 0
    property real to: 1
    property real value: 0.5
    property real stepSize: 0.1
    property string unit: ""
    property string displayValue: value.toFixed(2)

    signal valueChanged(real value)

    Layout.fillWidth: true
    spacing: 10

    Text {
        text: label + "："
        font.pixelSize: 16
        color: "#95a5a6"
        Layout.preferredWidth: 130
    }

    Slider {
        id: slider
        from: root.from
        to: root.to
        value: root.value
        stepSize: root.stepSize
        Layout.fillWidth: true

        onValueChanged: {
            root.valueChanged(value)
        }

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: "#34495e"

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                color: "#00d4ff"
                radius: 2
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 20
            height: 20
            radius: 10
            color: slider.pressed ? "#00d4ff" : "#ecf0f1"
            border.color: "#00d4ff"
            border.width: 2
        }
    }

    Text {
        text: root.displayValue + root.unit
        font.pixelSize: 16
        color: "#00d4ff"
        Layout.preferredWidth: 80
        horizontalAlignment: Text.AlignRight
    }
}
```

#### 3.3 修改 NetworkParametersSection.qml

**文件**: `src/qml/components/parameter_settings/NetworkParametersSection.qml`

在现有网络参数后面添加TTS设置区域（详见技术决策文档）。

---

### Phase 4: 配置持久化 ⏳

已在 Phase 1.3 中实现 TTSConfigManager 类。

---

### Phase 5: 测试验证 ⏳

#### 测试清单

- [ ] 模型切换功能测试
- [ ] 说话人ID切换测试
- [ ] 语速调整测试
- [ ] 音量调整测试
- [ ] 配置持久化测试
- [ ] 测试语音按钮测试
- [ ] 场景配置独立性测试

---

## 📝 下一步操作

1. **用户确认**: 是否开始实施？
2. **Phase 1**: 修改后端代码（C++）
3. **Phase 2**: 下载和部署模型
4. **Phase 3**: 实现UI界面（QML）
5. **Phase 4**: 测试和验证

**预计工作量**: 4-6小时

---

**相关文档**:
- [技术决策文档](../技术决策/TTS模型动态配置UI方案.md)
- [TTS模型改进方案](01-TTS模型改进方案-音质优化和模型选择.md)
