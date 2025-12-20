#ifndef REMOTEVIDEOWIDGET_H
#define REMOTEVIDEOWIDGET_H

#include <QQuickItem>
#include <QQuickWindow>
#include <pjsua.h>

/**
 * @brief Qt Quick Item for embedding PJSIP SDL video window
 *
 * Based on PJSIP vidgui example's VidWin class.
 * Uses SetParent() on Windows to make SDL window a child of Qt window.
 */
class RemoteVideoWidget : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(bool hasVideo READ hasVideo NOTIFY hasVideoChanged)

public:
    explicit RemoteVideoWidget(QQuickItem *parent = nullptr);
    virtual ~RemoteVideoWidget();

    bool hasVideo() const { return m_hasVideo; }

    // Set the PJSIP video window handle to embed
    Q_INVOKABLE void attachVideoWindow(int videoWindowId);
    Q_INVOKABLE void detachVideoWindow();

signals:
    void hasVideoChanged();

protected:
    virtual bool event(QEvent *e) override;
    virtual void componentComplete() override;
    virtual void releaseResources() override;

private:
    pjmedia_vid_dev_hwnd m_hwnd;
    void *m_origParent;
    bool m_hasVideo;

    void attach();
    void detach();
    void setSize();
    void getSize();
    void showSdl(bool visible = true);
};

#endif // REMOTEVIDEOWIDGET_H
