#ifndef COMMONCONTROL_H
#define COMMONCONTROL_H

#include <QObject>
#include <QMediaPlayer>
#include <QAudioOutput>
// ❌ 2026-03-03 [Phase 7.47.75]: 回退 QSoundEffect，在 Docker 容器中失败
// 原因：QSoundEffect 通过 QAudioSink 需要 Qt 枚举音频设备
//        容器无 PulseAudio → Qt 枚举为空 → "No audio device detected"
//        与当初改用 QMediaPlayer+GStreamer 的原因完全一致
//        另外：play() 调用时文件仍在 Loading，isPlaying()=false → playingChanged 立刻误触发
// ✅ 2026-03-03 [Phase 7.47.73]: 添加 QSoundEffect，用于替代 QMediaPlayer 本地播放
// // 原因：QMediaPlayer 依赖 GStreamer 流式 pipeline，每次 setSource() 重建 pipeline
// //        引发 Buffer Underrun，导致语音卡顿。QSoundEffect 预加载 WAV 到内存后
// //        通过 QAudioSink 直接写 ALSA，与 aplay 路径相同，无流式重采样卡顿。
// #include <QSoundEffect>
#include <QKeyEvent>
#include <QTimer>
#include <QElapsedTimer>  // ✅ 2026-02-26 [Phase 7.47.8]: 播放时长计时器
#include <QThread>        // ✅ 2026-02-28 [Phase 7.47.39]: TTS异步初始化

// ✅ 2026-01-21 20:15 [音频网络传输] 添加音频网络发送器
#include "../audio_network/AudioNetworkSender.h"
// ✅ 2026-01-22 20:00 [TCP音频传输] 添加 TCP 模式音频发送器
#include "../audio_network/AudioNetworkTcpSender.h"
// ✅ 2026-01-23 00:00 [TTS网络传输] 添加 TTS 语音网络传输
// ✅ 2026-02-13 [Phase 7.46.7]: 注释掉旧的 SherpaOnnxTTS，改用 TTSEngineManager
// #include "SherpaOnnxTTS.h"

// ✅ 2026-02-13 [Phase 7.46.7]: 添加 TTS 引擎管理器
#include "tts/TTSEngineManager.h"
#include "tts/PaddleSpeechAdapter.h"
// ❌ 2026-02-24 23:00 [禁用 MeloTTS]: 不适合煤矿工业场景（语音太柔和，缺乏权威感）
// #include "tts/MeloTTSAdapter.h"

// 前向声明
class SystemConfig;
class NetworkTask;
class DeviceRuntimeTracker;
class DeviceConfigManager;  // ✅ 2026-03-21 [Phase 7.48.68]: 逻辑控制配置读取

/**
 * @brief 公共控制类 - 处理所有的控制逻辑
 *
 * 功能：
 * - 监听键盘事件
 * - 播放音频提示
 * - 控制皮带启动/停止
 * - 起车预警播放（按时间/按次数）
 */
class CommonControl : public QObject
{
    Q_OBJECT

public:
    // ✅ 2026-01-21 20:15 [音频网络传输] 添加音频输出模式枚举
    /**
     * @brief 音频输出模式
     */
    enum AudioOutputMode {
        LocalOnly,      ///< 仅本地音频设备（ES8388）
        NetworkOnly,    ///< 仅网络音频模块（UDP 组播）
        DualOutput,     ///< 本地 + 网络同时输出
        NetworkTcp      ///< 仅网络音频模块（TCP 模式）✅ 2026-01-22 20:00 [TCP音频传输] 新增
    };
    Q_ENUM(AudioOutputMode)

    explicit CommonControl(QObject *parent = nullptr);
    ~CommonControl();

    // 键盘事件过滤器
    bool eventFilter(QObject *watched, QEvent *event) override;

    // 设置系统配置（用于读取预警参数）
    void setSystemConfig(SystemConfig *config);

