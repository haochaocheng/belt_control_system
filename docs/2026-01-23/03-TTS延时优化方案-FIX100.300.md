# TTS延时优化方案 - FIX 100.300

**日期**: 2026-01-23
**问题**: TTS合成延时1.8-2秒，不可接受
**目标**: 将延时降低到100ms以内

---

## 📊 问题分析

### 当前延时数据（来自voip.md日志）

```
Line 621:  ⏱️  TTS 合成耗时: 1820 ms
Line 1076: ⏱️  TTS 合成耗时: 1868 ms
Line 1361: ⏱️  TTS 合成耗时: 1978 ms
Line 2488: ⏱️  TTS 合成耗时: 1791 ms
Line 2766: ⏱️  TTS 合成耗时: 2018 ms
```

**平均延时**: 约1.9秒（1900ms）
**文本内容**: "一号皮带准备启动，请注意"（相同文本）

### 问题根源

1. **每次都重新合成** ❌
   - 相同文本"一号皮带准备启动，请注意"每次都重新合成
   - 没有使用缓存机制
   - 浪费CPU资源和时间

2. **TTS引擎性能** ⚠️
   - vits-zh-aishell3模型在ARM64上合成速度较慢
   - 8000 Hz采样率，约28000-32000个采样点
   - 合成时间约1.8-2秒

3. **没有预热机制** ❌
   - 系统启动后第一次合成也需要1.8秒
   - 没有预先缓存常用文本

---

## 🎯 优化方案

**说明**: 预录音频方案已实现，本方案专注于优化TTS合成延时

### 方案1: TTS智能缓存机制（推荐⭐）

**原理**: 预合成常用文本，缓存到持久化存储，后续直接使用缓存

**核心思路**:
1. 相同文本只合成一次（首次1.9秒）
2. 合成后缓存到 `/app/appdata/tts_cache/`
3. 后续播放直接读取缓存（<50ms）
4. 系统启动时预热常用文本（异步，不阻塞启动）

**优势**:
- ✅ **后续零延时**：首次合成后，后续<50ms
- ✅ **灵活性高**：可以动态生成任意文本
- ✅ **持久化**：缓存保存在appdata，重启后仍有效
- ✅ **自动预热**：系统启动时异步预合成1-10号皮带文本

**劣势**:
- ⚠️ 首次合成仍需1.9秒（但只有一次）
- ⚠️ 需要管理缓存文件（自动清理旧缓存）

**实施步骤**:

#### 1.1 修改SherpaOnnxTTS添加智能缓存

**文件**: `src/control/SherpaOnnxTTS.cpp`

```cpp
// ✅ 2026-01-23 09:00 [FIX 100.300] TTS智能缓存机制
void SherpaOnnxTTS::sayToNetwork(const QString &text, bool useTcp)
{
    qDebug() << "🌐 SherpaOnnxTTS网络传输:" << text;

    // 生成缓存文件路径（基于场景和文本哈希）
    QString cacheKey = QString::number(qHash(text), 16);  // 16进制哈希
    QString cacheFilePath = QString("/app/appdata/tts_cache/%1_%2.wav")
                                .arg(m_sceneName.isEmpty() ? "default" : m_sceneName)
                                .arg(cacheKey);

    // 检查缓存是否存在
    if (QFile::exists(cacheFilePath)) {
        qDebug() << "   ✅ 使用TTS缓存（零延时）:" << cacheFilePath;
        qDebug() << "   📊 缓存命中，跳过合成";

        // 直接使用缓存文件
        if (useTcp && m_tcpSender && m_tcpSender->isConnected()) {
            m_tcpSender->playAudioFile(cacheFilePath);
        } else if (!useTcp && m_udpSender) {
            m_udpSender->playAudioFile(cacheFilePath);
        }
        return;
    }

    // 缓存不存在，需要合成
    qDebug() << "   ⚠️  缓存未命中，开始TTS合成...";
    qDebug() << "   🔄 合成后将缓存到:" << cacheFilePath;

    QElapsedTimer timer;
    timer.start();

    // 合成到缓存文件
    if (!synthesizeToFile(text, cacheFilePath)) {
        qWarning() << "   ❌ TTS 合成失败";
        return;
    }

    qint64 synthesisTime = timer.elapsed();
    qDebug() << "   ✅ 语音合成完成，耗时:" << synthesisTime << "ms";
    qDebug() << "   💾 已缓存，下次播放将零延时";

    // 发送到网络
    if (useTcp && m_tcpSender && m_tcpSender->isConnected()) {
        m_tcpSender->playAudioFile(cacheFilePath);
    } else if (!useTcp && m_udpSender) {
        m_udpSender->playAudioFile(cacheFilePath);
    }
}
```

