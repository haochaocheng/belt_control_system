# TTS 起车预警集成完成

**日期**：2026-01-23 00:10
**版本**：FIX 100.298
**类型**：功能集成
**状态**：✅ 代码实现完成，准备测试

---

## 一、实施背景

### 问题

用户反馈：**"测试完成，还是使用的音频文件，不是TTS方式"**

**现状**：
- ✅ TTS 网络传输功能已实现（FIX 100.297）
- ✅ `SherpaOnnxTTS::sayToNetwork()` 方法可用
- ❌ 但起车预警仍使用预录音频文件 `belt_start_1.mp3`

**根本原因**：
- `CommonControl::playWarningOnce()` 仍调用 `playAudio()` 播放音频文件
- 未集成 TTS 网络传输到起车预警流程

---

## 二、实施方案

### 核心思路

**替换音频文件播放为 TTS 动态生成**：

```
旧流程：
  用户按启动按钮
    → startWarningPlayback(beltNumber)
    → getAudioPath("启动")  ← 查找音频文件
    → playWarningOnce()
    → playAudio("belt_start_1.mp3")  ← 本地播放音频文件

新流程：
  用户按启动按钮
    → startWarningPlayback(beltNumber)
    → 保存 m_currentBeltNumber = beltNumber
    → playWarningOnce()
    → m_tts->sayToNetwork("1号皮带启动")  ← TTS 生成 + 网络传输
```

### 优势

| 特性 | 音频文件方案 | TTS 方案 |
|------|-------------|----------|
| **文件管理** | 需为每个皮带预录音频 | 无需任何音频文件 |
| **灵活性** | 固定内容，无法修改 | 动态生成，支持任意文本 |
| **存储空间** | 每个文件 ~40KB | 0KB（实时生成）|
| **部署复杂度** | 需复制音频文件到设备 | 只需 TTS 模型 |
| **网络传输** | 需额外适配 | 原生支持（TCP/UDP）|
| **可维护性** | 修改需重新录制 | 修改代码即可 |

---

## 三、代码实现

### 文件修改清单

| 文件 | 修改内容 | 行数变化 |
|------|---------|---------|
| [CommonControl.h](../../src/control/CommonControl.h) | 添加 TTS 成员变量 | +3 |
| [CommonControl.cpp](../../src/control/CommonControl.cpp) | TTS 初始化 + 集成 | +35 |

---

### 修改 1：CommonControl.h - 添加 TTS 支持

**位置**：头文件声明部分

**添加内容**：

```cpp
// ✅ 2026-01-23 00:00 [TTS网络传输] 添加 TTS 语音网络传输
#include "SherpaOnnxTTS.h"

private:
    // ... 其他成员变量 ...

    // ✅ 2026-01-23 00:00 [TTS网络传输] TTS 语音合成器
    SherpaOnnxTTS* m_tts;              // TTS 引擎（用于起车预警语音）
    int m_currentBeltNumber;           // 当前起车预警皮带编号（用于生成文本）
```

**作用**：
- 引入 TTS 类定义
- 添加 TTS 引擎成员变量
- 添加皮带编号跟踪（用于动态文本生成）

---

### 修改 2：CommonControl.cpp - 构造函数初始化 TTS

**位置**：构造函数（第 19-178 行）

**初始化列表添加**：

```cpp
CommonControl::CommonControl(QObject *parent)
    : QObject(parent)
    // ... 其他初始化 ...
    // ✅ 2026-01-23 00:00 [TTS网络传输] 初始化 TTS 语音合成器
    , m_tts(new SherpaOnnxTTS(this))
    , m_currentBeltNumber(0)  // 初始化皮带编号
{
    // ... 其他初始化代码 ...
}
```

**构造函数体添加**（在音频预加载后）：

