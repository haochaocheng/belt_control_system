#include "RemoteVideoManager.h"
#include <QDebug>
#include <QImage>
#include <QDateTime>
#include <QProcess>
#include <QFile>
#include <QCoreApplication>
#include <pjsua-lib/pjsua.h>
#include <pjsua-lib/pjsua_internal.h>

/**
 * @brief 远端视频管理器实现 - 事件驱动的 Push 模式 + 异步处理 (v6)
 *
 * 不再使用定时器主动拉取帧,而是创建自定义 pjmedia_port
 * 并连接到 video conference bridge,让 PJSIP 主动推送帧
 * v6: 使用工作线程异步处理视频帧转换,避免阻塞 PJSIP 回调
 */

// ========== FrameProcessorThread 实现 ==========

FrameProcessorThread::FrameProcessorThread(QObject *parent)
    : QThread(parent)
    , m_running(false)
{
    qDebug() << "✅ FrameProcessorThread created";
}

FrameProcessorThread::~FrameProcessorThread()
{
    stop();
    wait();
    qDebug() << "✅ FrameProcessorThread destroyed";
}

void FrameProcessorThread::enqueueFrame(const FrameBuffer &frame)
{
    QMutexLocker locker(&m_queueMutex);

    // ✅ Attempt 20: 如果队列已满,丢弃最旧的帧（队列扩大到10，丢帧应该大幅减少）
    if (m_frameQueue.size() >= MAX_QUEUE_SIZE) {
        m_frameQueue.dequeue();
        static int dropCount = 0;
        if (dropCount % 100 == 0) {  // 每100帧打印一次（之前30帧打印太频繁）
            qDebug() << "⚠️ [ASYNC] Frame queue full, dropping frame (total drops:" << dropCount << ")";
        }
        dropCount++;
    }

    m_frameQueue.enqueue(frame);
    m_queueCondition.wakeOne();
}

void FrameProcessorThread::stop()
{
    m_running = false;
    m_queueCondition.wakeAll();
}

void FrameProcessorThread::run()
{
    qDebug() << "🚀 [ASYNC] FrameProcessorThread started";
    m_running = true;

    int processedCount = 0;
    qint64 lastLogTime = 0;
    qint64 firstFrameTime = 0;

    while (m_running) {
        FrameBuffer frameBuffer;

        {
            QMutexLocker locker(&m_queueMutex);

            // ✅ Attempt 20: 减少等待超时，提高响应速度
            // 等待新帧或停止信号
            while (m_frameQueue.isEmpty() && m_running) {
                m_queueCondition.wait(&m_queueMutex, 33);  // 33ms 超时（约30fps的帧间隔）
            }

            if (!m_running) {
                break;
            }

            if (m_frameQueue.isEmpty()) {
                continue;
            }

            frameBuffer = m_frameQueue.dequeue();
        }

        // 在锁外处理帧（耗时操作）
        qint64 convertStart = QDateTime::currentMSecsSinceEpoch();
        QVideoFrame videoFrame = convertFrameToQt(frameBuffer);
        qint64 convertEnd = QDateTime::currentMSecsSinceEpoch();

        if (videoFrame.isValid()) {
            emit frameProcessed(videoFrame);
            processedCount++;

            if (firstFrameTime == 0) {
                firstFrameTime = QDateTime::currentMSecsSinceEpoch();
            }

            // 每秒统计一次
            qint64 now = QDateTime::currentMSecsSinceEpoch();
            if (lastLogTime == 0) {
                lastLogTime = now;
            } else if (now - lastLogTime >= 1000) {
                double processingFps = (processedCount * 1000.0) / (now - firstFrameTime);
                qDebug() << "🔧 [ASYNC WORKER]"
                         << "Processed FPS:" << QString::number(processingFps, 'f', 1)
                         << "| Last convert time:" << (convertEnd - convertStart) << "ms"
                         << "| Queue size:" << m_frameQueue.size();
                lastLogTime = now;
            }
        }
    }

    qDebug() << "⏹️ [ASYNC] FrameProcessorThread stopped";
}

QVideoFrame FrameProcessorThread::convertFrameToQt(const FrameBuffer &frameBuffer)
{
    // 这里复制原来的 convertPjFrameToQt 逻辑
    // 但使用 FrameBuffer 中的数据

    int width = frameBuffer.width;
    int height = frameBuffer.height;
    pj_uint32_t pjfmt = frameBuffer.format.id;

    const pj_uint32_t PJMEDIA_FORMAT_J420 = 0x3032344a;

    if (pjfmt == PJMEDIA_FORMAT_I420 || pjfmt == PJMEDIA_FORMAT_IYUV || pjfmt == PJMEDIA_FORMAT_J420) {
        size_t required_size = width * height * 3 / 2;
        if ((size_t)frameBuffer.data.size() < required_size) {
            return QVideoFrame();
        }

        QVideoFrameFormat format(QSize(width, height), QVideoFrameFormat::Format_YUV420P);
        QVideoFrame videoFrame(format);

        if (!videoFrame.map(QVideoFrame::WriteOnly)) {
            return QVideoFrame();
        }

        const unsigned char *src_y = (const unsigned char *)frameBuffer.data.constData();
        const unsigned char *src_u = src_y + width * height;
        const unsigned char *src_v = src_u + (width * height / 4);

        unsigned char *dst_y = videoFrame.bits(0);
        memcpy(dst_y, src_y, width * height);

        unsigned char *dst_u = videoFrame.bits(1);
        memcpy(dst_u, src_u, width * height / 4);

        unsigned char *dst_v = videoFrame.bits(2);
        memcpy(dst_v, src_v, width * height / 4);

        videoFrame.unmap();
        return videoFrame;
    }

    return QVideoFrame();
}

