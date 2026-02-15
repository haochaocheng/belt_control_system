# PaddleSpeech 集成技术决策

**创建时间**: 2026-02-15 12:45
**决策类型**: 架构设计 + 技术选型
**状态**: ✅ 决策完成

---

## 📋 背景

### 项目现状

**已有架构**（2026-02-13设计）：
- ✅ 语音管理界面（TTSConfigSection.qml）
- ✅ 多引擎支持框架（TTSEngineManager）
- ✅ 引擎选择下拉框（PaddleSpeech、MeloTTS）
- ✅ 模型切换功能
- ✅ 参数调整（说话人ID、语速、音量）

**2月13日的决策**：
- ❌ 放弃多引擎方案
- ✅ 只使用Sherpa-ONNX单引擎
- **原因**: PaddleSpeech和MeloTTS模型下载失败

**2月15日的突破**：
- ✅ 成功测试PaddleSpeech（Phase 7.46.11）
- ✅ 解决了所有技术问题（8个问题）
- ✅ 生成了151.8 KB测试音频
- ✅ 语音质量优秀（⭐⭐⭐⭐⭐）

---

## 🎯 核心问题

### 问题1：是否集成PaddleSpeech？

**选项A：保持Sherpa-ONNX单引擎**
- ✅ 代码简单，维护容易
- ✅ 部署简单，无Python依赖
- ✅ 性能好，启动快
- ❌ 语音质量一般（用户反馈不满意）
- ❌ 无法调整语速、音调等参数

**选项B：添加PaddleSpeech作为可选引擎**
- ✅ 语音质量最好（百度专注中文）
- ✅ 可调整语速、音调、音量
- ✅ 支持多种声音模型
- ❌ 部署复杂（需要Python+PaddlePaddle）
- ❌ 模型较大（1.1 GB）
- ❌ 启动较慢（5-10秒）

**选项C：完全替换为PaddleSpeech**
- ✅ 语音质量最好
- ❌ 失去Sherpa-ONNX的优势
- ❌ 部署复杂度增加

### 问题2：如何使用已下载的模型？

**已下载模型**（E:\2025\3_gongkongji\belt_control_system\tts_models）：
1. ✅ fastspeech2_aishell3 (405 MB) - 中文多说话人（含男声）
2. ✅ hifigan_aishell3 (916 MB) - HiFiGAN声码器
3. ✅ hifigan_csmsc (915 MB) - HiFiGAN声码器
4. ✅ tacotron2_csmsc (294 MB) - Tacotron2中文女声
5. ✅ vits_csmsc (1027 MB) - VITS中文女声（高质量）
6. ✅ fastspeech2_vctk (428 MB) - 英文多说话人

**总计**: 3985 MB（约3.9 GB）

**可用组合**：
1. **VITS-CSMSC**（端到端，无需声码器）- 中文女声，高质量
2. **FastSpeech2-AISHELL3 + HiFiGAN-AISHELL3** - 中文多说话人（含男声）
3. **Tacotron2-CSMSC + HiFiGAN-CSMSC** - 中文女声（经典）
4. **FastSpeech2-VCTK**（需要声码器）- 英文多说话人

### 问题3：如何集成到现有界面？

**现有界面**（TTSConfigSection.qml）：
```qml
ComboBox {
    id: engineComboBox
    model: [
        "PaddleSpeech (中文最好)",
        "MeloTTS (推荐)"
    ]
    currentIndex: 1  // 默认选择 MeloTTS
}
```

**问题**：
- MeloTTS未实现
- PaddleSpeech已测试成功
- 需要更新引擎列表

---

## ✅ 技术决策

### 决策1：采用混合方案（推荐）⭐

**架构**：
```
TTSEngineManager
├── SherpaOnnxTTS (默认，快速启动)
└── PaddleSpeechAdapter (可选，高质量)
```

**理由**：
1. **满足不同需求**
   - 默认使用Sherpa-ONNX（快速、稳定）
   - 需要高质量时切换到PaddleSpeech
   - 用户可根据场景选择

2. **保留已有优势**
   - Sherpa-ONNX的快速启动
   - Sherpa-ONNX的简单部署
   - 7个现有模型继续可用

3. **获得新能力**
   - PaddleSpeech的高质量语音
   - 可调整语速、音调、音量
   - 支持男声（AISHELL3）

4. **降低风险**
   - 如果PaddleSpeech部署失败，仍有Sherpa-ONNX可用
   - 渐进式集成，不影响现有功能

### 决策2：PaddleSpeech部署方案

**方案A：Docker容器方式（推荐用于测试）**

**优点**：
- ✅ 环境隔离，不影响主系统
- ✅ 依赖管理简单
- ✅ 适合开发和测试

**缺点**：
- ❌ 性能开销（容器化）
- ❌ 不适合生产环境

