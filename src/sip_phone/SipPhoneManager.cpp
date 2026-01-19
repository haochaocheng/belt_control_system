#include "SipPhoneManager.h"
#include "VideoCallManager.h"
#include "VideoPreviewWidget.h"
#include "QtVideoPreview.h"
#include "VideoSinkItem.h"
#include "LocalVideoManager.h"
#include "RemoteVideoManager.h"
#include <QDebug>
#include <QTimer>
#include <QThread>
#include <QQmlEngine>
#include <QJSEngine>
#include <QQmlContext>
#include <QRegularExpression>
#include <QSet>  // ✅ 2026-01-18 12:30 [FIX 100.246] 用于过滤重复声卡
#include <QFileDialog>
#include <QFile>
#include <QDir>
#include <QSettings>
#include <QFileInfo>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QUrl>

// Undefine UNICODE before including PJSIP headers to avoid string function errors
#ifdef UNICODE
#undef UNICODE
#endif
#ifdef _UNICODE
#undef _UNICODE
#endif

// Macro to stringify FD_SETSIZE value for debug output
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

// Risip SDK headers
#include "risipendpoint.h"
#include "risipcall.h"
#include "risipaccount.h"
#include "risipaccountconfiguration.h"
#include "risipcallmanager.h"
#include "risip.h"
#include "ContactDatabase.h"  // 联系人数据库

// PJMEDIA video device headers (for setting default devices)
#include <pjmedia/videodev.h>

// PJSUA C API headers (for direct video/audio control)
#include <pjsua.h>

// Windows-specific headers for window embedding
#ifdef _WIN32
#include <windows.h>
#include <SDL.h>
#include <SDL_syswm.h>
#endif

// ✅ Static callback for receiving call state notifications from PJSIP C API calls
// This is registered with RisipEndpoint to receive updates about video calls created with C API
static void onCallStateChanged(int call_id, pjsip_inv_state state, const char* state_text)
{
    // Get SipPhoneManager instance
    SipPhoneManager *manager = SipPhoneManager::instance();
    if (!manager) {
        return;
    }

    // Map PJSIP call states to user-friendly messages
    QString statusText;
    bool isInCall = false;

    switch (state) {
    case PJSIP_INV_STATE_NULL:
        statusText = "就绪";
        break;
    case PJSIP_INV_STATE_CALLING:
        // ✅ 呼叫状态也显示联系人名字
        {
            QString displayName = manager->callerDisplayName();
            if (displayName.isEmpty()) {
                statusText = "呼叫中...";
            } else {
                // 检查是否是视频通话
                bool isVideoCall = manager->isCurrentCallVideo();
                statusText = isVideoCall ?
                    QString("视频拨号: %1").arg(displayName) :
                    QString("呼叫 %1").arg(displayName);
            }
        }
        break;
    case PJSIP_INV_STATE_INCOMING:
        // ✅ 来电状态也显示联系人名字
        {
            QString displayName = manager->callerDisplayName();
            if (displayName.isEmpty()) {
                statusText = "来电中...";
            } else {
                statusText = QString("来电: %1").arg(displayName);
            }
        }
        isInCall = true;

        // ✅ Video detection is now handled in risipendpoint.cpp call_state_callback_wrapper()
        // BEFORE this callback is invoked, using invite session's SDP negotiator
        // DO NOT detect video here as media_cnt is still 0 and will overwrite the correct detection!
        break;
    case PJSIP_INV_STATE_EARLY:
        // ✅ 振铃状态也显示联系人名字
        {
            QString displayName = manager->callerDisplayName();
            if (displayName.isEmpty()) {
                statusText = "早期媒体/振铃中...";
            } else {
                statusText = QString("%1 振铃中").arg(displayName);
            }
        }
        break;
    case PJSIP_INV_STATE_CONNECTING:
        statusText = "连接中...";
        break;
    case PJSIP_INV_STATE_CONFIRMED:
        // ✅ 使用联系人显示名而不是硬编码 "通话中"
        {
            QString displayName = manager->callerDisplayName();
            if (displayName.isEmpty()) {
                statusText = "通话中";
            } else {
                // 检查是否是视频通话
                bool isVideoCall = manager->isCurrentCallVideo();
                statusText = isVideoCall ?
                    QString("视频通话中: %1").arg(displayName) :
                    QString("与 %1 通话中").arg(displayName);
            }
        }
        isInCall = true;
        // Notify video managers that call is connected
        manager->notifyCallConnected(call_id);

        // ❌ 2026-01-19 07:30 [FIX 100.249] 移除会议桥音量恢复代码
        // 原因：已改用硬件增益 API (pjsua_snd_set_setting)
        //       硬件增益在 PJSIP 初始化时就已经恢复，无需在通话建立时再次设置
        // 新位置：risipendpoint.cpp 音频设备初始化后
        // 旧代码保留用于参考：
        // QMetaObject::invokeMethod(manager, [manager]() {
        //     QSettings settings;
        //     int savedVolume = settings.value("SIP/MicrophoneVolume", 80).toInt();
        //     float level = (savedVolume / 100.0f) * 2.0f;
        //     pj_status_t status = pjsua_conf_adjust_tx_level(0, level);
        //     ...
        // }, Qt::QueuedConnection);

        // ✅ ATTEMPT 13: Activate video via CHANGE_DIR after call is CONFIRMED
        // Check if this call has pending video activation
        QMetaObject::invokeMethod(manager, [manager, call_id]() {
            manager->activatePendingVideo(call_id);
        }, Qt::QueuedConnection);
        break;
    case PJSIP_INV_STATE_DISCONNECTED:
        qDebug() << "🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════";
        qDebug() << "🔴 [HANGUP-DEBUG] 进入 PJSIP_INV_STATE_DISCONNECTED 回调";
        qDebug() << "🔴 [HANGUP-DEBUG] call_id:" << call_id;
        qDebug() << "🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════";
        qDebug() << "🔴 [FIX 72 DIAG] PJSIP_INV_STATE_DISCONNECTED triggered, call_id:" << call_id;
        statusText = "通话结束";
        isInCall = false;
        // Notify video managers that call is disconnected
        qDebug() << "🔴 [HANGUP-DEBUG] 准备调用 notifyCallDisconnected()...";
        qDebug() << "🔴 [FIX 72] About to call notifyCallDisconnected()";
        manager->notifyCallDisconnected();
        qDebug() << "🔴 [HANGUP-DEBUG] notifyCallDisconnected() 已完成";
        qDebug() << "🔴 [FIX 72] notifyCallDisconnected() completed";

        // ✅ 重置视频来电标志和当前通话视频标志
        QMetaObject::invokeMethod(manager, [manager]() {
            manager->setIsIncomingVideoCall(false);
            manager->setIsCurrentCallVideo(false);
        }, Qt::QueuedConnection);
        break;
    default:
        statusText = QString::fromUtf8(state_text);
        break;
    }

    qDebug() << "✅ [UI UPDATE] Call" << call_id << "state:" << statusText;

    // Update UI status via SipPhoneManager's public method
    manager->updateCallStatus(statusText);

    // Update inCall property
    if (manager->isInCall() != isInCall) {
        manager->setInCall(isInCall);
    }

    // ✅ CRITICAL FIX: Start/stop call timer in Qt main thread
    // This callback is called from PJSIP thread, but QTimer must be started in Qt main thread
    if (state == PJSIP_INV_STATE_CONFIRMED) {
        // Use QMetaObject::invokeMethod to call startCallTimer() in Qt main thread
        QMetaObject::invokeMethod(manager, "startCallTimer", Qt::QueuedConnection);
    } else if (state == PJSIP_INV_STATE_DISCONNECTED) {
        // Use QMetaObject::invokeMethod to call stopCallTimer() in Qt main thread
        QMetaObject::invokeMethod(manager, "stopCallTimer", Qt::QueuedConnection);
        QMetaObject::invokeMethod(manager, [manager]() {
            manager->setCurrentNumber("");  // Clear number when call ends
        }, Qt::QueuedConnection);
    }
}

/**
 * Private implementation class (PIMPL pattern)
 * This separates the Risip/PJSIP implementation details from the header
 */
class SipPhoneManager::Private
{
public:
    Private(SipPhoneManager *parent)
        : q(parent)
        , initialized(false)
        , registered(false)
        , inCall(false)
        , callStatus("就绪")
        , serverStatus("未连接")
        , currentNumber("")
        , isIncomingVideoCall(false)
        , isCurrentCallVideo(false)
        , callDuration(0)
        , callTimer(nullptr)
        , risipInstance(nullptr)
        , currentAccount(nullptr)
        , currentCall(nullptr)
        , videoCallManager(nullptr)
        , videoPreviewActive(false)      // ✅ 视频预览状态
        , videoPreviewWindowId(PJSUA_INVALID_ID)  // ✅ 视频预览窗口ID
        , videoPreviewWidget(nullptr)    // ✅ 视频预览Widget
    {
        callTimer = new QTimer(parent);
        callTimer->setInterval(1000);

        // Create video call manager
        videoCallManager = new VideoCallManager(parent);

        // Create Qt Multimedia-based video preview
        qtVideoPreview = new QtVideoPreview(parent);
        qDebug() << "✅ QtVideoPreview created (for QML integration)";

        // Create local video manager (PJSIP preview)
        localVideoManager = new LocalVideoManager(parent);
        qDebug() << "✅ LocalVideoManager created (for PJSIP preview)";

        // Create remote video manager
        remoteVideoManager = new RemoteVideoManager(parent);
        qDebug() << "✅ RemoteVideoManager created (for video calls)";

        // ✅ 2026-01-18 01:00 [FIX 100.246] 不在构造函数中创建 Risip
        // 原因：用户点击 SIP 按钮进入设置页面时才需要设备枚举
        // Risip 实例将在第一次调用设备枚举函数时按需创建
        qDebug() << "✅ [FIX 100.246] Risip instance will be created on-demand when user enters SIP settings";
    }

    ~Private()
    {
        // Cleanup is handled in shutdownEndpoint
    }

    SipPhoneManager *q;

    // State variables
    bool initialized;
    bool registered;
    bool inCall;
    QString callStatus;
    QString serverStatus;
    QString currentNumber;
    QString callerDisplayName;  // 来电/去电显示名（联系人名或号码）
    bool isIncomingVideoCall;  // 标识当前来电是否是视频通话
    bool isCurrentCallVideo;   // 标识当前通话（呼入或呼出）是否是视频通话
    int callDuration;

    // Timer for call duration
    QTimer *callTimer;

    // Risip components
    risip::Risip *risipInstance;
    risip::RisipAccount *currentAccount;
    risip::RisipCall *currentCall;

    // Video call manager
    VideoCallManager *videoCallManager;

    // Video preview state (本机视频预览)
    bool videoPreviewActive;          // 视频预览是否正在运行
    pjsua_vid_win_id videoPreviewWindowId;  // PJSIP 视频预览窗口 ID
    VideoPreviewWidget *videoPreviewWidget;  // Widget用于嵌入SDL窗口

    // Qt Multimedia-based video preview (NEW: replaces SDL embedding)
    QtVideoPreview *qtVideoPreview;   // Qt-native video preview

    // Local video manager (for displaying local PJSIP preview in QML)
    LocalVideoManager *localVideoManager;

    // Remote video manager (for displaying remote party's video in calls)
    RemoteVideoManager *remoteVideoManager;

    // ✅ 2026-01-18 12:00 [FIX 100.246] 设备列表缓存（前后端分离）
    // 原因：QML 绑定 property，PJSIP 初始化后更新这些列表并发射 signal
    QStringList cachedAudioInputDevices;   // 音频输入设备列表（麦克风）
    QStringList cachedAudioOutputDevices;  // 音频输出设备列表（扬声器）
    QStringList cachedVideoDevices;        // 视频设备列表（摄像头）

    // ✅ 2026-01-19 08:15 [FIX 100.250] 设备索引映射数组
    // 原因：用户层设备索引（过滤后）≠ PJSIP 层设备索引（原始）
    // 问题：设备枚举时过滤了 Loopback、HDMI、虚拟设备，用户看到的索引 [0,1,2]
    //       但 PJSIP 原始索引可能是 [6,7,21]，直接使用用户索引会选错设备
    // 解决：枚举时建立映射数组，选择时转换索引
    // 示例：用户选择索引 1（USB 麦克风）→ 映射到 PJSIP 索引 21
    // 参考：docs/2026-01-19/02-三个问题完整修复方案.md Lines 257-407
    QVector<int> audioInputDeviceMapping;   // 用户索引 → PJSIP 索引（麦克风）
    QVector<int> audioOutputDeviceMapping;  // 用户索引 → PJSIP 索引（扬声器）
    QVector<int> videoDeviceMapping;        // 用户索引 → PJSIP 索引（摄像头）

    // ✅ ATTEMPT 13: Pending video activation (CHANGE_DIR approach)
    pjsua_call_id pendingVideoActivationCallId = PJSUA_INVALID_ID;
};

// Static instance
SipPhoneManager *SipPhoneManager::m_instance = nullptr;

SipPhoneManager::SipPhoneManager(QObject *parent)
    : QObject(parent)
    , d(new Private(this))
{
    // Initialize call timer
    connect(d->callTimer, &QTimer::timeout, this, [this]() {
        d->callDuration++;
        emit callDurationChanged(d->callDuration);
    });

    // Initialize contact database
    risip::ContactDatabase::instance()->initialize();

    // ✅ 2026-01-18 01:00 [FIX 100.246] 版本确认
    qDebug() << "═══════════════════════════════════════════════════════";
    qDebug() << "🔥🔥🔥 SipPhoneManager VERSION 2026-01-18-01:00";
    qDebug() << "🔥🔥🔥 FIX 100.246 - 懒加载：用户进入 SIP 设置时才创建 Risip";
    qDebug() << "═══════════════════════════════════════════════════════";
}

SipPhoneManager::~SipPhoneManager()
{
    shutdownEndpoint();
    delete d;
}

SipPhoneManager* SipPhoneManager::instance()
{
    if (!m_instance) {
        m_instance = new SipPhoneManager();
    }
    return m_instance;
}

void SipPhoneManager::registerToQml()
{
    static bool registered = false;
    if (registered) {
        qDebug() << "SipPhoneManager already registered, skipping";
        return;
    }

    qmlRegisterSingletonType<SipPhoneManager>("BeltControl.SipPhone", 1, 0, "SipPhoneManager",
        [](QQmlEngine *engine, QJSEngine *scriptEngine) -> QObject * {
            Q_UNUSED(engine)
            Q_UNUSED(scriptEngine)
            return SipPhoneManager::instance();
        });

    // Register VideoPreviewWidget type for QML (though QML can't directly use QWidget)
    // The widget will be accessed via SipPhoneManager's getVideoPreviewWidget() method
    qmlRegisterUncreatableType<VideoPreviewWidget>("BeltControl.SipPhone", 1, 0, "VideoPreviewWidget",
        "VideoPreviewWidget can only be obtained from SipPhoneManager");

    // Register VideoSinkItem - custom QML component for displaying video from QVideoSink
    qmlRegisterType<VideoSinkItem>("BeltControl.SipPhone", 1, 0, "VideoSinkItem");
    // Register RemoteVideoWidget for embedding PJSIP SDL video windows
    qDebug() << "✅ VideoSinkItem registered to QML";

    registered = true;
    qDebug() << "SipPhoneManager registered to QML";
}

// Property getters
bool SipPhoneManager::isInitialized() const
{
    return d->initialized;
}

bool SipPhoneManager::isRegistered() const
{
    return d->registered;
}

bool SipPhoneManager::isInCall() const
{
    return d->inCall;
}

QString SipPhoneManager::callStatus() const
{
    return d->callStatus;
}

QString SipPhoneManager::currentNumber() const
{
    return d->currentNumber;
}

QString SipPhoneManager::callerDisplayName() const
{
    return d->callerDisplayName;
}

bool SipPhoneManager::isIncomingVideoCall() const
{
    return d->isIncomingVideoCall;
}

bool SipPhoneManager::isCurrentCallVideo() const
{
    return d->isCurrentCallVideo;
}

int SipPhoneManager::callDuration() const
{
    return d->callDuration;
}

QString SipPhoneManager::serverStatus() const
{
    return d->serverStatus;
}

QObject* SipPhoneManager::accountsModel() const
{
    if (!d->risipInstance) {
        qDebug() << "[DEBUG] accountsModel() called but risipInstance is null";
        return nullptr;
    }

    QObject* model = d->risipInstance->allAccountsModel();
    if (model) {
        QAbstractItemModel* itemModel = qobject_cast<QAbstractItemModel*>(model);
        if (itemModel) {
            qDebug() << "[DEBUG] accountsModel() returning model with" << itemModel->rowCount() << "accounts";
        }
    } else {
        qDebug() << "[DEBUG] accountsModel() returning nullptr";
    }
    return model;
}

void SipPhoneManager::setCurrentNumber(const QString &number)
{
    if (d->currentNumber != number) {
        d->currentNumber = number;
        emit currentNumberChanged(number);
    }
}

void SipPhoneManager::setCallerDisplayName(const QString &name)
{
    if (d->callerDisplayName != name) {
        d->callerDisplayName = name;
        emit callerDisplayNameChanged(name);
    }
}

