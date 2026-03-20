# Phase 7.48.61-62 - QDS Loader路径修复 + 三个音频Bug修复

## Phase 7.48.61 - 修复QDS预览不显示基本参数设置

### 问题

在 QDS 上运行时，基本配置页 `BasicConfigPage.qml` 的下半部分（基本参数设置区域）不显示，但设备上运行正常。

### 根本原因

`BasicConfigPage.qml` 中 Loader 使用 QRC 绝对路径：
```qml
// ❌ QDS 无法解析这个路径
source: "qrc:/qt/qml/BeltControlQml/components/parameter_settings/BasicParametersSection.qml"
```

QDS 预览不挂载 QRC 虚拟文件系统，Loader 静默返回空内容。

### 修复

改为相对路径：
```qml
// ✅ QDS 可以解析相对路径
source: "../../parameter_settings/BasicParametersSection.qml"
source: "../../parameter_settings/NetworkParametersSection.qml"
```

---

## Phase 7.48.62 - 修复三个音频Bug（voip.md测试日志发现）

### Bug 1：音频来源UI显示"默认"（应是TTS）

**根本原因**：`BasicConfigPage.qml::loadBasicParams()` 当 SQLite 无记录时直接返回 `false`，未从 C++ `systemConfig`（config.ini）读取 `beltAudioSource` 作为 fallback，导致 UI 始终显示默认值 0。

**修复**：在空记录分支中补充 fallback 逻辑：
```qml
if (!config || Object.keys(config).length === 0) {
    console.log("⚠️ [BasicConfigPage] 没有找到基本参数配置，使用默认值")
    // ✅ fallback: 从 C++ systemConfig 读取运行时值
    if (typeof systemConfig !== "undefined" && systemConfig !== null) {
        basicParams.beltAudioSource = systemConfig.beltAudioSource || 0
    }
    return false
}
```

**修改文件**：`src/qml/components/device_info/pages/BasicConfigPage.qml`

---

### Bug 2：起车预警音频仅播放约1秒

**根本原因**：计时器竞态条件（Race Condition）
- `startWarningPlayback()` 先调用 `m_warningTimer->start(10000)`（10秒）
- 随即调用 `playWarningOnce()` → TTS 同步合成（约9.7秒）
- 合成完成，`playAudio()` 开始播放，此时距计时器启动已过9.7秒
- 0.3秒后计时器触发 `onWarningTimerTimeout()` → 停止播放
- 实际只播放了约0.24秒

**修复**：TTS 合成成功后重置计时器：
```cpp
if (m_ttsEngineManager->synthesize(warningText, tempFile, params)) {
    m_currentAudioPath = tempFile;
    playAudio(m_currentAudioPath);
    // ✅ TTS合成完成后重置计时器，保证完整播放预警时长
    if (m_warningTimer->isActive() && m_systemConfig) {
        m_warningTimer->start(m_systemConfig->warningTimeSeconds() * 1000);
    }
    return;
}
```

**修改文件**：`src/control/CommonControl.cpp`（`playWarningOnce()` 函数）

---

### Bug 3：音频文件存在但程序判断未找到

**根本原因**：
- 批量 TTS 生成的音频文件存储在：`/home/linaro/belt-control-data/audio/1#PD/1号皮带启动.mp3`
- 该路径通过**容器卷挂载**（`-v /home/linaro/belt-control-data:/home/linaro/belt-control-data`）在容器内可访问
- `getAudioPath()` 只搜索 `/app/AUDIO/1#PD/`，未搜索数据目录路径

**路径分析**：
| 路径 | 说明 |
|------|------|
| `/app/AUDIO/1#PD/` | 容器内静态资源路径（预制音频，不常用） |
| `/home/linaro/belt-control-data/audio/1#PD/` | 卷挂载路径（TTS批量生成存储位置）✅ |
| `/home/linaro/belt-control-data/audio/paddlespeech-xxx-spkN/1#PD/` | TTS配置路径（按引擎/模型/说话人分目录） |

**修复**：在 `getAudioPath()` 中添加数据目录作为第二搜索路径（在TTS路径和 `/app/AUDIO/` 路径之间）：
```cpp
// 数据目录路径（容器挂载卷，优先于/app/AUDIO/）
QString dataBaseDir = DataPathConfig::getAudioBaseDirectory();
QString dataFolder = QString("%1/%2#PD").arg(dataBaseDir).arg(beltNumber);
for (const QString &fileName : possibleNames) {
    QString audioPath = QString("%1/%2").arg(dataFolder, fileName);
    if (QFile::exists(audioPath)) {
        qDebug() << "✅ CommonControl: 使用数据目录音频:" << audioPath;
        return audioPath;
    }
}
```

**修改文件**：`src/control/CommonControl.cpp`（`getAudioPath()` 函数）

---

## 搜索优先级（修复后）

1. **TTS合成路径**（当 `beltAudioSource == 1`）：`{audioBase}/paddlespeech-{model}-spk{id}/{N}#PD/`
2. **数据目录路径**（始终搜索）：`{audioBase}/{N}#PD/`（卷挂载路径）
3. **默认容器路径**（兜底）：`{appDir}/AUDIO/{N}#PD/`

其中 `audioBase = DataPathConfig::getAudioBaseDirectory() = /home/linaro/belt-control-data/audio`
