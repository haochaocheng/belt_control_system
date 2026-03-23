#include "CommonControl.h"
#include "SystemConfig.h"
#include "DeviceConfigManager.h"  // ✅ 2026-03-21 [Phase 7.48.68]: 逻辑控制配置读取
#include "OperationLogDatabase.h"
#include "DeviceRuntimeTracker.h"
#include "TTSConfigManager.h"  // ✅ 2026-02-26 [Phase 7.47.19]: 采样率配置
#include <QJsonDocument>  // ✅ 2026-03-21 [Phase 7.48.68]: JSON解析启停序列
#include <QJsonArray>
#include <QRegularExpression>  // ✅ 2026-03-21 [Phase 7.48.68]: 设备名称匹配
#include "DataPathConfig.h"    // ✅ 2026-03-20 [Phase 7.48.60]: TTS音频基础路径
#include <QDebug>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>      // ✅ 2026-01-21 16:00 [DEBUG] 获取文件信息（大小、格式）
#include <QElapsedTimer>  // ✅ 2026-01-21 16:00 [DEBUG] 测量播放各阶段耗时
// ❌ 2026-01-21 15:30 [FIX 100.278] 移除不需要的头文件
// 原因：不再枚举音频设备，直接使用默认 QAudioOutput
// #include <QMediaDevices>  // ✅ 2026-01-21 [音频设备] 枚举音频设备
// #include <QAudioDevice>   // ✅ 2026-01-21 [音频设备] QAudioDevice 类定义

// 前向声明NetworkTask，不include头文件避免依赖Qt::SerialBus
class NetworkTask;

CommonControl::CommonControl(QObject *parent)
    : QObject(parent)
    , m_mediaPlayer(new QMediaPlayer(this))
    , m_audioOutput(nullptr)  // ✅ 2026-01-21 [音频设备] 延迟初始化，需要先选择设备
    // ❌ 2026-03-03 [Phase 7.47.75]: 回退 QSoundEffect（Docker 容器中 No audio device detected）
    // , m_soundEffect(new QSoundEffect(this))
    // , m_usingSoundEffect(false)
    , m_systemConfig(nullptr)
    , m_networkTask(nullptr)
    , m_operationLogDB(nullptr)
    , m_runtimeTracker(nullptr)
    // ✅ 2026-01-21 20:20 [音频网络传输] 初始化音频网络发送器
    , m_audioNetworkSender(new AudioNetworkSender(this))
    // ❌ 2026-01-22 17:00 [测试TCP] 临时注释：原默认 DualOutput 模式（本地 + UDP 网络）
    // 原因：需要测试验证 TCP 音频发送功能是否正常工作
    // , m_audioOutputMode(DualOutput)  // 默认：本地 + 网络同时输出

    // ✅ 2026-01-22 17:00 [测试TCP] 强制使用 TCP 模式，验证 WebSocket BINARY 帧发送
    // 原因：TCP 音频发送功能代码已实现，但从未真正测试过（日志中只看到 UDP 组播）
    // 期望：日志应显示 "[TCP发送]" 和 "📡 已发送: X / Y 帧"
    , m_audioOutputMode(NetworkTcp)  // 测试：强制使用 TCP 模式
    // ✅ 2026-01-22 20:00 [TCP音频传输] 初始化 TCP 模式音频发送器
    , m_audioNetworkTcpSender(new AudioNetworkTcpSender(this))
    // ✅ 2026-01-23 00:00 [TTS网络传输] 初始化 TTS 语音合成器
    // ✅ 2026-02-13 [Phase 7.46.7]: 替换为 TTS 引擎管理器
    // , m_tts(new SherpaOnnxTTS(this))
    , m_ttsEngineManager(new TTSEngineManager(this))
    // ✅ 2026-03-04 [Phase 7.47.87]: 初始化音频播放队列
    , m_isPlayingFromQueue(false)
    // ❌ 2026-03-04 17:00 [Phase 7.47.90]: 移除 m_pendingPlay（延迟播放导致设备无声）
    // , m_pendingPlay(false)
    , m_warningTimer(new QTimer(this))
    , m_currentPlayCount(0)
    , m_isWarningPlaying(false)
    , m_currentBeltNumber(0)  // ✅ 2026-01-23 00:00 [TTS网络传输] 初始化皮带编号
    , m_isStopAudioPlaying(false)
    , m_isFaultStop(false)
    , m_deviceSequenceTimer(new QTimer(this))
    , m_currentSequenceIndex(0)
    , m_isSequenceRunning(false)
    , m_isStartupSequence(true)
    , m_lastFeedbackRegisterValue(0)
{
    qDebug() << "✅ CommonControl: 公共控制模块已创建";

    // ✅ 2026-01-21 15:30 [FIX 100.278] 使用 ALSA 默认设备播放音频
    // 背景：
    //   - Qt Multimedia 无法在容器中枚举 ALSA 设备（无 PulseAudio）
    //   - 已配置 /etc/asound.conf 设置 ES8388（Card 1）为默认设备
    //   - GStreamer alsasink 自动使用 ALSA "default" 设备
    // 工作流程：
    //   QMediaPlayer → GStreamer → alsasink → ALSA default → ES8388 🔊
    // 优点：
    //   - 无需设备枚举，代码简洁
    //   - 符合 ALSA/GStreamer 标准用法
    //   - 容器环境下稳定工作
    //
    // ❌ 2026-01-21 14:30 旧方案：枚举设备并选择 ES8388（容器中失败）
    // const QList<QAudioDevice> devices = QMediaDevices::audioOutputs();  // 返回空列表
    // 原因：容器内没有 PulseAudio 服务，Qt 枚举机制失效

    m_audioOutput = new QAudioOutput(this);  // 使用默认音频输出
    m_audioOutput->setVolume(1.0);           // 音量100%
    m_mediaPlayer->setAudioOutput(m_audioOutput);

    qDebug() << "🔊 CommonControl: 音频输出已配置（使用 ALSA 默认设备 → ES8388）";

    // ❌ 2026-03-03 [Phase 7.47.75]: 回退 QSoundEffect，注释掉全部初始化代码
    // 原因：QSoundEffect 在 Docker 容器中失败（No audio device detected）
    //   容器无 PulseAudio → QAudioSink 枚举设备为空 → 无法播放
    //   另：play() 时文件仍 Loading → isPlaying()=false → playingChanged 立刻误触发（0秒完成）
    // ✅ 2026-03-03 [Phase 7.47.73]: 初始化 QSoundEffect（低延迟本地播放）
    // // QSoundEffect 通过 QAudioSink 直接写 ALSA default，与 aplay 路径相同
    // // 不依赖 GStreamer 流式 pipeline，无重采样卡顿，无 pipeline 重建开销
    // m_soundEffect->setVolume(1.0);

    // // ① QSoundEffect 播放结束 → 触发 onPlaybackFinished()（仅当由 QSoundEffect 主播时）
    // connect(m_soundEffect, &QSoundEffect::playingChanged, this, [this]() {
    //     if (!m_soundEffect->isPlaying() && m_usingSoundEffect) {
    //         m_usingSoundEffect = false;
    //         qint64 playbackMs = m_playbackTimer.elapsed();
    //         qDebug() << "✅ [QSoundEffect] 播放结束，时长:" << QString::number(playbackMs / 1000.0, 'f', 2) << "秒";
    //         onPlaybackFinished();
    //     }
    // });

    // // ② QSoundEffect 加载失败 → 回退到 QMediaPlayer
    // connect(m_soundEffect, &QSoundEffect::statusChanged, this, [this]() {
    //     if (m_soundEffect->status() == QSoundEffect::Error && m_usingSoundEffect) {
    //         qWarning() << "⚠️ [QSoundEffect] 加载失败，回退到 QMediaPlayer:" << m_soundEffect->source();
    //         m_usingSoundEffect = false;
    //         // 重置 QMediaPlayer 并用旧方式播放
    //         m_mediaPlayer->setSource(QUrl());
    //         m_mediaPlayer->setSource(m_soundEffect->source());
    //         m_mediaPlayer->play();
    //     }
    //     qDebug() << "   [QSoundEffect] status:" << m_soundEffect->status()
    //              << "| source:" << m_soundEffect->source().fileName();
    // });

    // ✅ 2026-01-21 16:00 [DEBUG] 连接播放状态变化信号
    // 原因：监控播放状态转换时间，定位卡顿发生的阶段
    connect(m_mediaPlayer, &QMediaPlayer::errorOccurred,
            this, &CommonControl::onMediaPlayerError);

    connect(m_mediaPlayer, &QMediaPlayer::playbackStateChanged,
            this, [this](QMediaPlayer::PlaybackState state) {
                static QElapsedTimer stateTimer;
                static bool timerStarted = false;
                if (!timerStarted) {
                    stateTimer.start();
                    timerStarted = true;
                }

                qint64 elapsed = stateTimer.restart();
                qDebug() << "   [状态变化] 播放状态:"
                         << (state == QMediaPlayer::StoppedState ? "Stopped" :
                             state == QMediaPlayer::PlayingState ? "Playing" : "Paused")
                         << "| 距上次状态变化:" << elapsed << "ms";

                // ✅ 2026-02-26 [Phase 7.47.8]: 播放开始时启动计时器
                if (state == QMediaPlayer::PlayingState) {
                    m_playbackTimer.start();
                    qDebug() << "   [播放计时] 开始计时";
                }

                if (state == QMediaPlayer::StoppedState) {
                    // ❌ 2026-03-03 [Phase 7.47.75]: 移除 !m_usingSoundEffect 守卫（QSoundEffect 已回退）
                    // ✅ 2026-03-03 [Phase 7.47.73]: 守卫：QSoundEffect 播放期间忽略 QMediaPlayer 停止信号
                    // // if (!m_usingSoundEffect) {
                    // //     onPlaybackFinished();
                    // // } else {
                    // //     qDebug() << "   [守卫] QSoundEffect 播放中，忽略 QMediaPlayer Stopped 信号";
                    // // }
                    onPlaybackFinished();
                }
            });

    // ✅ 2026-01-21 16:00 [DEBUG] 连接媒体状态变化信号
    // 原因：监控媒体加载过程（LoadingMedia → LoadedMedia → BufferedMedia）
    // ❌ 2026-03-04 17:00 [Phase 7.47.90]: 移除 m_pendingPlay 延迟播放机制
    // 原因：从 mediaStatusChanged 信号处理器内部调用 play() 导致 GStreamer 管道状态异常
    //       QMediaPlayer 报告 Playing 状态（3.95秒），但实际不向 ALSA 输出音频数据
    //       设备完全无声。恢复直接调用 play()（在 setSource 后立即调用）
    connect(m_mediaPlayer, &QMediaPlayer::mediaStatusChanged,
            this, [this](QMediaPlayer::MediaStatus status) {
                static QElapsedTimer mediaTimer;
                static bool mediaTimerStarted = false;
                if (!mediaTimerStarted) {
                    mediaTimer.start();
                    mediaTimerStarted = true;
                }

                qint64 elapsed = mediaTimer.restart();
                QString statusName;
                switch (status) {
                    case QMediaPlayer::NoMedia: statusName = "NoMedia"; break;
                    case QMediaPlayer::LoadingMedia: statusName = "LoadingMedia"; break;
                    case QMediaPlayer::LoadedMedia: statusName = "LoadedMedia"; break;
                    case QMediaPlayer::StalledMedia: statusName = "StalledMedia"; break;
                    case QMediaPlayer::BufferingMedia: statusName = "BufferingMedia"; break;
                    case QMediaPlayer::BufferedMedia: statusName = "BufferedMedia"; break;
                    case QMediaPlayer::EndOfMedia: statusName = "EndOfMedia"; break;
                    case QMediaPlayer::InvalidMedia: statusName = "InvalidMedia"; break;
                    default: statusName = "Unknown"; break;
                }

                qDebug() << "   [媒体状态] " << statusName
                         << "| 距上次状态变化:" << elapsed << "ms";

                // ❌ 2026-03-04 17:00 [Phase 7.47.90]: 以下延迟播放代码已移除
                // 问题：从 mediaStatusChanged 回调内部调用 m_mediaPlayer->play()
                //       GStreamer 管道在状态转换回调中收到 play() 请求
                //       导致管道内部状态与 ALSA 输出不同步 → 报告 Playing 但无实际音频输出
                // 方案：恢复在 setSource() 后立即调用 play()（3月3日之前的工作方式）
                // if (status == QMediaPlayer::LoadedMedia && m_pendingPlay) { ... }
                // if (status == QMediaPlayer::InvalidMedia && m_pendingPlay) { ... }
            });

    // 连接预警定时器
    connect(m_warningTimer, &QTimer::timeout,
            this, &CommonControl::onWarningTimerTimeout);

    // 连接设备序列定时器
    m_deviceSequenceTimer->setSingleShot(true);
    connect(m_deviceSequenceTimer, &QTimer::timeout,
            this, &CommonControl::onDeviceSequenceTimer);

    qDebug() << "🔊 CommonControl: 音频播放器已初始化";

    // ✅ 2026-01-22 20:05 [TCP音频传输] 自动启动 UDP 服务发现
    // 原因：上位机会在应用启动后立即发送 UDP 广播（端口 8600）
    // 如果不启动监听，设备会返回 ICMP Port Unreachable 错误
    m_audioNetworkTcpSender->startDiscovery();
    qDebug() << "✅ CommonControl: TCP 音频模块已启动 UDP 服务发现";

    // ✅ 2026-01-22 19:00 [FIX 100.292] 预加载常用音频文件（性能优化）
    // 效果：
    //   - 首次播放延迟：200ms → 20ms（编码时间节省）
    //   - 重复播放延迟：170ms → <1ms（缓存命中）
    // 内存开销：
    //   - 每个音频文件约 40KB（2秒音频 = 100帧 × 400字节/帧）
    //   - 预加载 3 个文件约占用 120KB 内存
    QStringList preloadFiles = {
        "/app/appdata/audio/belt_start_1.mp3",  // 起车预警音频
        "/app/appdata/audio/belt_stop_1.mp3",   // 停车预警音频（如果有）
    };
    m_audioNetworkTcpSender->preloadAudioFiles(preloadFiles);
    qDebug() << "✅ CommonControl: 音频预加载完成（缓存文件数:"
             << m_audioNetworkTcpSender->getCachedFilesCount() << "）";

    // ✅ 2026-01-23 00:00 [TTS网络传输] 初始化 TTS 语音合成器
    // 原因：使用 TTS 代替音频文件进行起车预警播报
    // 优点：
    //   - 动态生成语音（如 "1号皮带启动"、"2号皮带启动"）
    //   - 无需预录制多个音频文件
    //   - 支持 TCP 模式网络传输
    // ❌ 2026-02-15 20:30: 注释旧的 TTS 初始化代码（使用 m_tts，已废弃）
    // 新的实现使用 m_ttsEngineManager（支持多引擎切换）
    /*
    // ❌ 2026-01-23 01:00 [路径修复] 修正 TTS 模型目录路径
    // 原因：日志显示模型目录不存在，应使用与 AlarmPlaybackService 相同的路径
    // 参考：docs/log/voip.md 第208行 - AlarmPlaybackService 使用 /app/tts_models/vits-zh-aishell3
    QString ttsModelDir = "/app/tts_models/vits-zh-aishell3";  // TTS 模型目录
    if (m_tts->initialize(ttsModelDir)) {
        qDebug() << "✅ CommonControl: TTS 语音合成器初始化成功";
        qDebug() << "   模型目录:" << ttsModelDir;
        qDebug() << "   输出模式: 网络传输（TCP 模式 → 上位机）";
    } else {
        qWarning() << "⚠️ CommonControl: TTS 初始化失败，将使用音频文件作为备选";
        qWarning() << "   模型目录:" << ttsModelDir;
    }

    // ✅ 2026-01-23 00:30 [信号转发] 连接 TTS 网络传输完成信号
    // 原因：TTS 网络传输完成后需要触发 onPlaybackFinished() 继续预警循环
    // 流程：TTS 传输完成 → emit networkTransmissionFinished() → onPlaybackFinished() → 播放第2、3次
    connect(m_tts, &SherpaOnnxTTS::networkTransmissionFinished,
            this, &CommonControl::onPlaybackFinished);
    qDebug() << "✅ CommonControl: TTS 信号已连接到预警循环";

    // ✅ 2026-01-23 01:30 [网络共享] 共享网络发送器给 TTS
    // 原因：避免 TTS 创建未连接的发送器，复用 CommonControl 已连接的 WebSocket
    // 问题：
    //   - TTS 构造函数创建独立的 AudioNetworkTcpSender 实例
    //   - 这个新实例没有调用 startDiscovery()，没有连接 WebSocket
    //   - 导致 TTS 传输失败（日志：❌ "WebSocket 未连接，无法播放音频"）
    // 解决方案：
    //   - 让 TTS 复用 CommonControl 的已连接发送器（第145行已启动服务发现）
    //   - 共享同一个 WebSocket 连接，无需重复连接
    // 效果：
    //   - TTS 可以直接使用已建立的网络连接
    //   - 节省资源（一个连接 vs 两个连接）
    //   - 避免重复的 UDP 服务发现
    m_tts->setTcpSender(m_audioNetworkTcpSender);
    m_tts->setUdpSender(m_audioNetworkSender);
    qDebug() << "✅ CommonControl: 已共享网络发送器给 TTS";
    */

    // ✅ 2026-02-15 22:10: 实现新的 TTS 引擎管理器初始化
    // 使用 m_ttsEngineManager 替代 m_tts
    registerTTSEngines();
    qDebug() << "✅ CommonControl: TTS 引擎管理器初始化完成";

    // ✅ 2026-02-21 22:50: 连接 TTS 初始化进度信号
    // 原因：PaddleSpeech 初始化需要 5-10 分钟，QML 需要显示进度
    // 效果：将 TTSEngineManager 的进度信号转发到 QML
    connect(m_ttsEngineManager, &TTSEngineManager::initializationProgress,
            this, &CommonControl::ttsInitializationProgress);
    qDebug() << "✅ CommonControl: TTS 初始化进度信号已连接";
}

