#include "VideoPreviewWidget.h"
#include <QDebug>
#include <QBoxLayout>
#include <QEvent>
#include <QTimer>

#ifdef _WIN32
#include <windows.h>
#endif

#define TRACE_(...) qDebug() << "[VideoPreviewWidget]" << __VA_ARGS__

VideoPreviewWidget::VideoPreviewWidget(const pjmedia_vid_dev_hwnd *hwnd,
                                       QWidget *parent)
    : QWidget(parent)
    , m_origParent(nullptr)
    , m_sizeHint(QWIDGETSIZE_MAX, QWIDGETSIZE_MAX)
    , m_allowHide(false)  // ✅ By default, do NOT allow hiding
    , m_attached(false)   // ✅ Not attached yet
{
    // ✅ CRITICAL: Set Qt::WA_NativeWindow attribute (from official example)
    // This ensures this QWidget has a native window handle that can be used as parent
    setAttribute(Qt::WA_NativeWindow);

    // ✅ Make this widget "lighter" (from official PJSIP example)
    // These attributes tell Qt not to interfere with SDL's rendering
    setAttribute(Qt::WA_UpdatesDisabled);  // ✅ Disable Qt's update mechanism
    setAttribute(Qt::WA_PaintOnScreen);
    setAttribute(Qt::WA_NoSystemBackground);
    setUpdatesEnabled(false);  // ✅ Disable Qt's update system

    // Set background to black
    setAutoFillBackground(true);
    QPalette pal = palette();
    pal.setColor(QPalette::Window, Qt::black);
    setPalette(pal);

    qDebug() << "[VideoPreviewWidget] 🏗️  Constructor: WA_NativeWindow set, updates enabled";

    // Copy hwnd structure
    pj_bzero(&m_hwnd, sizeof(m_hwnd));
    if (hwnd) {
        m_hwnd = *hwnd;
        qDebug() << "✅ hwnd structure copied";
    } else {
        qWarning() << "❌ hwnd pointer is null!";
    }

#ifdef _WIN32
    HWND winHwnd = (HWND)m_hwnd.info.win.hwnd;
    TRACE_("Created with hwnd:", (void*)winHwnd);
#else
    TRACE_("Created (non-Windows platform)");
#endif
}

VideoPreviewWidget::~VideoPreviewWidget()
{
    showSdl(false);
    detach();
}

void VideoPreviewWidget::putIntoLayout(QBoxLayout *layout)
{
    layout->addWidget(this, 1);
    show();
    activateWindow();
}

bool VideoPreviewWidget::event(QEvent *e)
{
    switch(e->type()) {

    case QEvent::Resize:
        qDebug() << "[VideoPreviewWidget] 📏 Resize event, new size:" << size();
        setSize();
        break;

    case QEvent::ParentChange:
        qDebug() << "[VideoPreviewWidget] 👪 ParentChange event, attached=" << m_attached;
        if (!m_attached) {
            getSize();
            setFixedSize(m_sizeHint);
            attach();
            m_attached = true;
            qDebug() << "[VideoPreviewWidget] ✅ Attached via ParentChange event";
        } else {
            qDebug() << "[VideoPreviewWidget] ⚠️ Already attached - skipping";
        }
        break;

    case QEvent::Show:
        qDebug() << "[VideoPreviewWidget] 👁️  Show event triggered, attached=" << m_attached;

        // ✅ If already attached (manual attach before show), just set size and show
        if (m_attached) {
            qDebug() << "[VideoPreviewWidget] ✅ Already attached manually, showing SDL window";
            setSize();
            showSdl(true);
            setFixedSize(QWIDGETSIZE_MAX, QWIDGETSIZE_MAX);
        } else {
            // ✅ Fallback: attach on Show event if not already attached
            // This shouldn't happen if attach() was called manually before show()
            qDebug() << "[VideoPreviewWidget] ⚠️ Not attached yet, attaching on Show event";
            attach();
            m_attached = true;
            setSize();
            showSdl(true);
            setFixedSize(QWIDGETSIZE_MAX, QWIDGETSIZE_MAX);
        }
        break;

    case QEvent::Hide:
        qDebug() << "[VideoPreviewWidget] 👁️  Hide event triggered";
        // ✅ The m_allowHide flag controls whether we allow hiding
        if (m_allowHide) {
            qDebug() << "[VideoPreviewWidget] ✅ Hide allowed, hiding SDL window";
            showSdl(false);
            // Let the Hide event proceed normally
        } else {
            qDebug() << "[VideoPreviewWidget] ⚠️ Hide not allowed - ignoring Hide event";
            // ✅ CRITICAL: Ignore the Hide event to prevent QWidget from being hidden
            // This is essential because if QWidget (parent) is hidden, SDL child window
            // will also be hidden automatically by Windows window manager
            e->ignore();
            qDebug() << "[VideoPreviewWidget] ✅ Hide event ignored, widget should stay visible";
        }
        break;

    default:
        break;
    }

    return QWidget::event(e);
}

// ===== Platform specific implementation =====

#ifdef _WIN32