// ========== RemoteVideoManager 实现 ==========

RemoteVideoManager::RemoteVideoManager(QObject *parent)
    : QObject(parent)
    , m_videoSink(new QVideoSink(this))
    , m_hasRemoteVideo(false)
    , m_currentCallId(PJSUA_INVALID_ID)
    , m_checkTimer(new QTimer(this))
    , m_customPort(nullptr)
    , m_pool(nullptr)
    , m_videoMediaIndex(0)
    , m_customSlot(PJSUA_INVALID_ID)
    , m_formatMismatch(false)
    , m_processorThread(nullptr)
{
    qDebug() << "✅ RemoteVideoManager created (Event-driven Push mode + Async v6)";

    // 检查定时器 - 每500ms检查一次远端视频是否可用
    // 一旦检测到视频流,就创建 custom port 并连接到 bridge
    m_checkTimer->setInterval(500);
    connect(m_checkTimer, &QTimer::timeout, this, &RemoteVideoManager::checkRemoteVideo);

    // 连接信号 - 确保定时器在 Qt 主线程中启动/停止
    connect(this, &RemoteVideoManager::requestStartCheck, this, &RemoteVideoManager::startCheckInMainThread, Qt::QueuedConnection);
    connect(this, &RemoteVideoManager::requestStopCheck, this, &RemoteVideoManager::stopCheckInMainThread, Qt::QueuedConnection);

    // ✅ v6: 创建并启动工作线程
    m_processorThread = new FrameProcessorThread(this);
    connect(m_processorThread, &FrameProcessorThread::frameProcessed,
            this, &RemoteVideoManager::displayFrame, Qt::QueuedConnection);
    m_processorThread->start();
    qDebug() << "✅ [ASYNC] Frame processor thread started";
}

RemoteVideoManager::~RemoteVideoManager()
{
    qDebug() << "RemoteVideoManager: Shutting down...";

    // ✅ v6: 先停止工作线程
    if (m_processorThread) {
        m_processorThread->stop();
        m_processorThread->wait(1000);  // 等待最多1秒
        if (m_processorThread->isRunning()) {
            qWarning() << "⚠️ [ASYNC] Force terminating processor thread";
            m_processorThread->terminate();
            m_processorThread->wait();
        }
        qDebug() << "✅ [ASYNC] Frame processor thread stopped";
    }

    disconnectFromVideoBridge();
    destroyCustomPort();
}

QObject* RemoteVideoManager::videoSink() const
{
    return m_videoSink;
}

void RemoteVideoManager::onCallConnected(int callId)
{
    qDebug() << "📹 RemoteVideoManager: Call connected, callId =" << callId;

    /* ✅ 2026-01-09 14:40 [调试 Fix 95] 验证 QVideoSink 连接
     * 问题：Fix 95 解决解码错误后，视频无法显示
     * 目的：检查 m_videoSink 指针是否有效
     * 预期：指针不为空，有效连接到 VideoSinkItem
     */
    qDebug() << "📹 [DEBUG Fix 95] m_videoSink pointer:" << m_videoSink;
    qDebug() << "📹 [DEBUG Fix 95] m_videoSink is valid:" << (m_videoSink != nullptr);

    m_currentCallId = callId;

    // 发送信号,让 Qt 主线程启动检查定时器
    emit requestStartCheck();
}

void RemoteVideoManager::onCallDisconnected()
{
    qDebug() << "🔴 [FIX 72] RemoteVideoManager::onCallDisconnected() entered";
    qDebug() << "📹 RemoteVideoManager: Call disconnected";

    // 发送信号,让 Qt 主线程停止检查定时器
    qDebug() << "🔴 [FIX 72] Emitting requestStopCheck signal";
    emit requestStopCheck();

    // 断开连接并销毁 custom port
    qDebug() << "🔴 [FIX 72] Calling disconnectFromVideoBridge()";
    disconnectFromVideoBridge();
    qDebug() << "🔴 [FIX 72] Calling destroyCustomPort()";
    destroyCustomPort();
    qDebug() << "🔴 [FIX 72] Port cleanup completed";

    m_currentCallId = PJSUA_INVALID_ID;
    m_formatMismatch = false;  // 重置格式不匹配标志

    if (m_hasRemoteVideo) {
        m_hasRemoteVideo = false;
        emit hasRemoteVideoChanged();
    }
}

void RemoteVideoManager::startCheckInMainThread()
{
    if (!m_checkTimer->isActive()) {
        m_checkTimer->start();
        qDebug() << "✅ RemoteVideoManager: Check timer started";
    }
}

void RemoteVideoManager::stopCheckInMainThread()
{
    if (m_checkTimer->isActive()) {
        m_checkTimer->stop();
        qDebug() << "⏹️ RemoteVideoManager: Check timer stopped";
    }
}

