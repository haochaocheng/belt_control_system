#include "VideoFrameProvider.h"
#include <QDebug>
#include <pjmedia/converter.h>

// Static instance
VideoFrameProvider* VideoFrameProvider::m_instance = nullptr;
VideoFrameNotifier* VideoFrameNotifier::m_instance = nullptr;

VideoFrameProvider::VideoFrameProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
    qDebug() << "✅ VideoFrameProvider created";

    // Create a default black frame
    m_currentFrame = QImage(640, 480, QImage::Format_RGB888);
    m_currentFrame.fill(Qt::black);
}

VideoFrameProvider::~VideoFrameProvider()
{
}

QImage VideoFrameProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    Q_UNUSED(id);
    Q_UNUSED(requestedSize);

    QMutexLocker locker(&m_frameMutex);

    if (size) {
        *size = m_currentFrame.size();
    }

    // Return copy of current frame
    return m_currentFrame.copy();
}

void VideoFrameProvider::updateFrame(const QImage &newFrame)
{
    if (newFrame.isNull()) {
        return;
    }

    {
        QMutexLocker locker(&m_frameMutex);
        m_currentFrame = newFrame.copy();
    }

    // Notify QML to update the image
    if (VideoFrameNotifier::instance()) {
        emit VideoFrameNotifier::instance()->frameUpdated();
    }
}

VideoFrameProvider* VideoFrameProvider::instance()
{
    if (!m_instance) {
        m_instance = new VideoFrameProvider();
    }
    return m_instance;
}

// VideoFrameNotifier implementation
VideoFrameNotifier* VideoFrameNotifier::instance()
{
    if (!m_instance) {
        m_instance = new VideoFrameNotifier();
    }
    return m_instance;
}
