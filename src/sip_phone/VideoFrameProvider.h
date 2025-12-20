#ifndef VIDEOFRAMEPROVIDER_H
#define VIDEOFRAMEPROVIDER_H

#include <QObject>
#include <QQuickImageProvider>
#include <QImage>
#include <QMutex>
#include <pjsua.h>

/**
 * @brief Image provider that delivers video frames from PJSIP to QML
 *
 * This class receives raw video frames from PJSIP camera capture and
 * converts them to QImage for display in QML Image component.
 *
 * Usage in QML:
 *   Image {
 *       source: "image://videoprovider/frame"
 *       cache: false  // Important: disable caching for live video
 *   }
 */
class VideoFrameProvider : public QQuickImageProvider
{
public:
    VideoFrameProvider();
    ~VideoFrameProvider();

    // Override from QQuickImageProvider
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

    // Update the current frame (called from PJSIP callback)
    void updateFrame(const QImage &newFrame);

    // Get singleton instance
    static VideoFrameProvider* instance();

private:
    QImage m_currentFrame;
    QMutex m_frameMutex;
    static VideoFrameProvider* m_instance;
};

/**
 * @brief QObject wrapper for VideoFrameProvider to expose signals to QML
 *
 * Since QQuickImageProvider cannot inherit QObject, we use this wrapper
 * to emit signals when new frames arrive.
 */
class VideoFrameNotifier : public QObject
{
    Q_OBJECT

public:
    static VideoFrameNotifier* instance();

signals:
    void frameUpdated();  // Emitted when new frame is available

private:
    VideoFrameNotifier() = default;
    static VideoFrameNotifier* m_instance;
};

#endif // VIDEOFRAMEPROVIDER_H
