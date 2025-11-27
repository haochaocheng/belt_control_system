#ifndef SIPPHONEMANAGER_H
#define SIPPHONEMANAGER_H

#include <QObject>
#include <QString>
#include <QDateTime>

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
    Q_PROPERTY(int callDuration READ callDuration NOTIFY callDurationChanged)
    Q_PROPERTY(QString serverStatus READ serverStatus NOTIFY serverStatusChanged)

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
    int callDuration() const;
    QString serverStatus() const;

    // Property setters
    void setCurrentNumber(const QString &number);

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

    // Call control
    void makeCall(const QString &number);
    void answerCall();
    void hangupCall();
    void holdCall(bool hold);
    void transferCall(const QString &targetNumber);

    // Audio control
    void setMicrophoneVolume(int volume);  // 0-100
    void setSpeakerVolume(int volume);     // 0-100
    void muteMicrophone(bool mute);

    // DTMF (dial tone)
    void sendDtmf(const QString &digits);

signals:
    // Status signals
    void isInitializedChanged(bool initialized);
    void isRegisteredChanged(bool registered);
    void isInCallChanged(bool inCall);
    void callStatusChanged(const QString &status);
    void currentNumberChanged(const QString &number);
    void callDurationChanged(int duration);
    void serverStatusChanged(const QString &status);

    // Event signals
    void incomingCall(const QString &callerNumber, const QString &callerName);
    void callConnected();
    void callDisconnected();
    void registrationSuccess();
    void registrationFailed(const QString &reason);
    void callFailed(const QString &reason);

    // Error signals
    void errorOccurred(const QString &errorMessage);

private:
    class Private;
    Private *d;

    static SipPhoneManager *m_instance;

    // Helper methods
    void updateCallStatus(const QString &status);
    void updateServerStatus(const QString &status);
};

#endif // SIPPHONEMANAGER_H
