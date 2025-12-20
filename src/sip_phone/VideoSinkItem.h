#ifndef VIDEOSINKITEM_H
#define VIDEOSINKITEM_H

#include <QQuickItem>
#include <QVideoSink>
#include <QVideoFrame>
#include <QImage>

/**
 * @brief QML item that displays video frames from a QVideoSink
 *
 * This custom QQuickItem renders video frames from Qt Multimedia's QVideoSink
 * directly in QML using Qt Quick Scene Graph.
 *
 * Usage in QML:
 *   VideoSinkItem {
 *       anchors.fill: parent
 *       sink: SipPhoneManager.qtVideoPreview.videoSink
 *   }
 */
class VideoSinkItem : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(QVideoSink* sink READ sink WRITE setSink NOTIFY sinkChanged)

public:
    explicit VideoSinkItem(QQuickItem *parent = nullptr);
    ~VideoSinkItem();

    QVideoSink* sink() const { return m_sink; }
    void setSink(QVideoSink *sink);

signals:
    void sinkChanged();

protected:
    QSGNode* updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;

private slots:
    void onVideoFrameChanged(const QVideoFrame &frame);

private:
    QVideoSink *m_sink;
    QImage m_currentImage;
    bool m_frameChanged;
    bool m_hasContentEnabled;  // Track if ItemHasContents has been enabled
};

#endif // VIDEOSINKITEM_H
