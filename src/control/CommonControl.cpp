#include "CommonControl.h"
#include "SystemConfig.h"
#include "OperationLogDatabase.h"
#include "DeviceRuntimeTracker.h"
#include <QDebug>
#include <QCoreApplication>
#include <QDir>
#include <QFile>

// 前向声明NetworkTask，不include头文件避免依赖Qt::SerialBus
class NetworkTask;

CommonControl::CommonControl(QObject *parent)
    : QObject(parent)
    , m_mediaPlayer(new QMediaPlayer(this))
    , m_audioOutput(new QAudioOutput(this))
    , m_systemConfig(nullptr)
    , m_networkTask(nullptr)
    , m_operationLogDB(nullptr)
    , m_runtimeTracker(nullptr)
    , m_warningTimer(new QTimer(this))
    , m_currentPlayCount(0)
    , m_isWarningPlaying(false)
    , m_isStopAudioPlaying(false)
    , m_isFaultStop(false)
    , m_deviceSequenceTimer(new QTimer(this))
    , m_currentSequenceIndex(0)
    , m_isSequenceRunning(false)
    , m_isStartupSequence(true)
    , m_lastFeedbackRegisterValue(0)
{
    qDebug() << "✅ CommonControl: 公共控制模块已创建";

    // 配置音频输出
    m_audioOutput->setVolume(1.0);  // 音量100%
    m_mediaPlayer->setAudioOutput(m_audioOutput);

    // 连接信号
    connect(m_mediaPlayer, &QMediaPlayer::errorOccurred,
            this, &CommonControl::onMediaPlayerError);
    connect(m_mediaPlayer, &QMediaPlayer::playbackStateChanged,
            this, [this](QMediaPlayer::PlaybackState state) {
                if (state == QMediaPlayer::StoppedState) {
                    onPlaybackFinished();
                }
            });

    // 连接预警定时器
    connect(m_warningTimer, &QTimer::timeout,
            this, &CommonControl::onWarningTimerTimeout);

    // 连接设备序列定时器
    m_deviceSequenceTimer->setSingleShot(true);
    connect(m_deviceSequenceTimer, &QTimer::timeout,
            this, &CommonControl::onDeviceSequenceTimer);

    qDebug() << "🔊 CommonControl: 音频播放器已初始化";
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
    // 检查文件是否存在
    if (!QFile::exists(audioPath)) {
        qWarning() << "❌ CommonControl: 音频文件不存在:" << audioPath;
        return;
    }

    qDebug() << "🔊 CommonControl: 播放音频:" << audioPath;

    // 先停止当前播放
    if (m_mediaPlayer->playbackState() != QMediaPlayer::StoppedState) {
        m_mediaPlayer->stop();
    }

    // 检查是否是同一个音频文件
    QUrl currentSource = m_mediaPlayer->source();
    QUrl newSource = QUrl::fromLocalFile(audioPath);

    if (currentSource == newSource) {
        // 同一个文件，只需重置位置并播放
        qDebug() << "🔄 CommonControl: 重用音频源，重置位置";
        m_mediaPlayer->setPosition(0);
    } else {
        // 不同文件，需要重新设置源
        qDebug() << "🆕 CommonControl: 设置新音频源";
        m_mediaPlayer->setSource(newSource);
    }

    m_mediaPlayer->play();
}