void RemoteVideoManager::checkRemoteVideo()
{
    if (m_currentCallId == PJSUA_INVALID_ID) {
        return;
    }

    // ✅ Attempt 24: 修复SDP重新协商后连接检查逻辑
    // 不仅检查custom port是否存在，还要检查call video slot是否仍然连接到custom port
    // 因为SDP重新协商会创建新的video stream，新stream可能没有连接到我们的custom port

    bool needReconnect = false;

    if (m_customPort != nullptr && m_customSlot != PJSUA_INVALID_ID) {
        // 检查custom port是否仍然有效
        pjsua_vid_conf_port_info port_info;
        pj_status_t status = pjsua_vid_conf_get_port_info(m_customSlot, &port_info);

        if (status != PJ_SUCCESS) {
            // Custom port已失效，需要重新连接
            qDebug() << "⚠️ [Attempt 24] Custom port invalid (slot" << m_customSlot << "), reconnecting...";
            needReconnect = true;
        } else {
            // Custom port有效，但需要检查call video slot是否连接到它
            int call_vid_slot = pjsua_call_get_vid_conf_port(m_currentCallId, PJMEDIA_DIR_DECODING);

            if (call_vid_slot == PJSUA_INVALID_ID) {
                // Call video slot不存在，可能还没准备好
                qDebug() << "⚠️ [Attempt 24] Call video slot not ready yet";
                return;
            }

            // ✅ 关键检查：验证call video slot是否连接到我们的custom port
            // 检查方法：尝试获取call video slot的listener列表，看是否包含我们的custom slot
            pjsua_vid_conf_port_info call_port_info;
            status = pjsua_vid_conf_get_port_info(call_vid_slot, &call_port_info);

            if (status == PJ_SUCCESS) {
                // 检查call video port的所有listener
                bool isConnected = false;
                for (unsigned i = 0; i < call_port_info.listener_cnt; ++i) {
                    if (call_port_info.listeners[i] == m_customSlot) {
                        isConnected = true;
                        break;
                    }
                }

                if (!isConnected) {
                    // Call video slot没有连接到我们的custom port（SDP重新协商后的常见情况）
                    qDebug() << "⚠️ [Attempt 24] Call video slot" << call_vid_slot
                             << "not connected to custom slot" << m_customSlot << ", reconnecting...";
                    needReconnect = true;
                } else {
                    // 连接仍然有效，无需重新连接
                    return;
                }
            } else {
                // 无法获取call video port信息，可能出错了
                qDebug() << "⚠️ [Attempt 24] Cannot get call video port info, reconnecting...";
                needReconnect = true;
            }
        }
    } else {
        // Custom port不存在，需要创建并连接
        needReconnect = true;
    }

    if (needReconnect) {
        // 断开旧连接并销毁custom port
        disconnectFromVideoBridge();
        destroyCustomPort();

        // 尝试重新连接到video conference bridge
        bool success = detectAndConnectToVideoBridge();

        if (success && !m_hasRemoteVideo) {
            m_hasRemoteVideo = true;
            emit hasRemoteVideoChanged();
            qDebug() << "✅ [Attempt 24] Connected to video bridge (Push mode)";
        }

        if (success && m_hasRemoteVideo) {
            qDebug() << "🔄 [Attempt 24] Reconnected to video bridge after SDP renegotiation";
        }
    }

    // ✅ Attempt 24: 保持检查定时器运行，以便在SDP重新协商后能自动重新连接
    // m_checkTimer->stop();  // 注释掉这一行，保持定时器运行
}

