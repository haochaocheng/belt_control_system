# TCP/UDP 自动切换架构设计

**日期**:2026-01-22 22:30
**版本**:设计方案 v1.0
**类型**:架构设计
**状态**:⏳ 待实施

---

## 一、需求分析

### 用户需求

> "实现 TCP/UDP 自动切换功能 - TCP 优先,失败自动降级到 UDP"

### 核心目标

1. ✅ **TCP 优先**:默认使用 TCP 模式(更可靠、有反馈)
2. ✅ **自动降级**:TCP 失败时自动切换到 UDP(兜底方案)
3. ✅ **透明切换**:上层无感知,统一接口
4. ✅ **智能恢复**:TCP 恢复后可自动切回(可选)

---

## 二、现有架构分析

### 现有两种模式对比

| 特性 | TCP 模式(AudioNetworkTcpSender) | UDP 模式(AudioNetworkSender) |
|------|--------------------------------|------------------------------|
| **连接方式** | UDP 服务发现 + TCP 连接 + WebSocket | UDP 组播(224.1.x.1:8800) |
| **可靠性** | ✅ 高(TCP 保证顺序和完整性) | ⚠️ 中(UDP 可能丢包) |
| **延迟** | ⚠️ 中(连接建立、心跳) | ✅ 低(无连接开销) |
| **双向通信** | ✅ 支持(WebSocket 双向) | ❌ 单向(仅发送) |
| **心跳机制** | ✅ 5 秒 PING,2 秒超时 | ❌ 无 |
| **连接状态** | ✅ 可检测(心跳、错误事件) | ❌ 无(发送即发送) |
| **适用场景** | 上位机控制(需要反馈) | 音频模块(单向播放) |
| **精度** | ✅ 20ms ± 1ms(独立线程) | ✅ 20ms ± 5ms(主线程) |

### 共同特性

两个类都提供相同的播放接口:

```cpp
// 播放接口
void playAudioToNetwork(const QString& filePath);
void stopPlayback();
bool isPlaying() const;

// 信号
void playbackStarted(const QString& fileName);
void playbackProgress(int framesSent, int totalFrames);
void playbackFinished();
void playbackError(const QString& error);
```

这为统一接口设计提供了基础。

---

## 三、架构设计方案

### 方案:适配器模式 + 状态机

#### 核心思想

创建一个 **AudioNetworkManager** 类:
- 内部持有 TCP 和 UDP 两个实例
- 提供统一的接口给上层
- 状态机管理模式切换

#### 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    上层调用者(CommonControl)                 │
│                 playAudio(), stopAudio()                    │
└───────────────────────────┬─────────────────────────────────┘
                            │ 统一接口
                            ↓
┌───────────────────────────────────────────────────────────┐
│                  AudioNetworkManager                      │
│                    (管理者 + 适配器)                       │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  状态机:                                                   │
│  ┌─────────┐  TCP失败   ┌─────────┐                      │
│  │TCP模式  │ ─────────→ │UDP模式  │                      │
│  └─────────┘            └─────────┘                      │
│      ↑                       │                            │
│      └───────────────────────┘                            │
│           TCP恢复(可选)                                    │
│                                                           │
│  失败检测:                                                 │
│  - TCP 连接超时(5 秒)                                      │
│  - 心跳超时(2 秒)                                          │
│  - 发送错误                                                │
│                                                           │
└───────────────┬───────────────────────────────┬───────────┘
                │                               │
                ↓                               ↓
