# Phase 7.47.93 - 安装 gstreamer1.0-alsa 修复音频播放卡顿

## 日期
2026-03-04 19:40

## 问题描述
从 Phase 7.47.73（3月3日）至今，音频播放一直存在卡顿问题。尝试了多种修复方案均失败：
- Phase 7.47.73: 尝试 QSoundEffect → Docker 无 PulseAudio，完全无声
- Phase 7.47.75: dmix 采样率改为 24kHz → ES8388 不支持 24kHz，ALSA 初始化失败
- Phase 7.47.87: 移除 setSource(QUrl()) 管道重建 → GStreamer 管道残留，完全无声
- Phase 7.47.90: 延迟 play() 机制 → GStreamer 状态不同步，完全无声
- Phase 7.47.91-92: 修复采样率为 48kHz + TTS 重采样 → 有声音但仍卡顿

## 真正的根因

容器缺少 `gstreamer1.0-alsa` 包。GStreamer `autoaudiosink` 的音频输出回退链过长：

```
autoaudiosink 回退链（修复前）：
  ① PulseAudio sink → 失败（容器无 PulseAudio 服务）
  ② Jack sink       → 失败（容器无 Jack 服务）
  ③ OSS4 sink       → 失败（容器无 /dev/dsp）
  ④ PipeWire sink   → 失败（容器无 PipeWire）
  ⑤ OpenAL sink     → 成功（通过 OpenAL → ALSA 间接输出）

每次失败尝试约 20-30ms，共 4 次失败 ≈ 100ms 延迟
OpenAL 间接输出的缓冲管理不如 alsasink 直接，导致播放卡顿
```

安装 `gstreamer1.0-alsa` 后，`alsasink` 的 Rank 为 primary (256)，高于 OpenAL 的 secondary (128)：

```
autoaudiosink 回退链（修复后）：
  ① PulseAudio sink → 失败（容器无 PulseAudio 服务）
  ② alsasink        → 成功（直接访问 ALSA hw:1,0）

只有 1 次失败，alsasink 直接输出，无中间层
```

## 验证数据

### gst-launch 播放测试
| 场景 | 播放时间 | 文件时长 | 是否完整 |
|------|---------|---------|---------|
| 修复前（OpenAL 回退） | 2.130s | 2.312s | 结尾截断 0.18s |
| 修复后（alsasink 直接） | 2.314s | 2.312s | 完整播放 |

### 实际应用测试
- 修复前：播放"沿线急停"音频，中间有明显卡顿（十几毫秒停顿）
- 修复后：播放流畅，无卡顿，语音完整

## 修复方案

### 方案选择：应用层 Dockerfile 安装 deb 包

**不修改基础镜像**（重建需要 3-4 小时下载 PaddleSpeech 依赖），
在应用层 `Dockerfile.ubuntu24-apt` 中使用预下载的 .deb 文件安装：

```dockerfile
# 复制预下载的 deb 包
COPY packages/gstreamer1.0-alsa_1.24.2-1ubuntu0.3_arm64.deb /tmp/gstreamer1.0-alsa.deb
# dpkg 安装（不需要 apt-get update，依赖已在基础镜像中满足）
RUN dpkg -i /tmp/gstreamer1.0-alsa.deb && rm -f /tmp/gstreamer1.0-alsa.deb
```

### 依赖关系
gstreamer1.0-alsa 依赖 `libasound2t64` 和 `libgstreamer-plugins-base1.0-0`，
这两个包已在基础镜像中安装，`dpkg -i` 可以直接成功。

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| docker/rk3588/packages/gstreamer1.0-alsa_1.24.2-1ubuntu0.3_arm64.deb | 新增：预下载的 ARM64 deb 包（40KB）|
| Dockerfile.ubuntu24-apt | 新增：COPY deb + dpkg -i 安装 gstreamer1.0-alsa |
| build-ubuntu24-apt.ps1 | 新增：Step 2 中复制 packages/ 目录到 Docker 构建上下文 |

## 技术架构说明

```
Docker 镜像分层：
┌─────────────────────────────────────────────┐
│ 应用层 (Dockerfile.ubuntu24-apt)            │  ← 修改此层
│  + belt_control_system 二进制               │
│  + Qt6 库 / QML / 插件                      │
│  + TTS 引擎脚本                             │
│  + gstreamer1.0-alsa (新增，40KB deb)       │  ← 新增
│  构建时间：2-3 分钟                          │
├─────────────────────────────────────────────┤
│ 基础层 (Dockerfile.ubuntu24-base)           │  ← 不修改
│  + Ubuntu 24.04 ARM64                       │
│  + 系统库 + GStreamer + Python              │
│  + PaddleSpeech 依赖（pip install 80分钟）  │
│  构建时间：3-4 小时                          │
└─────────────────────────────────────────────┘
```

## 历史教训总结

3月3日到3月4日，共 6 个 Phase 尝试修复音频卡顿，全部针对"采样率"和"播放机制"：
- 采样率方向：24kHz（硬件不支持）→ 48kHz（正确但不是根因）
- 播放机制方向：QSoundEffect（Docker 不支持）→ 延迟播放（状态不同步）→ 管道优化（导致无声）

**真正的根因不在应用层代码，而在容器运行环境缺少关键 GStreamer 插件。**

关键发现方法：
```bash
# 检查 GStreamer 是否有 ALSA 插件
gst-inspect-1.0 | grep alsa    # 结果为空 → 没有安装

# 查看 autoaudiosink 实际回退过程
GST_DEBUG=3 gst-launch-1.0 filesrc location=/app/AUDIO/xxx.wav ! wavparse ! audioconvert ! audioresample ! autoaudiosink
# 日志显示 4 次失败尝试后回退到 OpenAL
```
