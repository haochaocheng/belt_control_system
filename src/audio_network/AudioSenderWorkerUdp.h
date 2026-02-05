// ========================================
// AudioSenderWorkerUdp.h
// ========================================
// 日期: 2026-01-22 22:50
// 作者: Claude AI
// 目的: UDP 组播音频发送工作对象（独立线程）
// 参考: AudioSenderWorker.h（TCP 版本）
//
// 功能：
// 1. 在独立线程中运行（隔离主线程干扰）
// 2. Qt::PreciseTimer 精确定时（20ms ± 1ms）
// 3. 绝对时间戳控制（避免累积误差）
// 4. 40ms 预缓冲（稳定发送）
//
// 架构：
// - 运行在独立线程（QThread）
// - 接收 Opus 帧列表（主线程传入）
// - 定时发送到 UDP 组播地址（224.1.x.1:8800）
// ========================================

#ifndef AUDIOSENDERWORKERUDP_H
#define AUDIOSENDERWORKERUDP_H

#include <QObject>
#include <QUdpSocket>
#include <QHostAddress>
#include <QTimer>
#include <QElapsedTimer>
#include <QByteArray>
#include <QList>

/**
 * @brief UDP 组播音频发送工作对象（独立线程）
 *
 * 设计目标：
 * - 20ms 精确定时（误差 < 5%）
 * - 不受主线程干扰（UI、数据库、键盘事件）
 * - 适应恶劣网络环境（预缓冲、绝对时间戳控制）
 *
 * 使用示例：
 * @code
 * // 主线程
 * QThread* thread = new QThread(this);
 * AudioSenderWorkerUdp* worker = new AudioSenderWorkerUdp(multicastAddr, port);
 * worker->moveToThread(thread);
 * thread->start();
 *
 * // 发送 Opus 帧
 * QMetaObject::invokeMethod(worker, "startSending",
 *                           Qt::QueuedConnection,
 *                           Q_ARG(QList<QByteArray>, opusFrames));
 * @endcode
 *
 * 工作流程：
 * 1. 主线程调用 startSending(frames)
 * 2. 预缓冲 40ms
 * 3. 每 20ms 精确发送一帧到 UDP 组播
 * 4. 所有帧发送完成后触发 sendingFinished()
 */
class AudioSenderWorkerUdp : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief 构造函数
     * @param multicastAddress 组播地址（例如：224.1.1.1）
     * @param multicastPort 组播端口（例如：8800）
     * @param parent 父对象
     */
    explicit AudioSenderWorkerUdp(const QHostAddress& multicastAddress,
                                   quint16 multicastPort,
                                   QObject *parent = nullptr);

    /**
     * @brief 析构函数
     */
    ~AudioSenderWorkerUdp();

signals:
    /**
     * @brief 发送开始信号
     * @param totalFrames 总帧数
     */
    void sendingStarted(int totalFrames);

    /**
     * @brief 发送进度信号
     * @param framesSent 已发送帧数
     * @param totalFrames 总帧数
     */
    void sendingProgress(int framesSent, int totalFrames);

    /**
     * @brief 发送完成信号
     */
    void sendingFinished();

    /**
     * @brief 发送错误信号
     * @param error 错误描述
     */
    void sendingError(const QString& error);

public slots:
    /**
     * @brief 开始发送 Opus 帧
     * @param frames Opus 帧列表（每帧 20ms）
     *
     * 工作流程：
     * 1. 保存帧列表到成员变量
     * 2. 启动预缓冲定时器（40ms）
     * 3. 40ms 后开始发送第一帧
     * 4. 每 20ms 精确发送下一帧
     * 5. 所有帧发送完成后触发 sendingFinished()
     *
     * 注意：
     * - 此方法通过 Qt::QueuedConnection 跨线程调用
     * - 帧数据通过 QByteArray 隐式共享（线程安全）
     */
    void startSending(const QList<QByteArray>& frames);

    /**
     * @brief 停止发送
     *
     * 立即停止定时器，清空帧列表
     */
    void stopSending();

private slots:
    /**
     * @brief 发送下一帧（定时器触发）
     *
     * 核心算法：
     * 1. 发送当前帧到 UDP 组播
     * 2. 更新帧索引
     * 3. 计算下一帧应该发送的绝对时间戳
     * 4. 调度定时器（动态调整延迟）
     *
     * 绝对时间戳控制：
     * - nextFrameTime = startTime + frameIndex * 20ms
     * - delay = nextFrameTime - currentTime
     * - 如果 delay > 0，延迟发送
     * - 如果 delay <= 0，立即发送（已经延迟）
     *
     * 这样可以避免累积误差，确保 20ms 精确间隔
     */
    void sendNextFrame();

private:
    // ========== UDP 网络 ==========
    QUdpSocket* m_udpSocket;             ///< UDP socket
    QHostAddress m_multicastAddress;     ///< 组播地址（224.1.x.1）
    quint16 m_multicastPort;             ///< 组播端口（8800）

    // ========== 帧数据 ==========
    QList<QByteArray> m_frames;          ///< Opus 帧列表
    int m_currentFrameIndex;             ///< 当前发送帧索引
    int m_totalFrames;                   ///< 总帧数

    // ========== 发送状态 ==========
    bool m_isSending;                    ///< 是否正在发送

    // ========== 精确定时 ==========
    QTimer* m_sendTimer;                 ///< 发送定时器（Qt::PreciseTimer）
    QElapsedTimer m_elapsedTimer;        ///< 高精度计时器
    qint64 m_sendStartTime;              ///< 发送开始时间戳（ms）
};

#endif // AUDIOSENDERWORKERUDP_H