CommonControl::~CommonControl()
{
    stopWarningPlayback();
    if (m_mediaPlayer) {
        m_mediaPlayer->stop();
    }
    qDebug() << "✅ CommonControl: 公共控制模块已销毁";
}

void CommonControl::setSystemConfig(SystemConfig *config)
{
    m_systemConfig = config;
    qDebug() << "🔗 CommonControl: SystemConfig已连接";
}

// ✅ 2026-03-21 [Phase 7.48.68]: 设置设备配置管理器
void CommonControl::setDeviceConfigManager(DeviceConfigManager *mgr)
{
    m_deviceConfigMgr = mgr;
    qDebug() << "🔗 CommonControl: DeviceConfigManager已连接";
}

void CommonControl::setNetworkTask(NetworkTask *task)
{
    m_networkTask = task;
    qDebug() << "🔗 CommonControl: NetworkTask已连接";

    // 连接寄存器值接收信号以监听反馈
    if (m_networkTask) {
        connect(reinterpret_cast<QObject*>(m_networkTask), SIGNAL(registerValueReceived(int, quint16)),
                this, SLOT(onRegisterValueReceived(int, quint16)));
        qDebug() << "🔗 CommonControl: 已连接 registerValueReceived 信号";
    }
}

void CommonControl::setOperationLogDB(OperationLogDatabase *logDB)
{
    m_operationLogDB = logDB;
    if (m_operationLogDB) {
        qDebug() << "🔗 CommonControl: OperationLogDB已连接";
    }
}

void CommonControl::setRuntimeTracker(DeviceRuntimeTracker *tracker)
{
    m_runtimeTracker = tracker;
    if (m_runtimeTracker) {
        qDebug() << "🔗 CommonControl: RuntimeTracker已连接";
    }
}

bool CommonControl::eventFilter(QObject *watched, QEvent *event)
{
    // 键盘事件现在由 App.qml 处理
    // 这个 eventFilter 保留用于将来可能的其他事件处理
    return QObject::eventFilter(watched, event);
}

void CommonControl::playAudio(const QString &audioPath)
{
    // ✅ 2026-03-04 [Phase 7.47.87]: 音频播放队列（防止多个离线语音互相打断）
    // 检查文件是否存在
    if (!QFile::exists(audioPath)) {
        qWarning() << "❌ CommonControl: 音频文件不存在:" << audioPath;
        return;
    }

    // 加入队列
    m_audioQueue.append(audioPath);
    qDebug() << "📋 CommonControl: 音频加入队列:" << QFileInfo(audioPath).fileName()
             << "| 队列长度:" << m_audioQueue.size();

    // 如果当前没有播放，立即开始播放队列
    if (!m_isPlayingFromQueue) {
        playNextInQueue();
    }
}

// ✅ 2026-03-04 [Phase 7.47.87]: 播放队列中的下一个音频
void CommonControl::playNextInQueue()
{
    if (m_audioQueue.isEmpty()) {
        m_isPlayingFromQueue = false;
        qDebug() << "✅ CommonControl: 队列播放完成";
        return;
    }

    m_isPlayingFromQueue = true;
    QString audioPath = m_audioQueue.takeFirst();
    qDebug() << "▶️ CommonControl: 从队列播放:" << QFileInfo(audioPath).fileName()
             << "| 剩余队列:" << m_audioQueue.size();

    playAudioInternal(audioPath);
}

