# 跨平台 TTS 部署指南

## RK3588 (aarch64 Linux) TTS 配置

### 方案一：eSpeak-NG（轻量级，推荐入门）

#### 1. 安装
```bash
# Debian/Ubuntu系统
sudo apt-get update
sudo apt-get install espeak-ng espeak-ng-data

# 或从源码编译(RK3588优化)
git clone https://github.com/espeak-ng/espeak-ng.git
cd espeak-ng
./autogen.sh
./configure
make -j4
sudo make install
```

#### 2. 测试
```bash
# 测试中文播放
espeak-ng -v zh "你好，这是测试"

# 调整语速和音量
espeak-ng -v zh -s 150 -a 150 "皮带控制系统报警"
```

#### 3. 优点与缺点
- ✅ 极其轻量(< 5MB)
- ✅ 资源占用低
- ✅ 支持多语言
- ❌ 中文发音质量一般（机械感较重）

---

### 方案二：sherpa-onnx（高质量中文，推荐生产）

#### 1. 安装 sherpa-onnx
```bash
# 下载预编译版本
wget https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-v1.10.0-linux-arm64.tar.bz2
tar -xf sherpa-onnx-v1.10.0-linux-arm64.tar.bz2
sudo cp sherpa-onnx-v1.10.0-linux-arm64/bin/* /usr/local/bin/
sudo cp -r sherpa-onnx-v1.10.0-linux-arm64/lib/* /usr/local/lib/
sudo ldconfig
```

#### 2. 下载中文TTS模型
```bash
# 下载中文女声模型(推荐，质量高)
mkdir -p ~/tts_models
cd ~/tts_models

# 方案A: 阿里巴巴 MossFormer 模型 (自然度高)
wget https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-aishell3-icefall.tar.bz2
tar -xf vits-zh-aishell3-icefall.tar.bz2

# 方案B: Piper 中文模型 (体积小)
wget https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-zh_CN-huayan-medium.tar.bz2
tar -xf vits-piper-zh_CN-huayan-medium.tar.bz2
```

#### 3. 测试
```bash
# 使用 MossFormer 模型
sherpa-onnx-offline-tts \
  --vits-model=~/tts_models/vits-zh-aishell3-icefall/model.onnx \
  --vits-lexicon=~/tts_models/vits-zh-aishell3-icefall/lexicon.txt \
  --vits-tokens=~/tts_models/vits-zh-aishell3-icefall/tokens.txt \
  --output-filename=/tmp/test.wav \
  "急停保护报警"

# 播放生成的音频
aplay /tmp/test.wav
```

#### 4. 应用配置
在程序中配置模型路径（修改 `CrossPlatformTTS.cpp`）:
```cpp
void CrossPlatformTTS::sayWithSherpa(const QString &text)
{
    QStringList args;
    args << "--vits-model" << "/home/user/tts_models/vits-zh-aishell3-icefall/model.onnx";
    args << "--vits-lexicon" << "/home/user/tts_models/vits-zh-aishell3-icefall/lexicon.txt";
    args << "--vits-tokens" << "/home/user/tts_models/vits-zh-aishell3-icefall/tokens.txt";
    args << "--output-filename" << "/tmp/tts_output.wav";
    args << text;

    m_process->start("sherpa-onnx-offline-tts", args);

    // 播放生成的音频
    QProcess::execute("aplay", QStringList() << "/tmp/tts_output.wav");
}
```

#### 5. 优点与缺点
- ✅ 中文发音质量极高
- ✅ 支持多种音色
- ✅ 完全离线
- ✅ 支持ARM NEON优化
- ❌ 模型文件较大(50-200MB)
- ❌ 首次加载需要时间

---

### 方案三：Pico TTS（Android移植）

#### 1. 安装
```bash
# 安装 SVOX Pico TTS
sudo apt-get install libttspico-utils libttspico0 libttspico-data

# 或手动编译ARM64版本
git clone https://github.com/naggety/picotts.git
cd picotts/pico
./autogen.sh
./configure
make -j4
sudo make install
```

#### 2. 测试
```bash
# 测试播放(支持英文为主)
pico2wave -l en-US -w test.wav "Emergency stop alarm"
aplay test.wav
```

#### 3. 优点与缺点
- ✅ 非常轻量
- ✅ Android验证成熟
- ❌ 中文支持有限
- ❌ 主要用于英文

---

### 方案四：在线TTS API（联网方案）

适合对音质要求高且有网络的场景。