**实施方法**：
```cpp
// src/tts_engines/PaddleSpeechAdapter.cpp
void PaddleSpeechAdapter::generateSpeech(const QString& text, const QString& outputPath) {
    // 调用Docker容器
    QProcess process;
    process.start("docker", QStringList()
        << "run" << "--rm"
        << "-v" << "/app/models:/models"
        << "-v" << "/app/output:/output"
        << "paddlespeech-tts:latest"
        << "python3" << "/app/tts_script.py"
        << text << outputPath
    );
    process.waitForFinished();
}
```

**方案B：直接在RK3588上安装（推荐用于生产）**

**优点**：
- ✅ 性能最好，无容器开销
- ✅ 适合生产环境
- ✅ 可利用RK3588的NPU加速

**缺点**：
- ❌ 安装复杂
- ❌ 依赖管理困难

**实施步骤**：
1. 在RK3588上安装PaddlePaddle（ARM64版本）
2. 安装PaddleSpeech
3. 应用aistudio_sdk补丁
4. 同步模型到设备
5. 创建TTS服务脚本
6. C++集成

### 决策3：模型使用策略

**优先级1：立即可用（已下载）**

1. **VITS-CSMSC**（中文女声，高质量）
   ```python
   am='vits_csmsc'  # 端到端，不需要声码器
   ```

2. **FastSpeech2-AISHELL3 + HiFiGAN**（中文多说话人，含男声）
   ```python
   am='fastspeech2_aishell3'
   voc='hifigan_aishell3'
   spk_id=174  # 男声ID（需要测试）
   ```

3. **Tacotron2-CSMSC + HiFiGAN**（中文女声，经典）
   ```python
   am='tacotron2_csmsc'
   voc='hifigan_csmsc'
   ```

**优先级2：自动下载（需要时）**

使用TTSExecutor自动下载功能：
```python
from paddlespeech.cli.tts import TTSExecutor

tts = TTSExecutor()

# 第一次调用会自动下载模型
tts(
    text='测试',
    output='test.wav',
    am='fastspeech2_csmsc',  # 会自动下载最新版本
    voc='pwgan_csmsc',       # 会自动下载最新版本
    lang='zh'
)
```

**注意**：
- ❌ 不要依赖固定URL下载（容易过期）
- ✅ 使用TTSExecutor自动下载（官方维护）
- ✅ 优先使用HiFiGAN声码器（PWG可能已弃用）

### 决策4：界面更新方案

**更新引擎列表**：
```qml
ComboBox {
    id: engineComboBox
    model: [
        "Sherpa-ONNX (快速，默认)",
        "PaddleSpeech (高质量，中文最好)"
    ]
    currentIndex: 0  // 默认选择 Sherpa-ONNX
}
```

**动态模型列表**：
```qml
// 根据选择的引擎动态更新模型列表
onCurrentIndexChanged: {
    if (currentIndex === 0) {
        // Sherpa-ONNX 模型
        modelComboBox.model = [
            "vits-zh-aishell3",
            "vits-zh-hf-eula",
            "vits-zh-hf-fanchen-C",
            "vits-zh-hf-fanchen-wnj",
            "vits-zh-hf-theresa",
            "vits-melo-tts-zh_en",
            "sherpa-onnx-vits-zh-ll"
        ]
    } else if (currentIndex === 1) {
        // PaddleSpeech 模型
        modelComboBox.model = [
            "VITS-CSMSC (女声，高质量)",
            "FastSpeech2-AISHELL3 (多说话人)",
            "Tacotron2-CSMSC (女声，经典)"
        ]
    }
}
```

---

## 📊 方案对比

### 单引擎 vs 多引擎

| 指标 | Sherpa-ONNX单引擎 | 混合方案 | PaddleSpeech单引擎 |
|------|-------------------|----------|-------------------|
| 语音质量 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 部署难度 | 简单 | 中等 | 复杂 |
| 启动速度 | 快（<1秒） | 快/慢可选 | 慢（5-10秒） |
| 模型大小 | 130 MB | 130 MB + 1.1 GB | 1.1 GB |
| 参数调整 | 有限 | 丰富 | 丰富 |
| 依赖 | 无 | 无/Python可选 | Python+PaddlePaddle |
| 灵活性 | 低 | 高 | 中 |
| 风险 | 低 | 低 | 中 |

**推荐**: ✅ 混合方案

### Docker vs 直接安装

| 指标 | Docker容器 | 直接安装 |
|------|-----------|---------|
| 部署难度 | 简单 | 复杂 |
| 性能 | 中等（有开销） | 最好 |
| 环境隔离 | 好 | 差 |
| 适用场景 | 开发/测试 | 生产 |
| 维护成本 | 低 | 高 |

**推荐**:
- 开发/测试：✅ Docker容器
- 生产环境：✅ 直接安装

---

## 🎯 实施计划

### Phase 1: 保留Sherpa-ONNX（已完成）

- ✅ Sherpa-ONNX已实现
- ✅ 7个模型可用
- ✅ 界面已完成

### Phase 2: 添加PaddleSpeech适配器

**文件**：
- `src/tts_engines/PaddleSpeechAdapter.h`
- `src/tts_engines/PaddleSpeechAdapter.cpp`