// SIP endpoint control
bool SipPhoneManager::initializeEndpoint()
{
    // ✅ 2026-01-18 11:30 [DEBUG] 添加调用时机追踪
    qDebug() << "════════════════════════════════════════════════════════════";
    qDebug() << "🔥🔥🔥 [ENTRY] initializeEndpoint() called!";
    qDebug() << "   [TIMING] Called at:" << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz");
    qDebug() << "   [STATE] d->initialized =" << d->initialized;
    qDebug() << "   [STATE] d->risipInstance =" << (d->risipInstance ? "EXISTS" : "NULL");
    qDebug() << "════════════════════════════════════════════════════════════";

    qDebug() << "Initializing SIP endpoint with Risip SDK...";

    if (d->initialized) {
        qDebug() << "Endpoint already initialized";
        return true;
    }

    // ✅ 2026-01-18 01:00 [FIX 100.246] 创建或使用已有的 Risip 实例
    // 原因：Risip 可能已在设备枚举时创建（用户进入设置页面），也可能还未创建
    // 无论哪种情况，确保 Risip 实例存在
    if (!d->risipInstance) {
        qDebug() << "Creating Risip instance (not yet created by device enumeration)...";
        d->risipInstance = risip::Risip::instance();
        if (!d->risipInstance) {
            qCritical() << "Failed to create Risip instance";
            updateServerStatus("无法创建 SIP 引擎");
            return false;
        }
        qDebug() << "✅ Risip instance created";
    } else {
        qDebug() << "✅ Using existing Risip instance (created by device enumeration)";
    }

    // Get the SIP endpoint from Risip singleton
    risip::RisipEndpoint *endpoint = d->risipInstance->sipEndpoint();
    if (!endpoint) {
        qCritical() << "Failed to get SIP endpoint from Risip instance";
        updateServerStatus("无法获取 SIP 引擎");
        return false;
    }

    // Initialize Risip endpoint (with recompiled PJSIP 2.15.1)
    qDebug() << "Starting Risip endpoint with fixed PJSIP (FD_SETSIZE=" TOSTRING(FD_SETSIZE) ")...";
    int status = endpoint->start();

    if (status != 1) {  // 1 means Started
        QString errorMsg = endpoint->errorMessage();
        QString errorInfo = endpoint->errorInfo();
        qCritical() << "SIP引擎启动失败:" << errorMsg;
        qCritical() << "Error info:" << errorInfo;
        qCritical() << "Endpoint status:" << status;
        updateServerStatus("SIP引擎启动失败: " + errorMsg);
        return false;
    }

    qDebug() << "SIP endpoint started successfully";
    d->initialized = true;
    emit isInitializedChanged(true);
    updateServerStatus("已初始化");

    // ✅ 2026-01-01 22:55 [调试] 在PJSIP初始化完成后立即设置详细日志级别
    // 目的：诊断视频接收失败问题（远程视频接收为0帧）
    // 时机：必须在PJSIP endpoint启动之后，这样日志设置才能生效
    pj_log_set_level(5);  // 0=禁用, 5=最详细
    qDebug() << "✅ PJSIP log level set to 5 (maximum debug) after endpoint initialization";

    // ✅ Register call state callback for UI updates
    // This ensures video calls created with C API will update the UI
    risip::RisipEndpoint::registerCallStateCallback(&onCallStateChanged);
    qDebug() << "✅ Registered call state callback for UI updates";

    // CRITICAL: Initialize video subsystem AFTER PJSIP is ready
    // This must happen BEFORE we enumerate devices
    qDebug() << "Initializing video subsystem (PJSIP is now ready)...";
    if (d->videoCallManager) {
        d->videoCallManager->initVideoSubsystem();
    }

    // CRITICAL: Set video capture device in ALL accounts
    // This is REQUIRED for PJSIP to find the device during video channel updates
    // Based on PJSIP examples: pjsua/pjsua_app_common.c and vidgui/vidgui.cpp
    qDebug() << "Setting video capture device in all accounts...";

    // ✅ CRITICAL: Get the REAL capture device ID from VideoCallManager
    // We CANNOT hardcode device 0 because on this system:
    //   Device 0 = colorbar (RENDER ONLY, Dir=2)
    //   Device 1 = Integrated Webcam (CAPTURE, Dir=1)
    pjmedia_vid_dev_index realCaptureDevice = 0;
    if (d->videoCallManager) {
        realCaptureDevice = d->videoCallManager->getCaptureDeviceId();
        qDebug() << "✅ Using real capture device ID from VideoCallManager:" << realCaptureDevice;
    } else {
        qWarning() << "⚠️ VideoCallManager not available, using device 0 (may be colorbar!)";
    }

    try {
        // Get all account IDs
        pjsua_acc_id acc_ids[10];
        unsigned count = PJ_ARRAY_SIZE(acc_ids);
        pj_status_t status = pjsua_enum_accs(acc_ids, &count);

        if (status == PJ_SUCCESS && count > 0) {
            qDebug() << "Found" << count << "accounts, setting video devices...";
            for (unsigned i = 0; i < count; ++i) {
                // Create temporary pool for getting account config
                pj_pool_t *pool = pjsua_pool_create("tmp-acc-cfg", 512, 512);
                if (!pool) {
                    qWarning() << "Failed to create pool for account config";
                    continue;
                }

                // Get current account config (requires pool parameter)
                pjsua_acc_config acc_cfg;
                pjsua_acc_config_default(&acc_cfg);
                status = pjsua_acc_get_config(acc_ids[i], pool, &acc_cfg);

                if (status == PJ_SUCCESS) {
                    // Set video capture device to the REAL camera (not colorbar!)
                    acc_cfg.vid_cap_dev = realCaptureDevice;
                    acc_cfg.vid_rend_dev = PJMEDIA_VID_DEFAULT_RENDER_DEV;  // ✅ 必须保留渲染设备以接收远程视频

                    // ✅ CRITICAL FIX: Enable auto-transmit so video encoder starts automatically
                    // ✅ Disable auto-show (no SDL window), use Qt VideoSinkItem for remote video
                    acc_cfg.vid_in_auto_show = PJ_FALSE;  // ✅ 禁用SDL窗口自动显示，但保留渲染器
                    acc_cfg.vid_out_auto_transmit = PJ_TRUE;  // ✅ Changed from PJ_FALSE - this was causing encoder to pause!

                    // Modify account with new video config
                    status = pjsua_acc_modify(acc_ids[i], &acc_cfg);
                    if (status == PJ_SUCCESS) {
                        qDebug() << "Account" << acc_ids[i] << "video device set to" << realCaptureDevice;
                    } else {
                        char errmsg[PJ_ERR_MSG_SIZE];
                        pj_strerror(status, errmsg, sizeof(errmsg));
                        qWarning() << "Failed to modify account" << acc_ids[i] << ":" << errmsg;
                    }
                } else {
                    char errmsg[PJ_ERR_MSG_SIZE];
                    pj_strerror(status, errmsg, sizeof(errmsg));
                    qWarning() << "Failed to get account config for account" << acc_ids[i] << ":" << errmsg;
                }

                // Release the temporary pool
                pj_pool_release(pool);
            }
        } else {
            qDebug() << "No accounts found yet (will be configured when account is created)";
        }
    } catch (const std::exception &ex) {
        qWarning() << "Failed to set video devices:" << ex.what();
    } catch (...) {
        qWarning() << "Unknown error setting video devices";
    }

    // Connect to RisipCallManager for incoming calls
    risip::RisipCallManager *callManager = risip::RisipCallManager::instance();
    if (callManager) {
        connect(callManager, &risip::RisipCallManager::incomingCall, this, [this](risip::RisipCall *call) {
            // 2026-01-17 13:50 [调试] 添加详细日志定位卡住位置
            qDebug() << "[SipPhoneManager-DEBUG] ⏰ Lambda START: Incoming call handler";

            if (!call) {
                qDebug() << "[SipPhoneManager-DEBUG] ⚠️ call is NULL, returning";
                return;
            }
            qDebug() << "[SipPhoneManager-DEBUG] ✅ Step 1: call is valid";

            qDebug() << "[SipPhoneManager-DEBUG] ⏰ Step 2: Getting contact from buddy...";
            qDebug() << "Incoming call from:" << call->buddy()->contact();
            qDebug() << "[SipPhoneManager-DEBUG] ✅ Step 2: Got contact";

            qDebug() << "[SipPhoneManager-DEBUG] ⏰ Step 3: Setting currentCall...";
            d->currentCall = call;
            qDebug() << "[SipPhoneManager-DEBUG] ✅ Step 3: currentCall set";

            // ✅ Video detection is now handled in risipendpoint.cpp call_state_callback_wrapper()
            // at INCOMING state using invite session's SDP negotiator - this is more reliable
            // because it has access to the remote SDP before answering the call.
            // DO NOT detect video here as media_cnt is still 0 at this point!

            // Emit incoming call signal to QML
            qDebug() << "[SipPhoneManager-DEBUG] ⏰ Step 4: Getting caller number...";
            QString callerNumber = call->buddy()->contact();
            qDebug() << "[SipPhoneManager-DEBUG] ✅ Step 4: Caller number:" << callerNumber;

            // ✅ 提取纯号码（处理 "Extension 1006" 1006 这样的格式）
            qDebug() << "[SipPhoneManager-DEBUG] ⏰ Step 5: Extracting phone number...";
            QString extractedNumber = extractPhoneNumber(callerNumber);
            qDebug() << "[SipPhoneManager-DEBUG] ✅ Step 5: Extracted:" << extractedNumber;

            // ✅ 查询联系人名字，优先显示联系人名字
            qDebug() << "[SipPhoneManager-DEBUG] ⏰ Step 6: Querying contact database...";
            QString callerName = risip::ContactDatabase::instance()->getContactName(extractedNumber);
            qDebug() << "[SipPhoneManager-DEBUG] ✅ Step 6: Got contact name:" << callerName;

            qDebug() << "[SipPhoneManager-DEBUG] ⏰ Step 7: Determining display name...";
            QString displayName = callerName.isEmpty() ? callerNumber : callerName;
            qDebug() << "[SipPhoneManager-DEBUG] ✅ Step 7: Display name:" << displayName;

            qDebug() << "📇 Incoming call - Raw:" << callerNumber << "Extracted:" << extractedNumber << "Display:" << displayName;

            // 保存显示名供后续使用
            qDebug() << "[SipPhoneManager-DEBUG] ⏰ Step 8: Setting caller display name...";
            setCallerDisplayName(displayName);
            qDebug() << "[SipPhoneManager-DEBUG] ✅ Step 8: Caller display name set";

            qDebug() << "[SipPhoneManager-DEBUG] ⏰ Step 9: Emitting incomingCall() signal to QML...";
            emit incomingCall(callerNumber, displayName);
            qDebug() << "[SipPhoneManager-DEBUG] ✅ Step 9: incomingCall() signal emitted";

            qDebug() << "[SipPhoneManager-DEBUG] ⏰ Step 10: Updating call status...";
            updateCallStatus("来电: " + displayName);
            qDebug() << "[SipPhoneManager-DEBUG] ✅ Step 10: Call status updated";

            // Connect call status signals (same as in makeCall)
            qDebug() << "[SipPhoneManager-DEBUG] ⏰ Step 11: Connecting status changed signal...";
            connect(d->currentCall, &risip::RisipCall::statusChanged, this, [this]() {
                if (!d->currentCall) {
                    qDebug() << "Call status changed but currentCall is null, ignoring";
                    return;
                }
                int callState = d->currentCall->status();
                qDebug() << "Call state changed:" << callState;

                if (callState == risip::RisipCall::CallConfirmed) {
                    d->inCall = true;
                    emit isInCallChanged(true);
                    emit callConnected();
                    updateCallStatus("通话中");
                    d->callDuration = 0;
                    d->callTimer->start();
                    qDebug() << "Call connected";
                } else if (callState == risip::RisipCall::CallDisconnected) {
                    // Remote party hung up - clean up call state
                    qDebug() << "Remote party disconnected, cleaning up...";
                    d->callTimer->stop();
                    d->currentCall = nullptr;
                    d->inCall = false;
                    emit isInCallChanged(false);
                    emit callDisconnected();
                    updateCallStatus("就绪");
                    d->callDuration = 0;
                    emit callDurationChanged(0);

                    // ✅ 重置视频来电标志并停止预启动的设备
                    if (d->videoPreviewActive && d->videoCallManager) {
                        qDebug() << "📹 [PRE-START] Stopping pre-started device (call disconnected)";
                        pjmedia_vid_dev_index cap_dev = d->videoCallManager->getCaptureDeviceId();
                        pjsua_vid_preview_stop(cap_dev);
                        d->videoPreviewActive = false;
                    }
                    setIsIncomingVideoCall(false);
                } else if (callState == risip::RisipCall::Null) {
                    // Call returned to Null state after disconnect
                    qDebug() << "Call state returned to Null, cleaning up...";
                    d->callTimer->stop();
                    d->currentCall = nullptr;
                    d->inCall = false;
                    emit isInCallChanged(false);
                    emit callDisconnected();
                    updateCallStatus("就绪");
                    d->callDuration = 0;
                    emit callDurationChanged(0);

                    // ✅ 重置视频来电标志并停止预启动的设备
                    if (d->videoPreviewActive && d->videoCallManager) {
                        qDebug() << "📹 [PRE-START] Stopping pre-started device (call returned to Null)";
                        pjmedia_vid_dev_index cap_dev = d->videoCallManager->getCaptureDeviceId();
                        pjsua_vid_preview_stop(cap_dev);
                        d->videoPreviewActive = false;
                    }
                    setIsIncomingVideoCall(false);
                }
            });
            qDebug() << "[SipPhoneManager-DEBUG] ✅ Step 11: Status changed signal connected";

            qDebug() << "[SipPhoneManager-DEBUG] ✅ Lambda END: Incoming call handler completed";
        });
        qDebug() << "Connected to RisipCallManager for incoming calls";
    }

    // Load saved accounts from QSettings
    qDebug() << "Loading saved accounts from QSettings...";
    bool settingsLoaded = d->risipInstance->readSettings();

    if (settingsLoaded) {
        qDebug() << "Saved accounts loaded successfully";

        // CRITICAL: Emit signal to notify QML that accountsModel is now populated
        emit accountsModelChanged();
        qDebug() << "Emitted accountsModelChanged() signal to QML";

        // If there's a default account, auto-register it
        risip::RisipAccount *defaultAccount = d->risipInstance->defaultAccount();
        if (defaultAccount && defaultAccount->configuration()) {
            qDebug() << "Auto-registering default account:" << defaultAccount->configuration()->uri();
            d->currentAccount = defaultAccount;

            // Set as active account in RisipCallManager (CRITICAL for incoming calls!)
            risip::RisipCallManager *callManager = risip::RisipCallManager::instance();
            if (callManager) {
                callManager->setActiveAccount(d->currentAccount);
                qDebug() << "Set default account as active in RisipCallManager";
            }

            // Connect account status signals (same as in registerAccount)
            connect(d->currentAccount, &risip::RisipAccount::statusChanged, this, [this]() {
                int status = d->currentAccount->status();
                qDebug() << "Account status changed:" << status << "(" << d->currentAccount->statusText() << ")";

                if (status == risip::RisipAccount::SignedIn) {
                    d->registered = true;
                    emit isRegisteredChanged(true);
                    emit registrationSuccess();
                    updateServerStatus(QString("已连接: %1").arg(d->currentAccount->configuration()->uri()));
                    qDebug() << "Account registered successfully";
                } else if (status == risip::RisipAccount::SignedOut || status == risip::RisipAccount::AccountError) {
                    d->registered = false;
                    emit isRegisteredChanged(false);
                    QString reason = d->currentAccount->statusText();
                    emit registrationFailed(reason);
                    updateServerStatus("注册失败: " + reason);
                    qDebug() << "Registration failed:" << status << reason;
                }
            });

            // Auto-login if autoSignIn is enabled
            if (defaultAccount->autoSignIn()) {
                qDebug() << "Auto-login enabled, starting registration...";

                // ✅ CRITICAL FIX: Do NOT configure video device before login()
                // The PJSIP account is created during login(), so video config must happen AFTER
                // We'll configure video device after successful registration via signal handler

                d->currentAccount->login();
                updateServerStatus("正在注册到: " + defaultAccount->configuration()->uri());

                // ✅ NEW: Configure video device AFTER login() initiates account creation
                // Wait a bit for PJSIP account creation to complete
                QTimer::singleShot(100, this, [this, defaultAccount]() {
                    QString accountUri = defaultAccount->configuration()->uri();
                    qDebug() << "✅ Configuring video device AFTER login initiation:" << accountUri;
                    configureAccountVideoDevice(accountUri);
                });
            } else {
                qDebug() << "Auto-login disabled for this account";
                updateServerStatus("账户已加载,未自动登录");
            }
        } else {
            qDebug() << "No default account found - user needs to configure";
        }
    } else {
        qDebug() << "Configs files cannot be found nor be read!!";
        qDebug() << "Creating default SIP accounts...";

        // 创建默认账户1: 1001@192.168.10.243 (主服务器)
        QString account1_username = "1001";
        QString account1_password = "1234";
        QString account1_server = "192.168.10.243";
        QString account1_uri = QString("sip:%1@%2").arg(account1_username, account1_server);

        qDebug() << "Creating default account 1:" << account1_uri;
        registerAccount(account1_username, account1_password, account1_server);

        // 设置为默认账户并自动登录
        setAsDefaultAccount(account1_uri);

        // 创建默认账户2: 1001@192.168.1.9 (备用服务器)
        QString account2_username = "1001";
        QString account2_password = "1234";
        QString account2_server = "192.168.1.9";
        QString account2_uri = QString("sip:%1@%2").arg(account2_username, account2_server);

        qDebug() << "Creating default account 2:" << account2_uri;
        // Note: Don't call registerAccount again, just add the account configuration
        risip::RisipAccountConfiguration cfg;
        cfg.setUri(account2_uri);
        cfg.setUserName(account2_username);
        cfg.setPassword(account2_password);
        cfg.setServerAddress(account2_server);

        // ⚠️ 2026-01-04 强制使用TCP传输（与主账户一致）
        cfg.setNetworkProtocol(1);  // 强制TCP (0=UDP, 1=TCP, 2=TLS)
        qDebug() << "🔧 [TCP TRANSPORT] Forced TCP for account 2 (backup account)";

        risip::RisipAccount *account2 = d->risipInstance->createAccount(&cfg);
        if (account2) {
            qDebug() << "✅ Default account 2 created (backup, no auto-login):" << account2_uri;
        } else {
            qWarning() << "Failed to create default account 2";
        }

        // 保存配置
        d->risipInstance->saveSettings();
        qDebug() << "✅ Default accounts created and saved";

        emit accountsModelChanged();
    }

    // ✅ 2026-01-18 12:00 [FIX 100.246] PJSIP 初始化成功后枚举设备并发射信号
    // 原因：QML 通过 property 绑定监听这些信号，PJSIP 初始化完成后才更新设备列表
    // 时机：必须在 PJSIP endpoint 启动且视频子系统初始化之后
    qDebug() << "";
    qDebug() << "════════════════════════════════════════════════════════════";
    qDebug() << "📱 [FIX 100.246] Enumerating devices after PJSIP initialization";
    qDebug() << "════════════════════════════════════════════════════════════";

    // Enumerate audio input devices
    d->cachedAudioInputDevices = getAudioInputDevices();
    qDebug() << "✅ Audio input devices enumerated:" << d->cachedAudioInputDevices.count();
    emit audioInputDevicesChanged(d->cachedAudioInputDevices);

    // Enumerate audio output devices
    d->cachedAudioOutputDevices = getAudioOutputDevices();
    qDebug() << "✅ Audio output devices enumerated:" << d->cachedAudioOutputDevices.count();
    emit audioOutputDevicesChanged(d->cachedAudioOutputDevices);

    // Enumerate video devices
    d->cachedVideoDevices = getVideoDevices();
    qDebug() << "✅ Video devices enumerated:" << d->cachedVideoDevices.count();
    emit videoDevicesChanged(d->cachedVideoDevices);

    qDebug() << "════════════════════════════════════════════════════════════";
    qDebug() << "📱 [FIX 100.246] All devices enumerated, signals emitted to QML";
    qDebug() << "════════════════════════════════════════════════════════════";
    qDebug() << "";

    return true;
}


void SipPhoneManager::shutdownEndpoint()
{
    if (!d->initialized) {
        return;
    }

    qDebug() << "Shutting down SIP endpoint...";

    // Stop any active call
    if (d->inCall) {
        hangupCall();
    }

    // Unregister account
    if (d->registered) {
        unregisterAccount();
    }

    // The Risip singleton handles endpoint cleanup internally
    d->initialized = false;
    emit isInitializedChanged(false);
    updateServerStatus("未连接");
    qDebug() << "SIP endpoint shutdown complete";
}

// ✅ 2026-01-01 22:45 [调试] 实现PJSIP日志级别控制
// 目的：在运行时动态设置PJSIP日志级别，用于诊断视频接收失败问题
void SipPhoneManager::setPjsipLogLevel(int level)
{
    pj_log_set_level(level);
    qDebug() << "✅ PJSIP log level set to" << level << "(0=disabled, 5=maximum debug)";
}

