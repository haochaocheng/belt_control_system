#ifndef CROSSPLATFORMTTS_H
#define CROSSPLATFORMTTS_H

#include <QObject>
#include <QString>
#include <QTextToSpeech>
#include <QProcess>

/**
 * @brief 跨平台TTS管理器
 *
 * 支持多种TTS后端：
 * - Windows: QTextToSpeech (使用Windows SAPI)
 * - Linux (x86_64): QTextToSpeech + speech-dispatcher
 * - Linux (ARM64/RK3588): eSpeak-NG / sherpa-onnx / 在线API
 */
class CrossPlatformTTS : public QObject
{
    Q_OBJECT

public:
    enum TTSBackend {
        QtTTS,           // Qt QTextToSpeech (Windows/Linux with speech-dispatcher)
        ESpeak,          // eSpeak-NG (轻量级，适合嵌入式)
        SherpaOnnx,      // sherpa-onnx (高质量中文，离线)
        OnlineAPI        // 在线TTS API (百度/讯飞等)
    };

    explicit CrossPlatformTTS(QObject *parent = nullptr);
    ~CrossPlatformTTS();

    // 初始化TTS引擎
    bool initialize();

    // 播放文字
    void say(const QString &text);

    // 停止播放
    void stop();

    // 设置参数
    void setRate(double rate);      // 语速 (-1.0 to 1.0)
    void setPitch(double pitch);    // 音调 (-1.0 to 1.0)
    void setVolume(double volume);  // 音量 (0.0 to 1.0)

    // 获取当前后端
    TTSBackend currentBackend() const { return m_backend; }

    // 检查TTS是否可用
    bool isAvailable() const;

signals:
    void stateChanged(int state);  // 状态变化信号（兼容QTextToSpeech）

private:
    // 自动检测可用的TTS后端
    TTSBackend detectBestBackend();

    // Qt TTS后端
    void sayWithQt(const QString &text);
    void stopQt();

    // eSpeak后端
    void sayWithESpeak(const QString &text);
    void stopESpeak();

    // sherpa-onnx后端
    void sayWithSherpa(const QString &text);
    void stopSherpa();

    // 在线API后端
    void sayWithOnlineAPI(const QString &text);

private slots:
    void onQtTtsStateChanged(QTextToSpeech::State state);
    void onProcessFinished(int exitCode);

private:
    TTSBackend m_backend;

    // Qt TTS
    QTextToSpeech *m_qtTts;

    // 外部进程(eSpeak, sherpa-onnx等)
    QProcess *m_process;

    // TTS参数
    double m_rate;
    double m_pitch;
    double m_volume;

    // 是否可用
    bool m_available;
};

#endif // CROSSPLATFORMTTS_H
