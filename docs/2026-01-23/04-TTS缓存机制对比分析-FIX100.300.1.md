# TTS缓存机制对比分析 - FIX 100.300.1

**日期**: 2026-01-23
**问题**: 现有TTS缓存机制与提出方案的区别
**目标**: 明确问题根源，提出针对性解决方案

---

## 📊 现有TTS缓存机制分析

### 1. AlarmPlaybackService的TTS缓存

**实现位置**: `src/control/AlarmPlaybackService.cpp:448-478`

**缓存范围**（仅10个报警文本）:
```cpp
commonTexts << "急停保护报警"
            << "主机急停保护报警"
            << "沿线急停"
            << "打滑保护报警"
            << "跑偏保护报警"
            << "堆煤保护报警"
            << "撕裂保护报警"
            << "超速保护报警"
            << "低速保护报警"
            << "温度保护报警";
```

**缓存机制**:
- 缓存目录: `/app/appdata/tts_cache/`
- 文件命名: MD5哈希值 + `.wav`
- 预缓存: 系统启动时预合成10个报警文本
- 使用: `getCachedTtsFile(text)` 检查缓存

**日志证据**（启动时）:
```
[DEBUG] 🗂️  AlarmPlaybackService: 初始化TTS缓存
[DEBUG]   TTS缓存目录（持久化）: "/app/appdata/tts_cache"
[DEBUG]   开始预缓存 10 个常用报警文本...
[DEBUG]   ✓ 已存在: "急停保护报警"
[DEBUG]   ✓ 已存在: "主机急停保护报警"
...
[DEBUG] ✅ TTS缓存初始化完成，已缓存 10 个文本
```

---

### 2. SherpaOnnxTTS::sayToNetwork() - 无缓存

**实现位置**: `src/control/SherpaOnnxTTS.cpp:415-490`

**当前流程**（每次都重新合成）:
```cpp
void SherpaOnnxTTS::sayToNetwork(const QString &text, bool useTcp)
{
    // 1. 创建临时文件
    m_networkTempFile = new QTemporaryFile(...);

    // 2. 合成语音到临时文件（每次都合成，1.9秒）
    if (!synthesize(text, tempFilePath)) {
        return;
    }

    // 3. 发送到网络
    if (useTcp) {
        m_tcpSender->playAudioToNetwork(tempFilePath);
    } else {
        m_udpSender->playAudioToNetwork(tempFilePath);
    }
}
```

**问题**:
- ❌ **没有缓存检查**：每次调用都重新合成
- ❌ **使用临时文件**：`QTemporaryFile` 自动删除，无法复用
- ❌ **延时1.9秒**：相同文本每次都要合成1.9秒

**日志证据**（voip.md）:
```
Line 610: 🗣️ CommonControl: 使用 TTS 播放预警: "一号皮带准备启动，请注意"
Line 614:    🔄 开始 TTS 合成...
Line 621:   ⏱️  TTS 合成耗时: 1820 ms

Line 1064: 🗣️ CommonControl: 使用 TTS 播放预警: "一号皮带准备启动，请注意"
Line 1068:    🔄 开始 TTS 合成...
Line 1076:   ⏱️  TTS 合成耗时: 1868 ms

Line 1342: 🗣️ CommonControl: 使用 TTS 播放预警: "一号皮带准备启动，请注意"
Line 1346:    🔄 开始 TTS 合成...
Line 1361:   ⏱️  TTS 合成耗时: 1978 ms
```

**结论**: 相同文本"一号皮带准备启动，请注意"每次都重新合成！

---

### 3. CommonControl::playWarningOnce() - 调用无缓存的方法

**实现位置**: `src/control/CommonControl.cpp:616-645`

**当前流程**:
```cpp
void CommonControl::playWarningOnce()
{
    // 构造文本
    QString chineseNumber = numberToChinese(m_currentBeltNumber);
    QString warningText = QString("%1号皮带准备启动，请注意").arg(chineseNumber);

    // 直接调用 sayToNetwork（无缓存）
    if (m_tts && m_tts->state() == SherpaOnnxTTS::Ready) {
        m_tts->sayToNetwork(warningText, true);  // ❌ 每次都合成1.9秒
    }
}
```

**问题**:
- ❌ 没有使用 AlarmPlaybackService 的缓存机制
- ❌ 直接调用 `sayToNetwork()`，每次都重新合成
- ❌ 起车预警文本不在 AlarmPlaybackService 的预缓存列表中

---

## 🎯 问题根源总结