    // ✅ 2026-03-21 [Phase 7.48.68]: 设置设备配置管理器
    void setDeviceConfigManager(DeviceConfigManager *mgr);
    void setNetworkTask(NetworkTask *task);

    // 设置运行日志数据库（用于记录操作）
    void setOperationLogDB(class OperationLogDatabase *logDB);

    // 设置设备运行时间跟踪器（用于状态跟踪）
    void setRuntimeTracker(DeviceRuntimeTracker *tracker);

    // ✅ 2026-01-21 20:15 [音频网络传输] 添加音频输出配置方法
    /**
     * @brief 设置音频输出模式
     * @param mode 输出模式（LocalOnly, NetworkOnly, DualOutput）
     */
    Q_INVOKABLE void setAudioOutputMode(AudioOutputMode mode);

    /**
     * @brief 配置网络音频参数
     * @param multicastAddress 组播地址（默认：224.1.1.1）
     * @param port 组播端口（默认：8800）
     * @param bitrate Opus 比特率（默认：16000，范围：16000-32000）
     */
    Q_INVOKABLE void configureNetworkAudio(const QString &multicastAddress = "224.1.1.1",
                                           quint16 port = 8800,
                                           int bitrate = 16000);

    // ✅ 2026-01-22 20:00 [TCP音频传输] 添加 TCP 模式配置方法
    /**
     * @brief 配置 TCP 音频传输参数
     * @param udpDiscoveryPort UDP 服务发现端口（默认：8600）
     * @param deviceInfo 设备信息（名称、UUID 等）
     */
    Q_INVOKABLE void configureTcpAudio(quint16 udpDiscoveryPort = 8600,
                                       const AudioNetworkTcpSender::DeviceInfo &deviceInfo = AudioNetworkTcpSender::DeviceInfo());

    /**
     * @brief 启动 TCP 模式服务发现
     *
     * 说明：
     * - 绑定 UDP 端口 8600（或自定义端口）
     * - 等待上位机广播配置 JSON
     * - 解析 TCP 服务器 IP 和端口
     * - 自动连接并发送设备信息
     */
    Q_INVOKABLE void startTcpDiscovery();

    /**
     * @brief 获取当前音频输出模式
     * @return 当前输出模式
     */
    Q_INVOKABLE AudioOutputMode audioOutputMode() const;

    // ✅ 2026-02-13 [Phase 7.46.7]: TTS 引擎管理接口

    /**
     * @brief 切换 TTS 引擎
     * @param engineIndex 引擎索引（0: PaddleSpeech, 1: MeloTTS）
     * @return 切换是否成功
     */
    Q_INVOKABLE bool switchTTSEngine(int engineIndex);

    /**
     * @brief 切换 TTS 模型
     * @param modelIndex 模型索引
     * @return 切换是否成功
     */
    Q_INVOKABLE bool switchTTSModel(int modelIndex);

    /**
     * @brief 异步切换 TTS 模型（不阻塞主线程）
     * @param modelIndex 模型索引
     * ✅ 2026-02-28 [Phase 7.47.39]: 启动优化，后台线程初始化TTS引擎
     */
    Q_INVOKABLE void switchTTSModelAsync(int modelIndex);

    /**
     * @brief 获取当前引擎的模型列表
     * @return 模型名称列表
     */
    Q_INVOKABLE QStringList getTTSModelList();

    /**
     * @brief 获取指定模型的最大说话人ID
     * @param modelIndex 模型索引
     * @return 最大说话人ID
     */
    Q_INVOKABLE int getMaxSpeakerId(int modelIndex);

    /**
     * @brief 获取当前 TTS 引擎名称
     * @return 引擎名称
     */
    Q_INVOKABLE QString getCurrentTTSEngine();

    /**
     * @brief 获取 TTS 引擎管理器
     * @return TTS 引擎管理器指针
     * ✅ 2026-02-26 08:50 [Phase 7.47.3]: 添加此方法供 BatchAudioGenerator 使用
     */
    TTSEngineManager* getTTSEngineManager() { return m_ttsEngineManager; }

