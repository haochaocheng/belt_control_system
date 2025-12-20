# Sherpa-ONNX TTS 集成指南（量产部署）

## 📦 集成架构

```
belt_control_system/
├── libs/
│   ├── sherpa-onnx/
│   │   ├── windows-x64/           # Windows库文件
│   │   │   ├── bin/
│   │   │   │   └── sherpa-onnx.dll
│   │   │   ├── lib/
│   │   │   │   └── sherpa-onnx.lib
│   │   │   └── include/
│   │   │       └── sherpa-onnx/
│   │   └── linux-arm64/           # RK3588库文件
│   │       ├── lib/
│   │       │   └── libsherpa-onnx.so
│   │       └── include/
│   │           └── sherpa-onnx/
│   └── tts_models/                # TTS模型文件
│       └── vits-zh-aishell3/
│           ├── model.onnx         (~150MB)
│           ├── lexicon.txt
│           └── tokens.txt
└── src/control/
    ├── SherpaOnnxTTS.h            # 封装类
    └── SherpaOnnxTTS.cpp
```

---

## 🔧 步骤1：下载预编译库和模型

### Windows (开发环境)
```bash
cd E:\2025\3_gongkongji\belt_control_system
mkdir -p libs/sherpa-onnx/windows-x64

# 下载Windows版sherpa-onnx
curl -LO https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.10.0/sherpa-onnx-v1.10.0-win-x64.tar.bz2
tar -xf sherpa-onnx-v1.10.0-win-x64.tar.bz2
mv sherpa-onnx-v1.10.0-win-x64/* libs/sherpa-onnx/windows-x64/
```

### RK3588 (目标设备)
```bash
cd /path/to/belt_control_system
mkdir -p libs/sherpa-onnx/linux-arm64

# 下载ARM64版sherpa-onnx
wget https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.10.0/sherpa-onnx-v1.10.0-linux-arm64.tar.bz2
tar -xf sherpa-onnx-v1.10.0-linux-arm64.tar.bz2
mv sherpa-onnx-v1.10.0-linux-arm64/* libs/sherpa-onnx/linux-arm64/
```

### 下载中文TTS模型（通用）
```bash
mkdir -p libs/tts_models
cd libs/tts_models

# 方案A: 高质量女声（推荐）
wget https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-aishell3.tar.bz2
tar -xf vits-zh-aishell3.tar.bz2

# 方案B: 轻量模型（体积小50%）
# wget https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-zh_CN-huayan-medium.tar.bz2
# tar -xf vits-piper-zh_CN-huayan-medium.tar.bz2
```

---

## 🛠️ 步骤2：修改CMakeLists.txt

### src/control/CMakeLists.txt
```cmake
# 添加源文件
set(CONTROL_SOURCES
    ...
    SherpaOnnxTTS.cpp
)

set(CONTROL_HEADERS
    ...
    SherpaOnnxTTS.h
)

# ========== Sherpa-ONNX 集成 ==========
option(ENABLE_SHERPA_ONNX "Enable Sherpa-ONNX TTS support" ON)

if(ENABLE_SHERPA_ONNX)
    message(STATUS "Sherpa-ONNX TTS support: ENABLED")

    # 定义平台相关的库路径
    if(WIN32)
        set(SHERPA_ONNX_ROOT "${CMAKE_SOURCE_DIR}/libs/sherpa-onnx/windows-x64")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64" OR CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
        set(SHERPA_ONNX_ROOT "${CMAKE_SOURCE_DIR}/libs/sherpa-onnx/linux-arm64")
    else()
        set(SHERPA_ONNX_ROOT "${CMAKE_SOURCE_DIR}/libs/sherpa-onnx/linux-x64")
    endif()

    # 查找sherpa-onnx库
    find_library(SHERPA_ONNX_LIB
        NAMES sherpa-onnx
        PATHS "${SHERPA_ONNX_ROOT}/lib" "${SHERPA_ONNX_ROOT}/bin"
        NO_DEFAULT_PATH
    )

    if(SHERPA_ONNX_LIB)
        message(STATUS "Found sherpa-onnx: ${SHERPA_ONNX_LIB}")

        # 添加头文件路径
        target_include_directories(control_module PRIVATE
            "${SHERPA_ONNX_ROOT}/include"
        )

        # 链接sherpa-onnx库
        target_link_libraries(control_module PRIVATE
            ${SHERPA_ONNX_LIB}
        )

        # 添加编译定义
        target_compile_definitions(control_module PRIVATE
            ENABLE_SHERPA_ONNX
        )

        # Windows: 复制DLL到输出目录
        if(WIN32)
            add_custom_command(TARGET control_module POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${SHERPA_ONNX_ROOT}/bin/sherpa-onnx.dll"
                    "$<TARGET_FILE_DIR:belt_control_system>"
                COMMENT "Copying sherpa-onnx.dll to output directory"
            )
        endif()

    else()
        message(WARNING "sherpa-onnx library not found, TTS will be disabled")
        set(ENABLE_SHERPA_ONNX OFF)
    endif()
else()
    message(STATUS "Sherpa-ONNX TTS support: DISABLED")
endif()

# ========== 复制TTS模型到输出目录 ==========
add_custom_command(TARGET control_module POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "Copying TTS models..."
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_SOURCE_DIR}/libs/tts_models"
        "$<TARGET_FILE_DIR:belt_control_system>/tts_models"
    COMMENT "Copying TTS model files"
)
```

