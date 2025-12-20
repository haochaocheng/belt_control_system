#include "VideoSinkItem.h"
#include <QSGSimpleTextureNode>
#include <QQuickWindow>
#include <QDebug>

VideoSinkItem::VideoSinkItem(QQuickItem *parent)
    : QQuickItem(parent)
    , m_sink(nullptr)
    , m_frameChanged(false)
    , m_hasContentEnabled(false)
{
    // DON'T set ItemHasContents here - only enable it when we have frames
    // setFlag(ItemHasContents, true);  // ❌ This blocks other QML elements!
    qDebug() << "✅ VideoSinkItem created (ItemHasContents disabled until first frame)";
}

VideoSinkItem::~VideoSinkItem()
{
    if (m_sink) {
        disconnect(m_sink, nullptr, this, nullptr);
    }
}

void VideoSinkItem::setSink(QVideoSink *sink)
{
    if (m_sink == sink) {
        return;
    }

    // Disconnect old sink
    if (m_sink) {
        disconnect(m_sink, &QVideoSink::videoFrameChanged, this, &VideoSinkItem::onVideoFrameChanged);
        qDebug() << "Disconnected from old video sink";
    }

    m_sink = sink;

    // Connect new sink
    if (m_sink) {
        connect(m_sink, &QVideoSink::videoFrameChanged, this, &VideoSinkItem::onVideoFrameChanged);
        qDebug() << "✅ Connected to video sink, waiting for frames...";
    }

    emit sinkChanged();
}

void VideoSinkItem::onVideoFrameChanged(const QVideoFrame &frame)
{
    static int frameCount = 0;

    if (!frame.isValid()) {
        return;
    }

    // Convert video frame to QImage
    QVideoFrame clonedFrame = frame;
    if (!clonedFrame.map(QVideoFrame::ReadOnly)) {
        qWarning() << "❌ Failed to map video frame";
        return;
    }

    // Get image from video frame
    QImage image = clonedFrame.toImage();
    clonedFrame.unmap();

    if (image.isNull()) {
        qWarning() << "❌ Failed to convert frame to image, format:" << frame.pixelFormat();
        return;
    }

    // Convert to RGB32 format for rendering
    m_currentImage = image.convertToFormat(QImage::Format_RGB32);
    m_frameChanged = true;

    // ✅ Enable ItemHasContents on first frame (not in constructor!)
    // This prevents blocking other QML elements when no video is available
    if (!m_hasContentEnabled) {
        setFlag(ItemHasContents, true);
        m_hasContentEnabled = true;
        qDebug() << "✅ First video frame received:" << m_currentImage.size()
                 << "from format:" << frame.pixelFormat();
        qDebug() << "✅ ItemHasContents enabled now that we have frames";
    }

    frameCount++;
    // Verbose debug disabled per user request
    // if (frameCount % 60 == 0) {  // 每2秒打印一次（30fps）
    //     qDebug() << "🎞️ VideoSinkItem rendered" << frameCount << "frames";
    // }

    // Request update to render the new frame
    update();
}

QSGNode* VideoSinkItem::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *)
{
    if (m_currentImage.isNull()) {
        // No frame yet, return empty node
        delete oldNode;
        return nullptr;
    }

    QSGSimpleTextureNode *textureNode = static_cast<QSGSimpleTextureNode*>(oldNode);
    if (!textureNode) {
        textureNode = new QSGSimpleTextureNode();
    }

    // Only update texture if we have a new frame
    if (m_frameChanged) {
        QSGTexture *texture = window()->createTextureFromImage(m_currentImage, QQuickWindow::TextureIsOpaque);
        textureNode->setTexture(texture);
        textureNode->setOwnsTexture(true);
        m_frameChanged = false;
    }

    // Update geometry to match item size
    QRectF rect(0, 0, width(), height());

    // Calculate aspect ratio preserving rectangle
    if (!m_currentImage.isNull()) {
        qreal imageAspect = qreal(m_currentImage.width()) / m_currentImage.height();
        qreal itemAspect = width() / height();

        if (imageAspect > itemAspect) {
            // Image is wider - fit to width
            qreal scaledHeight = width() / imageAspect;
            qreal yOffset = (height() - scaledHeight) / 2;
            rect = QRectF(0, yOffset, width(), scaledHeight);
        } else {
            // Image is taller - fit to height
            qreal scaledWidth = height() * imageAspect;
            qreal xOffset = (width() - scaledWidth) / 2;
            rect = QRectF(xOffset, 0, scaledWidth, height());
        }
    }

    textureNode->setRect(rect);

    return textureNode;
}
