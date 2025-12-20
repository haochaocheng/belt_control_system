#ifndef COMMONCONTROL_H
#define COMMONCONTROL_H

#include <QObject>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QKeyEvent>
#include <QTimer>

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

signals:
    void beltStartRequested(int beltNumber);  // 皮带启动请求
    void beltStopRequested(int beltNumber);   // 皮带停止请求
    void warningPlaybackFinished();           // 预警播放完成
    void deviceStatusChanged(const QString &deviceName, bool isRunning);  // 设备状态改变

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

private slots:
    void onMediaPlayerError(QMediaPlayer::Error error, const QString &errorString);
    void onPlaybackFinished();
    void onWarningTimerTimeout();  // 按时间模式的定时器超时
    void onDeviceSequenceTimer();  // 设备序列定时器超时
    void onRegisterValueReceived(int registerAddress, quint16 value);  // 接收寄存器值（用于反馈检测）

private:
    QMediaPlayer *m_mediaPlayer;   // 音频播放器
    QAudioOutput *m_audioOutput;   // 音频输出
    SystemConfig *m_systemConfig;  // 系统配置
    NetworkTask *m_networkTask;    // 网络任务（Modbus控制）
    class OperationLogDatabase *m_operationLogDB;  // 运行日志数据库
    DeviceRuntimeTracker *m_runtimeTracker;  // 设备运行时间跟踪器

    // 预警播放相关
    QTimer *m_warningTimer;        // 按时间模式的定时器
    int m_currentPlayCount;        // 当前已播放次数
    bool m_isWarningPlaying;       // 是否正在播放预警
    QString m_currentAudioPath;    // 当前播放的音频路径
    bool m_isStopAudioPlaying;     // 是否正在播放停车音频
    bool m_isFaultStop;            // 是否因故障而停止（跳过停车音频）

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
};

#endif // COMMONCONTROL_H