bool RemoteVideoManager::detectAndConnectToVideoBridge()
{
    // 获取通话信息
    pjsua_call_info ci;
    pj_status_t status = pjsua_call_get_info(m_currentCallId, &ci);

    if (status != PJ_SUCCESS) {
        return false;
    }

    // 查找远端视频流
    for (unsigned i = 0; i < ci.media_cnt; ++i) {
        if (ci.media[i].type == PJMEDIA_TYPE_VIDEO &&
            ci.media[i].status == PJSUA_CALL_MEDIA_ACTIVE &&
            ci.media[i].dir & PJMEDIA_DIR_DECODING) {

            m_videoMediaIndex = i;

            // ✅ 打印硬件解码验证信息
            qDebug() << "==========================================";
            qDebug() << "🔍 [HARDWARE DECODER VERIFICATION]";
            qDebug() << "==========================================";

            // ✅ 声明call_vid_slot一次，后续复用
            int call_vid_slot = PJSUA_INVALID_ID;

            // 获取call video slot用于查询解码器信息
            call_vid_slot = pjsua_call_get_vid_conf_port(m_currentCallId, PJMEDIA_DIR_DECODING);
            if (call_vid_slot != PJSUA_INVALID_ID) {
                pjsua_vid_conf_port_info port_info;
                pj_status_t info_status = pjsua_vid_conf_get_port_info(call_vid_slot, &port_info);

                if (info_status == PJ_SUCCESS) {
                    qDebug() << "📹 Video Stream Info:";
                    qDebug() << "   Port Name:" << QString::fromUtf8(port_info.name.ptr, port_info.name.slen);
                    qDebug() << "   Format:" << port_info.format.id;

                    // 获取视频格式详情
                    pjmedia_video_format_detail *vfd = pjmedia_format_get_video_format_detail(&port_info.format, PJ_TRUE);
                    if (vfd) {
                        qDebug() << "   Resolution:" << vfd->size.w << "x" << vfd->size.h;
                        qDebug() << "   FPS:" << vfd->fps.num << "/" << vfd->fps.denum;
                        qDebug() << "   Avg Bitrate:" << vfd->avg_bps << "bps";
                        qDebug() << "   Max Bitrate:" << vfd->max_bps << "bps";
                    }
                }

                // ✅ 真正的硬件解码验证
                verifyHardwareDecoder();
            }

            qDebug() << "==========================================";

            // ✅ 直接使用默认格式创建 custom port
            // 注意：不要从 pjsua_vid_conf_get_port_info() 获取格式，
            // 因为它返回的是 bridge 调整后的格式（如 720x480），
            // 而不是真实的解码器输出格式（如 640x360）。
            // 使用默认的 640x360 @ 30fps 可以避免不必要的缩放。
            qDebug() << "✅ Creating custom port with default format (640x360 @ 30fps)";
            if (!createCustomPort()) {
                qCritical() << "❌ Failed to create custom port with default format";
                return false;
            }

            // 获取通话的视频端口用于连接（复用之前声明的变量）
            call_vid_slot = pjsua_call_get_vid_conf_port(m_currentCallId, PJMEDIA_DIR_DECODING);
            if (call_vid_slot == PJSUA_INVALID_ID) {
                qWarning() << "⚠️ Video port not ready yet, will retry in 500ms...";
                // 销毁刚创建的 custom port，下次再试
                destroyCustomPort();
                return false;  // 返回 false 但不停止定时器，会继续重试
            }

            qDebug() << "✅ Call video slot:" << call_vid_slot;

            // 添加自定义 port 到 video conference
            int custom_slot = PJSUA_INVALID_ID;
            status = pjsua_vid_conf_add_port(m_pool, m_customPort, NULL, &custom_slot);

            if (status != PJ_SUCCESS) {
                qCritical() << "❌ Failed to add custom port to vid conf:" << status;
                return false;
            }

            qDebug() << "✅ Custom port added to vid conf, slot:" << custom_slot;

            // 存储 custom slot ID 用于后续重建
            m_customSlot = custom_slot;

            // 连接: call_video_port -> custom_port (PJSIP 会主动推送帧到我们的 port!)
            status = pjsua_vid_conf_connect(call_vid_slot, custom_slot, NULL);

            if (status != PJ_SUCCESS) {
                qCritical() << "❌ Failed to connect call video to custom port:" << status;
                pjsua_vid_conf_remove_port(custom_slot);
                m_customSlot = PJSUA_INVALID_ID;
                return false;
            }

            qDebug() << "✅ Connected call video slot" << call_vid_slot << "-> custom slot" << custom_slot;
            qDebug() << "🎉 RemoteVideoManager: Event-driven Push mode activated!";

            // ✅ Attempt 22: 隐藏PJSIP自动创建的SDL视频窗口
            // PJSIP会为视频流自动创建SDL窗口，我们使用Qt界面显示，不需要SDL窗口
            hideAllPjsipVideoWindows();

            return true;
        }
    }

    return false;
}

void RemoteVideoManager::disconnectFromVideoBridge()
{
    if (m_customSlot != PJSUA_INVALID_ID) {
        qDebug() << "🔌 RemoteVideoManager: Removing custom port from video conference, slot:" << m_customSlot;
        pjsua_vid_conf_remove_port(m_customSlot);
        m_customSlot = PJSUA_INVALID_ID;
    }

    if (m_customPort) {
        qDebug() << "🔌 RemoteVideoManager: Disconnecting from video bridge";
    }
}

// ========== Port 创建和销毁 ==========

bool RemoteVideoManager::createCustomPort(int width, int height, int fps_num, int fps_denum)
{
    if (m_customPort) {
        return true;  // 已经创建
    }

    // 创建内存池
    m_pool = pjsua_pool_create("remote_video_port", 4000, 4000);
    if (!m_pool) {
        qCritical() << "❌ Failed to create pool for custom port";
        return false;
    }

    // 分配 pjmedia_port 结构
    m_customPort = (pjmedia_port*)pj_pool_zalloc(m_pool, sizeof(pjmedia_port));
    if (!m_customPort) {
        pj_pool_release(m_pool);
        m_pool = nullptr;
        return false;
    }

    // 初始化 port 信息
    pj_str_t name = pj_str((char*)"qt_remote_video_sink");
    pjmedia_port_info_init(&m_customPort->info, &name,
                           PJMEDIA_SIG_CLASS_PORT_VID('Q', 'T'),
                           90000,  // clock_rate (90kHz for video)
                           1,      // channel_count
                           16,     // bits_per_sample
                           1);     // samples_per_frame

    // ✅ 设置视频格式 - 使用实际的分辨率和帧率
    pjmedia_format_init_video(&m_customPort->info.fmt,
                              PJMEDIA_FORMAT_I420,
                              width, height,        // 使用实际视频尺寸
                              fps_num, fps_denum);  // 使用实际帧率

    // ✅ 关键: 设置回调函数
    m_customPort->put_frame = &RemoteVideoManager::port_put_frame;  // PJSIP 推送帧
    m_customPort->get_frame = &RemoteVideoManager::port_get_frame;  // 不需要
    m_customPort->on_destroy = &RemoteVideoManager::port_on_destroy;

    // 将 this 指针存储在 port_data 中,以便在静态回调中访问
    m_customPort->port_data.pdata = this;

    qDebug() << "✅ Custom pjmedia_port created for Qt video sink:"
             << width << "x" << height << "@" << fps_num << "/" << fps_denum << "fps";

    return true;
}

void RemoteVideoManager::destroyCustomPort()
{
    if (m_customPort) {
        m_customPort = nullptr;  // port 由 pool 管理
    }

    if (m_pool) {
        pj_pool_release(m_pool);
        m_pool = nullptr;
        qDebug() << "✅ Custom port pool released";
    }
}

