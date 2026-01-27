#include "SherpaOnnxTTS.h"
#include <QDebug>
#include <QDir>
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QEventLoop>
#include <QTimer>

// ✅ 2026-01-27 [FIX 100.300.45]: 包含网络传输类的完整定义
#include "audio_network/AudioNetworkTcpSender.h"
#include "audio_network/AudioNetworkSender.h"

SherpaOnnxTTS::SherpaOnnxTTS(QObject *parent)
    : QObject(parent)
    , m_ttsProcess(new QProcess(this))
    , m_mediaPlayer(new QMediaPlayer(this))
    , m_audioOutput(new QAudioOutput(this))
    , m_state(Ready)
    , m_available(false)
    , m_rate(1.0)
    , m_volume(0.8)
    , m_speakerId(0)           // ✅ 2026-01-23 09:30 [FIX 100.299] 默认说话人0
    , m_maxSpeakerId(173)      // ✅ 2026-01-23 09:30 [FIX 100.299] 默认aishell3的最大值
    , m_sceneName("unknown")   // ✅ 2026-01-23 09:30 [FIX 100.299] 默认场景名
    , m_tcpSender(nullptr)        // ✅ 2026-01-22 23:30 [网络传输] TCP 发送器（延迟初始化）
    , m_udpSender(nullptr)        // ✅ 2026-01-22 23:30 [网络传输] UDP 发送器（延迟初始化）
    , m_networkTempFile(nullptr)  // ✅ 2026-01-22 23:30 [网络传输] 临时文件指针
{
    qDebug() << "🎙️ SherpaOnnxTTS: 初始化TTS封装（进程通信模式）";

    // 连接媒体播放器
    m_mediaPlayer->setAudioOutput(m_audioOutput);
    m_audioOutput->setVolume(m_volume);

    connect(m_mediaPlayer, &QMediaPlayer::playbackStateChanged,
            this, &SherpaOnnxTTS::onMediaPlayerStateChanged);

    // 连接进程信号
    connect(m_ttsProcess, &QProcess::readyReadStandardOutput,
            this, &SherpaOnnxTTS::onProcessReadyRead);
    connect(m_ttsProcess, &QProcess::errorOccurred,
            this, &SherpaOnnxTTS::onProcessError);

    // ✅ 2026-01-22 23:30 [网络传输] 初始化音频网络发送器
    m_tcpSender = new AudioNetworkTcpSender(this);
    m_udpSender = new AudioNetworkSender(this);

    // 连接网络传输完成信号
    connect(m_tcpSender, &AudioNetworkTcpSender::playbackFinished,
            this, &SherpaOnnxTTS::onNetworkTransmissionFinished);
    connect(m_udpSender, &AudioNetworkSender::playbackFinished,
            this, &SherpaOnnxTTS::onNetworkTransmissionFinished);
}

SherpaOnnxTTS::~SherpaOnnxTTS()
{
    // ✅ 2026-01-22 23:30 [网络传输] 清理网络传输资源
    if (m_tcpSender && m_tcpSender->isPlaying()) {
        m_tcpSender->stopPlayback();
    }
    if (m_udpSender && m_udpSender->isPlaying()) {
        m_udpSender->stopPlayback();
    }

    // 删除临时文件
    if (m_networkTempFile) {
        delete m_networkTempFile;
        m_networkTempFile = nullptr;
    }

    if (m_ttsProcess->state() != QProcess::NotRunning) {
        qDebug() << "🛑 SherpaOnnxTTS: 停止TTS服务进程";

        // 尝试发送停止命令（不使用事件循环等待响应）
        QJsonObject stopCmd;
        stopCmd["command"] = "stop";
        QJsonDocument doc(stopCmd);
        QByteArray jsonData = doc.toJson(QJsonDocument::Compact);
        jsonData.append('\n');

        m_ttsProcess->write(jsonData);
        m_ttsProcess->waitForBytesWritten(1000);

        // 等待进程自然退出
        if (!m_ttsProcess->waitForFinished(2000)) {
            qWarning() << "⚠️  TTS服务进程未正常退出，强制终止";
            m_ttsProcess->terminate();  // 先尝试温和终止

            if (!m_ttsProcess->waitForFinished(1000)) {
                m_ttsProcess->kill();  // 强制杀死
            }
        }
    }

    qDebug() << "✅ SherpaOnnxTTS: TTS封装已销毁";
}

