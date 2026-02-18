# Phase7.46.19 - 修复PaddleSpeech响应读取冲突问题

**日期**: 2026-02-16
**阶段**: Phase 7.46.19
**状态**: ✅ 已完成

---

## 📋 问题描述

### 现象

从 voip.md 日志可以看到：

```
[DEBUG] [PaddleSpeech Output] "{\"status\": \"success\", \"error\": null}"
[WARNING] ⚠️ [PaddleSpeech] 响应不完整
[WARNING] ❌ [PaddleSpeech] 初始化命令失败
```

**症状**：
- ✅ Python 服务返回了正确的 JSON 响应
- ✅ 响应包含换行符（Python `print()` 默认添加）
- ❌ C++ 代码报告"响应不完整"
- ❌ 初始化失败

---

## 🔍 根本原因

### 问题分析

**PaddleSpeechAdapter 的信号连接**：

```cpp
// startService() 中连接信号
connect(m_process, &QProcess::readyReadStandardOutput,
        this, &PaddleSpeechAdapter::onProcessReadyRead);

// sendCommand() 中也连接信号
connect(m_process, &QProcess::readyReadStandardOutput, &loop, &QEventLoop::quit);
```

**冲突场景**：
1. `sendCommand()` 发送命令
2. Python 服务返回响应
3. `readyReadStandardOutput` 信号触发
4. **两个槽函数同时执行**：
   - `onProcessReadyRead()` 读取数据 → 数据被读走
   - `sendCommand()` 的事件循环退出 → 读取数据时已经空了
5. `sendCommand()` 找不到换行符 → 报告"响应不完整"

**关键代码**（修复前）：

```cpp
// sendCommand() 中
QByteArray responseData = m_process->readAllStandardOutput();  // ❌ 数据已被 onProcessReadyRead() 读走
m_responseBuffer += QString::fromUtf8(responseData);

int newlineIndex = m_responseBuffer.indexOf('\n');
if (newlineIndex == -1) {
    qWarning() << "⚠️ [PaddleSpeech] 响应不完整";  // ❌ 找不到换行符
    return false;
}
```

---

## 🛠️ 修复方案

### 策略：临时断开信号连接

在 `sendCommand()` 执行期间，临时断开 `onProcessReadyRead()` 的信号连接，避免数据被读走。

### 修改：PaddleSpeechAdapter.cpp

**文件**: `src/control/tts/PaddleSpeechAdapter.cpp`

**位置**: `sendCommand()` 方法（第 255-335 行）

**修改内容**：

```cpp
bool PaddleSpeechAdapter::sendCommand(const QJsonObject &command, QJsonObject &response, int timeoutMs)
{
    if (!m_process || m_process->state() != QProcess::Running) {
        qWarning() << "⚠️ [PaddleSpeech] 服务未运行";
        return false;
    }

    // ✅ 2026-02-16 02:50: 临时断开 readyReadStandardOutput 信号
    // 原因：onProcessReadyRead() 会读取数据，导致 sendCommand() 读不到完整响应
    // 效果：避免响应被其他槽函数读走
    disconnect(m_process, &QProcess::readyReadStandardOutput,
               this, &PaddleSpeechAdapter::onProcessReadyRead);

    // ... 发送命令和读取响应 ...

    // ✅ 2026-02-16 02:50: 恢复信号连接
    connect(m_process, &QProcess::readyReadStandardOutput,
            this, &PaddleSpeechAdapter::onProcessReadyRead);

    return true;
}
```

**说明**：
1. 在发送命令前，断开 `onProcessReadyRead()` 的信号连接
2. 读取响应后，恢复信号连接
3. 在所有返回路径（超时、错误）都恢复信号连接

---

## 📊 修复前后对比

### 修复前

**执行流程**：
```
sendCommand() 发送命令
  ↓
Python 返回响应
  ↓
readyReadStandardOutput 信号触发
  ↓
onProcessReadyRead() 读取数据 ❌ 数据被读走
  ↓
sendCommand() 读取数据 ❌ 读到空数据
  ↓
找不到换行符 ❌ 报告"响应不完整"
```

