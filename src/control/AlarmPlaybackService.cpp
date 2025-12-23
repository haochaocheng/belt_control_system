#include "AlarmPlaybackService.h"
#include "DataPathConfig.h"
#include <QDebug>
#include <QFile>
#include <QDateTime>
#include <QCoreApplication>
#include <QSettings>
#include <QDir>
#include <QCryptographicHash>

AlarmPlaybackService::AlarmPlaybackService(QObject *parent)
    : QObject(parent)
    , m_isRunning(false)
    , m_mediaPlayer(new QMediaPlayer(this))
    , m_audioOutput(new QAudioOutput(this))
    , m_tts(nullptr)
    , m_playTimer(new QTimer(this))
    , m_durationTimer(new QTimer(this))
    , m_isPlaying(false)
{
    qDebug() << "✅ AlarmPlaybackService: 报警播放服务已创建";

    // 连接媒体播放器到音频输出
    m_mediaPlayer->setAudioOutput(m_audioOutput);

    // 设置音量（可根据需要调整，0.0-1.0）
    m_audioOutput->setVolume(0.8);

    // 连接媒体播放器信号
    connect(m_mediaPlayer, &QMediaPlayer::playbackStateChanged,
            this, &AlarmPlaybackService::onMediaPlayerStateChanged);
    connect(m_mediaPlayer, &QMediaPlayer::errorOccurred,
            this, &AlarmPlaybackService::onMediaPlayerError);

#ifdef ENABLE_SHERPA_ONNX
    // 使用Sherpa-ONNX TTS
    qDebug() << "🎙️ 初始化 Sherpa-ONNX TTS引擎...";
    m_tts = new SherpaOnnxTTS(this);

    // 模型路径（相对于可执行文件）
    // 可选模型列表（按音质排序）：
    // 1. vits-melo-tts-zh_en      - MeloTTS，音质最好，更自然 ⭐⭐⭐⭐⭐
    // 2. vits-zh-hf-theresa       - 清晰女声，适合播报 ⭐⭐⭐⭐
    // 3. vits-zh-hf-fanchen-wnj   - 柔和女声 ⭐⭐⭐⭐
    // 4. vits-zh-aishell3         - 标准女声（当前） ⭐⭐⭐

    // 从配置文件读取模型名称（如果存在）
    QSettings settings(QCoreApplication::applicationDirPath() + "/config.ini", QSettings::IniFormat);
    settings.beginGroup("TTS");
    QString modelName = settings.value("model", "vits-zh-aishell3").toString();
    double ttsRate = settings.value("rate", 0.9).toDouble();
    double ttsVolume = settings.value("volume", 1.0).toDouble();
    settings.endGroup();

    QString modelDir = QCoreApplication::applicationDirPath() + "/tts_models/" + modelName;
    qDebug() << "  使用TTS模型:" << modelName;
    qDebug() << "  模型目录:" << modelDir;
    qDebug() << "  语速:" << ttsRate << "  音量:" << ttsVolume;

    if (m_tts->initialize(modelDir)) {
        qDebug() << "✅ Sherpa-ONNX TTS初始化成功";
        m_tts->setRate(ttsRate);    // 从配置读取
        m_tts->setVolume(ttsVolume); // 从配置读取

        connect(m_tts, &SherpaOnnxTTS::stateChanged,
                this, &AlarmPlaybackService::onTtsStateChanged);

        // 初始化TTS缓存
        initializeTtsCache();
    } else {
        qWarning() << "❌ Sherpa-ONNX TTS初始化失败，TTS功能不可用";
        qWarning() << "   请确保模型文件存在于:" << modelDir;
        delete m_tts;
        m_tts = nullptr;
    }
#else
    // 使用Qt TTS（Windows SAPI等）
    qDebug() << "🎙️ 使用 Qt TextToSpeech (系统TTS)";
    m_tts = new QTextToSpeech(this);
    m_tts->setRate(0.0);    // 语速：-1.0（慢）到 1.0（快），0.0为正常
    m_tts->setPitch(0.0);   // 音调：-1.0（低）到 1.0（高），0.0为正常
    m_tts->setVolume(0.8);  // 音量：0.0 到 1.0

    connect(m_tts, &QTextToSpeech::stateChanged,
            this, &AlarmPlaybackService::onTtsStateChanged);
#endif

    // 连接定时器
    connect(m_playTimer, &QTimer::timeout,
            this, &AlarmPlaybackService::onPlayTimerTimeout);
    connect(m_durationTimer, &QTimer::timeout,
            this, &AlarmPlaybackService::onDurationTimerTimeout);

    // 设置定时器为单次触发
    m_playTimer->setSingleShot(true);
    m_durationTimer->setSingleShot(true);
}

