# TTS（文字转语音）功能完整分析报告

## 文档信息
- **创建时间**: 2026-02-11
- **分析范围**: Belt Control System 项目完整 TTS 功能
- **完善程度**: ⭐⭐⭐⭐ (4/5)

---

## 一、TTS 系统架构概览

项目实现了一个**多层次、多模式的 TTS 系统**，支持跨平台部署和多种音频输出方式。

### 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    应用层 (QML + C++)                        │
│  ├─ VoiceManagement.qml (语音管理界面)                      │
│  ├─ TTSConfigSection.qml (TTS配置UI)                       │
│  └─ CommonControl (起车预警、报警播放)                      │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│              控制层 (C++ 核心模块)                           │
│  ├─ SherpaOnnxTTS (主TTS引擎 - 进程通信模式)               │
│  ├─ AudioManagementController (音频管理)                   │
│  ├─ AlarmPlaybackService (报警播放服务)                    │
│  ├─ TTSConfigManager (配置管理 - 场景模式)                 │
│  └─ CrossPlatformTTS (跨平台适配层)                        │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│           TTS 服务进程 (独立可执行程序)                      │
│  ├─ sherpa_tts_service.exe (Windows MSVC编译)              │
│  ├─ sherpa_tts_service (Linux ARM64 GCC编译)               │
│  └─ JSON 通信协议 (stdin/stdout)                           │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│         Sherpa-ONNX 库 (ONNX Runtime + TTS模型)             │
│  ├─ libsherpa-onnx-cxx-api.so/dll                          │
│  ├─ libsherpa-onnx-c-api.so/dll                            │
│  └─ TTS 模型文件 (7个可选模型)                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、核心功能模块详解

### 2.1 SherpaOnnxTTS（主 TTS 引擎）

**文件位置**: `src/control/SherpaOnnxTTS.{h,cpp}`

**核心特性**:
- ✅ **进程通信模式**: 通过 QProcess 与独立 TTS 服务通信（解决 MinGW/MSVC ABI 不兼容）
- ✅ **JSON 协议**: 使用 JSON 格式的 stdin/stdout 通信
- ✅ **多模型支持**: 支持 7 个不同的 TTS 模型切换
- ✅ **网络传输**: 支持 TCP/UDP 双模式网络音频传输
- ✅ **智能缓存**: 持久化缓存机制（首次 1.9 秒，后续 <50ms）
- ✅ **说话人管理**: 支持多说话人模型（最多 804 个说话人）

**关键方法**:
```cpp
bool initialize(const QString &modelDir);           // 初始化引擎
bool switchModel(const QString &modelDir);          // 切换模型
void say(const QString &text);                      // 本地播放
void sayToNetwork(const QString &text, bool useTcp); // 网络传输
bool synthesizeToFile(const QString &text, const QString &outputFile); // 合成到文件
QString getCacheFilePath(const QString &text) const; // 获取缓存路径
void setSpeakerId(int speakerId);                   // 设置说话人
```

**支持的 TTS 模型**:

| 模型索引 | 模型名称 | 说话人数 | 采样率 | 特点 |
|---------|---------|--------|-------|------|
| 0 | vits-zh-aishell3 | 174 | 8kHz | 女声，多说话人 |
| 1 | vits-zh-hf-fanchen-wnj | 1 | 16kHz | 男声，高质量 |
| 2 | vits-zh-hf-fanchen-C | 187 | 16kHz | 女声，多说话人 |
| 3 | vits-zh-hf-theresa | 804 | 16kHz | 女声，超多说话人 |
| 4 | vits-zh-hf-eula | 804 | 16kHz | 女声，超多说话人 |
| 5 | sherpa-onnx-vits-zh-ll | 5 | 16kHz | 轻量级，5说话人 |
| 6 | vits-melo-tts-zh_en | 1 | 16kHz | 中英混合 |

---

### 2.2 TTSConfigManager（配置管理）

**文件位置**: `src/control/TTSConfigManager.{h,cpp}`

**功能**:
- 场景化配置（3 个独立场景）
- 持久化存储（QSettings）
- 动态模型切换

**三个场景**:
```cpp
enum Scene {
    StartupWarning = 0,  // 起车预警（1-10号皮带）
    FaultAlarm = 1,      // 故障报警（保护装置触发）
    Test = 2             // 测试（参数设置界面）
};
```

