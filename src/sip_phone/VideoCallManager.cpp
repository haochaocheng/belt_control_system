#include "VideoCallManager.h"
#include <QDebug>
#include <QQuickWindow>
#include <pjsua-lib/pjsua.h>

VideoCallManager::VideoCallManager(QObject *parent)
    : QObject(parent)
    , m_videoEnabled(false)
    , m_previewActive(false)
    , m_inVideoCall(false)
    , m_localVideoWindow(nullptr)
    , m_remoteVideoWindow(nullptr)
    , m_currentCallId(PJSUA_INVALID_ID)
    , m_captureDevId(PJMEDIA_VID_DEFAULT_CAPTURE_DEV)
    , m_previewWinId(PJSUA_INVALID_ID)
{
    qDebug() << "VideoCallManager: Created (video subsystem will be initialized after PJSIP startup)";
    // DON'T call initVideoSubsystem() here - PJSIP isn't initialized yet!
    // It will be called from SipPhoneManager after PJSIP is ready
}

VideoCallManager::~VideoCallManager()
{
    qDebug() << "VideoCallManager: Shutting down...";
    stopPreview();
}

bool VideoCallManager::initVideoSubsystem()
{
    pj_status_t status;

    // 枚举视频设备
    unsigned count = pjsua_vid_dev_count();
    qDebug() << "VideoCallManager: Found" << count << "video devices";

    if (count == 0) {
        qWarning() << "VideoCallManager: No video devices found!";
        return false;
    }

    // 列出所有视频设备并查找第一个真实摄像头
    pjmedia_vid_dev_index firstRealCamera = -1;
    for (unsigned i = 0; i < count; ++i) {
        pjmedia_vid_dev_info info;
        status = pjsua_vid_dev_get_info(i, &info);
        if (status == PJ_SUCCESS) {
            qDebug() << "VideoCallManager: Device" << i << ":" << info.name
                     << "Driver:" << info.driver;

            // 查找第一个支持捕获的真实摄像头（跳过HDMI输入、colorbar、null等）
            if (firstRealCamera == -1 && (info.dir & PJMEDIA_DIR_CAPTURE)) {
                // 跳过非摄像头设备（colorbar, null, HDMI input等）
                QString deviceName = QString::fromUtf8(info.name);
                if (!deviceName.contains("colorbar", Qt::CaseInsensitive) &&
                    !deviceName.contains("null", Qt::CaseInsensitive) &&
                    !deviceName.contains("hdmirx", Qt::CaseInsensitive) &&
                    !deviceName.contains("rk_hdmirx", Qt::CaseInsensitive)) {
                    firstRealCamera = i;
                    qDebug() << "✅ VideoCallManager: Selected camera" << i << "as default:" << info.name;
                }
            }
        }
    }

    // ✅ CRITICAL FIX: 设置默认捕获设备为第一个真实摄像头
    if (firstRealCamera >= 0) {
        m_captureDevId = firstRealCamera;
        qDebug() << "✅ VideoCallManager: Default capture device set to:" << m_captureDevId;
    } else {
        qWarning() << "❌ VideoCallManager: No real capture device found, using device 0";
        m_captureDevId = 0;  // 回退到设备0
    }

    // ✅ CRITICAL: Configure H264 encoder parameters for optimal frame rate
    // This fixes the choppy video issue when others see our video
    qDebug() << "📹 Configuring H264 encoder parameters for optimal frame rate...";

    // Configure H264 codec to encode at higher frame rate
    pjmedia_vid_codec_param h264_param;
    pj_str_t h264_codec_id = pj_str((char*)"H264");

    status = pjsua_vid_codec_get_param(&h264_codec_id, &h264_param);
    if (status == PJ_SUCCESS) {
        // ✅ CRITICAL: Check if format structure is initialized before accessing det.vid
        // If detail_type is not PJMEDIA_FORMAT_DETAIL_VIDEO, calling det.vid will crash
        // This happens when default_attr() hasn't been called yet (e.g. manual codec registration)
        if (h264_param.enc_fmt.detail_type != PJMEDIA_FORMAT_DETAIL_VIDEO) {
            qDebug() << "⚠️ H264 format not initialized (detail_type=" << h264_param.enc_fmt.detail_type
                     << "), initializing manually...";

            // Initialize format structures properly
            // ❌ 2025-12-31 旧代码：1280x720 @ 25fps
            // ✅ 2026-01-11 11:35 [修复 100.37.1] 改为 VGA 640x480 @ 30fps（匹配 RisipEndpoint 配置）
            pjmedia_format_init_video(&h264_param.enc_fmt,
                                     PJMEDIA_FORMAT_H264,  // H.264 format ID
                                     640, 480,             // VGA resolution
                                     30, 1);               // 30 fps

            // ❌ 2025-12-31 旧代码：1280x720 @ 60fps
            // ✅ 2026-01-11 11:35 [修复 100.37.1] 改为 VGA 640x480 @ 30fps
            pjmedia_format_init_video(&h264_param.dec_fmt,
                                     PJMEDIA_FORMAT_I420,  // Raw YUV420 for decoder
                                     640, 480,             // VGA resolution
                                     30, 1);               // 30 fps

            qDebug() << "✅ Format initialized: enc_fmt.detail_type=" << h264_param.enc_fmt.detail_type
                     << ", dec_fmt.detail_type=" << h264_param.dec_fmt.detail_type;
        }

        qDebug() << "  Current H264 encoder FPS:" << h264_param.enc_fmt.det.vid.fps.num
                 << "/" << h264_param.enc_fmt.det.vid.fps.denum;

        // ❌ ATTEMPT 14 旧代码: Set encoder to 720P (1280x720) @ 25fps
        // ✅ 2026-01-11 11:35 [修复 100.37.1] 改为 VGA 640x480 @ 30fps（匹配 RisipEndpoint 配置）
        h264_param.enc_fmt.det.vid.fps.num = 30;  // 30 fps
        h264_param.enc_fmt.det.vid.fps.denum = 1;

        // Set resolution to VGA (640x480) - 匹配 RisipEndpoint 配置和对方分辨率
        h264_param.enc_fmt.det.vid.size.w = 640;   // VGA width
        h264_param.enc_fmt.det.vid.size.h = 480;   // VGA height

        // Decoder to match encoder - 30fps
        h264_param.dec_fmt.det.vid.fps.num = 30;   // 30 fps
        h264_param.dec_fmt.det.vid.fps.denum = 1;

        status = pjsua_vid_codec_set_param(&h264_codec_id, &h264_param);
        if (status == PJ_SUCCESS) {
            // ✅ 2026-01-11 11:35 [修复 100.37.1] 更新日志消息为 VGA 640x480 @ 30fps
            qDebug() << "✅ H264 encoder configured: 640x480 (VGA) @ 30fps (TX/RX)";
        } else {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            qWarning() << "⚠️ Failed to set H264 encoder params:" << errmsg;
        }
    } else {
        char errmsg[PJ_ERR_MSG_SIZE];
        pj_strerror(status, errmsg, sizeof(errmsg));
        qWarning() << "⚠️ Failed to get H264 encoder params:" << errmsg;
    }

    // 🚫 REMOVED: Manual codec parameter configuration
    // REASON: Causes crash because pjsua_vid_codec_get_param() returns uninitialized
    // parameters (enc_fmt.detail_type=0) when default_attr() hasn't been called yet.
    // PJSIP will automatically negotiate codec parameters during call setup.
    // See format.c:138 assertion failure in pjmedia_format_get_video_format_detail()
    //
    // Previously attempted to set: codec_param.dir = PJMEDIA_DIR_ENCODING_DECODING
    // But this broke the format structure. PJSIP's default codec negotiation works fine.
    qDebug() << "✅ Using PJSIP's automatic H264 codec parameter negotiation";

    // ✅ Also check and configure video codec priorities
    pjsua_codec_info vid_codecs[32];
    unsigned vid_codec_count = PJ_ARRAY_SIZE(vid_codecs);
    status = pjsua_vid_enum_codecs(vid_codecs, &vid_codec_count);

    if (status == PJ_SUCCESS) {
        qDebug() << "📹 Ensuring video codec priorities are set...";
        for (unsigned i = 0; i < vid_codec_count; ++i) {
            pj_str_t vid_codec_id = vid_codecs[i].codec_id;
            QString codecName = QString::fromUtf8(vid_codec_id.ptr, vid_codec_id.slen);

            // Prioritize H264 highest
            if (codecName.contains("H264", Qt::CaseInsensitive)) {
                pjsua_vid_codec_set_priority(&vid_codec_id, 200);  // Highest priority
                qDebug() << "  Set" << codecName << "priority to 200 (highest)";
            } else if (codecName.contains("VP8", Qt::CaseInsensitive)) {
                pjsua_vid_codec_set_priority(&vid_codec_id, 150);
                qDebug() << "  Set" << codecName << "priority to 150";
            } else if (codecName.contains("VP9", Qt::CaseInsensitive)) {
                pjsua_vid_codec_set_priority(&vid_codec_id, 140);
                qDebug() << "  Set" << codecName << "priority to 140";
            }
        }
    }

    m_videoEnabled = true;
    emit videoEnabledChanged();
    return true;
}

