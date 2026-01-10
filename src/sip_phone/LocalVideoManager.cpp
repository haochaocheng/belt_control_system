#include "LocalVideoManager.h"
#include <QDebug>
#include <QImage>
#include <QDateTime>
#include <pjsua-lib/pjsua.h>
#include <pjsua-lib/pjsua_internal.h>

/**
 * @brief 本地视频管理器实现 - 从 PJSIP 预览获取帧
 *
 * 使用 PJSIP 的视频预览功能，避免 Qt Multimedia QCamera 独立控制摄像头
 * 这样 PJSIP 可以同时用摄像头做预览和发送给对方
 */
LocalVideoManager::LocalVideoManager(QObject *parent)
    : QObject(parent)
    , m_videoSink(new QVideoSink(this))
    , m_hasLocalVideo(false)
    , m_previewWinId(PJSUA_INVALID_ID)
    , m_previewPort(nullptr)
    , m_captureTimer(new QTimer(this))
    , m_captureDevId(PJMEDIA_VID_DEFAULT_CAPTURE_DEV)
{
    qDebug() << "✅ LocalVideoManager created (PJSIP preview mode)";

    // 捕获定时器 - 60fps (17ms) for smooth preview
    m_captureTimer->setInterval(17);  // 60fps to match high frame rate video
    connect(m_captureTimer, &QTimer::timeout, this, &LocalVideoManager::capturePreviewFrame);
}

LocalVideoManager::~LocalVideoManager()
{
    qDebug() << "LocalVideoManager: Shutting down...";
    stopPreview();
}

QObject* LocalVideoManager::videoSink() const
{
    return m_videoSink;
}

