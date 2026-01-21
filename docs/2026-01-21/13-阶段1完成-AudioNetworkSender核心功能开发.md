# 阶段 1 完成 - AudioNetworkSender 核心功能开发

**日期**: 2026-01-21 20:10
**状态**: ✅ 核心功能全部实现完成
**下一步**: 集成到 CommonControl（阶段 2）

---

## 📦 实施成果

### 创建的文件

1. **src/audio_network/AudioNetworkSender.h** - 完整类定义
   - 接口设计：配置、播放、停止
   - 信号定义：播放状态、进度、错误
   - 完整文档注释

2. **src/audio_network/AudioNetworkSender.cpp** - 核心实现
   - ✅ FFmpeg 音频解码（阶段 1.2）
   - ✅ Opus 编码（阶段 1.3）
   - ✅ UDP 组播发送（阶段 1.4）

3. **src/audio_network/CMakeLists.txt** - 编译配置
   - 链接 FFmpeg 库（libavcodec, libavformat, libavutil, libswresample）
   - 链接 Opus 库（libopus）
   - 链接 Qt 网络模块（Qt6::Network）

4. **CMakeLists.txt** - 更新顶层配置
   - 添加 `add_subdirectory(src/audio_network)`

5. **src/main/CMakeLists.txt** - 更新链接
   - 添加 `audio_network` 模块链接

---

## ✅ 功能实现清单

### 1.1 类框架（完成）

- [x] AudioNetworkSender 类定义
- [x] 构造/析构函数（自动初始化 UDP socket、定时器）
- [x] 配置接口（`setUdpMulticastAddress`, `setOpusBitrate`）
- [x] 播放接口（`playAudioToNetwork`, `stopPlayback`, `isPlaying`）
- [x] 信号定义（播放状态、进度、错误）
- [x] CMake 配置（链接 FFmpeg + Opus + Qt Network）

### 1.2 FFmpeg 音频解码（完成）

**实现位置**: `AudioNetworkSender::decodeAudioFile()` (Line 217-419)

**功能**:
- ✅ 打开音频文件（支持 MP3, WAV, OGG 等所有 FFmpeg 支持的格式）
- ✅ 查找音频流
- ✅ 初始化解码器
- ✅ 初始化重采样器（兼容 FFmpeg 6.x `AVChannelLayout` API）
- ✅ 解码音频帧并重采样到 16kHz, 16bit, mono
- ✅ 刷新解码器和重采样器（获取剩余帧）
- ✅ 异常安全（自动清理 FFmpeg 资源）

**关键技术**:
```cpp
// FFmpeg 6.x 新 API（AVChannelLayout）
AVChannelLayout in_ch_layout = codecCtx->ch_layout;
AVChannelLayout out_ch_layout = AV_CHANNEL_LAYOUT_MONO;

swr_alloc_set_opts2(&swrCtx,
    &out_ch_layout, AV_SAMPLE_FMT_S16, 16000,  // 输出
    &in_ch_layout, codecCtx->sample_fmt, codecCtx->sample_rate,  // 输入
    0, nullptr);
```

**输出**:
- PCM 数据（`QByteArray`）：16kHz, 16bit, 单声道
- 元数据：采样率、声道数、时长（毫秒）

### 1.3 Opus 编码（完成）

**实现位置**: `AudioNetworkSender::encodeToOpus()` (Line 421-524)

**功能**:
- ✅ 检查音频参数（16kHz, 单声道）
- ✅ 初始化 Opus 编码器（`OPUS_APPLICATION_VOIP` 低延迟模式）
- ✅ 设置比特率（默认 16kbps，可调 16-32kbps）
- ✅ 切分 PCM 为 20ms 帧（320 样本 @ 16kHz）
- ✅ 逐帧编码为 Opus（每帧约 40 字节 @ 16kbps）
- ✅ 统计信息（总帧数、平均帧大小、实际比特率）

**关键参数**:
```cpp
opus_encoder_create(
    16000,                      // 采样率 16kHz
    1,                          // 单声道
    OPUS_APPLICATION_VOIP,      // 语音模式（低延迟）
    &error
);

opus_encoder_ctl(m_opusEncoder, OPUS_SET_BITRATE(16000));  // 16kbps
```

**输出**:
- Opus 帧列表（`QList<QByteArray>`）
- 每帧 20ms（320 样本）
- 每帧约 40 字节 @ 16kbps（实际比特率可能略有波动）

### 1.4 UDP 组播发送（完成）

**实现位置**:
- `AudioNetworkSender::sendNextFrame()` (Line 538-567)
- `AudioNetworkSender::onFrameTimerTimeout()` (Line 197-211)

**功能**:
- ✅ QUdpSocket 绑定（`QHostAddress::AnyIPv4:0`）
- ✅ 设置组播 TTL = 1（局域网内）
- ✅ 20ms 精确定时器（`Qt::PreciseTimer`）
- ✅ 逐帧发送 UDP 组播（目标：224.1.1.1:8800）
- ✅ 发送进度信号（每帧触发 `playbackProgress`）
- ✅ 发送完成信号（`playbackFinished`）
- ✅ 网络错误处理（`networkError` 信号）

**关键代码**:
```cpp
// 每 20ms 发送一帧
m_frameTimer->start(20);

// 发送到组播地址
m_udpSocket->writeDatagram(
    opusFrame.constData(),
    opusFrame.size(),
    QHostAddress("224.1.1.1"),
    8800
);
```

