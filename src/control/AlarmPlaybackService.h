#ifndef ALARMPLAYBACKSERVICE_H
#define ALARMPLAYBACKSERVICE_H

#include <QObject>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QTimer>
#include <QMap>

// 条件包含：如果启用了sherpa-onnx就使用，否则使用Qt TTS
#ifdef ENABLE_SHERPA_ONNX
#include "SherpaOnnxTTS.h"
typedef SherpaOnnxTTS TTSEngine;
#else
#include <QTextToSpeech>
typedef QTextToSpeech TTSEngine;
#endif

/**
 * @brief 报警播放服务 - 处理报警音频播放（音频文件 + TTS）
 *
 * 功能：
 * - 接收保护监控服务的报警触发信号
 * - 根据配置播放音频文件或TTS语音
 * - 支持重复播放（playCount）
 * - 支持持续播放时长（playDuration）
 * - 管理播放队列，避免同时播放多个报警
 */
class AlarmPlaybackService : public QObject
{
    Q_OBJECT

public:
    explicit AlarmPlaybackService(QObject *parent = nullptr);
    ~AlarmPlaybackService();

    // 启动/停止服务
    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE bool isRunning() const { return m_isRunning; }

    // 手动播放报警（用于测试）
    Q_INVOKABLE void playAlarm(const QString &protectionName, const QString &ttsText,
                                const QString &audioFile, bool useTextToSpeech,
                                const QString &playMode, int playCount, double playDuration);

public slots:
    // 接收报警触发信号
    void onAlarmTriggered(const QString &protectionName, const QString &ttsText,
                         const QString &audioFile, bool useTextToSpeech,
                         const QString &playMode, int playCount, double playDuration);

signals:
    // 报警播放开始
    void alarmPlaybackStarted(const QString &protectionName);

    // 报警播放结束
    void alarmPlaybackFinished(const QString &protectionName);

private slots:
    // 媒体播放器状态变化
    void onMediaPlayerStateChanged(QMediaPlayer::PlaybackState state);

    // 媒体播放器错误
    void onMediaPlayerError(QMediaPlayer::Error error, const QString &errorString);

    // TTS语音状态变化
#ifdef ENABLE_SHERPA_ONNX
    void onTtsStateChanged(SherpaOnnxTTS::State state);
#else
    void onTtsStateChanged(QTextToSpeech::State state);
#endif

    // 播放定时器超时（用于重复播放和持续播放）
    void onPlayTimerTimeout();

    // 持续播放定时器超时
    void onDurationTimerTimeout();

private:
    // 播放音频文件
    void playAudioFile(const QString &audioFile);

    // 播放TTS语音
    void playTtsText(const QString &ttsText);

    // 停止当前播放
    void stopCurrentPlayback();

    // 处理下一个播放（重复播放或持续播放）
    void handleNextPlayback();

    // TTS缓存相关
    void initializeTtsCache();  // 初始化TTS缓存
    QString getCachedTtsFile(const QString &text);  // 获取缓存的TTS文件
    void precacheTtsText(const QString &text);  // 预缓存TTS文本

private:
    // 运行状态
    bool m_isRunning;

    // Qt多媒体组件
    QMediaPlayer *m_mediaPlayer;
    QAudioOutput *m_audioOutput;
    TTSEngine *m_tts;

    // 当前播放信息
    struct PlaybackInfo {
        QString protectionName;
        QString ttsText;
        QString audioFile;
        bool useTextToSpeech;
        QString playMode;          // 播放模式："count" 或 "duration"
        int playCount;
        int currentPlayCount;
        double playDuration;
        qint64 startTime;  // 播放开始时间（毫秒）
    };
    PlaybackInfo m_currentPlayback;

    // 定时器
    QTimer *m_playTimer;       // 重复播放定时器
    QTimer *m_durationTimer;   // 持续播放定时器

    // 播放队列（用于管理多个报警）
    QList<PlaybackInfo> m_playbackQueue;

    // 播放状态
    bool m_isPlaying;

    // TTS缓存
    QMap<QString, QString> m_ttsCache;  // 文本 -> 缓存文件路径
    QString m_ttsCacheDir;  // TTS缓存目录
};

#endif // ALARMPLAYBACKSERVICE_H