// Account management
bool SipPhoneManager::registerAccount(const QString &sipServer,
                                     const QString &username,
                                     const QString &password,
                                     int port)
{
    // ✅ 2026-01-18 11:30 [DEBUG] 添加调用时机追踪
    qDebug() << "════════════════════════════════════════════════════════════";
    qDebug() << "🔥🔥🔥 [ENTRY] registerAccount() called!";
    qDebug() << "   [TIMING] Called at:" << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz");
    qDebug() << "   [PARAMS] Server:" << sipServer << "Port:" << port;
    qDebug() << "   [PARAMS] Username:" << username;
    qDebug() << "   [STATE] d->initialized =" << d->initialized;
    qDebug() << "   [STATE] d->risipInstance =" << (d->risipInstance ? "EXISTS" : "NULL");
    qDebug() << "════════════════════════════════════════════════════════════";

    if (!d->initialized) {
        qDebug() << "Cannot register: endpoint not initialized";
        emit errorOccurred("SIP引擎未初始化");
        return false;
    }

    qDebug() << "Registering account:" << username << "@" << sipServer << ":" << port;

    try {
        // Create account configuration
        risip::RisipAccountConfiguration *config = new risip::RisipAccountConfiguration(this);

        // Build SIP URI: sip:username@server
        QString sipUri = QString("sip:%1@%2").arg(username, sipServer);
        config->setUri(sipUri);
        config->setUserName(username);
        config->setPassword(password);

        // Set registrar server address with port
        QString serverWithPort = port == 5060 ? sipServer : QString("%1:%2").arg(sipServer).arg(port);
        config->setServerAddress(serverWithPort);

        // ⚠️ 2026-01-04 强制使用TCP传输：避免UDP分片问题
        // miniSIP服务器不支持UDP分片（违反RFC 3261），TCP可以绕过此限制
        config->setNetworkProtocol(1);  // 强制TCP (0=UDP, 1=TCP, 2=TLS)
        qDebug() << "🔧 [TCP TRANSPORT] Forced TCP transport for registerAccount (miniSIP UDP fragmentation workaround)";

        // ✅ CRITICAL FIX: Set video capture device in AccountConfig BEFORE creating account
        // Following PJSIP official example approach: set vid_cap_dev before pjsua_acc_add()
        try {
            AccountConfig pjsipAccCfg = config->pjsipAccountConfig();
            pjsipAccCfg.videoConfig.defaultCaptureDevice = 0;  // Device 0 = Integrated Webcam
            pjsipAccCfg.videoConfig.defaultRenderDevice = PJMEDIA_VID_DEFAULT_RENDER_DEV;  // ✅ 必须保留渲染设备以接收远程视频
            config->setPjsipAccountConfig(pjsipAccCfg);
            qDebug() << "✅ Set video capture device to 0 in AccountConfig before account creation";
        } catch (const std::exception &ex) {
            qWarning() << "Failed to set video config in AccountConfig:" << ex.what();
        }

        // Create and register account
        d->currentAccount = d->risipInstance->createAccount(config);

        if (!d->currentAccount) {
            qDebug() << "Failed to create account";
            emit errorOccurred("创建账户失败");
            delete config;
            return false;
        }

        // Enable auto sign-in for automatic login on app restart
        d->currentAccount->setAutoSignIn(true);
        qDebug() << "Enabled auto sign-in for account";

        // Connect account status signals
        connect(d->currentAccount, &risip::RisipAccount::statusChanged, this, [this]() {
            int status = d->currentAccount->status();
            qDebug() << "Account status changed:" << status << "(" << d->currentAccount->statusText() << ")";

            if (status == risip::RisipAccount::SignedIn) {
                d->registered = true;
                emit isRegisteredChanged(true);
                emit registrationSuccess();
                updateServerStatus(QString("已连接: %1").arg(d->currentAccount->configuration()->uri()));
                qDebug() << "Account registered successfully";
            } else if (status == risip::RisipAccount::SignedOut || status == risip::RisipAccount::AccountError) {
                d->registered = false;
                emit isRegisteredChanged(false);
                QString reason = d->currentAccount->statusText();
                emit registrationFailed(reason);
                updateServerStatus("注册失败: " + reason);
                qDebug() << "Registration failed:" << status << reason;
            }
        });

        // Set as active account in RisipCallManager (CRITICAL for incoming calls!)
        risip::RisipCallManager *callManager = risip::RisipCallManager::instance();
        if (callManager) {
            callManager->setActiveAccount(d->currentAccount);
            qDebug() << "Set account as active in RisipCallManager";
        }

        // Set as default account in Risip (CRITICAL for persistence!)
        // This must be done BEFORE saveSettings() to ensure correct URI is saved
        d->risipInstance->setDefaultAccount(sipUri);
        qDebug() << "Set as default account:" << sipUri;

        // Start registration
        d->currentAccount->login();

        // Save account configuration to QSettings
        qDebug() << "Saving account configuration to QSettings...";
        if (d->risipInstance->saveSettings()) {
            qDebug() << "Account configuration saved successfully";

            // CRITICAL: Emit signal to notify QML that a new account was added to the model
            emit accountsModelChanged();
            qDebug() << "Emitted accountsModelChanged() after adding new account";
        } else {
            qWarning() << "Failed to save account configuration";
        }

        qDebug() << "Account registration initiated";
        return true;

    } catch (const std::exception &ex) {
        QString error = QString("注册异常: %1").arg(ex.what());
        qDebug() << error;
        emit registrationFailed(error);
        return false;
    } catch (...) {
        qDebug() << "Unknown error during registration";
        emit registrationFailed("未知错误");
        return false;
    }
}

// Create new account (like Risip.createAccount in risipapp)
bool SipPhoneManager::createAccount(const QString &username,
                                   const QString &password,
                                   const QString &serverAddress,
                                   const QString &proxyServer,
                                   int localPort,
                                   int networkProtocol)
{
    if (!d->initialized) {
        qDebug() << "Cannot create account: endpoint not initialized";
        emit errorOccurred("SIP引擎未初始化");
        return false;
    }

    qDebug() << "Creating new account:" << username << "@" << serverAddress;

    try {
        // Create account configuration (similar to risipapp's AddSipAccountPage)
        risip::RisipAccountConfiguration *config = new risip::RisipAccountConfiguration(this);

        // Build SIP URI: sip:username@server
        QString sipUri = QString("sip:%1@%2").arg(username, serverAddress);
        config->setUri(sipUri);
        config->setUserName(username);
        config->setPassword(password);
        config->setServerAddress(serverAddress);

        // Set proxy server if provided
        if (!proxyServer.isEmpty()) {
            config->setProxyServer(proxyServer);
        }

        // Set local port and network protocol
        config->setLocalPort(localPort);
        config->setRandomLocalPort(localPort);  // Use same port

        // ⚠️ 2026-01-04 强制使用TCP传输：避免UDP分片问题
        // miniSIP服务器不支持UDP分片（违反RFC 3261），UDP INVITE 1583字节 > MTU 1500导致分片被拒绝
        // 解决：强制使用TCP传输（TCP自动分段，无MTU限制）
        // 参考：docs/2026-01-04/4.TCP传输配置方案.md
        config->setNetworkProtocol(1);  // 强制TCP (0=UDP, 1=TCP, 2=TLS)
        qDebug() << "🔧 [TCP TRANSPORT] Forced TCP transport for account (miniSIP UDP fragmentation workaround)";

        // config->setNetworkProtocol(networkProtocol);  // ← 原代码：使用参数值（已禁用）

        // ✅ CRITICAL FIX: Set video capture device in AccountConfig BEFORE creating account
        // Following PJSIP official example approach: set vid_cap_dev before pjsua_acc_add()
        try {
            AccountConfig pjsipAccCfg = config->pjsipAccountConfig();
            pjsipAccCfg.videoConfig.defaultCaptureDevice = 0;  // Device 0 = Integrated Webcam
            pjsipAccCfg.videoConfig.defaultRenderDevice = PJMEDIA_VID_DEFAULT_RENDER_DEV;  // ✅ 必须保留渲染设备以接收远程视频
            config->setPjsipAccountConfig(pjsipAccCfg);
            qDebug() << "✅ Set video capture device to 0 in AccountConfig before account creation";
        } catch (const std::exception &ex) {
            qWarning() << "Failed to set video config in AccountConfig:" << ex.what();
        }

        // Create account using Risip
        risip::RisipAccount *newAccount = d->risipInstance->createAccount(config);

        if (!newAccount) {
            qDebug() << "Failed to create account";
            emit errorOccurred("创建账户失败");
            delete config;
            return false;
        }

        qDebug() << "Account created successfully:" << sipUri;

        // Enable auto sign-in
        newAccount->setAutoSignIn(true);

        // Save configuration to persist the account
        if (d->risipInstance->saveSettings()) {
            qDebug() << "Account configuration saved";
            // Notify QML that accounts model has changed
            emit accountsModelChanged();
        } else {
            qWarning() << "Failed to save account configuration";
        }

        return true;

    } catch (const std::exception &ex) {
        QString error = QString("创建账户异常: %1").arg(ex.what());
        qDebug() << error;
        emit errorOccurred(error);
        return false;
    } catch (...) {
        qDebug() << "Unknown error during account creation";
        emit errorOccurred("未知错误");
        return false;
    }
}

void SipPhoneManager::unregisterAccount()
{
    if (!d->registered || !d->currentAccount) {
        return;
    }

    qDebug() << "Unregistering account...";

    // ❌ PROBLEM: logout() causes RisipAccount to delete pjsipAccount, leading to crash
    // ✅ SOLUTION: Just clear the current account reference without calling logout()
    // The account remains in the saved list and can be logged in again later

    QString accountUri = d->currentAccount->configuration()->uri();
    qDebug() << "Clearing current account reference for:" << accountUri;

    // Simply clear the current account reference
    // Do NOT call logout() - it triggers pjsipAccount deletion and crash
    // Do NOT call removeAccount() - user wants to keep it saved
    d->currentAccount = nullptr;

    d->registered = false;
    emit isRegisteredChanged(false);
    updateServerStatus("已断开连接");

    qDebug() << "Account reference cleared (account still saved in list)";
    qDebug() << "Note: Account" << accountUri << "is still registered with SIP server";
    qDebug() << "To properly logout, select and re-login the account next time";
}

// Multi-account management methods
QObject* SipPhoneManager::getAllAccountsModel()
{
    if (d->risipInstance) {
        QObject* model = d->risipInstance->allAccountsModel();
        if (model) {
            // Debug: Check model row count
            QAbstractItemModel* itemModel = qobject_cast<QAbstractItemModel*>(model);
            if (itemModel) {
                int count = itemModel->rowCount();
                qDebug() << "[DEBUG] getAllAccountsModel() returning model with" << count << "accounts";

                // Debug: Print all accounts in the model
                for (int i = 0; i < count; ++i) {
                    QModelIndex index = itemModel->index(i, 0);
                    QString uri = itemModel->data(index, Qt::UserRole + 1).toString();
                    QString serverAddr = itemModel->data(index, Qt::UserRole + 6).toString();
                    bool isDefault = itemModel->data(index, Qt::UserRole + 7).toBool();
                    qDebug() << "  Account" << i << ":" << uri << "Server:" << serverAddr << "Default:" << isDefault;
                }
            } else {
                qDebug() << "[DEBUG] getAllAccountsModel() model is not QAbstractItemModel!";
            }
        } else {
            qDebug() << "[DEBUG] getAllAccountsModel() allAccountsModel() returned nullptr!";
        }
        return model;
    }
    qDebug() << "[DEBUG] getAllAccountsModel() risipInstance is null!";
    return nullptr;
}

bool SipPhoneManager::removeAccount(const QString &accountUri)
{
    if (!d->risipInstance) {
        qWarning() << "Cannot remove account: Risip instance not initialized";
        return false;
    }

    qDebug() << "Removing account:" << accountUri;
    bool success = d->risipInstance->removeAccount(accountUri);

    if (success) {
        // Save settings after removing account
        d->risipInstance->saveSettings();
        qDebug() << "Account removed and settings saved";
    } else {
        qWarning() << "Failed to remove account:" << accountUri;
    }

    return success;
}

bool SipPhoneManager::setAsDefaultAccount(const QString &accountUri)
{
    if (!d->risipInstance) {
        qWarning() << "Cannot set default account: Risip instance not initialized";
        return false;
    }

    qDebug() << "Setting default account:" << accountUri;
    d->risipInstance->setDefaultAccount(accountUri);

    // Save settings after changing default
    if (d->risipInstance->saveSettings()) {
        qDebug() << "Default account set and settings saved";
        return true;
    } else {
        qWarning() << "Failed to save settings after setting default account";
        return false;
    }
}

bool SipPhoneManager::loginExistingAccount(const QString &accountUri)
{
    if (!d->initialized || !d->risipInstance) {
        qWarning() << "Cannot login: Risip instance not initialized";
        emit errorOccurred("SIP引擎未初始化");
        return false;
    }

    qDebug() << "Logging in to existing account:" << accountUri;

    // ✅ Use accountForUri() to get the account directly
    risip::RisipAccount *account = d->risipInstance->accountForUri(accountUri);
    if (!account) {
        qWarning() << "Account not found:" << accountUri;
        emit errorOccurred("账户不存在: " + accountUri);
        return false;
    }

    if (!account->configuration()) {
        qWarning() << "Account configuration is null for:" << accountUri;
        emit errorOccurred("账户配置无效: " + accountUri);
        return false;
    }

    qDebug() << "Found account, checking if already logged in...";

    // If already logged in to this account, no need to do anything
    if (d->currentAccount && d->currentAccount->configuration()->uri() == accountUri) {
        if (d->currentAccount->status() == risip::RisipAccount::SignedIn) {
            qDebug() << "Already logged in to this account";
            return true;
        }
    }

    // If logged in to a different account, logout first
    if (d->currentAccount && d->currentAccount->status() == risip::RisipAccount::SignedIn) {
        qDebug() << "Logging out from current account:" << d->currentAccount->configuration()->uri();
        d->currentAccount->logout();
        d->registered = false;
        emit isRegisteredChanged(false);
    }

    // Set as current account
    d->currentAccount = account;

    // Connect account status signals if not already connected
    // Disconnect any previous connections to avoid duplicate signals
    disconnect(d->currentAccount, &risip::RisipAccount::statusChanged, this, nullptr);

    connect(d->currentAccount, &risip::RisipAccount::statusChanged, this, [this]() {
        if (!d->currentAccount) return;

        int status = d->currentAccount->status();
        qDebug() << "Account status changed:" << status << "(" << d->currentAccount->statusText() << ")";

        if (status == risip::RisipAccount::SignedIn) {
            d->registered = true;
            emit isRegisteredChanged(true);
            emit registrationSuccess();
            updateServerStatus(QString("已连接: %1").arg(d->currentAccount->configuration()->uri()));
            qDebug() << "Account logged in successfully";
        } else if (status == risip::RisipAccount::SignedOut || status == risip::RisipAccount::AccountError) {
            d->registered = false;
            emit isRegisteredChanged(false);
            QString reason = d->currentAccount->statusText();
            emit registrationFailed(reason);
            updateServerStatus("登录失败: " + reason);
            qDebug() << "Login failed:" << status << reason;
        }
    });

    // Set as active account in RisipCallManager
    risip::RisipCallManager *callManager = risip::RisipCallManager::instance();
    if (callManager) {
        callManager->setActiveAccount(d->currentAccount);
        qDebug() << "Set account as active in RisipCallManager";
    }

    // ✅ CRITICAL: Configure video device for this account BEFORE login
    configureAccountVideoDevice(accountUri);

    // Start login
    qDebug() << "Starting login for account:" << accountUri;
    d->currentAccount->login();
    updateServerStatus("正在登录: " + accountUri);

    return true;
}

// Call history management
QObject* SipPhoneManager::getCallHistoryModel()
{
    risip::RisipCallManager *callManager = risip::RisipCallManager::instance();
    if (!callManager) {
        qWarning() << "Call manager not available";
        return nullptr;
    }

    if (!d->currentAccount) {
        qWarning() << "No active account - cannot get call history";
        return nullptr;
    }

    // Get the call history model for the current account
    QString accountUri = d->currentAccount->configuration()->uri();
    QAbstractItemModel *historyModel = callManager->historyCallModelForAccount(accountUri);

    if (historyModel) {
        qDebug() << "Retrieved call history model for account:" << accountUri;
    } else {
        qWarning() << "No call history model found for account:" << accountUri;
    }

    return historyModel;
}

void SipPhoneManager::deleteCallHistoryRecord(int index)
{
    qDebug() << "🗑️ Deleting call history record at index:" << index;

    risip::RisipCallManager *callManager = risip::RisipCallManager::instance();
    if (!callManager) {
        qWarning() << "Call manager not available";
        return;
    }

    if (!d->currentAccount) {
        qWarning() << "No active account - cannot delete call history";
        return;
    }

    // Get the call history model for the current account
    QString accountUri = d->currentAccount->configuration()->uri();
    QAbstractItemModel *historyModel = callManager->historyCallModelForAccount(accountUri);

    if (!historyModel) {
        qWarning() << "No call history model found for account:" << accountUri;
        return;
    }

    // Cast to RisipCallHistoryModel to access removeRecordAtIndex
    risip::RisipCallHistoryModel *callHistoryModel = qobject_cast<risip::RisipCallHistoryModel*>(historyModel);
    if (!callHistoryModel) {
        qWarning() << "Failed to cast to RisipCallHistoryModel";
        return;
    }

    callHistoryModel->removeRecordAtIndex(index);
    qDebug() << "✅ Call history record deleted successfully";
}

// Call control - Internal helper with video support
void SipPhoneManager::makeCall(const QString &number, bool enableVideo)
{
    if (!d->registered || !d->currentAccount) {
        qDebug() << "Cannot make call: not registered";
        emit errorOccurred("未注册到SIP服务器");
        return;
    }

    if (d->inCall) {
        qDebug() << "Already in a call";
        emit errorOccurred("当前正在通话中");
        return;
    }

    qDebug() << "✅ Making call to:" << number << (enableVideo ? "(Video)" : "(Audio only)");

    // ✅ 查询联系人名字，优先显示联系人名字
    QString contactName = risip::ContactDatabase::instance()->getContactName(number);
    QString displayName = contactName.isEmpty() ? number : contactName;

    qDebug() << "📇 Outgoing call - Number:" << number << "Display:" << displayName;

    // 保存显示名供后续使用
    setCallerDisplayName(displayName);

    try {
        // Get call manager
        risip::RisipCallManager *callManager = risip::RisipCallManager::instance();
        if (!callManager) {
            qDebug() << "Call manager not available";
            emit errorOccurred("呼叫管理器未就绪");
            return;
        }

        // Set active account for call manager
        callManager->setActiveAccount(d->currentAccount);

        // ✅ CRITICAL: Ensure account's video device configuration is applied BEFORE making call
        if (enableVideo) {
            QString accountUri = d->currentAccount->configuration()->uri();
            qDebug() << "✅ Refreshing video device configuration before call for:" << accountUri;
            configureAccountVideoDevice(accountUri);

            if (d->videoCallManager) {
                pjmedia_vid_dev_index realCaptureDevice = d->videoCallManager->getCaptureDeviceId();
                qDebug() << "✅ Account configured with capture device:" << realCaptureDevice << "(from VideoCallManager)";
            } else {
                qWarning() << "⚠️ VideoCallManager not available, video may fail!";
            }
        }

        // ⭐ 完全重构：统一使用 Risip API（视频 + 语音）
        // 不再使用直接 PJSIP 调用，改用 Risip 的统一接口
        qDebug() << "📞 Creating call using unified Risip API, video =" << enableVideo;
        d->currentCall = callManager->callPhoneWithVideo(number, enableVideo);  // ⭐ 统一 API

        if (!d->currentCall) {
            qDebug() << "❌ Failed to create call";
            emit callFailed("创建呼叫失败");
            return;
        }

        // ✅ 调试：检查 callDirection 是否正确设置
        int direction = d->currentCall->callDirection();
        qDebug() << "🔍 通话创建后 callDirection =" << direction
                 << "(0=Outgoing, 1=Incoming, 2=Unknown), video =" << enableVideo;

        setCurrentNumber(number);
        updateCallStatus(enableVideo ? QString("视频拨号: %1").arg(displayName) : QString("呼叫 %1").arg(displayName));

        // ✅ Set current call video flag
        d->isCurrentCallVideo = enableVideo;
        emit isCurrentCallVideoChanged(enableVideo);

        // Connect call status signals (works for both video and audio calls)
        connect(d->currentCall, &risip::RisipCall::statusChanged, this, [this, enableVideo]() {
            handleCallStatusChange(enableVideo);  // Pass video flag
        });

        qDebug() << "✅ Call initiated via unified Risip API, video =" << enableVideo;

    } catch (const std::exception &ex) {
        QString error = QString("呼叫异常: %1").arg(ex.what());
        qDebug() << error;
        emit callFailed(error);
    } catch (...) {
        qDebug() << "Unknown error making call";
        emit callFailed("未知错误");
    }
}