// ========== PJSIP 静态回调函数 (C 风格) ==========

pj_status_t RemoteVideoManager::port_put_frame(pjmedia_port *port, pjmedia_frame *frame)
{
    // ✅ PJSIP 在收到新帧时主动调用这个函数 (Push 模式!)
    // ⚠️ 添加详细日志追踪实际帧到达频率和过滤统计
    static int callback_count = 0;
    static int video_frames = 0;
    static int non_video_frames = 0;
    static int empty_frames = 0;
    static qint64 last_callback_time = 0;
    static qint64 first_callback_time = 0;

    qint64 current_time = QDateTime::currentMSecsSinceEpoch();

    if (callback_count == 0) {
        first_callback_time = current_time;
        qDebug() << "🎯 [PJSIP CALLBACK] First put_frame call";
    }

    callback_count++;

    // 每秒统计一次回调频率
    if (last_callback_time == 0) {
        last_callback_time = current_time;
    } else if (current_time - last_callback_time >= 1000) {
        qint64 elapsed = current_time - last_callback_time;
        double callback_fps = (callback_count * 1000.0) / (current_time - first_callback_time);
        qDebug() << "🎯 [PJSIP CALLBACK FPS]" << QString::number(callback_fps, 'f', 1)
                 << "| Total callbacks:" << callback_count
                 << "| Video frames:" << video_frames
                 << "| Non-video:" << non_video_frames
                 << "| Empty:" << empty_frames
                 << "| Elapsed:" << (current_time - first_callback_time) << "ms";
        last_callback_time = current_time;
    }

    // 从 port_data 恢复 this 指针
    RemoteVideoManager *self = static_cast<RemoteVideoManager*>(port->port_data.pdata);

    if (!self) {
        return PJ_SUCCESS;
    }

    // ✅ 统计帧类型
    if (frame->type != PJMEDIA_FRAME_TYPE_VIDEO) {
        non_video_frames++;
        return PJ_SUCCESS;
    }

    // ✅ 安全检查：验证帧数据有效性
    if (!frame->buf || frame->size == 0) {
        empty_frames++;
        return PJ_SUCCESS;  // 静默忽略无效帧
    }

    video_frames++;

    // 调用成员函数处理帧
    self->onFrameReceived(frame, &port->info.fmt);

    return PJ_SUCCESS;
}

pj_status_t RemoteVideoManager::port_get_frame(pjmedia_port *port, pjmedia_frame *frame)
{
    // Sink port 不需要提供帧
    PJ_UNUSED_ARG(port);
    frame->type = PJMEDIA_FRAME_TYPE_NONE;
    return PJ_SUCCESS;
}

pj_status_t RemoteVideoManager::port_on_destroy(pjmedia_port *port)
{
    qDebug() << "📹 Custom port on_destroy called";
    PJ_UNUSED_ARG(port);
    return PJ_SUCCESS;
}

// ========== 帧处理 (Push 模式核心 + 异步处理 v6) ==========

