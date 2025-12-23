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

        // ✅ ATTEMPT 13: Activate video via CHANGE_DIR after call is CONFIRMED
        // Check if this call has pending video activation
        QMetaObject::invokeMethod(manager, [manager, call_id]() {
            manager->activatePendingVideo(call_id);
        }, Qt::QueuedConnection);
        break;
    case PJSIP_INV_STATE_DISCONNECTED:
        statusText = "通话结束";
        isInCall = false;
        // Notify video managers that call is disconnected
        manager->notifyCallDisconnected();

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

        // DON'T create Risip instance here - defer until initializeEndpoint() is called
        // This prevents PJSIP initialization crash during app startup
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

    qDebug() << "SipPhoneManager created with Risip SDK";
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
    qDebug() << "Initializing SIP endpoint with Risip SDK...";

    if (d->initialized) {
        qDebug() << "Endpoint already initialized";
        return true;
    }

    // Create Risip instance on first initialization (lazy initialization)
    if (!d->risipInstance) {
        qDebug() << "Creating Risip instance (this will initialize PJSIP)...";
        d->risipInstance = risip::Risip::instance();
        if (!d->risipInstance) {
            qCritical() << "Failed to create Risip instance";
            updateServerStatus("无法创建 SIP 引擎");
            return false;
        }
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
            if (!call) return;

            qDebug() << "Incoming call from:" << call->buddy()->contact();
            d->currentCall = call;

            // ✅ Video detection is now handled in risipendpoint.cpp call_state_callback_wrapper()
            // at INCOMING state using invite session's SDP negotiator - this is more reliable
            // because it has access to the remote SDP before answering the call.
            // DO NOT detect video here as media_cnt is still 0 at this point!

            // Emit incoming call signal to QML
            QString callerNumber = call->buddy()->contact();

            // ✅ 提取纯号码（处理 "Extension 1006" 1006 这样的格式）
            QString extractedNumber = extractPhoneNumber(callerNumber);

            // ✅ 查询联系人名字，优先显示联系人名字
            QString callerName = risip::ContactDatabase::instance()->getContactName(extractedNumber);
            QString displayName = callerName.isEmpty() ? callerNumber : callerName;

            qDebug() << "📇 Incoming call - Raw:" << callerNumber << "Extracted:" << extractedNumber << "Display:" << displayName;

            // 保存显示名供后续使用
            setCallerDisplayName(displayName);

            emit incomingCall(callerNumber, displayName);
            updateCallStatus("来电: " + displayName);

            // Connect call status signals (same as in makeCall)
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

                // ✅ CRITICAL: Configure video device BEFORE login() for existing saved accounts
                // Existing accounts loaded from settings need vid_cap_dev configured via pjsua_acc_modify()
                QString accountUri = defaultAccount->configuration()->uri();
                qDebug() << "Configuring video device for saved default account:" << accountUri;
                configureAccountVideoDevice(accountUri);

                d->currentAccount->login();
                updateServerStatus("正在注册到: " + defaultAccount->configuration()->uri());
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
        cfg.setAccountUri(account2_uri);
        cfg.setUsername(account2_username);
        cfg.setPassword(account2_password);
        cfg.setServerUri(QString("sip:%1").arg(account2_server));
        cfg.setAutoSignIn(false); // Not auto-login for backup account

        risip::RisipAccount *account2 = d->risipInstance->addAccount(cfg);
        if (account2) {
            qDebug() << "✅ Default account 2 created (backup, no auto-login):" << account2_uri;
        } else {
            qWarning() << "Failed to create default account 2";
        }

        // 保存配置
        d->risipInstance->writeSettings();
        qDebug() << "✅ Default accounts created and saved";

        emit accountsModelChanged();
    }

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

// Account management
bool SipPhoneManager::registerAccount(const QString &sipServer,
                                     const QString &username,
                                     const QString &password,
                                     int port)
{
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
        config->setNetworkProtocol(networkProtocol);  // 0=UDP, 1=TCP, 2=TLS

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
    if (!d->currentCall) {
        qDebug() << "Call status changed but currentCall is null, ignoring";
        return;
    }

    int callState = d->currentCall->status();
    qDebug() << "Call state changed:" << callState;

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
        qDebug() << "Hanging up video call (PJSIP C API)...";

        try {
            // Find active call and hangup
            pjsua_call_id call_ids[PJSUA_MAX_CALLS];
            unsigned count = PJ_ARRAY_SIZE(call_ids);
            pj_status_t status = pjsua_enum_calls(call_ids, &count);

            if (status == PJ_SUCCESS && count > 0) {
                qDebug() << "Found" << count << "active calls, hanging up...";

                for (unsigned i = 0; i < count; ++i) {
                    pjsua_call_info ci;
                    status = pjsua_call_get_info(call_ids[i], &ci);

                    if (status == PJ_SUCCESS && ci.state != PJSIP_INV_STATE_DISCONNECTED) {
                        qDebug() << "Hanging up call ID:" << call_ids[i];
                        pjsua_call_hangup(call_ids[i], 0, NULL, NULL);
                    }
                }

                // The onCallStateChanged callback will handle UI updates when call disconnects
                qDebug() << "✅ Video call hangup command sent (waiting for callback)";

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

// Audio control
void SipPhoneManager::setMicrophoneVolume(int volume)
{
    qDebug() << "Set microphone volume:" << volume;

    // Note: Audio control through RisipMedia requires an active call
    if (!d->inCall || !d->currentCall) {
        qDebug() << "No active call for audio control";
        return;
    }

    try {
        risip::RisipMedia *media = d->currentCall->media();
        if (media) {
            // Volume range is typically 0.0 - 1.0
            // Note: RisipMedia may not have these exact methods
            // This is a placeholder - actual implementation may need adjustment
            qDebug() << "Media control not fully implemented yet";
        }
    } catch (const std::exception &ex) {
        qDebug() << "Error setting mic volume:" << ex.what();
    } catch (...) {
        qDebug() << "Unknown error setting mic volume";
    }
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
    qDebug() << "✅ Notifying video managers: Call disconnected";
    if (d->remoteVideoManager) {
        d->remoteVideoManager->onCallDisconnected();
    }
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