void VideoCallManager::setVideoEnabled(bool enabled)
{
    if (m_videoEnabled != enabled) {
        m_videoEnabled = enabled;
        emit videoEnabledChanged();

        if (!enabled) {
            stopPreview();
        }
    }
}

bool VideoCallManager::startPreview()
{
    if (m_previewActive) {
        qDebug() << "VideoCallManager: Preview already active";
        return true;
    }

    if (!m_videoEnabled) {
        qWarning() << "VideoCallManager: Video is disabled";
        return false;
    }

    qDebug() << "VideoCallManager: Starting preview...";

    pj_status_t status;
    pjsua_vid_preview_param param;
    pjsua_vid_preview_param_default(&param);

    // 如果有 QML 窗口，使用原生窗口句柄
    if (m_localVideoWindow) {
        VideoRenderer* renderer = qobject_cast<VideoRenderer*>(m_localVideoWindow);
        if (renderer) {
            param.wnd.info.win.hwnd = renderer->getNativeHandle();
        }
    }

    // ✅ Attempt 21: 禁用独立SDL窗口（用户反馈：不需要额外的SDL预览窗口）
    // 本地视频已经通过LocalVideoManager在QML界面中显示
    param.show = PJ_FALSE;

    // 启动预览
    status = pjsua_vid_preview_start(m_captureDevId, &param);
    if (status != PJ_SUCCESS) {
        char errmsg[PJ_ERR_MSG_SIZE];
        pj_strerror(status, errmsg, sizeof(errmsg));
        qWarning() << "VideoCallManager: Failed to start preview:" << errmsg;
        emit videoCallError(QString("Failed to start preview: %1").arg(errmsg));
        return false;
    }

    // 获取预览窗口 ID
    m_previewWinId = pjsua_vid_preview_get_win(m_captureDevId);
    qDebug() << "VideoCallManager: Preview started, window ID:" << m_previewWinId;

    m_previewActive = true;
    emit previewActiveChanged();
    return true;
}

