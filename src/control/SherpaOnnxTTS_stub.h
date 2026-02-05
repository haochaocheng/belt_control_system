// ❌ 2026-01-24: Windows 平台 SherpaOnnxTTS 空实现（临时方案）
// 目的：避免修改大量代码，提供空实现让 Windows 编译通过
// 注意：这是临时方案，后续需要完整实现或条件编译

#ifdef _WIN32

#ifndef SHERPAONNXTTS_H
#define SHERPAONNXTTS_H

#include <QObject>
#include <QString>

// 前向声明
class AudioNetworkTcpSender;
class AudioNetworkSender;

class SherpaOnnxTTS : public QObject
{
    Q_OBJECT

public:
    enum State {
        Uninitialized,
        Ready,
        Synthesizing,
        Playing,
        Error
    };
    Q_ENUM(State)

    explicit SherpaOnnxTTS(QObject *parent = nullptr) : QObject(parent) {}
    ~SherpaOnnxTTS() {}

    // 空实现
    bool initialize(const QString &) { return false; }
    void setTcpSender(AudioNetworkTcpSender *) {}
    void setUdpSender(AudioNetworkSender *) {}
    void sayToNetwork(const QString &, bool) {}
    QString getCacheFilePath(const QString &) const { return QString(); }
    bool synthesizeToFile(const QString &, const QString &) { return false; }
    State state() const { return Uninitialized; }
    void say(const QString &) {}
    void switchModel(const QString &) {}
    void setSceneName(const QString &) {}
    void setSpeakerId(int) {}
    void setRate(double) {}
    void setVolume(double) {}

signals:
    void networkTransmissionFinished();
    void localPlaybackFinished();

public:
    static const QMetaObject staticMetaObject;
};

#endif // SHERPAONNXTTS_H

#endif // _WIN32