// ✅ 2026-03-04 [Phase 7.47.87]: 内部播放方法（原 playAudio 逻辑）
void CommonControl::playAudioInternal(const QString &audioPath)
{
    // ✅ 2026-01-21 16:00 [DEBUG] 添加详细的播放时间测量日志
    // 原因：用户报告播放起车预警时中间卡一下（时间很短）
    // 目的：定位卡顿是发生在哪个阶段（文件加载、解码器初始化、设备打开）
    QElapsedTimer timer;
    timer.start();

    // 检查文件是否存在
    if (!QFile::exists(audioPath)) {
        qWarning() << "❌ CommonControl: 音频文件不存在:" << audioPath;
        return;
    }

    // ✅ 2026-01-21 16:00 [DEBUG] 记录文件信息
    QFileInfo fileInfo(audioPath);
    qint64 fileSize = fileInfo.size();
    QString fileName = fileInfo.fileName();
    qDebug() << "🔊 CommonControl: 播放音频:" << fileName
             << "| 大小:" << (fileSize / 1024) << "KB"
             << "| 格式:" << fileInfo.suffix().toUpper();

    // 记录当前播放状态
    QMediaPlayer::PlaybackState currentState = m_mediaPlayer->playbackState();
    qDebug() << "   [状态] 当前播放状态:"
             << (currentState == QMediaPlayer::StoppedState ? "Stopped" :
                 currentState == QMediaPlayer::PlayingState ? "Playing" : "Paused");

    // 先停止当前播放
    if (currentState != QMediaPlayer::StoppedState) {
        qint64 stopTime = timer.elapsed();
        m_mediaPlayer->stop();
        qDebug() << "   [停止] 停止当前播放耗时:" << (timer.elapsed() - stopTime) << "ms";
    }

    // ❌ 2026-01-21 17:00 [FIX 100.279.1] 弃用重置位置方案（卡顿 300ms+）
    // 问题：根据日志分析，setPosition(0) 导致状态转换延迟
    //   [媒体状态] "LoadedMedia" | 距上次状态变化: 337 ms  ← 卡顿300ms+
    // 原因：QMediaPlayer/GStreamer 状态机切换复杂，setPosition(0) 需要重新初始化
    // 旧代码：
    //   if (currentSource == newSource) {
    //       m_mediaPlayer->setPosition(0);  ← 慢！
    //   }

    // ❌ 2026-03-04 [Phase 7.47.87]: 曾尝试移除清空源操作（避免 pipeline 重建，111ms 延迟）
    // ✅ 2026-03-04 17:00 [Phase 7.47.90]: 恢复清空源操作
    // 原因：不清空源直接设置新源，GStreamer 管道在文件切换时未正确重置
    //       可能导致管道内部状态残留，配合延迟播放机制产生"报告 Playing 但无音频输出"的问题
    //       恢复先清空再设置的安全方式，确保 pipeline 完全重建
    qDebug() << "   [清空] 清空音频源";
    qint64 clearTime = timer.elapsed();
    m_mediaPlayer->setSource(QUrl());  // 清空源，确保 pipeline 重建
    qDebug() << "   [清空] 清空源耗时:" << (timer.elapsed() - clearTime) << "ms";

    qDebug() << "   [新源] 设置新音频源:" << fileName;
    qint64 setSourceTime = timer.elapsed();
    QUrl newSource = QUrl::fromLocalFile(audioPath);
    m_mediaPlayer->setSource(newSource);
    qDebug() << "   [加载] setSource() 耗时:" << (timer.elapsed() - setSourceTime) << "ms";

    // ✅ 2026-01-21 20:25 [音频网络传输] 根据输出模式选择播放方式
    const char* modeName = (m_audioOutputMode == LocalOnly ? "本地" :
                            m_audioOutputMode == NetworkOnly ? "网络" :
                            m_audioOutputMode == NetworkTcp ? "TCP网络" : "本地+网络");
    qDebug() << "   [输出模式]" << modeName;

    switch (m_audioOutputMode) {
        case LocalOnly: {
            // ❌ 2026-03-03 [Phase 7.47.75]: QSoundEffect 在 Docker 容器失败，已回退 QMediaPlayer
            // ✅ 2026-03-03 [Phase 7.47.75]: 恢复 QMediaPlayer（卡顿由 asound.conf rate=24kHz 缓解）
            // ❌ 2026-03-04 [Phase 7.47.89]: 曾改为 m_pendingPlay 延迟播放（导致设备完全无声）
            // ✅ 2026-03-04 17:00 [Phase 7.47.90]: 恢复直接调用 play()
            qDebug() << "   [本地播放] QMediaPlayer（GStreamer → ALSA default）";
            m_mediaPlayer->play();
            break;
        }

        case NetworkOnly: {
            // 仅发送到网络音频模块
            qDebug() << "   [网络发送] 开始发送到音频模块（224.1.1.1:8800）...";
            m_audioNetworkSender->playAudioToNetwork(audioPath);
            break;
        }

        case DualOutput: {
            // 本地 + 网络同时
            qDebug() << "   [双输出] 本地播放 + 网络发送...";
            // ❌ 2026-03-04 [Phase 7.47.89]: 曾改为 m_pendingPlay 延迟播放（导致设备完全无声）
            // ✅ 2026-03-04 17:00 [Phase 7.47.90]: 恢复直接调用 play()
            m_mediaPlayer->play();

            qint64 networkTime = timer.elapsed();
            m_audioNetworkSender->playAudioToNetwork(audioPath);
            qDebug() << "      网络发送启动耗时:" << (timer.elapsed() - networkTime) << "ms";
            break;
        }

        case NetworkTcp: {
            // ✅ 2026-01-22 20:00 [TCP音频传输] 仅发送到 TCP 音频模块
            qDebug() << "   [TCP发送] 开始发送到 TCP 音频模块...";
            if (m_audioNetworkTcpSender->isConnected()) {
                m_audioNetworkTcpSender->playAudioToNetwork(audioPath);
            } else {
                // ❌ 2026-03-03 [Phase 7.47.75]: QSoundEffect 在 Docker 容器失败，回退 QMediaPlayer
                // ❌ 2026-03-04 [Phase 7.47.89]: 曾改为 m_pendingPlay 延迟播放（导致设备完全无声）
                // ✅ 2026-03-04 17:00 [Phase 7.47.90]: 恢复直接调用 play()
                qWarning() << "   [TCP发送] ⚠️ 未连接到 TCP 服务器，本地播放（QMediaPlayer）";
                m_mediaPlayer->play();
            }
            break;
        }
    }

    qDebug() << "   [总计] playAudio() 总耗时:" << timer.elapsed() << "ms";

    // ✅ 2026-01-21 16:00 [DEBUG] 记录 QMediaPlayer 内部状态
    qDebug() << "   [媒体] 当前源:" << m_mediaPlayer->source().toString();
    qDebug() << "   [媒体] 媒体状态:"
             << (m_mediaPlayer->mediaStatus() == QMediaPlayer::NoMedia ? "NoMedia" :
                 m_mediaPlayer->mediaStatus() == QMediaPlayer::LoadingMedia ? "LoadingMedia" :
                 m_mediaPlayer->mediaStatus() == QMediaPlayer::LoadedMedia ? "LoadedMedia" :
                 m_mediaPlayer->mediaStatus() == QMediaPlayer::BufferingMedia ? "BufferingMedia" :
                 m_mediaPlayer->mediaStatus() == QMediaPlayer::BufferedMedia ? "BufferedMedia" : "Other");
    qDebug() << "   [媒体] 音频可用:" << m_mediaPlayer->hasAudio();
    qDebug() << "   [媒体] 时长:" << m_mediaPlayer->duration() << "ms";
}

void CommonControl::startBelt(int beltNumber)
{
    // ✅ 2026-03-23 [Phase 7.48.85.2]: 防重入检查 - R键长按/自动重复导致startBelt被快速反复调用
    // 原因：每次调用都会 stopWarningPlayback() + startWarningPlayback()，音频播放30-120ms就被打断，
    //       m_warningTimer 被不断重置永远不到期，设备序列永远不启动。
    if (m_isWarningPlaying || m_isStopAudioPlaying || m_isSequenceRunning) {
        qDebug() << "⚠️ CommonControl: 忽略重复启动请求（当前状态："
                 << (m_isWarningPlaying ? "预警播放中" : "")
                 << (m_isStopAudioPlaying ? "停车音频中" : "")
                 << (m_isSequenceRunning ? "设备序列中" : "") << "）";
        return;
    }

    qDebug() << "🚀 CommonControl: 请求启动" << beltNumber << "号皮带";

    // 记录启动操作到数据库
    if (m_operationLogDB && m_systemConfig) {
        QString workModeName = getWorkModeName();
        m_operationLogDB->logOperation(workModeName, "按键", "启动请求",
                                      QString("%1号皮带").arg(beltNumber), "");
    }

    // 使用预警播放模式
    // ✅ 2026-03-21 [Phase 7.48.66]: 发出预警开始信号（时间轴实时可视化使用）
    emit warningStarted();
    startWarningPlayback(beltNumber);
}

void CommonControl::stopBelt(int beltNumber)
{
    qDebug() << "🛑 CommonControl: 请求停止" << beltNumber << "号皮带";

    // 检查是否已经停止（避免重复执行停止逻辑）
    if (m_runtimeTracker && !m_runtimeTracker->isRunning() && m_runtimeTracker->currentStatus() == "停止") {
        qDebug() << "⚠️  CommonControl: 设备已经停止，忽略停止请求";
        return;
    }

    // 更新RuntimeTracker：停车预警（在播放音频前立即显示）
    if (m_runtimeTracker) {
        m_runtimeTracker->onStopWarning();
    }

    // ✅ 2026-03-21 [Phase 7.48.72]: 发出停车预警开始信号（S键��下时立即发出）
    // 原因：QML需要立即切换到停止Tab，不能等到停车音频播完后的stopSequenceStarted
    emit stopWarningStarted();

    // 记录停止操作到数据库
    if (m_operationLogDB && m_systemConfig) {
        QString workModeName = getWorkModeName();
        m_operationLogDB->logOperation(workModeName, "按键", "停止请求",
                                      QString("%1号皮带").arg(beltNumber), "");
    }

    // 停止当前预警播放（如果正在播放）
    stopWarningPlayback();

    // ✅ 2026-03-23 [Phase 7.48.85]: 故障停车跳过停车音频，直接执行停止序列
    // 原因：紧急停车（protection_level=0）无需播放停车音频，直接停止设备
    if (m_isFaultStop) {
        qDebug() << "🚨 CommonControl: 故障/紧急停车模式，跳过停车音频，直接停止设备序列";
        m_isFaultStop = false;  // 重置标志
        stopDeviceSequence();
        return;
    }

    // 获取停车音频路径
    QString stopAudioPath = getAudioPath(beltNumber, "停车");
    if (stopAudioPath.isEmpty()) {
        qWarning() << "❌ CommonControl: 未找到" << beltNumber << "号皮带的停车音频";
        // 即使没有音频，也要停止设备序列
        stopDeviceSequence();
        return;
    }

    // 标记正在播放停车音频
    m_isStopAudioPlaying = true;

    // 播放停车音频（只播放一次）
    qDebug() << "🔊 CommonControl: 播放停车音频（一次）";
    playAudio(stopAudioPath);
}

// ✅ 2026-03-23 [Phase 7.48.85]: 紧急停车 — 跳过停车音频，直接执行停止序列
// 用途：保护逻辑控制器触发的紧急停车（protection_level=0），或主站紧急停车命令
void CommonControl::emergencyStopBelt(int beltNumber)
{
    qDebug() << "🚨 CommonControl: 紧急停车" << beltNumber << "号皮带（跳过停车音频）";
    m_isFaultStop = true;   // 标记故障停车（stopBelt内部将跳过停车音频）
    stopBelt(beltNumber);   // 复用现有停止逻辑
}

