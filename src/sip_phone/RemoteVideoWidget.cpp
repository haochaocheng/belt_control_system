#include "RemoteVideoWidget.h"
#include <QDebug>
#include <QEvent>
#include <pjsua-lib/pjsua.h>

#ifdef _WIN32
#include <windows.h>
#endif

#define THIS_FILE "RemoteVideoWidget.cpp"

RemoteVideoWidget::RemoteVideoWidget(QQuickItem *parent)
    : QQuickItem(parent)
    , m_origParent(nullptr)
    , m_hasVideo(false)
{
    // Don't set ItemHasContents - this widget is just a container for SDL window
    // The actual rendering is done by SDL, not by Qt

    // Don't capture mouse events - let them pass through
    setAcceptedMouseButtons(Qt::NoButton);

    // Make this item transparent and non-interactive
    setOpacity(1.0);
    setEnabled(true);

    pj_bzero(&m_hwnd, sizeof(m_hwnd));

    qDebug() << "✅ RemoteVideoWidget created (transparent container)";
}

RemoteVideoWidget::~RemoteVideoWidget()
{
    qDebug() << "RemoteVideoWidget: Destroying...";
    showSdl(false);
    detach();
}

void RemoteVideoWidget::attachVideoWindow(int videoWindowId)
{
    if (videoWindowId == PJSUA_INVALID_ID) {
        qWarning() << "❌ RemoteVideoWidget: Invalid video window ID";
        return;
    }

    qDebug() << "📹 RemoteVideoWidget: Attaching video window" << videoWindowId;

    // Get PJSIP video window info
    pjsua_vid_win_info wi;
    pj_status_t status = pjsua_vid_win_get_info(videoWindowId, &wi);

    if (status != PJ_SUCCESS) {
        char errmsg[PJ_ERR_MSG_SIZE];
        pj_strerror(status, errmsg, sizeof(errmsg));
        qWarning() << "❌ RemoteVideoWidget: Failed to get video window info:" << errmsg;
        return;
    }

    qDebug() << "📺 RemoteVideoWidget: Video window info:";
    qDebug() << "   - Show:" << (wi.show ? "Yes" : "No");
    qDebug() << "   - Position:" << wi.pos.x << "," << wi.pos.y;
    qDebug() << "   - Size:" << wi.size.w << "x" << wi.size.h;

    // Store the HWND
    m_hwnd = wi.hwnd;

    // Get the original size
    getSize();

    // Attach SDL window to this Qt Quick item
    attach();

    // Show the SDL window
    showSdl(true);

    m_hasVideo = true;
    emit hasVideoChanged();

    qDebug() << "✅ RemoteVideoWidget: Video window attached successfully";
}

void RemoteVideoWidget::detachVideoWindow()
{
    if (!m_hasVideo) {
        return;
    }

    qDebug() << "🔌 RemoteVideoWidget: Detaching video window";

    showSdl(false);
    detach();

    pj_bzero(&m_hwnd, sizeof(m_hwnd));
    m_hasVideo = false;
    emit hasVideoChanged();
}

bool RemoteVideoWidget::event(QEvent *e)
{
    switch (e->type()) {

    case QEvent::Resize:
        if (m_hasVideo) {
            setSize();
        }
        break;

    case QEvent::Show:
        if (m_hasVideo) {
            showSdl(true);
        }
        break;

    case QEvent::Hide:
        if (m_hasVideo) {
            showSdl(false);
        }
        break;

    default:
        break;
    }

    return QQuickItem::event(e);
}

void RemoteVideoWidget::componentComplete()
{
    QQuickItem::componentComplete();
    qDebug() << "RemoteVideoWidget: Component complete";
}

void RemoteVideoWidget::releaseResources()
{
    QQuickItem::releaseResources();
    detachVideoWindow();
}

// ============================================================================
// Platform-specific implementation (Windows)
// ============================================================================

#ifdef _WIN32

