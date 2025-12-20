#ifndef LOCALVIDEOMANAGER_H
#define LOCALVIDEOMANAGER_H

#include <QObject>
#include <QTimer>
#include <QVideoSink>
#include <QVideoFrame>
#include <QImage>
#include <pjsua.h>
#include <pjmedia.h>

/**
 * @brief 本地视频管理器 - 从 PJSIP 预览获取视频帧
 *
 * 不使用 Qt Multimedia 的 QCamera 独立控制摄像头，
 * 而是从 PJSIP 的视频预览端口获取帧，避免摄像头资源冲突
 */
class LocalVideoManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject* videoSink READ videoSink CONSTANT)
    Q_PROPERTY(bool hasLocalVideo READ hasLocalVideo NOTIFY hasLocalVideoChanged)

public:
    explicit LocalVideoManager(QObject *parent = nullptr);
    ~LocalVideoManager();

    QObject* videoSink() const;
    bool hasLocalVideo() const { return m_hasLocalVideo; }

    // 视频预览控制
    Q_INVOKABLE void startPreview();
    Q_INVOKABLE void stopPreview();

signals:
    void hasLocalVideoChanged();
    void errorOccurred(const QString &error);

private slots:
    void capturePreviewFrame();

private:
    QVideoSink *m_videoSink;
    bool m_hasLocalVideo;
    pjsua_vid_win_id m_previewWinId;
    pjmedia_port *m_previewPort;
    QTimer *m_captureTimer;
    pjmedia_vid_dev_index m_captureDevId;  // ✅ Store the capture device ID used for preview

    bool attachPreviewPort();
    void detachPreviewPort();
    QVideoFrame convertPjFrameToQt(pjmedia_frame *frame, const pjmedia_format *fmt);
};

#endif // LOCALVIDEOMANAGER_H