QString CommonControl::getAudioPath(int beltNumber, const QString &actionType)
{
    // 尝试多种文件名格式
    QStringList possibleNames;
    // 格式1: "1号皮带启动.mp3" - 完整格式
    possibleNames << QString("%1号皮带%2.mp3").arg(beltNumber).arg(actionType);
    possibleNames << QString("%1号皮带%2.wav").arg(beltNumber).arg(actionType);
    // 格式2: "带启动.mp3" - 简化格式
    possibleNames << QString("带%1.mp3").arg(actionType);
    possibleNames << QString("带%1.wav").arg(actionType);
    // 格式3: "启动.mp3" - 最简格式
    possibleNames << QString("%1.mp3").arg(actionType);
    possibleNames << QString("%1.wav").arg(actionType);

    // ✅ 2026-03-20 [Phase 7.48.60]: TTS合成路径优先
    if (m_systemConfig && m_systemConfig->beltAudioSource() == 1) {
        // 使用TTS引擎音频路径：{audioBase}/{engine}-{model}-spk{id}/{N}#PD/
        TTSConfigManager *ttsConfig = TTSConfigManager::instance();
        int modelIndex = ttsConfig->modelIndex(TTSConfigManager::Test);
        QString engineName = "paddlespeech";
        QString modelName = ttsConfig->modelName(modelIndex);
        int speakerId = ttsConfig->speakerId(TTSConfigManager::Test);
        QString ttsFolder = QString("%1/%2-%3-spk%4/%5#PD")
                                .arg(DataPathConfig::getAudioBaseDirectory())
                                .arg(engineName)
                                .arg(modelName)
                                .arg(speakerId)
                                .arg(beltNumber);
        for (const QString &fileName : possibleNames) {
            QString audioPath = QString("%1/%2").arg(ttsFolder, fileName);
            if (QFile::exists(audioPath)) {
                qDebug() << "✅ CommonControl: 使用TTS音频:" << audioPath;
                return audioPath;
            }
        }
        qDebug() << "⚠️ CommonControl: TTS路径未找到音频，回退到默认路径";
        qDebug() << "   TTS文件夹:" << ttsFolder;
    }

    // ✅ 2026-03-20 [Phase 7.48.62]: 数据目录路径（容器挂载卷）
    // /home/linaro/belt-control-data/audio 通过容器卷挂载，在容器内可直接访问
    // SSH确认文件实际存储位置：/home/linaro/belt-control-data/audio/1#PD/
    QString dataBaseDir = DataPathConfig::getAudioBaseDirectory();
    QString dataFolder = QString("%1/%2#PD").arg(dataBaseDir).arg(beltNumber);
    for (const QString &fileName : possibleNames) {
        QString audioPath = QString("%1/%2").arg(dataFolder, fileName);
        if (QFile::exists(audioPath)) {
            qDebug() << "✅ CommonControl: 使用数据目录音频:" << audioPath;
            return audioPath;
        }
    }
    qDebug() << "⚠️ CommonControl: 数据目录未找到音频:" << dataFolder;

    // 默认路径：{appDir}/AUDIO/{N}#PD/
    // ❌ 2026-03-20 [Phase 7.48.60]: 原代码直接在此处定义folderName和appDir，现改为先尝试TTS路径
    QString appDir = QCoreApplication::applicationDirPath();
    // 构建音频文件路径: AUDIO/<编号>#PD/<文件名>
    QString folderName = QString("%1#PD").arg(beltNumber);

    // 按顺序尝试所有可能的文件名
    for (const QString &fileName : possibleNames) {
        QString audioPath = QString("%1/AUDIO/%2/%3").arg(appDir, folderName, fileName);
        if (QFile::exists(audioPath)) {
            return audioPath;
        }
    }

    qDebug() << "⚠️ CommonControl: 在以下位置未找到音频文件:";
    qDebug() << "   " << dataFolder << "/";
    qDebug() << "   " << QString("%1/AUDIO/%2/").arg(appDir, folderName);
    qDebug() << "   尝试的文件名:" << possibleNames.join(", ");

    return QString();
}

void CommonControl::onMediaPlayerError(QMediaPlayer::Error error, const QString &errorString)
{
    qWarning() << "❌ CommonControl: 音频播放错误:" << errorString;
    qWarning() << "   错误代码:" << error;
}

void CommonControl::onPlaybackFinished()
{
    if (m_isStopAudioPlaying) {
        // 停车音频播放完成
        qDebug() << "✅ CommonControl: 停车音频播放完成";
        m_isStopAudioPlaying = false;
        // ✅ 2026-03-21 [Phase 7.48.70]: 重置音频队列状态，防止后续playAudio()入队后无法启动播放
        // 原因：stop音频播放完成后 m_isPlayingFromQueue 仍为 true，
        //       下次按R键 playAudio() 只入队不播放，导致第2/3次R键无声音
        m_isPlayingFromQueue = false;
        m_audioQueue.clear();

        // 自动停止设备序列
        qDebug() << "🔄 CommonControl: 停车音频结束，自动停止设备序列";
        stopDeviceSequence();
    } else if (m_isWarningPlaying) {
        // 预警播放模式
        if (!m_systemConfig) {
            qWarning() << "❌ CommonControl: SystemConfig未设置";
            stopWarningPlayback();
            return;
        }

        SystemConfig::WarningMode mode = m_systemConfig->warningMode();

        if (mode == SystemConfig::ByCount) {
            // 按次数模式：检查是否达到目标次数
            m_currentPlayCount++;
            qDebug() << "📊 CommonControl: 已播放" << m_currentPlayCount << "/"
                     << m_systemConfig->warningPlayCount() << "次";

            if (m_currentPlayCount < m_systemConfig->warningPlayCount()) {
                // 继续播放 - 添加300ms延迟确保媒体播放器准备好
                // ✅ 2026-03-21 [Phase 7.48.70]: 重置队列状态后再排队下一次
                m_isPlayingFromQueue = false;
                QTimer::singleShot(300, this, &CommonControl::playWarningOnce);
            } else {
                // 播放完成
                qDebug() << "✅ CommonControl: 预警播放完成（按次数）";
                stopWarningPlayback();
                emit warningPlaybackFinished();
                emit beltStartRequested(m_systemConfig->machineNumber());

                // 自动启动设备序列
                qDebug() << "🔄 CommonControl: 预警结束，自动启动设备序列";
                startDeviceSequence();
            }
        } else {
            // 按时间模式：检查定时器是否还在运行，继续播放
            if (m_warningTimer->isActive()) {
                qDebug() << "🔁 CommonControl: 定时器仍在运行，继续播放预警";
                // ✅ 2026-03-21 [Phase 7.48.70]: 重置队列状态后再排队下一次播放
                // 原因：ByTime模式下每轮播完一次后 m_isPlayingFromQueue 仍为 true，
                //       playWarningOnce→playAudio 只入队不启动，导致定时器期间只播一次
                m_isPlayingFromQueue = false;
                // 添加300ms延迟确保媒体播放器准备好
                QTimer::singleShot(300, this, &CommonControl::playWarningOnce);
            } else {
                qDebug() << "⏸️ CommonControl: 定时器已停止，不再播放";
                // ✅ 2026-03-21 [Phase 7.48.70]: 定时器停止时也需要重置队列状态
                m_isPlayingFromQueue = false;
                m_audioQueue.clear();
            }
        }
    } else {
        // 普通播放完成
        // ✅ 2026-02-26 [Phase 7.47.8]: 输出播放时长（秒）
        qint64 playbackMs = m_playbackTimer.elapsed();
        double playbackSec = playbackMs / 1000.0;
        qDebug() << "✅ CommonControl: 音频播放完成，时长:" << QString::number(playbackSec, 'f', 2) << "秒";

        // ✅ 2026-03-04 [Phase 7.47.87]: 播放队列中的下一个音频
        // ✅ 2026-03-04 [Phase 7.47.89]: 过滤虚假 EndOfMedia（7ms）：
        //   切换源时 GStreamer 会在 LoadingMedia 后约 7ms 内产生一次虚假 EndOfMedia
        //   → PlaybackState=Stopped → 触发此处 → 但此时新文件还在加载，播放时长极短
        //   → 过滤 < 200ms 的完成事件，避免队列状态被提前清空
        if (playbackMs < 200) {
            qDebug() << "⚠️ CommonControl: 忽略虚假完成事件（时长 < 200ms，可能为 GStreamer 源切换产生）";
        } else if (m_isPlayingFromQueue) {
            playNextInQueue();
        }
    }
}

void CommonControl::onWarningTimerTimeout()
{
    // 按时间模式的定时器到期
    qDebug() << "⏰ CommonControl: 预警时间到达";
    stopWarningPlayback();
    emit warningPlaybackFinished();

    if (m_systemConfig) {
        emit beltStartRequested(m_systemConfig->machineNumber());

        // 自动启动设备序列
        qDebug() << "🔄 CommonControl: 预警结束，自动启动设备序列";
        startDeviceSequence();
    }
}

void CommonControl::startWarningPlayback(int beltNumber)
{
    if (!m_systemConfig) {
        qWarning() << "❌ CommonControl: SystemConfig未设置，无法启动预警播放";
        return;
    }

    // ✅ 2026-01-23 00:00 [TTS网络传输] 保存皮带编号用于 TTS 文本生成
    m_currentBeltNumber = beltNumber;

    // 更新RuntimeTracker：起车预警
    if (m_runtimeTracker) {
        m_runtimeTracker->onStartWarning();
    }

    // 停止之前的播放
    stopWarningPlayback();

    // ❌ 2026-01-23 00:05 [TTS网络传输] 不再需要音频文件路径（改用 TTS 生成）
    // 保留此代码用于 TTS 不可用时的备选方案
    // 获取音频文件路径
    m_currentAudioPath = getAudioPath(beltNumber, "启动");
    if (m_currentAudioPath.isEmpty()) {
        qDebug() << "⚠️ CommonControl: 未找到" << beltNumber << "号皮带的启动音频，将使用 TTS 生成";
        // ✅ 不再 return，继续使用 TTS
    }

    m_isWarningPlaying = true;
    m_currentPlayCount = 0;

    SystemConfig::WarningMode mode = m_systemConfig->warningMode();

    // 记录预警到数据库
    if (m_operationLogDB) {
        QString workModeName = getWorkModeName();
        QString detail;
        if (mode == SystemConfig::ByTime) {
            detail = QString("按时间: %1秒").arg(m_systemConfig->warningTimeSeconds());
        } else {
            detail = QString("按次数: %1次").arg(m_systemConfig->warningPlayCount());
        }
        m_operationLogDB->logWarning(workModeName, detail);
    }

    if (mode == SystemConfig::ByTime) {
        // 按时间模式
        int warningTime = m_systemConfig->warningTimeSeconds();
        qDebug() << "⏰ CommonControl: 启动预警播放（按时间）- " << warningTime << "秒";

        // ✅ 2026-03-20 [Phase 7.48.59]: 设为单次定时器（singleShot），防止重复触发
        // 旧代码未设 singleShot，QTimer 默认重复，每 N 秒触发一次 startDeviceSequence()，
        // 与故障停止逻辑叠加形成无限启动循环。
        m_warningTimer->setSingleShot(true);
        m_warningTimer->start(warningTime * 1000);

        // 开始播放
        playWarningOnce();
    } else {
        // 按次数模式
        int warningCount = m_systemConfig->warningPlayCount();
        qDebug() << "🔢 CommonControl: 启动预警播放（按次数）- " << warningCount << "次";

        // 开始播放
        playWarningOnce();
    }
}