    /**
     * @brief 测试 TTS 语音合成
     * @param text 要合成的文本
     * @param speakerId 说话人ID
     * @param rate 语速
     * @param volume 音量
     */
    Q_INVOKABLE void testTTS(const QString &text, int speakerId = 0, double rate = 1.0, double volume = 0.8);

    /**
     * @brief 设置 TTS 采样率
     * @param sampleRate 采样率（16000, 22050, 24000, 44100, 48000）
     * ✅ 2026-02-26 [Phase 7.47.19]: 添加采样率配置
     */
    Q_INVOKABLE void setTTSSampleRate(int sampleRate);

    /**
     * @brief 获取当前 TTS 采样率
     * @return 采样率
     */
    Q_INVOKABLE int getTTSSampleRate();

signals:
    void beltStartRequested(int beltNumber);  // 皮带启动请求
    void beltStopRequested(int beltNumber);   // 皮带停止请求
    void warningPlaybackFinished();           // 预警播放完成
    // ✅ 2026-03-21 [Phase 7.48.66]: 预警开始信号（用于时间轴实时可视化）
    void warningStarted();                    // 预警播放开始（运行键按下后立即发出）
    void deviceStatusChanged(const QString &deviceName, bool isRunning);  // 设备状态改变
    // ✅ 2026-03-21 [Phase 7.48.70]: 停止序列开始信号（用于时间轴实时可视化停车过程）
    void stopSequenceStarted();   // 停止序列开始执行
    // ✅ 2026-03-21 [Phase 7.48.72]: 停车预警开始信号（S键按下时立即发出）
    void stopWarningStarted();    // 停车预警开始（用于QML立即切换到停止Tab）

    // ✅ 2026-02-21 22:45: 添加 TTS 初始化进度信号
    // 原因：PaddleSpeech 初始化需要 5-10 分钟，QML 需要显示进度
    void ttsInitializationProgress(const QString &message);  // TTS 初始化进度

    // ✅ 2026-02-28 [Phase 7.47.39]: TTS模型异步切换完成信号
    void ttsModelSwitchCompleted(bool success, int modelIndex);

    // ✅ 2026-03-23 [Phase 7.48.86]: 电机状态信号（用于速度保护启动延时）
    // 原因：MqttProtectionMonitor::notifyMotorStarted/Stopped 从未被调用，
    //       m_motorRunning 始终为 false，速度保护启动延时形同虚设
    void motorActivated(int beltNumber);    // 电机启动（第一个电机激活时发出）
    void motorDeactivated(int beltNumber);  // 电机停止（最后一个电机停用时发出）

    // ✅ 2026-03-25 [Phase 7.48.88.21]: 按皮带号运行状态变化信号
    void beltRunningChanged(int beltNumber, bool running);

    // ✅ 2026-03-26 [Phase 7.48.88.25]: 序列执行进度信号（供QML卡片显示阶段状态）
    // phase: "起车预警"/"松闸"/"1号电机"/"运行"/"停车预警"/"停止"等
    // current/total: 当前步骤/总步骤数
    // delayMs: 当前步骤倒计时毫秒数（0=无倒计时）
    void beltSequenceProgress(int beltNumber, const QString &phase, int current, int total, int delayMs);

public slots:
    // 播放指定的音频文件
    void playAudio(const QString &audioPath);

    // 皮带控制函数
    // ✅ 2026-03-25 [Phase 7.48.88.21]: 添加 Q_INVOKABLE，支持QML数字键直接调用
    Q_INVOKABLE void startBelt(int beltNumber);  // 启动指定编号的皮带（带预警播放）
    Q_INVOKABLE void stopBelt(int beltNumber);   // 停止指定编号的皮带（播放停车音频，然后停止设备序列）

    // ✅ 2026-03-23 [Phase 7.48.85]: 紧急停车（跳过停车音频，直接执行停止序列）
    // 用途：保护逻辑控制器触发紧急停车（protection_level=0）
    void emergencyStopBelt(int beltNumber);