void LocalVideoManager::startPreview()
{
    // ✅ 2026-01-01 23:20 [修复 26] 优先使用 PJSIP 自动创建的 preview，避免摄像头资源冲突
    // 背景：PJSIP 在视频通话时自动创建 preview window 并连接摄像头到编码器
    // 策略：
    // 1. 首先检查 PJSIP 是否已为通话创建了 preview window
    // 2. 如果有 → 直接复用（避免资源冲突）
    // 3. 如果没有 → 独立启动 preview（Windows 多路访问场景）
    //
    // 关键差异：
    // - 通话中：PJSIP preview 同时连接 camera → encoder (RTP发送) ✅
    // - 非通话：独立 preview 只连接 camera → SDL display (仅本地显示) ⚠️

    // ✅ Step 1: 检测首选的摄像头设备
    m_captureDevId = PJMEDIA_VID_DEFAULT_CAPTURE_DEV;  // Default: -1 (auto)

    unsigned vidDevCount = pjsua_vid_dev_count();
    for (unsigned i = 0; i < vidDevCount; ++i) {
        pjmedia_vid_dev_info devInfo;
        if (pjsua_vid_dev_get_info(i, &devInfo) == PJ_SUCCESS) {
            // Find first real capture device (skip colorbar/null/HDMI input)
            if (devInfo.dir & PJMEDIA_DIR_CAPTURE) {
                QString deviceName = QString::fromUtf8(devInfo.name);
                // Skip non-camera devices
                if (!deviceName.contains("colorbar", Qt::CaseInsensitive) &&
                    !deviceName.contains("null", Qt::CaseInsensitive) &&
                    !deviceName.contains("hdmirx", Qt::CaseInsensitive) &&
                    !deviceName.contains("rk_hdmirx", Qt::CaseInsensitive)) {
                    m_captureDevId = i;
                    qDebug() << "✅ LocalVideoManager: Auto-selected capture device" << i << ":" << devInfo.name;
                    break;
                }
            }
        }
    }

    if (m_captureDevId == PJMEDIA_VID_DEFAULT_CAPTURE_DEV) {
        qWarning() << "⚠️ LocalVideoManager: No suitable camera found, using default (-1)";
        // 继续尝试，可能系统会自动选择合适的设备
        m_captureDevId = 0;  // 尝试设备 0
    }

    // ✅ Step 2: 检查 PJSIP 是否已为该设备创建了 preview window
    pjsua_vid_win_id existingWinId = pjsua_vid_preview_get_win(m_captureDevId);

    if (existingWinId != PJSUA_INVALID_ID) {
        // ✅ PJSIP 已创建 preview（通话场景）→ 直接复用
        qDebug() << "✅ LocalVideoManager: Found existing PJSIP preview window" << existingWinId
                 << "for device" << m_captureDevId << "→ reusing it";
        m_previewWinId = existingWinId;

        // 直接附加到现有 preview 端口
        if (attachPreviewPort()) {
            m_hasLocalVideo = true;
            emit hasLocalVideoChanged();
            m_captureTimer->start();
            qDebug() << "✅ LocalVideoManager: Attached to PJSIP preview (通话模式，摄像头已连接到编码器)";
        } else {
            qWarning() << "❌ LocalVideoManager: Failed to attach to existing preview port";
        }
        return;
    }

    // ✅ Step 3: PJSIP 没有 preview → 检查是否有活跃通话
    qDebug() << "⚠️ LocalVideoManager: No PJSIP preview found for device" << m_captureDevId;

#ifdef __linux__
    // ✅ 2026-01-07 [修复 69.2] Linux V4L2 不支持多路访问
    // 问题：通话时摄像头已被占用，创建独立preview会导致 "Device or resource busy"
    // 方案：检查活跃通话，复用通话的capture port，避免重复打开摄像头
    // 详细：docs/2026-01-06/27-Fix69-复用capture-port解决V4L2冲突.md

    pjsua_conf_port_id cap_slot = findActiveCallCaptureSlot(m_captureDevId);
    if (cap_slot != PJSUA_INVALID_ID) {
        qDebug() << "✅ [FIX 69.2] Active call found, reusing enc_slot:" << cap_slot;
        qDebug() << "   Strategy: Create renderer connected to existing capture port";

        // ✅ 2026-01-07 [修复 69.2 完整实施] 创建渲染器并连接到已打开的摄像头端口
        // 原理：PJSIP 视频会议桥（vid_tee）可以将一个capture port的数据分发到多个目标
        // 架构：Camera → Capture Port → Vid Tee → Encoder (RTP) + Renderer (预览)
        // 详细：docs/2026-01-06/27-Fix69-复用capture-port解决V4L2冲突.md

        // Step 1: 获取通话的视频会议桥信息
        pjsua_vid_win_info cap_win_info;
        pj_status_t status;

        // 尝试从 enc_slot 获取窗口信息
        // 注意：enc_slot 是视频会议桥的端口ID，不是 window ID
        // 我们需要在视频会议桥上创建新的渲染器端口

        // Step 2: 创建渲染器端口
        // ✅ 2026-01-07 23:20 修复编译错误：使用正确的 pjmedia_vid_port_param 类型
        pjmedia_vid_port_param vp_param;
        pjmedia_vid_port_param_default(&vp_param);

        // 配置设备参数
        vp_param.vidparam.dir = PJMEDIA_DIR_RENDER;
        vp_param.vidparam.rend_id = PJMEDIA_VID_DEFAULT_RENDER_DEV;  // SDL renderer
        vp_param.vidparam.fmt.type = PJMEDIA_TYPE_VIDEO;
        // 使用与通话相同的分辨率和帧率（640x360 @ 25fps）
        // ❌ 2026-01-11 01:45 [修复 100.29] 修改为 640x368（16像素对齐）
        // ✅ 2026-01-11 04:00 [修复 100.33] 修改为 640x480 @ 30fps（摄像头硬件支持）
        pjmedia_format_init_video(&vp_param.vidparam.fmt, PJMEDIA_FORMAT_I420, 640, 480, 30, 1);
        vp_param.vidparam.disp_size.w = 640;
        vp_param.vidparam.disp_size.h = 480;
        vp_param.vidparam.flags = PJMEDIA_VID_DEV_CAP_OUTPUT_HIDE;  // 隐藏SDL窗口
        vp_param.vidparam.window_hide = PJ_TRUE;

        // 设置为被动模式（从会议桥接收数据）
        vp_param.active = PJ_FALSE;

        // 创建内存池
        m_reusedPool = pjsua_pool_create("local_preview_rend", 2000, 2000);
        if (!m_reusedPool) {
            qWarning() << "❌ [FIX 69.2] Failed to create memory pool";
            goto fallback;
        }

        // 创建渲染器 vid_port
        status = pjmedia_vid_port_create(m_reusedPool, &vp_param, &m_reusedRendPort);
        if (status != PJ_SUCCESS) {
            qWarning() << "❌ [FIX 69.2] Failed to create renderer port, status:" << status;
            if (m_reusedPool) {
                pj_pool_release(m_reusedPool);
                m_reusedPool = nullptr;
            }
            goto fallback;
        }

        // Step 3: 添加渲染器到视频会议桥
        status = pjsua_vid_conf_add_port(m_reusedPool,
                                         pjmedia_vid_port_get_passive_port(m_reusedRendPort),
                                         NULL, &m_reusedRendSlot);
        if (status != PJ_SUCCESS) {
            qWarning() << "❌ [FIX 69.2] Failed to add renderer to vid conf, status:" << status;
            pjmedia_vid_port_destroy(m_reusedRendPort);
            pj_pool_release(m_reusedPool);
            m_reusedRendPort = nullptr;
            m_reusedPool = nullptr;
            goto fallback;
        }

        qDebug() << "✅ [FIX 69.2] Renderer added to vid conf, slot:" << m_reusedRendSlot;

        // Step 4: 连接 capture → renderer（关键！复用已打开的摄像头）
        m_reusedCapSlot = cap_slot;
        status = pjsua_vid_conf_connect(m_reusedCapSlot, m_reusedRendSlot, NULL);
        if (status != PJ_SUCCESS) {
            qWarning() << "❌ [FIX 69.2] Failed to connect cap→rend, status:" << status;
            pjsua_vid_conf_remove_port(m_reusedRendSlot);
            pjmedia_vid_port_destroy(m_reusedRendPort);
            pj_pool_release(m_reusedPool);
            m_reusedCapSlot = PJSUA_INVALID_ID;
            m_reusedRendSlot = PJSUA_INVALID_ID;
            m_reusedRendPort = nullptr;
            m_reusedPool = nullptr;
            goto fallback;
        }

        qDebug() << "✅ [FIX 69.2] Connected cap_slot:" << m_reusedCapSlot << "→ rend_slot:" << m_reusedRendSlot;

        // Step 5: 启动渲染器
        status = pjmedia_vid_port_start(m_reusedRendPort);
        if (status != PJ_SUCCESS) {
            qWarning() << "❌ [FIX 69.2] Failed to start renderer, status:" << status;
            pjsua_vid_conf_disconnect(m_reusedCapSlot, m_reusedRendSlot);
            pjsua_vid_conf_remove_port(m_reusedRendSlot);
            pjmedia_vid_port_destroy(m_reusedRendPort);
            pj_pool_release(m_reusedPool);
            m_reusedCapSlot = PJSUA_INVALID_ID;
            m_reusedRendSlot = PJSUA_INVALID_ID;
            m_reusedRendPort = nullptr;
            m_reusedPool = nullptr;
            goto fallback;
        }

        qDebug() << "✅ [FIX 69.2] Renderer started successfully";

        // Step 6: 附加到渲染器端口以获取帧数据
        // 设置 m_previewPort 指向渲染器的被动端口
        m_previewPort = pjmedia_vid_port_get_passive_port(m_reusedRendPort);
        if (!m_previewPort) {
            qWarning() << "❌ [FIX 69.2] Failed to get passive port from renderer";
            pjmedia_vid_port_stop(m_reusedRendPort);
            pjsua_vid_conf_disconnect(m_reusedCapSlot, m_reusedRendSlot);
            pjsua_vid_conf_remove_port(m_reusedRendSlot);
            pjmedia_vid_port_destroy(m_reusedRendPort);
            pj_pool_release(m_reusedPool);
            m_reusedCapSlot = PJSUA_INVALID_ID;
            m_reusedRendSlot = PJSUA_INVALID_ID;
            m_reusedRendPort = nullptr;
            m_reusedPool = nullptr;
            m_previewPort = nullptr;
            goto fallback;
        }

        // ✅ 成功！开始捕获帧
        m_hasLocalVideo = true;
        emit hasLocalVideoChanged();
        m_captureTimer->start();

        qDebug() << "🎉 [FIX 69.2] Local video preview activated via reused capture port!";
        qDebug() << "   Architecture: Camera → Capture Port → Vid Tee → [Encoder (RTP) + Renderer (本地预览)]";
        qDebug() << "   No duplicate camera access, Linux V4L2 compatible ✅";
        return;  // 成功，直接返回

fallback:
        qWarning() << "❌ [FIX 69.2] Failed to create renderer using reused cap_slot";
        qWarning() << "   Falling back to independent preview (may fail on Linux)";
    } else {
        qDebug() << "   No active call found, will create independent preview";
    }
#endif

    // ⚠️ 原有逻辑：创建独立预览（Windows 或无通话时）
    // 注意：Linux 通话时会失败（V4L2 资源冲突）
    qDebug() << "→ creating independent preview";
    qDebug() << "   Note: Windows多路访问正常，Linux V4L2可能导致通话时摄像头冲突";

    // 启动独立的 PJSIP 视频预览
    pjsua_vid_preview_param param;
    pjsua_vid_preview_param_default(&param);

    // ✅ 配置摄像头：640x360 @ 25fps，匹配通话分辨率
    // ❌ 2026-01-11 01:45 [修复 100.29] 修改为 640x368（16像素对齐）
    // ✅ 2026-01-11 04:00 [修复 100.33] 修改为 640x480 @ 30fps（摄像头硬件支持）
    pjmedia_format_init_video(&param.format, PJMEDIA_FORMAT_YUY2, 640, 480, 30, 1);
    param.show = PJ_FALSE;  // 隐藏SDL窗口

    qDebug() << "📹 Creating independent preview: 640x480 @ 30fps (YUY2), SDL window hidden";

    pj_status_t status = pjsua_vid_preview_start(m_captureDevId, &param);
    if (status != PJ_SUCCESS) {
        qWarning() << "❌ LocalVideoManager: Failed to start independent preview, status:" << status;
        qWarning() << "   This may be expected if already in a video call (camera busy)";
        emit errorOccurred("Failed to start video preview");
        return;
    }

    qDebug() << "✅ LocalVideoManager: Independent preview started successfully";

    // 获取独立 preview 的窗口ID
    m_previewWinId = pjsua_vid_preview_get_win(m_captureDevId);
    if (m_previewWinId == PJSUA_INVALID_ID) {
        qWarning() << "❌ LocalVideoManager: Failed to get independent preview window ID";
        return;
    }

    // 附加到独立 preview 端口
    if (attachPreviewPort()) {
        m_hasLocalVideo = true;
        emit hasLocalVideoChanged();
        m_captureTimer->start();
        qDebug() << "✅ LocalVideoManager: Frame capture started (独立预览模式，仅本地显示)";
    } else {
        qWarning() << "❌ LocalVideoManager: Failed to attach to independent preview port";
    }
}

