#ifndef SIPPHONEMANAGER_H
#define SIPPHONEMANAGER_H

#include <QObject>
#include <QString>
#include <QDateTime>
#include <QWindow>

/**
 * @brief SIP Phone Manager - Main entry point for SIP functionality
 *
 * This class manages the SIP phone system including:
 * - SIP endpoint initialization
 * - Account registration
 * - Call management
 * - Audio/video handling
 *
 * Based on risip architecture wrapping PJSIP
 */
class SipPhoneManager : public QObject
{
    Q_OBJECT

    // Properties exposed to QML
    Q_PROPERTY(bool isInitialized READ isInitialized NOTIFY isInitializedChanged)
    Q_PROPERTY(bool isRegistered READ isRegistered NOTIFY isRegisteredChanged)
    Q_PROPERTY(bool isInCall READ isInCall NOTIFY isInCallChanged)
    Q_PROPERTY(QString callStatus READ callStatus NOTIFY callStatusChanged)
    Q_PROPERTY(QString currentNumber READ currentNumber WRITE setCurrentNumber NOTIFY currentNumberChanged)
    Q_PROPERTY(QString callerDisplayName READ callerDisplayName WRITE setCallerDisplayName NOTIFY callerDisplayNameChanged)
    Q_PROPERTY(bool isIncomingVideoCall READ isIncomingVideoCall NOTIFY isIncomingVideoCallChanged)
    Q_PROPERTY(bool isCurrentCallVideo READ isCurrentCallVideo NOTIFY isCurrentCallVideoChanged)
    Q_PROPERTY(int callDuration READ callDuration NOTIFY callDurationChanged)
    Q_PROPERTY(QString serverStatus READ serverStatus NOTIFY serverStatusChanged)
    Q_PROPERTY(QObject* accountsModel READ accountsModel NOTIFY accountsModelChanged)
    Q_PROPERTY(QObject* videoCallManager READ videoCallManager CONSTANT)
    Q_PROPERTY(QObject* qtVideoPreview READ qtVideoPreview CONSTANT)
    Q_PROPERTY(QObject* localVideoManager READ localVideoManager CONSTANT)
    Q_PROPERTY(QObject* remoteVideoManager READ remoteVideoManager CONSTANT)

public:
    explicit SipPhoneManager(QObject *parent = nullptr);
    ~SipPhoneManager();

    // Static singleton instance
    static SipPhoneManager* instance();
    static void registerToQml();

    // Property getters
    bool isInitialized() const;
    bool isRegistered() const;
    bool isInCall() const;
    QString callStatus() const;
    QString currentNumber() const;
    QString callerDisplayName() const;
    bool isIncomingVideoCall() const;
    bool isCurrentCallVideo() const;
    int callDuration() const;
    QString serverStatus() const;
    QObject* accountsModel() const;
    QObject* videoCallManager() const;
    QObject* qtVideoPreview() const;
    QObject* localVideoManager() const;
    QObject* remoteVideoManager() const;

    // Property setters
    void setCurrentNumber(const QString &number);
    void setCallerDisplayName(const QString &name);

public slots:
    // SIP endpoint control
    bool initializeEndpoint();
    void shutdownEndpoint();

    // Account management
    bool registerAccount(const QString &sipServer,
                        const QString &username,
                        const QString &password,
                        int port = 5060);
    void unregisterAccount();

    // Multi-account management (uses Risip's built-in account model)
    QObject* getAllAccountsModel();  // Returns QAbstractItemModel* as QObject*
    bool removeAccount(const QString &accountUri);
    bool setAsDefaultAccount(const QString &accountUri);
    bool loginExistingAccount(const QString &accountUri);  // Login to an existing saved account

    // Create new account (like Risip.createAccount)
    bool createAccount(const QString &username,
                      const QString &password,
                      const QString &serverAddress,
                      const QString &proxyServer = QString(),
                      int localPort = 5060,
                      int networkProtocol = 0);  // 0=UDP, 1=TCP, 2=TLS

    // Auto sign-in management
    bool getAutoSignIn() const;
    void setAutoSignInEnabled(bool enabled);

    // Call history management (uses Risip's built-in call history model)
    QObject* getCallHistoryModel();  // Returns current account's call history model
    Q_INVOKABLE void deleteCallHistoryRecord(int index);  // Delete a call history record by index