    // 停止当前预警播放
    void stopWarningPlayback();

    // 设备序列控制（通过R/S键盘快捷键触发）
    // ✅ 2026-03-25 [Phase 7.48.88.22]: 改为带皮带号参数，支持多皮带并行序列
    Q_INVOKABLE void startDeviceSequence(int beltNumber = 0);  // 按启动顺序启动设备（0=使用m_currentBeltNumber）
    Q_INVOKABLE void stopDeviceSequence(int beltNumber = 0);   // 按停止顺序停止设备（0=使用m_currentBeltNumber）

    // ✅ 2026-03-25 [Phase 7.48.88.22]: 获取序列执行状态（支持按皮带号查询）
    // 返回：{isRunning, isStartup, currentIndex, totalCount, isWarning, isStopAudio}
    Q_INVOKABLE QVariantMap getSequenceState() const;           // 返回当前音频皮带的状态
    Q_INVOKABLE QVariantMap getSequenceState(int beltNumber) const;  // 返回指定皮带状态

    // ✅ 2026-03-25 [Phase 7.48.88.21]: 按皮带号查询运行状态（用于数字键toggle判断）
    Q_INVOKABLE bool isBeltRunning(int beltNumber) const;

    // ✅ 2026-03-27 [Phase 7.48.88.32]: 按皮带号查询是否正在启动中（预警播放或启动序列执行中）
    // 安全修复：启动过程中按停止键必须能中断启动，否则有安全隐患
    Q_INVOKABLE bool isBeltStarting(int beltNumber) const;

    // 设置设备反馈参数（从QML调用）
    Q_INVOKABLE void setDeviceFeedbackConfig(const QString &deviceName, bool useFeedback, int feedbackChannel, int feedbackDelay);

    // ✅ 2026-02-13 [Phase 7.45.35, 7.45.36, 7.45.37]: 旧的 TTS 方法已移到上面的 TTS 引擎管理接口区域

private slots:
    void onMediaPlayerError(QMediaPlayer::Error error, const QString &errorString);
    void onPlaybackFinished();
    void onWarningTimerTimeout();  // 按时间模式的定时器超时
    // ❌ 2026-03-25 [Phase 7.48.88.22]: 废弃单一定时器槽，改用per-belt lambda定时器
    // void onDeviceSequenceTimer();  // 设备序列定时器超时
    void onRegisterValueReceived(int registerAddress, quint16 value);  // 接收寄存器值（用于反馈检测）

private:
    QMediaPlayer *m_mediaPlayer;   // 音频播放器（GStreamer 后端，用于网络/复杂场景）
    QAudioOutput *m_audioOutput;   // 音频输出（配套 QMediaPlayer）
    // ❌ 2026-03-03 [Phase 7.47.75]: QSoundEffect 在 Docker 容器中失败，已回退
    //    "No audio device detected"：QAudioSink 需枚举设备，容器无 PulseAudio → 枚举为空
    //    play() 时 isPlaying()=false → playingChanged 立刻误触发 onPlaybackFinished()（0秒）
    // ✅ 2026-03-03 [Phase 7.47.73]: QSoundEffect 本地播放（优先，低延迟无卡顿）
    // // 历史原因：选 QMediaPlayer 是因为容器无 PulseAudio 时 Qt 无法枚举 ALSA 设备
    // //   但枚举失败 ≠ 播放失败。QSoundEffect 用 QAudioSink 直接写 ALSA default
    // //   与 aplay 同路径，不受枚举限制，且无 GStreamer 流式 pipeline 开销。
    // // 策略：本地播放优先用 QSoundEffect；失败（status=Error）时回退 QMediaPlayer
    // QSoundEffect *m_soundEffect;       // 低延迟本地播放（QAudioSink → ALSA direct）
    // bool m_usingSoundEffect;           // 当前是否正在用 QSoundEffect 播放
    SystemConfig *m_systemConfig;  // 系统配置
    DeviceConfigManager *m_deviceConfigMgr = nullptr;  // ✅ 2026-03-21 [Phase 7.48.68]
    NetworkTask *m_networkTask;    // 网络任务（Modbus控制）
    class OperationLogDatabase *m_operationLogDB;  // 运行日志数据库
    DeviceRuntimeTracker *m_runtimeTracker;  // 设备运行时间跟踪器

