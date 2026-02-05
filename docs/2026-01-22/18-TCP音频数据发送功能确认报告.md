# TCP 音频数据发送功能确认报告

**文档编号**: 18
**日期**: 2026-01-22 16:50
**版本**: v1.0
**优先级**: **P0** (立即确认)

---

## ✅ 结论：TCP 音频发送功能已实现，但未启用

**确认结果**:
1. ✅ **代码已实现**：TCP 音频数据发送功能完整实现
2. ❌ **未启用**：当前使用的是 `DualOutput` 模式（本地 + UDP），不是 `NetworkTcp` 模式
3. ✅ **功能正常**：TCP 连接、WebSocket 握手、心跳机制均工作正常
4. ⏸️ **待启用**：需要切换音频输出模式为 `NetworkTcp` 才能发送 TCP 音频数据

---

## 📋 代码分析

### 1. TCP 音频发送实现（AudioNetworkTcpSender.cpp）

**文件**: `src/audio_network/AudioNetworkTcpSender.cpp`

**关键代码**: 第 815-867 行

```cpp
void AudioNetworkTcpSender::sendNextFrame()
{
    // ✅ 检查是否已播放完成
    if (!m_isPlaying || m_currentFrameIndex >= m_currentFrames.size()) {
        qDebug() << "✅ 所有帧发送完成";
        stopPlayback();
        emit playbackFinished();
        return;
    }

    // ✅ 发送当前帧（WebSocket BINARY 帧）← 关键代码！
    static QElapsedTimer timer;
    if (!timer.isValid()) {
        timer.start();
    }
    qint64 currentTime = timer.elapsed();

    const QByteArray& opusFrame = m_currentFrames[m_currentFrameIndex];
    m_wsClient->sendBinaryFrame(opusFrame);  // ← 第 836 行：确实在发送 BINARY 帧！

    // ✅ 计算下一帧的绝对发送时间
    m_currentFrameIndex++;

    // 核心公式：下一帧应该发送的绝对时间戳
    // 公式：startTime + frameIndex * 20ms
    qint64 nextFrameAbsoluteTime = m_sendStartTime + m_currentFrameIndex * 20;
    qint64 delay = nextFrameAbsoluteTime - currentTime;

    // ✅ 调试日志（每 50 帧打印一次）← 应该在日志中看到！
    if ((m_currentFrameIndex - 1) % 50 == 0) {
        qDebug() << "   📡 已发送:" << (m_currentFrameIndex - 1) << "/" << m_totalFrames
                 << "帧（" << currentTime << "ms）";
        qDebug() << "      下一帧延迟:" << delay << "ms";
    }

    // 触发进度信号
    emit playbackProgress(m_currentFrameIndex, m_totalFrames);

    // 调度下一帧发送
    if (delay > 0) {
        // 延迟发送（正常情况）
        QTimer::singleShot(delay, this, &AudioNetworkTcpSender::sendNextFrame);
    } else {
        // 已经延迟了，立即发送
        if (delay < -10) {
            qWarning() << "⚠️ 严重延迟（帧" << m_currentFrameIndex << "）: 已延迟" << (-delay) << "ms";
        }
        QTimer::singleShot(0, this, &AudioNetworkTcpSender::sendNextFrame);
    }
}
```

**分析**:
- ✅ 第 836 行：`m_wsClient->sendBinaryFrame(opusFrame);` → **确实在发送 WebSocket BINARY 帧**
- ✅ 第 848-851 行：调试日志（每 50 帧打印一次）→ **应该在日志中看到，但实际没有**
- ✅ 音频帧发送逻辑完整：解码 → 编码 → 分帧 → 定时发送
- ✅ 绝对时间戳控制算法（复用 `AudioNetworkSender` 的成熟逻辑）

### 2. 调用链（CommonControl.cpp）

**文件**: `src/control/CommonControl.cpp`

**关键代码**: 第 190-297 行

