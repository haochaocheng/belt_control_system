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

    /* ✅ 2026-01-09 14:40 [调试 Fix 95] 追踪 QVideoSink 信号接收
     * 问题：RemoteVideoManager 调用 setVideoFrame，但 VideoSinkItem 可能未收到信号
     * 目的：验证 QVideoSink::videoFrameChanged 信号是否触发
     * 预期：每帧触发，frameCount 递增
     */
    frameCount++;
    if (frameCount % 15 == 1) {
        qDebug() << "📹 [VIDEO SINK ITEM] Received frame" << frameCount
                 << "size:" << frame.width() << "x" << frame.height()
                 << "valid:" << frame.isValid()
                 << "format:" << frame.pixelFormat();
    }

    if (!frame.isValid()) {
        if (frameCount < 5) {
            qWarning() << "❌ [ERROR Fix 95] VideoSinkItem received invalid frame!";
        }
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

    // Request update to render the new frame
    update();
}

QSGNode* VideoSinkItem::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *)
{
    /* ✅ 2026-01-09 14:40 [调试 Fix 95] 追踪 Qt Scene Graph 渲染
     * 问题：帧接收正常，但可能未渲染到屏幕
     * 目的：验证 Qt Scene Graph 是否调用渲染函数
     * 预期：每帧调用，创建纹理并更新节点
     */
    static int renderCount = 0;
    renderCount++;

    if (renderCount % 15 == 1) {
        qDebug() << "📹 [PAINT NODE] Rendering frame" << renderCount
                 << "image:" << m_currentImage.width() << "x" << m_currentImage.height()
                 << "item size:" << width() << "x" << height()
                 << "has content:" << m_hasContentEnabled;
    }

    if (m_currentImage.isNull()) {
        // No frame yet, return empty node
        if (renderCount == 1) {
            qDebug() << "⚠️ [PAINT NODE] No image yet, returning nullptr";
        }
        delete oldNode;
        return nullptr;
    }

    QSGSimpleTextureNode *textureNode = static_cast<QSGSimpleTextureNode*>(oldNode);
    if (!textureNode) {
        textureNode = new QSGSimpleTextureNode();
        qDebug() << "📹 [PAINT NODE] Created new texture node";
    }

    // Only update texture if we have a new frame
    if (m_frameChanged) {
        QSGTexture *texture = window()->createTextureFromImage(m_currentImage, QQuickWindow::TextureIsOpaque);
        textureNode->setTexture(texture);
        textureNode->setOwnsTexture(true);
        m_frameChanged = false;

        if (renderCount % 15 == 1) {
            qDebug() << "📹 [PAINT NODE] Created texture from image:" << m_currentImage.size();
        }
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
