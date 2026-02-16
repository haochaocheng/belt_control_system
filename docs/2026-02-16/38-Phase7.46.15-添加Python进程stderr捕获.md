# Phase7.46.15 - 添加Python进程stderr捕获

**日期**: 2026-02-16
**阶段**: Phase 7.46.15
**状态**: ✅ 已完成

---

## 📋 问题描述

### 现象

从 voip.md 日志（第 727-738 行）可以看到：

```
[DEBUG] 🚀 [PaddleSpeech] 启动服务: "/app/tts_engines/paddlespeech/paddle_tts_service.py"
[DEBUG] ✅ [PaddleSpeech] 服务启动成功
[DEBUG] 📤 [PaddleSpeech] 发送命令: "initialize"
[DEBUG] [PaddleSpeech Output] "{\"status\": \"error\", \"error\": \"初始化失败\"}"
[WARNING] ⚠️ [PaddleSpeech] 响应不完整
[WARNING] ❌ [PaddleSpeech] 初始化命令失败
```

**症状**：
- ✅ 服务脚本成功启动
- ✅ 初始化命令发送成功
- ❌ Python 返回 `{"status": "error", "error": "初始化失败"}`
- ❌ **看不到具体的错误原因**（如 traceback、异常信息）

---

## 🔍 根本原因

### 问题分析

**Python 服务的日志输出**：
- **stdout**：JSON 响应（如 `{"status": "error", "error": "初始化失败"}`）
- **stderr**：详细的错误信息（如 traceback、异常堆栈）

**C++ 代码的问题**：
- ✅ 捕获了 stdout（JSON 响应）
- ❌ **没有捕获 stderr**（详细错误信息）
- ❌ 导致看不到 Python 的具体错误原因

**关键代码**（修改前）：
```cpp
// 只连接了 stdout
connect(m_process, &QProcess::readyReadStandardOutput,
        this, &PaddleSpeechAdapter::onProcessReadyRead);
connect(m_process, &QProcess::errorOccurred,
        this, &PaddleSpeechAdapter::onProcessError);
```

---

## 🛠️ 修复方案

### 修改1：PaddleSpeechAdapter.cpp

**文件**: `src/control/tts/PaddleSpeechAdapter.cpp`

**位置**: 第 190-204 行（startService 方法）

**修改内容**：

```cpp
// 连接信号
connect(m_process, &QProcess::readyReadStandardOutput,
        this, &PaddleSpeechAdapter::onProcessReadyRead);
connect(m_process, &QProcess::readyReadStandardError, this, [this]() {
    // ✅ 2026-02-16 00:35: 捕获 Python 进程的 stderr 输出
    QByteArray data = m_process->readAllStandardError();
    QString error = QString::fromUtf8(data).trimmed();
    if (!error.isEmpty()) {
        qWarning() << "[PaddleSpeech Error]" << error;
    }
});
connect(m_process, &QProcess::errorOccurred,
        this, &PaddleSpeechAdapter::onProcessError);
connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
        this, &PaddleSpeechAdapter::onProcessFinished);
```

**说明**：
- 添加 `readyReadStandardError` 信号连接
- 使用 lambda 表达式捕获 stderr 输出
- 输出到日志，前缀 `[PaddleSpeech Error]`

---

### 修改2：MeloTTSAdapter.cpp

**文件**: `src/control/tts/MeloTTSAdapter.cpp`

**位置**: 第 179-193 行（startService 方法）

**修改内容**：

```cpp
// 连接信号
connect(m_process, &QProcess::readyReadStandardOutput,
        this, &MeloTTSAdapter::onProcessReadyRead);
connect(m_process, &QProcess::readyReadStandardError, this, [this]() {
    // ✅ 2026-02-16 00:35: 捕获 Python 进程的 stderr 输出
    QByteArray data = m_process->readAllStandardError();
    QString error = QString::fromUtf8(data).trimmed();
    if (!error.isEmpty()) {
        qWarning() << "[MeloTTS Error]" << error;
    }
});
connect(m_process, &QProcess::errorOccurred,
        this, &MeloTTSAdapter::onProcessError);
connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
        this, &MeloTTSAdapter::onProcessFinished);
```

**说明**：
- 与 PaddleSpeech 相同的修改
- 输出到日志，前缀 `[MeloTTS Error]`

---

## 📊 修复前后对比

### 修复前

**日志输出**：
```
[DEBUG] 🚀 [PaddleSpeech] 启动服务: "/app/tts_engines/paddlespeech/paddle_tts_service.py"
[DEBUG] ✅ [PaddleSpeech] 服务启动成功
[DEBUG] 📤 [PaddleSpeech] 发送命令: "initialize"
[DEBUG] [PaddleSpeech Output] "{\"status\": \"error\", \"error\": \"初始化失败\"}"
[WARNING] ⚠️ [PaddleSpeech] 响应不完整
[WARNING] ❌ [PaddleSpeech] 初始化命令失败
```

**问题**：
- ❌ 只知道"初始化失败"
- ❌ 不知道具体原因（缺少 Python 依赖？模型路径错误？）
- ❌ 无法定位问题

### 修复后