#### 1.2 系统启动时预热TTS缓存

**文件**: `src/control/CommonControl.cpp`

```cpp
// ✅ 2026-01-23 09:00 [FIX 100.300] 预热TTS缓存（异步，不阻塞启动）
void CommonControl::preloadTTSCache()
{
    qDebug() << "🔥 CommonControl: 启动TTS缓存预热（异步）...";

    // 预合成1-10号皮带的预警文本
    for (int i = 1; i <= 10; ++i) {
        // 延迟启动，避免阻塞主线程（每个间隔200ms）
        QTimer::singleShot(i * 200, this, [this, i]() {
            QString chineseNumber = numberToChinese(i);
            QString warningText = QString("%1号皮带准备启动，请注意").arg(chineseNumber);

            // 生成缓存文件路径
            QString cacheKey = QString::number(qHash(warningText), 16);
            QString cacheFilePath = QString("/app/appdata/tts_cache/startup_warning_%1.wav")
                                        .arg(cacheKey);

            // 检查缓存是否已存在
            if (!QFile::exists(cacheFilePath)) {
                qDebug() << "   🔄 预热缓存:" << i << "号皮带";

                // 异步合成到缓存
                if (m_tts) {
                    m_tts->synthesizeToFile(warningText, cacheFilePath);
                }
            } else {
                qDebug() << "   ✅ 缓存已存在:" << i << "号皮带";
            }
        });
    }

    qDebug() << "✅ CommonControl: TTS缓存预热已启动（后台进行）";
}

// 在初始化时调用
void CommonControl::initialize()
{
    // ... 现有初始化代码 ...

    // 延迟5秒后启动预热（等待系统稳定）
    QTimer::singleShot(5000, this, [this]() {
        preloadTTSCache();
    });
}
```

**预期效果**:
- 系统启动后5秒开始预热
- 每个文本间隔200ms合成（避免CPU峰值）
- 预热完成后，1-10号皮带预警全部零延时
- 首次播放其他文本：1.9秒（合成并缓存）
- 后续播放：<50ms（使用缓存）

---

### 方案2: 切换到更快的TTS模型

**原理**: 使用更轻量级或优化更好的TTS模型

**可选模型测试**:

#### 2.1 sherpa-onnx-vits-zh-ll (5说话人, 16kHz)
- 模型更小，可能更快
- 需要实际测试性能

#### 2.2 降低采样率 (8kHz → 4kHz)
- 合成速度可能提升50%
- 音质下降（不推荐）

**实施**: 需要逐个测试模型性能

**预期效果**: 可能将1.9秒降低到1.0-1.5秒（仍然较慢）

---

### 方案3: 流式TTS（边合成边播放）

**原理**: 不等待完整合成，边合成边发送音频帧

**技术难点**:
- Sherpa-ONNX是否支持流式输出？（需要查文档）
- 网络传输需要支持流式发送
- 实现复杂度高

**预期效果**:
- 首字延时：可能降低到200-500ms
- 总延时：仍需1.9秒完成全部合成

**评估**: 实现复杂，收益有限（不推荐）

---

### 方案4: 多线程TTS预合成

**原理**: 使用独立线程在后台预合成常用文本

**实施**:
1. 创建TTS预合成线程
2. 系统启动时在后台合成1-10号皮带文本
3. 合成完成后缓存到文件

**优势**:
- 不阻塞主线程
- 预合成完成后零延时

**劣势**:
- 与方案1的预热机制类似
- 增加线程管理复杂度

**评估**: 方案1已包含此功能（QTimer异步）

---

### 方案5: 使用GPU加速（长期）

**原理**: 使用Mali GPU加速TTS合成

**技术难点**:
- Sherpa-ONNX是否支持Mali GPU？
- 需要重新编译ONNX Runtime with GPU support
- 实现复杂度极高

**预期效果**: 可能将1.9秒降低到500-1000ms

**评估**: 实现成本高，收益不确定（不推荐）

---

### 方案6: 混合策略（推荐⭐⭐）

**原理**: 结合方案1（缓存）+ 方案2（更快模型）