void LocalVideoManager::stopPreview()
{
    // qDebug() << "📹 LocalVideoManager: Stopping PJSIP video preview";

    // ✅ 2026-01-07 [修复 69.3] 清理复用的渲染器资源
#ifdef __linux__
    if (m_reusedRendPort) {
        qDebug() << "🔧 [FIX 69.3] Cleaning up reused renderer (cap_slot:" << m_reusedCapSlot
                 << "→ rend_slot:" << m_reusedRendSlot << ")";

        // Step 1: 停止帧捕获
        m_captureTimer->stop();

        // Step 2: 分离预览端口
        detachPreviewPort();

        // Step 3: 停止渲染器
        pjmedia_vid_port_stop(m_reusedRendPort);
        qDebug() << "   [FIX 69.3] Step 1: Renderer stopped";

        // Step 4: 断开视频会议桥连接
        if (m_reusedCapSlot != PJSUA_INVALID_ID && m_reusedRendSlot != PJSUA_INVALID_ID) {
            pjsua_vid_conf_disconnect(m_reusedCapSlot, m_reusedRendSlot);
            qDebug() << "   [FIX 69.3] Step 2: Disconnected cap_slot → rend_slot";
        }

        // Step 5: 从视频会议桥移除渲染器端口
        if (m_reusedRendSlot != PJSUA_INVALID_ID) {
            pjsua_vid_conf_remove_port(m_reusedRendSlot);
            qDebug() << "   [FIX 69.3] Step 3: Removed rend_slot from vid conf";
        }

        // Step 6: 销毁渲染器 vid_port
        pjmedia_vid_port_destroy(m_reusedRendPort);
        qDebug() << "   [FIX 69.3] Step 4: Destroyed renderer vid_port";

        // Step 7: 释放内存池
        if (m_reusedPool) {
            pj_pool_release(m_reusedPool);
            qDebug() << "   [FIX 69.3] Step 5: Released memory pool";
        }

        // Step 8: 清除所有引用
        m_reusedCapSlot = PJSUA_INVALID_ID;
        m_reusedRendSlot = PJSUA_INVALID_ID;
        m_reusedRendPort = nullptr;
        m_reusedPool = nullptr;

        if (m_hasLocalVideo) {
            m_hasLocalVideo = false;
            emit hasLocalVideoChanged();
        }

        qDebug() << "✅ [FIX 69.3] Reused renderer fully cleaned up";
        qDebug() << "   Note: Capture port remains active (used by call)";
        return;
    }
#endif

    // 停止帧捕获
    m_captureTimer->stop();

    // 分离预览端口
    detachPreviewPort();

    // 停止 PJSIP 预览 (使用检测到的摄像头设备ID)
    if (m_previewWinId != PJSUA_INVALID_ID) {
        pjsua_vid_preview_stop(m_captureDevId);
        m_previewWinId = PJSUA_INVALID_ID;
    }

    if (m_hasLocalVideo) {
        m_hasLocalVideo = false;
        emit hasLocalVideoChanged();
    }

    qDebug() << "✅ LocalVideoManager: Preview stopped";
}