void RemoteVideoManager::onFrameReceived(pjmedia_frame *frame, const pjmedia_format *fmt)
{
    // ✅ v6: 在 PJSIP 线程中调用,必须快速返回!
    // 只做快速的内存拷贝,耗时的转换操作在工作线程中处理

    static int frameCount = 0;
    static qint64 lastLogTime = 0;
    static qint64 lastFrameTime = 0;
    static int framesInSecond = 0;
    static qint64 totalFrameInterval = 0;
    static int intervalSamples = 0;
    static qint64 totalCopyTime = 0;

    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();

    // ✅ 在第一帧到达时,检测实际格式并记录详细信息
    if (frameCount == 0 && fmt) {
        pjmedia_video_format_detail *vfd = pjmedia_format_get_video_format_detail(fmt, PJ_TRUE);
        if (vfd) {
            qDebug() << "🎬 [FIRST FRAME] Port format:" << vfd->size.w << "x" << vfd->size.h
                     << "@" << vfd->fps.num << "/" << vfd->fps.denum << "fps"
                     << "| Frame buffer size:" << frame->size << "bytes"
                     << "| Format ID:" << Qt::hex << fmt->id;

            // 检测格式不匹配
            size_t expected_size = vfd->size.w * vfd->size.h * 3 / 2;
            if (frame->size != expected_size) {
                qWarning() << "⚠️ [FORMAT MISMATCH] Expected buffer size:" << expected_size
                           << "but got:" << frame->size;
                m_formatMismatch = true;
            }
        }
    }

    // 统计帧间隔
    if (lastFrameTime > 0) {
        qint64 interval = currentTime - lastFrameTime;
        totalFrameInterval += interval;
        intervalSamples++;
    }
    lastFrameTime = currentTime;

    // ✅ v6: 快速拷贝帧数据并入队，避免阻塞 PJSIP 线程
    qint64 copyStart = QDateTime::currentMSecsSinceEpoch();

    if (frame && fmt && frame->buf && frame->size > 0) {
        pjmedia_video_format_detail *vfd = pjmedia_format_get_video_format_detail(fmt, PJ_TRUE);
        if (vfd && m_processorThread) {
            FrameBuffer frameBuffer;
            frameBuffer.data = QByteArray((const char*)frame->buf, frame->size);
            frameBuffer.format = *fmt;
            frameBuffer.width = vfd->size.w;
            frameBuffer.height = vfd->size.h;
            frameBuffer.timestamp = currentTime;

            // 智能尺寸检测（与之前一样）
            size_t expected_size = vfd->size.w * vfd->size.h * 3 / 2;
            pj_uint32_t pjfmt = fmt->id;
            const pj_uint32_t PJMEDIA_FORMAT_J420 = 0x3032344a;

            if ((pjfmt == PJMEDIA_FORMAT_I420 || pjfmt == PJMEDIA_FORMAT_IYUV || pjfmt == PJMEDIA_FORMAT_J420) &&
                frame->size != expected_size) {
                struct Resolution { int w; int h; size_t size; };
                static const Resolution common_resolutions[] = {
                    {320, 240, 320*240*3/2},      // QVGA
                    {640, 360, 640*360*3/2},      // nHD
                    {640, 480, 640*480*3/2},      // VGA
                    {720, 480, 720*480*3/2},      // NTSC
                    {1280, 720, 1280*720*3/2},    // 720p
                    {1920, 1080, 1920*1080*3/2},  // 1080p
                };

                for (const auto& res : common_resolutions) {
                    if (frame->size == res.size) {
                        frameBuffer.width = res.w;
                        frameBuffer.height = res.h;
                        break;
                    }
                }
            }

            // 入队到工作线程处理
            m_processorThread->enqueueFrame(frameBuffer);

            frameCount++;
            framesInSecond++;
        }
    }

    qint64 copyEnd = QDateTime::currentMSecsSinceEpoch();
    totalCopyTime += (copyEnd - copyStart);

    // 每秒统计一次性能
    if (lastLogTime == 0) {
        lastLogTime = currentTime;
    } else if (currentTime - lastLogTime >= 1000) {
        qint64 elapsedMs = currentTime - lastLogTime;
        double actualFps = (framesInSecond * 1000.0) / elapsedMs;
        double avgInterval = intervalSamples > 0 ? (double)totalFrameInterval / intervalSamples : 0;
        double avgCopyTime = framesInSecond > 0 ? (double)totalCopyTime / framesInSecond : 0;

        QString mismatchWarning = m_formatMismatch ? " ⚠️ FORMAT MISMATCH DETECTED" : "";
        qDebug() << "📊 [REMOTE VIDEO PUSH]"
                 << "Enqueued FPS:" << QString::number(actualFps, 'f', 1)
                 << "| Avg interval:" << QString::number(avgInterval, 'f', 1) << "ms"
                 << "| Avg copy time:" << QString::number(avgCopyTime, 'f', 2) << "ms"
                 << "| Total frames:" << frameCount
                 << mismatchWarning;

        // 重置计数器
        lastLogTime = currentTime;
        framesInSecond = 0;
        totalFrameInterval = 0;
        intervalSamples = 0;
        totalCopyTime = 0;
    }
}

void RemoteVideoManager::displayFrame(QVideoFrame frame)
{
    /* ✅ 2026-01-09 14:40 [调试 Fix 95] 追踪帧传递到 QVideoSink
     * 问题：视频帧到达 RemoteVideoManager，但屏幕无显示
     * 目的：验证帧是否传递到 QVideoSink
     * 预期：每帧日志输出，m_videoSink 不为空
     */
    static int displayCount = 0;
    displayCount++;

    // 每秒打印一次（假设 ~15fps）
    if (displayCount % 15 == 1) {
        qDebug() << "📹 [DISPLAY FRAME] Presenting to QVideoSink:"
                 << "frame" << displayCount
                 << "size:" << frame.width() << "x" << frame.height()
                 << "valid:" << frame.isValid()
                 << "m_videoSink:" << m_videoSink;
    }

    // 在 Qt 主线程中调用
    if (frame.isValid()) {
        if (m_videoSink) {
            m_videoSink->setVideoFrame(frame);
        } else {
            qWarning() << "❌ [ERROR Fix 95] m_videoSink is nullptr! Cannot display frame!";
        }
    } else {
        static int invalidCount = 0;
        if (invalidCount < 5) {
            qWarning() << "❌ [ERROR Fix 95] Invalid QVideoFrame received!";
            invalidCount++;
        }
    }
}