void CommonControl::playWarningOnce()
{
    // ✅ 2026-03-20 [Phase 7.48.58]: 重写起车预警播放逻辑
    // 旧逻辑：TTS代码已注释 + 音频文件路径错误 → 无法播放 → onPlaybackFinished永不触发 → 设备序列永不启动
    // 新逻辑：优先预制音频文件 → TTS合成 → 直接启动（保证设备序列一定执行）

    // 构造 TTS 预警文字：使用本机名称（例如 "1号皮带准备启动，注意安全"）
    QString warningText;
    if (m_systemConfig && !m_systemConfig->localDeviceName().isEmpty()) {
        // ✅ 用本机名称（基本参数设置中配置）
        warningText = m_systemConfig->localDeviceName() + "准备启动，注意安全";
    } else {
        // 备选：用皮带编号中文
        QString chineseNumber = numberToChinese(m_currentBeltNumber);
        warningText = QString("%1号皮带准备启动，注意安全").arg(chineseNumber);
    }

    // ① 优先：使用预制音频文件（批量生成的）
    if (!m_currentAudioPath.isEmpty() && QFile::exists(m_currentAudioPath)) {
        qDebug() << "🔊 CommonControl: 使用预制音频文件播放起车预警:" << m_currentAudioPath;
        playAudio(m_currentAudioPath);
        return;
    }

    // ② 次选：TTS实时合成
    if (m_ttsEngineManager) {
        TTSParameters params;
        params.speakerId = 0;
        params.rate = 0.9;
        params.volume = 1.0;

        // 使用固定临时文件路径（同一次预警复用，避免重复合成）
        QString tempFile = QString("/tmp/startup_warning_%1.wav").arg(m_currentBeltNumber);

        qDebug() << "🗣️ CommonControl: TTS合成起车预警:" << warningText;
        if (m_ttsEngineManager->synthesize(warningText, tempFile, params)) {
            qDebug() << "✅ CommonControl: TTS合成成功，播放:" << tempFile;
            m_currentAudioPath = tempFile;  // 缓存路径，本次预警重复播放时直接复用
            playAudio(m_currentAudioPath);
            // ✅ 2026-03-20 [Phase 7.48.62]: TTS合成（同步约10秒）后重置计时器
            // 原因：m_warningTimer 在 startWarningPlayback() 中已 start(N秒)，
            //       TTS合成耗时≈9.7秒，合成完成时计时器仅剩0.3秒就触发timeout，
            //       导致音频只播放0.24秒就结束。重置计时器保证音频完整播放完整预警时长。
            if (m_warningTimer->isActive() && m_systemConfig) {
                m_warningTimer->start(m_systemConfig->warningTimeSeconds() * 1000);
                qDebug() << "🔄 CommonControl: TTS合成后重置预警计时器:" << m_systemConfig->warningTimeSeconds() << "秒";
            }
            return;
        } else {
            qWarning() << "⚠️ CommonControl: TTS合成失败，跳过预警直接启动设备序列";
        }
    } else {
        qWarning() << "⚠️ CommonControl: TTS引擎不可用，跳过预警直接启动设备序列";
    }

    // ③ 最后备选：无音频可用，直接触发设备序列（不能因为没有音频就永远卡住）
    qWarning() << "❌ CommonControl: 起车预警无可用音频，直接执行启动序列";
    // ✅ 2026-03-20 [Phase 7.48.59]: 必须先停止 warningTimer！
    // 原因：m_warningTimer 在 startWarningPlayback() 中已 start(N秒)，若此处不停止，
    //       N秒后 onWarningTimerTimeout() 仍会触发 startDeviceSequence()，
    //       导致设备故障停止后自动重启，形成无限循环。
    m_warningTimer->stop();
    m_isWarningPlaying = false;
    startDeviceSequence();
}

void CommonControl::stopWarningPlayback()
{
    if (m_isWarningPlaying) {
        qDebug() << "⏹️ CommonControl: 停止预警播放";
        m_isWarningPlaying = false;
        m_warningTimer->stop();
        // ✅ 2026-03-21 [Phase 7.48.63]: 清空音频队列，防止残留项目占用位置导致新预警排队播不上
        // 原因：stopWarningPlayback()之前只 stop() 了 mediaPlayer，但 m_audioQueue 里的旧音频
        //       仍然保留。下次 startWarningPlayback() 时新音频只能排到队列末尾，10秒计时器到了
        //       仍在等队列前面的旧音频播完，导致起车预警永远播不出来。
        m_isPlayingFromQueue = false;
        m_audioQueue.clear();
        m_mediaPlayer->stop();
        m_currentPlayCount = 0;
        m_currentAudioPath.clear();
    }
}

// ==================== 设备序列控制实现 ====================

void CommonControl::startDeviceSequence()
{
    if (!m_systemConfig) {
        qWarning() << "❌ CommonControl: 无法启动设备序列 - SystemConfig未设置";
        return;
    }

    if (m_isSequenceRunning) {
        qDebug() << "⚠️  CommonControl: 设备序列正在运行中，忽略新的启动请求";
        return;
    }

    // ✅ 2026-03-21 [Phase 7.48.68]: 从 device_logic_configs 读取per-device启动序列
    // 旧代码：m_currentSequence = m_systemConfig->startupSequence();
    if (m_deviceConfigMgr) {
        // 默认设备ID=1（后续可通过参数传入指定设备ID）
        QVariantMap logicConfig = m_deviceConfigMgr->loadDeviceLogicConfig(1);
        QString seqStr = logicConfig.value("startup_sequence", "[]").toString();
        QJsonArray seqArray = QJsonDocument::fromJson(seqStr.toUtf8()).array();
        m_currentSequence.clear();
        for (const QJsonValue &val : seqArray) {
            m_currentSequence.append(val.toString());
        }
    } else {
        m_currentSequence = m_systemConfig->startupSequence();
    }
    if (m_currentSequence.isEmpty()) {
        qDebug() << "⚠️  CommonControl: 启动顺序为空，无需执行";
        return;
    }

    qDebug() << "🚀 CommonControl: 开始执行启动顺序:" << m_currentSequence.join(" → ");
    m_isStartupSequence = true;
    m_isSequenceRunning = true;
    m_currentSequenceIndex = 0;

    // 更新RuntimeTracker：正在松闸（启动前）
    if (m_runtimeTracker) {
        m_runtimeTracker->onBrakeReleasing();
    }

    // 立即执行第一个设备
    executeNextDeviceInSequence();
}

void CommonControl::stopDeviceSequence()
{
    if (!m_systemConfig) {
        qWarning() << "❌ CommonControl: 无法停止设备序列 - SystemConfig未设置";
        return;
    }

    // 停止当前正在运行的序列
    if (m_isSequenceRunning) {
        qDebug() << "⏸️  CommonControl: 中断当前序列";
        m_isSequenceRunning = false;
        m_deviceSequenceTimer->stop();
    }

    // ✅ 2026-03-20 [Phase 7.48.59]: 取消所有正在运行的反馈检测定时器
    // 原因：启动序列激活多个设备时，每个设备都有独立的反馈超时定时器。
    //       当第一个设备失败触发 stopDeviceSequence() 时，其他设备的定时器仍在运行。
    //       这些定时器逐个超时后又各自触发 stopDeviceSequence()，
    //       导致同时有多个停止序列并发运行（日志中可见 [1/4] 2号电机 连续打印3次）。
    if (!m_feedbackChecks.isEmpty()) {
        QList<QString> activeDevices = m_feedbackChecks.keys();
        qDebug() << "⏹️  CommonControl: 取消" << activeDevices.size() << "个反馈检测定时器:" << activeDevices.join(", ");
        for (const QString &device : activeDevices) {
            stopFeedbackCheck(device);
        }
    }

    // ✅ 2026-03-21 [Phase 7.48.68]: 从 device_logic_configs 读取per-device停止序列
    // 旧代码：m_currentSequence = m_systemConfig->stopSequence();
    if (m_deviceConfigMgr) {
        QVariantMap logicConfig = m_deviceConfigMgr->loadDeviceLogicConfig(1);
        QString seqStr = logicConfig.value("stop_sequence", "[]").toString();
        QJsonArray seqArray = QJsonDocument::fromJson(seqStr.toUtf8()).array();
        m_currentSequence.clear();
        for (const QJsonValue &val : seqArray) {
            m_currentSequence.append(val.toString());
        }
    } else {
        m_currentSequence = m_systemConfig->stopSequence();
    }
    if (m_currentSequence.isEmpty()) {
        qDebug() << "⚠️  CommonControl: 停止顺序为空，无需执行";
        m_isFaultStop = false;  // 重置故障停止标志
        return;
    }

    if (m_isFaultStop) {
        qDebug() << "🛑 CommonControl: 故障停止，直接执行停止顺序（跳过停车预警）";
        m_isFaultStop = false;  // 重置故障停止标志
    } else {
        qDebug() << "🛑 CommonControl: 开始执行停止顺序:" << m_currentSequence.join(" → ");
    }

    m_isStartupSequence = false;
    m_isSequenceRunning = true;
    m_currentSequenceIndex = 0;

    // ✅ 2026-03-21 [Phase 7.48.70]: 发出停止序列开始信号（用于QML时间轴可视化停车过程）
    emit stopSequenceStarted();

    // 立即执行第一个设备
    executeNextDeviceInSequence();
}