### 核心问题

1. **AlarmPlaybackService的缓存只用于报警文本**
   - 只缓存10个报警文本（急停、打滑等）
   - 不包含起车预警文本（"一号皮带准备启动，请注意"）

2. **SherpaOnnxTTS::sayToNetwork() 没有缓存机制**
   - 每次调用都重新合成
   - 使用临时文件，无法复用
   - 这是起车预警的调用路径

3. **两个缓存系统不互通**
   - AlarmPlaybackService 有缓存（用于报警）
   - SherpaOnnxTTS 无缓存（用于起车预警）
   - 导致起车预警每次都要合成1.9秒

---

## 💡 解决方案对比

### 方案A: 在SherpaOnnxTTS层添加缓存（我的方案）

**优势**:
- ✅ **底层统一**：所有TTS调用都会被缓存（报警+起车预警）
- ✅ **自动覆盖**：无需修改调用方代码
- ✅ **持久化**：缓存保存在 `/app/appdata/tts_cache/`
- ✅ **预热机制**：系统启动时预合成1-10号皮带文本

**实施**:
修改 `SherpaOnnxTTS::sayToNetwork()`:
```cpp
void SherpaOnnxTTS::sayToNetwork(const QString &text, bool useTcp)
{
    // 生成缓存文件路径
    QString cacheKey = QString::number(qHash(text), 16);
    QString cacheFilePath = QString("/app/appdata/tts_cache/network_%1.wav").arg(cacheKey);

    // 检查缓存
    if (QFile::exists(cacheFilePath)) {
        qDebug() << "   ✅ 使用TTS缓存（零延时）:" << cacheFilePath;

        // 直接使用缓存文件
        if (useTcp && m_tcpSender && m_tcpSender->isConnected()) {
            m_tcpSender->playAudioFile(cacheFilePath);
        } else if (!useTcp && m_udpSender) {
            m_udpSender->playAudioFile(cacheFilePath);
        }
        return;
    }

    // 缓存不存在，合成并缓存
    qDebug() << "   ⚠️  缓存未命中，开始TTS合成...";

    // 合成到缓存文件（而非临时文件）
    if (!synthesize(text, cacheFilePath)) {
        return;
    }

    qDebug() << "   💾 已缓存，下次播放将零延时";

    // 发送到网络
    if (useTcp && m_tcpSender && m_tcpSender->isConnected()) {
        m_tcpSender->playAudioFile(cacheFilePath);
    } else if (!useTcp && m_udpSender) {
        m_udpSender->playAudioFile(cacheFilePath);
    }
}
```

**预期效果**:
- 首次播放"一号皮带准备启动，请注意"：1.9秒（合成并缓存）
- 后续播放相同文本：<50ms（使用缓存）
- 系统启动后预热1-10号皮带：全部零延时

---

### 方案B: 扩展AlarmPlaybackService缓存范围

**实施**:
在 `AlarmPlaybackService::initializeTtsCache()` 中添加起车预警文本:
```cpp
// 添加起车预警文本到预缓存列表
for (int i = 1; i <= 10; ++i) {
    QString chineseNumber = numberToChinese(i);
    QString warningText = QString("%1号皮带准备启动，请注意").arg(chineseNumber);
    commonTexts << warningText;
}
```

然后修改 `CommonControl::playWarningOnce()` 使用 AlarmPlaybackService 的缓存:
```cpp
void CommonControl::playWarningOnce()
{
    QString warningText = ...;

    // 使用 AlarmPlaybackService 的缓存
    QString cachedFile = m_alarmService->getCachedTtsFile(warningText);

    if (!cachedFile.isEmpty()) {
        // 使用缓存文件
        m_tcpSender->playAudioFile(cachedFile);
    } else {
        // 降级到实时合成
        m_tts->sayToNetwork(warningText, true);
    }
}
```

**劣势**:
- ⚠️ 需要修改多处代码（AlarmPlaybackService + CommonControl）
- ⚠️ 缓存逻辑分散在两个类中
- ⚠️ 不够通用（只解决起车预警，其他场景仍需单独处理）

---

## 📋 推荐方案

### 最佳方案：方案A（在SherpaOnnxTTS层添加缓存）⭐⭐⭐

**理由**:
1. **底层统一**：一次修改，所有TTS调用都受益
2. **自动覆盖**：无需修改调用方代码（CommonControl、AlarmPlaybackService等）
3. **持久化**：与现有AlarmPlaybackService共用缓存目录
4. **预热机制**：系统启动时预合成常用文本