// Helper function to handle call status changes (extracted for reuse)
void SipPhoneManager::handleCallStatusChange(bool isVideoCall)
{
    qDebug() << "🔔 [SipPhoneManager] handleCallStatusChange() called, isVideoCall:" << isVideoCall;

    if (!d->currentCall) {
        qDebug() << "Call status changed but currentCall is null, ignoring";
        return;
    }

    qDebug() << "🔔 [SipPhoneManager] Calling d->currentCall->status()...";
    int callState = d->currentCall->status();
    qDebug() << "🔔 [SipPhoneManager] status() returned, callState:" << callState;

    // Call states from Risip::RisipCall::Status
    // CallConfirmed = 4 (call connected)
    // CallDisconnected = 5 (call ended)
    // CallEarly = 6 (ringing)

    if (callState == risip::RisipCall::CallConfirmed) {
        d->inCall = true;
        emit isInCallChanged(true);
        emit callConnected();
        d->callDuration = 0;
        d->callTimer->start();
        qDebug() << "Call connected";
        qDebug() << "📇 [CALL STATUS] callerDisplayName:" << d->callerDisplayName << "isVideoCall:" << isVideoCall;

        // ✅ Video encoder starts automatically via vid_out_auto_transmit = PJ_TRUE config
        // ✅ Audio ports connect automatically via onCallMediaStateCallback() for ALL calls
        // No manual intervention needed - the official PJSIP callback mechanism handles everything

        // For video calls, video was already included in initial INVITE
        // No need to add it via re-INVITE
        QString statusText = isVideoCall ?
            QString("视频通话中: %1").arg(d->callerDisplayName) :
            QString("与 %1 通话中").arg(d->callerDisplayName);
        updateCallStatus(statusText);
        qDebug() << "📇 [CALL STATUS] Status text:" << statusText;

    } else if (callState == risip::RisipCall::CallDisconnected) {
        // Remote party hung up - clean up call state
        qDebug() << "Remote party disconnected, cleaning up...";
        d->callTimer->stop();

        // ✅ CRITICAL: 在通话结束前缓存时长到 RisipCall 对象
        // 因为 PJSIP 会话销毁后，callDuration() 将返回 0
        if (d->currentCall) {
            long duration = d->currentCall->callDuration();
            if (duration > 0) {
                d->currentCall->setProperty("cachedDuration", QVariant::fromValue(duration));
                qDebug() << "✅ 通话结束，缓存时长:" << duration << "ms (" << (duration/1000) << "s)";
            } else {
                qDebug() << "⚠️ 通话结束，但时长为 0，可能通话未真正建立";
            }
        }

        d->currentCall = nullptr;
        d->inCall = false;
        emit isInCallChanged(false);
        emit callDisconnected();
        updateCallStatus("就绪");
        d->callDuration = 0;
        emit callDurationChanged(0);
    } else if (callState == risip::RisipCall::CallEarly) {
        updateCallStatus(QString("%1 振铃中").arg(d->callerDisplayName));
    } else if (callState == risip::RisipCall::IncomingCallStarted) {
        updateCallStatus("来电");
        qDebug() << "Incoming call";
    } else if (callState == risip::RisipCall::OutgoingCallStarted) {
        QString statusText = isVideoCall ?
            QString("视频拨号: %1").arg(d->callerDisplayName) :
            QString("呼叫 %1").arg(d->callerDisplayName);
        updateCallStatus(statusText);
        qDebug() << "Outgoing call started";
    } else if (callState == risip::RisipCall::Null) {
        // Call returned to Null state after disconnect
        qDebug() << "Call state returned to Null, cleaning up...";
        d->callTimer->stop();

        // ✅ CRITICAL: 在通话结束前缓存时长到 RisipCall 对象
        // 因为 PJSIP 会话销毁后，callDuration() 将返回 0
        if (d->currentCall) {
            long duration = d->currentCall->callDuration();
            if (duration > 0) {
                d->currentCall->setProperty("cachedDuration", QVariant::fromValue(duration));
                qDebug() << "✅ 通话结束（Null状态），缓存时长:" << duration << "ms (" << (duration/1000) << "s)";
            } else {
                qDebug() << "⚠️ 通话结束（Null状态），但时长为 0";
            }
        }

        d->currentCall = nullptr;
        d->inCall = false;
        emit isInCallChanged(false);
        emit callDisconnected();
        updateCallStatus("就绪");
        d->callDuration = 0;
        emit callDurationChanged(0);
    }
}

// Extract phone number from various contact string formats
// Examples:
//   "Extension 1006" 1006 -> 1006
//   "\"Extension 1006\" 1006" -> 1006
//   sip:1006@server -> 1006
//   1006 -> 1006
QString SipPhoneManager::extractPhoneNumber(const QString &contact)
{
    if (contact.isEmpty()) {
        return contact;
    }

    // Try to extract number from SIP URI (sip:1006@server or <sip:1006@server>)
    QRegularExpression sipRegex(R"(sip:(\d+)@)");
    QRegularExpressionMatch match = sipRegex.match(contact);
    if (match.hasMatch()) {
        QString number = match.captured(1);
        qDebug() << "📇 [EXTRACT] From SIP URI:" << contact << "-> Number:" << number;
        return number;
    }

    // Try to extract number from "Extension XXXX" XXXX format
    // Match: any text followed by space and then pure digits at the end
    QRegularExpression extRegex(R"(\s+(\d+)\s*$)");
    match = extRegex.match(contact);
    if (match.hasMatch()) {
        QString number = match.captured(1);
        qDebug() << "📇 [EXTRACT] From Extension format:" << contact << "-> Number:" << number;
        return number;
    }

    // If it's just a plain number, return as is
    QRegularExpression numberRegex(R"(^\d+$)");
    if (numberRegex.match(contact).hasMatch()) {
        qDebug() << "📇 [EXTRACT] Pure number:" << contact;
        return contact;
    }

    // Otherwise return the original (fallback)
    qDebug() << "⚠️ [EXTRACT] Could not extract number from:" << contact << "- using as-is";
    return contact;
}

// Public methods - Audio-only call
void SipPhoneManager::makeCall(const QString &number)
{
    makeCall(number, false);  // Audio only
}

// Public methods - Video call
void SipPhoneManager::makeVideoCall(const QString &number)
{
    makeCall(number, true);  // Audio + Video
}

void SipPhoneManager::answerCall()
{
    qDebug() << "✅ answerCall() called, isIncomingVideoCall:" << d->isIncomingVideoCall;

    // ✅ CRITICAL FIX: Check if this is a video call FIRST
    // If it's a video call, we MUST use PJSIP C API with vid_cnt=1
    // Even if d->currentCall exists (it's set for all incoming calls)
    if (d->isIncomingVideoCall) {
        qDebug() << "✅ Answering incoming VIDEO call with PJSIP C API (vid_cnt=1)...";

        // ✅ CRITICAL: Refresh account video configuration BEFORE answering
        // This ensures vid_cap_dev and vid_out_auto_transmit are correctly set
        if (d->currentAccount && d->currentAccount->configuration()) {
            QString accountUri = d->currentAccount->configuration()->uri();
            qDebug() << "✅ Refreshing video config before answering for account:" << accountUri;
            configureAccountVideoDevice(accountUri);
        }

        // Find the incoming call
        pjsua_call_id call_ids[PJSUA_MAX_CALLS];
        unsigned count = PJ_ARRAY_SIZE(call_ids);
        pj_status_t status = pjsua_enum_calls(call_ids, &count);

        if (status == PJ_SUCCESS && count > 0) {
            for (unsigned i = 0; i < count; ++i) {
                pjsua_call_info ci;
                status = pjsua_call_get_info(call_ids[i], &ci);

                if (status == PJ_SUCCESS && ci.state == PJSIP_INV_STATE_INCOMING) {
                    // ✅ DIAGNOSTIC: Check video codec availability and remote SDP BEFORE answering
                    qDebug() << "📹 [VIDEO CODEC CHECK] Checking video codec configuration...";

                    // Check available video codecs and their priorities
                    pjsua_codec_info codec_info[32];
                    unsigned codec_count = PJ_ARRAY_SIZE(codec_info);
                    status = pjsua_vid_enum_codecs(codec_info, &codec_count);

                    if (status == PJ_SUCCESS) {
                        qDebug() << "📹 [VIDEO CODEC CHECK] Found" << codec_count << "video codecs:";
                        for (unsigned j = 0; j < codec_count; ++j) {
                            pj_str_t codec_id = codec_info[j].codec_id;
                            QString codecName = QString::fromUtf8(codec_id.ptr, codec_id.slen);
                            qDebug() << "  Codec" << j << ":" << codecName
                                     << "Priority:" << codec_info[j].priority;
                        }
                    } else {
                        qWarning() << "❌ Failed to enumerate video codecs";
                    }

                    // Check the INVITE message body for offered codecs
                    qDebug() << "📹 [VIDEO CODEC CHECK] Checking call media info...";
                    qDebug() << "  Call has" << ci.media_cnt << "media streams at INCOMING state";

                    // Also check account video configuration
                    if (d->currentAccount) {
                        QString accountUri = d->currentAccount->configuration()->uri();

                        // Find the account ID
                        pjsua_acc_id acc_ids_check[10];
                        unsigned acc_count = PJ_ARRAY_SIZE(acc_ids_check);
                        pj_status_t acc_status = pjsua_enum_accs(acc_ids_check, &acc_count);

                        if (acc_status == PJ_SUCCESS && acc_count > 0) {
                            for (unsigned a = 0; a < acc_count; ++a) {
                                pjsua_acc_info accInfo;
                                acc_status = pjsua_acc_get_info(acc_ids_check[a], &accInfo);
                                if (acc_status == PJ_SUCCESS) {
                                    QString accUri = QString::fromUtf8(accInfo.acc_uri.ptr, accInfo.acc_uri.slen);
                                    if (accUri == accountUri) {
                                        qDebug() << "📹 [ACCOUNT CHECK] Found account" << acc_ids_check[a];

                                        // Get account config to check video device
                                        pj_pool_t *pool = pjsua_pool_create("tmp-check", 512, 512);
                                        if (pool) {
                                            pjsua_acc_config acc_cfg;
                                            pjsua_acc_config_default(&acc_cfg);
                                            acc_status = pjsua_acc_get_config(acc_ids_check[a], pool, &acc_cfg);

                                            if (acc_status == PJ_SUCCESS) {
                                                qDebug() << "  vid_cap_dev:" << acc_cfg.vid_cap_dev;
                                                qDebug() << "  vid_rend_dev:" << acc_cfg.vid_rend_dev;
                                                qDebug() << "  vid_in_auto_show:" << acc_cfg.vid_in_auto_show;
                                                qDebug() << "  vid_out_auto_transmit:" << acc_cfg.vid_out_auto_transmit;
                                            }
                                            pj_pool_release(pool);
                                        }
                                        break;
                                    }
                                }
                            }
                        }
                    }

                    // Found incoming call, answer with video
                    pjsua_call_setting call_opt;
                    pjsua_call_setting_default(&call_opt);

                    // ✅ NEW APPROACH: Answer with video AFTER ensuring encoder is initialized
                    // Previous issues:
                    //   1. Answering with vid_cnt=1 directly → video port=0 (encoder not ready)
                    //   2. Answering with vid_cnt=0 then re-INVITE → payload type mismatch (new offer)
                    // Solution: Initialize video encoder BEFORE answering with vid_cnt=1
                    qDebug() << "📹 [VIDEO CALL] Initializing video encoder before answering...";

                    // ✅ CRITICAL: Get the negotiated video payload type from the incoming INVITE
                    // We need to check what payload type the remote is offering so we can match it
                    pjsua_call_info call_info;
                    if (pjsua_call_get_info(call_ids[i], &call_info) == PJ_SUCCESS) {
                        qDebug() << "📹 Incoming call media_cnt:" << call_info.media_cnt;
                        for (unsigned m = 0; m < call_info.media_cnt; m++) {
                            if (call_info.media[m].type == PJMEDIA_TYPE_VIDEO) {
                                qDebug() << "📹 Video media found at index" << m;
                                qDebug() << "   dir:" << call_info.media[m].dir;
                                qDebug() << "   status:" << call_info.media[m].status;
                            }
                        }
                    }

                    // ✅ DEEP DEBUG MODE: Print everything to understand why vid_cnt=1 fails
                    qDebug() << "";
                    qDebug() << "========================================";
                    qDebug() << "📹 [DEEP DEBUG] INCOMING VIDEO CALL ANSWER";
                    qDebug() << "========================================";
                    qDebug() << "Call ID:" << call_ids[i];

                    // 1. Check video devices
                    unsigned vid_dev_count = pjsua_vid_dev_count();
                    qDebug() << "📹 [1] Video Devices: Total" << vid_dev_count << "devices";
                    for (unsigned v = 0; v < vid_dev_count && v < 5; v++) {
                        pjmedia_vid_dev_info vinfo;
                        if (pjsua_vid_dev_get_info(v, &vinfo) == PJ_SUCCESS) {
                            qDebug() << "   Device" << v << ":" << vinfo.name << "| Dir:" << vinfo.dir;
                        }
                    }

                    // 2. Check video codecs
                    pjsua_codec_info vid_codecs[32];
                    unsigned vid_codec_count = 32;
                    pjsua_vid_enum_codecs(vid_codecs, &vid_codec_count);
                    qDebug() << "📹 [2] Video Codecs:" << vid_codec_count << "available";
                    for (unsigned c = 0; c < vid_codec_count && c < 5; c++) {
                        QString codec_name = QString::fromUtf8(vid_codecs[c].codec_id.ptr, vid_codecs[c].codec_id.slen);
                        qDebug() << "   " << codec_name << "Priority:" << vid_codecs[c].priority;
                    }

                    // 3. Get current call info before answering (includes account ID)
                    pjsua_call_info pre_answer_ci;
                    if (pjsua_call_get_info(call_ids[i], &pre_answer_ci) == PJ_SUCCESS) {
                        pjsua_acc_id acc_id = pre_answer_ci.acc_id;
                        qDebug() << "📹 [3] Account ID:" << acc_id;

                        pjsua_acc_info acc_info;
                        if (pjsua_acc_get_info(acc_id, &acc_info) == PJ_SUCCESS) {
                            qDebug() << "   Account:" << QString::fromUtf8(acc_info.acc_uri.ptr, acc_info.acc_uri.slen);
                        }

                        qDebug() << "📹 [4] Call Info BEFORE Answer:";
                        qDebug() << "   State:" << QString::fromUtf8(pre_answer_ci.state_text.ptr, pre_answer_ci.state_text.slen);
                        qDebug() << "   Media count:" << pre_answer_ci.media_cnt;
                        qDebug() << "   Media status:" << pre_answer_ci.media_status;
                    }

                    // ✅ ATTEMPT 18: Add video stream BEFORE answering
                    // Root cause: PJSIP doesn't create video RTP transport for incoming calls
                    // even with vid_in_auto_show=1 and vid_cnt=1, due to WebRTC RTCP feedback
                    // attributes in remote SDP that PJSIP doesn't recognize.
                    // Solution: Explicitly add video stream before answering
                    qDebug() << "📹 [5] ATTEMPT 18: Adding video stream BEFORE answering";
                    qDebug() << "   This forces PJSIP to create video RTP transport";

                    // First, add video stream to the call
                    pjsua_call_vid_strm_op vid_op = PJSUA_CALL_VID_STRM_ADD;
                    pjsua_call_vid_strm_op_param vid_param;
                    pjsua_call_vid_strm_op_param_default(&vid_param);

                    status = pjsua_call_set_vid_strm(call_ids[i], vid_op, &vid_param);
                    qDebug() << "   pjsua_call_set_vid_strm (ADD) status:" << (status == PJ_SUCCESS ? "SUCCESS" : "FAILED");
                    if (status != PJ_SUCCESS) {
                        char errmsg[PJ_ERR_MSG_SIZE];
                        pj_strerror(status, errmsg, sizeof(errmsg));
                        qDebug() << "   Error:" << errmsg;
                    }

                    // Now answer with video enabled
                    call_opt.vid_cnt = 1;  // VIDEO enabled from the start ✅
                    call_opt.aud_cnt = 1;
                    call_opt.flag = 0;

                    qDebug() << "   Settings: vid_cnt=" << call_opt.vid_cnt
                             << "(VIDEO enabled from start)";

                    // Send normal 200 OK answer
                    status = pjsua_call_answer2(call_ids[i], &call_opt, 200, NULL, NULL);

                    qDebug() << "📹 [6] 200 OK answer status:" << (status == PJ_SUCCESS ? "SUCCESS" : "FAILED");
                    if (status != PJ_SUCCESS) {
                        char errmsg[PJ_ERR_MSG_SIZE];
                        pj_strerror(status, errmsg, sizeof(errmsg));
                        qDebug() << "   Error:" << errmsg;
                    }

                    if (status == PJ_SUCCESS) {
                        // ✅ ATTEMPT 18: Video stream added before answer
                        // This should force PJSIP to create video RTP transport
                        qDebug() << "📹 [7] Video stream added, video transport should be created";

                        // ✅ Don't store pendingVideoActivationCallId - we're not doing re-INVITE
                        // d->pendingVideoActivationCallId = -1;  // Not needed

                        qDebug() << "📹 [8] Video RTP transport should be active now";

                        // ✅ Set current call video flag
                        d->isCurrentCallVideo = true;
                        emit isCurrentCallVideoChanged(true);
                    }
                    qDebug() << "========================================";
                    qDebug() << "";

                    if (status != PJ_SUCCESS) {
                        char errmsg[PJ_ERR_MSG_SIZE];
                        pj_strerror(status, errmsg, sizeof(errmsg));
                        qWarning() << "❌ Failed to answer call:" << errmsg;
                        emit errorOccurred("接听失败");
                    }
                    return;
                }
            }
        }

        qDebug() << "❌ No incoming call found to answer";
        return;
    }

    // ✅ Audio-only call path
    if (d->currentCall) {
        qDebug() << "✅ Answering incoming AUDIO call with Risip C++ API...";

        try {
            d->currentCall->answer();

            // ✅ Set current call video flag for incoming audio call
            d->isCurrentCallVideo = false;
            emit isCurrentCallVideoChanged(false);

            d->inCall = true;
            emit isInCallChanged(true);
            emit callConnected();
            updateCallStatus("通话中");
            d->callDuration = 0;
            d->callTimer->start();

        } catch (const std::exception &ex) {
            qDebug() << "Error answering call:" << ex.what();
            emit errorOccurred("接听失败");
        } catch (...) {
            qDebug() << "Unknown error answering call";
            emit errorOccurred("接听失败");
        }
    } else {
        qDebug() << "❌ No call to answer";
    }
}

// ✅ 仅语音接听视频来电（拒绝视频流）
void SipPhoneManager::answerCallAsAudio()
{
    qDebug() << "Answering incoming video call as audio-only (declining video)...";

    // 查找当前来电
    pjsua_call_id call_ids[PJSUA_MAX_CALLS];
    unsigned count = PJ_ARRAY_SIZE(call_ids);
    pj_status_t status = pjsua_enum_calls(call_ids, &count);

    if (status == PJ_SUCCESS && count > 0) {
        for (unsigned i = 0; i < count; ++i) {
            pjsua_call_info ci;
            status = pjsua_call_get_info(call_ids[i], &ci);

            if (status == PJ_SUCCESS && ci.state == PJSIP_INV_STATE_INCOMING) {
                // 找到来电，仅使用音频接听（vid_cnt=0 禁用视频）
                pjsua_call_setting call_opt;
                pjsua_call_setting_default(&call_opt);
                call_opt.vid_cnt = 0;  // 禁用视频

                status = pjsua_call_answer2(call_ids[i], &call_opt, 200, NULL, NULL);
                if (status == PJ_SUCCESS) {
                    qDebug() << "✅ Video call answered as audio-only (video declined)";
                } else {
                    qWarning() << "❌ Failed to answer call as audio-only, status:" << status;
                    emit errorOccurred("接听失败");
                }
                return;
            }
        }
    }

    qDebug() << "❌ No incoming call found to answer";
}

