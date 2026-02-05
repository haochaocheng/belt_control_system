# TTS 缓存预热卡住问题分析

**日期**: 2026-01-23 10:50
**版本**: FIX 100.299 - Phase 5 调试
**状态**: 🔍 问题已定位

---

## 📋 问题描述

应用程序启动后卡在 TTS 缓存预热阶段：

```
[DEBUG] 🔥 CommonControl: 启动TTS缓存预热（异步）...
[DEBUG] ✅ CommonControl: TTS缓存预热已启动（后台进行）
[DEBUG]    🔄 预热缓存: 1 号皮带
[DEBUG]   合成语音到文件: "/app/appdata/tts_cache/network_21839810471ce12c.wav"
[DEBUG] 📤 发送命令: {"command":"synthesize",...}
[DEBUG]    🔄 预热缓存: 2 号皮带
```

**症状**：
- 第一个缓存文件已生成（57K，Jan 23 02:36）
- 日志显示开始预热 "2 号皮带"，但没有发送合成命令
- 没有显示 "✅ 语音合成成功" 或超时错误
- 程序完全卡住，无法继续启动

---

## 🔍 根本原因分析

### 对比两种预缓存方法

#### ✅ AlarmPlaybackService（成功）

**代码位置**: `src/control/AlarmPlaybackService.cpp:509-529`

```cpp
void AlarmPlaybackService::precacheTtsText(const QString &text)
{
    QString cachedFile = m_ttsCacheDir + "/" + hash + ".wav";

    // 如果已存在，直接加入缓存映射
    if (QFile::exists(cachedFile)) {
        m_ttsCache[text] = cachedFile;
        qDebug() << "  ✓ 已存在:" << text;
        return;  // ✅ 直接返回，不调用 TTS
    }

    // 生成缓存文件（同步阻塞）
    if (m_tts && m_tts->synthesizeToFile(text, cachedFile)) {
        m_ttsCache[text] = cachedFile;
        qDebug() << "  ✅ 已缓存:" << text;
    }
}
```

**调用方式**（Line 471-475）：
```cpp
qDebug() << "  开始预缓存" << commonTexts.size() << "个常用报警文本...";

for (const QString &text : commonTexts) {
    precacheTtsText(text);  // ✅ 同步顺序调用
}

qDebug() << "✅ TTS缓存初始化完成，已缓存" << m_ttsCache.size() << "个文本";
```

**为什么成功**：
1. **同步顺序执行**：一个接一个完成
2. **文件已存在**：所有 10 个文件都已缓存，直接返回
3. **没有实际调用 TTS**：避免了阻塞问题

---

#### ❌ CommonControl（失败）

**代码位置**: `src/control/CommonControl.cpp:1208-1227`

```cpp
// 延迟启动，避免阻塞主线程（每个间隔200ms）
QTimer::singleShot(i * 200, this, [this, i]() {
    QString warningText = QString("%1号皮带准备启动，请注意").arg(chineseNumber);
    QString cacheFilePath = m_tts->getCacheFilePath(warningText);

    if (!QFile::exists(cacheFilePath)) {
        qDebug() << "   🔄 预热缓存:" << i << "号皮带";

        // ❌ 异步合成到缓存（synthesizeToFile 会阻塞，但在定时器回调中执行）
        if (m_tts) {
            m_tts->synthesizeToFile(warningText, cacheFilePath);
        }
    }
});
```

**为什么失败**：
1. **异步并发执行**：每 200ms 启动一个定时器
2. **synthesizeToFile 是同步阻塞的**：会等待 30 秒超时
3. **多个调用同时进行**：
   - 0ms: 启动定时器 1 → 调用 synthesizeToFile("1号皮带") → **阻塞等待**
   - 200ms: 启动定时器 2 → 调用 synthesizeToFile("2号皮带") → **阻塞等待**
   - 400ms: 启动定时器 3 → ...
4. **TTS 服务无法处理并发请求**：导致混乱和卡死

---

## 🎯 核心问题

### synthesizeToFile 是同步阻塞的

**代码位置**: `src/control/SherpaOnnxTTS.cpp:314-346`

```cpp
bool SherpaOnnxTTS::synthesize(const QString &text, const QString &outputPath)
{
    QJsonObject synthCmd;
    synthCmd["command"] = "synthesize";
    synthCmd["text"] = text;
    synthCmd["output_path"] = outputPath;

    QJsonObject response;
    if (!sendCommand(synthCmd, response, 30000)) {  // ⏱️ 30秒超时
        qWarning() << "  ❌ 语音合成失败:" << response["message"].toString();
        return false;
    }

    return true;
}
```

**sendCommand 的实现**（Line 244-299）：
```cpp
bool SherpaOnnxTTS::sendCommand(const QJsonObject &command, QJsonObject &response, int timeoutMs)
{
    // 写入命令
    m_ttsProcess->write(jsonData);
    m_ttsProcess->waitForBytesWritten(1000);

    // ❌ 使用 QEventLoop 阻塞等待响应
    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);

    connect(m_ttsProcess, &QProcess::readyReadStandardOutput, &loop, [&]() {
        onProcessReadyRead();
        if (!m_responseBuffer.isEmpty() && m_responseBuffer.contains('\n')) {
            responseReceived = true;
            loop.quit();  // 收到响应后退出循环
        }
    });

    connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);
    timeout.start(timeoutMs);  // 30000ms = 30秒
    loop.exec();  // ❌ 阻塞当前线程

    if (!responseReceived) {
        qWarning() << "⏱️  等待TTS响应超时";
        return false;
    }

    return true;
}
```