void VideoCallManager::stopPreview()
{
    if (!m_previewActive) {
        return;
    }

    qDebug() << "VideoCallManager: Stopping preview...";

    pj_status_t status = pjsua_vid_preview_stop(m_captureDevId);
    if (status != PJ_SUCCESS) {
        char errmsg[PJ_ERR_MSG_SIZE];
        pj_strerror(status, errmsg, sizeof(errmsg));
        qWarning() << "VideoCallManager: Failed to stop preview:" << errmsg;
    }

    m_previewWinId = PJSUA_INVALID_ID;
    m_previewActive = false;
    emit previewActiveChanged();
}

bool VideoCallManager::startVideoCall(int callId)
{
    if (!m_videoEnabled) {
        qWarning() << "VideoCallManager: Video is disabled";
        return false;
    }

    qDebug() << "VideoCallManager: Starting video for call" << callId << "with capture device" << m_captureDevId;

    m_currentCallId = callId;

    // 停止预览（如果正在预览）
    if (m_previewActive) {
        stopPreview();
    }

    pj_status_t status;
    pjsua_call_vid_strm_op_param param;
    pjsua_call_vid_strm_op_param_default(&param);

    // ✅ CRITICAL FIX: Use m_captureDevId (set in initVideoSubsystem) instead of hardcoded 0
    // m_captureDevId contains the actual camera device ID detected during initialization
    param.cap_dev = m_captureDevId;
    qDebug() << "✅ VideoCallManager: Adding video stream with cap_dev=" << param.cap_dev;

    // 添加视频流（发送和接收）
    status = pjsua_call_set_vid_strm(callId, PJSUA_CALL_VID_STRM_ADD, &param);
    if (status != PJ_SUCCESS) {
        char errmsg[PJ_ERR_MSG_SIZE];
        pj_strerror(status, errmsg, sizeof(errmsg));
        qWarning() << "VideoCallManager: Failed to add video stream:" << errmsg;
        emit videoCallError(QString("Failed to add video stream: %1").arg(errmsg));
        return false;
    }

    qDebug() << "VideoCallManager: Video stream added for call" << callId;

    m_inVideoCall = true;
    emit inVideoCallChanged();
    return true;
}

