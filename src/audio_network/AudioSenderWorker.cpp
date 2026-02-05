// ✅ 2026-01-22 20:30 [FIX 100.295] 独立音频发送线程实现
// 文件: src/audio_network/AudioSenderWorker.cpp
// 功能: 在独立线程中发送 Opus 音频帧，不受主线程干扰
// 作者: Claude AI
// 日期: 2026-01-22

#include "AudioSenderWorker.h"
#include <QDebug>

AudioSenderWorker::AudioSenderWorker(WebSocketClient* wsClient, QObject *parent)
    : QObject(parent)
    , m_wsClient(wsClient)
    , m_currentFrameIndex(0)
    , m_totalFrames(0)
    , m_isSending(false)
    , m_sendTimer(new QTimer(this))
    , m_sendStartTime(0)
{
    // ✅ 使用 Qt::PreciseTimer 提高定时精度
    m_sendTimer->setTimerType(Qt::PreciseTimer);
    m_sendTimer->setSingleShot(true);  // 单次触发（每次手动调度）

    // 连接定时器信号
    connect(m_sendTimer, &QTimer::timeout, this, &AudioSenderWorker::sendNextFrame);

    qDebug() << "✅ AudioSenderWorker: 音频发送工作线程已创建（Qt::PreciseTimer）";
}

AudioSenderWorker::~AudioSenderWorker()
{
    stopSending();
    qDebug() << "✅ AudioSenderWorker: 音频发送工作线程已销毁";
}

void AudioSenderWorker::startSending(const QList<QByteArray>& frames)
{
    // ✅ 2026-01-22 20:30 [独立线程发送] 开始发送 Opus 帧列表

    // 检查是否正在发送
    if (m_isSending) {
        qWarning() << "⚠️ AudioSenderWorker: 正在发送中，忽略新任务";
        return;
    }

    // 检查帧列表是否为空
    if (frames.isEmpty()) {
        QString error = "Opus 帧列表为空";
        qWarning() << "❌ AudioSenderWorker:" << error;
        emit sendingError(error);
        return;
    }

    // 初始化发送状态
    m_frames = frames;
    m_currentFrameIndex = 0;
    m_totalFrames = frames.size();
    m_isSending = true;

    // 启动时间计数器
    if (!m_elapsedTimer.isValid()) {
        m_elapsedTimer.start();
    }

    // ✅ 2026-01-22 20:30 [预缓冲] 延迟 40ms 开始发送（防止 TCP 缓冲区积压）
    m_sendStartTime = m_elapsedTimer.elapsed() + 40;

    qDebug() << "🚀 AudioSenderWorker: 开始发送 Opus 帧";
    qDebug() << "   总帧数:" << m_totalFrames << "帧";
    qDebug() << "   音频时长:" << (m_totalFrames * 20) << "ms";
    qDebug() << "   ⏱️ 预缓冲 40ms";

    emit sendingStarted(m_totalFrames);

    // 延迟 40ms 后开始发送第一帧
    m_sendTimer->start(40);
}

void AudioSenderWorker::stopSending()
{
    // ✅ 2026-01-22 20:30 [停止发送] 停止音频发送

    if (!m_isSending) {
        return;
    }

    qDebug() << "🛑 AudioSenderWorker: 停止音频发送";

    m_isSending = false;
    m_sendTimer->stop();
    m_frames.clear();
    m_currentFrameIndex = 0;
    m_totalFrames = 0;
}

void AudioSenderWorker::sendNextFrame()
{
    // ✅ 2026-01-22 20:30 [发送单帧] 发送下一帧 Opus 数据

    // 检查是否已发送完成
    if (!m_isSending || m_currentFrameIndex >= m_totalFrames) {
        qDebug() << "✅ AudioSenderWorker: 所有帧发送完成";
        m_isSending = false;
        emit sendingFinished();
        return;
    }

    // 获取当前时间
    qint64 currentTime = m_elapsedTimer.elapsed();

    // 发送当前帧（WebSocket BINARY 帧）
    // ✅ 2026-01-22 21:10 [FIX 100.295.1] 跨线程调用（独立线程 → 主线程）
    // worker 在独立线程，WebSocketClient 在主线程
    // 使用 Qt::QueuedConnection 确保线程安全
    const QByteArray& opusFrame = m_frames[m_currentFrameIndex];
    QMetaObject::invokeMethod(m_wsClient, "sendBinaryFrame",
                              Qt::QueuedConnection,
                              Q_ARG(QByteArray, opusFrame));

    // 更新发送进度
    m_currentFrameIndex++;

    // 发送进度信号（每 50 帧发送一次，减少跨线程信号开销）
    if ((m_currentFrameIndex - 1) % 50 == 0) {
        emit sendingProgress(m_currentFrameIndex, m_totalFrames);
    }

    // ========== 绝对时间戳控制（精确 20ms 间隔）==========

    // 核心公式：下一帧应该发送的绝对时间戳
    // 公式：startTime + frameIndex * 20ms
    qint64 nextFrameAbsoluteTime = m_sendStartTime + m_currentFrameIndex * 20;
    qint64 delay = nextFrameAbsoluteTime - currentTime;

    // 调试日志（每 50 帧打印一次）
    if ((m_currentFrameIndex - 1) % 50 == 0) {
        qDebug() << "   📡 已发送:" << (m_currentFrameIndex - 1) << "/" << m_totalFrames
                 << "帧（" << currentTime << "ms）";
        qDebug() << "      下一帧延迟:" << delay << "ms";
    }

    // 调度下一帧发送
    if (delay > 0) {
        // 正常情况：延迟发送
        m_sendTimer->start(delay);
    } else {
        // 已经延迟了：立即发送
        if (delay < -10) {
            // 严重延迟：打印警告
            qWarning() << "⚠️ AudioSenderWorker 严重延迟（帧" << m_currentFrameIndex
                       << "）: 已延迟" << (-delay) << "ms";
        }
        // 立即发送下一帧
        m_sendTimer->start(0);
    }
}