AlarmPlaybackService::~AlarmPlaybackService()
{
    stop();
    qDebug() << "✅ AlarmPlaybackService: 报警播放服务已销毁";
}

void AlarmPlaybackService::start()
{
    if (m_isRunning) {
        qDebug() << "⚠️  AlarmPlaybackService: 播放服务已经在运行中";
        return;
    }

    qDebug() << "🚀 AlarmPlaybackService: 启动报警播放服务";
    m_isRunning = true;
}

void AlarmPlaybackService::stop()
{
    if (!m_isRunning) {
        return;
    }

    qDebug() << "🛑 AlarmPlaybackService: 停止报警播放服务";
    m_isRunning = false;

    // 停止当前播放
    stopCurrentPlayback();

    // 清空播放队列
    m_playbackQueue.clear();
}

void AlarmPlaybackService::playAlarm(const QString &protectionName, const QString &ttsText,
                                    const QString &audioFile, bool useTextToSpeech,
                                    const QString &playMode, int playCount, double playDuration)
{
    if (!m_isRunning) {
        qWarning() << "❌ AlarmPlaybackService: 播放服务未启动";
        return;
    }

    qDebug() << "🎵 AlarmPlaybackService: 手动播放报警 -" << protectionName;
    onAlarmTriggered(protectionName, ttsText, audioFile, useTextToSpeech, playMode, playCount, playDuration);
}

void AlarmPlaybackService::onAlarmTriggered(const QString &protectionName, const QString &ttsText,
                                           const QString &audioFile, bool useTextToSpeech,
                                           const QString &playMode, int playCount, double playDuration)
{
    if (!m_isRunning) {
        return;
    }

    qDebug() << "🚨 AlarmPlaybackService: 接收到报警触发 -" << protectionName;
    qDebug() << "  TTS文本:" << ttsText;
    qDebug() << "  音频文件:" << audioFile;
    qDebug() << "  使用TTS:" << (useTextToSpeech ? "是" : "否");
    qDebug() << "  播放模式:" << playMode;
    qDebug() << "  播放次数:" << playCount;
    qDebug() << "  播放时长:" << playDuration << "秒";

    // 创建播放信息
    PlaybackInfo info;
    info.protectionName = protectionName;
    info.ttsText = ttsText;
    info.audioFile = audioFile;
    info.useTextToSpeech = useTextToSpeech;  // 使用传递的参数而不是判断 audioFile.isEmpty()
    info.playMode = playMode;
    info.playCount = playCount;
    info.currentPlayCount = 0;
    info.playDuration = playDuration;
    info.startTime = 0;

    // 如果当前没有播放，立即播放；否则加入队列
    if (!m_isPlaying) {
        m_currentPlayback = info;
        handleNextPlayback();
    } else {
        // 加入队列
        m_playbackQueue.append(info);
        qDebug() << "  当前正在播放其他报警，已加入队列（队列长度:" << m_playbackQueue.size() << "）";
    }
}