// ✅ 2026-03-21 [Phase 7.48.72]: 重构为"前等待"语义
// 含义："张紧控制启动延时=5s"表示预警结束后等5秒才激活张紧
// 旧代码（后等待）：先激活设备，再用该设备的延时等待下一设备
// 新代码（前等待）：先用当前设备的延时等待，再激活当前设备
void CommonControl::executeNextDeviceInSequence()
{
    if (!m_isSequenceRunning || m_currentSequenceIndex >= m_currentSequence.size()) {
        // 序列执行完成
        m_isSequenceRunning = false;
        qDebug() << "✅ CommonControl: 设备序列执行完成";

        // 更新RuntimeTracker：序列完成后的状态
        if (m_runtimeTracker) {
            if (m_isStartupSequence) {
                m_runtimeTracker->onRunning();
            } else {
                m_runtimeTracker->onBrakeEngaging();
                QTimer::singleShot(500, this, [this]() {
                    if (m_runtimeTracker) {
                        m_runtimeTracker->onStopped();
                    }
                });
            }
        }
        return;
    }

    // 读取即将激活的设备的延时（前等待）
    const QString deviceName = m_currentSequence[m_currentSequenceIndex];
    int delayMs = 1000;  // 默认1秒

    if (m_deviceConfigMgr) {
        double delaySec = 1.0;
        QRegularExpression motorRe("(\\d+)号电机");
        QRegularExpression brakeRe("(\\d+)号制动器");
        auto motorMatch = motorRe.match(deviceName);
        auto brakeMatch = brakeRe.match(deviceName);
        if (motorMatch.hasMatch()) {
            int idx = motorMatch.captured(1).toInt() - 1;
            QVariantMap cfg = m_deviceConfigMgr->loadMotorConfig(1, idx, 0);
            delaySec = cfg.value("startup_delay", 8).toDouble();
        } else if (brakeMatch.hasMatch()) {
            int idx = brakeMatch.captured(1).toInt() - 1;
            QVariantMap cfg = m_deviceConfigMgr->loadBrakeConfig(1, idx);
            if (m_isStartupSequence) {
                delaySec = cfg.value("release_startup_delay", 1.0).toDouble();
            } else {
                delaySec = cfg.value("brake_startup_delay", 1.0).toDouble();
            }
        } else if (deviceName == "张紧控制" || deviceName == "张紧") {
            QVariantMap cfg = m_deviceConfigMgr->loadTensionConfig(1, 0);
            delaySec = cfg.value("startup_delay", 5).toDouble();
        }
        delayMs = static_cast<int>(delaySec * 1000);
    } else if (m_systemConfig) {
        QVariantList delays = m_isStartupSequence ?
            m_systemConfig->startupDelays() : m_systemConfig->stopDelays();
        if (m_currentSequenceIndex < delays.size()) {
            delayMs = static_cast<int>(delays[m_currentSequenceIndex].toDouble() * 1000);
        }
    }

    if (delayMs < 500) delayMs = 500;
    if (delayMs > 30000) delayMs = 30000;
    qDebug() << QString("  [%1/%2] 等待 %3ms 后%4设备: %5")
                    .arg(m_currentSequenceIndex + 1)
                    .arg(m_currentSequence.size())
                    .arg(delayMs)
                    .arg(m_isStartupSequence ? "启动" : "停止")
                    .arg(deviceName);
    m_deviceSequenceTimer->start(delayMs);
}

void CommonControl::onDeviceSequenceTimer()
{
    // ✅ 2026-03-21 [Phase 7.48.72]: 定时器到期，激活当前设备（前等待语义）
    if (!m_isSequenceRunning || m_currentSequenceIndex >= m_currentSequence.size()) {
        return;
    }

    const QString deviceName = m_currentSequence[m_currentSequenceIndex];
    qDebug() << QString("  [%1/%2] %3设备: %4")
                    .arg(m_currentSequenceIndex + 1)
                    .arg(m_currentSequence.size())
                    .arg(m_isStartupSequence ? "启动" : "停止")
                    .arg(deviceName);

    // 激活/停用设备
    activateDevice(deviceName, m_isStartupSequence);
    m_currentSequenceIndex++;

    // 继续执行下一个
    executeNextDeviceInSequence();
}

void CommonControl::activateDevice(const QString &deviceName, bool activate)
{
    qDebug() << QString("  %1 设备: %2").arg(activate ? "✅ 启动" : "⏹️  停止").arg(deviceName);

    // 记录设备启动/停止到数据库
    if (m_operationLogDB && m_systemConfig) {
        QString workModeName = getWorkModeName();
        if (activate) {
            m_operationLogDB->logDeviceStart(workModeName, deviceName);
        } else {
            m_operationLogDB->logDeviceStop(workModeName, deviceName);
        }
    }

    // 发送设备状态改变信号（更新UI）
    emit deviceStatusChanged(deviceName, activate);

    // 更新RuntimeTracker状态（识别电机停止）
    if (m_runtimeTracker && !activate) {
        // 停止电机2
        if (deviceName.contains("电机2") || deviceName.contains("2号电机")) {
            m_runtimeTracker->onMotor2Stopping();
        }
        // 停止电机1
        else if (deviceName.contains("电机1") || deviceName.contains("1号电机")) {
            m_runtimeTracker->onMotor1Stopping();
        }
    }

    if (activate) {
        // 启动设备时，检查是否需要启动反馈检测
        if (m_deviceFeedbackConfigs.contains(deviceName)) {
            DeviceFeedbackConfig config = m_deviceFeedbackConfigs[deviceName];
            if (config.useFeedback) {
                qDebug() << "  🔍 启动反馈检测:" << deviceName;
                startFeedbackCheck(deviceName, config.feedbackChannel, config.feedbackDelay);
            }
        }
    } else {
        // 停止设备时，停止反馈检测
        stopFeedbackCheck(deviceName);
    }

    // 通过NetworkTask控制Modbus寄存器
    if (m_networkTask) {
        // TODO: 需要从设备数据库或配置中获取设备的通道号
        // 这里暂时使用固定映射（后续需要从OutputDevicePanel获取）
        // 寄存器50：继电器输出模块，通道0-15
        int channel = getDeviceChannel(deviceName);
        if (channel >= 0) {
            const int OUTPUT_REGISTER = 50;  // 继电器输出模块寄存器地址
            // 使用QMetaObject::invokeMethod调用方法，避免包含NetworkTask.h
            // NetworkTask继承自QObject，这里安全转换
            QMetaObject::invokeMethod(reinterpret_cast<QObject*>(m_networkTask), "writeDeviceControl",
                                     Qt::QueuedConnection,
                                     Q_ARG(int, OUTPUT_REGISTER),
                                     Q_ARG(int, channel),
                                     Q_ARG(bool, activate));
        } else {
            qWarning() << "⚠️  CommonControl: 未找到设备通道配置:" << deviceName;
        }
    } else {
        qWarning() << "⚠️  CommonControl: NetworkTask未设置，无法控制设备";
    }
}

void CommonControl::setDeviceFeedbackConfig(const QString &deviceName, bool useFeedback, int feedbackChannel, int feedbackDelay)
{
    DeviceFeedbackConfig config;
    config.useFeedback = useFeedback;
    config.feedbackChannel = feedbackChannel;
    config.feedbackDelay = feedbackDelay;

    m_deviceFeedbackConfigs[deviceName] = config;

    qDebug() << "📋 CommonControl: 设置设备反馈配置 -" << deviceName
             << "使用反馈:" << useFeedback
             << "反馈通道:" << feedbackChannel
             << "反馈延时:" << feedbackDelay << "秒";
}

// ❌ 2026-02-15 20:30: 删除旧的 TTS 实现（使用 m_tts，已废弃）
// 新的实现在文件末尾，使用 m_ttsEngineManager

// ✅ 2026-03-20 [Phase 7.48.58]: 根据设备名获取通道号
// 支持逻辑控制面板的新名称和旧名称（兼容已有配置）
int CommonControl::getDeviceChannel(const QString &deviceName)
{
    // 设备名到通道号的映射（0-15）
    // ✅ 2026-03-20 [Phase 7.48.58]: 新增逻辑控制面板设备池名称别名
    static const QMap<QString, int> deviceChannelMap = {
        // 旧名称（DeviceDatabase默认名）
        {"张紧", 0},
        {"抱闸", 1},
        {"洒水", 2},
        {"1号电机", 3},
        {"2号电机", 4},
        {"破碎机", 5},
        {"转载机", 6},
        {"前刮板", 7},
        {"后刮板", 8},
        {"1号乳化液泵", 9},
        {"2号乳化液泵", 10},
        {"3号乳化液泵", 11},
        {"4号乳化液泵", 12},
        {"1号喷雾泵", 13},
        {"2号喷雾泵", 14},
        {"3号喷雾泵", 15},
        // ✅ 新名称别名（逻辑控制面板设备池使用）
        {"张紧控制", 0},    // = 张紧
        {"1号制动器", 1}    // = 抱闸
    };

    return deviceChannelMap.value(deviceName, -1);
}

// ==================== 反馈检测实现 ====================

void CommonControl::startFeedbackCheck(const QString &deviceName, int feedbackChannel, int feedbackDelay)
{
    qDebug() << "🔍 CommonControl: 启动反馈检测 -" << deviceName
             << "反馈通道:" << feedbackChannel
             << "延时:" << feedbackDelay << "秒";

    // 停止之前的检测（如果存在）
    stopFeedbackCheck(deviceName);

    // 创建新的反馈检测
    FeedbackCheck check;
    check.deviceName = deviceName;
    check.feedbackChannel = feedbackChannel;
    check.feedbackDelay = feedbackDelay;
    check.timer = new QTimer(this);
    check.timer->setSingleShot(true);
    check.isMonitoring = false;  // 初始为非监控状态（等待启动成功）
    check.lastFeedbackState = false;  // 初始状态为0

    // 连接超时信号
    connect(check.timer, &QTimer::timeout, this, [this, deviceName]() {
        onFeedbackTimeout(deviceName);
    });

    // 启动定时器
    check.timer->start(feedbackDelay * 1000);

    m_feedbackChecks[deviceName] = check;
}

void CommonControl::stopFeedbackCheck(const QString &deviceName)
{
    if (m_feedbackChecks.contains(deviceName)) {
        qDebug() << "⏹️  CommonControl: 停止反馈检测 -" << deviceName;
        FeedbackCheck &check = m_feedbackChecks[deviceName];
        if (check.timer) {
            check.timer->stop();
            check.timer->deleteLater();
        }
        m_feedbackChecks.remove(deviceName);
    }
}

void CommonControl::onFeedbackTimeout(const QString &deviceName)
{
    qDebug() << "⏰ CommonControl: 反馈超时 -" << deviceName;

    if (!m_feedbackChecks.contains(deviceName)) {
        return;
    }

    FeedbackCheck check = m_feedbackChecks[deviceName];
    int feedbackChannel = check.feedbackChannel;

    // 检查反馈通道的值
    bool feedbackOk = checkFeedbackBit(m_lastFeedbackRegisterValue, feedbackChannel);

    if (feedbackOk) {
        qDebug() << "✅ CommonControl: 反馈正常 -" << deviceName << "通道" << feedbackChannel << "为1";

        // 进入持续监控状态（而不是停止检测）
        m_feedbackChecks[deviceName].isMonitoring = true;
        m_feedbackChecks[deviceName].lastFeedbackState = true;
        qDebug() << "👁️  CommonControl: 进入持续监控状态 -" << deviceName;
    } else {
        qWarning() << "❌ CommonControl: 反馈失败 -" << deviceName << "通道" << feedbackChannel << "仍为0";

        // 停止当前所有音频播放
        stopWarningPlayback();
        if (m_mediaPlayer->playbackState() != QMediaPlayer::StoppedState) {
            m_mediaPlayer->stop();
        }
        m_isStopAudioPlaying = false;

        // 播放运行失败音频
        QString failureAudioPath = getDeviceFailureAudioPath(deviceName);
        if (!failureAudioPath.isEmpty()) {
            qDebug() << "🔊 CommonControl: 播放运行失败音频:" << failureAudioPath;
            playAudio(failureAudioPath);
        } else {
            qWarning() << "⚠️  CommonControl: 未找到运行失败音频:" << deviceName;
        }

        // 记录到数据库
        if (m_operationLogDB && m_systemConfig) {
            QString workModeName = getWorkModeName();
            m_operationLogDB->logOperation(workModeName, "反馈检测", "设备运行失败", deviceName, "反馈超时");
        }

        // 调用RuntimeTracker报告故障
        if (m_runtimeTracker) {
            m_runtimeTracker->onFault(deviceName + " 运行失败");
            m_runtimeTracker->onDeviceFault(deviceName);  // 记录故障设备
        }

        // 停止当前序列并执行停止序列
        qDebug() << "🛑 CommonControl: 设备运行失败，执行停止序列";
        stopFeedbackCheck(deviceName);
        m_isFaultStop = true;  // 标记为故障停止
        stopDeviceSequence();
    }
}

