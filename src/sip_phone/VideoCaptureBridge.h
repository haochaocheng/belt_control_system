#ifndef VIDEOCAPTUREBRIDGE_H
#define VIDEOCAPTUREBRIDGE_H

#include <QObject>
#include <QImage>
#include <pjsua.h>
#include <pjmedia/videodev.h>

/**
 * @brief Bridge between PJSIP video capture and Qt/QML
 *
 * This class captures raw video frames from PJSIP camera device
 * and converts them to QImage for display in QML.
 *
 * Approach: Use PJSIP's video port directly to receive frames
 * without relying on SDL window rendering.
 */
class VideoCaptureBridge : public QObject
{
    Q_OBJECT

public:
    explicit VideoCaptureBridge(QObject *parent = nullptr);
    ~VideoCaptureBridge();

    // Start capturing video from camera
    bool startCapture(pjmedia_vid_dev_index captureDeviceId);

    // Stop capturing video
    void stopCapture();

    // Check if capture is active
    bool isCapturing() const { return m_capturing; }

signals:
    void frameReady(const QImage &frame);
    void errorOccurred(const QString &error);

private:
    bool m_capturing;
    pjmedia_vid_port *m_vidPort;
    pjmedia_port *m_vidPortBase;
    pj_pool_t *m_pool;

    // Callback for video frames from PJSIP
    static pj_status_t onFrameCallback(pjmedia_port *port,
                                       pjmedia_frame *frame);

    // Convert PJSIP frame to QImage
    QImage convertFrameToImage(pjmedia_frame *frame);
};

#endif // VIDEOCAPTUREBRIDGE_H