void VideoCallManager::stopVideoCall(int callId)
{
    if (!m_inVideoCall) {
        return;
    }

    qDebug() << "VideoCallManager: Stopping video for call" << callId;

    pjsua_call_vid_strm_op_param param;
    pjsua_call_vid_strm_op_param_default(&param);

    // 移除视频流（但保持音频）
    pj_status_t status = pjsua_call_set_vid_strm(callId, PJSUA_CALL_VID_STRM_REMOVE, &param);
    if (status != PJ_SUCCESS) {
        char errmsg[PJ_ERR_MSG_SIZE];
        pj_strerror(status, errmsg, sizeof(errmsg));
        qWarning() << "VideoCallManager: Failed to remove video stream:" << errmsg;
    }

    m_inVideoCall = false;
    emit inVideoCallChanged();
    m_currentCallId = PJSUA_INVALID_ID;
}

void VideoCallManager::toggleCamera()
{
    if (!m_inVideoCall && !m_previewActive) {
        qWarning() << "VideoCallManager: No active video to toggle camera";
        return;
    }

    qDebug() << "VideoCallManager: Toggling camera...";

    if (m_inVideoCall) {
        // 在通话中切换摄像头
        pjsua_call_vid_strm_op_param param;
        pjsua_call_vid_strm_op_param_default(&param);

        pj_status_t status = pjsua_call_set_vid_strm(m_currentCallId,
                                                       PJSUA_CALL_VID_STRM_CHANGE_CAP_DEV,
                                                       &param);
        if (status != PJ_SUCCESS) {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            qWarning() << "VideoCallManager: Failed to toggle camera:" << errmsg;
        }
    } else if (m_previewActive) {
        // 在预览中重新启动预览
        stopPreview();
        startPreview();
    }
}

void VideoCallManager::setLocalVideoWindow(QObject* window)
{
    if (m_localVideoWindow != window) {
        m_localVideoWindow = window;
        emit localVideoWindowChanged();
        qDebug() << "VideoCallManager: Local video window set:" << window;
    }
}

void VideoCallManager::setRemoteVideoWindow(QObject* window)
{
    if (m_remoteVideoWindow != window) {
        m_remoteVideoWindow = window;
        emit remoteVideoWindowChanged();
        qDebug() << "VideoCallManager: Remote video window set:" << window;
    }
}