```cpp
void CommonControl::playAudio(const QString &audioPath)
{
    // ...省略前面的代码...

    // 根据音频输出模式选择播放方式
    switch (m_audioOutputMode) {
        case LocalOnly: {
            // 仅本地播放
            qDebug() << "   [本地播放] 仅本地播放，不发送网络";
            break;
        }

        case NetworkOnly: {
            // 仅发送到网络音频模块（UDP 组播）
            qDebug() << "   [网络发送] 开始发送到音频模块（224.1.1.1:8800）...";
            m_audioNetworkSender->playAudioToNetwork(audioPath);  // ← UDP 组播
            break;
        }

        case DualOutput: {
            // 本地 + 网络同时（默认模式）
            qint64 networkTime = timer.elapsed();
            m_audioNetworkSender->playAudioToNetwork(audioPath);  // ← UDP 组播
            qDebug() << "      网络发送启动耗时:" << (timer.elapsed() - networkTime) << "ms";
            break;
        }

        case NetworkTcp: {  // ← TCP 模式（新增）
            // TCP 网络模式
            qDebug() << "   [TCP发送] 开始发送到 TCP 音频模块...";
            if (m_audioNetworkTcpSender->isConnected()) {
                m_audioNetworkTcpSender->playAudioToNetwork(audioPath);  // ← TCP 发送
            } else {
                qWarning() << "   [TCP发送] ❌ 未连接到 TCP 服务器，无法播放";
            }
            break;
        }
    }

    qDebug() << "   [总计] playAudio() 总耗时:" << timer.elapsed() << "ms";
}
```

**分析**:
- ✅ 第 289 行：`m_audioNetworkTcpSender->playAudioToNetwork(audioPath);` → **确实调用了 TCP 发送**
- ❌ 但是当前模式是 `DualOutput`（第 29 行默认值），不是 `NetworkTcp`
- ✅ 日志应该显示 `[TCP发送]`，但实际显示的是 `[本地播放]` 或 `[网络发送]`

### 3. 音频输出模式枚举

**文件**: `src/control/CommonControl.h`

```cpp
enum AudioOutputMode {
    LocalOnly,      // 仅本地播放
    NetworkOnly,    // 仅 UDP 组播网络发送
    DualOutput,     // 本地 + UDP 网络（默认）← 当前使用这个
    NetworkTcp      // TCP 网络模式（新增）← 需要切换到这个
};

// 默认模式（第 29 行）
, m_audioOutputMode(DualOutput)  // 默认：本地 + 网络同时输出
```

---

## 📊 日志证据分析

### voip.md 日志分析

**期望看到的日志**（TCP 模式）:
```
[DEBUG] 🎵 开始播放音频到网络: /app/AUDIO/1#PD/1号皮带启动.mp3
[DEBUG] 📡 开始发送 Opus 帧（总 326 帧）
[DEBUG]    📡 已发送: 0 / 326 帧（ 158 ms）
[DEBUG]       下一帧延迟: 20 ms
[DEBUG]    📡 已发送: 50 / 326 帧（ 1158 ms）
[DEBUG]       下一帧延迟: 18 ms
...
[DEBUG] ✅ 所有帧发送完成
```

**实际看到的日志**（UDP 模式）:
```
[DEBUG]    [3/3] 开始发送 UDP 组播...  ← 只有 UDP 组播
[DEBUG]    总帧数: 326 帧
[DEBUG]    预计时长: 6520 ms
[DEBUG]    目标地址: "224.1.10.1" : 8800
[DEBUG]    📡 已发送: 0 / 326 帧（ 158 ms）
[DEBUG]    ✅ 发送已启动（绝对时间戳控制模式）
```

**分析**:
- ❌ 没有看到 `🎵 开始播放音频到网络` → 说明没有调用 `AudioNetworkTcpSender::playAudioToNetwork()`
- ❌ 没有看到 `📡 开始发送 Opus 帧` → 说明没有进入 TCP 发送流程
- ✅ 只看到 UDP 组播日志 → 说明当前使用的是 `DualOutput` 或 `NetworkOnly` 模式
- ✅ TCP 连接、WebSocket 握手、心跳机制均正常 → 说明基础设施工作正常

---

## 🎯 根本原因

**原因**：
1. 音频输出模式默认是 `DualOutput`（本地 + UDP 网络）
2. **没有切换到 `NetworkTcp` 模式**
3. 因此 `playAudio()` 走的是 `DualOutput` 分支，调用的是 `m_audioNetworkSender->playAudioToNetwork()`（UDP 组播）
4. **从未调用** `m_audioNetworkTcpSender->playAudioToNetwork()`（TCP 发送）

**证据**：
- 日志中只看到 UDP 组播发送（224.1.10.1:8800）
- 日志中没有 `[TCP发送]` 相关日志
- 日志中没有 `📡 已发送: X / Y 帧` 的 TCP 发送进度日志

---

## 🔧 解决方案