┌───────────────────────────┐   ┌──────────────────────────┐
│ AudioNetworkTcpSender     │   │ AudioNetworkSender       │
│ (TCP 模式)                 │   │ (UDP 模式)                │
├───────────────────────────┤   ├──────────────────────────┤
│ - UDP 服务发现             │   │ - UDP 组播发送            │
│ - TCP 连接                 │   │ - 20ms 精确定时           │
│ - WebSocket 协议           │   │ - 简单可靠                │
│ - 心跳机制                 │   │                          │
│ - 独立发送线程             │   │                          │
│ - 20ms 精确定时            │   │                          │
└───────────────────────────┘   └──────────────────────────┘
```

---

## 四、详细设计

### 4.1 AudioNetworkManager.h

#### 类定义

```cpp
class AudioNetworkManager : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief 传输模式枚举
     */
    enum TransmissionMode {
        TCP_MODE,      ///< TCP 模式(优先)
        UDP_MODE,      ///< UDP 模式(降级)
        AUTO_MODE      ///< 自动模式(TCP 优先,失败降级)
    };

    explicit AudioNetworkManager(QObject *parent = nullptr);
    ~AudioNetworkManager();

    // ========== 配置接口 ==========

    /**
     * @brief 设置传输模式
     * @param mode 传输模式
     *
     * - TCP_MODE:  强制使用 TCP(不降级)
     * - UDP_MODE:  强制使用 UDP
     * - AUTO_MODE: 自动切换(默认,推荐)
     */
    void setTransmissionMode(TransmissionMode mode);

    /**
     * @brief 获取当前使用的模式
     * @return 当前模式
     */
    TransmissionMode getCurrentMode() const;

    /**
     * @brief 设置 TCP 连接超时时间
     * @param seconds 超时秒数(默认 5 秒)
     */
    void setTcpConnectionTimeout(int seconds);

    /**
     * @brief 设置是否自动恢复 TCP
     * @param enable true=TCP 恢复后自动切回,false=保持 UDP
     *
     * 默认:false(不自动切回,避免频繁切换)
     */
    void setAutoRecoveryEnabled(bool enable);

    /**
     * @brief 设置设备信息(用于 TCP 模式)
     * @param info 设备信息
     */
    void setDeviceInfo(const AudioNetworkTcpSender::DeviceInfo& info);

    // ========== 播放接口(统一) ==========

    /**
     * @brief 播放音频到网络
     * @param filePath 音频文件路径
     *
     * 自动选择 TCP 或 UDP 模式发送
     */
    void playAudioToNetwork(const QString& filePath);

    /**
     * @brief 停止播放
     */
    void stopPlayback();

    /**
     * @brief 查询是否正在播放
     * @return true=正在播放,false=空闲
     */
    bool isPlaying() const;

signals:
    // ========== 模式切换信号 ==========

    /**
     * @brief 模式切换信号
     * @param from 切换前的模式
     * @param to 切换后的模式
     * @param reason 切换原因
     */
    void modeChanged(TransmissionMode from, TransmissionMode to, const QString& reason);

    // ========== 播放信号(统一) ==========

    void playbackStarted(const QString& fileName);
    void playbackProgress(int framesSent, int totalFrames);
    void playbackFinished();
    void playbackError(const QString& error);

private slots:
    // ========== TCP 模式槽函数 ==========

    void onTcpDiscoveryFailed(const QString& error);
    void onTcpConnected();
    void onWebSocketReady();
    void onTcpDisconnected();
    void onTcpError(const QString& error);
    void onHeartbeatTimeout();

    // ========== 播放状态转发槽函数 ==========

    void onPlaybackStarted(const QString& fileName);
    void onPlaybackProgress(int framesSent, int totalFrames);
    void onPlaybackFinished();
    void onPlaybackError(const QString& error);

    // ========== 超时检测槽函数 ==========

    void onConnectionTimeout();