**每个场景的配置**:
- modelIndex: 选择的模型（0-6）
- modelPath: 模型文件路径
- speakerId: 说话人 ID
- rate: 语速（0.5-2.0）
- volume: 音量（0.0-1.0）

---

### 2.3 AlarmPlaybackService（报警播放服务）

**文件位置**: `src/control/AlarmPlaybackService.{h,cpp}`

**功能**:
- 接收保护监控服务的报警触发信号
- 支持音频文件播放或 TTS 语音播放
- 支持重复播放（playCount）和持续播放（playDuration）
- 播放队列管理（避免同时播放多个报警）
- TTS 缓存机制（10 个常见报警文本预缓存）

**报警播放模式**:
```cpp
// 模式1: 重复播放
playMode = "count"
playCount = 3  // 播放3次

// 模式2: 持续播放
playMode = "duration"
playDuration = 5.0  // 持续5秒
```

**预缓存的报警文本**:
1. 急停保护报警
2. 主机急停保护报警
3. 沿线急停
4. 打滑保护报警
5. 跑偏保护报警
6. 堆煤保护报警
7. 撕裂保护报警
8. 超速保护报警
9. 低速保护报警
10. 温度保护报警

---

### 2.4 AudioManagementController（音频管理控制器）

**文件位置**: `src/control/AudioManagementController.{h,cpp}`

**功能**:
- 音频文件扫描和管理
- 批量识别（ASR）和生成（TTS）
- 进度管理和状态跟踪

**文件状态流**:
```
Pending → Recognizing → Recognized → Generating → Generated
                                          ↓
                                       Failed
```

---

### 2.5 CrossPlatformTTS（跨平台适配层）

**文件位置**: `src/control/CrossPlatformTTS.{h,cpp}`

**支持的后端**:
- QtTTS: Windows SAPI / Linux speech-dispatcher
- ESpeak: 轻量级 Linux 方案
- SherpaOnnx: 高质量离线方案（当前主要使用）
- OnlineAPI: 在线 API（百度/讯飞等）

---

## 三、TTS 服务进程

**文件位置**: `src/tts_service/sherpa_tts_service.cpp`

**特点**:
- 独立可执行程序（Windows MSVC 编译，Linux GCC 编译）
- JSON 通信协议
- 支持多个命令：init、synthesize、stop
- 自动模型加载和卸载

**通信协议示例**:

```json
// 初始化命令
{
  "command": "init",
  "model_dir": "/app/tts_models/vits-zh-aishell3"
}

// 合成命令
{
  "command": "synthesize",
  "text": "皮带启动",
  "output_path": "/tmp/output.wav",
  "rate": 1.0,
  "speaker_id": 0
}

// 停止命令
{
  "command": "stop"
}
```

**响应格式**:
```json
{
  "success": true,
  "message": "TTS engine initialized successfully. Sample rate: 8000Hz"
}
```

---

## 四、网络音频传输集成

**架构**:
```
SherpaOnnxTTS::sayToNetwork()
    ↓
创建临时 WAV 文件 (QTemporaryFile)
    ↓
调用 synthesize() 合成语音
    ↓
选择发送器 (TCP 或 UDP)
    ↓
AudioNetworkTcpSender / AudioNetworkSender
    ├─ FFmpeg 解码 WAV → PCM
    ├─ Opus 编码 PCM → 20ms 帧
    └─ 独立线程发送到网络
```

**支持的传输模式**:
- **TCP**: 发送到上位机（192.168.1.4:8000）
- **UDP**: 发送到音频模块（224.1.x.1:8800）

**网络传输流程**:
1. TTS 合成语音到临时 WAV 文件
2. FFmpeg 解码 WAV 为 PCM（16kHz, 单声道）
3. Opus 编码 PCM 为 20ms 音频帧
4. 通过 TCP/UDP 发送到网络
5. 接收端解码并播放

---

## 五、QML 用户界面

### 5.1 VoiceManagement.qml（语音管理页面）

**位置**: `src/qml/pages/VoiceManagement.qml`

**功能**:
- TTS 模型配置
- 音频文件管理
- 批量识别和生成