---

## 🔌 步骤3：在AlarmPlaybackService中集成

### 修改 AlarmPlaybackService.h
```cpp
#ifndef ALARMPLAYBACKSERVICE_H
#define ALARMPLAYBACKSERVICE_H

#include <QObject>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QTimer>

// 条件包含：如果启用了sherpa-onnx就使用，否则使用Qt TTS
#ifdef ENABLE_SHERPA_ONNX
#include "SherpaOnnxTTS.h"
typedef SherpaOnnxTTS TTSEngine;
#else
#include <QTextToSpeech>
typedef QTextToSpeech TTSEngine;
#endif

class AlarmPlaybackService : public QObject
{
    Q_OBJECT

public:
    explicit AlarmPlaybackService(QObject *parent = nullptr);
    ~AlarmPlaybackService();

    // ... 其他方法 ...

private:
    // 使用统一的TTS引擎类型
    TTSEngine *m_tts;

    // ... 其他成员 ...
};

#endif
```

### 修改 AlarmPlaybackService.cpp
```cpp
#include "AlarmPlaybackService.h"
#include <QDebug>
#include <QCoreApplication>

AlarmPlaybackService::AlarmPlaybackService(QObject *parent)
    : QObject(parent)
    , m_tts(nullptr)
    , m_mediaPlayer(new QMediaPlayer(this))
    , m_audioOutput(new QAudioOutput(this))
    // ... 其他初始化 ...
{
    qDebug() << "✅ AlarmPlaybackService: 报警播放服务已创建";

#ifdef ENABLE_SHERPA_ONNX
    // 使用Sherpa-ONNX TTS
    m_tts = new SherpaOnnxTTS(this);

    // 模型路径（相对于可执行文件）
    QString modelDir = QCoreApplication::applicationDirPath() + "/tts_models/vits-zh-aishell3";

    if (m_tts->initialize(modelDir)) {
        qDebug() << "✅ Sherpa-ONNX TTS初始化成功";
        m_tts->setRate(1.0);
        m_tts->setVolume(0.8);

        connect(m_tts, &SherpaOnnxTTS::stateChanged,
                this, &AlarmPlaybackService::onTtsStateChanged);
    } else {
        qWarning() << "❌ Sherpa-ONNX TTS初始化失败，将使用音频文件播放";
        delete m_tts;
        m_tts = nullptr;
    }
#else
    // 使用Qt TTS（Windows SAPI等）
    m_tts = new QTextToSpeech(this);
    m_tts->setRate(0.0);
    m_tts->setPitch(0.0);
    m_tts->setVolume(0.8);

    connect(m_tts, &QTextToSpeech::stateChanged,
            this, &AlarmPlaybackService::onTtsStateChanged);
#endif

    // ... 其他初始化代码 ...
}

void AlarmPlaybackService::playTtsText(const QString &ttsText)
{
    if (!m_tts) {
        qWarning() << "❌ TTS引擎不可用";
        handleNextPlayback();
        return;
    }

    if (ttsText.isEmpty()) {
        qWarning() << "❌ TTS文本为空";
        handleNextPlayback();
        return;
    }

    qDebug() << "🗣️  AlarmPlaybackService: 播放TTS语音:" << ttsText;
    m_tts->say(ttsText);
}

void AlarmPlaybackService::onTtsStateChanged(int state)
{
    qDebug() << "🗣️  TTS状态变化:" << state;

#ifdef ENABLE_SHERPA_ONNX
    if (state == SherpaOnnxTTS::Ready) {
#else
    if (state == QTextToSpeech::Ready) {
#endif
        // TTS播放结束，延时后进行下一次播放
        m_playTimer->start(500);
    }
}
```

---

## 📦 步骤4：打包部署

### Windows部署包结构
```
belt_control_system_v1.0_windows/
├── belt_control_system.exe
├── sherpa-onnx.dll              # 从libs/sherpa-onnx/windows-x64/bin复制
├── Qt6*.dll                      # Qt运行时库
├── tts_models/                   # TTS模型
│   └── vits-zh-aishell3/
│       ├── model.onnx
│       ├── lexicon.txt
│       └── tokens.txt
├── AUDIO/                        # 音频文件
└── config.ini
```

### RK3588部署包结构
```
belt_control_system_v1.0_rk3588/
├── belt_control_system           # ARM64可执行文件
├── lib/
│   ├── libsherpa-onnx.so        # 从libs/sherpa-onnx/linux-arm64/lib复制
│   ├── libQt6*.so.6             # Qt运行时库
│   └── libonnxruntime.so        # ONNX Runtime（sherpa-onnx依赖）
├── tts_models/                   # TTS模型（与Windows相同）
│   └── vits-zh-aishell3/
├── AUDIO/
└── config.ini
```