void RemoteVideoWidget::attach()
{
    if (!m_hwnd.info.win.hwnd) {
        qWarning() << "❌ RemoteVideoWidget::attach: No HWND available";
        return;
    }

    HWND sdlWindow = (HWND)m_hwnd.info.win.hwnd;

    // Get the Qt Quick window's HWND
    QQuickWindow *qwindow = window();
    if (!qwindow) {
        qWarning() << "❌ RemoteVideoWidget::attach: No QQuickWindow available";
        return;
    }

    HWND qtWindow = (HWND)qwindow->winId();

    // Save original parent
    m_origParent = GetParent(sdlWindow);

    qDebug() << "🔗 RemoteVideoWidget: Attaching SDL window" << sdlWindow
             << "to Qt window" << qtWindow;

    // 🔑 KEY: Set SDL window as child of Qt window (like vidgui does)
    SetParent(sdlWindow, qtWindow);

    // Set size to match this QML item
    setSize();

    qDebug() << "✅ RemoteVideoWidget: SDL window attached as child of Qt window";
}

void RemoteVideoWidget::detach()
{
    if (!m_hwnd.info.win.hwnd) {
        return;
    }

    HWND sdlWindow = (HWND)m_hwnd.info.win.hwnd;

    qDebug() << "🔌 RemoteVideoWidget: Detaching SDL window" << sdlWindow;

    // Restore original parent
    SetParent(sdlWindow, (HWND)m_origParent);
}

void RemoteVideoWidget::setSize()
{
    if (!m_hwnd.info.win.hwnd) {
        return;
    }

    HWND sdlWindow = (HWND)m_hwnd.info.win.hwnd;

    // Get this QML item's geometry
    int itemWidth = static_cast<int>(width());
    int itemHeight = static_cast<int>(height());

    // Get the QML item's position in the window
    QQuickWindow *qwindow = window();
    if (!qwindow) {
        return;
    }

    QPointF scenePos = mapToScene(QPointF(0, 0));
    int x = static_cast<int>(scenePos.x());
    int y = static_cast<int>(scenePos.y());

    qDebug() << "📐 RemoteVideoWidget: Resizing SDL window to"
             << itemWidth << "x" << itemHeight
             << "at position" << x << "," << y;

    // Position and size the SDL window within the Qt window
    UINT swpFlag = SWP_NOACTIVATE | SWP_NOZORDER;
    SetWindowPos(sdlWindow, HWND_TOP, x, y, itemWidth, itemHeight, swpFlag);
}

void RemoteVideoWidget::getSize()
{
    if (!m_hwnd.info.win.hwnd) {
        return;
    }

    HWND sdlWindow = (HWND)m_hwnd.info.win.hwnd;
    RECT r;

    if (GetWindowRect(sdlWindow, &r)) {
        int w = r.right - r.left;
        int h = r.bottom - r.top;
        qDebug() << "📏 RemoteVideoWidget: SDL window size:" << w << "x" << h;
    }
}

void RemoteVideoWidget::showSdl(bool visible)
{
    if (!m_hwnd.info.win.hwnd) {
        return;
    }

    HWND sdlWindow = (HWND)m_hwnd.info.win.hwnd;

    qDebug() << "👁️ RemoteVideoWidget: Setting SDL window visibility to" << visible;
    ShowWindow(sdlWindow, visible ? SW_SHOW : SW_HIDE);
}

#else
// Non-Windows platforms would need their own implementation
// (X11 for Linux, Cocoa for macOS)

void RemoteVideoWidget::attach()
{
    qWarning() << "⚠️ RemoteVideoWidget::attach: Not implemented for this platform";
}

void RemoteVideoWidget::detach()
{
}

void RemoteVideoWidget::setSize()
{
}

void RemoteVideoWidget::getSize()
{
}

void RemoteVideoWidget::showSdl(bool visible)
{
    Q_UNUSED(visible);
}

#endif