    // ✅ 2026-01-21 20:15 [音频网络传输] 添加音频网络发送器
    AudioNetworkSender *m_audioNetworkSender;  // 音频网络发送器（UDP 组播 Opus）
    AudioOutputMode m_audioOutputMode;         // 音频输出模式（本地/网络/双输出）

    // ✅ 2026-01-22 20:00 [TCP音频传输] 添加 TCP 模式音频发送器
    AudioNetworkTcpSender *m_audioNetworkTcpSender;  // TCP 模式音频发送器（UDP 发现 + TCP 连接 + WebSocket）

    // ✅ 2026-01-23 00:00 [TTS网络传输] 添加 TTS 语音网络传输
    // ✅ 2026-02-13 [Phase 7.46.7]: 替换为 TTS 引擎管理器
    // SherpaOnnxTTS *m_tts;  // TTS 语音合成器（用于起车预警语音）
    TTSEngineManager *m_ttsEngineManager;  // TTS 引擎管理器（支持多引擎切换）

    // ✅ 2026-03-04 [Phase 7.47.87]: 音频播放队列（防止多个离线语音互相打断）
    QStringList m_audioQueue;              // 音频播放队列
    bool m_isPlayingFromQueue;             // 是否正在播放队列中的音频

    // ❌ 2026-03-04 17:00 [Phase 7.47.90]: 移除延迟播放机制
    // 原因：从 mediaStatusChanged 回调内部调用 play() 导致 GStreamer 管道状态异常
    //       QMediaPlayer 报告 Playing（3.95秒）但 ALSA 无音频输出，设备完全无声
    //       恢复在 setSource() 后直接调用 play()（3月3日之前的工作方式）
    // ❌ 2026-03-04 [Phase 7.47.89]: 延迟 play() 到 BufferedMedia 后执行
    // 原因：play() 在 LoadingMedia 阶段调用会导致 125ms 静音 + 突变卡顿
    // bool m_pendingPlay;                    // 等待 BufferedMedia 后再调用 play()

    // 预警播放相关
    QTimer *m_warningTimer;        // 按时间模式的定时器
    int m_currentPlayCount;        // 当前已播放次数
    bool m_isWarningPlaying;       // 是否正在播放预警
    QString m_currentAudioPath;    // 当前播放的音频路径
    int m_currentBeltNumber;       // ✅ 2026-01-23 00:00 [TTS网络传输] 当前起车预警皮带编号
    bool m_isStopAudioPlaying;     // 是否正在播放停车音频
    bool m_isFaultStop;            // 是否因故障而停止（跳过停车音频）
    QElapsedTimer m_playbackTimer; // ✅ 2026-02-26 [Phase 7.47.8]: 播放时长计时器

    // ❌ 2026-03-25 [Phase 7.48.88.22]: 废弃单一序列状态变量，改用per-belt BeltSequenceState
    // 原因：单一全局状态导致多皮带无法并行执行启停序列
    // QTimer *m_deviceSequenceTimer; // 设备序列延时定时器
    // QStringList m_currentSequence; // 当前执行的设备序列
    // int m_currentSequenceIndex;    // 当前序列执行索引
    // bool m_isSequenceRunning;      // 是否正在执行序列
    // bool m_isStartupSequence;      // true=启动序列, false=停止序列

