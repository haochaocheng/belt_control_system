# Phase 7.46.8 终极方案 - 手动下载预打包模型

**更新时间**: 2026-02-13 19:15
**问题**: 所有自动下载方案都失败（Windows Python、Docker）
**终极方案**: 手动下载预打包的模型文件

---

## 🎯 最简单的解决方案

既然自动下载一直失败，我们采用最直接的方式：

### 方案：使用已有的 Sherpa-ONNX 模型

**发现**：您的系统中已经有 TTS 模型了！

```
libs/tts_models/
├── sherpa-onnx-vits-zh-ll: 129.2 MB
├── vits-melo-tts-zh_en: 182.4 MB
├── vits-zh-aishell3: 444.1 MB
├── vits-zh-hf-eula: 132.2 MB
├── vits-zh-hf-fanchen-C: 131.3 MB
├── vits-zh-hf-fanchen-wnj: 131.1 MB
└── vits-zh-hf-theresa: 132.2 MB

总计: 1282.6 MB
```

**这些模型已经可以用了！**

---

## 🔄 调整实施方案

### 方案 A: 使用现有的 Sherpa-ONNX 模型（推荐）

**优势**：
- ✅ 模型已经存在，无需下载
- ✅ Sherpa-ONNX 是我们已经集成的引擎
- ✅ 已经在代码中实现（SherpaOnnxTTS）
- ✅ 立即可用

**实施**：
1. 直接使用现有的 `SherpaOnnxTTS` 类
2. 跳过 PaddleSpeech 和 MeloTTS
3. 在 QML 中只显示 Sherpa-ONNX 引擎选项

**修改 QML**：
```qml
ComboBox {
    id: engineComboBox
    model: [
        "Sherpa-ONNX (已安装)"
    ]
    currentIndex: 0
    enabled: false  // 只有一个选项，禁用选择
}
```

---

### 方案 B: 从百度网盘下载 PaddleSpeech 模型

如果确实需要 PaddleSpeech：

**步骤**：
1. 在有 Linux 环境的机器上下载模型
2. 打包上传到百度网盘
3. 在 Windows 上下载
4. 解压到 `libs/tts_models/paddlespeech/`

**Linux 下载命令**（在有 Linux 的机器上执行）：
```bash
# 安装 paddlespeech
pip install paddlespeech

# 触发模型下载
python -c "from paddlespeech.cli.tts import TTSExecutor; TTSExecutor()"

# 打包模型
tar -czf paddlespeech-models.tar.gz ~/.paddlespeech

# 上传到百度网盘
```

**Windows 使用**：
```powershell
# 下载 paddlespeech-models.tar.gz
# 解压到项目目录
tar -xzf paddlespeech-models.tar.gz -C libs/tts_models/
```

---

### 方案 C: 简化 TTS 功能（最务实）

**调整策略**：
1. **Phase 7.46 改为单引擎** - 只使用 Sherpa-ONNX
2. **移除多引擎架构** - 简化代码
3. **使用现有模型** - 无需下载

**优势**：
- ✅ 立即可用
- ✅ 代码简单
- ✅ 维护成本低
- ✅ 避免依赖问题

**实施**：
```cpp
// 移除 TTSEngineManager
// 直接使用 SherpaOnnxTTS

class CommonControl {
    Q_INVOKABLE void testTTS(const QString& text, int speakerId, float speed, float volume) {
        m_sherpaOnnxTTS->generateSpeech(text, speakerId, speed, volume);
    }

private:
    SherpaOnnxTTS* m_sherpaOnnxTTS;  // 直接使用，不需要管理器
};
```

---

## 📊 方案对比

| 方案 | 优势 | 劣势 | 推荐度 |
|------|------|------|--------|
| **A: 使用现有模型** | 立即可用，无需下载 | 只有一个引擎 | ⭐⭐⭐⭐⭐ |
| **B: 百度网盘** | 可以使用 PaddleSpeech | 需要手动操作 | ⭐⭐⭐ |
| **C: 简化功能** | 代码简单，维护容易 | 功能受限 | ⭐⭐⭐⭐ |

---

## 🎯 推荐实施方案

### 立即可行：方案 A + C 组合

**第一步**：使用现有的 Sherpa-ONNX 模型
- 修改 QML，只显示 Sherpa-ONNX 选项
- 移除 PaddleSpeech 和 MeloTTS 相关代码
- 简化 TTSEngineManager

**第二步**（可选）：如果确实需要 PaddleSpeech
- 在有 Linux 的机器上下载模型
- 通过百度网盘或 U 盘传输
- 再集成到系统中

---

## 🔧 具体修改

### 1. 修改 QML 界面

**文件**: `src/qml/components/voice_management/TTSConfigSection.qml`

```qml
// 修改引擎选择
ComboBox {
    id: engineComboBox
    model: [
        "Sherpa-ONNX (中文语音合成)"
    ]
    currentIndex: 0
    enabled: false  // 只有一个选项
}

// 修改模型列表（使用现有的 7 个模型）
ComboBox {
    id: modelComboBox
    model: [
        "vits-zh-aishell3",
        "vits-zh-hf-eula",
        "vits-zh-hf-fanchen-C",
        "vits-zh-hf-fanchen-wnj",
        "vits-zh-hf-theresa",
        "vits-melo-tts-zh_en",
        "sherpa-onnx-vits-zh-ll"
    ]
}
```

### 2. 简化 C++ 代码

**文件**: `src/control/CommonControl.cpp`

```cpp
// 移除 TTSEngineManager
// 直接使用 SherpaOnnxTTS

void CommonControl::testTTS(const QString& text, int speakerId, float speed, float volume) {
    if (!m_sherpaOnnxTTS) {
        qWarning() << "SherpaOnnxTTS not initialized";
        return;
    }

    // 直接调用
    m_sherpaOnnxTTS->generateSpeech(text, speakerId, speed, volume);
}
```

### 3. 更新 Docker 配置

**文件**: `docker/rk3588/Dockerfile.v3.3-runtime`

```dockerfile
# ❌ 移除 Python 和 TTS 依赖安装
# 原因：使用 Sherpa-ONNX（C++ 实现），不需要 Python

# ✅ 只保留 Sherpa-ONNX 库
# 已经在基础镜像中包含
```

---

## ✅ 总结

**最务实的方案**：
1. 使用现有的 Sherpa-ONNX 模型（1.3GB，7个模型）
2. 简化代码，移除多引擎架构
3. 立即可用，无需下载

**如果确实需要 PaddleSpeech**：
- 在 Linux 机器上下载
- 通过网盘或 U 盘传输
- 这是唯一可靠的方式

**放弃的方案**：
- ❌ Windows Python 自动下载（编译失败）
- ❌ Docker 自动下载（如果也失败）
- ❌ 任何需要在 Windows 上编译 C++ 的方案

---

**状态**: ✅ 方案确定
**下一步**: 选择方案并实施