**日志**:
- 每 50 帧（1 秒）打印一次进度

---

## 🔧 技术亮点

### 1. FFmpeg 6.x 兼容性

使用最新的 `AVChannelLayout` API（替代旧的 `channel_layout`）：
```cpp
AVChannelLayout in_ch_layout = codecCtx->ch_layout;      // 新 API
AVChannelLayout out_ch_layout = AV_CHANNEL_LAYOUT_MONO;

swr_alloc_set_opts2(&swrCtx, ...);  // 新 API（FFmpeg 6.0+）
```

### 2. 异常安全

所有 FFmpeg 资源自动清理：
```cpp
try {
    // FFmpeg 操作...
} catch (...) {
    // 清理资源
    if (frame) av_frame_free(&frame);
    if (packet) av_packet_free(&packet);
    if (swrCtx) swr_free(&swrCtx);
    if (codecCtx) avcodec_free_context(&codecCtx);
    if (formatCtx) avformat_close_input(&formatCtx);
    throw;  // 重新抛出
}
```

### 3. 自动重采样

支持任意输入格式，自动转换为目标格式：
- **输入**：任意采样率（8kHz - 192kHz）、任意声道（单声道/立体声/5.1）、任意格式（float/int16/int32）
- **输出**：统一 16kHz, 16bit, 单声道

### 4. Opus 低延迟模式

使用 `OPUS_APPLICATION_VOIP`：
- 优化语音清晰度（相比音乐模式）
- 降低编码延迟（<10ms）
- 适合实时传输

### 5. 精确定时器

使用 Qt `PreciseTimer`：
- 20ms 精度
- 确保稳定的 50 帧/秒发送速率

---

## 📊 性能评估

### 编码性能

**测试场景**：5 秒 MP3 文件（44.1kHz, 立体声, 128kbps）

| 步骤 | 预计耗时 | 内存占用 |
|------|---------|---------|
| **FFmpeg 解码 + 重采样** | ~50ms | ~200KB |
| **Opus 编码（250 帧）** | ~20ms | ~10KB |
| **UDP 发送（批量）** | 5000ms（实时播放） | ~40KB 缓冲 |
| **总计** | ~5070ms | ~250KB |

**CPU 占用**（预估）：
- 解码 + 编码：<5% CPU（RK3588）
- UDP 发送：<1% CPU

### 带宽占用

| 比特率 | 每帧大小 | 每秒带宽 | 备注 |
|--------|---------|---------|------|
| **16 kbps** | ~40 字节 | 2 KB/s | 清晰（推荐）|
| **24 kbps** | ~60 字节 | 3 KB/s | 良好 |
| **32 kbps** | ~80 字节 | 4 KB/s | 高质量 |

**结论**：100Mbps 网络可支持数百路音频同时传输 ✅

---

## 🚀 下一步计划（阶段 2）

### 2.1 集成到 CommonControl（0.5 天）

**修改文件**: `src/control/CommonControl.h` 和 `.cpp`

**任务**:
1. 添加 `AudioNetworkSender* m_audioNetworkSender` 成员变量
2. 添加 `AudioOutputMode` 枚举：`LocalOnly`, `NetworkOnly`, `DualOutput`
3. 修改 `playAudio()` 方法：
   ```cpp
   switch (m_audioOutputMode) {
       case LocalOnly:
           m_mediaPlayer->play();  // 本地 ES8388
           break;
       case NetworkOnly:
           m_audioNetworkSender->playAudioToNetwork(audioPath);  // 网络
           break;
       case DualOutput:
           m_mediaPlayer->play();  // 本地
           m_audioNetworkSender->playAudioToNetwork(audioPath);  // 网络（同时）
           break;
   }
   ```
4. 连接信号槽（监听播放状态）

### 2.2 配置持久化（0.5 天）

**修改文件**: `src/control/CommonControl.cpp`

**任务**:
1. 添加 QSettings 配置项：
   - `audio/outputMode`: "local" / "network" / "dual"
   - `audio/networkMulticastAddress`: "224.1.1.1"
   - `audio/networkPort`: 8800
   - `audio/opusBitrate`: 16000-32000
2. 实现 `loadAudioSettings()` 和 `saveAudioSettings()` 方法
3. 在构造函数中加载配置

---

## 📝 技术债务

### 低优先级优化

1. **实时发送模式**：
   - 当前：批量发送（解码全部 → 编码全部 → 定时发送）
   - 备选：实时发送（边解码边编码边发送）
   - **触发条件**：如果首帧延迟 >500ms

2. **TTS 集成测试**：
   - 当前：理论上支持（Sherpa-ONNX → WAV → 网络）
   - 待测试：实际 TTS 输出（采样率可能不是 16kHz）

3. **网络错误重传**：
   - 当前：发送失败仅记录日志
   - 备选：添加简单的重传机制（如果音频模块支持）

---

## 🎯 总结

**阶段 1 完成情况**：✅ **100%**

- ✅ 类框架（0.5 天完成）
- ✅ FFmpeg 解码（1 天完成）
- ✅ Opus 编码（1 天完成）
- ✅ UDP 发送（1 天完成）

**代码质量**：
- ✅ 异常安全
- ✅ 资源自动管理
- ✅ 详细日志
- ✅ 完整文档注释

**下一步**：
- 继续阶段 2：集成到 CommonControl（预计 1 天）

---

**创建时间**: 2026-01-21 20:10
**作者**: Claude AI
**状态**: ✅ 核心功能全部实现完成