void AlarmPlaybackService::playAudioFile(const QString &audioFile)
{
    // 检查文件是否存在
    if (!QFile::exists(audioFile)) {
        qWarning() << "❌ AlarmPlaybackService: 音频文件不存在:" << audioFile;
        // 如果音频文件不存在，尝试使用TTS
        if (!m_currentPlayback.ttsText.isEmpty()) {
            qDebug() << "  尝试使用TTS播放";
            playTtsText(m_currentPlayback.ttsText);
        } else {
            // 如果也没有TTS文本，跳过此次播放
            handleNextPlayback();
        }
        return;
    }

    qDebug() << "🔊 AlarmPlaybackService: 播放音频文件:" << audioFile;

    // 检查是否是同一个音频文件（重复播放场景）
    QUrl currentSource = m_mediaPlayer->source();
    QUrl newSource = QUrl::fromLocalFile(audioFile);

    if (currentSource == newSource) {
        // 同一个文件，只需重置位置并播放
        qDebug() << "  🔄 重用音频源，重置位置到开头";
        m_mediaPlayer->setPosition(0);
    } else {
        // 不同文件，需要重新设置源
        qDebug() << "  🆕 设置新音频源";
        m_mediaPlayer->setSource(newSource);
    }

    m_mediaPlayer->play();
}

void AlarmPlaybackService::playTtsText(const QString &ttsText)
{
    if (!m_tts) {
        qWarning() << "❌ AlarmPlaybackService: TTS引擎不可用";
        handleNextPlayback();
        return;
    }

    if (ttsText.isEmpty()) {
        qWarning() << "❌ AlarmPlaybackService: TTS文本为空";
        handleNextPlayback();
        return;
    }

    qDebug() << "🗣️  AlarmPlaybackService: 播放TTS语音:" << ttsText;

    // 尝试使用缓存文件
    QString cachedFile = getCachedTtsFile(ttsText);
    if (!cachedFile.isEmpty()) {
        // 使用缓存文件直接播放（更快）
        playAudioFile(cachedFile);
    } else {
        // 回退到实时合成
        qDebug() << "  ⚠️  缓存未命中，使用实时合成";
        m_tts->say(ttsText);
    }
}

void AlarmPlaybackService::stopCurrentPlayback()
{
    // 停止媒体播放器
    if (m_mediaPlayer->playbackState() != QMediaPlayer::StoppedState) {
        m_mediaPlayer->stop();
    }

    // 停止TTS
    if (m_tts) {
#ifdef ENABLE_SHERPA_ONNX
        if (m_tts->state() != SherpaOnnxTTS::Ready) {
            m_tts->stop();
        }
#else
        if (m_tts->state() != QTextToSpeech::Ready) {
            m_tts->stop();
        }
#endif
    }

    // 停止定时器
    m_playTimer->stop();
    m_durationTimer->stop();

    m_isPlaying = false;
}

