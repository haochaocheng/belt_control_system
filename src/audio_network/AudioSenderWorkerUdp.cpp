// ========================================
// AudioSenderWorkerUdp.cpp
// ========================================
// 日期: 2026-01-22 22:50
// 作者: Claude AI
// 实现: UDP 组播音频发送工作对象（独立线程）
// ========================================

#include "AudioSenderWorkerUdp.h"
#include <QDebug>

// ✅ 2026-01-22 22:50 [独立线程] UDP 组播音频发送工作对象
// 功能：20ms 精确定时，不受主线程干扰
// 架构：独立线程 + Qt::PreciseTimer + 绝对时间戳控制 + 40ms 预缓冲

AudioSenderWorkerUdp::AudioSenderWorkerUdp(const QHostAddress& multicastAddress,
                                             quint16 multicastPort,
                                             QObject *parent)
    : QObject(parent)
    , m_udpSocket(new QUdpSocket(this))
    , m_multicastAddress(multicastAddress)
    , m_multicastPort(multicastPort)
    , m_currentFrameIndex(0)
    , m_totalFrames(0)
    , m_isSending(false)
    , m_sendTimer(new QTimer(this))
    , m_sendStartTime(0)
{
    // ✅ 配置 UDP socket（不需要绑定端口，仅发送）
    // 组播发送不需要加入组播组

    // ✅ 配置精确定时器
    // Qt::PreciseTimer: 1ms 精度（vs Qt::CoarseTimer: 5% 精度）
    m_sendTimer->setTimerType(Qt::PreciseTimer);
    m_sendTimer->setSingleShot(true);  // 单次触发，手动调度

    // ✅ 连接定时器信号
    connect(m_sendTimer, &QTimer::timeout, this, &AudioSenderWorkerUdp::sendNextFrame);

    qDebug() << "✅ AudioSenderWorkerUdp: 已创建（UDP 组播音频发送）";
    qDebug() << "   组播地址:" << m_multicastAddress.toString();
    qDebug() << "   组播端口:" << m_multicastPort;
    qDebug() << "   定时器精度: Qt::PreciseTimer (±1ms)";
}

AudioSenderWorkerUdp::~AudioSenderWorkerUdp()
{
    stopSending();
    qDebug() << "✅ AudioSenderWorkerUdp: 已销毁";
}

void AudioSenderWorkerUdp::startSending(const QList<QByteArray>& frames)
{
    // ✅ 保存帧列表
    m_frames = frames;
    m_totalFrames = frames.size();
    m_currentFrameIndex = 0;
    m_isSending = true;

    if (m_totalFrames == 0) {
        qWarning() << "⚠️ AudioSenderWorkerUdp: 帧列表为空，无法发送";
        emit sendingError("帧列表为空");
        return;
    }

    qDebug() << "🚀 AudioSenderWorkerUdp: 开始发送 Opus 帧";
    qDebug() << "   总帧数:" << m_totalFrames << "帧";
    qDebug() << "   音频时长:" << (m_totalFrames * 20) << "ms";

    // ✅ 启动高精度计时器
    m_elapsedTimer.start();

    // ✅ 2026-01-22 19:30 [FIX 100.293] 预缓冲 40ms
    // 原因：让系统准备好，避免前期发送过快导致缓冲区积压
    // 效果：消除前期积压，延迟稳定在 20ms
    m_sendStartTime = m_elapsedTimer.elapsed() + 40;
    qDebug() << "   ⏱️ 预缓冲 40ms";

    // ✅ 发送开始信号
    emit sendingStarted(m_totalFrames);

    // ✅ 启动定时器（40ms 后发送第一帧）
    m_sendTimer->start(40);
}

void AudioSenderWorkerUdp::stopSending()
{
    if (!m_isSending) {
        return;
    }

    m_sendTimer->stop();
    m_frames.clear();
    m_isSending = false;

    qDebug() << "⏹️ AudioSenderWorkerUdp: 已停止发送";
}

void AudioSenderWorkerUdp::sendNextFrame()
{
    // ✅ 检查是否已发送完成
    if (!m_isSending || m_currentFrameIndex >= m_totalFrames) {
        qDebug() << "✅ AudioSenderWorkerUdp: 所有帧发送完成";
        m_isSending = false;
        emit sendingFinished();
        return;
    }

    // ✅ 获取当前时间（相对于 elapsedTimer.start()）
    qint64 currentTime = m_elapsedTimer.elapsed();

    // ✅ 发送当前帧（UDP 组播）
    const QByteArray& opusFrame = m_frames[m_currentFrameIndex];
    qint64 bytesSent = m_udpSocket->writeDatagram(opusFrame,
                                                   m_multicastAddress,
                                                   m_multicastPort);

    if (bytesSent == -1) {
        qWarning() << "❌ AudioSenderWorkerUdp: UDP 发送失败" << m_udpSocket->errorString();
        emit sendingError("UDP 发送失败: " + m_udpSocket->errorString());
        stopSending();
        return;
    }

    // ✅ 更新发送进度
    m_currentFrameIndex++;

    // ✅ 每 50 帧打印一次进度（避免日志过多）
    if (m_currentFrameIndex % 50 == 0 || m_currentFrameIndex == m_totalFrames) {
        qint64 nextFrameAbsoluteTime = m_sendStartTime + m_currentFrameIndex * 20;
        qint64 delay = nextFrameAbsoluteTime - currentTime;
        qDebug() << "📡 已发送:" << m_currentFrameIndex << "/" << m_totalFrames << "帧"
                 << "（" << currentTime << "ms）";
        qDebug() << "   下一帧延迟:" << delay << "ms";
    }

    // ✅ 发送进度信号
    emit sendingProgress(m_currentFrameIndex, m_totalFrames);

    // ✅ 核心算法：绝对时间戳控制
    // 下一帧应该发送的绝对时间 = 开始时间 + 帧索引 * 20ms
    // 例如：
    //   - 开始时间: 1000ms（预缓冲 40ms 后）
    //   - 第 0 帧: 1000ms（立即发送）
    //   - 第 1 帧: 1020ms（延迟 20ms）
    //   - 第 2 帧: 1040ms（延迟 20ms）
    //   - ...
    // 这样可以避免累积误差
    qint64 nextFrameAbsoluteTime = m_sendStartTime + m_currentFrameIndex * 20;
    qint64 delay = nextFrameAbsoluteTime - currentTime;

    // ✅ 调度下一帧发送
    if (delay > 0) {
        // 正常情况：延迟发送
        m_sendTimer->start(delay);
    } else {
        // 已经延迟了：立即发送（补偿）
        m_sendTimer->start(0);
    }
}