void SipPhoneManager::hangupCall()
{
    qDebug() << "✅ hangupCall() called";

    // ✅ Handle both Risip C++ API calls (audio-only) and PJSIP C API calls (video)
    if (d->currentCall) {
        // Audio-only call using Risip C++ wrapper
        qDebug() << "Hanging up audio-only call (Risip C++ API)...";

        try {
            d->callTimer->stop();

            // ✅ CRITICAL FIX: Cache duration BEFORE hanging up
            // Otherwise, after hangup() the PJSIP session is destroyed and we can't get duration
            long duration = d->currentCall->callDuration();
            if (duration > 0) {
                d->currentCall->setProperty("cachedDuration", QVariant::fromValue(duration));
                qDebug() << "✅ Caching call duration before hangup:" << duration << "ms (" << (duration/1000) << "s)";
            } else {
                qDebug() << "⚠️ Call duration is 0, not caching";
            }

            // Hangup the call
            d->currentCall->hangup();
            d->currentCall = nullptr;

            d->inCall = false;
            emit isInCallChanged(false);
            emit callDisconnected();
            updateCallStatus("就绪");
            d->callDuration = 0;
            emit callDurationChanged(0);

            // ✅ Reset current call video flag
            d->isCurrentCallVideo = false;
            emit isCurrentCallVideoChanged(false);

            qDebug() << "Audio-only call ended";

        } catch (const std::exception &ex) {
            qDebug() << "Error hanging up audio call:" << ex.what();
        } catch (...) {
            qDebug() << "Unknown error hanging up audio call";
        }
    } else if (d->inCall) {
        // ✅ Video call created with PJSIP C API (no RisipCall object)
        // Need to hangup using PJSIP C API directly
        qDebug() << "🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════";
        qDebug() << "🔴 [HANGUP-DEBUG] 本机主动挂断视频通话 (PJSIP C API)";
        qDebug() << "🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════";

        try {
            // Find active call and hangup
            pjsua_call_id call_ids[PJSUA_MAX_CALLS];
            unsigned count = PJ_ARRAY_SIZE(call_ids);
            pj_status_t status = pjsua_enum_calls(call_ids, &count);

            if (status == PJ_SUCCESS && count > 0) {
                qDebug() << "🔴 [HANGUP-DEBUG] 找到" << count << "个活跃通话";

                for (unsigned i = 0; i < count; ++i) {
                    pjsua_call_info ci;
                    status = pjsua_call_get_info(call_ids[i], &ci);

                    if (status == PJ_SUCCESS && ci.state != PJSIP_INV_STATE_DISCONNECTED) {
                        qDebug() << "🔴 [HANGUP-DEBUG] 准备挂断 call_id:" << call_ids[i];
                        qDebug() << "🔴 [HANGUP-DEBUG] 当前状态:" << ci.state;
                        qDebug() << "🔴 [HANGUP-DEBUG] 调用 pjsua_call_hangup()...";
                        pjsua_call_hangup(call_ids[i], 0, NULL, NULL);
                        qDebug() << "🔴 [HANGUP-DEBUG] pjsua_call_hangup() 返回";
                    }
                }

                // The onCallStateChanged callback will handle UI updates when call disconnects
                qDebug() << "🔴 [HANGUP-DEBUG] 挂断命令已发送，等待 onCallStateChanged 回调";
                qDebug() << "🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════";

            } else {
                qWarning() << "❌ No active calls found to hangup";

                // Manually update UI since there's no call to disconnect
                d->callTimer->stop();
                d->inCall = false;
                emit isInCallChanged(false);
                emit callDisconnected();
                updateCallStatus("就绪");
                d->callDuration = 0;
                emit callDurationChanged(0);

                // ✅ Reset current call video flag
                d->isCurrentCallVideo = false;
                emit isCurrentCallVideoChanged(false);
            }

        } catch (const std::exception &ex) {
            qDebug() << "Error hanging up video call:" << ex.what();
        } catch (...) {
            qDebug() << "Unknown error hanging up video call";
        }
    } else {
        qDebug() << "⚠️ No active call to hangup";
    }
}

void SipPhoneManager::holdCall(bool hold)
{
    if (!d->inCall || !d->currentCall) {
        return;
    }

    qDebug() << "Hold call:" << hold;

    try {
        if (hold) {
            d->currentCall->hold(true);
            d->callTimer->stop();
            updateCallStatus("保持中");
        } else {
            d->currentCall->hold(false);
            d->callTimer->start();
            updateCallStatus("通话中");
        }
    } catch (const std::exception &ex) {
        qDebug() << "Error toggling hold:" << ex.what();
    } catch (...) {
        qDebug() << "Unknown error toggling hold";
    }
}

void SipPhoneManager::transferCall(const QString &targetNumber)
{
    if (!d->inCall || !d->currentCall) {
        return;
    }

    qDebug() << "Transferring call to:" << targetNumber;

    try {
        // Use transferDirect instead of transferCall
        d->currentCall->transferDirect(targetNumber);
    } catch (const std::exception &ex) {
        qDebug() << "Error transferring call:" << ex.what();
        emit errorOccurred("转移失败");
    } catch (...) {
        qDebug() << "Unknown error transferring call";
        emit errorOccurred("转移失败");
    }
}

// ✅ ATTEMPT 13: Activate video via CHANGE_DIR after call establishment
void SipPhoneManager::activatePendingVideo(int call_id)
{
    qDebug() << "📹 [ACTIVATE VIDEO] Checking for pending video activation for call" << call_id;

    // Check if this call has pending video activation
    if (d->pendingVideoActivationCallId != call_id) {
        qDebug() << "   No pending video activation for this call";
        return;
    }

    qDebug() << "📹 [ACTIVATE VIDEO] Call" << call_id << "is CONFIRMED, activating video now...";

    // Verify call is valid and in CONFIRMED state
    pjsua_call_info call_info;
    pj_status_t status = pjsua_call_get_info(call_id, &call_info);
    if (status != PJ_SUCCESS) {
        qDebug() << "⚠️ [ACTIVATE VIDEO] Failed to get call info, status:" << status;
        d->pendingVideoActivationCallId = PJSUA_INVALID_ID;
        return;
    }

    if (call_info.state != PJSIP_INV_STATE_CONFIRMED) {
        qDebug() << "   Call not yet CONFIRMED, waiting...";
        return;
    }

    // Use pjsua_call_set_vid_strm() with PJSUA_CALL_VID_STRM_CHANGE_DIR
    // to change video stream direction from inactive to sendrecv
    pjsua_call_vid_strm_op op = PJSUA_CALL_VID_STRM_CHANGE_DIR;
    pjsua_call_vid_strm_op_param param;
    pjsua_call_vid_strm_op_param_default(&param);

    param.med_idx = 1;  // Video stream is typically media index 1 (0=audio, 1=video)
    param.dir = PJMEDIA_DIR_ENCODING_DECODING;  // sendrecv

    qDebug() << "📹 [ACTIVATE VIDEO] Calling pjsua_call_set_vid_strm()...";
    qDebug() << "   op: PJSUA_CALL_VID_STRM_CHANGE_DIR";
    qDebug() << "   med_idx:" << param.med_idx;
    qDebug() << "   dir: PJMEDIA_DIR_ENCODING_DECODING (sendrecv)";

    status = pjsua_call_set_vid_strm(call_id, op, &param);

    if (status == PJ_SUCCESS) {
        qDebug() << "✅ [ACTIVATE VIDEO] Video activation SUCCESS! This will trigger re-INVITE.";
        qDebug() << "   Remote party should now see our video.";
        // Clear pending activation flag
        d->pendingVideoActivationCallId = PJSUA_INVALID_ID;
    } else {
        char errmsg[PJ_ERR_MSG_SIZE];
        pj_strerror(status, errmsg, sizeof(errmsg));
        qDebug() << "❌ [ACTIVATE VIDEO] Failed to activate video:" << errmsg;
        // Keep pending flag in case we can retry
    }
}

// ❌ 2026-01-19 05:10 删除旧代码：依赖 d->inCall，导致通话前无法设置音量
// 旧实现：只在通话中才能设置音量，且功能未实现（"Media control not fully implemented yet"）
// void SipPhoneManager::setMicrophoneVolume(int volume)
// {
//     qDebug() << "Set microphone volume:" << volume;
//     if (!d->inCall || !d->currentCall) {
//         qDebug() << "No active call for audio control";
//         return;
//     }
//     try {
//         risip::RisipMedia *media = d->currentCall->media();
//         if (media) {
//             qDebug() << "Media control not fully implemented yet";
//         }
//     } catch (const std::exception &ex) {
//         qDebug() << "Error setting mic volume:" << ex.what();
//     } catch (...) {
//         qDebug() << "Unknown error setting mic volume";
//     }
// }

// ❌ 2026-01-19 07:30 [FIX 100.249] 会议桥方案失败 - 只能在通话中调整
// 问题：用户在通话前调整音量 → 保存到 QSettings 但未应用到 PJSIP
//       会议桥 API (pjsua_conf_adjust_tx_level) 只能在通话建立后使用
// 测试结果：用户反馈"音量条件到99，但对方感觉没有变化"
// 原代码保留用于参考

// ✅ 2026-01-19 07:30 [FIX 100.249] 麦克风音量控制 - 使用硬件增益 API
// 原因：用户反馈"对方听到本机音量很小"，调整滑块到99%无效
// 新方案：使用 PJSIP 全局音频设备增益 API（pjsua_snd_set_setting）
// 优势：
//   1. 通话前即可设置，无需等待通话建立
//   2. 设置后自动持久化到所有未来通话
//   3. 调整硬件麦克风增益，效果更显著
// 参考：docs/2026-01-19/02-三个问题完整修复方案.md Lines 186-222
void SipPhoneManager::setMicrophoneVolume(int volume)
{
    qDebug() << "════════════════════════════════════════════════";
    qDebug() << "🎤 [FIX 100.249 v2] Setting microphone volume:" << volume << "%";
    qDebug() << "════════════════════════════════════════════════";

    // ✅ 保存到 QSettings（下次启动恢复）
    QSettings settings;
    settings.setValue("SIP/MicrophoneVolume", volume);
    qDebug() << "  ✅ [Settings] Microphone volume saved:" << volume;

    // ✅ 如果 PJSIP 已初始化，立即应用音量设置（硬件增益）
    if (d->initialized) {
        qDebug() << "  📞 [PJSIP] Initialized, applying hardware microphone gain";

        // 转换百分比 (0-100) 到 PJSIP 音量 (0-255)
        unsigned int pj_volume = (volume * 255) / 100;

        qDebug() << "  🔢 [Volume Calc] UI slider:" << volume << "% → PJSIP level:" << pj_volume << "/255";
        qDebug() << "     Interpretation: 0=静音, 128=50%, 255=100%增益";

        // 使用 PJSIP API 设置麦克风硬件增益
        // PJMEDIA_AUD_DEV_CAP_INPUT_VOLUME_SETTING: 输入音量设置能力
        // PJ_TRUE: 保持设置用于未来的音频设备
        qDebug() << "  🔧 [Hardware Gain] Calling pjsua_snd_set_setting(INPUT_VOLUME_SETTING, " << pj_volume << ")";
        pj_status_t status = pjsua_snd_set_setting(
            PJMEDIA_AUD_DEV_CAP_INPUT_VOLUME_SETTING,
            &pj_volume,
            PJ_TRUE  // Keep setting for future devices
        );

        if (status == PJ_SUCCESS) {
            qDebug() << "  ✅ [SUCCESS] Microphone hardware gain applied!";
            qDebug() << "     PJSIP level:" << pj_volume << "/255 (" << volume << "%)";
            qDebug() << "     Effect: 立即生效，无需等待通话建立";

            // ✅ 验证当前设置
            unsigned int verify_volume = 0;
            pj_status_t verify_status = pjsua_snd_get_setting(
                PJMEDIA_AUD_DEV_CAP_INPUT_VOLUME_SETTING,
                &verify_volume
            );
            if (verify_status == PJ_SUCCESS) {
                qDebug() << "  ✅ [Verify] Current hardware gain:" << verify_volume << "/255";
            }
        } else {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            qWarning() << "  ⚠️ [PJSIP] Failed to set microphone hardware gain:" << errmsg;
            qWarning() << "     Error code:" << status;
            qWarning() << "     But volume saved to settings, will be used when audio device is opened";
        }

        // ✅ 2026-01-19 07:30 额外检查 ALSA RMS 警告
        qDebug() << "  💡 [Hint] If low volume persists, check:";
        qDebug() << "     1. 物理麦克风音量是否正常";
        qDebug() << "     2. ALSA 系统音量设置 (alsamixer)";
        qDebug() << "     3. 麦克风是否静音或硬件问题";

    } else {
        qDebug() << "  📌 [PJSIP] Not initialized yet";
        qDebug() << "     Volume will be applied when PJSIP starts";
    }

    qDebug() << "════════════════════════════════════════════════";
}

void SipPhoneManager::setSpeakerVolume(int volume)
{
    qDebug() << "Set speaker volume:" << volume;

    if (!d->inCall || !d->currentCall) {
        qDebug() << "No active call for audio control";
        return;
    }

    try {
        risip::RisipMedia *media = d->currentCall->media();
        if (media) {
            // Note: RisipMedia may not have these exact methods
            // This is a placeholder - actual implementation may need adjustment
            qDebug() << "Media control not fully implemented yet";
        }
    } catch (const std::exception &ex) {
        qDebug() << "Error setting speaker volume:" << ex.what();
    } catch (...) {
        qDebug() << "Unknown error setting speaker volume";
    }
}

void SipPhoneManager::muteMicrophone(bool mute)
{
    qDebug() << "Mute microphone:" << mute;

    if (!d->inCall || !d->currentCall) {
        qDebug() << "No active call for audio control";
        return;
    }

    try {
        risip::RisipMedia *media = d->currentCall->media();
        if (media) {
            // Note: RisipMedia may not have these exact methods
            // This is a placeholder - actual implementation may need adjustment
            qDebug() << "Media control not fully implemented yet";
        }
    } catch (const std::exception &ex) {
        qDebug() << "Error muting mic:" << ex.what();
    } catch (...) {
        qDebug() << "Unknown error muting mic";
    }
}

// ✅ 2026-01-17 22:30 [FIX 100.246] 设备枚举和选择实现
// ⚠️ 2026-01-18 12:00 [DEPRECATED] 此函数已废弃，仅保留用于内部枚举
// QML 应使用 audioInputDevices property 而不是调用此函数
QStringList SipPhoneManager::getAudioInputDevices()
{
    // ✅ 2026-01-18 12:00 [DEBUG] 添加调用时机追踪
    qDebug() << "════════════════════════════════════════════════════════════";
    qDebug() << "🔥🔥🔥 [ENTRY] getAudioInputDevices() called!";
    qDebug() << "   [TIMING] Called at:" << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz");
    qDebug() << "   [STATE] d->initialized =" << d->initialized;
    qDebug() << "   [STATE] d->risipInstance =" << (d->risipInstance ? "EXISTS" : "NULL");
    qDebug() << "════════════════════════════════════════════════════════════";

    QStringList devices;

    // ✅ 2026-01-18 12:00 [FIX 100.246] 只在 PJSIP 已初始化时枚举设备
    // 原因：避免 QML 绑定时立即触发 PJSIP 初始化
    // QML 应监听 audioInputDevicesChanged signal 获取设备列表
    if (!d->initialized) {
        qDebug() << "   ⚠️ PJSIP not initialized yet, returning empty list";
        qDebug() << "   ℹ️ Devices will be enumerated after PJSIP initialization";
        return devices;  // 返回空列表
    }

    // 使用 pjsua_enum_aud_devs 枚举音频设备
    pjmedia_aud_dev_info info[64];  // 最多64个设备
    unsigned count = 64;

    qDebug() << "   [API] Calling pjsua_enum_aud_devs() with max count:" << count;
    pj_status_t status = pjsua_enum_aud_devs(info, &count);
    qDebug() << "   [API] pjsua_enum_aud_devs() returned, status:" << status << "count:" << count;

    if (status != PJ_SUCCESS) {
        char errmsg[PJ_ERR_MSG_SIZE];
        pj_strerror(status, errmsg, sizeof(errmsg));
        qWarning() << "❌ Failed to enumerate audio devices, error:" << errmsg;
        return devices;
    }

    qDebug() << "📢 [Device Enum] Total audio devices:" << count;

    // ✅ 2026-01-19 08:15 [FIX 100.250] 清空设备索引映射数组
    // 原因：每次枚举设备时都要重建映射，避免使用旧的索引
    d->audioInputDeviceMapping.clear();
    qDebug() << "   [FIX 100.250] Device index mapping cleared";

    // ✅ 2026-01-18 22:00 [FIX 100.248] 优先使用 plughw 设备（支持所有采样率）
    // 原因：
    //   - hw: 设备只支持硬件原生采样率（如 22050 Hz），不支持 PCMA 需要的 8000 Hz
    //   - plughw: 设备支持所有采样率（ALSA 自动重采样），确保 PCMA/PCMU 在任意设备都能工作
    // 核心理念：程序适应设备，而不是设备适应程序（容器化部署要求）
    // 参考：docs/2026-01-18/16-FIX100.248-优先使用plughw设备.md
    QSet<QString> seenCards;  // 记录已添加的声卡，避免重复
    QMap<QString, int> hwDeviceIndex;  // 暂存 hw: 设备索引，作为备选

    qDebug() << "";
    qDebug() << "🔍 [FIX 100.248] Device selection strategy:";
    qDebug() << "   1️⃣ Prefer: plughw:CARD=X (supports all sample rates)";
    qDebug() << "   2️⃣ Fallback: hw:CARD=X (only if no plughw available)";
    qDebug() << "   3️⃣ Skip: other aliases (default, sysdefault, etc.)";
    qDebug() << "";

    for (unsigned i = 0; i < count; ++i) {
        QString deviceName = QString::fromUtf8(info[i].name);
        qDebug() << "   [ALL] Device" << i << ":" << deviceName
                 << "| In:" << info[i].input_count << "Out:" << info[i].output_count;

        // 只添加支持录音(输入)的设备
        if (info[i].input_count == 0) {
            qDebug() << "      ⏭️ SKIPPED (no input channels)";
            continue;
        }

        // ✅ 提取声卡名称（CARD=xxx）
        QString cardName;
        QRegularExpression cardRegex("CARD=([^,\\s]+)");
        QRegularExpressionMatch match = cardRegex.match(deviceName);
        if (match.hasMatch()) {
            cardName = match.captured(1);
        } else {
            cardName = deviceName;  // 没有 CARD= 的情况，使用完整名称
        }

        // ✅ 过滤虚拟设备
        if (cardName.contains("Loopback", Qt::CaseInsensitive) ||
            deviceName.contains("dmix:", Qt::CaseInsensitive) ||
            deviceName.contains("dsnoop:", Qt::CaseInsensitive) ||
            deviceName.contains("surround", Qt::CaseInsensitive)) {
            qDebug() << "      ⏭️ SKIPPED (virtual device):" << cardName;
            continue;
        }

        // ✅ 2026-01-18 22:00 [FIX 100.248] 优先选择 plughw
        bool isPlughw = deviceName.startsWith("plughw:");
        bool isHw = deviceName.startsWith("hw:");

        // 情况 1: plughw 设备 - 立即添加（最优选择）
        if (isPlughw && deviceName.contains("DEV=0")) {
            if (seenCards.contains(cardName)) {
                qDebug() << "      ⏭️ SKIPPED (card already added):" << cardName;
                continue;
            }

            // 添加 plughw 设备
            QString friendlyName = cardName + " (麦克风)";
            qDebug() << "      ✅ ADDED:" << friendlyName << "(" << cardName << ")";
            qDebug() << "         [DEVICE TYPE] plughw (supports all sample rates) ⭐";
            qDebug() << "         [SAMPLE RATES] 8k/16k/22.05k/32k/44.1k/48k/96k all supported";
            qDebug() << "         [RESAMPLING] ALSA automatic resampling enabled";
            qDebug() << "         [INDEX MAPPING] User index:" << devices.count() << "→ PJSIP index:" << i;

            devices.append(friendlyName);
            seenCards.insert(cardName);

            // ✅ 2026-01-19 08:15 [FIX 100.250] 保存 PJSIP 原始索引到映射数组
            // 用户索引 = devices.count() - 1, PJSIP 索引 = i
            d->audioInputDeviceMapping.append(i);
            qDebug() << "         [FIX 100.250] Mapping saved: User" << (devices.count() - 1) << "→ PJSIP" << i;

            // 移除对应的 hw 设备（如果之前暂存了）
            if (hwDeviceIndex.contains(cardName)) {
                qDebug() << "         [INFO] Removed hw: fallback (plughw: is better)";
                hwDeviceIndex.remove(cardName);
            }
        }
        // 情况 2: hw 设备 - 暂存，等待对应的 plughw
        else if (isHw && deviceName.contains("DEV=0")) {
            if (seenCards.contains(cardName)) {
                qDebug() << "      ⏭️ SKIPPED (already added as plughw):" << cardName;
                continue;
            }

            // 暂存 hw 设备索引，作为备选
            if (!hwDeviceIndex.contains(cardName)) {
                hwDeviceIndex[cardName] = i;
                qDebug() << "      📦 STORED as fallback:" << cardName;
                qDebug() << "         [DEVICE TYPE] hw (limited sample rate support)";
                qDebug() << "         [WAITING] Will use if no plughw: available";
            } else {
                qDebug() << "      ⏭️ SKIPPED (duplicate hw alias)";
            }
        }
        // 情况 3: 其他设备（default, sysdefault 等）- 跳过
        else {
            if (seenCards.contains(cardName)) {
                qDebug() << "      ⏭️ SKIPPED (card already added):" << cardName;
            } else {
                qDebug() << "      ⏭️ SKIPPED (not plughw:CARD=X,DEV=0)";
            }
        }
    }

    // ✅ 2026-01-18 22:00 [FIX 100.248] 添加备选 hw 设备（没有 plughw 的情况）
    if (!hwDeviceIndex.isEmpty()) {
        qDebug() << "";
        qDebug() << "🔄 [FIX 100.248] Processing fallback hw: devices:";
    }

    for (auto it = hwDeviceIndex.constBegin(); it != hwDeviceIndex.constEnd(); ++it) {
        QString cardName = it.key();
        int deviceIndex = it.value();

        if (!seenCards.contains(cardName)) {
            QString deviceName = QString::fromUtf8(info[deviceIndex].name);
            QString friendlyName = cardName + " (麦克风)";

            qDebug() << "      ✅ ADDED (fallback):" << friendlyName << "(" << cardName << ")";
            qDebug() << "         [DEVICE TYPE] hw (limited sample rate support) ⚠️";
            qDebug() << "         [SAMPLE RATES] Only hardware native rates (e.g., 22.05k, 32k, 44.1k, 48k)";
            qDebug() << "         [WARNING] May not support 8kHz (PCMA) or 16kHz (AEC)";
            qDebug() << "         [INDEX MAPPING] User index:" << devices.count() << "→ PJSIP index:" << deviceIndex;

            devices.append(friendlyName);
            seenCards.insert(cardName);

            // ✅ 2026-01-19 08:15 [FIX 100.250] 保存 PJSIP 原始索引到映射数组
            // 用户索引 = devices.count() - 1, PJSIP 索引 = deviceIndex
            d->audioInputDeviceMapping.append(deviceIndex);
            qDebug() << "         [FIX 100.250] Mapping saved: User" << (devices.count() - 1) << "→ PJSIP" << deviceIndex;
        }
    }

    qDebug() << "📢 [Device Enum] Total INPUT devices added:" << devices.count();

    // ✅ 2026-01-18 16:10 [FIX 100.246.4] 如果没有可用设备，显示提示信息
    if (devices.isEmpty()) {
        devices.append("无可用麦克风");
        qDebug() << "⚠️ [Device Enum] No input devices found, added placeholder";
    }

    return devices;
}

