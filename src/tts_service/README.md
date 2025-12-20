# Sherpa-ONNX TTS 服务 (方案2：混合架构)

## 概述

此目录包含 Sherpa-ONNX TTS 的独立服务进程实现，用于解决 MinGW/MSVC ABI 不兼容问题。

## 架构设计

### 问题背景
- **主程序**: 使用 MinGW 11.2.0 编译 (与 Qt6 兼容)
- **Sherpa-ONNX 库**: 官方提供的是 MSVC 编译的 DLL
- **ABI 不兼容**: MinGW 和 MSVC 的 C++ ABI 不兼容，无法直接链接

### 解决方案：混合架构（方案2）
```
┌─────────────────────────────────────────────────────────────┐
│                     主程序 (MinGW)                           │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │  SherpaOnnxTTS (QProcess 封装)                     │     │
│  │  - 启动 TTS 服务进程                               │     │
│  │  - 发送 JSON 命令                                  │     │
│  │  - 接收 JSON 响应                                  │     │
│  │  - 播放生成的 WAV 文件                             │     │
│  └────────────────────────────────────────────────────┘     │
│                         │                                    │
│                         │ JSON via stdin/stdout              │
│                         ▼                                    │
│  ┌────────────────────────────────────────────────────┐     │
│  │  sherpa_tts_service.exe (MSVC)                     │     │
│  │  - 加载 Sherpa-ONNX 库                             │     │
│  │  - 处理 init/synthesize 命令                       │     │
│  │  - 生成 WAV 文件                                   │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## 文件说明

- `sherpa_tts_service.cpp`: TTS 服务主程序（MSVC 编译）
- `CMakeLists.txt`: CMake 构建配置（需要 MSVC）
- `build_msvc.bat`: MSVC 编译脚本（自动检测 Visual Studio）
- `README.md`: 本文档

## 通信协议

### JSON 命令格式

#### 1. 初始化命令
```json
{
  "command": "init",
  "model_dir": "C:/path/to/tts_models/vits-zh-aishell3"
}
```

响应:
```json
{
  "success": true,
  "message": "TTS engine initialized successfully. Sample rate: 22050Hz"
}
```

#### 2. 合成命令
```json
{
  "command": "synthesize",
  "text": "你好，世界",
  "output_path": "C:/temp/output.wav",
  "rate": 1.0,
  "speaker_id": 0
}
```

响应:
```json
{
  "success": true,
  "message": "Synthesis successful. Samples: 44100",
  "output_path": "C:/temp/output.wav"
}
```

#### 3. 停止命令
```json
{
  "command": "stop"
}
```

响应:
```json
{
  "success": true,
  "message": "Service stopping"
}
```

## 编译指南

### 前提条件

1. **Visual Studio 2019 或 2022**
   - 下载: https://visualstudio.microsoft.com/downloads/
   - 需要安装 "Desktop development with C++" 工作负载
   - 需要安装 CMake 工具

2. **Sherpa-ONNX 预编译库**
   - 位置: `libs/sherpa-onnx/windows-x64/`
   - 包含: `lib/*.lib`, `lib/*.dll`, `bin/*.dll`, `include/*`

### 编译步骤

#### 方法 1: 使用批处理脚本（推荐）

```batch
cd src/tts_service
build_msvc.bat
```

脚本会自动：
1. 检测 Visual Studio 安装路径
2. 设置 MSVC 环境变量
3. 配置 CMake
4. 编译 Release 版本

#### 方法 2: 手动编译

```batch
# 1. 打开 Visual Studio Developer Command Prompt (x64)

# 2. 进入目录
cd src/tts_service

# 3. 创建构建目录
mkdir build-msvc
cd build-msvc

# 4. 配置 CMake
cmake .. -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=Release

# 5. 编译
cmake --build . --config Release -j4
```

### 输出文件

编译成功后，可执行文件位于:
- `src/tts_service/build-msvc/Release/sherpa_tts_service.exe`

## 部署

### 1. 复制文件到主程序目录

```batch
# 复制 TTS 服务可执行文件
copy src\tts_service\build-msvc\Release\sherpa_tts_service.exe build\bin_windows\

# 复制 Sherpa-ONNX DLL（如果 CMakeLists.txt 没有自动复制）
copy libs\sherpa-onnx\windows-x64\lib\*.dll build\bin_windows\
copy libs\sherpa-onnx\windows-x64\bin\*.dll build\bin_windows\

# 复制 TTS 模型（如果存在）
xcopy /E /I libs\tts_models build\bin_windows\tts_models
```

### 2. 目录结构

部署后的目录结构应该是:
```
build/bin_windows/
├── belt_control_system.exe          # 主程序 (MinGW)
├── sherpa_tts_service.exe            # TTS 服务 (MSVC)
├── sherpa-onnx-*.dll                 # Sherpa-ONNX 库
├── Qt6*.dll                          # Qt 库
└── tts_models/                       # TTS 模型
    └── vits-zh-aishell3/
        ├── model.onnx
        ├── lexicon.txt
        └── tokens.txt
```

## 使用方法

### 在 C++ 代码中

```cpp
#include "SherpaOnnxTTS.h"

// 创建 TTS 对象
SherpaOnnxTTS *tts = new SherpaOnnxTTS(this);

// 初始化（会自动启动 TTS 服务进程）
QString modelDir = QCoreApplication::applicationDirPath() + "/tts_models/vits-zh-aishell3";
if (tts->initialize(modelDir)) {
    qDebug() << "TTS 初始化成功";

    // 设置参数
    tts->setRate(1.0);    // 语速
    tts->setVolume(0.8);  // 音量

    // 播放语音
    tts->say("皮带系统报警，请立即检查");
} else {
    qWarning() << "TTS 初始化失败";
}
```

### TTS 服务自动管理

- **启动**: `initialize()` 时自动启动进程
- **通信**: QProcess 通过 stdin/stdout 交换 JSON 消息
- **停止**: 析构函数时自动停止进程

## 测试

### 1. 独立测试 TTS 服务

```batch
# 启动服务（手动测试）
sherpa_tts_service.exe

# 在另一个终端，输入 JSON 命令
echo {"command":"init","model_dir":"C:/path/to/models"} | sherpa_tts_service.exe
```

### 2. 查看调试输出

TTS 服务会输出详细日志到 stderr:
- `Sherpa-ONNX TTS Service started`
- `Received request: {...}`
- `Sent response: {...}`

## 故障排除

### 问题 1: 找不到 sherpa_tts_service.exe

**原因**: TTS 服务未编译或未复制到正确位置

**解决**:
```batch
# 检查文件是否存在
dir build\bin_windows\sherpa_tts_service.exe

# 如果不存在，重新编译并复制
cd src\tts_service
build_msvc.bat
copy build-msvc\Release\sherpa_tts_service.exe ..\..\build\bin_windows\
```

### 问题 2: TTS 服务启动失败

**可能原因**:
1. 缺少 DLL 依赖
2. 模型文件不存在

**解决**:
```batch
# 检查 DLL 依赖
dumpbin /dependents sherpa_tts_service.exe

# 复制所有 Sherpa-ONNX DLL
copy libs\sherpa-onnx\windows-x64\lib\*.dll build\bin_windows\
```

### 问题 3: 语音合成失败

**可能原因**: 模型文件缺失或路径错误

**解决**:
1. 检查模型目录是否存在
2. 确认包含以下文件:
   - `model.onnx`
   - `lexicon.txt`
   - `tokens.txt`

## 性能优化

- **进程复用**: TTS 服务进程在 `initialize()` 时启动，会一直运行直到主程序退出
- **异步通信**: 使用 QEventLoop 实现同步等待，避免阻塞主线程
- **临时文件清理**: WAV 文件播放完成后自动删除

## 平台支持

### Windows (当前实现)
- 主程序: MinGW 11.2.0
- TTS 服务: MSVC 2019/2022
- 通信: QProcess + JSON

### Linux ARM64 (RK3588) - 待实现（方案3）
- 主程序: GCC 11 (ARM64)
- TTS 服务: GCC 11 (ARM64) - 本地编译，无 ABI 问题
- 可以直接链接 Sherpa-ONNX 库，或继续使用进程架构

## 相关链接

- Sherpa-ONNX: https://github.com/k2-fsa/sherpa-onnx
- VITS 模型下载: https://github.com/k2-fsa/sherpa-onnx/releases
- Qt6 文档: https://doc.qt.io/qt-6/

## 作者

- 实现: Claude Code
- 架构设计: 方案2（混合架构 MinGW + MSVC）
- 日期: 2025-12