void CommonControl::onRegisterValueReceived(int registerAddress, quint16 value)
{
    // 只监听寄存器0（反馈输入模块）
    if (registerAddress != 0) {
        return;
    }

    m_lastFeedbackRegisterValue = value;

    // 检查所有正在检测的设备
    QList<QString> devicesToCheck = m_feedbackChecks.keys();
    for (const QString &deviceName : devicesToCheck) {
        // 检查设备是否仍在监控列表中（可能在循环中被删除）
        if (!m_feedbackChecks.contains(deviceName)) {
            continue;
        }

        FeedbackCheck &check = m_feedbackChecks[deviceName];
        int feedbackChannel = check.feedbackChannel;
        bool currentFeedbackState = checkFeedbackBit(value, feedbackChannel);

        if (!check.isMonitoring) {
            // 启动阶段：检查反馈位是否已经变为1
            if (currentFeedbackState) {
                qDebug() << "✅ CommonControl: 反馈正常（提前检测到） -" << deviceName
                         << "通道" << feedbackChannel << "为1";

                // 进入持续监控状态
                check.isMonitoring = true;
                check.lastFeedbackState = true;
                check.timer->stop();  // 停止超时定时器
                qDebug() << "👁️  CommonControl: 进入持续监控状态 -" << deviceName;
            }
        } else {
            // 持续监控阶段：检测从1→0的变化（设备故障）
            if (check.lastFeedbackState && !currentFeedbackState) {
                qWarning() << "❌ CommonControl: 设备运行失败（反馈信号丢失） -" << deviceName
                          << "通道" << feedbackChannel << "从1变为0";

                // 停止当前所有音频播放
                stopWarningPlayback();
                if (m_mediaPlayer->playbackState() != QMediaPlayer::StoppedState) {
                    m_mediaPlayer->stop();
                }
                m_isStopAudioPlaying = false;

                // 播放运行失败音频
                QString failureAudioPath = getDeviceFailureAudioPath(deviceName);
                if (!failureAudioPath.isEmpty()) {
                    qDebug() << "🔊 CommonControl: 播放运行失败音频:" << failureAudioPath;
                    playAudio(failureAudioPath);
                } else {
                    qWarning() << "⚠️  CommonControl: 未找到运行失败音频:" << deviceName;
                }

                // 记录到数据库
                if (m_operationLogDB && m_systemConfig) {
                    QString workModeName = getWorkModeName();
                    m_operationLogDB->logOperation(workModeName, "反馈检测", "设备运行失败", deviceName, "反馈信号丢失");
                }

                // 调用RuntimeTracker报告故障
                if (m_runtimeTracker) {
                    m_runtimeTracker->onFault(deviceName + " 运行失败");
                    m_runtimeTracker->onDeviceFault(deviceName);  // 记录故障设备
                }

                // 停止当前序列并执行停止序列
                qDebug() << "🛑 CommonControl: 设备运行失败，执行停止序列";
                stopFeedbackCheck(deviceName);  // 这会从map中删除元素
                m_isFaultStop = true;  // 标记为故障停止
                stopDeviceSequence();

                // ⚠️ 重要：删除元素后立即continue，避免访问已删除的引用
                continue;
            }

            // 更新上次状态（只有在元素仍存在时才执行）
            check.lastFeedbackState = currentFeedbackState;
        }
    }
}

bool CommonControl::checkFeedbackBit(quint16 registerValue, int channel)
{
    if (channel < 0 || channel > 15) {
        return false;
    }

    // 检查指定位是否为1
    return (registerValue & (1 << channel)) != 0;
}

QString CommonControl::getDeviceFailureAudioPath(const QString &deviceName)
{
    // 获取应用程序根目录
    QString appDir = QCoreApplication::applicationDirPath();

    // 获取皮带编号（从SystemConfig获取）
    if (!m_systemConfig) {
        qWarning() << "⚠️  CommonControl: SystemConfig未设置，无法获取皮带编号";
        return QString();
    }

    int beltNumber = m_systemConfig->machineNumber();
    QString folderName = QString("%1#PD").arg(beltNumber);

    // 构建音频文件名列表
    QStringList possibleNames;

    // 特殊处理：抱闸对应"1号松闸运行失败"（所有皮带都用同样的文件名）
    if (deviceName == "抱闸") {
        possibleNames << "1号松闸运行失败.mp3";
        possibleNames << "1号松闸运行失败.wav";
    } else {
        // 格式1: "设备名称运行失败.mp3" (例如: "张紧运行失败.mp3", "1号电机运行失败.mp3")
        possibleNames << QString("%1运行失败.mp3").arg(deviceName);
        possibleNames << QString("%1运行失败.wav").arg(deviceName);
    }

    // ✅ 2026-03-21 [Phase 7.48.69]: TTS合成路径优先（与getAudioPath()对齐）
    // 原因：getAudioPath()在Phase 7.48.60中已添加TTS路径支持，但getDeviceFailureAudioPath()
    //       遗漏了这一步，导致音频来源为TTS时播放的是默认路径而非TTS合成路径
    if (m_systemConfig && m_systemConfig->beltAudioSource() == 1) {
        TTSConfigManager *ttsConfig = TTSConfigManager::instance();
        int modelIndex = ttsConfig->modelIndex(TTSConfigManager::Test);
        QString engineName = "paddlespeech";
        QString modelName = ttsConfig->modelName(modelIndex);
        int speakerId = ttsConfig->speakerId(TTSConfigManager::Test);
        QString ttsFolder = QString("%1/%2-%3-spk%4/%5")
                                .arg(DataPathConfig::getAudioBaseDirectory())
                                .arg(engineName)
                                .arg(modelName)
                                .arg(speakerId)
                                .arg(folderName);
        for (const QString &fileName : possibleNames) {
            QString audioPath = QString("%1/%2").arg(ttsFolder, fileName);
            if (QFile::exists(audioPath)) {
                qDebug() << "✅ CommonControl: 使用TTS运行失败音频:" << audioPath;
                return audioPath;
            }
        }
        qDebug() << "⚠️ CommonControl: TTS路径未找到运行失败音频，回退到默认路径";
        qDebug() << "   TTS文件夹:" << ttsFolder;
    }

    // ✅ 2026-03-21 [Phase 7.48.64]: 先在数据目录（容器挂载卷）中查找运行失败音频
    // 原因：getAudioPath()已在Phase 7.48.62中添加了数据目录支持，但getDeviceFailureAudioPath()
    //       遗漏了这一步，导致/home/linaro/belt-control-data/audio/中的音频无法被找到
    QString dataBaseDir = DataPathConfig::getAudioBaseDirectory();
    QString dataFolder = QString("%1/%2").arg(dataBaseDir, folderName);
    for (const QString &fileName : possibleNames) {
        QString audioPath = QString("%1/%2").arg(dataFolder, fileName);
        if (QFile::exists(audioPath)) {
            qDebug() << "✅ CommonControl: 找到运行失败音频（数据目录）:" << audioPath;
            return audioPath;
        }
    }
    qDebug() << "⚠️  CommonControl: 数据目录未找到运行失败音频:" << dataFolder;

    // 在 AUDIO/<皮带号>#PD 目录下查找音频文件（兜底）
    for (const QString &fileName : possibleNames) {
        QString audioPath = QString("%1/AUDIO/%2/%3").arg(appDir, folderName, fileName);
        if (QFile::exists(audioPath)) {
            qDebug() << "✅ CommonControl: 找到运行失败音频（应用目录）:" << audioPath;
            return audioPath;
        }
    }

    qDebug() << "⚠️  CommonControl: 在以下位置均未找到运行失败音频:";
    qDebug() << "   数据目录:" << dataFolder << "/";
    qDebug() << "   应用目录:" << QString("%1/AUDIO/%2/").arg(appDir, folderName);
    qDebug() << "   尝试的文件名:" << possibleNames.join(", ");

    return QString();
}

QString CommonControl::getWorkModeName() const
{
    if (!m_systemConfig) {
        return "未知";
    }

    switch (m_systemConfig->workMode()) {
        case SystemConfig::Maintenance: return "检修";
        case SystemConfig::Local: return "就地";
        case SystemConfig::Jog: return "点动";
        case SystemConfig::Centralized: return "集控";
        default: return "未知";
    }
}

// ✅ 2026-01-23 01:45 [TTS发音优化] 数字转中文函数实现
// 原因：
//   - 用户反馈："'1'没有播放出来，直接号皮带启动"
//   - TTS 模型对阿拉伯数字"1"发音不清晰（日志：line 515-517 合成成功但用户听不到"1"）
//   - 解决方案：使用中文数字"一"代替阿拉伯数字"1"
// 新格式：
//   - 旧："1号皮带启动"
//   - 新："一号皮带准备启动，请注意。"
// 效果：
//   - TTS 对中文数字发音清晰准确
//   - 增加"准备启动"和"请注意"使语音更友好自然
QString CommonControl::numberToChinese(int number) const
{
    // 支持 1-10 号皮带的中文数字转换
    static const QMap<int, QString> chineseNumbers = {
        {1, "一"},
        {2, "二"},
        {3, "三"},
        {4, "四"},
        {5, "五"},
        {6, "六"},
        {7, "七"},
        {8, "八"},
        {9, "九"},
        {10, "十"}
    };

    // 如果在映射范围内，返回中文数字
    if (chineseNumbers.contains(number)) {
        return chineseNumbers[number];
    }

    // 超出范围时回退到阿拉伯数字（如 11, 12 等）
    return QString::number(number);
}

// ========================================
// ✅ 2026-01-21 20:30 [音频网络传输] 新增配置方法
// ========================================

void CommonControl::setAudioOutputMode(AudioOutputMode mode)
{
    m_audioOutputMode = mode;

    const char* modeName = (mode == LocalOnly ? "仅本地" :
                            mode == NetworkOnly ? "仅网络" : "本地+网络");
    qDebug() << "✅ CommonControl: 设置音频输出模式:" << modeName;
}

void CommonControl::configureNetworkAudio(const QString &multicastAddress,
                                          quint16 port,
                                          int bitrate)
{
    qDebug() << "✅ CommonControl: 配置网络音频";
    qDebug() << "   组播地址:" << multicastAddress << ":" << port;
    qDebug() << "   Opus 比特率:" << bitrate << "bps";

    m_audioNetworkSender->setUdpMulticastAddress(multicastAddress, port);
    m_audioNetworkSender->setOpusBitrate(bitrate);
}