bool SherpaOnnxTTS::initialize(const QString &modelDir)
{
    m_modelDir = modelDir;

    qDebug() << "🎙️ SherpaOnnxTTS: 初始化TTS引擎，模型目录:" << modelDir;

    // 检查模型目录是否存在
    QDir dir(modelDir);
    if (!dir.exists()) {
        qWarning() << "❌ 模型目录不存在:" << modelDir;
        return false;
    }

    // 查找TTS服务可执行文件（跨平台）
    QString appDir = QCoreApplication::applicationDirPath();

#ifdef _WIN32
    QString exeSuffix = ".exe";
#else
    QString exeSuffix = "";  // Linux/Unix no extension
#endif

    // 尝试几个可能的位置
    QStringList possiblePaths = {
        appDir + "/sherpa_tts_service" + exeSuffix,                      // 同目录
        appDir + "/../src/tts_service/build-msvc/Release/sherpa_tts_service" + exeSuffix,  // 开发环境(Windows)
        appDir + "/../src/tts_service/build/sherpa_tts_service" + exeSuffix,  // 开发环境(Linux)
        appDir + "/bin/sherpa_tts_service" + exeSuffix                    // 安装目录
    };

    for (const QString &path : possiblePaths) {
        if (QFile::exists(path)) {
            m_serviceExecutable = path;
            break;
        }
    }

    if (m_serviceExecutable.isEmpty()) {
        qWarning() << "❌ 未找到 Sherpa-ONNX TTS 服务可执行文件";
        qWarning() << "   搜索路径:";
        for (const QString &path : possiblePaths) {
            qWarning() << "   -" << path;
        }
        qWarning() << "   请编译 src/tts_service 并复制到应用程序目录";
        qWarning() << "   Windows: 使用 MSVC 编译";
        qWarning() << "   Linux: 使用 CMake 编译";
        return false;
    }

    qDebug() << "✅ 找到TTS服务:" << m_serviceExecutable;

    // 启动TTS服务进程
    qDebug() << "🚀 启动TTS服务进程...";
    m_ttsProcess->start(m_serviceExecutable);

    if (!m_ttsProcess->waitForStarted(5000)) {
        qWarning() << "❌ TTS服务进程启动失败:" << m_ttsProcess->errorString();
        return false;
    }

    qDebug() << "✅ TTS服务进程已启动，PID:" << m_ttsProcess->processId();

    // 发送初始化命令
    QJsonObject initCmd;
    initCmd["command"] = "init";
    initCmd["model_dir"] = modelDir;

    QJsonObject response;
    if (!sendCommand(initCmd, response, 30000)) {
        qWarning() << "❌ TTS初始化失败:" << response["message"].toString();
        m_ttsProcess->kill();
        return false;
    }

    if (!response["success"].toBool()) {
        qWarning() << "❌ TTS初始化失败:" << response["message"].toString();
        m_ttsProcess->kill();
        return false;
    }

    m_available = true;
    qDebug() << "✅ SherpaOnnxTTS初始化成功:" << response["message"].toString();
    return true;
}

void SherpaOnnxTTS::say(const QString &text)
{
    if (!m_available || m_ttsProcess->state() != QProcess::Running) {
        qWarning() << "❌ TTS引擎不可用";
        return;
    }

    if (text.isEmpty()) {
        qWarning() << "❌ TTS文本为空";
        return;
    }

    qDebug() << "🗣️  SherpaOnnxTTS播放:" << text;

    setState(Speaking);

    // 生成临时文件路径
    QTemporaryFile tempFile(QDir::tempPath() + "/tts_XXXXXX.wav");
    tempFile.setAutoRemove(false);  // 播放完再删除
    if (!tempFile.open()) {
        qWarning() << "❌ 无法创建临时文件";
        setState(Error);
        return;
    }
    QString outputPath = tempFile.fileName();
    tempFile.close();

    // 发送合成命令
    QMutexLocker locker(&m_mutex);
    if (synthesize(text, outputPath)) {
        // 播放生成的音频
        m_mediaPlayer->setSource(QUrl::fromLocalFile(outputPath));
        m_mediaPlayer->play();
    } else {
        setState(Error);
        QFile::remove(outputPath);  // 删除失败的文件
    }
}

void SherpaOnnxTTS::stop()
{
    if (m_mediaPlayer->playbackState() != QMediaPlayer::StoppedState) {
        m_mediaPlayer->stop();
    }
    setState(Ready);
}

