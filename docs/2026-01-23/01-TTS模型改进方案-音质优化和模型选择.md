# TTS模型改进方案 - 音质优化和模型选择

**日期**: 2026-01-23
**问题**: 当前TTS模型（vits-zh-aishell3）声音不自然，使用女声
**目标**: 找到更好的免费TTS模型，支持本地部署，音质更自然

---

## 📊 当前系统配置

### 当前使用的模型
- **模型名称**: `vits-icefall-zh-aishell3`
- **说话人数量**: 174个说话人（多说话人模型）
- **当前配置**: `speaker_id=0`（女声）
- **采样率**: 8000 Hz
- **合成速度**: ~1000ms/短语
- **模型大小**: 116 MB
- **模型路径**: `/app/tts_models/vits-zh-aishell3`

### 可调参数（当前代码）
根据 [SherpaOnnxTTS.cpp:324-325](../../src/control/SherpaOnnxTTS.cpp#L324-L325)：

```cpp
synthCmd["rate"] = m_rate;        // 语速：0.5-2.0（当前1.0）
synthCmd["speaker_id"] = 0;       // 说话人ID：0-173（当前固定为0）
```

**可调整的参数**：
1. **rate（语速）**: 范围 0.5-2.0
   - 0.5 = 慢速
   - 1.0 = 正常速度（当前值）
   - 2.0 = 快速
   - 代码位置: [SherpaOnnxTTS.cpp:344-347](../../src/control/SherpaOnnxTTS.cpp#L344-L347)

2. **speaker_id（说话人）**: 范围 0-173
   - 当前固定为 0（女声）
   - **可以尝试其他ID来找男声**
   - 代码位置: [SherpaOnnxTTS.cpp:325](../../src/control/SherpaOnnxTTS.cpp#L325)

---

## 🎯 推荐解决方案

### 方案1：切换到男声模型（推荐⭐）

**模型**: `vits-zh-hf-fanchen-wnj`

**优势**：
- ✅ **单一男声说话人**（专门优化的男声）
- ✅ **更高采样率**：16000 Hz（当前8000 Hz）→ 音质更好
- ✅ **模型大小相近**：115 MB
- ✅ **支持文本规范化**：自动处理数字、日期、电话号码
- ✅ **免费开源**，支持本地部署

**下载和部署**：
```bash
# 1. 下载模型
wget https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-hf-fanchen-wnj.tar.bz2

# 2. 解压
tar xvf vits-zh-hf-fanchen-wnj.tar.bz2

# 3. 部署到容器
# 将解压后的文件夹复制到 docker/rk3588/tts_models/vits-zh-hf-fanchen-wnj/
```

**模型文件结构**：
```
vits-zh-hf-fanchen-wnj/
├── vits-zh-hf-fanchen-wnj.onnx  (115M)
├── lexicon.txt                   (2.3M)
├── tokens.txt                    (331B)
├── number.fst                    (数字规范化)
├── date.fst                      (日期规范化)
├── phone.fst                     (电话规范化)
├── new_heteronym.fst             (多音字处理)
├── rule.far                      (172M)
└── dict/                         (词典目录)
```

**代码修改**：
修改 [SherpaOnnxTTS.cpp](../../src/control/SherpaOnnxTTS.cpp) 中的模型路径：
```cpp
// 当前：
m_modelDir = "/app/tts_models/vits-zh-aishell3";

// 修改为：
m_modelDir = "/app/tts_models/vits-zh-hf-fanchen-wnj";
```

**预期效果**：
- 🎤 男声播报
- 🎵 音质提升（16kHz vs 8kHz）
- 📢 更适合工业场景的严肃语音

---

### 方案2：调整当前模型的speaker_id（快速测试）

**优势**：
- ✅ 无需下载新模型
- ✅ 快速测试不同声音
- ✅ 174个说话人可选

**实施步骤**：

1. **修改代码**，添加speaker_id参数：

```cpp
// 文件：src/control/SherpaOnnxTTS.h
class SherpaOnnxTTS : public QObject
{
    // ...
    void setSpeakerId(int speakerId);  // 新增方法
    int speakerId() const { return m_speakerId; }

private:
    int m_speakerId;  // 新增成员变量
};

// 文件：src/control/SherpaOnnxTTS.cpp
SherpaOnnxTTS::SherpaOnnxTTS(QObject *parent)
    : QObject(parent)
    , m_speakerId(0)  // 默认0
{
    // ...
}

void SherpaOnnxTTS::setSpeakerId(int speakerId)
{
    m_speakerId = qBound(0, speakerId, 173);  // 限制在0-173之间
    qDebug() << "设置说话人ID:" << m_speakerId;
}

// 修改合成命令
void SherpaOnnxTTS::say(const QString &text)
{
    // ...
    synthCmd["speaker_id"] = m_speakerId;  // 使用可配置的ID
    // ...
}
```

2. **测试不同speaker_id**：
```cpp
// 在 CommonControl.cpp 中测试
m_tts->setSpeakerId(10);  // 尝试不同的ID
m_tts->say("一号皮带准备启动，请注意");
```

**局限性**：
- ⚠️ 不知道哪个ID是男声（需要逐个测试）
- ⚠️ 采样率仍然是8000 Hz（音质有限）

---

### 方案3：使用多说话人模型（高级选项）

如果需要更多声音选择，可以考虑以下模型：

#### 3.1 vits-zh-hf-fanchen-C
- **说话人数量**: 187个
- **采样率**: 16000 Hz
- **大小**: 116 MB
- **下载**: `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-hf-fanchen-C.tar.bz2`

#### 3.2 vits-zh-hf-theresa
- **说话人数量**: 804个（最多选择）
- **采样率**: 22050 Hz（最高音质）
- **大小**: 117 MB
- **下载**: `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-hf-theresa.tar.bz2`

#### 3.3 vits-zh-hf-eula
- **说话人数量**: 804个
- **采样率**: 22050 Hz
- **大小**: 117 MB
- **下载**: `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-hf-eula.tar.bz2`

---

## 🔧 自定义模型训练

### 可行性评估

**训练VITS模型的要求**：
1. **数据集**: 需要10-20小时的高质量录音
2. **标注**: 每句话需要对应的文本标注
3. **硬件**: GPU（至少8GB显存）
4. **时间**: 训练需要数天到数周
5. **技术**: 需要深度学习和语音处理知识

**推荐的训练框架**：
- [PlayVoice/vits_chinese](https://github.com/PlayVoice/vits_chinese) - 中文VITS训练最佳实践
- [CosyVoice](https://cosyvoice.org/) - 阿里开源的多语言TTS
- [Qwen3-TTS](https://www.therift.ai/news-feed/qwen3-tts-full-family-open-sourced-with-voice-design-and-cloning) - 阿里最新开源，支持语音克隆

**结论**：
- ❌ **不推荐自己训练**（成本高、周期长）
- ✅ **推荐使用现成模型**（免费、质量好、即用）

---

## 📋 实施建议

### 推荐实施顺序

#### 第一步：快速测试（5分钟）
尝试调整当前模型的speaker_id，看是否有满意的男声：
```cpp
// 测试几个不同的ID
m_tts->setSpeakerId(50);   // 测试
m_tts->setSpeakerId(100);  // 测试
m_tts->setSpeakerId(150);  // 测试
```

#### 第二步：切换到男声模型（推荐⭐）
如果第一步没有找到满意的声音，切换到 `vits-zh-hf-fanchen-wnj`：
1. 下载模型（约115 MB）
2. 部署到容器
3. 修改代码中的模型路径
4. 重新编译和测试

#### 第三步：高级优化（可选）
如果需要更多选择，尝试804说话人的模型（theresa或eula）

---

## 🔗 参考资源

### 官方文档
- [Sherpa-ONNX TTS 官方文档](https://k2-fsa.github.io/sherpa/onnx/tts/index.html)
- [VITS 预训练模型列表](https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/vits.html)
- [所有TTS模型下载](https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models)

### 训练资源
- [PlayVoice/vits_chinese](https://github.com/PlayVoice/vits_chinese) - 中文VITS训练
- [CosyVoice](https://cosyvoice.org/) - 多语言TTS模型
- [Qwen3-TTS](https://www.therift.ai/news-feed/qwen3-tts-full-family-open-sourced-with-voice-design-and-cloning) - 阿里语音克隆
- [XTTS-v2](https://huggingface.co/coqui/XTTS-v2) - 多语言语音克隆

### 性能参考
所有模型在树莓派4上的RTF（实时因子）为1.5-2.5，适合嵌入式工业应用。

---

## 💡 总结

### 最佳方案
**推荐使用 `vits-zh-hf-fanchen-wnj` 男声模型**：
- ✅ 专门优化的男声
- ✅ 更高音质（16kHz）
- ✅ 免费开源
- ✅ 部署简单
- ✅ 适合工业场景

### 快速测试
先尝试调整当前模型的speaker_id（0-173），可能找到合适的男声。

### 不推荐
❌ 自己训练模型（成本高、周期长、技术要求高）

---

**下一步操作**：
1. 决定使用哪个方案
2. 如需切换模型，我可以帮您下载和部署
3. 如需调整参数，我可以修改代码添加speaker_id配置
