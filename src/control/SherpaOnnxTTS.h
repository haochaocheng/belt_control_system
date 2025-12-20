#ifndef SHERPAONNXTTS_H
#define SHERPAONNXTTS_H

#include <QObject>
#include <QString>
#include <QThread>
#include <QMutex>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QFile>
#include <QTemporaryFile>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <vector>
#include <cstdint>

/**
 * @brief Sherpa-ONNX TTS 封装类（进程通信版本）
 *
 * 通过 QProcess 与 MSVC 编译的 Sherpa-ONNX TTS 服务通信
 * 解决 MinGW/MSVC ABI 不兼容问题
 *
 * 架构:
 * - 主程序: MinGW 编译
 * - TTS 服务: MSVC 编译的独立进程 (sherpa_tts_service.exe)
 * - 通信: JSON via stdin/stdout
 *
 * 支持Windows和Linux(ARM64/x86_64)
 */
class SherpaOnnxTTS : public QObject
{
    Q_OBJECT

public:
    enum State {
        Ready = 0,
        Speaking = 1,
        Paused = 2,
        Error = 3
    };
    Q_ENUM(State)

    explicit SherpaOnnxTTS(QObject *parent = nullptr);
    ~SherpaOnnxTTS();

    // 初始化TTS引擎（加载模型）
    bool initialize(const QString &modelDir);

    // TTS操作
    void say(const QString &text);
    void stop();

    // 合成到文件（用于缓存）
    bool synthesizeToFile(const QString &text, const QString &outputFile);

    // 设置参数
    void setRate(double rate);      // 语速 (0.5 - 2.0)
    void setPitch(double pitch);    // 音调 (暂不支持)
    void setVolume(double volume);  // 音量 (0.0 - 1.0)

    // 状态查询
    State state() const { return m_state; }
    bool isAvailable() const { return m_available; }

signals:
    void stateChanged(SherpaOnnxTTS::State state);

private slots:
    void onMediaPlayerStateChanged(QMediaPlayer::PlaybackState state);
    void onProcessReadyRead();
    void onProcessError(QProcess::ProcessError error);

private:
    // 发送命令到TTS服务
    bool sendCommand(const QJsonObject &command, QJsonObject &response, int timeoutMs = 30000);

    // 合成语音（通过TTS服务）
    bool synthesize(const QString &text, const QString &outputPath);

    // 设置状态
    void setState(State newState);

private:
    // TTS服务进程
    QProcess *m_ttsProcess;
    QString m_serviceExecutable;

    // 播放器
    QMediaPlayer *m_mediaPlayer;
    QAudioOutput *m_audioOutput;

    // 状态
    State m_state;
    bool m_available;

    // 参数
    double m_rate;
    double m_volume;

    // 模型路径
    QString m_modelDir;

    // 线程安全
    QMutex m_mutex;

    // 响应缓冲区
    QString m_responseBuffer;
};

#endif // SHERPAONNXTTS_H