bool SherpaOnnxTTS::synthesizeToFile(const QString &text, const QString &outputFile)
{
    if (!m_available || m_ttsProcess->state() != QProcess::Running) {
        qWarning() << "❌ TTS引擎不可用";
        return false;
    }

    if (text.isEmpty()) {
        qWarning() << "❌ TTS文本为空";
        return false;
    }

    // 调用私有synthesize方法
    QMutexLocker locker(&m_mutex);
    return synthesize(text, outputFile);
}

bool SherpaOnnxTTS::sendCommand(const QJsonObject &command, QJsonObject &response, int timeoutMs)
{
    if (m_ttsProcess->state() != QProcess::Running) {
        qWarning() << "❌ TTS服务进程未运行";
        response["success"] = false;
        response["message"] = "Service process not running";
        return false;
    }

    // 转换为JSON字符串
    QJsonDocument doc(command);
    QByteArray jsonData = doc.toJson(QJsonDocument::Compact);
    jsonData.append('\n');

    qDebug() << "📤 发送命令:" << jsonData;

    // 清空响应缓冲区
    m_responseBuffer.clear();

    // 写入命令
    m_ttsProcess->write(jsonData);
    m_ttsProcess->waitForBytesWritten(1000);

    // 等待响应
    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);

    bool responseReceived = false;

    // 当收到响应时停止循环
    connect(m_ttsProcess, &QProcess::readyReadStandardOutput, &loop, [&]() {
        onProcessReadyRead();
        if (!m_responseBuffer.isEmpty() && m_responseBuffer.contains('\n')) {
            responseReceived = true;
            loop.quit();
        }
    });

    // 超时退出
    connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);

    timeout.start(timeoutMs);
    loop.exec();

    if (!responseReceived) {
        qWarning() << "⏱️  等待TTS响应超时";
        response["success"] = false;
        response["message"] = "Timeout waiting for response";
        return false;
    }

    // 解析响应
    QString responseLine = m_responseBuffer.left(m_responseBuffer.indexOf('\n'));
    m_responseBuffer.remove(0, responseLine.length() + 1);

    qDebug() << "📥 收到响应:" << responseLine;

    QJsonDocument responseDoc = QJsonDocument::fromJson(responseLine.toUtf8());
    if (responseDoc.isNull() || !responseDoc.isObject()) {
        qWarning() << "❌ 响应JSON解析失败";
        response["success"] = false;
        response["message"] = "Invalid JSON response";
        return false;
    }

    response = responseDoc.object();
    return response["success"].toBool();
}

bool SherpaOnnxTTS::synthesize(const QString &text, const QString &outputPath)
{
    qDebug() << "  合成语音到文件:" << outputPath;

    // ✅ 2026-01-22 23:40 [调试] 测量 TTS 合成延迟
    QElapsedTimer synthesizeTimer;
    synthesizeTimer.start();

    // 发送合成命令
    QJsonObject synthCmd;
    synthCmd["command"] = "synthesize";
    synthCmd["text"] = text;
    synthCmd["output_path"] = outputPath;
    synthCmd["rate"] = m_rate;
    // ✅ 2026-01-23 09:30 [FIX 100.299] 使用可配置的说话人ID（原来硬编码为0）
    synthCmd["speaker_id"] = m_speakerId;

    QJsonObject response;
    if (!sendCommand(synthCmd, response, 30000)) {
        qWarning() << "  ❌ 语音合成失败:" << response["message"].toString();
        return false;
    }

    if (!response["success"].toBool()) {
        qWarning() << "  ❌ 语音合成失败:" << response["message"].toString();
        return false;
    }

    qint64 synthesizeTime = synthesizeTimer.elapsed();
    qDebug() << "  ✅ 语音合成成功:" << response["message"].toString();
    qDebug() << "  ⏱️  TTS 合成耗时:" << synthesizeTime << "ms";
    return true;
}

void SherpaOnnxTTS::setRate(double rate)
{
    m_rate = qBound(0.5, rate, 2.0);  // 限制在0.5-2.0之间
    qDebug() << "设置语速:" << m_rate;
}

void SherpaOnnxTTS::setPitch(double pitch)
{
    Q_UNUSED(pitch);
    // sherpa-onnx VITS模型暂不支持音调调整
}

void SherpaOnnxTTS::setVolume(double volume)
{
    m_volume = qBound(0.0, volume, 1.0);
    if (m_audioOutput) {
        m_audioOutput->setVolume(m_volume);
    }
}