QVideoFrame RemoteVideoManager::convertPjFrameToQt(pjmedia_frame *frame, const pjmedia_format *fmt)
{
    if (!frame || !fmt || frame->type != PJMEDIA_FRAME_TYPE_VIDEO) {
        return QVideoFrame();
    }

    // 获取视频尺寸
    pjmedia_video_format_detail *vfd = pjmedia_format_get_video_format_detail(fmt, PJ_TRUE);
    if (!vfd) {
        return QVideoFrame();
    }

    int width = vfd->size.w;
    int height = vfd->size.h;

    // 检查格式
    pj_uint32_t pjfmt = fmt->id;

    // Define J420 format ID (JPEG YUV420 with full range)
    const pj_uint32_t PJMEDIA_FORMAT_J420 = 0x3032344a;

    // ✅ 智能尺寸检测：根据实际frame->size推断真实尺寸
    // 如果frame->size与声明的尺寸不匹配，尝试推断实际尺寸
    size_t expected_size_yuv420 = width * height * 3 / 2;

    if (pjfmt == PJMEDIA_FORMAT_I420 || pjfmt == PJMEDIA_FORMAT_IYUV || pjfmt == PJMEDIA_FORMAT_J420) {
        if (frame->size != expected_size_yuv420) {
            // 常见分辨率表（从小到大）
            struct Resolution { int w; int h; size_t size; };
            static const Resolution common_resolutions[] = {
                {320, 240, 320*240*3/2},      // QVGA
                {640, 360, 640*360*3/2},      // nHD
                {640, 480, 640*480*3/2},      // VGA
                {720, 480, 720*480*3/2},      // NTSC
                {1280, 720, 1280*720*3/2},    // 720p
                {1920, 1080, 1920*1080*3/2},  // 1080p
            };

            // 查找匹配的分辨率
            for (const auto& res : common_resolutions) {
                if (frame->size == res.size) {
                    static int detectCount = 0;
                    if (detectCount < 3) {
                        qDebug() << "🔍 [SMART DETECT] Frame size mismatch! Declared:"
                                 << width << "x" << height << "(" << expected_size_yuv420 << "bytes)"
                                 << "Actual:" << res.w << "x" << res.h << "(" << frame->size << "bytes)";
                        qDebug() << "✅ Using actual resolution:" << res.w << "x" << res.h;
                        detectCount++;
                    }
                    width = res.w;
                    height = res.h;
                    break;
                }
            }
        }
    }

    // ✅ 新方案：直接使用Qt的YUV格式支持，让Qt来处理颜色转换
    // 不再手动转换YUV到RGB，而是创建YUV格式的QVideoFrame

    if (pjfmt == PJMEDIA_FORMAT_I420 || pjfmt == PJMEDIA_FORMAT_IYUV || pjfmt == PJMEDIA_FORMAT_J420) {
        // I420/IYUV/J420 -> 使用Qt的YUV420P格式
        // Qt会自动处理颜色转换，无需手动计算

        // ✅ 安全检查：验证缓冲区大小
        size_t required_size = width * height * 3 / 2;  // YUV420 = 1.5 bytes per pixel
        if (frame->size < required_size) {
            static int errorCount = 0;
            if (errorCount < 5) {  // 只打印前5次错误
                qWarning() << "❌ RemoteVideoManager: Frame buffer too small:"
                           << frame->size << "< required" << required_size
                           << "for" << width << "x" << height;
                errorCount++;
            }
            return QVideoFrame();
        }

        QVideoFrameFormat format(QSize(width, height), QVideoFrameFormat::Format_YUV420P);
        QVideoFrame videoFrame(format);

        if (!videoFrame.map(QVideoFrame::WriteOnly)) {
            qWarning() << "❌ RemoteVideoManager: Failed to map YUV video frame";
            return QVideoFrame();
        }

        // YUV420P内存布局：Y平面 + U平面 + V平面
        const unsigned char *src_y = (const unsigned char *)frame->buf;
        const unsigned char *src_u = src_y + width * height;
        const unsigned char *src_v = src_u + (width * height / 4);

        // 复制Y平面
        unsigned char *dst_y = videoFrame.bits(0);
        memcpy(dst_y, src_y, width * height);

        // 复制U平面
        unsigned char *dst_u = videoFrame.bits(1);
        memcpy(dst_u, src_u, width * height / 4);

        // 复制V平面
        unsigned char *dst_v = videoFrame.bits(2);
        memcpy(dst_v, src_v, width * height / 4);

        videoFrame.unmap();

        static int logCount = 0;
        if (logCount == 0) {
            qDebug() << "✅ Using Qt native YUV420P format for"
                     << (pjfmt == PJMEDIA_FORMAT_J420 ? "J420" : "I420")
                     << "video:" << width << "x" << height;
            logCount++;
        }

        return videoFrame;
    }
    else if (pjfmt == PJMEDIA_FORMAT_RGB24) {
        // RGB24 -> 直接使用QImage然后转换

        // ✅ 安全检查：验证缓冲区大小
        size_t required_size = width * height * 3;  // RGB24 = 3 bytes per pixel
        if (frame->size < required_size) {
            qWarning() << "❌ RemoteVideoManager: RGB24 buffer too small:" << frame->size;
            return QVideoFrame();
        }

        QImage image((const uchar *)frame->buf, width, height, width * 3, QImage::Format_RGB888);

        QVideoFrameFormat format(image.size(), QVideoFrameFormat::Format_ARGB8888);
        QVideoFrame videoFrame(format);

        if (!videoFrame.map(QVideoFrame::WriteOnly)) {
            qWarning() << "❌ RemoteVideoManager: Failed to map video frame";
            return QVideoFrame();
        }

        QImage rgbImage = image.convertToFormat(QImage::Format_ARGB32);
        memcpy(videoFrame.bits(0), rgbImage.bits(), rgbImage.sizeInBytes());
        videoFrame.unmap();

        return videoFrame;
    }
    else if (pjfmt == PJMEDIA_FORMAT_RGBA) {
        // RGBA -> 直接使用QImage然后转换

        // ✅ 安全检查：验证缓冲区大小
        size_t required_size = width * height * 4;  // RGBA = 4 bytes per pixel
        if (frame->size < required_size) {
            qWarning() << "❌ RemoteVideoManager: RGBA buffer too small:" << frame->size;
            return QVideoFrame();
        }

        QImage image((const uchar *)frame->buf, width, height, width * 4, QImage::Format_RGBA8888);

        QVideoFrameFormat format(image.size(), QVideoFrameFormat::Format_ARGB8888);
        QVideoFrame videoFrame(format);

        if (!videoFrame.map(QVideoFrame::WriteOnly)) {
            qWarning() << "❌ RemoteVideoManager: Failed to map video frame";
            return QVideoFrame();
        }

        QImage rgbImage = image.convertToFormat(QImage::Format_ARGB32);
        memcpy(videoFrame.bits(0), rgbImage.bits(), rgbImage.sizeInBytes());
        videoFrame.unmap();

        return videoFrame;
    }
    else {
        qWarning() << "❌ RemoteVideoManager: Unsupported format:" << Qt::hex << pjfmt;
        return QVideoFrame();
    }
}

