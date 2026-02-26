# Phase 7.47.5-7.47.6 - 修复编译错误和模型路径问题

**创建时间**: 2026-02-26 10:40
**问题类型**: Bug 修复
**优先级**: 高
**状态**: ✅ 已完成

---

## 📋 问题描述

### 问题1：BatchAudioGenerator 编译错误 (Phase 7.47.5)

编译时出现以下错误：
```
error: 'class QTextStream' has no member named 'setCodec'
error: 'class TTSEngineManager' has no member named 'switchEngine'
error: 'class TTSEngineManager' has no member named 'switchModel'
```

### 问题2：PaddleSpeech 模型路径问题 (Phase 7.47.6)

TTS合成失败，错误信息：
```
RuntimeError: Download from https://paddlespeech.cdn.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_nosil_aishell3_ckpt_0.4.zip failed. Retry limit reached
```

---

## 🔍 问题诊断

### 问题1分析

1. **QTextStream::setCodec** - Qt 6 已移除此方法，UTF-8 是默认编码
2. **TTSEngineManager::switchEngine** - 方法不存在，应使用 `setCurrentEngine`
3. **TTSEngineManager::switchModel** - 方法不存在，模型通过 speakerId 在 synthesize 中指定

### 问题2分析

1. **符号链接已创建** - app-entrypoint.sh 中创建了符号链接
2. **环境变量未设置** - `PADDLESPEECH_HOME` 环境变量未传递给 Python 进程
3. **根本原因** - Python 进程由 QProcess 启动，不继承 shell 脚本中设置的环境变量

---

## 🔧 解决方案

### Phase 7.47.5 - 修复编译错误

**文件**: `src/control/BatchAudioGenerator.cpp`

1. **移除 setCodec 调用**（第216行和第523行）：
```cpp
// 修改前
out.setCodec("UTF-8");

// 修改后
// ✅ 2026-02-26 10:00 [Phase 7.47.5]: Qt 6移除了setCodec，UTF-8是默认编码
// out.setCodec("UTF-8");  // Qt 6已移除
```

2. **修复 API 调用**（第488-496行）：
```cpp
// 修改前
if (!m_ttsEngineManager->switchEngine(task.engineName)) { ... }
if (!m_ttsEngineManager->switchModel(task.modelName)) { ... }

// 修改后
// ✅ 2026-02-26 10:00 [Phase 7.47.5]: 修复API调用，使用setCurrentEngine代替switchEngine
if (!m_ttsEngineManager->setCurrentEngine(task.engineName)) { ... }
// 移除 switchModel 调用，模型通过 speakerId 在 synthesize 中指定
```

---

### Phase 7.47.6 - 修复模型路径问题

#### 方案1：app-entrypoint.sh 设置环境变量

**文件**: `docker/rk3588/app-entrypoint.sh`

```bash
# ✅ 2026-02-26 10:30 [Phase 7.47.6]: 设置环境变量（最可靠的方案）
# PaddleSpeech 会在 $PADDLESPEECH_HOME/models/ 查找模型
export PADDLESPEECH_HOME="$PADDLESPEECH_HOME"
echo "✅ 已设置 PADDLESPEECH_HOME=$PADDLESPEECH_HOME"
```

#### 方案2：PaddleSpeechAdapter.cpp 传递环境变量（关键修复）

**文件**: `src/control/tts/PaddleSpeechAdapter.cpp`

```cpp
// ✅ 2026-02-26 10:35 [Phase 7.47.6]: 设置 PADDLESPEECH_HOME 环境变量
// 原因：PaddleSpeech 需要知道模型路径，避免从网络下载
// 效果：Python 进程继承此环境变量，正确找到本地模型
QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
#ifdef Q_OS_LINUX
    // 检测模型路径（优先 linaro，其次 pi）
    QString paddleSpeechHome;
    if (QDir("/home/linaro/belt-control-data/models/tts_models/paddlespeech").exists()) {
        paddleSpeechHome = "/home/linaro/belt-control-data/models/tts_models/paddlespeech";
    } else if (QDir("/home/pi/belt-control-data/models/tts_models/paddlespeech").exists()) {
        paddleSpeechHome = "/home/pi/belt-control-data/models/tts_models/paddlespeech";
    } else {
        paddleSpeechHome = "/app/tts_models/paddlespeech";
    }
    env.insert("PADDLESPEECH_HOME", paddleSpeechHome);
    qDebug() << "📂 [PaddleSpeech] PADDLESPEECH_HOME=" << paddleSpeechHome;
#endif
m_process->setProcessEnvironment(env);
```

---

## 📁 修改文件清单

### Phase 7.47.5
| 文件 | 修改内容 |
|------|----------|
| `src/control/BatchAudioGenerator.cpp` | 移除 setCodec，修复 API 调用 |
| `CMakeLists.txt` | 注释掉 tests 目录（用户已删除） |

### Phase 7.47.6
| 文件 | 修改内容 |
|------|----------|
| `docker/rk3588/app-entrypoint.sh` | 添加 PADDLESPEECH_HOME 环境变量设置 |
| `src/control/tts/PaddleSpeechAdapter.cpp` | 在启动 Python 进程时传递环境变量 |

---

## 🧪 测试计划

### 测试步骤

1. **编译测试**
   - 运行 `.\build-ubuntu24-apt.ps1 185`
   - 确认无编译错误

2. **TTS 合成测试**
   - 打开语音管理界面
   - 选择 `fastspeech2_aishell3` 模型
   - 选择说话人 ID 21
   - 输入测试文本："一号皮带准备启动，请注意"
   - 点击"生成测试语音"

3. **预期结果**
   - ✅ 编译成功
   - ✅ 日志显示：`📂 [PaddleSpeech] PADDLESPEECH_HOME=/home/linaro/belt-control-data/models/tts_models/paddlespeech`
   - ✅ 合成成功，不再尝试网络下载

---

## 📊 技术说明

### PaddleSpeech 模型查找机制

PaddleSpeech 按以下顺序查找模型：

1. **环境变量 `PADDLESPEECH_HOME`**
   - 如果设置，在 `$PADDLESPEECH_HOME/models/` 查找

2. **默认路径 `~/.paddlespeech/`**
   - 如果未设置环境变量，使用默认路径

3. **自动下载**
   - 如果本地找不到，尝试从 CDN 下载

### 为什么需要在 C++ 中设置环境变量

- Python 进程由 `QProcess` 启动
- `QProcess` 默认继承父进程的环境变量
- 但 `app-entrypoint.sh` 中设置的环境变量不会传递给 C++ 应用
- 因此需要在 `PaddleSpeechAdapter::startService()` 中显式设置

---

## 🚀 下一步工作

1. **TTS 全局配置** - 批量合成使用语音管理界面的全局 TTS 配置
2. **配置永久保存** - 将 TTS 配置保存到配置文件

---

**文档版本**: v1.0
**最后更新**: 2026-02-26 10:45
