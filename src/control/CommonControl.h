#ifndef COMMONCONTROL_H
#define COMMONCONTROL_H

#include <QObject>
#include <QMediaPlayer>
#include <QAudioOutput>
// ✅ 2026-03-03 [Phase 7.47.73]: 添加 QSoundEffect，用于替代 QMediaPlayer 本地播放
// 原因：QMediaPlayer 依赖 GStreamer 流式 pipeline，每次 setSource() 重建 pipeline
//        引发 Buffer Underrun，导致语音卡顿。QSoundEffect 预加载 WAV 到内存后
//        通过 QAudioSink 直接写 ALSA，与 aplay 路径相同，无流式重采样卡顿。
#include <QSoundEffect>
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

    // 设置网络任务（用于Modbus设备控制）
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
    void deviceStatusChanged(const QString &deviceName, bool isRunning);  // 设备状态改变

    // ✅ 2026-02-21 22:45: 添加 TTS 初始化进度信号
    // 原因：PaddleSpeech 初始化需要 5-10 分钟，QML 需要显示进度
    void ttsInitializationProgress(const QString &message);  // TTS 初始化进度

    // ✅ 2026-02-28 [Phase 7.47.39]: TTS模型异步切换完成信号
    void ttsModelSwitchCompleted(bool success, int modelIndex);

public slots:
    // 播放指定的音频文件
    void playAudio(const QString &audioPath);

    // 皮带控制函数
    void startBelt(int beltNumber);  // 启动指定编号的皮带（带预警播放）
    void stopBelt(int beltNumber);   // 停止指定编号的皮带（播放停车音频，然后停止设备序列）

    // 停止当前预警播放
    void stopWarningPlayback();

    // 设备序列控制（通过R/S键盘快捷键触发）
    Q_INVOKABLE void startDeviceSequence();  // 按启动顺序启动设备
    Q_INVOKABLE void stopDeviceSequence();   // 按停止顺序停止设备

    // 设置设备反馈参数（从QML调用）
    Q_INVOKABLE void setDeviceFeedbackConfig(const QString &deviceName, bool useFeedback, int feedbackChannel, int feedbackDelay);

    // ✅ 2026-02-13 [Phase 7.45.35, 7.45.36, 7.45.37]: 旧的 TTS 方法已移到上面的 TTS 引擎管理接口区域

private slots:
    void onMediaPlayerError(QMediaPlayer::Error error, const QString &errorString);
    void onPlaybackFinished();
    void onWarningTimerTimeout();  // 按时间模式的定时器超时
    void onDeviceSequenceTimer();  // 设备序列定时器超时
    void onRegisterValueReceived(int registerAddress, quint16 value);  // 接收寄存器值（用于反馈检测）

private:
    QMediaPlayer *m_mediaPlayer;   // 音频播放器（GStreamer 后端，用于网络/复杂场景）
    QAudioOutput *m_audioOutput;   // 音频输出（配套 QMediaPlayer）
    // ✅ 2026-03-03 [Phase 7.47.73]: QSoundEffect 本地播放（优先，低延迟无卡顿）
    // 历史原因：选 QMediaPlayer 是因为容器无 PulseAudio 时 Qt 无法枚举 ALSA 设备
    //   但枚举失败 ≠ 播放失败。QSoundEffect 用 QAudioSink 直接写 ALSA default
    //   与 aplay 同路径，不受枚举限制，且无 GStreamer 流式 pipeline 开销。
    // 策略：本地播放优先用 QSoundEffect；失败（status=Error）时回退 QMediaPlayer
    QSoundEffect *m_soundEffect;       // 低延迟本地播放（QAudioSink → ALSA direct）
    bool m_usingSoundEffect;           // 当前是否正在用 QSoundEffect 播放
    SystemConfig *m_systemConfig;  // 系统配置
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

    // 预警播放相关
    QTimer *m_warningTimer;        // 按时间模式的定时器
    int m_currentPlayCount;        // 当前已播放次数
    bool m_isWarningPlaying;       // 是否正在播放预警
    QString m_currentAudioPath;    // 当前播放的音频路径
    int m_currentBeltNumber;       // ✅ 2026-01-23 00:00 [TTS网络传输] 当前起车预警皮带编号
    bool m_isStopAudioPlaying;     // 是否正在播放停车音频
    bool m_isFaultStop;            // 是否因故障而停止（跳过停车音频）
    QElapsedTimer m_playbackTimer; // ✅ 2026-02-26 [Phase 7.47.8]: 播放时长计时器

    // 设备序列控制相关
    QTimer *m_deviceSequenceTimer; // 设备序列延时定时器
    QStringList m_currentSequence; // 当前执行的设备序列
    int m_currentSequenceIndex;    // 当前序列执行索引
    bool m_isSequenceRunning;      // 是否正在执行序列
    bool m_isStartupSequence;      // true=启动序列, false=停止序列

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
    void executeNextDeviceInSequence();

    // 激活/停用指定设备
    void activateDevice(const QString &deviceName, bool activate);

    // 根据设备名获取通道号（临时实现，后续应从设备数据库读取）
    int getDeviceChannel(const QString &deviceName);

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

    // ✅ 2026-02-13 [Phase 7.46.7]: 添加 TTS 引擎注册方法
    /**
     * @brief 注册所有 TTS 引擎
     */
    void registerTTSEngines();
};

#endif // COMMONCONTROL_H
