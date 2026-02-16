# Phase7.46.12 - 修复TTS引擎注册问题

**日期**: 2026-02-15
**阶段**: Phase 7.46.12
**目标**: 修复 PaddleSpeech 和 MeloTTS 引擎未注册问题

---

## 📋 问题分析

### 发现的问题

从 `docs/log/voip.md` 日志分析发现：

1. **PaddleSpeech 引擎未注册**
   - 用户尝试切换到 PaddleSpeech 引擎失败
   - TTSEngineManager 报告该引擎未注册

2. **MeloTTS 引擎未注册**
   - 同样未注册到 TTSEngineManager

3. **界面与后端不同步**
   - QML 界面显示多个引擎选项
   - 后端只有 Sherpa-ONNX 引擎可用

### 根本原因

**代码分析**：
1. ✅ PaddleSpeech 和 MeloTTS 适配器已实现
   - `src/control/tts/PaddleSpeechAdapter.h/cpp`
   - `src/control/tts/MeloTTSAdapter.h/cpp`

2. ✅ 适配器已编译
   - `src/control/CMakeLists.txt` 包含了这些文件

3. ✅ CommonControl 包含了头文件
   - `#include "tts/PaddleSpeechAdapter.h"`
   - `#include "tts/MeloTTSAdapter.h"`

4. ✅ `registerTTSEngines()` 方法已实现
   - 注册 PaddleSpeech 和 MeloTTS

5. ❌ **关键问题**：`registerTTSEngines()` 从未被调用
   - CommonControl 构造函数中有 TODO 注释
   - 引擎管理器创建后，没有注册任何引擎

---

## 🛠️ 修复方案

### 修改1：调用 registerTTSEngines()

**文件**: `src/control/CommonControl.cpp`

**修改位置**: 构造函数末尾（第212-215行）

**修改前**:
```cpp
// TODO: 2026-02-15 20:30: 实现新的 TTS 引擎管理器初始化
// 使用 m_ttsEngineManager 替代 m_tts
}
```

**修改后**:
```cpp
// ✅ 2026-02-15 22:10: 实现新的 TTS 引擎管理器初始化
// 使用 m_ttsEngineManager 替代 m_tts
registerTTSEngines();
qDebug() << "✅ CommonControl: TTS 引擎管理器初始化完成";
}
```

**说明**：
- 在构造函数末尾调用 `registerTTSEngines()`
- 注册 PaddleSpeech 和 MeloTTS 引擎
- 添加日志输出，便于调试

---

## 📦 依赖检查

### Python 服务脚本

PaddleSpeech 和 MeloTTS 适配器需要 Python 服务脚本：

**本地文件**（已存在）：
- `docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py` (7.8 KB)
- `docker/rk3588/tts_engines/paddlespeech/requirements.txt` (247 B)
- `docker/rk3588/tts_engines/melotts/melo_tts_service.py` (7.2 KB)
- `docker/rk3588/tts_engines/melotts/requirements.txt` (195 B)

**Dockerfile 配置**（已存在）：
```dockerfile
COPY tts_engines /app/tts_engines
```

**设备状态**：
- ❌ 容器内 `/app/tts_engines/` 目录不存在
- **原因**：镜像构建时未包含这些脚本
- **解决**：重新构建镜像

---

## 🚀 部署流程

### 步骤1：编译应用程序

```powershell
.\build-ubuntu24-apt.ps1 186
```

**自动完成**：
1. 检测源码变化
2. 交叉编译应用程序
3. 构建 Docker 镜像（包含 tts_engines 目录）
4. 部署到设备 192.168.10.186

### 步骤2：验证部署

**检查容器内文件**：
```bash
ssh pi@192.168.10.186 "docker exec belt-control-app ls -lh /app/tts_engines/"
```

**预期输出**：
```
drwxr-xr-x 2 root root 4.0K melotts
drwxr-xr-x 2 root root 4.0K paddlespeech
```

### 步骤3：查看日志

**启动应用**：
```bash
ssh pi@192.168.10.186 "docker logs -f belt-control-app"
```