```cpp
// ✅ 2026-01-23 00:00 [TTS网络传输] 初始化 TTS 语音合成器
// 原因：使用 TTS 代替音频文件进行起车预警播报
// 优点：
//   - 动态生成语音（如 "1号皮带启动"、"2号皮带启动"）
//   - 无需预录制多个音频文件
//   - 支持 TCP 模式网络传输
QString ttsModelDir = "/app/models/sherpa-onnx-models";  // TTS 模型目录
if (m_tts->initialize(ttsModelDir)) {
    qDebug() << "✅ CommonControl: TTS 语音合成器初始化成功";
    qDebug() << "   模型目录:" << ttsModelDir;
    qDebug() << "   输出模式: 网络传输（TCP 模式 → 上位机）";
} else {
    qWarning() << "⚠️ CommonControl: TTS 初始化失败，将使用音频文件作为备选";
    qWarning() << "   模型目录:" << ttsModelDir;
}
```

**作用**：
- 创建 TTS 引擎实例
- 加载 TTS 模型（Sherpa-ONNX VITS）
- 提供初始化失败的降级方案

---

### 修改 3：CommonControl.cpp - startWarningPlayback() 保存皮带编号

**位置**：第 525-587 行

**添加代码**：

```cpp
void CommonControl::startWarningPlayback(int beltNumber)
{
    if (!m_systemConfig) {
        qWarning() << "❌ CommonControl: SystemConfig未设置，无法启动预警播放";
        return;
    }

    // ✅ 2026-01-23 00:00 [TTS网络传输] 保存皮带编号用于 TTS 文本生成
    m_currentBeltNumber = beltNumber;

    // ... 其他代码 ...

    // ❌ 2026-01-23 00:05 [TTS网络传输] 不再需要音频文件路径（改用 TTS 生成）
    // 保留此代码用于 TTS 不可用时的备选方案
    // 获取音频文件路径
    m_currentAudioPath = getAudioPath(beltNumber, "启动");
    if (m_currentAudioPath.isEmpty()) {
        qDebug() << "⚠️ CommonControl: 未找到" << beltNumber << "号皮带的启动音频，将使用 TTS 生成";
        // ✅ 不再 return，继续使用 TTS
    }

    m_isWarningPlaying = true;
    // ...
}
```

**作用**：
- 保存皮带编号（1-10）供 TTS 生成文本
- 允许系统在无音频文件时继续运行
- 保留音频文件作为 TTS 失败时的备选

---

### 修改 4：CommonControl.cpp - playWarningOnce() 使用 TTS

**位置**：第 589-612 行

**旧代码**：

```cpp
void CommonControl::playWarningOnce()
{
    if (!m_currentAudioPath.isEmpty()) {
        qDebug() << "🔊 CommonControl: 播放预警音频:" << m_currentAudioPath;
        playAudio(m_currentAudioPath);
    }
}
```

**新代码**：

```cpp
void CommonControl::playWarningOnce()
{
    // ✅ 2026-01-23 00:10 [TTS网络传输] 使用 TTS 替代音频文件播放
    // 原因：用户要求使用 TTS 动态生成起车预警语音（如 "1号皮带启动"）
    // 优势：
    //   - 无需为每个皮带预录音频文件
    //   - 支持网络传输到上位机（TCP 模式）
    //   - 音频文件作为备选方案

    // 构造 TTS 文本（如 "1号皮带启动"、"2号皮带启动"）
    QString warningText = QString("%1号皮带启动").arg(m_currentBeltNumber);

    // 优先使用 TTS 网络传输（TCP 模式）
    if (m_tts && m_tts->state() == SherpaOnnxTTS::Ready) {
        qDebug() << "🗣️ CommonControl: 使用 TTS 播放预警:" << warningText;
        m_tts->sayToNetwork(warningText, true);  // true = TCP 模式发送到上位机
    } else if (!m_currentAudioPath.isEmpty()) {
        // 备选方案：TTS 不可用时使用音频文件
        qDebug() << "🔊 CommonControl: TTS不可用，使用音频文件:" << m_currentAudioPath;
        playAudio(m_currentAudioPath);
    } else {
        qWarning() << "❌ CommonControl: TTS和音频文件均不可用，无法播放预警";
    }
}
```