    // ✅ 2026-03-25 [Phase 7.48.88.22]: 按皮带号独立管理序列状态（支持多皮带并行）
    struct BeltSequenceState {
        int beltNumber;
        QStringList sequence;       // 设备列表
        int currentIndex;           // 当前进度
        bool isRunning;             // 序列是否在执行
        bool isStartup;             // true=启动, false=停止
        QTimer *timer;              // 独立定时器
    };
    QMap<int, BeltSequenceState*> m_beltSequences;  // 按皮带号的活跃序列
    QList<QPair<int, bool>> m_pendingBeltOps;       // 待处理操作队列 (皮带号, true=启动/false=停止)

    // ✅ 2026-03-25 [Phase 7.48.88.21]: 按皮带号跟踪运行状态（支持多皮带并行运行）
    QMap<int, bool> m_beltRunning;

    // 反馈检测相关
    struct FeedbackCheck {
        QString deviceName;
        int feedbackChannel;
        int feedbackDelay;
        QTimer *timer;
        bool isMonitoring;  // 是否处于持续监控状态（启动完成后）
        bool lastFeedbackState;  // 上次反馈状态（用于检测从1→0的变化）
    };
    struct DeviceFeedbackConfig {
        bool useFeedback;
        int feedbackChannel;
        int feedbackDelay;
    };
    QMap<QString, FeedbackCheck> m_feedbackChecks;  // 正在检测的设备反馈
    QMap<QString, DeviceFeedbackConfig> m_deviceFeedbackConfigs;  // 设备反馈配置
    quint16 m_lastFeedbackRegisterValue;            // 上次反馈寄存器值

    // 音频文件路径配置
    QString getAudioPath(int beltNumber, const QString &actionType);

    // 开始预警播放
    void startWarningPlayback(int beltNumber);

    // 获取当前工作模式名称
    QString getWorkModeName() const;

    // 播放一次预警音频
    void playWarningOnce();

    // 执行设备序列的下一步
    // ✅ 2026-03-25 [Phase 7.48.88.22]: 改为按皮带号独立执行
    void executeNextDeviceInSequence(int beltNumber);

    // ✅ 2026-03-25 [Phase 7.48.88.22]: 按皮带号的定时器回调
    void onBeltSequenceTimer(int beltNumber);

    // ✅ 2026-03-25 [Phase 7.48.88.22]: 处理待处理的启停操作队列
    void processPendingBeltOps();

    // ✅ 2026-03-25 [Phase 7.48.88.22]: 读取设备延时配置
    int readDeviceDelay(const QString &deviceName, int beltNumber, bool isStartup);

    // ✅ 2026-03-25 [Phase 7.48.88.22]: 获取或创建per-belt序列状态
    BeltSequenceState* getOrCreateBeltState(int beltNumber);

    // 激活/停用指定设备
    void activateDevice(const QString &deviceName, bool activate);

    // ❌ 2026-03-24 [Phase 7.48.88.5]: 废弃，输出通道由各设备配置面板设置
    // int getDeviceChannel(const QString &deviceName);

    // 反馈检测相关方法
    void startFeedbackCheck(const QString &deviceName, int feedbackChannel, int feedbackDelay);
    void stopFeedbackCheck(const QString &deviceName);
    void onFeedbackTimeout(const QString &deviceName);
    bool checkFeedbackBit(quint16 registerValue, int channel);
    QString getDeviceFailureAudioPath(const QString &deviceName);

    // ✅ 2026-01-23 01:45 [TTS发音优化] 添加数字转中文辅助函数
    // 原因：TTS模型对阿拉伯数字"1"发音不清晰，改用中文数字"一"
    // 用途：将皮带编号（1-10）转换为中文数字（一-十）用于TTS文本生成
    QString numberToChinese(int number) const;

    // ✅ 2026-03-04 [Phase 7.47.87]: 音频队列处理方法
    void playNextInQueue();                // 播放队列中的下一个音频
    void playAudioInternal(const QString &audioPath);  // 内部播放方法（不加入队列）

    // ✅ 2026-02-13 [Phase 7.46.7]: 添加 TTS 引擎注册方法
    /**
     * @brief 注册所有 TTS 引擎
     */
    void registerTTSEngines();
};

#endif // COMMONCONTROL_H