// ========== Attempt 22: 隐藏SDL窗口 ==========

void RemoteVideoManager::hideAllPjsipVideoWindows()
{
    // 遍历所有PJSIP视频窗口并隐藏它们
    // PJSIP为每个视频流自动创建SDL窗口，我们使用Qt界面，不需要这些窗口

    qDebug() << "🔧 [Attempt 22] Hiding all PJSIP SDL video windows...";

    int hiddenCount = 0;
    for (int wid = 0; wid < PJSUA_MAX_VID_WINS; ++wid) {
        pjsua_vid_win_info wi;
        pj_status_t status = pjsua_vid_win_get_info(wid, &wi);

        if (status == PJ_SUCCESS && wi.show) {
            // 找到一个正在显示的窗口，隐藏它
            pjsua_vid_win_set_show(wid, PJ_FALSE);
            hiddenCount++;
            qDebug() << "  ✅ Hidden SDL window ID:" << wid
                     << "type:" << (wi.is_native ? "native" : "SDL");
        }
    }

    if (hiddenCount > 0) {
        qDebug() << "✅ [Attempt 22] Hidden" << hiddenCount << "SDL video window(s)";
    } else {
        qDebug() << "ℹ️ [Attempt 22] No SDL windows found to hide";
    }
}

// ========== 硬件解码真实验证 ==========

void RemoteVideoManager::verifyHardwareDecoder()
{
    qDebug() << "🔍 [HARDWARE DECODER VERIFICATION - REAL CHECK]";
    qDebug() << "==========================================";

#ifndef WIN32
    // 方法1: 检查硬件设备文件是否被打开
    qDebug() << "📂 Method 1: Checking hardware device usage...";

    QProcess lsofProc;
    lsofProc.start("lsof", QStringList() << "-p" << QString::number(QCoreApplication::applicationPid()));
    lsofProc.waitForFinished(2000);
    QString lsofOutput = QString::fromUtf8(lsofProc.readAllStandardOutput());

    bool foundV4L2Device = lsofOutput.contains("/dev/video");
    bool foundMPPDevice = lsofOutput.contains("/dev/mpp_service") || lsofOutput.contains("/dev/rkvdec");

    if (foundV4L2Device) {
        qDebug() << "   ✅ FOUND: V4L2 device (/dev/video*) is OPEN";
        qDebug() << "   → h264_v4l2m2m hardware decoder is ACTIVE";
    }

    if (foundMPPDevice) {
        qDebug() << "   ✅ FOUND: Rockchip MPP device is OPEN";
        qDebug() << "   → h264_rkmpp hardware decoder is ACTIVE";
    }

    if (!foundV4L2Device && !foundMPPDevice) {
        qDebug() << "   ⚠️ WARNING: No hardware decoder device detected";
        qDebug() << "   → Likely using SOFTWARE decoding (libx264)";
        qDebug() << "   → This will cause HIGH CPU usage";
    }

    // 方法2: 读取当前进程CPU使用率
    qDebug() << "";
    qDebug() << "⚙️ Method 2: Checking CPU usage (baseline)...";

    QFile statFile(QString("/proc/%1/stat").arg(QCoreApplication::applicationPid()));
    if (statFile.open(QIODevice::ReadOnly)) {
        QStringList stats = QString::fromUtf8(statFile.readAll()).split(' ');
        if (stats.size() > 14) {
            qint64 utime = stats[13].toLongLong();  // User mode time
            qint64 stime = stats[14].toLongLong();  // Kernel mode time
            qint64 total_time = utime + stime;

            qDebug() << "   ℹ️ Process CPU time (jiffies):" << total_time;
            qDebug() << "   ℹ️ Recommendation: Monitor CPU% during video call";
            qDebug() << "      - Hardware decoding: <20% CPU";
            qDebug() << "      - Software decoding: >60% CPU";
        }
        statFile.close();
    }

    // 方法3: 提示如何启用FFmpeg调试日志
    qDebug() << "";
    qDebug() << "📋 Method 3: Enable FFmpeg debug logs to see actual decoder";
    qDebug() << "   Run with environment variable:";
    qDebug() << "   export AV_LOG_FORCE_NOCOLOR=1";
    qDebug() << "   export AV_LOG_LEVEL=info";
    qDebug() << "   Then check logs for lines like:";
    qDebug() << "   → '[h264 @ 0x...] decoder: h264_v4l2m2m' (HARDWARE)";
    qDebug() << "   → '[h264 @ 0x...] decoder: h264' (SOFTWARE)";

#else
    // Windows - 无法直接检测硬件解码器
    qDebug() << "   ℹ️ Platform: Windows (hardware decoder detection not available)";
    qDebug() << "   ℹ️ Monitor CPU usage to verify:";
    qDebug() << "      - Low CPU (<20%): Likely hardware decoding";
    qDebug() << "      - High CPU (>60%): Likely software decoding";
#endif

    qDebug() << "==========================================";
}

// Push 模式实现完成 ✅
// 所有旧的 Pull 模式代码已替换