    // Contact management (联系人管理)
    Q_INVOKABLE QString getContactName(const QString &number);  // 根据号码查找联系人名字
    Q_INVOKABLE bool addContact(const QString &name, const QString &number);  // 添加联系人
    Q_INVOKABLE bool updateContact(int id, const QString &name, const QString &number);  // 更新联系人
    Q_INVOKABLE bool deleteContact(int id);  // 删除联系人
    Q_INVOKABLE QVariantList getAllContacts();  // 获取所有联系人（返回格式：[{name:"小七", number:"1006"}, ...]）

    // Call control
    void makeCall(const QString &number);          // Audio-only call (convenience wrapper)
    Q_INVOKABLE void makeCall(const QString &number, bool enableVideo);  // Unified call method with video flag
    void makeVideoCall(const QString &number);     // Video call (convenience wrapper)
    void answerCall();                             // Answer incoming call (video if offered, audio otherwise)
    void answerCallAsAudio();                      // Answer incoming call as audio-only (decline video)
    void hangupCall();
    void holdCall(bool hold);
    void transferCall(const QString &targetNumber);

    // Audio control
    void setMicrophoneVolume(int volume);  // 0-100
    void setSpeakerVolume(int volume);     // 0-100
    void muteMicrophone(bool mute);

    // DTMF (dial tone)
    void sendDtmf(const QString &digits);

    // Ringtone management (铃声管理)
    Q_INVOKABLE QString getRingtonePath();      // Get current ringtone path
    Q_INVOKABLE bool selectAndSetRingtone();    // Open file dialog and set custom ringtone
    Q_INVOKABLE QString getRingtoneFilename();  // Get ringtone filename (display only)

    // Video preview control (本机视频预览)
    void startVideoPreview();      // 开始本机视频预览
    void stopVideoPreview();       // 停止本机视频预览
    bool isVideoPreviewActive() const;  // 检查预览是否正在运行
    Q_INVOKABLE QWidget* getVideoPreviewWidget();  // 获取视频预览Widget(用于嵌入Qt界面)

    // ✅ Call timer control (must be slots for QMetaObject::invokeMethod to work from PJSIP thread)
    void startCallTimer();   // Start call duration timer
    void stopCallTimer();    // Stop call duration timer

signals:
    // Status signals
    void isInitializedChanged(bool initialized);
    void isRegisteredChanged(bool registered);
    void isInCallChanged(bool inCall);
    void callStatusChanged(const QString &status);
    void currentNumberChanged(const QString &number);
    void callerDisplayNameChanged(const QString &name);
    void isIncomingVideoCallChanged(bool isVideoCall);
    void isCurrentCallVideoChanged(bool isVideoCall);
    void callDurationChanged(int duration);
    void serverStatusChanged(const QString &status);
    void accountsModelChanged();
    void ringtonePathChanged(const QString &ringtonePath);  // 铃声路径变化

    // Event signals
    void incomingCall(const QString &callerNumber, const QString &callerName);
    void callConnected();
    void callDisconnected();
    void registrationSuccess();
    void registrationFailed(const QString &reason);
    void callFailed(const QString &reason);

    // Error signals
    void errorOccurred(const QString &errorMessage);

public:
    // ✅ Public methods for call state callback to update UI
    void setInCall(bool inCall);
    void updateCallStatus(const QString &status);
    void setIsIncomingVideoCall(bool isVideoCall);  // Update incoming video call flag
    void setIsCurrentCallVideo(bool isVideoCall);   // Update current call video flag
    void notifyCallConnected(int callId);  // Notify video managers of call connected
    void notifyCallDisconnected();         // Notify video managers of call disconnected
    void activatePendingVideo(int call_id);  // ✅ ATTEMPT 13: Activate video via CHANGE_DIR

private:
    class Private;
    Private *d;

    static SipPhoneManager *m_instance;

    // Helper methods
    void updateServerStatus(const QString &status);
    void configureAccountVideoDevice(const QString &accountUri);  // Configure video device for an account by URI
    void handleCallStatusChange(bool isVideoCall);  // Handle call status changes for both audio and video calls
    QString extractPhoneNumber(const QString &contact);  // Extract phone number from contact string (e.g., "Extension 1006" 1006 -> 1006)
};

#endif // SIPPHONEMANAGER_H