QStringList VideoCallManager::getAvailableCameras()
{
    QStringList cameras;
    unsigned count = pjsua_vid_dev_count();

    for (unsigned i = 0; i < count; ++i) {
        pjmedia_vid_dev_info info;
        pj_status_t status = pjsua_vid_dev_get_info(i, &info);
        if (status == PJ_SUCCESS && info.dir & PJMEDIA_DIR_CAPTURE) {
            cameras << QString::fromUtf8(info.name);
        }
    }

    return cameras;
}

void VideoCallManager::switchCamera(int cameraIndex)
{
    if (cameraIndex < 0 || cameraIndex >= (int)pjsua_vid_dev_count()) {
        qWarning() << "VideoCallManager: Invalid camera index:" << cameraIndex;
        return;
    }

    qDebug() << "VideoCallManager: Switching to camera" << cameraIndex;

    m_captureDevId = cameraIndex;

    // 如果正在预览或通话中，重新启动
    if (m_previewActive) {
        stopPreview();
        startPreview();
    }

    if (m_inVideoCall) {
        // 更改通话中的捕获设备
        pjsua_call_vid_strm_op_param param;
        pjsua_call_vid_strm_op_param_default(&param);
        param.cap_dev = m_captureDevId;

        pj_status_t status = pjsua_call_set_vid_strm(m_currentCallId,
                                                       PJSUA_CALL_VID_STRM_CHANGE_CAP_DEV,
                                                       &param);
        if (status != PJ_SUCCESS) {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            qWarning() << "VideoCallManager: Failed to switch camera:" << errmsg;
        }
    }
}

pjsua_vid_win_id VideoCallManager::createVideoWindow(QObject* qmlWindow, bool isPreview)
{
    Q_UNUSED(qmlWindow);
    Q_UNUSED(isPreview);
    // 此函数在当前实现中由 PJSIP 自动管理窗口
    return PJSUA_INVALID_ID;
}

void VideoCallManager::destroyVideoWindow(pjsua_vid_win_id winId)
{
    Q_UNUSED(winId);
    // 窗口由 PJSIP 自动管理
}

// ============================================================================
// VideoRenderer 实现
// ============================================================================

VideoRenderer::VideoRenderer(QQuickItem *parent)
    : QQuickItem(parent)
    , m_isPreview(false)
    , m_nativeHandle(nullptr)
{
    setFlag(QQuickItem::ItemHasContents, true);
    qDebug() << "VideoRenderer: Created";
}

VideoRenderer::~VideoRenderer()
{
    qDebug() << "VideoRenderer: Destroyed";
}

void VideoRenderer::setIsPreview(bool preview)
{
    if (m_isPreview != preview) {
        m_isPreview = preview;
        emit isPreviewChanged();
    }
}

void* VideoRenderer::getNativeHandle()
{
    if (!m_nativeHandle) {
        setupNativeWindow();
    }
    return m_nativeHandle;
}

void VideoRenderer::componentComplete()
{
    QQuickItem::componentComplete();
    qDebug() << "VideoRenderer: Component complete";
    setupNativeWindow();
}

void VideoRenderer::releaseResources()
{
    QQuickItem::releaseResources();
    m_nativeHandle = nullptr;
}

void VideoRenderer::setupNativeWindow()
{
    // 获取 QQuickWindow 的原生窗口句柄
    QQuickWindow* qwindow = window();
    if (!qwindow) {
        qWarning() << "VideoRenderer: No QQuickWindow available";
        return;
    }

#ifdef _WIN32
    // Windows: 获取 HWND
    m_nativeHandle = reinterpret_cast<void*>(qwindow->winId());
#elif defined(__APPLE__)
    // macOS: 获取 NSView
    m_nativeHandle = reinterpret_cast<void*>(qwindow->winId());
#else
    // Linux: 获取 X11 Window ID
    m_nativeHandle = reinterpret_cast<void*>(qwindow->winId());
#endif

    qDebug() << "VideoRenderer: Native handle obtained:" << m_nativeHandle;
    emit nativeHandleReady();
}
