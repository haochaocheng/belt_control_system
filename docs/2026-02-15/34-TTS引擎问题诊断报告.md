# TTS引擎问题诊断报告

**日期**: 2026-02-15
**问题来源**: voip.md 运行日志分析
**诊断人**: Claude

---

## 📋 问题概览

从 `docs/log/voip.md` 日志中发现以下TTS相关问题：

### ✅ 正常工作的部分

1. **Sherpa-ONNX TTS引擎初始化成功**
   - 行 368-402：Sherpa-ONNX TTS引擎成功初始化
   - 使用模型：`vits-zh-aishell3`
   - 模型目录：`/app/tts_models/vits-zh-aishell3`
   - 采样率：8000Hz
   - TTS服务进程PID：38

2. **TTS缓存系统正常**
   - 行 404-417：TTS缓存初始化完成
   - 缓存目录：`/app/appdata/tts_cache`
   - 已缓存文本：10个

### ❌ 发现的问题

#### 问题1：PaddleSpeech引擎未注册

**日志位置**: 行 716-718

```
[DEBUG] 🔄 [CommonControl] 切换 TTS 引擎 - 索引: 0 名称: "PaddleSpeech"
[WARNING] ⚠️ [TTSEngineManager] 引擎未注册: "PaddleSpeech"
[WARNING] ❌ [CommonControl] TTS 引擎切换失败: "PaddleSpeech"
```

**问题描述**：
- 用户尝试切换到 PaddleSpeech 引擎（索引0）
- TTSEngineManager 报告该引擎未注册
- 切换失败

**影响**：
- 用户无法使用 PaddleSpeech TTS引擎
- 界面显示的引擎列表与实际注册的引擎不匹配

---

#### 问题2：TTSConfigSection组件初始化时引擎为空

**日志位置**: 行 616-624

```
[DEBUG] 🚀 TTSConfigSection 组件加载完成
[DEBUG] 🔄 更新模型列表...
[WARNING] ⚠️ [TTSEngineManager] 当前引擎为空
[DEBUG] ✅ 模型列表已更新: 0 个模型
[DEBUG] 🔄 更新引擎状态...
[DEBUG] 📊 当前引擎:
[DEBUG] ✅ 引擎状态已更新: 未初始化
```

**问题描述**：
- TTSConfigSection 组件加载时，当前引擎为空
- 模型列表为空（0个模型）
- 引擎状态显示"未初始化"

**影响**：
- 用户打开TTS配置界面时，看不到任何可用的引擎和模型
- 界面显示不完整

---

#### 问题3：切换失败后引擎仍为空

**日志位置**: 行 719-724

```
[DEBUG] 🔄 更新模型列表...
[WARNING] ⚠️ [TTSEngineManager] 当前引擎为空
[DEBUG] ✅ 模型列表已更新: 0 个模型
[DEBUG] 🔄 更新引擎状态...
[DEBUG] 📊 当前引擎:
[DEBUG] ✅ 引擎状态已更新: 未初始化
```

**问题描述**：
- 切换引擎失败后，当前引擎仍然为空
- 没有回退到之前的引擎或默认引擎

**影响**：
- 用户切换失败后，系统处于无可用引擎状态
- 用户体验差

---

## 🔍 根本原因分析

### 1. 引擎注册问题

**现状**：
- 只有 Sherpa-ONNX 引擎被注册和初始化
- PaddleSpeech、Coqui、MeloTTS、Piper 等引擎未注册

**可能原因**：
1. **代码中只实现了 Sherpa-ONNX 引擎**
   - `src/control/tts/` 目录下可能只有 Sherpa-ONNX 的实现
   - 其他引擎的适配器代码未完成或未集成

2. **引擎注册代码缺失**
   - TTSEngineManager 初始化时，只注册了 Sherpa-ONNX
   - 其他引擎的注册代码未调用

3. **条件编译或配置问题**
   - 其他引擎可能被条件编译排除
   - CMakeLists.txt 中未包含其他引擎的源文件

### 2. 界面与后端不同步

**现状**：
- QML界面显示多个引擎选项（PaddleSpeech、Coqui等）
- 后端只注册了 Sherpa-ONNX 引擎

**可能原因**：
1. **硬编码的引擎列表**
   - QML界面使用硬编码的引擎名称列表
   - 没有从 TTSEngineManager 动态获取可用引擎

2. **缺少引擎可用性检查**
   - 界面没有检查引擎是否已注册
   - 允许用户选择未注册的引擎

---

## 🛠️ 解决方案

### 方案1：完成其他引擎的集成（推荐）

**步骤**：
1. 实现 PaddleSpeech、Coqui、MeloTTS、Piper 的适配器
2. 在 TTSEngineManager 中注册所有引擎
3. 确保所有引擎的模型文件已上传到设备

**优点**：
- 用户可以使用所有TTS引擎
- 功能完整

**缺点**：
- 工作量大
- 需要测试所有引擎

---

### 方案2：修改界面，只显示已注册的引擎（临时方案）

**步骤**：
1. 修改 QML 界面，从 TTSEngineManager 动态获取引擎列表
2. 只显示已注册的引擎（当前只有 Sherpa-ONNX）
3. 添加引擎可用性检查

**优点**：
- 快速修复，避免用户困惑
- 界面与后端保持一致

**缺点**：
- 用户只能使用 Sherpa-ONNX 引擎
- 功能不完整

---

### 方案3：添加引擎注册失败提示（最小修改）