bool LocalVideoManager::attachPreviewPort()
{
    if (m_previewWinId == PJSUA_INVALID_ID) {
        return false;
    }

    // 获取预览窗口信息
    pjsua_vid_win_info wi;
    pj_status_t status = pjsua_vid_win_get_info(m_previewWinId, &wi);
    if (status != PJ_SUCCESS) {
        qWarning() << "❌ LocalVideoManager: Failed to get preview window info, status:" << status;
        return false;
    }

    // qDebug() << "📺 LocalVideoManager: Preview window info:"
    //          << "show=" << wi.show
    //          << "is_native=" << wi.is_native
    //          << "hwnd.type=" << wi.hwnd.type;

    // 尝试方法1: 通过 pjmedia_vid_port 获取端口
    // 预览窗口的 pjmedia_vid_port 包含了从摄像头捕获的帧
    if (m_previewWinId >= 0 && m_previewWinId < PJSUA_MAX_VID_WINS) {
        pjsua_vid_win *win = &pjsua_var.win[m_previewWinId];

        // 检查是否是预览窗口（有捕获设备）
        if (win->preview_cap_id != PJSUA_INVALID_ID && win->vp_cap) {
            // 从捕获设备的 vid_port 获取被动端口
            m_previewPort = pjmedia_vid_port_get_passive_port(win->vp_cap);
            if (m_previewPort) {
                // qDebug() << "📺 LocalVideoManager: Attached to preview port via vp_cap" << m_previewPort;
                return true;
            }
        }

        // 方法2: 尝试从渲染端口获取
        if (win->vp_rend) {
            m_previewPort = pjmedia_vid_port_get_passive_port(win->vp_rend);
            if (m_previewPort) {
                // qDebug() << "📺 LocalVideoManager: Attached to preview port via vp_rend" << m_previewPort;
                return true;
            }
        }
    }

    qWarning() << "❌ LocalVideoManager: Could not attach to preview port";
    return false;
}