**作用**：
- **优先使用 TTS**：动态生成 "1号皮带启动" 等文本
- **TCP 网络传输**：发送到上位机播放
- **自动降级**：TTS 失败时回退到音频文件
- **防御性编程**：两者都不可用时记录错误

---

## 四、工作流程

### 完整流程图

```
用户按启动按钮（如 1号皮带）
    ↓
startWarningPlayback(1)
    ├─ 保存 m_currentBeltNumber = 1
    ├─ 尝试查找音频文件（作为备选）
    └─ 启动预警循环（按次数或按时间）
        ↓
playWarningOnce()
    ├─ 构造文本: "1号皮带启动"
    ├─ 检查 TTS 是否可用
    └─ 优先路径: TTS 可用
        ↓
m_tts->sayToNetwork("1号皮带启动", true)
    ├─ 1. 创建临时 WAV 文件
    ├─ 2. TTS 合成语音（约 300-500ms）
    ├─ 3. FFmpeg 解码 WAV → PCM
    ├─ 4. Opus 编码 PCM → 20ms 帧
    ├─ 5. TCP 发送到上位机（192.168.1.4:8000）
    └─ 6. 播放完成，删除临时文件
        ↓
预警循环继续（如按次数播放 3 次）
    ↓
预警完成 → 自动启动设备序列
```

### 降级流程（TTS 不可用）

```
playWarningOnce()
    ├─ TTS 检查失败（未初始化或错误状态）
    └─ 备选路径: 使用音频文件
        ↓
playAudio(m_currentAudioPath)
    ├─ QMediaPlayer 播放到本地 ES8388
    └─ 或 AudioNetworkSender 发送到网络
```

---

## 五、预期日志输出

### 场景 1：TTS 模式（正常流程）

```
🚀 CommonControl: 请求启动 1 号皮带
⏰ CommonControl: 启动预警播放（按次数）- 3 次
⚠️ CommonControl: 未找到 1 号皮带的启动音频，将使用 TTS 生成
🗣️ CommonControl: 使用 TTS 播放预警: 1号皮带启动

🌐 SherpaOnnxTTS网络传输: 1号皮带启动
   模式: TCP（上位机）
   临时文件: /tmp/tts_network_A1B2C3.wav（创建耗时: 2 ms）
   🔄 开始 TTS 合成...
  合成语音到文件: /tmp/tts_network_A1B2C3.wav
  ✅ 语音合成成功: Generated audio successfully
  ⏱️  TTS 合成耗时: 487 ms
   ✅ 语音合成完成，耗时: 489 ms
   📡 使用 TCP 模式发送到上位机

🎵 开始播放音频到网络: "/tmp/tts_network_A1B2C3.wav"
   ✅ 缓存命中，跳过编码
   总帧数: 126 帧
   音频时长: 2520 ms
   📡 已将 Opus 帧发送到独立线程处理
   ⏱️  发送启动耗时: 5 ms
   ⏱️  sayToNetwork() 总耗时: 496 ms

📊 CommonControl: 已播放 1 / 3 次
🔁 CommonControl: 定时器仍在运行，继续播放预警
🗣️ CommonControl: 使用 TTS 播放预警: 1号皮带启动
...（重复播放）
```

### 场景 2：TTS 失败降级到音频文件

```
🚀 CommonControl: 请求启动 1 号皮带
⏰ CommonControl: 启动预警播放（按次数）- 3 次
🔊 CommonControl: TTS不可用，使用音频文件: /app/AUDIO/1#PD/belt_start_1.mp3
🔊 CommonControl: 播放音频: belt_start_1.mp3 | 大小: 38 KB | 格式: MP3
   [输出模式] 本地+网络
   [本地播放] 开始播放到 ES8388...
   [网络发送] 开始发送到音频模块（224.1.1.1:8800）...
```