#### 百度TTS API
```cpp
// 示例代码
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrlQuery>

void CrossPlatformTTS::sayWithOnlineAPI(const QString &text)
{
    // 百度TTS API
    QString apiUrl = "https://tsn.baidu.com/text2audio";

    QUrlQuery query;
    query.addQueryItem("tex", text);
    query.addQueryItem("tok", "YOUR_ACCESS_TOKEN");  // 需要申请
    query.addQueryItem("cuid", "belt_control_system");
    query.addQueryItem("ctp", "1");
    query.addQueryItem("lan", "zh");
    query.addQueryItem("spd", "5");  // 语速
    query.addQueryItem("pit", "5");  // 音调
    query.addQueryItem("vol", "9");  // 音量
    query.addQueryItem("per", "1");  // 发音人(0-女声，1-男声)

    QUrl url(apiUrl);
    url.setQuery(query);

    // 下载音频并播放
    // TODO: 实现网络下载和播放逻辑
}
```

---

## 性能对比表

| 方案 | 发音质量 | 资源占用 | 延迟 | 中文支持 | 推荐场景 |
|------|---------|---------|------|---------|---------|
| eSpeak-NG | ⭐⭐ | 极低(5MB) | 极低(<100ms) | ⭐⭐⭐ | 低配硬件、实时性要求高 |
| sherpa-onnx | ⭐⭐⭐⭐⭐ | 中等(150MB) | 低(~500ms) | ⭐⭐⭐⭐⭐ | **生产环境推荐** |
| Pico TTS | ⭐⭐⭐ | 低(20MB) | 低(<200ms) | ⭐⭐ | 英文为主场景 |
| 在线API | ⭐⭐⭐⭐⭐ | 极低 | 高(1-3s) | ⭐⭐⭐⭐⭐ | 有网络、对音质要求高 |

---

## 集成到项目

### 1. 修改 CMakeLists.txt
```cmake
# 添加新文件
set(CONTROL_SOURCES
    ...
    CrossPlatformTTS.cpp
)

set(CONTROL_HEADERS
    ...
    CrossPlatformTTS.h
)
```

### 2. 修改 AlarmPlaybackService 使用新的TTS类
```cpp
// AlarmPlaybackService.h
#include "CrossPlatformTTS.h"

private:
    CrossPlatformTTS *m_tts;  // 替换原来的 QTextToSpeech

// AlarmPlaybackService.cpp
AlarmPlaybackService::AlarmPlaybackService(QObject *parent)
    : QObject(parent)
    , m_tts(new CrossPlatformTTS(this))
{
    m_tts->initialize();
    m_tts->setVolume(0.8);

    connect(m_tts, &CrossPlatformTTS::stateChanged,
            this, &AlarmPlaybackService::onTtsStateChanged);
}
```

---

## RK3588 优化建议

### 1. 使用 NEON 加速
sherpa-onnx 已经内置 ARM NEON 优化，确保编译时启用：
```bash
export CFLAGS="-march=armv8-a -mtune=cortex-a76.cortex-a55"
export CXXFLAGS="-march=armv8-a -mtune=cortex-a76.cortex-a55"
```

### 2. 使用 Mali GPU 加速（可选）
RK3588的Mali-G610可以加速ONNX推理：
```bash
# 安装 OpenCL 运行时
sudo apt-get install mali-g610-firmware opencl-headers
```

### 3. 音频输出配置
确保ALSA配置正确：
```bash
# 测试音频输出
speaker-test -t wav -c 2

# 如果有问题，配置默认声卡
sudo nano /etc/asound.conf
```

---

## 常见问题

### Q1: eSpeak中文发音不清晰？
A: eSpeak的中文语音库质量有限，可以安装额外的语音包或使用sherpa-onnx。

### Q2: sherpa-onnx模型太大？
A: 可以使用Piper系列的轻量模型，或者使用模型量化减小体积。

### Q3: RK3588上播放卡顿？
A: 检查CPU频率设置，确保性能模式：
```bash
sudo cpufreq-set -g performance
```

### Q4: 如何切换不同TTS后端？
A: `CrossPlatformTTS`会自动检测，也可以手动指定：
```cpp
m_tts->setBackend(CrossPlatformTTS::SherpaOnnx);
```

---

## 推荐配置（RK3588生产环境）

```bash
# 1. 安装 sherpa-onnx
wget https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-v1.10.0-linux-arm64.tar.bz2
tar -xf sherpa-onnx-v1.10.0-linux-arm64.tar.bz2
sudo cp -r sherpa-onnx-v1.10.0-linux-arm64/* /usr/local/

# 2. 下载中文模型
mkdir -p /opt/tts_models
cd /opt/tts_models
wget https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-aishell3-icefall.tar.bz2
tar -xf vits-zh-aishell3-icefall.tar.bz2

# 3. 安装备用方案(eSpeak)
sudo apt-get install espeak-ng

# 4. 配置音频
sudo apt-get install alsa-utils
```

这样配置后，系统会优先使用高质量的sherpa-onnx，如果不可用则自动降级到eSpeak。
