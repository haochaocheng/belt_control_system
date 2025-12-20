#ifndef VIDEOPREVIEWWIDGET_H
#define VIDEOPREVIEWWIDGET_H

#include <QWidget>
#include <pjmedia/videodev.h>

// Forward declarations
class QBoxLayout;

/**
 * @brief Widget for embedding SDL video preview window
 *
 * This widget embeds the PJSIP/SDL video preview window as a child window
 * Based on PJSIP official example: pjsip-apps/src/vidgui/vidwin.cpp
 */
class VideoPreviewWidget : public QWidget
{
    Q_OBJECT

public:
    explicit VideoPreviewWidget(const pjmedia_vid_dev_hwnd *hwnd,
                                QWidget *parent = nullptr);
    ~VideoPreviewWidget();

    void putIntoLayout(QBoxLayout *layout);

    // ✅ Control whether hide() is allowed (used by stopVideoPreview)
    void setAllowHide(bool allow) { m_allowHide = allow; }

    // ✅ Manually trigger attach (called before show() to ensure proper parent-child relationship)
    void attach();

protected:
    bool event(QEvent *e) override;

private:
    pjmedia_vid_dev_hwnd m_hwnd;
    void *m_origParent;
    QSize m_sizeHint;
    bool m_allowHide;  // ✅ Flag to control whether hide is allowed
    bool m_attached;   // ✅ Flag to track if SDL window is already attached

    void detach();
    void setSize();
    void getSize();
    void showSdl(bool visible = true);
};

#endif // VIDEOPREVIEWWIDGET_H