// ⚠️ 2026-01-18 12:00 [DEPRECATED] 此函数已废弃，仅保留用于内部枚举
// QML 应使用 audioOutputDevices property 而不是调用此函数
QStringList SipPhoneManager::getAudioOutputDevices()
{
    // ✅ 2026-01-18 12:00 [DEBUG] 添加调用时机追踪
    qDebug() << "════════════════════════════════════════════════════════════";
    qDebug() << "🔥🔥🔥 [ENTRY] getAudioOutputDevices() called!";
    qDebug() << "   [TIMING] Called at:" << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz");
    qDebug() << "   [STATE] d->initialized =" << d->initialized;
    qDebug() << "   [STATE] d->risipInstance =" << (d->risipInstance ? "EXISTS" : "NULL");
    qDebug() << "════════════════════════════════════════════════════════════";

    QStringList devices;

    // ✅ 2026-01-18 12:00 [FIX 100.246] 只在 PJSIP 已初始化时枚举设备
    // 原因：避免 QML 绑定时立即触发 PJSIP 初始化
    // QML 应监听 audioOutputDevicesChanged signal 获取设备列表
    if (!d->initialized) {
        qDebug() << "   ⚠️ PJSIP not initialized yet, returning empty list";
        qDebug() << "   ℹ️ Devices will be enumerated after PJSIP initialization";
        return devices;  // 返回空列表
    }

    // 使用 pjsua_enum_aud_devs 枚举音频设备
    pjmedia_aud_dev_info info[64];
    unsigned count = 64;

    qDebug() << "   [API] Calling pjsua_enum_aud_devs() with max count:" << count;
    pj_status_t status = pjsua_enum_aud_devs(info, &count);
    qDebug() << "   [API] pjsua_enum_aud_devs() returned, status:" << status << "count:" << count;

    if (status != PJ_SUCCESS) {
        char errmsg[PJ_ERR_MSG_SIZE];
        pj_strerror(status, errmsg, sizeof(errmsg));
        qWarning() << "❌ Failed to enumerate audio devices, error:" << errmsg;
        return devices;
    }

    qDebug() << "🔊 [Device Enum] Total audio devices:" << count;

    // ✅ 2026-01-19 08:15 [FIX 100.250] 清空设备索引映射数组
    // 原因：每次枚举设备时都要重建映射，避免使用旧的索引
    d->audioOutputDeviceMapping.clear();
    qDebug() << "   [FIX 100.250] Device index mapping cleared";

    // ✅ 2026-01-18 12:30 [FIX 100.246] 智能过滤和友好命名
    // 原因：ALSA 为每个物理设备创建多个别名（hw, plughw, default, front 等）
    // 解决：只保留代表性设备，过滤虚拟设备，添加中文友好名称
    QSet<QString> seenCards;  // 记录已添加的声卡，避免重复

    for (unsigned i = 0; i < count; ++i) {
        QString deviceName = QString::fromUtf8(info[i].name);
        qDebug() << "   [ALL] Device" << i << ":" << deviceName
                 << "| In:" << info[i].input_count << "Out:" << info[i].output_count;

        // ✅ 2026-01-18 17:00 [DEBUG] HDMI 设备深度调试 - 为什么 output_count=0
        if (deviceName.contains("hdmi", Qt::CaseInsensitive) ||
            deviceName.contains("rockchip", Qt::CaseInsensitive)) {
            qDebug() << "      [HDMI DEEP DEBUG] ═══════════════════════════════════";
            qDebug() << "      [HDMI] Device name:" << deviceName;
            qDebug() << "      [HDMI] Driver:" << QString::fromUtf8(info[i].driver);
            qDebug() << "      [HDMI] input_count:" << info[i].input_count;
            qDebug() << "      [HDMI] output_count:" << info[i].output_count << "← 为什么是 0？";
            qDebug() << "      [HDMI] default_samples_per_sec:" << info[i].default_samples_per_sec;
            qDebug() << "      [HDMI] caps (能力标志):" << info[i].caps;
            qDebug() << "      [HDMI] routes (路由数量):" << info[i].routes;
            qDebug() << "      [HDMI] ext_fmt_cnt (扩展格式数量):" << info[i].ext_fmt_cnt;
            // ⚠️ 2026-01-18 17:00 ext_fmt 是 pjmedia_format 数组，结构复杂
            // 只打印数量即可，详细信息不影响分析 output_count=0 问题
            qDebug() << "      [HDMI DEEP DEBUG] ═══════════════════════════════════";

            // ⚠️ 可能的原因分析
            qDebug() << "      [HDMI ANALYSIS] 可能的原因:";
            qDebug() << "         1. HDMI 未连接显示器 → 音频通道未激活";
            qDebug() << "         2. ALSA 驱动 bug → 未正确报告音频能力";
            qDebug() << "         3. PJSIP ALSA 适配问题 → 枚举逻辑有问题";
            qDebug() << "         4. 设备需要先打开 → 才能获取正确的通道数";
            qDebug() << "         5. 权限问题 → 需要特定权限查询设备能力";
        }

        // 只添加支持播放(输出)的设备
        if (info[i].output_count > 0) {
            // ✅ 提取声卡名称（CARD=xxx）
            QString cardName;
            QRegularExpression cardRegex("CARD=([^,\\s]+)");
            QRegularExpressionMatch match = cardRegex.match(deviceName);
            if (match.hasMatch()) {
                cardName = match.captured(1);
            } else {
                cardName = deviceName;  // 没有 CARD= 的情况，使用完整名称
            }

            // ✅ 过滤虚拟设备
            if (cardName.contains("Loopback", Qt::CaseInsensitive) ||
                deviceName.contains("dmix:", Qt::CaseInsensitive) ||
                deviceName.contains("dsnoop:", Qt::CaseInsensitive) ||
                deviceName.contains("surround", Qt::CaseInsensitive)) {
                qDebug() << "      ⏭️ SKIPPED (virtual device):" << cardName;
                continue;
            }

            // ✅ 只保留代表性设备（优先 default:CARD=xxx，其次 plughw:CARD=xxx,DEV=0）
            bool isRepresentative = deviceName.startsWith("default:CARD=") ||
                                   (deviceName.startsWith("plughw:CARD=") && deviceName.contains("DEV=0"));

            if (!isRepresentative) {
                qDebug() << "      ⏭️ SKIPPED (duplicate alias)";
                continue;
            }

            // ✅ 避免同一声卡重复添加
            if (seenCards.contains(cardName)) {
                qDebug() << "      ⏭️ SKIPPED (card already added):" << cardName;
                continue;
            }
            seenCards.insert(cardName);

            // ✅ 2026-01-18 15:50 [FIX 100.246.3] 显示实际设备名称（CARD 名称 + 类型标签）
            // 原因：所有 HDMI 设备都显示"HDMI 音频输出"，无法区分不同设备
            // 解决：保留 CARD 原始名称，添加类型标签
            // ❌ 2026-01-18 12:30 旧代码：使用通用友好名称，无法区分设备
            // if (cardName.contains("hdmi", Qt::CaseInsensitive)) {
            //     friendlyName = "HDMI 音频输出";
            // }
            QString friendlyName = cardName + " (扬声器)";  // 显示 "rockchiphdmi0 (扬声器)"

            // ✅ 2026-01-18 16:30 [DEBUG] 打印设备索引映射关系
            qDebug() << "      ✅ ADDED:" << friendlyName << "(" << cardName << ")";
            qDebug() << "         [INDEX MAPPING] User index:" << devices.count() << "→ PJSIP index:" << i;

            devices.append(friendlyName);

            // ✅ 2026-01-19 08:15 [FIX 100.250] 保存 PJSIP 原始索引到映射数组
            // 用户索引 = devices.count() - 1, PJSIP 索引 = i
            d->audioOutputDeviceMapping.append(i);
            qDebug() << "         [FIX 100.250] Mapping saved: User" << (devices.count() - 1) << "→ PJSIP" << i;
        } else {
            qDebug() << "      ⏭️ SKIPPED (no output channels)";
        }
    }

    qDebug() << "🔊 [Device Enum] Total OUTPUT devices added:" << devices.count();

    // ✅ 2026-01-18 16:10 [FIX 100.246.4] 如果没有可用设备，显示提示信息
    if (devices.isEmpty()) {
        devices.append("无可用扬声器");
        qDebug() << "⚠️ [Device Enum] No output devices found, added placeholder";
    }

    return devices;
}

// ⚠️ 2026-01-18 12:00 [DEPRECATED] 此函数已废弃，仅保留用于内部枚举
// QML 应使用 videoDevices property 而不是调用此函数
QStringList SipPhoneManager::getVideoDevices()
{
    // ✅ 2026-01-18 12:00 [DEBUG] 添加调用时机追踪
    qDebug() << "════════════════════════════════════════════════════════════";
    qDebug() << "🔥🔥🔥 [ENTRY] getVideoDevices() called!";
    qDebug() << "   [TIMING] Called at:" << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz");
    qDebug() << "   [STATE] d->initialized =" << d->initialized;
    qDebug() << "   [STATE] d->risipInstance =" << (d->risipInstance ? "EXISTS" : "NULL");
    qDebug() << "════════════════════════════════════════════════════════════";

    QStringList devices;

    // ✅ 2026-01-18 12:00 [FIX 100.246] 只在 PJSIP 已初始化时枚举设备
    // 原因：避免 QML 绑定时立即触发 PJSIP 初始化
    // QML 应监听 videoDevicesChanged signal 获取设备列表
    if (!d->initialized) {
        qDebug() << "   ⚠️ PJSIP not initialized yet, returning empty list";
        qDebug() << "   ℹ️ Devices will be enumerated after PJSIP initialization";
        return devices;  // 返回空列表
    }

    unsigned count = pjsua_vid_dev_count();
    qDebug() << "📹 [Device Enum] Total video devices:" << count;

    for (unsigned i = 0; i < count; ++i) {
        pjmedia_vid_dev_info info;
        pj_status_t status = pjsua_vid_dev_get_info(i, &info);

        if (status == PJ_SUCCESS) {
            // 只添加支持视频捕获的设备
            if (info.dir & PJMEDIA_DIR_CAPTURE) {
                QString deviceName = QString::fromUtf8(info.name);
                // 过滤掉虚拟设备(colorbar)
                if (!deviceName.contains("colorbar", Qt::CaseInsensitive)) {
                    devices.append(deviceName);
                    qDebug() << "   Video Device" << i << ":" << deviceName;
                }
            }
        }
    }

    qDebug() << "📹 [Device Enum] Total video devices found:" << devices.count();

    // ✅ 2026-01-18 16:10 [FIX 100.246.4] 如果没有可用设备，显示提示信息
    if (devices.isEmpty()) {
        devices.append("无可用摄像头");
        qDebug() << "⚠️ [Device Enum] No video devices found, added placeholder";
    }

    return devices;
}

int SipPhoneManager::getCurrentAudioInputDevice()
{
    // ✅ 2026-01-18 02:00 [FIX 100.246] 从 QSettings 读取保存的设备索引
    // ✅ 2026-01-19 08:30 [FIX 100.250] 验证索引有效性，防止设备配置变化后崩溃
    // 原因：用户需要下次启动后恢复上次选择的设备
    // 不再依赖 d->initialized，因为这是显示用的，不是实际设置用的

    QSettings settings;
    int savedIndex = settings.value("SIP/AudioInputDevice", 0).toInt();

    qDebug() << "📢 [FIX 100.250] Reading saved audio input device index:" << savedIndex;

    // ✅ 2026-01-19 08:30 [FIX 100.250] 验证索引是否在映射数组范围内
    // 原因：设备配置可能在两次运行之间发生变化（插拔USB设备等）
    // 如果索引无效，返回 0（默认第一个设备）
    if (savedIndex < 0 || savedIndex >= d->audioInputDeviceMapping.size()) {
        qWarning() << "   ⚠️ [FIX 100.250] Saved index" << savedIndex << "is out of range";
        qWarning() << "      Valid range: 0 -" << (d->audioInputDeviceMapping.size() - 1);
        qWarning() << "      Mapping size:" << d->audioInputDeviceMapping.size();
        qWarning() << "      Returning default index 0";
        return 0;
    }

    qDebug() << "   ✅ [FIX 100.250] Saved index is valid";
    qDebug() << "      User index:" << savedIndex;
    qDebug() << "      Maps to PJSIP index:" << d->audioInputDeviceMapping[savedIndex];

    return savedIndex;

    // ❌ 2026-01-18 02:00 旧代码：依赖 d->initialized，在懒加载模式下会返回 -1
    // if (!d->initialized) {
    //     return -1;
    // }
    //
    // // 使用 pjsua_get_snd_dev2 获取当前音频设备
    // pjsua_snd_dev_param param;
    // pjsua_snd_dev_param_default(&param);
    // pj_status_t status = pjsua_get_snd_dev2(&param);
    //
    // if (status == PJ_SUCCESS) {
    //     qDebug() << "📢 Current capture device:" << param.capture_dev;
    //     return param.capture_dev;
    // }
    //
    // return -1;
}

int SipPhoneManager::getCurrentAudioOutputDevice()
{
    // ✅ 2026-01-18 02:00 [FIX 100.246] 从 QSettings 读取保存的设备索引
    // ✅ 2026-01-19 08:30 [FIX 100.250] 验证索引有效性，防止设备配置变化后崩溃
    // 原因：用户需要下次启动后恢复上次选择的设备
    // 不再依赖 d->initialized，因为这是显示用的，不是实际设置用的

    QSettings settings;
    int savedIndex = settings.value("SIP/AudioOutputDevice", 0).toInt();

    qDebug() << "🔊 [FIX 100.250] Reading saved audio output device index:" << savedIndex;

    // ✅ 2026-01-19 08:30 [FIX 100.250] 验证索引是否在映射数组范围内
    // 原因：设备配置可能在两次运行之间发生变化（插拔USB设备等）
    // 如果索引无效，返回 0（默认第一个设备）
    if (savedIndex < 0 || savedIndex >= d->audioOutputDeviceMapping.size()) {
        qWarning() << "   ⚠️ [FIX 100.250] Saved index" << savedIndex << "is out of range";
        qWarning() << "      Valid range: 0 -" << (d->audioOutputDeviceMapping.size() - 1);
        qWarning() << "      Mapping size:" << d->audioOutputDeviceMapping.size();
        qWarning() << "      Returning default index 0";
        return 0;
    }

    qDebug() << "   ✅ [FIX 100.250] Saved index is valid";
    qDebug() << "      User index:" << savedIndex;
    qDebug() << "      Maps to PJSIP index:" << d->audioOutputDeviceMapping[savedIndex];

    return savedIndex;

    // ❌ 2026-01-18 02:00 旧代码：依赖 d->initialized，在懒加载模式下会返回 -1
    // if (!d->initialized) {
    //     return -1;
    // }
    //
    // // 使用 pjsua_get_snd_dev2 获取当前音频设备
    // pjsua_snd_dev_param param;
    // pjsua_snd_dev_param_default(&param);
    // pj_status_t status = pjsua_get_snd_dev2(&param);
    //
    // if (status == PJ_SUCCESS) {
    //     qDebug() << "🔊 Current playback device:" << param.playback_dev;
    //     return param.playback_dev;
    // }
    //
    // return -1;
}

int SipPhoneManager::getCurrentVideoDevice()
{
    // ✅ 2026-01-18 02:00 [FIX 100.246] 从 QSettings 读取保存的设备索引
    // 原因：用户需要下次启动后恢复上次选择的设备
    // 不再依赖 d->initialized，因为这是显示用的，不是实际设置用的

    QSettings settings;
    int savedIndex = settings.value("SIP/VideoDevice", 0).toInt();

    qDebug() << "📹 [Settings] Saved video device index:" << savedIndex;

    return savedIndex;

    // ❌ 2026-01-18 02:00 旧代码：依赖 d->initialized，在懒加载模式下会返回 -1
    // if (!d->initialized || !d->videoCallManager) {
    //     return -1;
    // }
    //
    // int deviceId = d->videoCallManager->getCaptureDeviceId();
    // qDebug() << "📹 Current video device:" << deviceId;
    // return deviceId;
}

