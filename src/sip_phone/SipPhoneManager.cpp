#include "SipPhoneManager.h"
#include <QDebug>
#include <QTimer>
#include <QQmlEngine>
#include <QJSEngine>
#include <QQmlContext>

// Undefine UNICODE before including PJSIP headers to avoid string function errors
#ifdef UNICODE
#undef UNICODE
#endif
#ifdef _UNICODE
#undef _UNICODE
#endif

// Risip SDK headers
#include "risipendpoint.h"
#include "risipcall.h"
#include "risipaccount.h"
#include "risipaccountconfiguration.h"
#include "risipcallmanager.h"
#include "risip.h"

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
        , callDuration(0)
        , callTimer(nullptr)
        , risipInstance(nullptr)
        , currentAccount(nullptr)
        , currentCall(nullptr)
    {
        callTimer = new QTimer(parent);
        callTimer->setInterval(1000);

        // Create Risip singleton instance
        risipInstance = risip::Risip::instance();
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
    int callDuration;

    // Timer for call duration
    QTimer *callTimer;

    // Risip components
    risip::Risip *risipInstance;
    risip::RisipAccount *currentAccount;
    risip::RisipCall *currentCall;
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

int SipPhoneManager::callDuration() const
{
    return d->callDuration;
}

QString SipPhoneManager::serverStatus() const
{
    return d->serverStatus;
}

void SipPhoneManager::setCurrentNumber(const QString &number)
{
    if (d->currentNumber != number) {
        d->currentNumber = number;
        emit currentNumberChanged(number);
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

    // CRITICAL ISSUE: PJSIP compiled with incorrect configuration for this Windows system
    // Error: "Assertion failed: sizeof(pj_fd_set_t)-sizeof(pj_sock_t) >= sizeof(fd_set)"
    // Location: pjlib/src/pj/sock_select.c, line 45
    //
    // ROOT CAUSE: The PJSIP library was compiled with socket configuration that doesn't
    // match the current Windows SDK's fd_set structure size. This is a compile-time
    // configuration mismatch between PJSIP's expectations and Windows headers.
    //
    // SOLUTION REQUIRED: Recompile PJSIP 2.15.1 with correct Windows configuration:
    // - Ensure PJ_IOQUEUE_MAX_HANDLES matches system capabilities
    // - Update config_site.h for Windows 10/11 compatibility
    // - Or use different select/poll mechanism (e.g., IOCP for Windows)
    //
    // TEMPORARY WORKAROUND: Disable PJSIP initialization to allow UI to function

    qWarning() << "==========================================================";
    qWarning() << "PJSIP INITIALIZATION DISABLED";
    qWarning() << "Reason: PJSIP library configuration mismatch";
    qWarning() << "Error: sizeof(pj_fd_set_t) assertion in sock_select.c:45";
    qWarning() << "This requires recompiling PJSIP with correct Windows config";
    qWarning() << "SIP telephone functionality will NOT work";
    qWarning() << "==========================================================";

    d->initialized = true;
    emit isInitializedChanged(true);
    updateServerStatus("SIP引擎配置错误（需要重新编译PJSIP）");

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

        // Build SIP URI: sip:username@server:port
        QString sipUri = QString("sip:%1@%2:%3").arg(username, sipServer).arg(port);
        config->setUri(sipUri);
        config->setUserName(username);
        config->setPassword(password);

        // Create and register account
        d->currentAccount = d->risipInstance->createAccount(config);

        if (!d->currentAccount) {
            qDebug() << "Failed to create account";
            emit errorOccurred("创建账户失败");
            delete config;
            return false;
        }

        // Connect account status signals
        connect(d->currentAccount, &risip::RisipAccount::statusChanged, this, [this]() {
            int status = d->currentAccount->status();
            qDebug() << "Account status changed:" << status;

            if (status == 200) { // SIP 200 OK = Registered
                d->registered = true;
                emit isRegisteredChanged(true);
                emit registrationSuccess();
                updateServerStatus(QString("已连接: %1").arg(d->currentAccount->configuration()->uri()));
                qDebug() << "Account registered successfully";
            } else if (status >= 400) { // Error status
                d->registered = false;
                emit isRegisteredChanged(false);
                QString reason = d->currentAccount->statusText();
                emit registrationFailed(reason);
                updateServerStatus("注册失败: " + reason);
                qDebug() << "Registration failed:" << status << reason;
            }
        });

        // Start registration
        d->currentAccount->login();

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

void SipPhoneManager::unregisterAccount()
{
    if (!d->registered || !d->currentAccount) {
        return;
    }

    qDebug() << "Unregistering account...";

    try {
        d->currentAccount->logout();

        // Delete the account
        d->risipInstance->removeAccount(d->currentAccount->configuration()->uri());
        d->currentAccount = nullptr;

    } catch (const std::exception &ex) {
        qDebug() << "Error unregistering:" << ex.what();
    } catch (...) {
        qDebug() << "Unknown error during unregister";
    }

    d->registered = false;
    emit isRegisteredChanged(false);
    updateServerStatus("SIP引擎已启动");
    qDebug() << "Account unregistered";
}

// Call control
void SipPhoneManager::makeCall(const QString &number)
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

    qDebug() << "Making call to:" << number;

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

        // Create call
        d->currentCall = callManager->callPhone(number);

        if (!d->currentCall) {
            qDebug() << "Failed to create call";
            emit callFailed("创建呼叫失败");
            return;
        }

        setCurrentNumber(number);
        updateCallStatus("拨号中");

        // Connect call status signals
        connect(d->currentCall, &risip::RisipCall::statusChanged, this, [this]() {
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
                updateCallStatus("通话中");
                d->callDuration = 0;
                d->callTimer->start();
                qDebug() << "Call connected";
            } else if (callState == risip::RisipCall::CallDisconnected) {
                hangupCall();
            } else if (callState == risip::RisipCall::CallEarly) {
                updateCallStatus("振铃中");
            }
        });

        qDebug() << "Call initiated";

    } catch (const std::exception &ex) {
        QString error = QString("呼叫异常: %1").arg(ex.what());
        qDebug() << error;
        emit callFailed(error);
    } catch (...) {
        qDebug() << "Unknown error making call";
        emit callFailed("未知错误");
    }
}

void SipPhoneManager::answerCall()
{
    if (!d->currentCall) {
        qDebug() << "No incoming call to answer";
        return;
    }

    qDebug() << "Answering incoming call...";

    try {
        d->currentCall->answer();

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
}

void SipPhoneManager::hangupCall()
{
    if (!d->currentCall) {
        return;
    }

    qDebug() << "Hanging up call...";

    try {
        d->callTimer->stop();

        // Hangup the call
        d->currentCall->hangup();
        d->currentCall = nullptr;

        d->inCall = false;
        emit isInCallChanged(false);
        emit callDisconnected();
        updateCallStatus("就绪");
        d->callDuration = 0;
        emit callDurationChanged(0);

        qDebug() << "Call ended";

    } catch (const std::exception &ex) {
        qDebug() << "Error hanging up:" << ex.what();
    } catch (...) {
        qDebug() << "Unknown error hanging up";
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

// Helper methods
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