void AlarmPlaybackService::handleNextPlayback()
{
    // 根据播放模式选择不同的处理逻辑
    if (m_currentPlayback.playMode == "count") {
        // ========== 按次数播放模式 ==========
        // 增加播放计数
        m_currentPlayback.currentPlayCount++;

        // 检查是否达到播放次数
        if (m_currentPlayback.playCount > 0 &&
            m_currentPlayback.currentPlayCount > m_currentPlayback.playCount) {
            qDebug() << "✅ AlarmPlaybackService: 播放次数已达到（"
                     << m_currentPlayback.playCount << "次），停止播放";
            emit alarmPlaybackFinished(m_currentPlayback.protectionName);

            // 检查队列中是否还有待播放的报警
            if (!m_playbackQueue.isEmpty()) {
                m_currentPlayback = m_playbackQueue.takeFirst();
                qDebug() << "  从队列中取出下一个报警:" << m_currentPlayback.protectionName
                         << "（剩余队列长度:" << m_playbackQueue.size() << "）";
                m_currentPlayback.currentPlayCount = 0;
                handleNextPlayback();
            } else {
                m_isPlaying = false;
            }
            return;
        }

        // 继续播放
        m_isPlaying = true;

        if (m_currentPlayback.currentPlayCount == 1) {
            // 首次播放，发射信号
            emit alarmPlaybackStarted(m_currentPlayback.protectionName);
        }

        // 根据配置选择播放方式
        if (m_currentPlayback.useTextToSpeech) {
            playTtsText(m_currentPlayback.ttsText);
        } else {
            playAudioFile(m_currentPlayback.audioFile);
        }

    } else if (m_currentPlayback.playMode == "duration") {
        // ========== 按时长播放模式 ==========
        // 增加播放计数（用于首次播放判断）
        m_currentPlayback.currentPlayCount++;

        if (m_currentPlayback.playDuration > 0) {
            if (m_currentPlayback.startTime == 0) {
                // 首次播放，记录开始时间
                m_currentPlayback.startTime = QDateTime::currentMSecsSinceEpoch();

                // 启动持续播放定时器
                int durationMs = static_cast<int>(m_currentPlayback.playDuration * 1000);
                m_durationTimer->start(durationMs);
                qDebug() << "  启动持续播放定时器:" << durationMs << "ms（"
                         << m_currentPlayback.playDuration << "秒）";
            } else {
                // 检查是否超过持续时长
                qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
                qint64 elapsed = currentTime - m_currentPlayback.startTime;
                if (elapsed >= m_currentPlayback.playDuration * 1000) {
                    qDebug() << "✅ AlarmPlaybackService: 播放时长已到（"
                             << m_currentPlayback.playDuration << "秒），停止播放";
                    emit alarmPlaybackFinished(m_currentPlayback.protectionName);

                    // 停止持续播放定时器
                    m_durationTimer->stop();

                    // 检查队列
                    if (!m_playbackQueue.isEmpty()) {
                        m_currentPlayback = m_playbackQueue.takeFirst();
                        qDebug() << "  从队列中取出下一个报警:" << m_currentPlayback.protectionName;
                        m_currentPlayback.currentPlayCount = 0;
                        handleNextPlayback();
                    } else {
                        m_isPlaying = false;
                    }
                    return;
                }
            }
        }

        // 继续播放
        m_isPlaying = true;

        if (m_currentPlayback.currentPlayCount == 1) {
            // 首次播放，发射信号
            emit alarmPlaybackStarted(m_currentPlayback.protectionName);
        }

        // 根据配置选择播放方式
        if (m_currentPlayback.useTextToSpeech) {
            playTtsText(m_currentPlayback.ttsText);
        } else {
            playAudioFile(m_currentPlayback.audioFile);
        }
    } else {
        // 未知播放模式，记录错误
        qWarning() << "❌ AlarmPlaybackService: 未知播放模式:" << m_currentPlayback.playMode;
        m_isPlaying = false;
    }
}

void AlarmPlaybackService::onMediaPlayerStateChanged(QMediaPlayer::PlaybackState state)
{
    qDebug() << "📻 AlarmPlaybackService: 媒体播放器状态变化:" << state;

    if (state == QMediaPlayer::StoppedState) {
        // 播放结束，延时后进行下一次播放
        // 延时500ms，避免播放过快
        m_playTimer->start(500);
    }
}

void AlarmPlaybackService::onMediaPlayerError(QMediaPlayer::Error error, const QString &errorString)
{
    qWarning() << "❌ AlarmPlaybackService: 媒体播放器错误:" << error << errorString;

    // 发生错误，尝试下一次播放
    m_playTimer->start(500);
}

#ifdef ENABLE_SHERPA_ONNX
void AlarmPlaybackService::onTtsStateChanged(SherpaOnnxTTS::State state)
{
    qDebug() << "🗣️  AlarmPlaybackService: TTS状态变化:" << state;

    if (state == SherpaOnnxTTS::Ready) {
        // TTS播放结束，延时后进行下一次播放
        m_playTimer->start(500);
    }
}
#else
void AlarmPlaybackService::onTtsStateChanged(QTextToSpeech::State state)
{
    qDebug() << "🗣️  AlarmPlaybackService: TTS状态变化:" << state;

    if (state == QTextToSpeech::Ready) {
        // TTS播放结束，延时后进行下一次播放
        m_playTimer->start(500);
    }
}
#endif