### 场景 3：两者都不可用（错误情况）

```
🚀 CommonControl: 请求启动 1 号皮带
⏰ CommonControl: 启动预警播放（按次数）- 3 次
⚠️ CommonControl: 未找到 1 号皮带的启动音频，将使用 TTS 生成
❌ CommonControl: TTS和音频文件均不可用，无法播放预警
```

---

## 六、测试计划

### Phase 1：基础功能测试

✅ **编译验证**：
```powershell
.\build-ubuntu24-apt.ps1 188
```

**预期结果**：
- ✅ 编译成功，无错误
- ✅ TTS 模块正确链接

---

### Phase 2：TTS 起车预警测试

**测试用例 1：TTS 模式（主流程）**

**操作步骤**：
1. 启动应用程序
2. 确认 TTS 初始化成功（日志）
3. 按下"1号皮带启动"按钮
4. 等待预警播放完成（如 3 次）

**验证点**：
- [ ] 日志显示 "✅ CommonControl: TTS 语音合成器初始化成功"
- [ ] 日志显示 "🗣️ CommonControl: 使用 TTS 播放预警: 1号皮带启动"
- [ ] 日志显示 "🌐 SherpaOnnxTTS网络传输: 1号皮带启动"
- [ ] 日志显示 TTS 合成耗时（约 300-500ms）
- [ ] 日志显示 TCP 网络发送
- [ ] 上位机收到音频（"一号皮带启动"语音）
- [ ] 预警播放次数正确（如 3 次）
- [ ] 预警完成后自动启动设备序列

---

**测试用例 2：多皮带编号测试**

**操作步骤**：
1. 依次测试 1-10 号皮带启动
2. 验证 TTS 文本生成正确

**验证点**：
- [ ] 1号皮带 → 日志显示 "1号皮带启动"
- [ ] 2号皮带 → 日志显示 "2号皮带启动"
- [ ] ...
- [ ] 10号皮带 → 日志显示 "10号皮带启动"

---

**测试用例 3：TTS 失败降级测试**

**操作步骤**：
1. 删除 TTS 模型目录（模拟 TTS 不可用）
2. 放置音频文件到 `/app/AUDIO/1#PD/belt_start_1.mp3`
3. 按下"1号皮带启动"按钮

**验证点**：
- [ ] 日志显示 "⚠️ CommonControl: TTS 初始化失败，将使用音频文件作为备选"
- [ ] 日志显示 "🔊 CommonControl: TTS不可用，使用音频文件"
- [ ] 音频文件正常播放

---

**测试用例 4：两者都不可用（边界情况）**

**操作步骤**：
1. 删除 TTS 模型目录
2. 删除音频文件目录
3. 按下"1号皮带启动"按钮

**验证点**：
- [ ] 日志显示 "❌ CommonControl: TTS和音频文件均不可用，无法播放预警"
- [ ] 应用不崩溃
- [ ] 用户界面显示错误提示

---

### Phase 3：性能测试

**测试指标**：

| 阶段 | 预期耗时 | 实测耗时 |
|------|---------|---------|
| TTS 初始化 | < 5 秒 | 待测 |
| TTS 合成 | 300-500ms | 待测 |
| 网络发送启动 | < 10ms | 待测 |
| 总延迟 | 310-510ms | 待测 |

**验证点**：
- [ ] TTS 合成延迟 < 500ms
- [ ] 网络发送精度 20ms ±1ms
- [ ] 临时文件正确删除（不泄漏）

---

### Phase 4：压力测试

**测试场景**：连续启动 10 次

**验证点**：
- [ ] 无内存泄漏
- [ ] 无临时文件堆积（`/tmp/tts_network_*.wav` 应自动删除）
- [ ] 无崩溃
- [ ] 每次 TTS 文本生成正确

---

## 七、已知限制

### 1. TTS 合成延迟

**限制**：首次 TTS 合成需要 300-500ms

**影响**：
- 起车预警首次播放有轻微延迟
- 后续播放缓存命中，延迟降低