private:
    // ========== 模式切换逻辑 ==========

    /**
     * @brief 切换到 TCP 模式
     */
    void switchToTcpMode();

    /**
     * @brief 切换到 UDP 模式
     * @param reason 切换原因
     */
    void switchToUdpMode(const QString& reason);

    /**
     * @brief 检查是否可以切回 TCP
     * @return true=可以尝试切回,false=不可以
     */
    bool canRecoverToTcp() const;

    // ========== 成员变量 ==========

    // 两个实例
    AudioNetworkTcpSender* m_tcpSender;  ///< TCP 发送器
    AudioNetworkSender* m_udpSender;     ///< UDP 发送器

    // 状态管理
    TransmissionMode m_configuredMode;   ///< 用户配置的模式
    TransmissionMode m_currentMode;      ///< 当前实际使用的模式
    bool m_autoRecoveryEnabled;          ///< 是否启用自动恢复

    // TCP 连接状态
    QTimer* m_connectionTimer;           ///< 连接超时定时器
    int m_connectionTimeoutSeconds;      ///< 连接超时秒数(默认 5)
    bool m_tcpEverConnected;             ///< TCP 是否曾经连接成功
};
```

---

### 4.2 工作流程

#### 场景 1:TCP 成功(正常流程)

```
用户调用:playAudioToNetwork("/app/audio/alarm.mp3")
    ↓
AudioNetworkManager::playAudioToNetwork()
    ├─ 当前模式:AUTO_MODE
    ├─ 优先尝试 TCP 模式
    └─ 调用:m_tcpSender->playAudioToNetwork()
    ↓
AudioNetworkTcpSender 启动:
    ├─ UDP 服务发现(< 1 秒)
    ├─ TCP 连接成功
    ├─ WebSocket 握手完成
    └─ 独立线程发送 Opus 帧
    ↓
播放成功完成
    ↓
emit playbackFinished()
```

#### 场景 2:TCP 失败,自动降级到 UDP

```
用户调用:playAudioToNetwork("/app/audio/alarm.mp3")
    ↓
AudioNetworkManager::playAudioToNetwork()
    ├─ 当前模式:AUTO_MODE
    ├─ 优先尝试 TCP 模式
    ├─ 启动连接超时定时器(5 秒)
    └─ 调用:m_tcpSender->playAudioToNetwork()
    ↓
AudioNetworkTcpSender 启动失败:
    ├─ UDP 服务发现超时(5 秒)
    └─ emit discoveryFailed("UDP 发现超时")
    ↓
AudioNetworkManager::onTcpDiscoveryFailed()
    ├─ 检测到 TCP 失败
    ├─ 自动切换到 UDP 模式
    └─ qWarning() << "⚠️ TCP 连接失败,自动降级到 UDP 模式"
    ↓
switchToUdpMode("TCP 连接失败")
    ├─ m_currentMode = UDP_MODE
    ├─ emit modeChanged(TCP_MODE, UDP_MODE, "TCP 连接失败")
    ├─ 停止 TCP 发送器
    └─ 调用:m_udpSender->playAudioToNetwork()
    ↓
AudioNetworkSender 接管:
    ├─ UDP 组播发送
    └─ 主线程发送 Opus 帧
    ↓
播放成功完成
    ↓
emit playbackFinished()
```

#### 场景 3:TCP 心跳超时,自动降级

```
正在播放中(TCP 模式):
    ├─ 音频播放进行到 50%
    ├─ 网络突然断开
    └─ 心跳超时(2 秒未收到 PONG)
    ↓
AudioNetworkTcpSender::heartbeatTimeout()
    ↓
AudioNetworkManager::onHeartbeatTimeout()
    ├─ 检测到连接丢失
    ├─ 自动切换到 UDP 模式
    └─ qWarning() << "⚠️ TCP 心跳超时,自动降级到 UDP 模式"
    ↓
switchToUdpMode("TCP 心跳超时")
    ├─ m_currentMode = UDP_MODE
    ├─ emit modeChanged(TCP_MODE, UDP_MODE, "TCP 心跳超时")
    ├─ 停止 TCP 发送器
    └─ 重新播放当前音频(UDP 模式)
    ↓
用户体验:
    - 短暂中断(< 1 秒)
    - 自动恢复播放(UDP 模式)
    - UI 显示:"连接模式:UDP(TCP 不可用)"
