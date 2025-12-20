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
    // Reduced verbosity - only log start
    // qDebug() << "📹 LocalVideoManager: Starting PJSIP video preview";

    // ✅ CRITICAL FIX: Auto-detect first real camera (skip HDMI input, colorbar, null devices)
    // This ensures compatibility with both Windows (usually device 0 or 1) and RK3588 (USB Camera = device 1)
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
    }

    // 启动 PJSIP 视频预览 (使用自动检测的摄像头，配置分辨率和帧率)
    pjsua_vid_preview_param param;
    pjsua_vid_preview_param_default(&param);

    // ✅ ATTEMPT 14: Configure camera for 720P (1280x720) to match H.264 encoder
    // This ensures device opens with correct resolution for PortSIP UC Client compatibility
    // PortSIP UC Client supports: CIF (352×288), 720P (1280×720), 1080P (1920×1080)
    pjmedia_format_init_video(&param.format, PJMEDIA_FORMAT_YUY2, 1280, 720, 60, 1);

    // ✅ 禁用独立 SDL 窗口显示（我们用 QML 界面显示视频）
    param.show = PJ_FALSE;

    // qDebug() << "📹 Configuring camera: 1280x720 (720P) @ 60fps (YUY2 format), SDL window hidden";

    pj_status_t status = pjsua_vid_preview_start(m_captureDevId, &param);
    if (status != PJ_SUCCESS) {
        qWarning() << "❌ LocalVideoManager: Failed to start PJSIP video preview, status:" << status;
        emit errorOccurred("Failed to start video preview");
        return;
    }

    qDebug() << "✅ LocalVideoManager: PJSIP preview started successfully";

    // 获取预览窗口ID (使用检测到的摄像头设备ID)
    m_previewWinId = pjsua_vid_preview_get_win(m_captureDevId);
    if (m_previewWinId == PJSUA_INVALID_ID) {
        qWarning() << "❌ LocalVideoManager: Failed to get preview window ID";
        return;
    }

    // qDebug() << "📺 LocalVideoManager: Preview window ID:" << m_previewWinId;

    // 尝试附加到预览端口
    if (attachPreviewPort()) {
        m_hasLocalVideo = true;
        emit hasLocalVideoChanged();

        // 启动帧捕获定时器
        m_captureTimer->start();
        // qDebug() << "✅ LocalVideoManager: Frame capture started at 60fps";
    } else {
        qWarning() << "❌ LocalVideoManager: Failed to attach to preview port";
    }
}

void LocalVideoManager::stopPreview()
{
    // qDebug() << "📹 LocalVideoManager: Stopping PJSIP video preview";

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