void SherpaOnnxTTS::setState(State newState)
{
    if (m_state != newState) {
        m_state = newState;
        emit stateChanged(newState);
    }
}

void SherpaOnnxTTS::onMediaPlayerStateChanged(QMediaPlayer::PlaybackState state)
{
    qDebug() << "📻 媒体播放器状态:" << state;

    switch (state) {
    case QMediaPlayer::StoppedState:
        setState(Ready);

        // 删除临时文件
        if (!m_mediaPlayer->source().isEmpty()) {
            QString filePath = m_mediaPlayer->source().toLocalFile();
            if (filePath.contains("/tts_") && filePath.endsWith(".wav")) {
                QFile::remove(filePath);
                qDebug() << "  删除临时文件:" << filePath;
            }
        }

        // ✅ 2026-01-23 15:30 [FIX 100.300.7] 发送本地播放完成信号
        emit localPlaybackFinished();
        break;

    case QMediaPlayer::PlayingState:
        setState(Speaking);
        break;

    case QMediaPlayer::PausedState:
        setState(Paused);
        break;
    }
}

void SherpaOnnxTTS::onProcessReadyRead()
{
    // 读取进程输出
    QByteArray output = m_ttsProcess->readAllStandardOutput();
    m_responseBuffer.append(QString::fromUtf8(output));
}

void SherpaOnnxTTS::onProcessError(QProcess::ProcessError error)
{
    qWarning() << "❌ TTS服务进程错误:" << error << m_ttsProcess->errorString();
    m_available = false;
    setState(Error);
}

// ✅ 2026-01-22 23:30 [网络传输] 语音输出到网络实现
// ✅ 2026-01-22 23:40 [调试] 测量整体延迟
// ✅ 2026-01-23 09:00 [FIX 100.300.1] TTS智能缓存机制
// 原因：相同文本每次都重新合成，延时1.9秒不可接受
// 方案：首次合成后缓存到持久化文件，后续直接使用缓存（<50ms）
void SherpaOnnxTTS::sayToNetwork(const QString &text, bool useTcp)
{
    QElapsedTimer totalTimer;
    totalTimer.start();

    if (!m_available || m_ttsProcess->state() != QProcess::Running) {
        qWarning() << "❌ TTS引擎不可用";
        return;
    }

    if (text.isEmpty()) {
        qWarning() << "❌ TTS文本为空";
        return;
    }

    qDebug() << "🌐 SherpaOnnxTTS网络传输:" << text;
    qDebug() << "   模式:" << (useTcp ? "TCP（上位机）" : "UDP（音频模块）");

    // ✅ 2026-01-23 09:00 [FIX 100.300.1] 检查缓存
    QString cacheFilePath = getCacheFilePath(text);

    if (QFile::exists(cacheFilePath)) {
        // 缓存命中，直接使用
        qDebug() << "   ✅ 使用TTS缓存（零延时）:" << cacheFilePath;
        qDebug() << "   📊 缓存命中，跳过合成";

        // 直接发送缓存文件到网络
        if (useTcp) {
            qDebug() << "   📡 使用 TCP 模式发送到上位机";
            m_tcpSender->playAudioToNetwork(cacheFilePath);
        } else {
            qDebug() << "   📡 使用 UDP 模式发送到音频模块";
            m_udpSender->playAudioToNetwork(cacheFilePath);
        }

        qint64 totalTime = totalTimer.elapsed();
        qDebug() << "   ⏱️  sayToNetwork() 总耗时:" << totalTime << "ms（使用缓存）";
        return;
    }

    // 缓存未命中，需要合成
    qDebug() << "   ⚠️  缓存未命中，开始TTS合成...";
    qDebug() << "   🔄 合成后将缓存到:" << cacheFilePath;

    // 合成语音到缓存文件（而非临时文件）
    QElapsedTimer synthesizeTimer;
    synthesizeTimer.start();

    QMutexLocker locker(&m_mutex);
    if (!synthesize(text, cacheFilePath)) {
        qWarning() << "❌ 语音合成失败";
        return;
    }

    qint64 synthesizeTime = synthesizeTimer.elapsed();
    qDebug() << "   ✅ 语音合成完成，耗时:" << synthesizeTime << "ms";
    qDebug() << "   💾 已缓存，下次播放将零延时";

    // 选择发送器并发送到网络
    QElapsedTimer sendTimer;
    sendTimer.start();

    if (useTcp) {
        qDebug() << "   📡 使用 TCP 模式发送到上位机";
        m_tcpSender->playAudioToNetwork(cacheFilePath);
    } else {
        qDebug() << "   📡 使用 UDP 模式发送到音频模块";
        m_udpSender->playAudioToNetwork(cacheFilePath);
    }

    qint64 sendStartTime = sendTimer.elapsed();
    qint64 totalTime = totalTimer.elapsed();

    qDebug() << "   ⏱️  发送启动耗时:" << sendStartTime << "ms";
    qDebug() << "   ⏱️  sayToNetwork() 总耗时:" << totalTime << "ms";
    qDebug() << "      - TTS 合成:" << synthesizeTime << "ms";
    qDebug() << "      - 发送启动:" << sendStartTime << "ms";
}