void LocalVideoManager::detachPreviewPort()
{
    if (m_previewPort) {
        // qDebug() << "🔌 LocalVideoManager: Detaching preview port";
        m_previewPort = nullptr;
    }
}

void LocalVideoManager::capturePreviewFrame()
{
    // ✅ 性能统计（类似 RemoteVideoManager）
    static int frameCount = 0;
    static qint64 lastLogTime = 0;
    static qint64 lastFrameTime = 0;
    static int framesInSecond = 0;
    static qint64 totalFrameInterval = 0;
    static int intervalSamples = 0;
    static int errorCount = 0;

    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();

    if (!m_previewPort) {
        if (errorCount < 5) {
            qDebug() << "⚠️ capturePreviewFrame: No preview port";
            errorCount++;
        }
        return;
    }

    // 准备帧缓冲区
    pjmedia_frame frame;
    pj_bzero(&frame, sizeof(frame));

    // 分配足够大的缓冲区 (假设最大 1920x1080 RGBA)
    static unsigned char buffer[1920 * 1080 * 4];
    frame.buf = buffer;
    frame.size = sizeof(buffer);
    frame.type = PJMEDIA_FRAME_TYPE_NONE;

    // 从端口获取帧
    pj_status_t status = pjmedia_port_get_frame(m_previewPort, &frame);

    if (status != PJ_SUCCESS) {
        if (errorCount < 5) {
            qDebug() << "❌ pjmedia_port_get_frame failed, status:" << status;
            errorCount++;
        }
        return;
    }

    if (frame.type != PJMEDIA_FRAME_TYPE_VIDEO) {
        if (errorCount < 5) {
            qDebug() << "⚠️ Frame type is not video, type:" << frame.type;
            errorCount++;
        }
        return;
    }

    // 获取视频格式
    const pjmedia_format *fmt = &m_previewPort->info.fmt;

    // 转换为 QVideoFrame
    QVideoFrame videoFrame = convertPjFrameToQt(&frame, fmt);

    if (videoFrame.isValid()) {
        frameCount++;
        framesInSecond++;

        // 发送到 QVideoSink
        m_videoSink->setVideoFrame(videoFrame);

        // ✅ 统计帧间隔
        if (lastFrameTime > 0) {
            qint64 interval = currentTime - lastFrameTime;
            totalFrameInterval += interval;
            intervalSamples++;
        }
        lastFrameTime = currentTime;

        // ✅ 首帧日志
        if (frameCount == 1) {
            pjmedia_video_format_detail *vfd = pjmedia_format_get_video_format_detail(fmt, PJ_TRUE);
            if (vfd) {
                qDebug() << "🎬 [FIRST LOCAL FRAME] Sending format:" << vfd->size.w << "x" << vfd->size.h
                         << "@" << vfd->fps.num << "/" << vfd->fps.denum << "fps"
                         << "| Format:" << videoFrame.pixelFormat();
            }
        }

        // ✅ 每秒统计一次性能
        if (lastLogTime == 0) {
            lastLogTime = currentTime;
        } else if (currentTime - lastLogTime >= 1000) {
            qint64 elapsedMs = currentTime - lastLogTime;
            double actualFps = (framesInSecond * 1000.0) / elapsedMs;
            double avgInterval = intervalSamples > 0 ? (double)totalFrameInterval / intervalSamples : 0;

            qDebug() << "📤 [LOCAL VIDEO SEND]"
                     << "Sending FPS:" << QString::number(actualFps, 'f', 1)
                     << "| Avg interval:" << QString::number(avgInterval, 'f', 1) << "ms"
                     << "| Total frames:" << frameCount
                     << "| Size:" << videoFrame.size()
                     << "| Format:" << videoFrame.pixelFormat();

            // 重置计数器
            lastLogTime = currentTime;
            framesInSecond = 0;
            totalFrameInterval = 0;
            intervalSamples = 0;
        }

        // 重置错误计数
        errorCount = 0;
    } else {
        if (errorCount < 5) {
            qDebug() << "❌ convertPjFrameToQt returned invalid frame";
            errorCount++;
        }
    }
}