CommonControl::AudioOutputMode CommonControl::audioOutputMode() const
{
    return m_audioOutputMode;
}

// ✅ 2026-01-22 20:00 [TCP音频传输] TCP 模式配置方法实现

void CommonControl::configureTcpAudio(quint16 udpDiscoveryPort,
                                       const AudioNetworkTcpSender::DeviceInfo &deviceInfo)
{
    qDebug() << "✅ CommonControl: 配置 TCP 音频传输";
    qDebug() << "   UDP 发现端口:" << udpDiscoveryPort;
    qDebug() << "   设备信息:";
    qDebug() << "      - 名称:" << deviceInfo.name;
    qDebug() << "      - UUID:" << deviceInfo.uuid;
    qDebug() << "      - 型号:" << deviceInfo.plain;

    m_audioNetworkTcpSender->setUdpDiscoveryPort(udpDiscoveryPort);
    m_audioNetworkTcpSender->setDeviceInfo(deviceInfo);
}

void CommonControl::startTcpDiscovery()
{
    qDebug() << "📡 CommonControl: 启动 TCP 服务发现";
    m_audioNetworkTcpSender->startDiscovery();
}

// ========================================
// ✅ 2026-02-13 [Phase 7.46.7]: TTS 引擎管理方法实现
// ========================================

void CommonControl::registerTTSEngines()
{
    qDebug() << "🔧 [CommonControl] 注册 TTS 引擎";

    // 1. 注册 PaddleSpeech（中文质量最好，优先）
    PaddleSpeechAdapter *paddleAdapter = new PaddleSpeechAdapter(this);
    if (m_ttsEngineManager->registerEngine(paddleAdapter)) {
        qDebug() << "✅ [CommonControl] PaddleSpeech 注册成功";
    } else {
        qWarning() << "❌ [CommonControl] PaddleSpeech 注册失败";
    }

    // ❌ 2026-02-24 23:00 [禁用 MeloTTS]: 不适合煤矿工业场景
    // 原因：语音太柔和，缺乏权威感，部署复杂（需要 Rust 编译）
    // 详见：docs/2026-02-24/21-煤矿工业场景TTS方案分析.md
    /*
    // 2. 注册 MeloTTS（语音质量接近商业级别）
    MeloTTSAdapter *meloAdapter = new MeloTTSAdapter(this);
    if (m_ttsEngineManager->registerEngine(meloAdapter)) {
        qDebug() << "✅ [CommonControl] MeloTTS 注册成功";
    } else {
        qWarning() << "❌ [CommonControl] MeloTTS 注册失败";
    }
    */

    qDebug() << "✅ [CommonControl] 所有 TTS 引擎注册完成";
}

bool CommonControl::switchTTSEngine(int engineIndex)
{
    if (!m_ttsEngineManager) {
        qWarning() << "⚠️ [CommonControl] TTS 引擎管理器未初始化";
        return false;
    }

    // 引擎索引到名称的映射
    static const QMap<int, QString> ENGINE_NAMES = {
        {0, "PaddleSpeech"}
        // ❌ 2026-02-24 23:00 [禁用]: {1, "MeloTTS"}
    };

    if (!ENGINE_NAMES.contains(engineIndex)) {
        qWarning() << "⚠️ [CommonControl] 无效的引擎索引:" << engineIndex;
        return false;
    }

    QString engineName = ENGINE_NAMES[engineIndex];
    qDebug() << "🔄 [CommonControl] 切换 TTS 引擎 - 索引:" << engineIndex << "名称:" << engineName;

    bool success = m_ttsEngineManager->setCurrentEngine(engineName);

    if (success) {
        qDebug() << "✅ [CommonControl] TTS 引擎切换成功:" << engineName;
    } else {
        qWarning() << "❌ [CommonControl] TTS 引擎切换失败:" << engineName;
    }

    return success;
}

bool CommonControl::switchTTSModel(int modelIndex)
{
    if (!m_ttsEngineManager) {
        qWarning() << "⚠️ [CommonControl] TTS 引擎管理器未初始化";
        return false;
    }

    qDebug() << "🔄 [CommonControl] 切换 TTS 模型 - 索引:" << modelIndex;

    // 获取当前引擎的模型列表
    QStringList modelList = m_ttsEngineManager->getModelList();
    if (modelIndex < 0 || modelIndex >= modelList.size()) {
        qWarning() << "⚠️ [CommonControl] 无效的模型索引:" << modelIndex;
        return false;
    }

    // ✅ 2026-02-15 22:40: 实现模型切换逻辑
    // 获取当前引擎名称
    QString engineName = m_ttsEngineManager->currentEngine();

    // 提取模型名称（去掉括号中的描述）
    QString modelDisplayName = modelList[modelIndex];
    QString modelName = modelDisplayName.split(" ").first();  // 例如 "fastspeech2_csmsc (中文女声)" -> "fastspeech2_csmsc"

    // 构建模型路径
    // ✅ 2026-02-26 16:30 [Phase 7.47.12]: 修复模型路径
    // 原因：Docker 挂载 /home/linaro/belt-control-data/models/tts_models → /app/tts_models
    //       容器内应使用 /app/tts_models，不是宿主机路径
    // 效果：兼容 pi 和 linaro 两种设备
    QString modelPath;
    if (engineName == "PaddleSpeech") {
#ifdef Q_OS_LINUX
        // modelPath = QString("/home/pi/belt-control-data/models/tts_models/paddlespeech/%1").arg(modelName);
        modelPath = QString("/app/tts_models/paddlespeech/%1").arg(modelName);
#else
        modelPath = QString("tts_models/paddlespeech/%1").arg(modelName);
#endif
    /*
    // ❌ 2026-02-24 23:00 [禁用 MeloTTS]
    } else if (engineName == "MeloTTS") {
#ifdef Q_OS_LINUX
        // modelPath = QString("/home/pi/belt-control-data/models/tts_models/melotts/%1").arg(modelName);
        modelPath = QString("/app/tts_models/melotts/%1").arg(modelName);
#else
        modelPath = QString("tts_models/melotts/%1").arg(modelName);
#endif
    */
    } else {
        qWarning() << "⚠️ [CommonControl] 不支持的引擎:" << engineName;
        return false;
    }

    qDebug() << "   模型路径:" << modelPath;

    // ✅ 2026-02-15 22:40: 调用引擎管理器初始化当前引擎
    if (!m_ttsEngineManager->initialize(modelPath)) {
        qWarning() << "❌ [CommonControl] TTS 引擎初始化失败";
        return false;
    }

    qDebug() << "✅ [CommonControl] TTS 模型切换成功:" << modelList[modelIndex];
    return true;
}

// ✅ 2026-02-28 09:30 [Phase 7.47.39]: 异步切换TTS模型
// 原因：PaddleSpeech初始化阻塞主线程5-10分钟，导致程序启动卡住
// 效果：后台线程执行初始化，UI立即可用
void CommonControl::switchTTSModelAsync(int modelIndex)
{
    qDebug() << "🔄 [CommonControl] 异步切换 TTS 模型 - 索引:" << modelIndex;

    QThread *thread = QThread::create([this, modelIndex]() {
        bool success = switchTTSModel(modelIndex);
        // 使用 QueuedConnection 将信号发送回主线程
        QMetaObject::invokeMethod(this, [this, success, modelIndex]() {
            if (success) {
                qDebug() << "✅ [CommonControl] TTS 模型异步切换完成";
            } else {
                qWarning() << "❌ [CommonControl] TTS 模型异步切换失败";
            }
            emit ttsModelSwitchCompleted(success, modelIndex);
        }, Qt::QueuedConnection);
    });

    connect(thread, &QThread::finished, thread, &QThread::deleteLater);
    thread->start();
}

QStringList CommonControl::getTTSModelList()
{
    if (!m_ttsEngineManager) {
        qWarning() << "⚠️ [CommonControl] TTS 引擎管理器未初始化";
        return QStringList();
    }

    return m_ttsEngineManager->getModelList();
}

int CommonControl::getMaxSpeakerId(int modelIndex)
{
    if (!m_ttsEngineManager) {
        qWarning() << "⚠️ [CommonControl] TTS 引擎管理器未初始化";
        return 0;
    }

    // ✅ 2026-02-21 22:10: 添加调试日志
    // 原因：说话人ID范围不正确，需要确认调用时的引擎和索引
    qDebug() << "🔍 [CommonControl] getMaxSpeakerId - 模型索引:" << modelIndex
             << "当前引擎:" << m_ttsEngineManager->currentEngine();

    int maxSpeakerId = m_ttsEngineManager->getMaxSpeakerId(modelIndex);
    qDebug() << "   返回最大说话人ID:" << maxSpeakerId;

    return maxSpeakerId;
}

QString CommonControl::getCurrentTTSEngine()
{
    if (!m_ttsEngineManager) {
        qWarning() << "⚠️ [CommonControl] TTS 引擎管理器未初始化";
        return QString();
    }

    return m_ttsEngineManager->currentEngine();
}

void CommonControl::testTTS(const QString &text, int speakerId, double rate, double volume)
{
    if (!m_ttsEngineManager) {
        qWarning() << "⚠️ [CommonControl] TTS 引擎管理器未初始化";
        return;
    }

    qDebug() << "🎙️ [CommonControl] 测试 TTS - 文本:" << text
             << "说话人ID:" << speakerId
             << "语速:" << rate
             << "音量:" << volume;

    // 设置 TTS 参数
    TTSParameters params;
    params.speakerId = speakerId;
    params.rate = rate;
    params.volume = volume;
    // ✅ 2026-02-26 [Phase 7.47.19]: 使用配置的采样率
    params.sampleRate = TTSConfigManager::instance()->sampleRate(TTSConfigManager::Test);

    // 生成临时输出文件
    QString outputPath = "/tmp/test_tts.wav";

    // 合成语音
    if (m_ttsEngineManager->synthesize(text, outputPath, params)) {
        qDebug() << "✅ [CommonControl] TTS 合成成功:" << outputPath;

        // ✅ 2026-02-26 [Phase 7.47.17]: 清除该文件的 Opus 缓存
        // 原因：TTS 每次合成到同一文件，但 Opus 缓存使用文件路径作为键
        //       导致播放的是旧的缓存音频，而不是新合成的音频
        // 效果：清除缓存后，下次播放会重新编码新文件
        if (m_audioNetworkTcpSender) {
            m_audioNetworkTcpSender->removeFromOpusCache(outputPath);
        }

        // 播放生成的语音
        playAudio(outputPath);
    } else {
        qWarning() << "❌ [CommonControl] TTS 合成失败";
    }
}

// ✅ 2026-02-26 [Phase 7.47.19]: 采样率配置
void CommonControl::setTTSSampleRate(int sampleRate)
{
    qDebug() << "🔧 [CommonControl] 设置 TTS 采样率:" << sampleRate << "Hz";
    TTSConfigManager::instance()->setSampleRate(TTSConfigManager::Test, sampleRate);
    TTSConfigManager::instance()->saveConfig();
}

int CommonControl::getTTSSampleRate()
{
    return TTSConfigManager::instance()->sampleRate(TTSConfigManager::Test);
}