void CommonControl::startBelt(int beltNumber)
{
    qDebug() << "🚀 CommonControl: 请求启动" << beltNumber << "号皮带";

    // 记录启动操作到数据库
    if (m_operationLogDB && m_systemConfig) {
        QString workModeName = getWorkModeName();
        m_operationLogDB->logOperation(workModeName, "按键", "启动请求",
                                      QString("%1号皮带").arg(beltNumber), "");
    }

    // 使用预警播放模式
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

    // 记录停止操作到数据库
    if (m_operationLogDB && m_systemConfig) {
        QString workModeName = getWorkModeName();
        m_operationLogDB->logOperation(workModeName, "按键", "停止请求",
                                      QString("%1号皮带").arg(beltNumber), "");
    }

    // 停止当前预警播放（如果正在播放）
    stopWarningPlayback();

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

QString CommonControl::getAudioPath(int beltNumber, const QString &actionType)
{
    // 获取应用程序根目录
    QString appDir = QCoreApplication::applicationDirPath();

    // 构建音频文件路径: AUDIO/<编号>#PD/<文件名>
    QString folderName = QString("%1#PD").arg(beltNumber);

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

    // 按顺序尝试所有可能的文件名
    for (const QString &fileName : possibleNames) {
        QString audioPath = QString("%1/AUDIO/%2/%3").arg(appDir, folderName, fileName);
        if (QFile::exists(audioPath)) {
            return audioPath;
        }
    }

    qDebug() << "⚠️ CommonControl: 在以下位置未找到音频文件:";
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
                // 添加300ms延迟确保媒体播放器准备好
                QTimer::singleShot(300, this, &CommonControl::playWarningOnce);
            } else {
                qDebug() << "⏸️ CommonControl: 定时器已停止，不再播放";
            }
        }
    } else {
        // 普通播放完成
        qDebug() << "✅ CommonControl: 音频播放完成";
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

    // 更新RuntimeTracker：起车预警
    if (m_runtimeTracker) {
        m_runtimeTracker->onStartWarning();
    }

    // 停止之前的播放
    stopWarningPlayback();

    // 获取音频文件路径
    m_currentAudioPath = getAudioPath(beltNumber, "启动");
    if (m_currentAudioPath.isEmpty()) {
        qWarning() << "❌ CommonControl: 未找到" << beltNumber << "号皮带的启动音频";
        return;
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

        // 启动定时器
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
    if (!m_currentAudioPath.isEmpty()) {
        qDebug() << "🔊 CommonControl: 播放预警音频:" << m_currentAudioPath;
        playAudio(m_currentAudioPath);
    }
}

void CommonControl::stopWarningPlayback()
{
    if (m_isWarningPlaying) {
        qDebug() << "⏹️ CommonControl: 停止预警播放";
        m_isWarningPlaying = false;
        m_warningTimer->stop();
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

    m_currentSequence = m_systemConfig->startupSequence();
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

    m_currentSequence = m_systemConfig->stopSequence();
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

    // 立即执行第一个设备
    executeNextDeviceInSequence();
}

void CommonControl::executeNextDeviceInSequence()
{
    if (!m_isSequenceRunning || m_currentSequenceIndex >= m_currentSequence.size()) {
        // 序列执行完成
        m_isSequenceRunning = false;
        qDebug() << "✅ CommonControl: 设备序列执行完成";
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

    // 移动到下一个设备
    m_currentSequenceIndex++;

    // 如果还有下一个设备，使用延时定时器
    if (m_currentSequenceIndex < m_currentSequence.size()) {
        // 默认延时1秒（后续可以从设备配置读取）
        m_deviceSequenceTimer->start(1000);
    } else {
        // 序列执行完成
        m_isSequenceRunning = false;
        qDebug() << "✅ CommonControl: 设备序列执行完成";

        // 更新RuntimeTracker：序列完成后的状态
        if (m_runtimeTracker) {
            if (m_isStartupSequence) {
                // 启动序列完成，进入运行状态
                m_runtimeTracker->onRunning();
            } else {
                // 停止序列完成，先抱闸，然后停止
                m_runtimeTracker->onBrakeEngaging();
                // 延时后更新为停止状态
                QTimer::singleShot(500, this, [this]() {
                    if (m_runtimeTracker) {
                        m_runtimeTracker->onStopped();
                    }
                });
            }
        }
    }
}

void CommonControl::onDeviceSequenceTimer()
{
    // 定时器超时，执行下一个设备
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

// 临时函数：根据设备名获取通道号（后续应从设备数据库读取）
int CommonControl::getDeviceChannel(const QString &deviceName)
{
    // 设备名到通道号的映射（0-15）
    static const QMap<QString, int> deviceChannelMap = {
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
        {"3号喷雾泵", 15}
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

    // 在 AUDIO/<皮带号>#PD 目录下查找音频文件
    for (const QString &fileName : possibleNames) {
        QString audioPath = QString("%1/AUDIO/%2/%3").arg(appDir, folderName, fileName);
        if (QFile::exists(audioPath)) {
            qDebug() << "✅ CommonControl: 找到运行失败音频:" << audioPath;
            return audioPath;
        }
    }

    qDebug() << "⚠️  CommonControl: 在以下位置未找到运行失败音频:";
    qDebug() << "   目录:" << QString("%1/AUDIO/%2/").arg(appDir, folderName);
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
