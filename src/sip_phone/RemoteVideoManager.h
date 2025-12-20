#ifndef REMOTEVIDEOMANAGER_H
#define REMOTEVIDEOMANAGER_H

#include <QObject>
#include <QTimer>
#include <QVideoSink>
#include <QVideoFrame>
#include <QImage>
#include <QMutex>
#include <QThread>
#include <QQueue>
#include <QWaitCondition>
#include <pjsua.h>
#include <pjmedia.h>

/**
 * @brief 视频帧缓冲结构 - 用于异步处理
 */
struct FrameBuffer {
    QByteArray data;           // 帧数据
    pjmedia_format format;     // 帧格式
    int width;
    int height;
    qint64 timestamp;          // 时间戳(毫秒)
};

/**
 * @brief 视频帧处理工作线程
 */
class FrameProcessorThread : public QThread {
    Q_OBJECT
public:
    explicit FrameProcessorThread(QObject *parent = nullptr);
    ~FrameProcessorThread();

    void enqueueFrame(const FrameBuffer &frame);
    void stop();

signals:
    void frameProcessed(QVideoFrame frame);

protected:
    void run() override;

private:
    QQueue<FrameBuffer> m_frameQueue;
    QMutex m_queueMutex;
    QWaitCondition m_queueCondition;
    bool m_running;
    const int MAX_QUEUE_SIZE = 10;  // ✅ Attempt 20: 增加到10帧，减少丢帧（原3帧太小导致严重丢帧）

    QVideoFrame convertFrameToQt(const FrameBuffer &frameBuffer);
};

/**
 * @brief 远端视频管理器 - 事件驱动的 PJSIP Port 方案 + 异步处理
 *
 * 创建自定义 pjmedia_port 并注册到 video conference bridge,
 * 让 PJSIP 在收到新帧时主动推送(push),而不是定时器轮询(pull)
 * v6 优化：使用工作线程异步处理视频帧，避免阻塞 PJSIP 回调
 */
class RemoteVideoManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject* videoSink READ videoSink CONSTANT)
    Q_PROPERTY(bool hasRemoteVideo READ hasRemoteVideo NOTIFY hasRemoteVideoChanged)

public:
    explicit RemoteVideoManager(QObject *parent = nullptr);
    ~RemoteVideoManager();

    QObject* videoSink() const;
    bool hasRemoteVideo() const { return m_hasRemoteVideo; }

    // 通话状态更新（从 PJSIP 线程调用）
    Q_INVOKABLE void onCallConnected(int callId);
    Q_INVOKABLE void onCallDisconnected();

    // ✅ PJSIP 回调 - 当有新帧到达时被 PJSIP 调用(push 模式)
    // 在 PJSIP 线程中调用,必须快速处理
    void onFrameReceived(pjmedia_frame *frame, const pjmedia_format *fmt);

signals:
    void hasRemoteVideoChanged();
    void errorOccurred(const QString &error);

    // 内部信号 - 用于线程安全地启动/停止检查定时器
    void requestStartCheck();
    void requestStopCheck();

    // 内部信号 - 将视频帧从 PJSIP 线程传递到 Qt 主线程
    void frameReadyForDisplay(QVideoFrame frame);

private slots:
    void checkRemoteVideo();

    // 在 Qt 主线程中启动/停止检查定时器
    void startCheckInMainThread();
    void stopCheckInMainThread();

    // 在 Qt 主线程中显示帧
    void displayFrame(QVideoFrame frame);

private:
    QVideoSink *m_videoSink;
    bool m_hasRemoteVideo;
    pjsua_call_id m_currentCallId;
    QTimer *m_checkTimer;  // 只用于检查远端视频是否可用
    QMutex m_mutex;

    // ✅ 自定义 pjmedia_port 相关
    pjmedia_port *m_customPort;
    pj_pool_t *m_pool;
    unsigned m_videoMediaIndex;
    int m_customSlot;           // 自定义port在vid_conf中的slot ID
    bool m_formatMismatch;      // 标记是否检测到格式不匹配

    // ✅ v6: 异步处理工作线程
    FrameProcessorThread *m_processorThread;

    bool detectAndConnectToVideoBridge();
    void disconnectFromVideoBridge();

    // 创建和销毁自定义 port
    // 默认使用 640x360 @ 60fps - 匹配 FreeSWITCH 的视频格式
    bool createCustomPort(int width = 640, int height = 360, int fps_num = 60, int fps_denum = 1);
    void destroyCustomPort();

    // ✅ Attempt 22: 隐藏所有PJSIP SDL窗口
    void hideAllPjsipVideoWindows();

    QVideoFrame convertPjFrameToQt(pjmedia_frame *frame, const pjmedia_format *fmt);

    // ✅ 静态 C 风格回调,供 PJSIP 调用
    static pj_status_t port_put_frame(pjmedia_port *port, pjmedia_frame *frame);
    static pj_status_t port_get_frame(pjmedia_port *port, pjmedia_frame *frame);
    static pj_status_t port_on_destroy(pjmedia_port *port);
};

#endif // REMOTEVIDEOMANAGER_H