**功能**：
- ✅ Docker容器调用
- ✅ 模型管理
- ✅ 参数转换
- ✅ 错误处理

### Phase 3: 更新TTSEngineManager

**修改**：
- 添加PaddleSpeech引擎注册
- 实现引擎切换逻辑
- 添加引擎状态管理

### Phase 4: 更新QML界面

**修改**：
- 更新引擎列表
- 动态模型列表
- 添加引擎状态显示

### Phase 5: Docker镜像构建

**创建**：
- `docker/paddlespeech/Dockerfile`
- `docker/paddlespeech/tts_script.py`
- `docker/paddlespeech/requirements.txt`

### Phase 6: 设备部署和测试

**步骤**：
1. 同步模型到设备
2. 构建Docker镜像
3. 测试语音合成
4. 性能优化

---

## 📝 关键技术点

### 1. aistudio_sdk补丁

**问题**: paddlenlp依赖已移除的API

**解决**:
```python
import aistudio_sdk.hub as hub
def download(*args, **kwargs):
    return None
hub.download = download
```

### 2. 使用TTSExecutor高级API

**问题**: 底层API配置复杂，容易出错

**解决**:
```python
from paddlespeech.cli.tts import TTSExecutor

tts = TTSExecutor()
tts(
    text='你好',
    output='output.wav',
    am='fastspeech2_csmsc',
    voc='pwgan_csmsc',
    lang='zh'
)
```

### 3. 模型自动下载

**问题**: 手动URL容易过期

**解决**: 使用TTSExecutor自动下载功能

### 4. HiFiGAN vs PWG

**发现**: PWG声码器可能已弃用（全部404）

**建议**: 优先使用HiFiGAN声码器

---

## ⚠️ 风险和注意事项

### 风险1：PaddleSpeech部署失败

**缓解措施**：
- ✅ 保留Sherpa-ONNX作为后备
- ✅ 渐进式集成，不影响现有功能
- ✅ 充分测试后再部署到生产

### 风险2：模型文件过大

**缓解措施**：
- ✅ 只下载必需的模型
- ✅ 使用模型量化（INT8）
- ✅ 按需下载，不全部打包

### 风险3：性能问题

**缓解措施**：
- ✅ 使用Docker容器隔离
- ✅ 异步处理语音合成
- ✅ 添加缓存机制

### 风险4：依赖冲突

**缓解措施**：
- ✅ 使用Docker容器隔离环境
- ✅ 固定依赖版本
- ✅ 充分测试兼容性

---

## 📈 预期效果

### 用户体验

**默认场景**（快速启动）：
- 使用Sherpa-ONNX
- 启动时间 < 1秒
- 语音质量满足基本需求

**高质量场景**（追求质量）：
- 切换到PaddleSpeech
- 启动时间 5-10秒
- 语音质量最好（⭐⭐⭐⭐⭐）

### 技术指标

| 指标 | Sherpa-ONNX | PaddleSpeech |
|------|-------------|--------------|
| 启动时间 | <1秒 | 5-10秒 |
| 合成速度 | 快 | 中等 |
| 语音质量 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 内存占用 | 低 | 中等 |
| CPU占用 | 低 | 中等 |

---

## 🔗 相关文档

### 已完成
- [04-Phase7.46.11完成总结-PaddleSpeech测试成功.md](./04-Phase7.46.11完成总结-PaddleSpeech测试成功.md)
- [05-PaddleSpeech模型详细分析-男声女声选项.md](./05-PaddleSpeech模型详细分析-男声女声选项.md)
- [06-PaddleSpeech所有模型下载清单.md](./06-PaddleSpeech所有模型下载清单.md)
- [09-模型下载404错误分析与解决方案.md](./09-模型下载404错误分析与解决方案.md)

### 2月13日设计
- [06-四引擎TTS集成实施计划-总览.md](../2026-02-13/06-四引擎TTS集成实施计划-总览.md)
- [12-Phase7.46.6-修改QML界面.md](../2026-02-13/12-Phase7.46.6-修改QML界面.md)
- [25-Phase7.46.8最终决策-使用Sherpa-ONNX单引擎.md](../2026-02-13/25-Phase7.46.8最终决策-使用Sherpa-ONNX单引擎.md)

---

## ✅ 最终决策

### 架构决策
✅ **采用混合方案**：Sherpa-ONNX（默认）+ PaddleSpeech（可选）

### 部署决策
- 开发/测试：✅ Docker容器方式
- 生产环境：✅ 直接安装方式

### 模型决策
- 优先使用已下载的3个模型组合
- 需要时使用TTSExecutor自动下载
- 优先使用HiFiGAN声码器

### 界面决策
- 更新引擎列表（Sherpa-ONNX + PaddleSpeech）
- 动态模型列表（根据引擎切换）
- 保持现有参数控制

---

**决策版本**: v1.0
**创建时间**: 2026-02-15 12:45
**决策人**: Claude + 用户
**状态**: ✅ 决策完成，待实施