bool SipPhoneManager::setAudioInputDevice(int userIndex)
{
    qDebug() << "════════════════════════════════════════════════";
    qDebug() << "📢 [FIX 100.250] Setting audio input device to user index:" << userIndex;
    qDebug() << "════════════════════════════════════════════════";

    // ✅ 2026-01-19 08:15 [FIX 100.250] 索引映射：用户索引 → PJSIP 索引
    // 原因：设备枚举时过滤了 Loopback、HDMI、虚拟设备，用户索引 ≠ PJSIP 索引
    // 问题：直接使用用户索引会导致 PJMEDIA_EAUD_INVDEV 错误（设备不存在）
    // 解决：使用映射数组转换索引
    // 示例：用户选择索引 1（USB 麦克风）→ 映射到 PJSIP 索引 21
    if (userIndex < 0 || userIndex >= d->audioInputDeviceMapping.size()) {
        qWarning() << "❌ [FIX 100.250] Invalid user device index:" << userIndex;
        qWarning() << "   Valid range: 0 -" << (d->audioInputDeviceMapping.size() - 1);
        qWarning() << "   Mapping size:" << d->audioInputDeviceMapping.size();
        return false;
    }

    int pjsipIndex = d->audioInputDeviceMapping[userIndex];
    qDebug() << "   [FIX 100.250] Index mapping:";
    qDebug() << "      User index:" << userIndex << "→ PJSIP index:" << pjsipIndex;
    qDebug() << "      Mapping array size:" << d->audioInputDeviceMapping.size();
    qDebug() << "      Full mapping:" << d->audioInputDeviceMapping;

    // ✅ 2026-01-18 15:50 [FIX 100.246.2] 禁止在通话中切换设备（防止崩溃）
    // 原因：通话中重复创建/销毁音频设备可能导致堆内存损坏（Exit code 133）
    // 日志证据：docs/2026-01-18/05-FIX100.246失败分析-HDMI设备无输出通道.md
    if (d->inCall) {
        qWarning() << "⚠️ [FIX 100.246.2] Cannot change audio device during active call!";
        qWarning() << "   Reason: May cause heap corruption (SIGTRAP Exit 133)";
        qWarning() << "   Solution: Please end call before changing audio device";
        return false;
    }

    // ✅ 2026-01-19 08:15 [FIX 100.250] 保存用户索引到 QSettings（不是 PJSIP 索引！）
    // 原因：用户需要下次启动后恢复上次选择的设备
    // 重要：保存的是用户索引，读取后再通过映射数组转换为 PJSIP 索引
    QSettings settings;
    settings.setValue("SIP/AudioInputDevice", userIndex);
    qDebug() << "✅ [Settings] Audio input device (user index) saved to QSettings:" << userIndex;

    // ✅ 2026-01-18 02:00 如果 PJSIP 已初始化，立即应用设置
    // 如果未初始化，只保存到 QSettings，下次初始化时会使用
    if (d->initialized) {
        qDebug() << "   [PJSIP] PJSIP initialized, applying device setting now...";

        // 获取当前设置
        pjsua_snd_dev_param param;
        pjsua_snd_dev_param_default(&param);
        pj_status_t status = pjsua_get_snd_dev2(&param);

        if (status != PJ_SUCCESS) {
            // 如果获取失败，使用默认设置
            param.playback_dev = PJSUA_SND_DEFAULT_PLAYBACK_DEV;
        }

        // ✅ 2026-01-19 08:15 [FIX 100.250] 使用 PJSIP 索引（不是用户索引！）
        param.capture_dev = pjsipIndex;  // ← 使用映射后的 PJSIP 索引

        // 应用设置
        status = pjsua_set_snd_dev2(&param);

        if (status == PJ_SUCCESS) {
            qDebug() << "✅ Audio input device changed in PJSIP:";
            qDebug() << "   User index:" << userIndex << "→ PJSIP index:" << pjsipIndex;
            qDebug() << "════════════════════════════════════════════════";
            return true;
        } else {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            qWarning() << "❌ Failed to set audio input device in PJSIP:" << errmsg;
            qWarning() << "⚠️ But saved to settings, will be used on next SIP initialization";
            qDebug() << "════════════════════════════════════════════════";
            return false;
        }
    } else {
        qDebug() << "   [PJSIP] PJSIP not initialized yet, device will be used when PJSIP starts";
        qDebug() << "════════════════════════════════════════════════";
        return true;  // 返回 true，因为已保存到 QSettings
    }

    // ❌ 2026-01-18 02:00 旧代码：不保存到 QSettings，下次启动会丢失选择
    // if (!d->initialized) {
    //     qWarning() << "❌ PJSIP not initialized";
    //     return false;
    // }
    //
    // qDebug() << "📢 Setting audio input device to:" << index;
    //
    // // 获取当前设置
    // pjsua_snd_dev_param param;
    // pjsua_snd_dev_param_default(&param);
    // pj_status_t status = pjsua_get_snd_dev2(&param);
    //
    // if (status != PJ_SUCCESS) {
    //     // 如果获取失败，使用默认设置
    //     param.playback_dev = PJSUA_SND_DEFAULT_PLAYBACK_DEV;
    // }
    //
    // // 更新录音设备
    // param.capture_dev = index;
    //
    // // 应用设置
    // status = pjsua_set_snd_dev2(&param);
    //
    // if (status == PJ_SUCCESS) {
    //     qDebug() << "✅ Audio input device changed to:" << index;
    //     return true;
    // } else {
    //     char errmsg[PJ_ERR_MSG_SIZE];
    //     pj_strerror(status, errmsg, sizeof(errmsg));
    //     qWarning() << "❌ Failed to set audio input device:" << errmsg;
    //     return false;
    // }
}

bool SipPhoneManager::setAudioOutputDevice(int userIndex)
{
    qDebug() << "════════════════════════════════════════════════";
    qDebug() << "🔊 [FIX 100.250] Setting audio output device to user index:" << userIndex;
    qDebug() << "════════════════════════════════════════════════";

    // ✅ 2026-01-19 08:15 [FIX 100.250] 索引映射：用户索引 → PJSIP 索引
    if (userIndex < 0 || userIndex >= d->audioOutputDeviceMapping.size()) {
        qWarning() << "❌ [FIX 100.250] Invalid user device index:" << userIndex;
        qWarning() << "   Valid range: 0 -" << (d->audioOutputDeviceMapping.size() - 1);
        qWarning() << "   Mapping size:" << d->audioOutputDeviceMapping.size();
        return false;
    }

    int pjsipIndex = d->audioOutputDeviceMapping[userIndex];
    qDebug() << "   [FIX 100.250] Index mapping:";
    qDebug() << "      User index:" << userIndex << "→ PJSIP index:" << pjsipIndex;
    qDebug() << "      Mapping array size:" << d->audioOutputDeviceMapping.size();

    // ✅ 2026-01-18 15:50 [FIX 100.246.2] 禁止在通话中切换设备（防止崩溃）
    // 原因：通话中重复创建/销毁音频设备可能导致堆内存损坏（Exit code 133）
    // 日志证据：docs/2026-01-18/05-FIX100.246失败分析-HDMI设备无输出通道.md
    if (d->inCall) {
        qWarning() << "⚠️ [FIX 100.246.2] Cannot change audio device during active call!";
        qWarning() << "   Reason: May cause heap corruption (SIGTRAP Exit 133)";
        qWarning() << "   Solution: Please end call before changing audio device";
        return false;
    }

    // ✅ 2026-01-19 08:15 [FIX 100.250] 保存用户索引到 QSettings（不是 PJSIP 索引！）
    QSettings settings;
    settings.setValue("SIP/AudioOutputDevice", userIndex);
    qDebug() << "✅ [Settings] Audio output device (user index) saved to QSettings:" << userIndex;

    // ✅ 2026-01-18 02:00 如果 PJSIP 已初始化，立即应用设置
    // 如果未初始化，只保存到 QSettings，下次初始化时会使用
    if (d->initialized) {
        qDebug() << "   [PJSIP] PJSIP initialized, applying device setting now...";

        // 获取当前设置
        pjsua_snd_dev_param param;
        pjsua_snd_dev_param_default(&param);
        pj_status_t status = pjsua_get_snd_dev2(&param);

        if (status != PJ_SUCCESS) {
            // 如果获取失败，使用默认设置
            param.capture_dev = PJSUA_SND_DEFAULT_CAPTURE_DEV;
        }

        // ✅ 2026-01-19 08:15 [FIX 100.250] 使用 PJSIP 索引（不是用户索引！）
        param.playback_dev = pjsipIndex;  // ← 使用映射后的 PJSIP 索引

        // 应用设置
        status = pjsua_set_snd_dev2(&param);

        if (status == PJ_SUCCESS) {
            qDebug() << "✅ Audio output device changed in PJSIP:";
            qDebug() << "   User index:" << userIndex << "→ PJSIP index:" << pjsipIndex;
            qDebug() << "════════════════════════════════════════════════";
            return true;
        } else {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            qWarning() << "❌ Failed to set audio output device in PJSIP:" << errmsg;
            qWarning() << "⚠️ But saved to settings, will be used on next SIP initialization";
            qDebug() << "════════════════════════════════════════════════";
            return false;
        }
    } else {
        qDebug() << "   [PJSIP] PJSIP not initialized yet, device will be used when PJSIP starts";
        qDebug() << "════════════════════════════════════════════════";
        return true;  // 返回 true，因为已保存到 QSettings
    }

    // ❌ 2026-01-18 02:00 旧代码：不保存到 QSettings，下次启动会丢失选择
    // if (!d->initialized) {
    //     qWarning() << "❌ PJSIP not initialized";
    //     return false;
    // }
    //
    // qDebug() << "🔊 Setting audio output device to:" << index;
    //
    // // 获取当前设置
    // pjsua_snd_dev_param param;
    // pjsua_snd_dev_param_default(&param);
    // pj_status_t status = pjsua_get_snd_dev2(&param);
    //
    // if (status != PJ_SUCCESS) {
    //     // 如果获取失败，使用默认设置
    //     param.capture_dev = PJSUA_SND_DEFAULT_CAPTURE_DEV;
    // }
    //
    // // 更新播放设备
    // param.playback_dev = index;
    //
    // // 应用设置
    // status = pjsua_set_snd_dev2(&param);
    //
    // if (status == PJ_SUCCESS) {
    //     qDebug() << "✅ Audio output device changed to:" << index;
    //     return true;
    // } else {
    //     char errmsg[PJ_ERR_MSG_SIZE];
    //     pj_strerror(status, errmsg, sizeof(errmsg));
    //     qWarning() << "❌ Failed to set audio output device:" << errmsg;
    //     return false;
    // }
}

bool SipPhoneManager::setVideoDevice(int index)
{
    qDebug() << "📹 [FIX 100.246] Setting video device to:" << index;

    // ✅ 2026-01-18 02:00 [FIX 100.246] 立即保存到 QSettings
    // 原因：用户需要下次启动后恢复上次选择的设备
    QSettings settings;
    settings.setValue("SIP/VideoDevice", index);
    qDebug() << "✅ [Settings] Video device saved to QSettings:" << index;

    // ⚠️ 2026-01-18 02:00 视频设备切换功能尚未完整实现
    // VideoCallManager 没有 setCaptureDeviceId 方法
    // 目前只保存到 QSettings，下次通话时会使用新设备
    qWarning() << "⚠️ Video device switching not fully implemented yet";
    qWarning() << "⚠️ New device will be used on next call";

    return true;  // 返回 true，因为已保存到 QSettings

    // ❌ 2026-01-18 02:00 旧代码：不保存到 QSettings，下次启动会丢失选择
    // if (!d->initialized) {
    //     qWarning() << "❌ PJSIP not initialized";
    //     return false;
    // }
    //
    // qDebug() << "📹 Setting video device to:" << index;
    //
    // // ❌ 2026-01-17 23:00 VideoCallManager 没有 setCaptureDeviceId 方法
    // // ✅ 简化实现：记录日志，实际切换需要通过 VideoCallManager 的其他方法
    // // 视频设备切换比较复杂，需要在下次通话时生效
    //
    // qWarning() << "⚠️ Video device switching not fully implemented yet";
    // qWarning() << "⚠️ New device will be used on next call";
    //
    // return true;  // 暂时返回 true，避免界面报错
}

void SipPhoneManager::sendDtmf(const QString &digits)
{
    if (!d->inCall || !d->currentCall) {
        return;
    }

    qDebug() << "Sending DTMF:" << digits;

    try {
        // Note: DTMF sending may require RisipMedia or direct PJSIP access
        // This is a placeholder - actual implementation may need adjustment
        qDebug() << "DTMF sending not fully implemented yet";
    } catch (const std::exception &ex) {
        qDebug() << "Error sending DTMF:" << ex.what();
    } catch (...) {
        qDebug() << "Unknown error sending DTMF";
    }
}

// ===========================================================================================
// Ringtone Management (铃声管理)
// ===========================================================================================

QString SipPhoneManager::getRingtonePath()
{
    QSettings settings("BeltControl", "SipPhone");
    QString customPath = settings.value("ringtone/customPath", "").toString();

    // If custom ringtone exists, return it
    if (!customPath.isEmpty() && QFile::exists(customPath)) {
        qDebug() << "🔔 [RINGTONE] Using custom ringtone:" << customPath;
        QString url = QUrl::fromLocalFile(customPath).toString();
        qDebug() << "🔔 [RINGTONE] URL format:" << url;
        return url;
    }

    // Check if ringtone exists in app directory
    QString appPath = QCoreApplication::applicationDirPath();
    QString localRingtone = appPath + "/sounds/custom_ringtone.wav";
    if (QFile::exists(localRingtone)) {
        qDebug() << "🔔 [RINGTONE] Using local ringtone:" << localRingtone;
        QString url = QUrl::fromLocalFile(localRingtone).toString();
        qDebug() << "🔔 [RINGTONE] URL format:" << url;
        return url;
    }

    // Fall back to Windows system ringtone
    QString systemRingtone = "C:/Windows/Media/Ring01.wav";
    qDebug() << "🔔 [RINGTONE] Using system ringtone:" << systemRingtone;
    QString url = QUrl::fromLocalFile(systemRingtone).toString();
    qDebug() << "🔔 [RINGTONE] URL format:" << url;
    return url;
}

QString SipPhoneManager::getRingtoneFilename()
{
    QSettings settings("BeltControl", "SipPhone");
    QString customPath = settings.value("ringtone/customPath", "").toString();

    if (!customPath.isEmpty() && QFile::exists(customPath)) {
        QFileInfo info(customPath);
        return info.fileName();
    }

    QString appPath = QCoreApplication::applicationDirPath();
    QString localRingtone = appPath + "/sounds/custom_ringtone.wav";
    if (QFile::exists(localRingtone)) {
        return "custom_ringtone.wav (本地)";
    }

    return "Ring01.wav (系统默认)";
}

bool SipPhoneManager::selectAndSetRingtone()
{
    qDebug() << "🔔 [RINGTONE] Opening file dialog to select ringtone...";

    // Open file dialog to select audio file
    QString selectedFile = QFileDialog::getOpenFileName(
        nullptr,
        "选择铃声文件",
        QStandardPaths::writableLocation(QStandardPaths::MusicLocation),
        "音频文件 (*.wav *.mp3 *.ogg *.m4a);;所有文件 (*.*)"
    );

    if (selectedFile.isEmpty()) {
        qDebug() << "🔔 [RINGTONE] User cancelled file selection";
        return false;
    }

    qDebug() << "🔔 [RINGTONE] Selected file:" << selectedFile;

    // Create sounds directory if it doesn't exist
    QString appPath = QCoreApplication::applicationDirPath();
    QString soundsDir = appPath + "/sounds";
    QDir dir;
    if (!dir.exists(soundsDir)) {
        if (!dir.mkpath(soundsDir)) {
            qCritical() << "❌ [RINGTONE] Failed to create sounds directory:" << soundsDir;
            return false;
        }
        qDebug() << "✅ [RINGTONE] Created sounds directory:" << soundsDir;
    }

    // ✅ 保留原始文件扩展名
    QFileInfo fileInfo(selectedFile);
    QString extension = fileInfo.suffix().toLower();
    if (extension.isEmpty()) {
        extension = "wav";  // 默认扩展名
    }
    QString destPath = soundsDir + "/custom_ringtone." + extension;

    qDebug() << "🔔 [RINGTONE] Destination path:" << destPath;

    // ✅ 先切换到系统铃声,释放旧文件(通过触发信号)
    // 临时清空设置,触发QML切换到系统铃声
    QSettings settings("BeltControl", "SipPhone");
    QString oldPath = settings.value("ringtone/customPath", "").toString();
    if (!oldPath.isEmpty()) {
        settings.setValue("ringtone/customPath", "");
        settings.sync();
        qDebug() << "🔔 [RINGTONE] Temporarily cleared custom ringtone to release old file";
        // 触发信号切换到系统铃声
        emit ringtonePathChanged("file:///C:/Windows/Media/Ring01.wav");
        // 等待100ms让QML切换完成
        QThread::msleep(100);
    }

    // ✅ 删除所有可能的旧铃声文件(不同扩展名)
    QStringList possibleExtensions = {"wav", "mp3", "ogg", "m4a"};
    for (const QString &ext : possibleExtensions) {
        QString oldFile = soundsDir + "/custom_ringtone." + ext;
        if (QFile::exists(oldFile)) {
            if (QFile::remove(oldFile)) {
                qDebug() << "✅ [RINGTONE] Removed old ringtone:" << oldFile;
            } else {
                qWarning() << "⚠️ [RINGTONE] Failed to remove old ringtone:" << oldFile;
            }
        }
    }

    // Copy selected file to sounds directory
    if (!QFile::copy(selectedFile, destPath)) {
        qCritical() << "❌ [RINGTONE] Failed to copy ringtone file to:" << destPath;
        qCritical() << "❌ [RINGTONE] Error:" << QFile(selectedFile).errorString();
        // 恢复旧设置
        if (!oldPath.isEmpty()) {
            settings.setValue("ringtone/customPath", oldPath);
            settings.sync();
        }
        return false;
    }

    qDebug() << "✅ [RINGTONE] Ringtone copied to:" << destPath;

    // Save to settings
    settings.setValue("ringtone/customPath", destPath);
    settings.sync();

    qDebug() << "✅ [RINGTONE] Ringtone path saved to settings";

    // Emit signal to notify QML
    emit ringtonePathChanged(getRingtonePath());

    return true;
}

// Helper methods
void SipPhoneManager::configureAccountVideoDevice(const QString &accountUri)
{
    qDebug() << "Configuring video device for account:" << accountUri;

    try {
        // Enumerate all PJSIP accounts to find the one matching this URI
        pjsua_acc_id acc_ids[10];
        unsigned count = PJ_ARRAY_SIZE(acc_ids);
        pj_status_t status = pjsua_enum_accs(acc_ids, &count);

        if (status != PJ_SUCCESS || count == 0) {
            qWarning() << "No PJSIP accounts found for video configuration";
            return;
        }

        // Find account ID matching the URI
        pjsua_acc_id targetAccId = PJSUA_INVALID_ID;
        for (unsigned i = 0; i < count; ++i) {
            pjsua_acc_info accInfo;
            status = pjsua_acc_get_info(acc_ids[i], &accInfo);
            if (status == PJ_SUCCESS) {
                QString accUri = QString::fromUtf8(accInfo.acc_uri.ptr, accInfo.acc_uri.slen);
                qDebug() << "Checking account" << acc_ids[i] << "URI:" << accUri;
                if (accUri == accountUri) {
                    targetAccId = acc_ids[i];
                    break;
                }
            }
        }

        if (targetAccId == PJSUA_INVALID_ID) {
            qWarning() << "No PJSIP account found matching URI:" << accountUri;
            return;
        }

        qDebug() << "Found account ID" << targetAccId << "for URI:" << accountUri;

        // Create temporary pool for getting account config
        pj_pool_t *pool = pjsua_pool_create("tmp-vid-cfg", 512, 512);
        if (!pool) {
            qWarning() << "Failed to create pool for account video config";
            return;
        }

        // Get current account config
        pjsua_acc_config acc_cfg;
        pjsua_acc_config_default(&acc_cfg);
        status = pjsua_acc_get_config(targetAccId, pool, &acc_cfg);

        if (status == PJ_SUCCESS) {
            // ✅ CRITICAL FIX: Get the REAL capture device ID from VideoCallManager
            // VideoCallManager already found the real camera (skipping colorbar/null devices)
            // We CANNOT hardcode device 0 because on this system:
            //   Device 0 = colorbar (RENDER ONLY, Dir=2)
            //   Device 1 = Integrated Webcam (CAPTURE, Dir=1)
            pjmedia_vid_dev_index realCaptureDevice = 0;
            if (d->videoCallManager) {
                realCaptureDevice = d->videoCallManager->getCaptureDeviceId();
                qDebug() << "✅ Using real capture device ID from VideoCallManager:" << realCaptureDevice;
            } else {
                qWarning() << "⚠️ VideoCallManager not available, using device 0 (may be wrong!)";
            }

            // Set video capture device to the REAL camera (not colorbar!)
            acc_cfg.vid_cap_dev = realCaptureDevice;
            acc_cfg.vid_rend_dev = PJMEDIA_VID_DEFAULT_RENDER_DEV;  // ✅ 必须保留渲染设备以接收远程视频

            // ✅ Disable auto-show (no SDL window), use Qt VideoSinkItem for remote video
            // Root cause: Setting vid_rend_dev to INVALID disables SDL renderer entirely
            acc_cfg.vid_in_auto_show = PJ_FALSE;  // ✅ 禁用SDL窗口自动显示，但保留渲染器
            acc_cfg.vid_out_auto_transmit = PJ_TRUE;  // ✅ Enable outgoing video transmission

            // Modify account with new video config
            status = pjsua_acc_modify(targetAccId, &acc_cfg);
            if (status == PJ_SUCCESS) {
                qDebug() << "✅ Account" << targetAccId << "video device configured: vid_cap_dev=" << realCaptureDevice;
            } else {
                char errmsg[PJ_ERR_MSG_SIZE];
                pj_strerror(status, errmsg, sizeof(errmsg));
                qWarning() << "❌ Failed to modify account" << targetAccId << "video config:" << errmsg;
            }
        } else {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            qWarning() << "Failed to get account config for account" << targetAccId << ":" << errmsg;
        }

        // Release the temporary pool
        pj_pool_release(pool);

    } catch (const std::exception &ex) {
        qWarning() << "Exception configuring video device:" << ex.what();
    } catch (...) {
        qWarning() << "Unknown error configuring video device";
    }
}

void SipPhoneManager::updateCallStatus(const QString &status)
{
    if (d->callStatus != status) {
        d->callStatus = status;
        emit callStatusChanged(status);
    }
}