```

---

### 4.3 失败检测机制

#### TCP 失败的判定条件

| 失败类型 | 检测方式 | 超时时间 | 处理方式 |
|---------|---------|---------|---------|
| **UDP 服务发现失败** | discoveryFailed 信号 | 5 秒 | 立即切换到 UDP |
| **TCP 连接超时** | QTimer 超时 | 5 秒 | 立即切换到 UDP |
| **TCP 连接错误** | tcpError 信号 | 立即 | 立即切换到 UDP |
| **心跳超时** | heartbeatTimeout 信号 | 2 秒 | 立即切换到 UDP |
| **WebSocket 握手失败** | webSocketReady 未触发 | 5 秒 | 立即切换到 UDP |

#### 切换策略

```cpp
void AudioNetworkManager::onTcpDiscoveryFailed(const QString& error)
{
    if (m_configuredMode == AUTO_MODE) {
        qWarning() << "⚠️ TCP 连接失败:" << error;
        qWarning() << "   自动降级到 UDP 模式";
        switchToUdpMode("TCP 连接失败: " + error);

        // 如果正在播放,使用 UDP 重新播放
        if (m_tcpSender->isPlaying()) {
            QString currentFile = m_lastPlayedFile;
            m_tcpSender->stopPlayback();
            m_udpSender->playAudioToNetwork(currentFile);
        }
    } else {
        // 如果是强制 TCP 模式,直接报错
        emit playbackError("TCP 连接失败: " + error);
    }
}
```

---

### 4.4 自动恢复机制(可选)

#### 场景:TCP 从故障恢复

```
当前状态:UDP 模式(因 TCP 失败降级)
    ↓
后台定时检查(每 30 秒):
    ├─ 检测 TCP 是否恢复
    └─ 发送 UDP 广播到 8600 端口
    ↓
收到 UDP 响应:
    ├─ TCP 服务器已恢复
    └─ qDebug() << "✅ TCP 服务器已恢复"
    ↓
如果启用自动恢复(m_autoRecoveryEnabled):
    ├─ 当前空闲(不在播放)
    ├─ 切换回 TCP 模式
    └─ emit modeChanged(UDP_MODE, TCP_MODE, "TCP 服务器已恢复")
    ↓
下次播放自动使用 TCP 模式
```

**注意**:默认**不启用**自动恢复,避免频繁切换影响稳定性。

---

## 五、配置示例

### 5.1 默认配置(推荐)

```cpp
// main.cpp 或 CommonControl.cpp
AudioNetworkManager* audioMgr = new AudioNetworkManager(this);

// 设置自动模式(默认)
audioMgr->setTransmissionMode(AudioNetworkManager::AUTO_MODE);

// 设置 TCP 连接超时(默认 5 秒)
audioMgr->setTcpConnectionTimeout(5);

// 不启用自动恢复(默认,推荐)
audioMgr->setAutoRecoveryEnabled(false);

// 设置设备信息
AudioNetworkTcpSender::DeviceInfo info;
info.id = 0;
info.uuid = "Belt-Control-System-001";
info.name = "皮带控制系统";
// ...
audioMgr->setDeviceInfo(info);

// 连接信号
connect(audioMgr, &AudioNetworkManager::modeChanged, [](auto from, auto to, auto reason) {
    qDebug() << "📡 传输模式切换:" << from << "→" << to << "原因:" << reason;
});