**预期日志输出**：
```
[DEBUG] 🚀 [PaddleSpeech] 启动服务: "/app/tts_engines/paddlespeech/paddle_tts_service.py"
[DEBUG] ✅ [PaddleSpeech] 服务启动成功
[DEBUG] 📤 [PaddleSpeech] 发送命令: "initialize"
[WARNING] [PaddleSpeech Error] [2026-02-16 00:40:00] [ERROR] ❌ 初始化失败: No module named 'paddlespeech'
[WARNING] [PaddleSpeech Error] Traceback (most recent call last):
[WARNING] [PaddleSpeech Error]   File "/app/tts_engines/paddlespeech/paddle_tts_service.py", line 47, in initialize_paddlespeech
[WARNING] [PaddleSpeech Error]     from paddlespeech.cli.tts.infer import TTSExecutor
[WARNING] [PaddleSpeech Error] ModuleNotFoundError: No module named 'paddlespeech'
[DEBUG] [PaddleSpeech Output] "{\"status\": \"error\", \"error\": \"初始化失败\"}"
[WARNING] ⚠️ [PaddleSpeech] 响应不完整
[WARNING] ❌ [PaddleSpeech] 初始化命令失败
```

**优势**：
- ✅ 看到完整的 Python traceback
- ✅ 知道具体错误原因（如缺少 paddlespeech 模块）
- ✅ 可以快速定位和修复问题

---

## 🚀 部署流程

### 步骤1：重新编译和部署

```powershell
.\build-ubuntu24-apt.ps1 186
```

**自动完成**：
1. 检测源码变化
2. 交叉编译应用程序
3. 构建 Docker 镜像
4. 部署到设备 192.168.10.186

### 步骤2：测试 PaddleSpeech 引擎

**操作**：
1. 启动应用程序
2. 打开 TTS 配置界面
3. 切换到 PaddleSpeech 引擎
4. 选择模型
5. 点击"测试"按钮

**查看日志**：
```bash
ssh pi@192.168.10.186 "docker logs -f belt-control-app | grep -E 'PaddleSpeech|Error'"
```

**预期结果**：
- ✅ 看到 Python 的详细错误信息
- ✅ 根据错误信息定位问题（如缺少依赖、模型路径错误等）

---

## 🔍 可能的错误原因

### 1. 缺少 Python 依赖

**错误信息**：
```
ModuleNotFoundError: No module named 'paddlespeech'
```

**解决方案**：
- 在 Dockerfile 中安装 PaddleSpeech
- 或在容器启动时安装依赖

### 2. 模型路径错误

**错误信息**：
```
FileNotFoundError: [Errno 2] No such file or directory: '/home/pi/belt-control-data/models/tts_models/paddlespeech/fastspeech2_csmsc'
```

**解决方案**：
- 检查模型是否已上传到设备
- 验证模型路径是否正确

### 3. 模型格式错误

**错误信息**：
```
ValueError: 无效的模型名称: fastspeech2_csmsc
```

**解决方案**：
- 检查模型名称解析逻辑
- 验证模型文件结构

---

## 📝 相关文档

1. [34-TTS引擎问题诊断报告.md](../2026-02-15/34-TTS引擎问题诊断报告.md) - 问题分析
2. [35-Phase7.46.12-修复TTS引擎注册问题.md](../2026-02-15/35-Phase7.46.12-修复TTS引擎注册问题.md) - 引擎注册修复
3. [36-Phase7.46.13-TTS引擎初始化功能完成总结.md](../2026-02-15/36-Phase7.46.13-TTS引擎初始化功能完成总结.md) - 初始化功能实现
4. [37-Phase7.46.14-修复TTS服务脚本缺失问题.md](37-Phase7.46.14-修复TTS服务脚本缺失问题.md) - 服务脚本修复

---

## ✅ Git提交记录

**提交**: Phase 7.46.15 - 添加Python进程stderr捕获

**修改文件**：
- `src/control/tts/PaddleSpeechAdapter.cpp` - 添加 stderr 捕获
- `src/control/tts/MeloTTSAdapter.cpp` - 添加 stderr 捕获
- `docs/2026-02-16/38-Phase7.46.15-添加Python进程stderr捕获.md` - 修复总结文档

**提交信息**：
```
fix: Phase 7.46.15 - 添加Python进程stderr捕获

- 在 PaddleSpeechAdapter 添加 stderr 捕获
- 在 MeloTTSAdapter 添加 stderr 捕获
- 修复看不到 Python 详细错误信息的问题
- 便于定位 TTS 引擎初始化失败的具体原因
```

---

## 🎯 下一步工作

### 立即执行

1. **重新编译和部署**
   ```powershell
   .\build-ubuntu24-apt.ps1 186
   ```

2. **测试 PaddleSpeech 引擎**
   - 切换到 PaddleSpeech 引擎
   - 选择模型
   - 点击"测试"按钮
   - **查看日志中的详细错误信息**

3. **根据错误信息修复问题**
   - 如果缺少 Python 依赖 → 安装依赖
   - 如果模型路径错误 → 修正路径
   - 如果模型格式错误 → 修正解析逻辑

### 后续工作

4. **完成 PaddleSpeech 引擎集成**
5. **测试 MeloTTS 引擎**
6. **实现 Coqui TTS 适配器**（低优先级）
7. **实现 Piper TTS 适配器**（低优先级）

---

**完成时间**: 2026-02-16 00:40
**下次测试**: 重新编译后