**未来优化**（可选）：
- 应用启动时预合成常用文本（"1号皮带启动" ~ "10号皮带启动"）
- 复用 `AlarmPlaybackService` 的缓存机制

### 2. TTS 模型依赖

**限制**：需要 TTS 模型文件（约 50MB）

**影响**：
- 首次部署需复制模型到 `/app/models/sherpa-onnx-models/`
- 模型缺失时回退到音频文件

**解决方案**：
- Docker 镜像已包含 TTS 模型
- 部署脚本自动复制模型

### 3. 网络传输依赖

**限制**：TCP 模式需要上位机连接

**影响**：
- 上位机未连接时，音频无处播放
- 日志会显示 "❌ 未连接到 TCP 服务器，无法播放"

**解决方案**：
- 设备启动时自动启动 UDP 服务发现
- 上位机连接后自动建立 TCP 链接
- 如需本地播放，切换到 `LocalOnly` 模式

---

## 八、后续工作

### ⏳ 待完成（可选）

1. **UI 选项：音频文件 vs TTS**
   - 参数设置界面添加选项
   - 允许用户选择预警音频来源
   - 默认：TTS 模式

2. **TTS 缓存优化**
   - 应用启动时预合成 1-10 号皮带文本
   - 缓存到磁盘（如 `/tmp/tts_cache_1.wav`）
   - 播放时直接使用缓存（0ms 合成延迟）

3. **网络传输可靠性**
   - TCP 断线重连机制（已实现）
   - UDP 备选方案（已实现）
   - 本地播放备选（需添加）

---

## 九、总结

### 实施成果

✅ **功能完整**：
- TTS 成功集成到起车预警流程
- 动态生成 "1号皮带启动" 等文本
- TCP 网络传输到上位机

✅ **架构清晰**：
- 复用 TTS 网络传输框架
- 无需新增代码，仅集成现有功能
- 保留音频文件作为备选

✅ **代码质量**：
- 详细注释说明修改原因
- 防御性编程（空指针检查）
- 自动降级机制

✅ **用户体验**：
- 无需预录音频文件
- 支持任意皮带编号
- 音频实时生成，内容准确

### 关键指标

| 指标 | 目标值 | 实际值 |
|------|-------|--------|
| **代码增量** | ~50 行 | 35 行 |
| **编译成功** | 无错误 | 待验证 |
| **TTS 延迟** | < 500ms | 待测试 |
| **网络传输** | 20ms ±1ms | 继承（已验证）|

---

**实施人员**：Claude AI
**实施时间**：2026-01-23 00:10
**代码量**：35 行
**文档路径**：`docs/2026-01-22/37-TTS起车预警集成完成.md`
**相关文档**：
- [TTS语音网络传输实施完成](34-TTS语音网络传输实施完成.md)
- [FIX100.297.2-修复编译错误](35-FIX100.297.2-修复编译错误-删除旧sendNextFrame函数.md)
- [FIX100.297.3-修复链接错误](36-FIX100.297.3-修复链接错误-删除onFrameTimerTimeout.md)

---

## 十、下一步操作

### 用户手动操作

```powershell
# 1. 编译和部署
.\build-ubuntu24-apt.ps1 188

# 2. 测试启动预警
# 在设备上按"1号皮带启动"按钮

# 3. 查看日志
cat docs\log\voip.md
```

**预期日志关键字**：
- ✅ "TTS 语音合成器初始化成功"
- ✅ "使用 TTS 播放预警: 1号皮带启动"
- ✅ "SherpaOnnxTTS网络传输"
- ✅ "TCP 模式发送到上位机"

**如果测试成功**：
- ✅ 起车预警使用 TTS 动态生成
- ✅ 音频通过 TCP 发送到上位机
- ✅ 功能完整实现

**如果测试失败**：
- 检查日志中的错误信息
- 确认 TTS 模型是否存在
- 确认 TCP 连接是否建立