QVideoFrame LocalVideoManager::convertPjFrameToQt(pjmedia_frame *frame, const pjmedia_format *fmt)
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

    // ✅ 使用Qt的YUV格式支持，让Qt来处理颜色转换（与 RemoteVideoManager 相同的方法）

    // YUY2/YUYV format (packed YUV 4:2:2) - 常用于摄像头输出
    if (pjfmt == PJMEDIA_FORMAT_YUY2) {
        // YUY2 -> 使用Qt的YUYV格式
        QVideoFrameFormat format(QSize(width, height), QVideoFrameFormat::Format_YUYV);
        QVideoFrame videoFrame(format);

        if (!videoFrame.map(QVideoFrame::WriteOnly)) {
            qWarning() << "❌ LocalVideoManager: Failed to map YUY2 video frame";
            return QVideoFrame();
        }

        // YUY2 是打包格式，直接复制整个缓冲区
        size_t bufferSize = width * height * 2;  // YUY2 每像素2字节
        memcpy(videoFrame.bits(0), frame->buf, bufferSize);

        videoFrame.unmap();

        static int logCount = 0;
        if (logCount == 0) {
            qDebug() << "✅ LocalVideoManager: Using Qt native YUYV format for YUY2 video:" << width << "x" << height;
            logCount++;
        }

        return videoFrame;
    }
    else if (pjfmt == PJMEDIA_FORMAT_I420 || pjfmt == PJMEDIA_FORMAT_IYUV || pjfmt == PJMEDIA_FORMAT_J420) {
        // I420/IYUV/J420 -> 使用Qt的YUV420P格式
        QVideoFrameFormat format(QSize(width, height), QVideoFrameFormat::Format_YUV420P);
        QVideoFrame videoFrame(format);

        if (!videoFrame.map(QVideoFrame::WriteOnly)) {
            qWarning() << "❌ LocalVideoManager: Failed to map YUV video frame";
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
            qDebug() << "✅ LocalVideoManager: Using Qt native YUV420P format for"
                     << (pjfmt == PJMEDIA_FORMAT_J420 ? "J420" : "I420")
                     << "video:" << width << "x" << height;
            logCount++;
        }

        return videoFrame;
    }
    else if (pjfmt == PJMEDIA_FORMAT_RGB24) {
        // RGB24 -> 直接使用QImage然后转换
        QImage image((const uchar *)frame->buf, width, height, width * 3, QImage::Format_RGB888);

        QVideoFrameFormat format(image.size(), QVideoFrameFormat::Format_ARGB8888);
        QVideoFrame videoFrame(format);

        if (!videoFrame.map(QVideoFrame::WriteOnly)) {
            qWarning() << "❌ LocalVideoManager: Failed to map video frame";
            return QVideoFrame();
        }

        QImage rgbImage = image.convertToFormat(QImage::Format_ARGB32);
        memcpy(videoFrame.bits(0), rgbImage.bits(), rgbImage.sizeInBytes());
        videoFrame.unmap();

        return videoFrame;
    }
    else if (pjfmt == PJMEDIA_FORMAT_RGBA) {
        // RGBA -> 直接使用QImage然后转换
        QImage image((const uchar *)frame->buf, width, height, width * 4, QImage::Format_RGBA8888);

        QVideoFrameFormat format(image.size(), QVideoFrameFormat::Format_ARGB8888);
        QVideoFrame videoFrame(format);

        if (!videoFrame.map(QVideoFrame::WriteOnly)) {
            qWarning() << "❌ LocalVideoManager: Failed to map video frame";
            return QVideoFrame();
        }

        QImage rgbImage = image.convertToFormat(QImage::Format_ARGB32);
        memcpy(videoFrame.bits(0), rgbImage.bits(), rgbImage.sizeInBytes());
        videoFrame.unmap();

        return videoFrame;
    }
    else {
        qWarning() << "❌ LocalVideoManager: Unsupported format:" << Qt::hex << pjfmt;
        return QVideoFrame();
    }
}