// 播放音频
audioMgr->playAudioToNetwork("/app/audio/alarm.mp3");
```

### 5.2 强制 TCP 模式(调试)

```cpp
// 只使用 TCP,失败直接报错(不降级)
audioMgr->setTransmissionMode(AudioNetworkManager::TCP_MODE);
```

### 5.3 强制 UDP 模式(兜底)

```cpp
// 只使用 UDP,简单可靠
audioMgr->setTransmissionMode(AudioNetworkManager::UDP_MODE);
```

---

## 六、实施计划

### Phase 1:基础架构(1-2 小时)

- [ ] 创建 AudioNetworkManager.h
- [ ] 创建 AudioNetworkManager.cpp
- [ ] 实现构造函数、析构函数
- [ ] 实现 setTransmissionMode()、getCurrentMode()
- [ ] 实现 playAudioToNetwork()、stopPlayback()、isPlaying()
- [ ] 连接 TCP 和 UDP 信号到统一信号

### Phase 2:失败检测(1 小时)

- [ ] 实现 onTcpDiscoveryFailed()
- [ ] 实现 onTcpError()
- [ ] 实现 onHeartbeatTimeout()
- [ ] 实现连接超时定时器

### Phase 3:模式切换(1 小时)

- [ ] 实现 switchToTcpMode()
- [ ] 实现 switchToUdpMode()
- [ ] 实现播放中断后自动重连
- [ ] 实现 modeChanged 信号

### Phase 4:测试验证(1 小时)

- [ ] 测试场景 1:TCP 正常连接
- [ ] 测试场景 2:TCP 连接失败,自动降级 UDP
- [ ] 测试场景 3:播放中 TCP 断开,自动切换 UDP
- [ ] 测试场景 4:强制 TCP 模式,失败报错
- [ ] 测试场景 5:强制 UDP 模式,直接使用 UDP

**总计**:4-5 小时

---

## 七、优势分析

### 对比其他方案

| 方案 | 优点 | 缺点 |
|------|------|------|
| **方案 1:适配器模式**(本方案) | ✅ 统一接口<br>✅ 透明切换<br>✅ 不修改现有代码<br>✅ 易于扩展 | ⚠️ 新增一个类 |
| **方案 2:合并两个类** | ✅ 代码集中 | ❌ 破坏单一职责<br>❌ 代码复杂度高<br>❌ 难以维护 |
| **方案 3:外部控制切换** | ✅ 简单 | ❌ 上层需要感知模式<br>❌ 无自动切换<br>❌ 用户体验差 |

**结论**:方案 1(适配器模式)是最优方案。

---

## 八、风险分析

### 潜在风险

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| **频繁切换** | 用户体验差 | ✅ 默认不启用自动恢复<br>✅ 增加切换冷却时间(30 秒) |
| **播放中断** | 音频中断 | ✅ 切换时保存播放进度<br>✅ UDP 接管后继续播放 |
| **资源占用** | 两个实例同时存在 | ✅ 只有活动实例工作<br>✅ 内存开销可接受(< 1MB) |
| **配置不一致** | 两个实例配置不同 | ✅ Manager 统一管理配置<br>✅ 设备信息只设置 TCP |

---

## 九、未来扩展

### 可选功能(未来版本)

1. **智能模式选择**:
   - 根据历史成功率选择默认模式
   - 例如:TCP 失败率 > 80% → 下次优先 UDP

2. **性能监控**:
   - 记录每种模式的成功率、延迟、丢包率
   - UI 显示统计信息

3. **手动切换**:
   - UI 按钮:手动切换 TCP/UDP
   - 调试模式:强制使用某种模式

4. **日志记录**:
   - 记录切换历史
   - 记录失败原因
   - 用于故障排查

---

## 十、总结

### 设计亮点

✅ **透明切换**:上层无需修改代码
✅ **自动降级**:TCP 失败自动用 UDP 兜底
✅ **统一接口**:playAudioToNetwork() 一个接口搞定
✅ **易于扩展**:未来可添加更多传输方式
✅ **不破坏现有代码**:AudioNetworkTcpSender 和 AudioNetworkSender 保持不变

### 关键指标

| 指标 | 目标 |
|------|------|
| **TCP 连接超时** | 5 秒 |
| **自动切换延迟** | < 1 秒 |
| **播放中断时间** | < 500ms |
| **代码增量** | ~500 行 |

### 下一步

⏳ 开始实施 Phase 1:创建 AudioNetworkManager.h 和 AudioNetworkManager.cpp

---

**设计人员**:Claude AI
**设计日期**:2026-01-22 22:30
**文档路径**:`docs/2026-01-22/31-TCP-UDP自动切换架构设计.md`