**关键点**：
- `loop.exec()` 会**阻塞当前线程**，直到收到响应或超时
- 如果多个定时器同时触发，会有多个 `loop.exec()` 同时阻塞
- TTS 服务可能无法处理并发请求，导致响应丢失

---

## ✅ 解决方案

### 方案 1：改为同步顺序预热（推荐）

**修改 CommonControl 的预热方法**，使用 AlarmPlaybackService 的成功模式：

```cpp
void CommonControl::warmupTtsCache()
{
    qDebug() << "🔥 CommonControl: 启动TTS缓存预热（同步顺序）...";

    // 同步顺序预热（不使用定时器）
    for (int i = 1; i <= 10; i++) {
        QString chineseNumber = numberToChinese(i);
        QString warningText = QString("%1号皮带准备启动，请注意").arg(chineseNumber);
        QString cacheFilePath = m_tts->getCacheFilePath(warningText);

        if (!QFile::exists(cacheFilePath)) {
            qDebug() << "   🔄 预热缓存:" << i << "号皮带";

            // ✅ 同步调用，一个接一个完成
            if (m_tts) {
                if (m_tts->synthesizeToFile(warningText, cacheFilePath)) {
                    qDebug() << "   ✅ 缓存成功:" << i << "号皮带";
                } else {
                    qWarning() << "   ❌ 缓存失败:" << i << "号皮带";
                }
            }
        } else {
            qDebug() << "   ✅ 缓存已存在:" << i << "号皮带";
        }
    }

    qDebug() << "✅ CommonControl: TTS缓存预热完成";
}
```

**优点**：
- 简单可靠，与 AlarmPlaybackService 一致
- 避免并发问题
- 容易调试和维护

**缺点**：
- 会阻塞主线程（但在启动阶段可接受）
- 如果有 10 个文件需要生成，可能需要较长时间

---

### 方案 2：使用工作线程（复杂）

将预热工作移到独立线程：

```cpp
void CommonControl::warmupTtsCache()
{
    qDebug() << "🔥 CommonControl: 启动TTS缓存预热（后台线程）...";

    // 在独立线程中执行预热
    QThread *workerThread = new QThread(this);
    QObject *worker = new QObject();
    worker->moveToThread(workerThread);

    connect(workerThread, &QThread::started, worker, [this, worker, workerThread]() {
        // 在工作线程中同步顺序预热
        for (int i = 1; i <= 10; i++) {
            // ... 同步调用 synthesizeToFile
        }

        // 完成后清理
        workerThread->quit();
        worker->deleteLater();
    });

    connect(workerThread, &QThread::finished, workerThread, &QThread::deleteLater);
    workerThread->start();
}
```

**优点**：
- 不阻塞主线程
- 可以在后台慢慢完成

**缺点**：
- 实现复杂
- 需要处理线程安全问题
- TTS 对象可能不是线程安全的

---

## 🚀 推荐实施方案

**使用方案 1：同步顺序预热**

**原因**：
1. **简单可靠**：与 AlarmPlaybackService 一致
2. **启动阶段可接受**：用户可以等待几秒钟
3. **避免并发问题**：TTS 服务不需要处理并发
4. **容易调试**：日志清晰，问题容易定位

**实施步骤**：
1. 修改 `CommonControl::warmupTtsCache()` 方法
2. 移除 `QTimer::singleShot` 异步调用
3. 改为 `for` 循环同步顺序调用
4. 添加详细日志（成功/失败/已存在）
5. 重新编译部署测试

---

## 📝 相关代码位置

- **CommonControl 预热方法**: `src/control/CommonControl.cpp:1208-1227`
- **AlarmPlaybackService 预缓存**: `src/control/AlarmPlaybackService.cpp:509-529`
- **SherpaOnnxTTS::synthesizeToFile**: `src/control/SherpaOnnxTTS.cpp:227-242`
- **SherpaOnnxTTS::synthesize**: `src/control/SherpaOnnxTTS.cpp:314-346`
- **SherpaOnnxTTS::sendCommand**: `src/control/SherpaOnnxTTS.cpp:244-299`

---

## 🎓 经验教训

1. **异步 + 同步阻塞 = 灾难**
   - 不要在异步回调中调用同步阻塞函数
   - 会导致多个阻塞调用同时进行

2. **TTS 服务不支持并发**
   - 一次只能处理一个请求
   - 需要顺序调用

3. **参考成功案例**
   - AlarmPlaybackService 已经证明同步顺序方式可行
   - 不要重新发明轮子

4. **启动阶段可以阻塞**
   - 用户可以等待几秒钟
   - 不需要过度优化

---

## ✅ 下一步操作

1. **修改 CommonControl::warmupTtsCache()** - 改为同步顺序预热
2. **重新编译部署** - `.\build-ubuntu24-apt.ps1 188`
3. **测试验证** - 查看日志确认预热成功
4. **更新文档** - 记录修复过程

**状态**: 问题已定位，准备修复