// ✅ 2026-01-07 [修复 69.1] 查找活跃通话的摄像头端口
// 原理：复用通话已打开的capture port，避免V4L2重复打开冲突
// 详细：docs/2026-01-06/27-Fix69-复用capture-port解决V4L2冲突.md
pjsua_conf_port_id LocalVideoManager::findActiveCallCaptureSlot(int capDevId)
{
    pjsua_call_id call_ids[PJSUA_MAX_CALLS];
    unsigned call_count = PJSUA_MAX_CALLS;

    // 获取所有活跃通话
    pj_status_t status = pjsua_enum_calls(call_ids, &call_count);
    if (status != PJ_SUCCESS || call_count == 0) {
        qDebug() << "   [FIX 69.1] No calls found, status:" << status << ", count:" << call_count;
        return PJSUA_INVALID_ID;  // 无活跃通话
    }

    qDebug() << "   [FIX 69.1] Found" << call_count << "calls, searching for video...";

    // 遍历通话，查找使用指定摄像头的enc_slot (编码端口，连接摄像头)
    for (unsigned i = 0; i < call_count; ++i) {
        pjsua_call_info ci;
        status = pjsua_call_get_info(call_ids[i], &ci);
        if (status != PJ_SUCCESS) {
            qDebug() << "   [FIX 69.1] Failed to get call info for call" << call_ids[i];
            continue;
        }

        qDebug() << "   [FIX 69.1] Call" << call_ids[i] << "has" << ci.media_cnt << "media streams";

        // 检查通话是否有视频媒体
        for (unsigned med_idx = 0; med_idx < ci.media_cnt; ++med_idx) {
            const pjsua_call_media_info &mi = ci.media[med_idx];

            // 只关心视频媒体
            if (mi.type != PJMEDIA_TYPE_VIDEO) {
                continue;
            }

            qDebug() << "   [FIX 69.1] Found video media, status:" << mi.status
                     << ", cap_dev:" << mi.stream.vid.cap_dev
                     << ", enc_slot:" << mi.stream.vid.enc_slot;

            // ✅ 2026-01-07 [修复 69.5] 放宽检测条件：
            // 问题：通话刚建立时，status 可能不是 ACTIVE，cap_dev 可能还未设置
            // 方案：只要有视频媒体且 enc_slot 有效，就复用
            // 旧代码：if (mi.status == PJSUA_CALL_MEDIA_ACTIVE && mi.stream.vid.cap_dev == capDevId)
            if (mi.stream.vid.enc_slot != PJSUA_INVALID_ID) {
                // 返回编码器的 enc_slot（连接到摄像头的端口）
                pjsua_conf_port_id enc_slot = mi.stream.vid.enc_slot;
                qDebug() << "✅ [FIX 69.1] Found video call with enc_slot:" << enc_slot;
                return enc_slot;  // 返回编码器端口（capture source）
            } else {
                qDebug() << "   [FIX 69.1] Video media found but enc_slot invalid, skipping";
            }
        }
    }

    qDebug() << "   [FIX 69.1] No video calls with valid enc_slot found";
    return PJSUA_INVALID_ID;  // 未找到
}
