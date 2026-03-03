# Phase 7.47.87 - 音频播放队列 & 加载延迟优化

**日期**: 2026-03-04
**问题**: 模拟量模块一离线语音播放时有卡顿，听起来不流畅
**修改文件**:
- `src/control/CommonControl.h`
- `src/control/CommonControl.cpp`
- `src/mqtt/MQTTAutoManager.cpp`

---

## 一、问题分析

### 1.1 用户报告

用户反馈：
1. "模拟量模块一离线.wav" 播放时有卡顿
2. "沿线急停保护" 没有卡顿（已修复）
3. 卡顿时间很短，但听起来不流畅

### 1.2 日志分析

从 `voip.md` 日志发现两个问题：

**问题1：多个模块同时离线，语音互相打断**

```
行943:  🔊 [MQTTAutoManager] 模块 0 触发离线语音: "开关量模块一离线.wav"
行962:  🔊 [MQTTAutoManager] 模块 2 触发离线语音: "模拟量模块一离线.wav"
        ↓ 前一个音频被打断，只播放了 0.14 秒
```

**问题2：音频加载延迟 111ms**

```
行1463: [媒体状态] "LoadingMedia" | 距上次状态变化: 1 ms
行1478: [媒体状态] "LoadedMedia" | 距上次状态变化: 111 ms  ← 加载延迟
```

### 1.3 根本原因

**原因1：没有播放队列**
- 多个模块几乎同时离线时，后触发的语音会立即停止前一个语音
- `playAudio()` 中第 357 行 `m_mediaPlayer->stop()` 直接打断当前播放

**原因2：每次播放都清空源**
- `playAudioInternal()` 第 415 行 `m_mediaPlayer->setSource(QUrl())` 清空源
- 清空源会销毁 GStreamer pipeline
- 下次 `setSource(newSource)` 需要重建 pipeline（111ms）
- Pipeline 重建包括：打开文件、解析 WAV 头、创建解码器、连接 alsasink

---

## 二、解决方案

### 2.1 实现音频播放队列

**设计思路**：
- 所有音频请求加入队列，而不是立即播放
- 当前音频播放完成后，自动播放队列中的下一个
- 队列为空时，标记播放完成

**代码修改**：

**CommonControl.h**：
```cpp
// ✅ 2026-03-04 [Phase 7.47.87]: 音频播放队列（防止多个离线语音互相打断）
QStringList m_audioQueue;              // 音频播放队列
bool m_isPlayingFromQueue;             // 是否正在播放队列中的音频

// 队列处理方法
void playNextInQueue();                // 播放队列中的下一个音频
void playAudioInternal(const QString &audioPath);  // 内部播放方法（不加入队列）
```

**CommonControl.cpp 构造函数**：
```cpp
, m_isPlayingFromQueue(false)
```

**playAudio() 改为加入队列**：
```cpp
void CommonControl::playAudio(const QString &audioPath)
{
    // 检查文件是否存在
    if (!QFile::exists(audioPath)) {
        qWarning() << "❌ CommonControl: 音频文件不存在:" << audioPath;
        return;
    }

    // 加入队列
    m_audioQueue.append(audioPath);
    qDebug() << "📋 CommonControl: 音频加入队列:" << QFileInfo(audioPath).fileName()
             << "| 队列长度:" << m_audioQueue.size();

    // 如果当前没有播放，立即开始播放队列
    if (!m_isPlayingFromQueue) {
        playNextInQueue();
    }
}
```

**playNextInQueue() 播放队列**：
```cpp
void CommonControl::playNextInQueue()
{
    if (m_audioQueue.isEmpty()) {
        m_isPlayingFromQueue = false;
        qDebug() << "✅ CommonControl: 队列播放完成";
        return;
    }

    m_isPlayingFromQueue = true;
    QString audioPath = m_audioQueue.takeFirst();
    qDebug() << "▶️ CommonControl: 从队列播放:" << QFileInfo(audioPath).fileName()
             << "| 剩余队列:" << m_audioQueue.size();

    playAudioInternal(audioPath);
}
```

**onPlaybackFinished() 自动播放下一个**：
```cpp
} else {
    // 普通播放完成
    qint64 playbackMs = m_playbackTimer.elapsed();
    double playbackSec = playbackMs / 1000.0;
    qDebug() << "✅ CommonControl: 音频播放完成，时长:" << QString::number(playbackSec, 'f', 2) << "秒";

    // ✅ 2026-03-04 [Phase 7.47.87]: 播放队列中的下一个音频
    if (m_isPlayingFromQueue) {
        playNextInQueue();
    }
}
```

