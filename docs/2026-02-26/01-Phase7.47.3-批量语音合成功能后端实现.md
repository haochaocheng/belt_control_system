# Phase 7.47.3 - 批量语音合成功能后端实现

**创建时间**: 2026-02-26 09:00
**任务类型**: 功能实现
**优先级**: 高
**状态**: ✅ 已完成

---

## 📋 任务概述

实现批量语音合成功能的完整后端支持，包括：
1. 创建 `BatchAudioGenerator` C++ 后端类
2. 集成 TTS 引擎管理器
3. 实现配置管理和文件清单生成
4. 实现批量生成和进度统计
5. 注册到 QML 供界面使用

---

## 🎯 问题诊断

### 原始问题
用户反馈：批量语音合成对话框的"开始生成"按钮不起作用，其他功能按钮和日志进度统计信息也未实现。

### 根本原因
1. **后端控制器未实现**：`BatchAudioGenerator` 类不存在
2. **QML 绑定缺失**：`VoiceManagement.qml` 中的 `batchGenerator` 属性被注释
3. **未注册到 QML**：`main.cpp` 中未创建和注册控制器实例
4. **CMakeLists.txt 未更新**：新源文件未添加到编译列表

---

## 🔧 实施步骤

### 1. 创建数据结构 (TTSBatchConfig.h)

**文件**: `src/control/tts/TTSBatchConfig.h`

**内容**:
- `ProtectionCategory` 枚举：定义保护类型分类
- `TTSEngineConfig` 结构：TTS 引擎配置
- `TTSBatchConfig` 结构：批量生成配置
- `VoiceFileItem` 结构：语音文件项
- `TTSBatchProgress` 结构：批量生成进度

**状态**: ✅ 已存在（2026-02-25 创建）

---

### 2. 创建 BatchAudioGenerator 类

#### 2.1 头文件 (BatchAudioGenerator.h)

**文件**: `src/control/BatchAudioGenerator.h`

**关键特性**:
```cpp
class BatchAudioGenerator : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)
    Q_PROPERTY(int totalFiles READ totalFiles NOTIFY totalFilesChanged)
    Q_PROPERTY(int completedFiles READ completedFiles NOTIFY completedFilesChanged)
    Q_PROPERTY(int failedFiles READ failedFiles NOTIFY failedFilesChanged)
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY currentFileChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)

public:
    explicit BatchAudioGenerator(TTSEngineManager *ttsManager, QObject *parent = nullptr);

public slots:
    void setConfig(const QVariantMap &config);
    int generateFileList();
    void start();
    void stop();
    void exportLog(const QString &filePath);

signals:
    void logMessage(const QString &level, const QString &message);
    void finished(bool success, const QString &message);
};
```

**状态**: ✅ 已创建

---

#### 2.2 实现文件 (BatchAudioGenerator.cpp)

**文件**: `src/control/BatchAudioGenerator.cpp`

**核心功能**:

1. **配置管理** (`setConfig`)
   - 解析 QML 传入的配置对象
   - 提取分类、编号范围、引擎配置等

2. **文件清单生成** (`generateFileList`)
   - 根据配置生成所有任务
   - 调用各分类的任务生成函数
   - 返回总任务数

3. **批量生成** (`start`)
   - 遍历任务列表
   - 调用 `executeTask` 执行单个任务
   - 更新进度和统计信息
   - 生成报告（可选）

4. **任务执行** (`executeTask`)
   - 检查文件是否已存在（可跳过）
   - 创建输出目录
   - 切换 TTS 引擎和模型
   - 调用 `TTSEngineManager::synthesize` 生成音频
   - 返回成功/失败状态

5. **分类任务生成**
   - `generateSwitchInputTasks`: 开关量输入保护
   - `generateAnalogInputTasks`: 模拟量输入保护
   - `generateMotorTasks`: 电机保护
   - `generateBrakeTasks`: 制动器保护
   - `generateTensionTasks`: 张紧控制保护
   - `generateLinePositionTasks`: 沿线点位保护
   - `generateSystemSoundTasks`: 系统提示音

**状态**: ✅ 已实现

---

### 3. 集成 TTS 引擎管理器

#### 3.1 添加 CommonControl 接口

**文件**: `src/control/CommonControl.h`

**新增方法**:
```cpp
/**
 * @brief 获取 TTS 引擎管理器
 * @return TTS 引擎管理器指针
 * ✅ 2026-02-26 08:50 [Phase 7.47.3]: 添加此方法供 BatchAudioGenerator 使用
 */
TTSEngineManager* getTTSEngineManager() { return m_ttsEngineManager; }
```

**状态**: ✅ 已添加

---

### 4. 注册到 QML

#### 4.1 更新 main.cpp

**文件**: `src/main/main.cpp`

**修改内容**:

1. **添加头文件**:
```cpp
// ✅ 2026-02-26 08:40 [Phase 7.47.3]: 添加批量音频生成器
#include "control/BatchAudioGenerator.h"
```