### 方案 1: 手动切换音频输出模式（测试用）

在 `main.cpp` 或 QML 中添加：

```cpp
// 在 CommonControl 初始化后
commonControl->setAudioOutputMode(CommonControl::NetworkTcp);
```

### 方案 2: 实现 TCP/UDP 智能切换策略（生产环境）

根据用户需求，实现智能切换逻辑：

1. **优先使用 TCP**:
   - 如果连接上位机服务端成功 → 自动切换到 `NetworkTcp` 模式
   - 只使用 TCP 发送音频数据，**不使用 UDP 组播**

2. **自动降级到 UDP**:
   - 如果 TCP 连接 2-3 秒无响应 → 自动切换到 `DualOutput` 或 `NetworkOnly` 模式
   - 使用 UDP 组播发送音频数据

3. **定期重试 TCP**:
   - UDP 模式下，每 10 秒重试 TCP 连接
   - 一旦连接成功，自动切换回 `NetworkTcp` 模式

**实现细节见**：[17-音频网络传输日志深度分析报告.md](./17-音频网络传输日志深度分析报告.md#架构设计)

---

## 📋 下一步行动

### 选项 A: 立即测试 TCP 音频发送功能（快速验证）

**目的**：验证 TCP 音频发送功能是否正常工作

**步骤**：
1. 修改 `CommonControl.cpp`，将默认模式改为 `NetworkTcp`：
   ```cpp
   , m_audioOutputMode(NetworkTcp)  // 测试：强制使用 TCP 模式
   ```
2. 重新编译部署
3. 测试音频播放
4. 检查日志：应该看到 `[TCP发送]` 和 `📡 已发送: X / Y 帧`

**预计耗时**: 10 分钟（编译 + 部署 + 测试）

### 选项 B: 实施 TCP/UDP 智能切换策略（完整方案）

**目的**：实现生产环境的音频传输策略

**步骤**：
1. 添加状态机枚举 `TransportMode`
2. 实现 TCP 连接超时检测（2.5 秒）
3. 实现音频输出模式自动切换逻辑
4. 实现定期重连 TCP（10 秒）
5. 修复频繁重连问题
6. 全面测试

**预计耗时**: 30-45 分钟

### 选项 C: 先分析日志，再决定（稳妥方案）

**目的**：确认日志中音频输出模式的实际值

**步骤**：
1. 检查 voip.md 日志中 `playAudio()` 的输出
2. 确认是 `[本地播放]`、`[网络发送]`、`[TCP发送]` 中的哪一个
3. 根据日志结果决定下一步操作

---

## 📊 功能完整性评估

| 功能模块 | 实现状态 | 测试状态 | 备注 |
|---------|---------|---------|------|
| UDP 服务发现 | ✅ 已实现 | ✅ 已测试 | FIX 100.290 成功 |
| TCP 连接 + WebSocket 握手 | ✅ 已实现 | ✅ 已测试 | 连接正常 |
| 设备信息交换 | ✅ 已实现 | ✅ 已测试 | ID/UUID 同步正常 |
| 心跳机制 | ✅ 已实现 | ✅ 已测试 | PING/PONG 正常 |
| Opus 编码 | ✅ 已实现 | ❌ **未测试** | 代码已实现 |
| WebSocket BINARY 帧发送 | ✅ 已实现 | ❌ **未测试** | 代码已实现 |
| 音频输出模式切换 | ✅ 已实现 | ❌ **未启用** | 默认 DualOutput，未切换到 NetworkTcp |

**结论**：
- TCP 音频发送功能**代码已完整实现**
- **从未真正测试过** TCP 音频数据发送
- 需要**切换音频输出模式**才能启用 TCP 发送

---

## 🎯 建议

**强烈建议选择选项 A**：立即测试 TCP 音频发送功能

**理由**：
1. 代码已经实现，只需要修改一行配置即可测试
2. 快速验证功能是否正常工作（10 分钟）
3. 为后续智能切换策略提供基础验证
4. 确认是否存在其他潜在问题

**风险**：
- 无风险，只是测试，不影响生产环境

**收益**：
- 确认 TCP 音频发送功能完整性
- 验证 WebSocket BINARY 帧发送是否正常
- 获取完整的 TCP 音频传输日志

---

**报告生成时间**: 2026-01-22 16:50
**分析工具**: Claude Code + 源码分析
**报告作者**: Claude Sonnet 4.5