**日志**：
```
[DEBUG] [PaddleSpeech Output] "{\"status\": \"success\", \"error\": null}"
[WARNING] ⚠️ [PaddleSpeech] 响应不完整
```

### 修复后

**执行流程**：
```
sendCommand() 发送命令
  ↓
断开 onProcessReadyRead() 信号 ✅
  ↓
Python 返回响应
  ↓
readyReadStandardOutput 信号触发
  ↓
sendCommand() 读取数据 ✅ 读到完整响应
  ↓
解析 JSON 成功 ✅
  ↓
恢复 onProcessReadyRead() 信号 ✅
```

**预期日志**：
```
[DEBUG] 📤 [PaddleSpeech] 发送命令: "initialize"
[DEBUG] 📥 [PaddleSpeech] 收到响应: "success"
[DEBUG] ✅ [PaddleSpeech] 初始化成功
```

---

## 🚀 部署流程

### 步骤1：重新构建基础镜像（如果还没构建）

```powershell
docker build --platform linux/arm64 -t belt-control-base:ubuntu24 -f Dockerfile.ubuntu24-base .
```

**预计时间**：~106 分钟（只需一次）

### 步骤2：构建应用镜像

```powershell
.\build-ubuntu24-apt.ps1 186
```

**预计时间**：~3 分钟

### 步骤3：测试 PaddleSpeech 引擎

**操作**：
1. 启动应用程序
2. 打开 TTS 配置界面
3. 切换到 PaddleSpeech 引擎
4. 选择模型
5. 点击"测试"按钮

**预期结果**：
- ✅ PaddleSpeech 引擎初始化成功
- ✅ 不再出现"响应不完整"错误
- ✅ 语音合成成功
- ✅ 播放合成的语音

---

## 📝 相关文档

1. [38-Phase7.46.15-添加Python进程stderr捕获.md](38-Phase7.46.15-添加Python进程stderr捕获.md) - stderr 捕获
2. [41-Phase7.46.18-将Python依赖移到基础镜像并修复numpy版本问题.md](41-Phase7.46.18-将Python依赖移到基础镜像并修复numpy版本问题.md) - numpy 版本修复

---

## ✅ Git提交记录

**提交**: Phase 7.46.19 - 修复PaddleSpeech响应读取冲突问题

**修改文件**：
- `src/control/tts/PaddleSpeechAdapter.cpp` - 修复响应读取冲突
- `docs/2026-02-16/42-Phase7.46.19-修复PaddleSpeech响应读取冲突问题.md` - 修复总结文档

**提交信息**：
```
fix: Phase 7.46.19 - 修复PaddleSpeech响应读取冲突问题

- 在 sendCommand() 中临时断开 onProcessReadyRead() 信号
- 避免响应被其他槽函数读走
- 修复"响应不完整"错误
- 确保 PaddleSpeech 引擎初始化成功
```

---

## 🎯 TTS 引擎状态

### 当前可用性

| 引擎名称 | 注册状态 | 依赖安装 | 响应读取 | 可用性 |
|---------|---------|---------|---------|--------|
| Sherpa-ONNX | ✅ 已注册 | ✅ C++实现 | ✅ 正常 | ✅ 可用 |
| PaddleSpeech | ✅ 已注册 | ✅ 已安装 | ✅ 已修复 | ⏳ 待测试 |
| MeloTTS | ✅ 已注册 | ❌ 未安装 | ✅ 正常 | ❌ 不可用 |
| Coqui TTS | ❌ 未注册 | ❌ 未安装 | ❌ 未实现 | ❌ 不可用 |
| Piper TTS | ❌ 未注册 | ❌ 未安装 | ❌ 未实现 | ❌ 不可用 |

---

**完成时间**: 2026-02-16 02:55
**下次测试**: 重新构建镜像后测试 PaddleSpeech