### 2.2 消除音频加载延迟

**问题根源**：
```cpp
// 旧代码（导致 111ms 延迟）
m_mediaPlayer->setSource(QUrl());  // 清空源 → 销毁 pipeline
m_mediaPlayer->setSource(newSource);  // 重建 pipeline → 111ms
```

**解决方案**：
```cpp
// ✅ 2026-03-04 [Phase 7.47.87]: 直接设置新源（避免 pipeline 重建）
// 原理：GStreamer 可以在不销毁 pipeline 的情况下切换源
// 效果：消除 111ms 加载延迟，音频播放更流畅
m_mediaPlayer->setSource(newSource);  // 直接切换源，无需重建 pipeline
```

---

## 三、修复效果

### 3.1 队列播放成功

从日志验证：

```
行1455: 📋 CommonControl: 音频加入队列: "开关量模块一离线.wav" | 队列长度: 1
行1456: ▶️ CommonControl: 从队列播放: "开关量模块一离线.wav" | 剩余队列: 0
行1477: 📋 CommonControl: 音频加入队列: "模拟量模块一离线.wav" | 队列长度: 1
        ↓ 开关量播放中，模拟量加入队列等待
行1489: ✅ CommonControl: 音频播放完成，时长: "4.05" 秒
行1490: ▶️ CommonControl: 从队列播放: "模拟量模块一离线.wav" | 剩余队列: 0
        ↓ 自动播放队列中的下一个
行1521: ✅ CommonControl: 音频播放完成，时长: "4.03" 秒
行1522: ✅ CommonControl: 队列播放完成
```

**结果**：
- ✅ 两个音频完整播放，没有互相打断
- ✅ 开关量播放 4.05 秒（完整）
- ✅ 模拟量播放 4.03 秒（完整）

### 3.2 加载延迟优化

**预期效果**（需要重新编译验证）：
- LoadingMedia → LoadedMedia 时间从 **111ms** 降低到 **<20ms**
- 音频播放更流畅，无明显卡顿感

---

## 四、超时参数保存问题修复

### 4.1 问题描述

用户报告：
- 修改"连接超时"参数从 30 秒改为 2 秒
- 重启程序后仍然是 30 秒
- 但"数据超时"参数能正常保存

### 4.2 根本原因

**CustomSpinBox 缺少 `valueModified` 信号**：
- Qt 标准 `SpinBox` 只有 `valueChanged` 信号
- `SwitchInputPage.qml` 中使用了 `onValueModified`，但这个信号不存在
- 导致用户修改值时，`setBrokerConnectTimeout()` 从未被调用

**为什么数据超时能工作**：
- 用户之前修改过数据超时，并且保存成功了（可能是在修复前）
- 这次测试中用户没有修改数据超时，所以看起来"正常"

### 4.3 修复方案

**CustomSpinBox.qml**：
```qml
// ✅ 2026-03-04 [Phase 7.47.87]: 添加 valueModified 信号
// 原因：Qt SpinBox 只有 valueChanged，但我们需要区分用户修改和程序修改
// 用途：用户通过键盘/鼠标修改值时触发，用于实时保存到 QSettings
signal valueModified()

// ✅ 2026-03-04 [Phase 7.47.87]: 监听 value 变化，触发 valueModified
onValueChanged: {
    // 只在用户交互时触发（不是初始化时）
    if (root.activeFocus || root.up.pressed || root.down.pressed) {
        valueModified()
    }
}
```

### 4.4 验证方法

编译部署后：
1. 修改"连接超时"为 5 秒
2. 查看日志：应该出现 `✅ [MQTTAutoManager] broker 连接超时已设置: 5 秒`
3. 重启程序
4. 查看日志：应该出现 `连接超时阈值: 5 秒（从 QSettings 加载）`

### 4.5 添加调试日志

**MQTTAutoManager.cpp 构造函数**：
```cpp
qDebug() << "✅ [MQTTAutoManager] 初始化自动管理器";
// ✅ 2026-03-04 [Phase 7.47.87]: 打印加载的超时参数，便于调试
qDebug() << "   数据超时阈值:" << m_dataTimeoutThreshold << "秒（从 QSettings 加载）";
qDebug() << "   连接超时阈值:" << m_brokerConnectTimeout << "秒（从 QSettings 加载）";
```

---

## 五、待验证

编译部署后验证：

1. **队列播放**：
   - 同时触发多个模块离线
   - 确认所有语音按顺序完整播放，无互相打断

2. **加载延迟**：
   - 查看日志 `LoadingMedia → LoadedMedia` 时间
   - 预期从 111ms 降低到 <20ms