### 部署脚本 (deploy.sh)
```bash
#!/bin/bash

# RK3588部署脚本
APP_DIR="/opt/belt_control_system"

# 1. 复制文件
sudo mkdir -p $APP_DIR
sudo cp -r * $APP_DIR/

# 2. 设置权限
sudo chmod +x $APP_DIR/belt_control_system

# 3. 配置库路径
echo "$APP_DIR/lib" | sudo tee /etc/ld.so.conf.d/belt_control.conf
sudo ldconfig

# 4. 创建启动脚本
cat > $APP_DIR/run.sh << 'EOF'
#!/bin/bash
export LD_LIBRARY_PATH=/opt/belt_control_system/lib:$LD_LIBRARY_PATH
cd /opt/belt_control_system
./belt_control_system
EOF

sudo chmod +x $APP_DIR/run.sh

# 5. 创建systemd服务（开机自启）
cat > /tmp/belt_control.service << EOF
[Unit]
Description=Belt Control System
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/run.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/belt_control.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable belt_control
sudo systemctl start belt_control

echo "✅ 部署完成！"
echo "启动: sudo systemctl start belt_control"
echo "停止: sudo systemctl stop belt_control"
echo "查看日志: sudo journalctl -u belt_control -f"
```

---

## 🔍 测试验证

### 1. 编译测试
```bash
# Windows
cd E:\2025\3_gongkongji\belt_control_system
mkdir build && cd build
cmake .. -DENABLE_SHERPA_ONNX=ON
cmake --build . --config Release

# RK3588
cd /path/to/belt_control_system
mkdir build && cd build
cmake .. -DENABLE_SHERPA_ONNX=ON -DCMAKE_BUILD_TYPE=Release
make -j4
```

### 2. 运行时测试
启动程序后，触发保护报警，应该听到高质量的中文语音播报。

查看日志：
```
✅ Sherpa-ONNX TTS初始化成功
🗣️ SherpaOnnxTTS播放: 急停保护报警
  合成语音到文件: /tmp/tts_123456.wav
  ✅ 语音合成成功，采样数: 48000
📻 媒体播放器状态: PlayingState
```

---

## 📊 性能优化

### RK3588优化配置
```cpp
// SherpaOnnxTTS.cpp初始化时
config.model.num_threads = 4;           // RK3588有8核，使用4线程
config.model.provider = "cpu";           // 使用CPU推理
config.model.debug = false;              // 关闭调试信息

// 如果支持GPU加速（需要额外配置）
// config.model.provider = "cuda";       // 或 "opencl"
```

### 模型选择
| 模型 | 大小 | 质量 | 速度 | 推荐场景 |
|------|------|------|------|---------|
| vits-zh-aishell3 | 150MB | ⭐⭐⭐⭐⭐ | 中等 | **生产推荐** |
| vits-piper-zh | 75MB | ⭐⭐⭐⭐ | 快 | 存储受限 |
| vits-zh-hf-fanchen | 200MB | ⭐⭐⭐⭐⭐ | 慢 | 最高质量 |

---

## ❓ 常见问题

### Q1: 编译时找不到sherpa-onnx库
**A**: 确保库文件放在正确路径：
```bash
# 检查文件是否存在
ls libs/sherpa-onnx/windows-x64/lib/sherpa-onnx.lib  # Windows
ls libs/sherpa-onnx/linux-arm64/lib/libsherpa-onnx.so  # Linux
```

### Q2: RK3588运行时报错 "cannot open shared object file"
**A**: 配置库路径：
```bash
export LD_LIBRARY_PATH=/opt/belt_control_system/lib:$LD_LIBRARY_PATH
# 或永久配置
echo "/opt/belt_control_system/lib" | sudo tee /etc/ld.so.conf.d/belt_control.conf
sudo ldconfig
```

### Q3: 模型加载慢
**A**: 首次加载需要时间（约1-2秒），后续合成很快。可以在程序启动时预加载：
```cpp
// main.cpp
alarmPlayback->initialize();  // 预加载模型
```

### Q4: 语音合成质量不如预期
**A**: 尝试更换模型或调整语速：
```cpp
m_tts->setRate(0.9);  // 降低语速，更自然
```

---

## ✅ 量产检查清单

- [ ] Windows和RK3588库文件已下载
- [ ] TTS模型文件已下载并测试
- [ ] CMakeLists.txt已正确配置
- [ ] AlarmPlaybackService已集成SherpaOnnxTTS
- [ ] Windows版本编译通过
- [ ] RK3588版本编译通过
- [ ] 部署脚本已准备
- [ ] TTS功能测试通过
- [ ] 音频播放重复次数正常
- [ ] 启动速度可接受（<3秒）

---

## 📚 相关资源

- [Sherpa-ONNX GitHub](https://github.com/k2-fsa/sherpa-onnx)
- [预训练模型下载](https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models)
- [API文档](https://k2-fsa.github.io/sherpa/onnx/tts/index.html)