**与现有方案的区别**:
| 特性 | 现有方案（AlarmPlaybackService） | 我的方案（SherpaOnnxTTS） |
|------|--------------------------------|-------------------------|
| **缓存范围** | 仅10个报警文本 | 所有TTS文本（报警+起车预警+其他） |
| **调用路径** | AlarmPlaybackService专用 | 所有TTS调用（底层统一） |
| **起车预警** | ❌ 不支持（每次1.9秒） | ✅ 支持（首次1.9秒，后续<50ms） |
| **预热机制** | 仅报警文本 | 报警文本 + 起车预警文本（1-10号皮带） |
| **实施难度** | - | 简单（只修改SherpaOnnxTTS） |

---

## 🔧 实施计划

### Phase 1: 修改SherpaOnnxTTS添加缓存

#### 步骤1: 修改sayToNetwork()方法
- 添加缓存检查逻辑
- 合成到持久化文件（而非临时文件）
- 缓存命中时直接使用

#### 步骤2: 添加预热机制
- 在CommonControl初始化时预热1-10号皮带文本
- 延迟5秒启动，避免阻塞启动

#### 步骤3: 编译测试
```powershell
.\build-ubuntu24-apt.ps1 192.168.10.188
```

#### 步骤4: 验证效果
- 查看日志，确认缓存命中
- 测量实际延时（应<50ms）
- 检查缓存文件是否生成

---

## 📊 预期效果

### 测试场景1: 首次播放起车预警
```
[DEBUG] 🗣️ CommonControl: 使用 TTS 播放预警: "一号皮带准备启动，请注意"
[DEBUG] 🌐 SherpaOnnxTTS网络传输: "一号皮带准备启动，请注意"
[DEBUG]    ⚠️  缓存未命中，开始TTS合成...
[DEBUG]    🔄 合成后将缓存到: /app/appdata/tts_cache/network_a1b2c3d4.wav
[DEBUG]   ✅ 语音合成完成，耗时: 1820 ms
[DEBUG]   💾 已缓存，下次播放将零延时
```

### 测试场景2: 后续播放相同文本
```
[DEBUG] 🗣️ CommonControl: 使用 TTS 播放预警: "一号皮带准备启动，请注意"
[DEBUG] 🌐 SherpaOnnxTTS网络传输: "一号皮带准备启动，请注意"
[DEBUG]    ✅ 使用TTS缓存（零延时）: /app/appdata/tts_cache/network_a1b2c3d4.wav
[DEBUG]    📊 缓存命中，跳过合成
[DEBUG]   ⏱️  sayToNetwork() 总耗时: 45 ms
```

### 测试场景3: 系统启动预热
```
[DEBUG] 🔥 CommonControl: 启动TTS缓存预热（异步）...
[DEBUG]    🔄 预热缓存: 1 号皮带
[DEBUG]   ✅ 语音合成完成，耗时: 1820 ms
[DEBUG]    🔄 预热缓存: 2 号皮带
[DEBUG]   ✅ 语音合成完成，耗时: 1850 ms
...
[DEBUG] ✅ CommonControl: TTS缓存预热完成（10个文本）
```

---

## ❓ 待确认问题

### 问题1: 缓存文件命名冲突
- AlarmPlaybackService使用MD5哈希
- 我的方案使用qHash（16进制）
- 是否需要统一命名规则？

**建议**: 使用不同前缀区分
- AlarmPlaybackService: `alarm_{MD5}.wav`
- SherpaOnnxTTS: `network_{qHash}.wav`

### 问题2: 预热时机
- 当前方案：系统启动5秒后开始预热
- 是否需要调整？

### 问题3: 缓存清理
- 是否需要自动清理旧缓存？
- 缓存大小限制？

---

## 🔍 下一步操作

1. **用户确认**: 是否实施方案A（在SherpaOnnxTTS层添加缓存）？
2. **开始编码**: 修改SherpaOnnxTTS::sayToNetwork()
3. **编译测试**: 验证缓存效果
4. **性能评估**: 测量实际延时改善

---

**相关文档**:
- [voip.md日志](../log/voip.md) - 延时数据来源
- [TTS延时优化方案](03-TTS延时优化方案-FIX100.300.md)
- [AlarmPlaybackService.cpp](../../src/control/AlarmPlaybackService.cpp) - 现有缓存实现
- [SherpaOnnxTTS.cpp](../../src/control/SherpaOnnxTTS.cpp) - 需要修改的文件