void VideoPreviewWidget::attach()
{
    if (!m_hwnd.info.win.hwnd) {
        qWarning() << "[VideoPreviewWidget] ❌ attach() called but hwnd is null";
        return;
    }

    HWND w = (HWND)m_hwnd.info.win.hwnd;
    HWND newParent = (HWND)winId();
    m_origParent = GetParent(w);

    qDebug() << "[VideoPreviewWidget] 🔗 Attaching SDL window:";
    qDebug() << "   SDL HWND:" << (void*)w;
    qDebug() << "   Original parent:" << m_origParent;
    qDebug() << "   New parent (Qt widget):" << (void*)newParent;

    // ✅ Following official PJSIP example: Do NOT modify window style!
    // SetWindowLong can break SDL's rendering context
    // Official example has this line commented out: //SetWindowLong(w, GWL_STYLE, WS_CHILD);

    // ✅ Just reparent the window (following official example)
    HWND result = SetParent(w, newParent);

    if (result) {
        qDebug() << "[VideoPreviewWidget] ✅ SetParent succeeded, old parent was:" << (void*)result;
    } else {
        DWORD error = GetLastError();
        qWarning() << "[VideoPreviewWidget] ❌ SetParent failed! Error code:" << error;
    }

    qDebug() << "[VideoPreviewWidget] ✅ SDL window attached (no style modification)";

    // Verify parent-child relationship
    HWND currentParent = GetParent(w);
    qDebug() << "[VideoPreviewWidget] 🔍 Verification:";
    qDebug() << "   Current parent of SDL window:" << (void*)currentParent;
    qDebug() << "   Expected parent (Qt widget):" << (void*)newParent;
    qDebug() << "   Match:" << (currentParent == newParent ? "YES ✅" : "NO ❌");
}

void VideoPreviewWidget::detach()
{
    if (!m_hwnd.info.win.hwnd) {
        return;
    }

    HWND w = (HWND)m_hwnd.info.win.hwnd;
    SetParent(w, (HWND)m_origParent);
    TRACE_("Detached:", (void*)w, "reverted to parent:", (void*)m_origParent);
}

void VideoPreviewWidget::setSize()
{
    if (!m_hwnd.info.win.hwnd) {
        qWarning() << "[VideoPreviewWidget] ❌ setSize() called but hwnd is null";
        return;
    }

    HWND w = (HWND)m_hwnd.info.win.hwnd;
    QRect qr = rect();

    qDebug() << "[VideoPreviewWidget] 📐 setSize() called:";
    qDebug() << "   SDL HWND:" << (void*)w;
    qDebug() << "   Widget rect:" << qr;
    qDebug() << "   Width x Height:" << qr.width() << "x" << qr.height();

    if (qr.width() == 0 || qr.height() == 0) {
        qWarning() << "[VideoPreviewWidget] ⚠️ Widget has zero size, SetWindowPos may not work correctly!";
    }

    UINT swpFlag = SWP_NOACTIVATE;
    BOOL result = SetWindowPos(w, HWND_TOP, 0, 0, qr.width(), qr.height(), swpFlag);

    if (result) {
        qDebug() << "[VideoPreviewWidget] ✅ SetWindowPos succeeded:" << qr.width() << "x" << qr.height();
    } else {
        DWORD error = GetLastError();
        qWarning() << "[VideoPreviewWidget] ❌ SetWindowPos failed! Error code:" << error;
    }

    // Verify the actual window size after SetWindowPos
    RECT actualRect;
    if (GetWindowRect(w, &actualRect)) {
        int actualWidth = actualRect.right - actualRect.left;
        int actualHeight = actualRect.bottom - actualRect.top;
        qDebug() << "[VideoPreviewWidget] 🔍 Actual SDL window size after SetWindowPos:" << actualWidth << "x" << actualHeight;
    }
}

void VideoPreviewWidget::getSize()
{
    if (!m_hwnd.info.win.hwnd) {
        return;
    }

    HWND w = (HWND)m_hwnd.info.win.hwnd;
    RECT r;
    if (GetWindowRect(w, &r)) {
        m_sizeHint = QSize(r.right - r.left + 1, r.bottom - r.top + 1);
    }
    TRACE_("Got size:", (void*)w, "=", m_sizeHint.width(), "x", m_sizeHint.height());
}

void VideoPreviewWidget::showSdl(bool visible)
{
    if (!m_hwnd.info.win.hwnd) {
        qWarning() << "[VideoPreviewWidget] ❌ showSdl() called but hwnd is null";
        return;
    }

    HWND w = (HWND)m_hwnd.info.win.hwnd;

    qDebug() << "[VideoPreviewWidget] 👁️  showSdl(" << visible << ") called:";
    qDebug() << "   SDL HWND:" << (void*)w;

    BOOL result = ShowWindow(w, visible ? SW_SHOW : SW_HIDE);

    if (visible) {
        // Also update and redraw the window to ensure it displays
        UpdateWindow(w);

        // Verify window is actually visible
        BOOL isVisible = IsWindowVisible(w);
        qDebug() << "[VideoPreviewWidget] ✅ SDL window shown and updated";
        qDebug() << "[VideoPreviewWidget] 🔍 IsWindowVisible:" << (isVisible ? "YES ✅" : "NO ❌");

        // Get window rect to verify position
        RECT windowRect;
        if (GetWindowRect(w, &windowRect)) {
            qDebug() << "[VideoPreviewWidget] 🔍 SDL window screen position:";
            qDebug() << "   Left:" << windowRect.left << "Top:" << windowRect.top;
            qDebug() << "   Right:" << windowRect.right << "Bottom:" << windowRect.bottom;
        }
    } else {
        qDebug() << "[VideoPreviewWidget] ✅ SDL window hidden";
    }
}

#else
// Stub implementations for non-Windows platforms
void VideoPreviewWidget::attach() {}
void VideoPreviewWidget::detach() {}
void VideoPreviewWidget::setSize() {}
void VideoPreviewWidget::getSize() {}
void VideoPreviewWidget::showSdl(bool visible) { Q_UNUSED(visible); }
#endif