**主要区域**:
1. **TTS 配置区**: 模型选择、说话人、语速、音量
2. **音频文件列表**: 显示所有音频文件及状态
3. **批量操作**: 批量识别、批量生成
4. **测试区**: 测试语音合成效果

---

### 5.2 TTSConfigSection.qml（TTS 配置区域）

**位置**: `src/qml/components/voice_management/TTSConfigSection.qml`

**控件**:
- **模型选择下拉框**: 7 个模型可选
- **说话人 ID 输入框**: 0 到最大说话人数
- **语速滑块**: 0.5-2.0（默认 1.0）
- **音量滑块**: 0.0-1.0（默认 1.0）
- **测试语音按钮**: 测试当前配置

**场景切换**:
```qml
ComboBox {
    model: ["起车预警", "故障报警", "测试"]
    onCurrentIndexChanged: {
        ttsConfigManager.loadScene(currentIndex)
    }
}
```

---

## 六、TTS 缓存机制

**缓存策略**:
- **缓存目录**: `/app/appdata/tts_cache/`
- **文件命名**: `network_{qHash}.wav`
- **持久化**: 重启后仍有效
- **预热机制**: 系统启动时预热 1-10 号皮带文本

**缓存流程**:
```cpp
QString SherpaOnnxTTS::getCacheFilePath(const QString &text) const {
    QString cacheDir = "/app/appdata/tts_cache";
    uint hash = qHash(text);
    return QString("%1/network_%2.wav").arg(cacheDir).arg(hash);
}

void SherpaOnnxTTS::sayToNetwork(const QString &text, bool useTcp) {
    QString cacheFile = getCacheFilePath(text);
    
    if (QFile::exists(cacheFile)) {
        // 使用缓存文件（<50ms）
        sendAudioFile(cacheFile, useTcp);
    } else {
        // 合成新文件（~1.9s）
        synthesizeToFile(text, cacheFile);
        sendAudioFile(cacheFile, useTcp);
    }
}
```

**性能对比**:
- **首次合成**: ~1.9 秒
- **缓存播放**: <50 毫秒
- **性能提升**: 约 38 倍

---

## 七、编译和构建配置

### 7.1 CMake 选项

```cmake
# 启用 Sherpa-ONNX TTS
cmake -DENABLE_SHERPA_ONNX=ON ..

# 指定库路径（交叉编译）
cmake -DENABLE_SHERPA_ONNX=ON \
      -DSHERPA_ONNX_LIB_DIR=/opt/rk3588-libs/lib ..
```

### 7.2 库依赖

**运行时依赖**:
- libsherpa-onnx-cxx-api.so/dll
- libsherpa-onnx-c-api.so/dll
- Qt6::Multimedia
- Qt6::TextToSpeech（备用）

**编译时依赖**:
- ONNX Runtime
- Sherpa-ONNX 头文件

### 7.3 TTS 服务编译

**Windows (MSVC)**:
```bash
cd src/tts_service
mkdir build && cd build
cmake -G "Visual Studio 17 2022" ..
cmake --build . --config Release
```

**Linux (GCC)**:
```bash
cd src/tts_service
mkdir build && cd build
cmake ..
make -j$(nproc)
```

---

## 八、当前实现的完善程度

### ✅ 已实现功能

#### 1. 核心 TTS 引擎
- ✅ 7 个 TTS 模型支持
- ✅ 多说话人支持（最多 804 个）
- ✅ 语速和音量调整
- ✅ 模型动态切换

#### 2. 音频输出
- ✅ 本地播放（QMediaPlayer）
- ✅ 网络传输（TCP/UDP）
- ✅ 文件合成

#### 3. 缓存机制
- ✅ 智能缓存（首次 1.9s，后续 <50ms）
- ✅ 持久化存储
- ✅ 预热机制

#### 4. 场景配置
- ✅ 起车预警配置
- ✅ 故障报警配置
- ✅ 测试配置

#### 5. 报警集成
- ✅ 报警播放服务
- ✅ 播放队列管理
- ✅ 重复播放和持续播放

#### 6. 用户界面
- ✅ 语音管理页面
- ✅ TTS 配置界面
- ✅ 模型选择和参数调整

#### 7. 跨平台支持
- ✅ Windows（MSVC 编译的独立服务）
- ✅ Linux ARM64（RK3588 交叉编译）
- ✅ Linux x86_64