**步骤**：
1. 在 TTSEngineManager 中添加 `getAvailableEngines()` 方法
2. 在 QML 界面中，切换引擎前检查引擎是否可用
3. 如果引擎不可用，显示友好的错误提示

**优点**：
- 修改最小
- 用户知道哪些引擎不可用

**缺点**：
- 仍然显示不可用的引擎
- 用户体验一般

---

## 📊 当前TTS引擎状态

**总计**：5个TTS引擎（1个已有 + 4个新增）

| 引擎名称 | 类型 | 注册状态 | 初始化状态 | 模型状态 | 可用性 |
|---------|------|---------|-----------|---------|--------|
| Sherpa-ONNX | 已有引擎 | ✅ 已注册 | ✅ 已初始化 | ✅ 已上传 | ✅ 可用 |
| PaddleSpeech | 新增引擎 | ❌ 未注册 | ❌ 未初始化 | ✅ 已上传 | ❌ 不可用 |
| Coqui TTS | 新增引擎 | ❌ 未注册 | ❌ 未初始化 | ✅ 已上传 | ❌ 不可用 |
| MeloTTS | 新增引擎 | ❌ 未注册 | ❌ 未初始化 | ✅ 已上传 | ❌ 不可用 |
| Piper TTS | 新增引擎 | ❌ 未注册 | ❌ 未初始化 | ✅ 已上传 | ❌ 不可用 |

**✅ 2026-02-15 22:00 更新**：所有TTS模型已成功上传到设备 `/home/pi/belt-control-data/models/tts_models/`

---

## 🎯 建议的修复优先级

### 高优先级（立即修复）

1. **修改QML界面，只显示已注册的引擎**
   - 文件：`src/qml/components/voice_management/TTSConfigSection.qml`
   - 避免用户选择不可用的引擎

2. **添加引擎可用性检查**
   - 文件：`src/control/CommonControl.cpp`
   - 切换引擎前检查引擎是否已注册

### 中优先级（本周完成）

3. **完成 PaddleSpeech 引擎集成**
   - 创建 PaddleSpeech 适配器
   - 注册到 TTSEngineManager
   - 测试基本功能

4. **完成其他引擎集成**
   - Coqui、MeloTTS、Piper
   - 逐个集成和测试

### 低优先级（后续优化）

5. **添加引擎动态加载**
   - 支持运行时加载/卸载引擎
   - 减少内存占用

6. **添加引擎状态监控**
   - 实时显示引擎状态
   - 自动重启失败的引擎

---

## 📝 相关文件

### 需要检查的源文件

1. **TTSEngineManager**
   - 文件：`src/control/tts/TTSEngineManager.h/cpp`
   - 检查引擎注册逻辑

2. **CommonControl**
   - 文件：`src/control/CommonControl.h/cpp`
   - 检查引擎切换逻辑

3. **TTSConfigSection**
   - 文件：`src/qml/components/voice_management/TTSConfigSection.qml`
   - 检查引擎列表显示逻辑

4. **TTS适配器**
   - 目录：`src/control/tts/`
   - 检查已实现的引擎适配器

---

## 🔗 相关文档

- [四引擎TTS模型下载完整总结](29-四引擎TTS模型下载完整总结.md)
- [TTS模型上传脚本](../../scripts/2026-02-15/31-upload-tts-models.ps1)
- [网络配置修复记录](本文档-网络部分)

---

## ✅ 下一步行动

1. **✅ 已完成**：
   - ✅ 修复网络配置问题（静态IP + DNS）
   - ✅ 上传所有TTS模型到设备（5个引擎，6.9GB）
   - ✅ 验证模型文件完整性

2. **今日完成**：
   - 修改QML界面，只显示已注册的引擎
   - 添加引擎可用性检查

3. **本周完成**：
   - 完成 PaddleSpeech 引擎集成
   - 完成 Coqui TTS 引擎集成
   - 完成 MeloTTS 引擎集成
   - 完成 Piper TTS 引擎集成
   - 测试所有引擎基本功能

---

## 📦 已上传的模型详情

**设备路径**: `/home/pi/belt-control-data/models/tts_models/`
**总大小**: 6.9GB

### 新增引擎模型（5个文件夹）

1. **coqui/** - Coqui TTS 模型（654.64 MB）
2. **melotts/** - MeloTTS 模型（397 MB）
3. **paddlespeech/** - PaddleSpeech 在线模型（2.3 GB）
4. **paddlespeech_offline/** - PaddleSpeech 离线模型（2.3 GB）
5. **piper/** - Piper TTS ONNX 模型（61 MB）

### 已有引擎模型（Sherpa-ONNX，7个文件夹）

1. **sherpa-onnx-vits-zh-ll/** - Sherpa-ONNX 中文模型
2. **vits-melo-tts-zh_en/** - MeloTTS 中英文混合模型
3. **vits-zh-aishell3/** - 当前使用的模型（8000Hz）
4. **vits-zh-hf-eula/** - HuggingFace Eula 模型
5. **vits-zh-hf-fanchen-C/** - HuggingFace Fanchen-C 模型
6. **vits-zh-hf-fanchen-wnj/** - HuggingFace Fanchen-WNJ 模型
7. **vits-zh-hf-theresa/** - HuggingFace Theresa 模型

---

**诊断完成时间**: 2026-02-15 21:50
**模型上传完成**: 2026-02-15 22:00
**下次更新**: 完成引擎集成后