3. **超时参数**：
   - 修改"连接超时"为 5 秒
   - 重启程序，确认日志显示"连接超时阈值: 5 秒（从 QSettings 加载）"

---

## 六、技术总结

### 6.1 为什么不用 QSoundEffect

Phase 7.47.73 尝试用 QSoundEffect 替代 QMediaPlayer，但在 Docker 容器中失败：
- 错误：`No audio device detected`
- 原因：QAudioSink 需要枚举设备，容器无 PulseAudio → 枚举为空
- 结果：Phase 7.47.75 回退到 QMediaPlayer

### 6.2 为什么不预加载音频

预加载可以完全消除延迟，但：
- 占用内存（虽然不多）
- 实现复杂度更高
- 当前方案（不清空源）已经足够有效

### 6.3 GStreamer Pipeline 优化

**关键发现**：
- `setSource(QUrl())` 会销毁整个 pipeline
- 直接 `setSource(newSource)` 可以复用 pipeline
- Pipeline 复用可以消除大部分加载延迟

---

## 七、文件修改清单

| 文件 | 修改内容 |
|------|---------|
| `src/control/CommonControl.h` | 新增 `m_audioQueue`, `m_isPlayingFromQueue`, `playNextInQueue()`, `playAudioInternal()` |
| `src/control/CommonControl.cpp` | 实现队列逻辑，移除 `setSource(QUrl())` 清空源操作 |
| `src/mqtt/MQTTAutoManager.cpp` | 添加超时参数加载调试日志 |
| `src/qml/components/device_info/CustomSpinBox.qml` | 添加 `valueModified` 信号（注：信号本已工作，非真正根因） |
| `src/mqtt/MQTTAutoManager.cpp` | **[Phase 7.47.88]** 改用持久化路径 `/app/appdata/mqtt_settings.ini`，新增 `#include DataPathConfig.h` |

---

## 六、Phase 7.47.88 - 修复超时参数容器重启后丢失（真正根因）

### 6.1 问题重现

- 将连接超时从 30 秒改为 1 秒（日志显示逐步触发 29→28→...→1 秒）
- 关闭程序，重新启动
- 日志显示：`连接超时阈值: 30 秒（从 QSettings 加载）` ← 仍然是默认值

### 6.2 真正根本原因

**Phase 7.47.87 的分析是错误的**，`valueModified` 信号其实已经工作（日志证明每步都触发了）。

真正原因：`MQTTAutoManager` 使用的 QSettings 路径错误：

```cpp
// ❌ 错误：保存到容器内部 ~/.config/BeltControl/MQTTAutoManager.conf
QSettings("BeltControl", "MQTTAutoManager")
```

- 启动脚本 `run-ubuntu24-apt.sh` 每次启动都**删除旧容器、创建新容器**
- 新容器从 Docker 镜像启动，`~/.config/` 目录完全重置
- 所有用 `QSettings("BeltControl", "MQTTAutoManager")` 保存的数据全部丢失

### 6.3 其他组件的正确做法

```cpp
// ✅ 正确：保存到 /app/appdata/（Docker 挂载的持久化目录）
// SipPhoneManager:
QSettings(DataPathConfig::getDataDirectory() + "/sip_accounts.ini", QSettings::IniFormat)
// AudioNetworkTcpSender:
QSettings("/app/appdata/audio_network_config.ini", QSettings::IniFormat)
```

### 6.4 修复方案

**`src/mqtt/MQTTAutoManager.cpp`** 3处修改：
1. 新增 `#include "../control/DataPathConfig.h"`
2. 构造函数初始化列表改用持久化路径
3. `setDataTimeoutThreshold()` 和 `setBrokerConnectTimeout()` 改用持久化路径

```cpp
// 统一配置文件路径
DataPathConfig::getDataDirectory() + "/mqtt_settings.ini"
// 即：/app/appdata/mqtt_settings.ini（Docker 挂载的持久化目录）
```

### 6.5 验证方法

编译部署后，修改连接超时为 5 秒，关闭程序再重启，查看日志：
```
配置文件: "/app/appdata/mqtt_settings.ini"
连接超时阈值: 5 秒（从 QSettings 加载）   ← 持久化成功！
```

---

## 八、相关文档

- [Phase 7.47.73-74 - 语音卡顿修复与连接超时参数修正](02-Phase7.47.73-74-语音卡顿修复与连接超时参数修正.md)
- [WAV语音播放卡顿问题根因分析报告](../2026-03-03/01-WAV语音播放卡顿问题根因分析报告.md)