---

### ⚠️ 存在的问题或限制

#### 1. 模型文件大小
- **问题**: 每个模型 100-200MB
- **影响**: 部署时需要充足的存储空间
- **建议**: 提供模型下载管理界面

#### 2. 首次合成延迟
- **问题**: 首次合成需要 1.9 秒
- **影响**: 用户体验不够流畅
- **建议**: 系统启动时预加载模型

#### 3. 说话人 ID 管理
- **问题**: 不同模型的说话人 ID 范围不同
- **影响**: 需要手动配置最大 ID
- **建议**: 自动检测模型说话人数量

#### 4. ASR（语音识别）
- **问题**: AudioManagementController 支持框架，但实际 ASR 实现不完整
- **影响**: 无法批量识别音频文件
- **建议**: 集成 Sherpa-ONNX ASR 模型

#### 5. 在线 API 支持
- **问题**: CrossPlatformTTS 中有框架，但未实现具体的百度/讯飞 API
- **影响**: 无法使用在线 TTS 服务
- **建议**: 实现在线 API 作为备选方案

---

## 九、改进方向和建议

### 🎯 优先级 1：完善 ASR（语音识别）功能

**当前状态**: 框架完整但实现不完整

**建议实施步骤**:
1. 集成 Sherpa-ONNX ASR 模型
2. 实现音频文件批量识别
3. 添加实时语音识别功能
4. 创建 ASR 配置界面

**预期效果**:
- 支持音频文件自动转文字
- 支持实时语音输入
- 完善语音管理功能

---

### 🎯 优先级 2：优化首次合成延迟

**当前问题**: 首次合成需要 1.9 秒

**建议实施步骤**:
1. **系统启动时预加载模型**
   ```cpp
   // 在 main.cpp 中添加
   QTimer::singleShot(1000, []() {
       sherpaOnnxTTS->preloadModel();
   });
   ```

2. **实现模型热切换**（不卸载旧模型）
   ```cpp
   // 保留多个模型在内存中
   QMap<QString, SherpaOnnxModel*> m_loadedModels;
   ```

3. **并行合成多个文本**
   ```cpp
   // 使用线程池并行合成
   QThreadPool::globalInstance()->start(new SynthesizeTask(text));
   ```

**预期效果**:
- 首次合成延迟降低到 <500ms
- 模型切换更流畅
- 支持批量合成

---

### 🎯 优先级 3：添加模型管理界面

**当前问题**: 模型文件大（100-200MB），部署复杂

**建议实施步骤**:
1. **创建模型管理页面**
   - 显示已安装模型列表
   - 显示模型大小和说话人数
   - 支持模型下载和删除

2. **实现模型在线下载**
   ```cpp
   class ModelDownloader : public QObject {
       Q_OBJECT
   public:
       void downloadModel(const QString &modelName);
   signals:
       void downloadProgress(int percent);
       void downloadFinished(bool success);
   };
   ```

3. **添加缓存清理工具**
   ```cpp
   void clearTTSCache() {
       QDir cacheDir("/app/appdata/tts_cache");
       cacheDir.removeRecursively();
   }
   ```

**预期效果**:
- 用户可按需下载模型
- 减少初始部署大小
- 方便管理存储空间

---

### 🎯 优先级 4：实现在线 API 备选方案

**当前状态**: CrossPlatformTTS 有框架但未实现

**建议实施步骤**:
1. **集成百度 TTS API**
   ```cpp
   class BaiduTTS : public OnlineTTSBackend {
   public:
       void synthesize(const QString &text) override;
   private:
       QString m_apiKey;
       QString m_secretKey;
   };
   ```

2. **集成讯飞 TTS API**
   ```cpp
   class XunfeiTTS : public OnlineTTSBackend {
   public:
       void synthesize(const QString &text) override;
   private:
       QString m_appId;
       QString m_apiKey;
   };
   ```

3. **实现自动切换机制**
   ```cpp
   // 离线模型不可用时自动切换到在线 API
   if (!sherpaOnnxTTS->isAvailable()) {
       useBaiduTTS();
   }
   ```

**预期效果**:
- 提供在线 TTS 备选方案
- 提高系统可靠性
- 支持更多语音选择

