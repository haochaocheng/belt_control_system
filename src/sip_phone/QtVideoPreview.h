#ifndef QTVIDEOPREVIEW_H
#define QTVIDEOPREVIEW_H

#include <QObject>
#include <QCamera>
#include <QVideoSink>
#include <QMediaCaptureSession>
#include <QVideoFrame>

/**
 * @brief Qt-native video preview using Qt Multimedia
 *
 * This class provides camera preview functionality using Qt 6 Multimedia
 * instead of PJSIP's SDL-based preview. This allows seamless integration
 * with QML without window embedding issues.
 *
 * The video frames are delivered via Qt's video sink mechanism and can be
 * displayed directly in QML using VideoOutput component.
 */
class QtVideoPreview : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject* videoSink READ videoSink CONSTANT)

public:
    explicit QtVideoPreview(QObject *parent = nullptr);
    ~QtVideoPreview();

    // Start camera preview
    Q_INVOKABLE bool startPreview();

    // Stop camera preview
    Q_INVOKABLE void stopPreview();

    // Check if preview is active
    Q_INVOKABLE bool isActive() const;

    // Get video sink for QML VideoOutput
    QObject* videoSink() const;

signals:
    void errorOccurred(const QString &error);
    void previewStarted();
    void previewStopped();

private slots:
    void onCameraErrorOccurred(QCamera::Error error, const QString &errorString);

private:
    QCamera *m_camera;
    QMediaCaptureSession *m_captureSession;
    QVideoSink *m_videoSink;
    bool m_active;
};

#endif // QTVIDEOPREVIEW_H
