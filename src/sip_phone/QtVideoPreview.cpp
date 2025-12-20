#include "QtVideoPreview.h"
#include <QDebug>
#include <QCameraDevice>
#include <QMediaDevices>

QtVideoPreview::QtVideoPreview(QObject *parent)
    : QObject(parent)
    , m_camera(nullptr)
    , m_captureSession(nullptr)
    , m_videoSink(nullptr)
    , m_active(false)
{
    qDebug() << "✅ QtVideoPreview created (Qt Multimedia-based)";

    // Create video sink for rendering
    m_videoSink = new QVideoSink(this);
    qDebug() << "✅ QVideoSink created";

    // Create capture session
    m_captureSession = new QMediaCaptureSession(this);
    m_captureSession->setVideoSink(m_videoSink);
    qDebug() << "✅ QMediaCaptureSession created and connected to video sink";
}

QtVideoPreview::~QtVideoPreview()
{
    stopPreview();
}

bool QtVideoPreview::startPreview()
{
    if (m_active) {
        qDebug() << "⚠️ Video preview already active";
        return true;
    }

    qDebug() << "✅ Starting Qt Multimedia video preview...";

    // Get list of available cameras
    const QList<QCameraDevice> cameras = QMediaDevices::videoInputs();
    if (cameras.isEmpty()) {
        QString error = "没有找到可用的摄像头";
        qWarning() << "❌" << error;
        emit errorOccurred(error);
        return false;
    }

    // Log available cameras
    qDebug() << "📹 Available cameras:";
    for (int i = 0; i < cameras.size(); ++i) {
        const QCameraDevice &cameraDevice = cameras.at(i);
        qDebug() << "   Camera" << i << ":" << cameraDevice.description();
        qDebug() << "      ID:" << cameraDevice.id();
        qDebug() << "      Position:" << cameraDevice.position();
        qDebug() << "      Default:" << (cameraDevice == QMediaDevices::defaultVideoInput() ? "YES" : "NO");
    }

    // Use default camera (usually the integrated webcam)
    const QCameraDevice &cameraDevice = QMediaDevices::defaultVideoInput();
    if (cameraDevice.isNull()) {
        QString error = "无法获取默认摄像头";
        qWarning() << "❌" << error;
        emit errorOccurred(error);
        return false;
    }

    qDebug() << "✅ Using camera:" << cameraDevice.description();

    // Create camera
    m_camera = new QCamera(cameraDevice, this);

    // Connect error signal
    connect(m_camera, &QCamera::errorOccurred, this, &QtVideoPreview::onCameraErrorOccurred);

    // Set camera to capture session
    m_captureSession->setCamera(m_camera);
    qDebug() << "✅ Camera connected to capture session";

    // Start camera
    m_camera->start();
    qDebug() << "✅ Camera started";

    m_active = true;
    emit previewStarted();
    qDebug() << "✅ Qt video preview started successfully";
    qDebug() << "   Video frames will be delivered to QML VideoOutput via videoSink";

    return true;
}

void QtVideoPreview::stopPreview()
{
    if (!m_active) {
        return;
    }

    qDebug() << "✅ Stopping Qt video preview...";

    if (m_camera) {
        m_camera->stop();
        m_camera->deleteLater();
        m_camera = nullptr;
        qDebug() << "✅ Camera stopped and deleted";
    }

    m_active = false;
    emit previewStopped();
    qDebug() << "✅ Qt video preview stopped";
}

bool QtVideoPreview::isActive() const
{
    return m_active;
}

QObject* QtVideoPreview::videoSink() const
{
    return m_videoSink;
}

void QtVideoPreview::onCameraErrorOccurred(QCamera::Error error, const QString &errorString)
{
    qWarning() << "❌ Camera error:" << error << errorString;
    emit errorOccurred(errorString);
}