void SherpaOnnxTTS::stopNetworkTransmission()
{
    qDebug() << "🛑 停止TTS网络传输";

    // 停止正在进行的网络传输
    if (m_tcpSender && m_tcpSender->isPlaying()) {
        m_tcpSender->stopPlayback();
    }
    if (m_udpSender && m_udpSender->isPlaying()) {
        m_udpSender->stopPlayback();
    }

    // 清理临时文件
    if (m_networkTempFile) {
        delete m_networkTempFile;
        m_networkTempFile = nullptr;
    }
}

void SherpaOnnxTTS::onNetworkTransmissionFinished()
{
    qDebug() << "✅ TTS网络传输完成";

    // 清理临时文件
    if (m_networkTempFile) {
        qDebug() << "   删除临时文件:" << m_networkTempFile->fileName();
        delete m_networkTempFile;
        m_networkTempFile = nullptr;
    }

    // ✅ 2026-01-23 00:30 [信号转发] 通知外部调用者（CommonControl）传输完成
    // 原因：CommonControl 需要接收此信号来继续预警循环（播放第2、3次）
    // 流程：playWarningOnce() → sayToNetwork() → [异步传输] → playbackFinished → 此槽 → emit信号 → CommonControl::onPlaybackFinished()
    emit networkTransmissionFinished();
}

// ✅ 2026-01-23 01:30 [网络共享] 设置共享的 TCP 音频发送器
// 原因：避免 TTS 创建未连接的发送器实例，复用 CommonControl 已连接的 WebSocket
// 背景：
//   - TTS 构造函数创建独立的 AudioNetworkTcpSender 实例（SherpaOnnxTTS.cpp:39）
//   - 这个新实例没有连接到 WebSocket（日志：❌ "WebSocket 未连接，无法播放音频"）
//   - CommonControl 的发送器已成功连接（日志：✅ "WebSocket 已连接到 192.168.1.4:8000"）
// 解决方案：
//   - 删除 TTS 自己创建的发送器
//   - 复用 CommonControl 的已连接发送器
//   - 正确处理信号连接（断开旧的，连接新的）
void SherpaOnnxTTS::setTcpSender(AudioNetworkTcpSender* sender)
{
    if (!sender) {
        qWarning() << "⚠️ SherpaOnnxTTS: 尝试设置 nullptr TCP 发送器";
        return;
    }

    // 断开旧发送器的信号连接
    if (m_tcpSender) {
        disconnect(m_tcpSender, &AudioNetworkTcpSender::playbackFinished,
                   this, &SherpaOnnxTTS::onNetworkTransmissionFinished);

        // 如果旧发送器是自己创建的（parent 是 this），删除它
        if (m_tcpSender->parent() == this) {
            qDebug() << "   删除旧的 TCP 发送器（自己创建的）";
            delete m_tcpSender;
        }
    }

    // 设置新的共享发送器
    m_tcpSender = sender;

    // 连接新发送器的信号
    connect(m_tcpSender, &AudioNetworkTcpSender::playbackFinished,
            this, &SherpaOnnxTTS::onNetworkTransmissionFinished);

    qDebug() << "✅ SherpaOnnxTTS: 已设置共享的 TCP 发送器";
}