void AlarmPlaybackService::onPlayTimerTimeout()
{
    // 定时器到期，进行下一次播放
    handleNextPlayback();
}

void AlarmPlaybackService::onDurationTimerTimeout()
{
    // 持续播放时长到期，停止播放
    qDebug() << "⏰ AlarmPlaybackService: 持续播放时长到期";

    // 停止当前播放
    stopCurrentPlayback();

    // 发射完成信号
    emit alarmPlaybackFinished(m_currentPlayback.protectionName);

    // 检查队列
    if (!m_playbackQueue.isEmpty()) {
        m_currentPlayback = m_playbackQueue.takeFirst();
        qDebug() << "  从队列中取出下一个报警:" << m_currentPlayback.protectionName;
        m_currentPlayback.currentPlayCount = 0;
        handleNextPlayback();
    } else {
        m_isPlaying = false;
    }
}

// TTS缓存相关函数实现

void AlarmPlaybackService::initializeTtsCache()
{
    qDebug() << "🗂️  AlarmPlaybackService: 初始化TTS缓存";

    // ✅ 使用统一数据路径配置（持久化到Docker卷）
    m_ttsCacheDir = DataPathConfig::getTtsCacheDirectory();
    qDebug() << "  TTS缓存目录（持久化）:" << m_ttsCacheDir;

    // 预缓存常用报警文本
    QStringList commonTexts;
    commonTexts << "急停保护报警"
                << "主机急停保护报警"
                << "沿线急停"
                << "打滑保护报警"
                << "跑偏保护报警"
                << "堆煤保护报警"
                << "撕裂保护报警"
                << "超速保护报警"
                << "低速保护报警"
                << "温度保护报警";

    qDebug() << "  开始预缓存" << commonTexts.size() << "个常用报警文本...";

    for (const QString &text : commonTexts) {
        precacheTtsText(text);
    }

    qDebug() << "✅ TTS缓存初始化完成，已缓存" << m_ttsCache.size() << "个文本";
}

QString AlarmPlaybackService::getCachedTtsFile(const QString &text)
{
    // 检查缓存
    if (m_ttsCache.contains(text)) {
        QString cachedFile = m_ttsCache[text];
        if (QFile::exists(cachedFile)) {
            qDebug() << "  ⚡ 使用缓存文件:" << cachedFile;
            return cachedFile;
        } else {
            // 缓存文件已不存在，重新生成
            m_ttsCache.remove(text);
        }
    }

    // 生成缓存文件
    QString hash = QString(QCryptographicHash::hash(text.toUtf8(), QCryptographicHash::Md5).toHex());
    QString cachedFile = m_ttsCacheDir + "/" + hash + ".wav";

#ifdef ENABLE_SHERPA_ONNX
    if (m_tts && m_tts->synthesizeToFile(text, cachedFile)) {
        m_ttsCache[text] = cachedFile;
        qDebug() << "  ✅ 生成并缓存TTS文件:" << cachedFile;
        return cachedFile;
    }
#endif

    return QString();  // 合成失败
}

void AlarmPlaybackService::precacheTtsText(const QString &text)
{
    // 生成文件名（使用MD5哈希）
    QString hash = QString(QCryptographicHash::hash(text.toUtf8(), QCryptographicHash::Md5).toHex());
    QString cachedFile = m_ttsCacheDir + "/" + hash + ".wav";

    // 如果已存在，直接加入缓存映射
    if (QFile::exists(cachedFile)) {
        m_ttsCache[text] = cachedFile;
        qDebug() << "  ✓ 已存在:" << text;
        return;
    }

    // 生成缓存文件
#ifdef ENABLE_SHERPA_ONNX
    if (m_tts && m_tts->synthesizeToFile(text, cachedFile)) {
        m_ttsCache[text] = cachedFile;
        qDebug() << "  ✅ 已缓存:" << text;
    } else {
        qWarning() << "  ❌ 缓存失败:" << text;
    }
#endif
}