void SipPhoneManager::updateServerStatus(const QString &status)
{
    if (d->serverStatus != status) {
        d->serverStatus = status;
        emit serverStatusChanged(status);
    }
}

// Auto sign-in management
bool SipPhoneManager::getAutoSignIn() const
{
    if (!d->currentAccount) {
        return false;
    }
    return d->currentAccount->autoSignIn();
}

void SipPhoneManager::setAutoSignInEnabled(bool enabled)
{
    if (!d->currentAccount) {
        qWarning() << "No account to set auto sign-in for";
        return;
    }

    d->currentAccount->setAutoSignIn(enabled);
    qDebug() << "Auto sign-in" << (enabled ? "enabled" : "disabled");

    // Save to settings
    if (d->risipInstance) {
        d->risipInstance->saveSettings();
        qDebug() << "Auto sign-in preference saved";
    }
}

// Video call manager getter
QObject* SipPhoneManager::videoCallManager() const
{
    return d->videoCallManager;
}

// Qt video preview getter
QObject* SipPhoneManager::qtVideoPreview() const
{
    return d->qtVideoPreview;
}

// Local video manager getter (PJSIP preview)
QObject* SipPhoneManager::localVideoManager() const
{
    return d->localVideoManager;
}

// Remote video manager getter
QObject* SipPhoneManager::remoteVideoManager() const
{
    return d->remoteVideoManager;
}

// ✅ 2026-01-18 12:00 [FIX 100.246] 设备列表 property getters（前后端分离）
QStringList SipPhoneManager::audioInputDevices() const
{
    return d->cachedAudioInputDevices;
}

QStringList SipPhoneManager::audioOutputDevices() const
{
    return d->cachedAudioOutputDevices;
}

QStringList SipPhoneManager::videoDevices() const
{
    return d->cachedVideoDevices;
}

// ✅ Public methods for call state callback to update UI
void SipPhoneManager::setInCall(bool inCall)
{
    if (d->inCall != inCall) {
        d->inCall = inCall;
        emit isInCallChanged(inCall);
        qDebug() << "✅ [UI] inCall changed to:" << inCall;
    }
}

void SipPhoneManager::setIsIncomingVideoCall(bool isVideoCall)
{
    if (d->isIncomingVideoCall != isVideoCall) {
        d->isIncomingVideoCall = isVideoCall;
        emit isIncomingVideoCallChanged(isVideoCall);
        qDebug() << "✅ Incoming call detected: Video =" << isVideoCall;

        // ✅ ATTEMPT 12: DISABLE pre-start completely
        // Hypothesis: Pre-starting device (even if stopped later) leaves PJSIP in a bad state
        // Let PJSIP handle device initialization completely on its own
        qDebug() << "📹 [ATTEMPT 12] Video call detected, but NOT pre-starting device";
        qDebug() << "   Let PJSIP initialize device from scratch during answer";

        // Do NOT pre-start device
        // Do NOT set d->videoPreviewActive = true
        //
        // This is counter-intuitive after 11 attempts trying to "help" PJSIP,
        // but maybe PJSIP works better when we don't interfere at all
    }
}

void SipPhoneManager::setIsCurrentCallVideo(bool isVideoCall)
{
    if (d->isCurrentCallVideo != isVideoCall) {
        d->isCurrentCallVideo = isVideoCall;
        emit isCurrentCallVideoChanged(isVideoCall);
        qDebug() << "✅ Current call video flag updated:" << isVideoCall;
    }
}

void SipPhoneManager::notifyCallConnected(int callId)
{
    qDebug() << "✅ Notifying video managers: Call connected, ID =" << callId;
    if (d->remoteVideoManager) {
        d->remoteVideoManager->onCallConnected(callId);
    }
}

void SipPhoneManager::notifyCallDisconnected()
{
    qDebug() << "🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════";
    qDebug() << "🔴 [HANGUP-DEBUG] notifyCallDisconnected() 开始执行";
    qDebug() << "🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════";
    qDebug() << "✅ Notifying video managers: Call disconnected";

    if (d->remoteVideoManager) {
        qDebug() << "🔴 [HANGUP-DEBUG] 步骤 1/2: 调用 RemoteVideoManager::onCallDisconnected()...";
        d->remoteVideoManager->onCallDisconnected();
        qDebug() << "🔴 [HANGUP-DEBUG] 步骤 1/2: RemoteVideoManager::onCallDisconnected() 完成";
    } else {
        qDebug() << "🔴 [HANGUP-DEBUG] 步骤 1/2: RemoteVideoManager 为 NULL，跳过";
    }

    // ✅ 2026-01-14 21:30 [修复 VERSION 156 LOCAL_PUSH 循环]
    // 问题：挂断后 LocalVideoManager 的 stopPreview() 从未被调用
    //       导致 port 仍在 vid_conf 中，port_put_frame 回调持续执行
    //       表现：[LOCAL PUSH] Video frames: 0 | Total callbacks: 持续增长
    // 根因：
    //   - 错误理念：认为"本地预览独立于通话状态"（FIX 100.47.1）
    //   - 实际：通话结束应停止本地预览（释放摄像头资源）
    //   - 证据：docs/log/voip.md Line 3389 "Assert failed: port->grp_lock"
    //          Line 3394+ "[LOCAL PUSH] Video frames: 0 | Total callbacks: 82, 113, 143..."
    // 解决：挂断时调用 stopPreview()，让 PJSIP 清理 port
    // 详细：docs/2026-01-14/12-VERSION156新问题分析-挂断后持续输出LOCAL_PUSH日志.md
    if (d->localVideoManager) {
        qDebug() << "🔴 [HANGUP-DEBUG] 步骤 2/2: 准备调用 LocalVideoManager::stopPreview()...";
        qDebug() << "🔧 [FIX VERSION 156] Stopping local preview on call disconnect";

        // ✅ 使用 QMetaObject::invokeMethod 在 Qt 主线程中调用
        // 原因：notifyCallDisconnected() 在 PJSIP 线程中执行
        //       LocalVideoManager 的方法必须在 Qt 主线程中调用
        qDebug() << "🔴 [HANGUP-DEBUG] 使用 QMetaObject::invokeMethod 在主线程调用...";
        QMetaObject::invokeMethod(d->localVideoManager, "stopPreview", Qt::QueuedConnection);

        qDebug() << "🔴 [HANGUP-DEBUG] 步骤 2/2: stopPreview() 已入队等待主线程执行";
        qDebug() << "✅ [FIX VERSION 156] stopPreview() queued for execution in Qt main thread";
    } else {
        qDebug() << "🔴 [HANGUP-DEBUG] 步骤 2/2: LocalVideoManager 为 NULL，跳过";
    }

    qDebug() << "🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════";
    qDebug() << "🔴 [HANGUP-DEBUG] notifyCallDisconnected() 执行完成";
    qDebug() << "🔴 [HANGUP-DEBUG] ═══════════════════════════════════════════";

    // ❌ 2026-01-11 22:10 [FIX 100.47.1 已推翻] 错误理念：LocalVideoManager 独立于通话状态
    // 原因：导致 stopPreview() 从未被调用，port 未清理，回调持续执行
    // 移除错误调用：d->localVideoManager->onCallDisconnected() (方法不存在)

    /* ❌ 2026-01-11 22:40 [FIX 100.47 已回退] 延迟 UI 更新方案失败
     * 原因：
     *   1. QTimer::singleShot() 在 PJSIP 线程中发出警告
     *      "[WARNING] QObject::startTimer: Timers can only be used with threads started with QThread"
     *   2. 延迟未生效，UI 更新仍然立即触发
     *   3. 崩溃仍在 avcodec_close() 内部 (PJSIP 线程 LWP 80)，与 Qt UI 无关
     * 真正根因：
     *   - avcodec_close() 内部 double free
     *   - hw_frames_ctx 需要手动释放并设置为 NULL
     * 参考：docs/2026-01-11/37-Fix100.47测试失败分析-延迟方案无效.md
     */
    // QTimer::singleShot(150, this, [this]() {
    //     emit callStatusChanged("通话结束");
    //     emit currentNumberChanged("");
    // });
}

void SipPhoneManager::startCallTimer()
{
    if (d->callTimer && !d->callTimer->isActive()) {
        d->callDuration = 0;
        emit callDurationChanged(0);
        d->callTimer->start();
        qDebug() << "✅ [UI] Call timer started";
    }
}

void SipPhoneManager::stopCallTimer()
{
    if (d->callTimer && d->callTimer->isActive()) {
        d->callTimer->stop();
        d->callDuration = 0;
        emit callDurationChanged(0);
        qDebug() << "✅ [UI] Call timer stopped";
    }
}

// ✅ Video preview control (本机视频预览功能)
// Based on PJSIP official example: pjsip-apps/src/vidgui/vidgui.cpp

void SipPhoneManager::startVideoPreview()
{
    if (!d->initialized) {
        qWarning() << "❌ Cannot start preview: endpoint not initialized";
        emit errorOccurred("SIP引擎未初始化");
        return;
    }

    if (d->videoPreviewActive) {
        qDebug() << "⚠️ Video preview already active";
        return;
    }

    qDebug() << "✅ Starting video preview...";

    try {
        // ✅ CRITICAL FIX: Detect the REAL capture device dynamically
        // We CANNOT hardcode device 0 because on RK3588:
        //   Device 0 = rk_hdmirx (HDMI input, not a camera) - causes libv4l2 errors!
        //   Device 1 = USB Camera (correct device)
        //
        // Solution: Replicate the device detection logic from VideoCallManager
        pjmedia_vid_dev_index captureDevice = PJMEDIA_VID_INVALID_DEV;

        // First try to get from VideoCallManager if available
        if (d->videoCallManager) {
            captureDevice = d->videoCallManager->getCaptureDeviceId();
            qDebug() << "📹 [PREVIEW] Device from VideoCallManager:" << captureDevice;
        }

        // Verify the device is valid and not a problematic device
        // If invalid or device 0 (which might be rk_hdmirx), detect the correct device
        if (captureDevice == PJMEDIA_VID_INVALID_DEV || captureDevice == 0) {
            qDebug() << "📹 [PREVIEW] Detecting real capture device (skipping HDMI input)...";

            unsigned count = pjsua_vid_dev_count();
            pjmedia_vid_dev_index firstRealCamera = PJMEDIA_VID_INVALID_DEV;

            for (unsigned i = 0; i < count; ++i) {
                pjmedia_vid_dev_info info;
                pj_status_t status = pjsua_vid_dev_get_info(i, &info);

                if (status == PJ_SUCCESS && (info.dir & PJMEDIA_DIR_CAPTURE)) {
                    QString deviceName = QString::fromUtf8(info.name);

                    // Skip problematic devices (colorbar, null, HDMI input)
                    if (!deviceName.contains("colorbar", Qt::CaseInsensitive) &&
                        !deviceName.contains("null", Qt::CaseInsensitive) &&
                        !deviceName.contains("hdmirx", Qt::CaseInsensitive) &&
                        !deviceName.contains("rk_hdmirx", Qt::CaseInsensitive)) {
                        firstRealCamera = i;
                        qDebug() << "✅ [PREVIEW] Found real camera at device" << i << ":" << deviceName;
                        break;  // Use the first real camera found
                    } else {
                        qDebug() << "⏭️ [PREVIEW] Skipping device" << i << ":" << deviceName;
                    }
                }
            }

            if (firstRealCamera != PJMEDIA_VID_INVALID_DEV) {
                captureDevice = firstRealCamera;
                qDebug() << "✅ [PREVIEW] Using detected device:" << captureDevice;
            } else {
                qWarning() << "❌ [PREVIEW] No real capture device found! Preview will likely fail.";
                emit errorOccurred("未找到可用的摄像头设备");
                return;
            }
        }

        qDebug() << "✅ [PREVIEW] Final capture device selected:" << captureDevice;

        // ✅ Start PJSIP local video preview with the correct device
        pjsua_vid_preview_param preview_param;
        pjsua_vid_preview_param_default(&preview_param);
        preview_param.rend_id = PJMEDIA_VID_INVALID_DEV;
        preview_param.show = PJ_FALSE;

        pj_status_t status = pjsua_vid_preview_start(captureDevice, &preview_param);
        if (status != PJ_SUCCESS) {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            qWarning() << "❌ Failed to start video preview:" << errmsg;
            emit errorOccurred(QString("启动视频预览失败: %1").arg(errmsg));
            return;
        }

        pjsua_vid_win_id wid = pjsua_vid_preview_get_win(captureDevice);
        if (wid == PJSUA_INVALID_ID) {
            qWarning() << "❌ Failed to get video preview window ID";
            pjsua_vid_preview_stop(captureDevice);
            emit errorOccurred("无法获取视频预览窗口");
            return;
        }

        qDebug() << "✅ Video preview started successfully";
        qDebug() << "   Capture device:" << captureDevice;
        qDebug() << "   Preview window ID:" << wid;

        pjsua_vid_win_info wi;
        status = pjsua_vid_win_get_info(wid, &wi);
        if (status != PJ_SUCCESS) {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            qWarning() << "❌ Failed to get video window info:" << errmsg;
        } else {
            qDebug() << "✅ Got video window info successfully";

#ifdef _WIN32
            // ✅ Check if hwnd is valid before creating widget
            HWND sdlHwnd = (HWND)wi.hwnd.info.win.hwnd;
            qDebug() << "   SDL HWND:" << (void*)sdlHwnd;

            if (!sdlHwnd) {
                qWarning() << "❌ SDL HWND is null! Window may not be created yet.";
                qWarning() << "   Trying to show window first...";

                // Try to show the SDL window first to ensure it's created
                pjsua_vid_win_set_show(wid, PJ_TRUE);

                // Wait a bit for window creation
                QThread::msleep(100);

                // Get window info again
                status = pjsua_vid_win_get_info(wid, &wi);
                if (status == PJ_SUCCESS) {
                    sdlHwnd = (HWND)wi.hwnd.info.win.hwnd;
                    qDebug() << "   After show, SDL HWND:" << (void*)sdlHwnd;
                }
            }

            if (sdlHwnd) {
                // ✅ NEW APPROACH: Since SetParent fails (SDL resets parent internally),
                // we'll make SDL window "pseudo-embedded" by:
                // 1. Removing window decorations (no border, no title bar)
                // 2. Positioning it as an overlay on top of main window
                // This gives the appearance of embedding without actual parent-child relationship

                qDebug() << "✅ Configuring SDL window for pseudo-embedding...";

                // ✅ Remove window decorations - make it borderless
                LONG style = GetWindowLong(sdlHwnd, GWL_STYLE);
                style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZE | WS_MAXIMIZE | WS_SYSMENU);
                style |= WS_POPUP;  // Popup style = no decorations
                SetWindowLong(sdlHwnd, GWL_STYLE, style);
                qDebug() << "✅ SDL window style set to borderless popup";

                // ✅ Set window to always be on top (so it stays above main window)
                SetWindowPos(sdlHwnd, HWND_TOPMOST, 0, 0, 640, 480,
                             SWP_NOMOVE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
                qDebug() << "✅ SDL window set to always on top, size: 640x480";

                // ✅ CRITICAL: Enable video rendering via PJSIP API
                // This tells PJSIP to start rendering video to the SDL window
                pjsua_vid_win_set_show(wid, PJ_TRUE);
                qDebug() << "✅ Enabled PJSIP video rendering";

                // ✅ Show the SDL window
                ShowWindow(sdlHwnd, SW_SHOW);
                UpdateWindow(sdlHwnd);
                qDebug() << "✅ SDL window shown";

                // ✅ Store the SDL HWND for later positioning
                d->videoPreviewWindowId = wid;

                qDebug() << "✅ Video preview configured as borderless floating window";
                qDebug() << "   SDL window should now show camera feed";
                qDebug() << "   Click '停止预览' button to close it";
            } else {
                qWarning() << "❌ Cannot configure SDL window: HWND is still null";
            }
#else
            qWarning() << "⚠️ Window embedding only supported on Windows platform";
#endif
        }

        // Save preview state
        d->videoPreviewActive = true;
        d->videoPreviewWindowId = wid;

    } catch (const std::exception &ex) {
        qWarning() << "❌ Exception starting video preview:" << ex.what();
        emit errorOccurred(QString("启动视频预览异常: %1").arg(ex.what()));
    } catch (...) {
        qWarning() << "❌ Unknown error starting video preview";
        emit errorOccurred("启动视频预览失败: 未知错误");
    }
}

void SipPhoneManager::stopVideoPreview()
{
    if (!d->videoPreviewActive) {
        qDebug() << "⚠️ Video preview not active, nothing to stop";
        return;
    }

    qDebug() << "✅ Stopping video preview...";

    try {
        // ✅ Get the capture device ID from VideoCallManager
        pjmedia_vid_dev_index captureDevice = 0;
        if (d->videoCallManager) {
            captureDevice = d->videoCallManager->getCaptureDeviceId();
        }

        // ✅ Stop video preview (following PJSIP official example)
        pj_status_t status = pjsua_vid_preview_stop(captureDevice);

        if (status != PJ_SUCCESS) {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            qWarning() << "❌ Failed to stop video preview:" << errmsg;
            emit errorOccurred(QString("停止视频预览失败: %1").arg(errmsg));
            // Still reset state even if stop failed
        }

        qDebug() << "✅ Video preview stopped successfully";

        // ✅ Hide SDL window directly via PJSIP API
        if (d->videoPreviewWindowId != PJSUA_INVALID_ID) {
            pjsua_vid_win_set_show(d->videoPreviewWindowId, PJ_FALSE);
            qDebug() << "✅ SDL window hidden";
        }

        // Reset preview state
        d->videoPreviewActive = false;
        d->videoPreviewWindowId = PJSUA_INVALID_ID;

    } catch (const std::exception &ex) {
        qWarning() << "❌ Exception stopping video preview:" << ex.what();
        emit errorOccurred(QString("停止视频预览异常: %1").arg(ex.what()));
        // Reset state anyway
        d->videoPreviewActive = false;
        d->videoPreviewWindowId = PJSUA_INVALID_ID;
    } catch (...) {
        qWarning() << "❌ Unknown error stopping video preview";
        emit errorOccurred("停止视频预览失败: 未知错误");
        // Reset state anyway
        d->videoPreviewActive = false;
        d->videoPreviewWindowId = PJSUA_INVALID_ID;
    }
}

bool SipPhoneManager::isVideoPreviewActive() const
{
    return d->videoPreviewActive;
}

QWidget* SipPhoneManager::getVideoPreviewWidget()
{
    if (d->videoPreviewWidget) {
        qDebug() << "✅ Returning video preview Widget for embedding";
        return d->videoPreviewWidget;
    } else {
        qWarning() << "⚠️ Video preview Widget not available (preview not active or embedding failed)";
        return nullptr;
    }
}

// ==================== Contact Management ====================

QString SipPhoneManager::getContactName(const QString &number)
{
    QString name = risip::ContactDatabase::instance()->getContactName(number);
    if (!name.isEmpty()) {
        qDebug() << "📇 Found contact:" << name << "for number:" << number;
        return name;
    }
    return QString();  // 返回空字符串表示未找到
}

bool SipPhoneManager::addContact(const QString &name, const QString &number)
{
    qDebug() << "📇 Adding contact:" << name << "(" << number << ")";
    return risip::ContactDatabase::instance()->addContact(name, number);
}

bool SipPhoneManager::updateContact(int id, const QString &name, const QString &number)
{
    qDebug() << "📇 Updating contact ID:" << id << "to" << name << "(" << number << ")";
    return risip::ContactDatabase::instance()->updateContact(id, name, number);
}

bool SipPhoneManager::deleteContact(int id)
{
    qDebug() << "📇 Deleting contact ID:" << id;
    return risip::ContactDatabase::instance()->deleteContact(id);
}

QVariantList SipPhoneManager::getAllContacts()
{
    QList<risip::Contact> contacts = risip::ContactDatabase::instance()->getAllContacts();
    QVariantList result;

    for (const risip::Contact &contact : contacts) {
        QVariantMap contactMap;
        contactMap["id"] = contact.id;
        contactMap["name"] = contact.name;
        contactMap["number"] = contact.number;
        result.append(contactMap);
    }

    qDebug() << "📇 [SipPhoneManager] Loaded" << result.size() << "contacts from database";
    return result;
}