2. **创建实例**:
```cpp
// ✅ 2026-02-26 08:40 [Phase 7.47.3]: 创建批量音频生成器
// 注意：需要传入 CommonControl 的 TTS 引擎管理器
BatchAudioGenerator batchAudioGenerator(commonControl.getTTSEngineManager());
logMessage("BatchAudioGenerator created");
```

3. **注册到 QML**:
```cpp
// ✅ 2026-02-26 08:45 [Phase 7.47.3]: 注册批量音频生成器到QML
engine.rootContext()->setContextProperty("batchGeneratorController", &batchAudioGenerator);
```

**状态**: ✅ 已完成

---

#### 4.2 更新 VoiceManagement.qml

**文件**: `src/qml/pages/VoiceManagement.qml`

**修改内容**:
```qml
BatchSynthesisDialog {
    id: batchSynthesisDialog
    anchors.centerIn: parent
    // ✅ 2026-02-26 08:55 [Phase 7.47.3]: 绑定后端控制器
    batchGenerator: batchGeneratorController
}
```

**状态**: ✅ 已完成

---

### 5. 更新 CMakeLists.txt

**文件**: `src/control/CMakeLists.txt`

**添加源文件**:
```cmake
# ✅ 2026-02-26 09:00 [Phase 7.47.3]: 添加批量音频生成器源文件
BatchAudioGenerator.cpp
```

**添加头文件**:
```cmake
# ✅ 2026-02-26 09:00 [Phase 7.47.3]: 添加批量音频生成器头文件
BatchAudioGenerator.h
tts/TTSBatchConfig.h
```

**状态**: ✅ 已完成

---

## 📁 文件清单

### 新增文件
1. `src/control/BatchAudioGenerator.h` - 批量音频生成器头文件
2. `src/control/BatchAudioGenerator.cpp` - 批量音频生成器实现
3. `src/control/tts/TTSBatchConfig.h` - 批量配置数据结构（已存在）

### 修改文件
1. `src/main/main.cpp` - 添加头文件、创建实例、注册到 QML
2. `src/control/CommonControl.h` - 添加 `getTTSEngineManager()` 方法
3. `src/qml/pages/VoiceManagement.qml` - 绑定后端控制器
4. `src/control/CMakeLists.txt` - 添加源文件和头文件

---

## 🎨 功能特性

### 1. 配置管理
- ✅ 支持多分类选择（开关量、模拟量、电机等）
- ✅ 支持编号范围配置（皮带、电机、制动器等）
- ✅ 支持多引擎配置（PaddleSpeech、MeloTTS 等）
- ✅ 支持跳过已存在文件
- ✅ 支持生成报告

### 2. 文件清单生成
- ✅ 根据配置自动生成任务列表
- ✅ 计算总文件数
- ✅ 预览功能（不实际生成）

### 3. 批量生成
- ✅ 串行执行任务（避免资源竞争）
- ✅ 实时进度更新
- ✅ 成功/失败统计
- ✅ 详细日志输出
- ✅ 支持中途停止

### 4. 进度统计
- ✅ 总文件数
- ✅ 已完成数
- ✅ 失败数
- ✅ 当前文件
- ✅ 进度百分比

### 5. 日志系统
- ✅ 分级日志（info、warn、error）
- ✅ 时间戳
- ✅ 实时显示
- ✅ 导出功能

### 6. 报告生成
- ✅ 生成详细报告
- ✅ 包含统计信息
- ✅ 保存到输出目录

---

## 🧪 测试计划

### 单元测试
- [ ] 测试配置解析
- [ ] 测试文件清单生成
- [ ] 测试任务执行
- [ ] 测试进度计算

### 集成测试
- [ ] 测试完整生成流程（小批量：10 个文件）
- [ ] 测试停止功能
- [ ] 测试跳过已存在文件
- [ ] 测试多引擎生成

### 界面测试
- [ ] 测试"预览清单"按钮
- [ ] 测试"开始生成"按钮
- [ ] 测试"停止生成"按钮
- [ ] 测试"导出日志"按钮
- [ ] 测试进度显示
- [ ] 测试日志输出

---

## 📊 预期效果

### 用户体验
1. **配置简单**：通过界面选择分类和范围
2. **预览清晰**：生成前可预览文件清单
3. **进度可见**：实时显示生成进度
4. **日志详细**：每个文件的生成状态都有记录
5. **可控性强**：支持中途停止

### 性能指标
- **生成速度**：取决于 TTS 引擎（PaddleSpeech 约 2-3 秒/文件）
- **内存占用**：串行执行，内存占用稳定
- **稳定性**：支持长时间运行（2000+ 文件）

---

## 🚀 下一步工作

1. **编译测试**：在 Windows 和 RK3588 上编译验证
2. **功能测试**：测试所有按钮和功能
3. **性能优化**：考虑并行生成（可选）
4. **用户文档**：编写使用说明

---

## 📝 参考文档

- [语音管理界面批量合成功能设计](../2026-02-24/02-语音管理界面批量合成功能设计.md)
- [语音管理界面批量合成功能实施计划](../2026-02-24/03-语音管理界面批量合成功能实施计划.md)

---

**文档版本**: v1.0
**最后更新**: 2026-02-26 09:10