**实施步骤**:
1. **Phase 1**: 实施方案1（TTS智能缓存）
   - 立即解决重复文本延时问题
   - 预热机制确保常用文本零延时

2. **Phase 2**: 测试更快的TTS模型
   - 测试 sherpa-onnx-vits-zh-ll
   - 测试其他轻量级模型
   - 如果找到更快的模型，替换默认模型

**预期效果**:
- Phase 1完成后：常用文本零延时，新文本1.9秒
- Phase 2完成后：新文本可能降低到1.0-1.5秒

---

## 📋 推荐实施方案

### 最佳方案：方案1（TTS智能缓存）⭐⭐⭐

**理由**:
1. **立即见效**：常用文本（1-10号皮带）零延时
2. **实施简单**：只需修改SherpaOnnxTTS和CommonControl
3. **持久化**：缓存保存在appdata，重启后仍有效
4. **自动预热**：系统启动后自动预合成常用文本

**实施步骤**:
1. ✅ 修改 `SherpaOnnxTTS::sayToNetwork()` 添加缓存逻辑
2. ✅ 修改 `CommonControl::initialize()` 添加预热机制
3. ✅ 编译测试
4. ✅ 验证缓存命中率

**预期效果**:
- 首次播放"一号皮带准备启动，请注意"：1.9秒（合成并缓存）
- 后续播放相同文本：<50ms（使用缓存）
- 系统启动5秒后，1-10号皮带全部预热完成

---

### 长期优化：方案6（混合策略）

如果方案1仍不满足需求，可以继续实施：
- 测试更快的TTS模型
- 研究GPU加速可行性

---

## 🔧 实施计划

### Phase 1: TTS智能缓存（立即实施）

#### 步骤1: 修改SherpaOnnxTTS.cpp
- 添加缓存检查逻辑
- 生成缓存文件路径（基于文本哈希）
- 缓存命中时直接使用，未命中时合成并缓存

#### 步骤2: 修改CommonControl.cpp
- 添加 `preloadTTSCache()` 方法
- 在 `initialize()` 中延迟5秒调用预热

#### 步骤3: 编译测试
```powershell
.\build-ubuntu24-apt.ps1 192.168.10.188
```

#### 步骤4: 验证效果
- 查看日志，确认缓存命中
- 测量实际延时（应<50ms）
- 检查缓存文件是否生成

---

### Phase 2: 模型性能测试（可选）

如果Phase 1效果不理想，再测试其他模型。

---

## 📊 预期效果对比

| 方案 | 首次延时 | 后续延时 | 灵活性 | 实施难度 | 推荐度 |
|------|---------|---------|--------|---------|--------|
| **当前** | 1900ms | 1900ms | 高 | - | - |
| **方案1（智能缓存）** | 1900ms | <50ms | 高 | 简单 | ⭐⭐⭐ |
| **方案2（更快模型）** | 1000ms? | 1000ms? | 高 | 中等 | ⭐ |
| **方案3（流式TTS）** | 500ms | 1900ms | 高 | 复杂 | ⭐ |
| **方案4（多线程）** | 1900ms | <50ms | 高 | 中等 | ⭐⭐ |
| **方案5（GPU加速）** | 500ms? | 500ms? | 高 | 极难 | ❌ |
| **方案6（混合策略）** | 1000ms | <50ms | 高 | 中等 | ⭐⭐⭐ |

---

## ❓ 待确认问题

### 问题1: 缓存策略
- 缓存文件命名：`{场景}_{文本哈希}.wav`
- 缓存目录：`/app/appdata/tts_cache/`
- 缓存清理：是否需要自动清理旧缓存？

### 问题2: 预热时机
- 系统启动后5秒开始预热
- 每个文本间隔200ms合成
- 是否需要调整时机？

### 问题3: 缓存范围
- 当前预热1-10号皮带
- 是否需要预热其他常用文本？

---

## 🔍 下一步操作

1. **用户确认**: 是否实施方案1（TTS智能缓存）？
2. **开始编码**: 修改SherpaOnnxTTS和CommonControl
3. **编译测试**: 验证缓存效果
4. **性能评估**: 测量实际延时改善

---

**相关文档**:
- [voip.md日志](../log/voip.md) - 延时数据来源
- [TTS模型改进方案](01-TTS模型改进方案-音质优化和模型选择.md)
- [TTS动态配置UI方案](../技术决策/TTS模型动态配置UI方案.md)