**预期日志**：
```
✅ [TTSEngineManager] 创建
🔧 [CommonControl] 注册 TTS 引擎
✅ [PaddleSpeech] 适配器创建
✅ [TTSEngineManager] 注册引擎: PaddleSpeech
✅ [CommonControl] PaddleSpeech 注册成功
✅ [MeloTTS] 适配器创建
✅ [TTSEngineManager] 注册引擎: MeloTTS
✅ [CommonControl] MeloTTS 注册成功
✅ [CommonControl] 所有 TTS 引擎注册完成
✅ CommonControl: TTS 引擎管理器初始化完成
```

---

## 🧪 测试计划

### 测试1：引擎注册验证

**操作**：
1. 启动应用程序
2. 查看日志输出

**预期结果**：
- ✅ PaddleSpeech 注册成功
- ✅ MeloTTS 注册成功
- ✅ 引擎列表包含 3 个引擎（Sherpa-ONNX、PaddleSpeech、MeloTTS）

### 测试2：引擎切换

**操作**：
1. 打开 TTS 配置界面
2. 切换到 PaddleSpeech 引擎

**预期结果**：
- ✅ 切换成功
- ✅ 显示 PaddleSpeech 模型列表
- ✅ 日志显示 "🔄 [TTSEngineManager] 切换引擎: PaddleSpeech"

### 测试3：语音合成

**操作**：
1. 选择 PaddleSpeech 引擎
2. 输入测试文本："你好，这是测试"
3. 点击"测试"按钮

**预期结果**：
- ✅ Python 服务进程启动
- ✅ 模型加载成功
- ✅ 语音合成成功
- ✅ 播放合成的语音

---

## 📊 当前TTS引擎状态

| 引擎名称 | 适配器状态 | Python脚本 | 模型状态 | 注册状态 | 可用性 |
|---------|-----------|-----------|---------|---------|--------|
| Sherpa-ONNX | ✅ 已实现 | ✅ C++实现 | ✅ 已上传 | ✅ 已注册 | ✅ 可用 |
| PaddleSpeech | ✅ 已实现 | ✅ 已存在 | ✅ 已上传 | ⏳ 待注册 | ⏳ 待测试 |
| MeloTTS | ✅ 已实现 | ✅ 已存在 | ✅ 已上传 | ⏳ 待注册 | ⏳ 待测试 |
| Coqui TTS | ❌ 未实现 | ❌ 未实现 | ✅ 已上传 | ❌ 未注册 | ❌ 不可用 |
| Piper TTS | ❌ 未实现 | ❌ 未实现 | ✅ 已上传 | ❌ 未注册 | ❌ 不可用 |

---

## 🎯 下一步工作

### 高优先级（本次完成）

1. ✅ 修复 `registerTTSEngines()` 调用
2. ⏳ 编译和部署应用程序
3. ⏳ 测试 PaddleSpeech 和 MeloTTS 引擎

### 中优先级（后续完成）

4. 实现 Coqui TTS 适配器
5. 实现 Piper TTS 适配器
6. 修改 QML 界面，只显示已注册的引擎

### 低优先级（优化）

7. 添加引擎动态加载
8. 添加引擎状态监控
9. 优化引擎切换性能

---

## 📝 相关文件

### 修改的文件

1. **src/control/CommonControl.cpp**
   - 添加 `registerTTSEngines()` 调用
   - 行号：212-215

### 相关文档

1. [TTS引擎问题诊断报告](34-TTS引擎问题诊断报告.md)
2. [四引擎TTS模型下载完整总结](29-四引擎TTS模型下载完整总结.md)
3. [TTS模型上传脚本](../../scripts/2026-02-15/31-upload-tts-models.ps1)

---

## ✅ 预期效果

**修复前**：
- 只有 Sherpa-ONNX 引擎可用
- 用户切换到 PaddleSpeech 失败
- 日志显示 "⚠️ [TTSEngineManager] 引擎未注册: PaddleSpeech"

**修复后**：
- 3 个引擎可用（Sherpa-ONNX、PaddleSpeech、MeloTTS）
- 用户可以成功切换引擎
- 日志显示 "✅ [CommonControl] PaddleSpeech 注册成功"

---

**修复开始时间**: 2026-02-15 22:10
**预计完成时间**: 2026-02-15 22:30
**实际完成时间**: 待测试