---

## 十、关键文件清单

| 文件路径 | 功能 | 行数 |
|---------|------|------|
| src/control/SherpaOnnxTTS.h | TTS 引擎头文件 | 146 |
| src/control/SherpaOnnxTTS.cpp | TTS 引擎实现 | ~600 |
| src/control/TTSConfigManager.h | 配置管理头文件 | 83 |
| src/control/TTSConfigManager.cpp | 配置管理实现 | ~150 |
| src/control/AlarmPlaybackService.h | 报警服务头文件 | 137 |
| src/control/AlarmPlaybackService.cpp | 报警服务实现 | ~400 |
| src/control/AudioManagementController.h | 音频管理头文件 | 136 |
| src/control/AudioManagementController.cpp | 音频管理实现 | ~300 |
| src/control/CrossPlatformTTS.h | 跨平台适配头文件 | 97 |
| src/control/CrossPlatformTTS.cpp | 跨平台适配实现 | ~200 |
| src/tts_service/sherpa_tts_service.cpp | TTS 服务进程 | ~400 |
| src/qml/pages/VoiceManagement.qml | 语音管理界面 | ~300 |
| src/qml/components/voice_management/TTSConfigSection.qml | TTS 配置界面 | ~400 |

---

## 十一、使用示例

### 11.1 基本使用

```cpp
// 初始化 TTS 引擎
SherpaOnnxTTS *tts = new SherpaOnnxTTS(this);
tts->initialize("/app/tts_models/vits-zh-aishell3");

// 本地播放
tts->say("皮带启动");

// 网络传输（TCP）
tts->sayToNetwork("皮带启动", true);

// 合成到文件
tts->synthesizeToFile("皮带启动", "/tmp/output.wav");
```

### 11.2 场景配置

```cpp
// 加载起车预警场景
TTSConfigManager *configManager = new TTSConfigManager(this);
configManager->loadScene(TTSConfigManager::StartupWarning);

// 获取配置
int modelIndex = configManager->getModelIndex();
int speakerId = configManager->getSpeakerId();
double rate = configManager->getRate();

// 应用配置
tts->switchModel(configManager->getModelPath());
tts->setSpeakerId(speakerId);
tts->setRate(rate);
```

### 11.3 报警播放

```cpp
// 创建报警播放服务
AlarmPlaybackService *alarmService = new AlarmPlaybackService(this);
alarmService->setTTS(tts);

// 播放报警（重复3次）
alarmService->playAlarm("急停保护报警", "count", 3, 0);

// 播放报警（持续5秒）
alarmService->playAlarm("打滑保护报警", "duration", 0, 5.0);
```

---

## 十二、总体评价

### 完善程度: ⭐⭐⭐⭐ (4/5)

**优势**:
- ✅ 架构设计合理，分层清晰
- ✅ 支持多个高质量 TTS 模型
- ✅ 缓存机制有效降低延迟
- ✅ 网络传输功能完整
- ✅ 跨平台支持良好
- ✅ 与报警系统集成完善

**不足**:
- ⚠️ ASR 功能框架完整但实现不完整
- ⚠️ 在线 API 支持不完整
- ⚠️ 模型文件较大，部署复杂
- ⚠️ 首次合成延迟仍然较长

**总结**:
项目的 TTS 功能已经非常完善，核心功能全部实现，性能优化到位，用户界面友好。主要的改进空间在于完善 ASR 功能、优化首次加载性能、添加模型管理界面和实现在线 API 备选方案。

---

## 十三、下一步工作建议

根据优先级，建议按以下顺序进行改进：

1. **完善 ASR 功能**（优先级最高）
   - 集成 Sherpa-ONNX ASR 模型
   - 实现音频文件批量识别
   - 添加实时语音识别

2. **优化首次合成延迟**
   - 系统启动时预加载模型
   - 实现模型热切换
   - 并行合成多个文本

3. **添加模型管理界面**
   - 创建模型管理页面
   - 实现模型在线下载
   - 添加缓存清理工具

4. **实现在线 API 备选方案**
   - 集成百度 TTS API
   - 集成讯飞 TTS API
   - 实现自动切换机制

---

**文档版本**: v1.0  
**最后更新**: 2026-02-11  
**作者**: Claude Sonnet 4.5