void SherpaOnnxTTS::setUdpSender(AudioNetworkSender* sender)
{
    if (!sender) {
        qWarning() << "⚠️ SherpaOnnxTTS: 尝试设置 nullptr UDP 发送器";
        return;
    }

    // 断开旧发送器的信号连接
    if (m_udpSender) {
        disconnect(m_udpSender, &AudioNetworkSender::playbackFinished,
                   this, &SherpaOnnxTTS::onNetworkTransmissionFinished);

        // 如果旧发送器是自己创建的（parent 是 this），删除它
        if (m_udpSender->parent() == this) {
            qDebug() << "   删除旧的 UDP 发送器（自己创建的）";
            delete m_udpSender;
        }
    }

    // 设置新的共享发送器
    m_udpSender = sender;

    // 连接新发送器的信号
    connect(m_udpSender, &AudioNetworkSender::playbackFinished,
            this, &SherpaOnnxTTS::onNetworkTransmissionFinished);

    qDebug() << "✅ SherpaOnnxTTS: 已设置共享的 UDP 发送器";
}

// ✅ 2026-01-23 09:00 [FIX 100.300.1] 获取TTS缓存文件路径
QString SherpaOnnxTTS::getCacheFilePath(const QString &text) const
{
    // 生成缓存文件路径
    // 使用 qHash 生成文本哈希值（16进制）
    QString cacheKey = QString::number(qHash(text), 16);

    // 缓存目录：/app/appdata/tts_cache/
    // 文件命名：network_{qHash}.wav
    // 与 AlarmPlaybackService 的缓存共用目录，但使用不同前缀区分
    QString cacheFilePath = QString("/app/appdata/tts_cache/network_%1.wav").arg(cacheKey);

    return cacheFilePath;
}

// ✅ 2026-01-23 09:30 [FIX 100.299] 设置说话人ID
void SherpaOnnxTTS::setSpeakerId(int speakerId)
{
    m_speakerId = qBound(0, speakerId, m_maxSpeakerId);
    qDebug() << "🎤 [TTS]" << m_sceneName << "设置说话人ID:" << m_speakerId;
}

// ✅ 2026-01-23 09:30 [FIX 100.299] 动态切换模型
// ✅ 2026-01-23 20:00 [FIX 100.300.15] 修复切换模型时进程未停止的问题
bool SherpaOnnxTTS::switchModel(const QString &modelDir)
{
    qDebug() << "🔄 [TTS]" << m_sceneName << "切换模型:" << modelDir;

    emit modelLoadingProgress("正在停止当前TTS服务...");

    // ✅ 2026-01-23 20:00 [FIX 100.300.15] 正确停止 TTS 服务进程
    // 原因：stop() 只停止播放，不停止进程，导致 "Process is already running" 错误
    // 方案：先停止播放，再停止进程
    if (m_ttsProcess->state() != QProcess::NotRunning) {
        // 停止播放
        stop();

        // 停止 TTS 服务进程
        qDebug() << "   停止 TTS 服务进程...";

        // 发送停止命令
        QJsonObject stopCmd;
        stopCmd["command"] = "stop";
        QJsonDocument doc(stopCmd);
        QByteArray jsonData = doc.toJson(QJsonDocument::Compact);
        jsonData.append('\n');

        m_ttsProcess->write(jsonData);
        m_ttsProcess->waitForBytesWritten(1000);

        // 等待进程自然退出
        if (!m_ttsProcess->waitForFinished(2000)) {
            qWarning() << "   ⚠️  TTS服务进程未正常退出，强制终止";
            m_ttsProcess->terminate();  // 先尝试温和终止

            if (!m_ttsProcess->waitForFinished(1000)) {
                m_ttsProcess->kill();  // 强制杀死
            }
        }

        qDebug() << "   ✅ TTS 服务进程已停止";
    }

    emit modelLoadingProgress("正在加载新模型...");

    // 重新初始化
    bool success = initialize(modelDir);

    if (success) {
        emit modelLoadingProgress("模型加载成功");
        emit modelSwitched(true, modelDir);
    } else {
        emit modelLoadingProgress("模型加载失败");
        emit modelSwitched(false, modelDir);
    }

    return success;
}

// ✅ 2026-01-23 09:30 [FIX 100.299] 设置场景名称
void SherpaOnnxTTS::setSceneName(const QString &sceneName)
{
    m_sceneName = sceneName;
    qDebug() << "🏷️  [TTS] 设置场景名称:" << m_sceneName;
}

// ✅ 2026-01-23 09:30 [FIX 100.299] 测试TTS
void SherpaOnnxTTS::testTTS(const QString &text)
{
    qDebug() << "🔊 [TTS]" << m_sceneName << "测试语音:" << text;
    say(text);
}
