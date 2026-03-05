#include "MqttProtectionMonitor.h"
#include "../mqtt/DIDataManager.h"
#include "../mqtt/AIDataManager.h"  // ✅ 2026-03-05 [Phase 7.48.5]
#include "CommonControl.h"
#include "DataPathConfig.h"      // ✅ 2026-02-28 [Phase 7.47.43]: 统一音频路径
#include "DeviceConfigManager.h" // ✅ 2026-02-28 [Phase 7.47.49]: 查询use_text_to_speech
#include "AlarmPlaybackService.h" // ✅ 2026-03-04 [Phase 7.47.95]: 按次数/按时长播放
#include <QDebug>
#include <QFile>

// ✅ 2026-02-27 10:30 [Phase 7.47.35]: 实现MQTT开关量保护监控器

MqttProtectionMonitor::MqttProtectionMonitor(DIDataManager *diManager,
                                             CommonControl *commonControl,
                                             QObject *parent)
    : QObject(parent)
    , m_diManager(diManager)
    , m_aiManager(nullptr)  // ✅ 2026-03-05 [Phase 7.48.5]: 由main.cpp通过setAIDataManager注入
    , m_commonControl(commonControl)
    // ✅ 2026-02-27 11:00 [Phase 7.47.35]: 修复编译错误，AudioPathMapper不是QObject，不接受parent参数
    // ⚠️ 2026-02-28 [Phase 7.47.43]: 先用默认构造，构造体内再设置正确路径（见下方）
    // 旧值（错误）：new AudioPathMapper("/app/audio")
    // 原因：Docker挂载的是 /home/{user}/belt-control-data/audio，不是 /app/audio
    //       AudioPathMapper("/app/audio") 会查找不存在的路径，导致音频文件找不到
    , m_audioPathMapper(new AudioPathMapper())
    , m_deviceConfigMgr(nullptr)  // ✅ 2026-02-28 [Phase 7.47.49]: 由main.cpp通过setDeviceConfigManager注入
    , m_alarmPlaybackService(nullptr) // ✅ 2026-03-04 [Phase 7.47.95]: 由main.cpp通过setAlarmPlaybackService注入
    , m_isRunning(false)
{
    // ✅ 2026-02-28 [Phase 7.47.43]: 使用DataPathConfig统一音频目录
    // 与BatchAudioGenerator的outputBaseDir保持一致（都从BELT_CONTROL_USER读取）
    // Docker启动命令注入：-e BELT_CONTROL_USER=linaro
    // 实际路径：/home/linaro/belt-control-data/audio（对应挂载卷）
    QString audioBaseDir = DataPathConfig::getAudioBaseDirectory();
    m_audioPathMapper->setBaseDirectory(audioBaseDir);
    qDebug() << "✅ [MqttProtectionMonitor] MQTT保护监控器已创建";
    qDebug() << "📁 [MqttProtectionMonitor] 音频基础目录:" << audioBaseDir;

    // 初始化默认皮带映射
    m_beltMapping[0] = 1;  // DI模块0 → 1号皮带
    m_beltMapping[1] = 2;  // DI模块1 → 2号皮带
    // ✅ 2026-03-05 [Phase 7.48.5]: 初始化AI模块皮带映射
    m_aiBeltMapping[0] = 1;  // AI模块0 → 1号皮带
    m_aiBeltMapping[1] = 2;  // AI模块1 → 2号皮带

    // 连接DIDataManager的bitChanged信号
    if (m_diManager) {
        connect(m_diManager, &DIDataManager::bitChanged,
                this, &MqttProtectionMonitor::onBitChanged);
        qDebug() << "🔗 [MqttProtectionMonitor] 已连接DIDataManager的bitChanged信号";
    } else {
        qWarning() << "⚠️ [MqttProtectionMonitor] DIDataManager为空，无法连接信号";
    }
}

MqttProtectionMonitor::~MqttProtectionMonitor()
{
    stop();
    // ✅ 2026-02-27 11:30 [Phase 7.47.36]: 释放AudioPathMapper内存（非QObject，不会自动释放）
    delete m_audioPathMapper;
    m_audioPathMapper = nullptr;
    qDebug() << "✅ [MqttProtectionMonitor] MQTT保护监控器已销毁";
}

void MqttProtectionMonitor::start()
{
    if (m_isRunning) {
        qDebug() << "⚠️ [MqttProtectionMonitor] 监控器已经在运行中";
        return;
    }

    if (!m_diManager) {
        qWarning() << "❌ [MqttProtectionMonitor] DIDataManager未设置，无法启动";
        return;
    }

    if (!m_commonControl) {
        qWarning() << "❌ [MqttProtectionMonitor] CommonControl未设置，无法启动";
        return;
    }

    qDebug() << "🚀 [MqttProtectionMonitor] 启动MQTT保护监控";
    qDebug() << "📋 [MqttProtectionMonitor] 皮带映射:";
    for (auto it = m_beltMapping.constBegin(); it != m_beltMapping.constEnd(); ++it) {
        qDebug() << "   模块" << it.key() << "→" << it.value() << "号皮带";
    }

    m_isRunning = true;
}

void MqttProtectionMonitor::stop()
{
    if (!m_isRunning) {
        return;
    }

    qDebug() << "🛑 [MqttProtectionMonitor] 停止MQTT保护监控";
    m_isRunning = false;
}

void MqttProtectionMonitor::setBeltMapping(int moduleIndex, int beltNumber)
{
    if (moduleIndex < 0 || moduleIndex > 1) {
        qWarning() << "⚠️ [MqttProtectionMonitor] 无效的模块索引:" << moduleIndex << "（应为0或1）";
        return;
    }

    if (beltNumber < 1 || beltNumber > 8) {
        qWarning() << "⚠️ [MqttProtectionMonitor] 无效的皮带编号:" << beltNumber << "（应为1-8）";
        return;
    }

    m_beltMapping[moduleIndex] = beltNumber;
    qDebug() << "📝 [MqttProtectionMonitor] 设置皮带映射: 模块" << moduleIndex << "→" << beltNumber << "号皮带";
}

int MqttProtectionMonitor::getBeltMapping(int moduleIndex) const
{
    return m_beltMapping.value(moduleIndex, 1);  // 默认返回1号皮带
}

// ✅ 2026-03-05 [Phase 7.48.10]: 电机启动/停止通知（用于速度保护延时启动）
void MqttProtectionMonitor::notifyMotorStarted(int beltNumber)
{
    m_motorRunning[beltNumber] = true;
    m_motorStartTimers[beltNumber].start();
    // 重置低速打滑计时器
    m_slipTimerActive[beltNumber] = false;
    qDebug() << "🏭 [MqttProtectionMonitor] 电机启动通知 - 皮带" << beltNumber
             << "速度保护延时计时开始";
}

void MqttProtectionMonitor::notifyMotorStopped(int beltNumber)
{
    m_motorRunning[beltNumber] = false;
    m_slipTimerActive[beltNumber] = false;
    qDebug() << "🛑 [MqttProtectionMonitor] 电机停止通知 - 皮带" << beltNumber
             << "速度保护状态已重置";
}

void MqttProtectionMonitor::onBitChanged(int moduleIndex, int bitIndex, bool value)
{
    if (!m_isRunning) {
        return;
    }

    // ✅ 只处理位从0→1的变化（保护触发）
    if (!value) {
        // 位从1→0，保护恢复，暂不处理
        return;
    }

    qDebug() << "🚨 [MqttProtectionMonitor] 检测到DI位变化:";
    qDebug() << "   模块索引:" << moduleIndex;
    qDebug() << "   位索引:" << bitIndex;
    qDebug() << "   位值:" << (value ? "1" : "0");

    // 获取对应的皮带编号
    int beltNumber = getBeltMapping(moduleIndex);
    qDebug() << "   对应皮带:" << beltNumber << "号";

    // 获取保护名称（TTS文件名格式，如"沿线急停"）
    QString protectionName = m_audioPathMapper->getProtectionName(bitIndex);
    qDebug() << "   保护名称:" << protectionName;

    // ✅ 2026-02-28 [Phase 7.47.49]: 根据 use_text_to_speech 选择音频路径
    // ✅ 2026-02-28 [Phase 7.47.52]: 默认改为false（默认音频），旧值true导致DB无记录时也走TTS
    // 旧：bool useTTS = true;
    QString audioPath;
    bool useTTS = false;
    // ✅ 2026-03-04 [Phase 7.47.95]: 读取播放方式参数
    QString playMode = "count";  // 默认按次数
    int playCount = 3;           // 默认3次
    double playDuration = 5.0;   // 默认5秒
    QString ttsText;

    if (m_deviceConfigMgr) {
        // 查询DB获取该保护的音频来源设置
        QString shortName = m_audioPathMapper->getShortProtectionName(bitIndex);
        QVariantMap protection = m_deviceConfigMgr->loadDigitalProtection(beltNumber, shortName);
        if (!protection.isEmpty()) {
            // ✅ 2026-03-01 [Phase 7.47.56]: 默认回退值改为0（默认音频），旧值1导致字段缺失时也走TTS
            // 旧：protection.value("use_text_to_speech", 1).toInt() == 1
            useTTS = (protection.value("use_text_to_speech", 0).toInt() == 1);
            // ✅ 2026-03-04 [Phase 7.47.95]: 读取播放方式、次数、时长
            playMode = protection.value("play_mode", "count").toString();
            playCount = protection.value("play_count", 3).toInt();
            playDuration = protection.value("play_duration", 5.0).toDouble();
            ttsText = protection.value("tts_text", "").toString();
            qDebug() << "📋 [MqttProtectionMonitor] 保护" << shortName
                     << "音频来源:" << (useTTS ? "TTS合成" : "默认(1#PD MP3)")
                     << "播放方式:" << playMode
                     << "次数:" << playCount << "时长:" << playDuration;
        }
    }

    if (useTTS) {
        // TTS合成路径：{baseDir}/paddlespeech-{model}-spk{id}/{belt}#PD/{name}.wav
        audioPath = m_audioPathMapper->getAudioPath(beltNumber, protectionName);
    } else {
        // 默认音频路径：{baseDir}/{belt}#PD/{filename}.mp3
        audioPath = m_audioPathMapper->getDefaultAudioPath(beltNumber, bitIndex);
    }
    qDebug() << "   音频路径:" << audioPath;

    // 检查音频文件是否存在
    if (!QFile::exists(audioPath)) {
        qWarning() << "⚠️ [MqttProtectionMonitor] 音频文件不存在:" << audioPath;
        qWarning() << "   将尝试播放，如果文件不存在，播放器会报错";
    }

    // 发射保护触发信号
    emit protectionTriggered(moduleIndex, bitIndex, beltNumber, protectionName, audioPath);

    // 播放音频
    // ✅ 2026-03-04 [Phase 7.47.95]: 改用 AlarmPlaybackService 支持按次数/按时长播放
    // 旧代码（Phase 7.47.49）：m_commonControl->playAudio(audioPath) — 只播放一遍
    if (m_alarmPlaybackService) {
        qDebug() << "🔊 [MqttProtectionMonitor] 通过AlarmPlaybackService触发播放:"
                 << audioPath << "模式:" << playMode;
        m_alarmPlaybackService->playAlarm(protectionName, ttsText, audioPath,
                                          useTTS, playMode, playCount, playDuration);
    } else if (m_commonControl) {
        // 回退：如果AlarmPlaybackService未注入，使用旧的单次播放
        qDebug() << "🔊 [MqttProtectionMonitor] 回退到CommonControl单次播放:" << audioPath;
        m_commonControl->playAudio(audioPath);
    } else {
        qWarning() << "⚠️ [MqttProtectionMonitor] AlarmPlaybackService和CommonControl均为空，无法播放音频";
    }
}

// ✅ 2026-03-05 [Phase 7.48.5]: AI模块皮带映射设置
void MqttProtectionMonitor::setAIBeltMapping(int moduleIndex, int beltNumber)
{
    if (moduleIndex < 0 || moduleIndex > 1) {
        qWarning() << "⚠️ [MqttProtectionMonitor] 无效的AI模块索引:" << moduleIndex << "（应为0或1）";
        return;
    }
    if (beltNumber < 1 || beltNumber > 8) {
        qWarning() << "⚠️ [MqttProtectionMonitor] 无效的皮带编号:" << beltNumber << "（应为1-8）";
        return;
    }
    m_aiBeltMapping[moduleIndex] = beltNumber;
    qDebug() << "✅ [MqttProtectionMonitor] 设置AI模块" << moduleIndex << "→" << beltNumber << "号皮带";
}

// ✅ 2026-03-05 [Phase 7.48.5]: AI通道变化处理（模拟量保护监控）
void MqttProtectionMonitor::onAIChannelChanged(int moduleIndex, int channelIndex, const ChannelData &data)
{
    if (!m_isRunning) {
        return;  // 监控未启动，忽略
    }

    // 获取皮带编号
    int beltNumber = m_aiBeltMapping.value(moduleIndex, 1);

    qDebug() << "📊 [MqttProtectionMonitor] AI通道变化 - 模块:" << moduleIndex
             << "通道:" << channelIndex << "AD值:" << data.adValue
             << "→ 皮带" << beltNumber;

    // 查询该皮带的所有模拟量保护配置
    if (!m_deviceConfigMgr) {
        qWarning() << "⚠️ [MqttProtectionMonitor] DeviceConfigManager未设置，无法查询模拟量保护";
        return;
    }

    QVariantList protections = m_deviceConfigMgr->loadAllAnalogProtections(beltNumber);
    if (protections.isEmpty()) {
        // 首次运行时可能没有保护项，不输出警告
        return;
    }

    // 遍历所有保护项，检查是否有匹配当前通道的
    for (const QVariant &p : protections) {
        QVariantMap prot = p.toMap();
        int regAddr = prot.value("register_address").toInt();

        // 通道匹配逻辑：register_address 5-26 对应通道 0-21
        // 简化映射：regAddr - 5 = channelIndex
        if (regAddr - 5 != channelIndex) {
            continue;  // 不是当前通道的保护项
        }

        QString protName = prot.value("protection_name").toString();
        double upperLimit = prot.value("upper_limit").toDouble();
        double lowerLimit = prot.value("lower_limit").toDouble();
        double rangeValue = prot.value("range_value").toDouble();

        // AD值转工程量（简化公式：线性映射）
        // 工程量 = 下限 + (AD值 / 65535) × 范围值
        // ✅ 2026-03-05 [Phase 7.48.5]: 从 ChannelData 获取 AD 值
        double engineeringValue = lowerLimit + (data.adValue / 65535.0) * rangeValue;

        qDebug() << "   保护:" << protName << "工程量:" << engineeringValue
                 << "阈值:[" << lowerLimit << "," << upperLimit << "]";

        // 检查是否超限
        // ✅ 2026-03-05 [Phase 7.48.9]: 记录超限方向，用于方向性音频选择（速度/张力/电压）
        bool exceeded = false;
        AudioPathMapper::LimitDirection limitDirection = AudioPathMapper::UpperLimit;

        // ✅ 2026-03-05 [Phase 7.48.10]: 速度保护特殊处理（延时启动 + 额定百分比检测模式）
        bool speedHandled = false;
        if (protName == "速度") {
            // 1. 延时启动检查：电机启动后延时X秒才开始检测
            double startDelay = prot.value("speed_start_delay", 0.0).toDouble();
            if (startDelay > 0 && m_motorRunning.value(beltNumber, false)) {
                double elapsed = m_motorStartTimers[beltNumber].elapsed() / 1000.0;
                if (elapsed < startDelay) {
                    qDebug() << "   ⏳ 速度保护延时中:" << elapsed << "/" << startDelay << "秒";
                    continue;  // 延时未到，跳过检测
                }
            }

            // 2. 检测模式分支
            QString detectMode = prot.value("speed_detect_mode", "limit").toString();
            if (detectMode == "percent") {
                // 模式B：额定速度百分比检测
                double ratedSpeed = prot.value("rated_speed", 0.0).toDouble();
                double slipDelay = prot.value("slip_delay", 10.0).toDouble();
                speedHandled = true;

                if (ratedSpeed <= 0) {
                    qWarning() << "⚠️ [MqttProtectionMonitor] 速度保护额定速度未设置，跳过百分比检测";
                    continue;
                }

                double ratio = engineeringValue / ratedSpeed;
                qDebug() << "   速度百分比检测: 工程量=" << engineeringValue
                         << "额定=" << ratedSpeed << "比值=" << (ratio * 100) << "%";

                if (ratio > 1.1) {
                    // > 110% 额定速度 → 立即报速度超速
                    qWarning() << "⚠️ [MqttProtectionMonitor] 速度超速（>110%额定）:" << engineeringValue
                               << ">" << (ratedSpeed * 1.1);
                    exceeded = true;
                    limitDirection = AudioPathMapper::UpperLimit;
                } else if (ratio >= 0.7) {
                    // 70%~110% → 正常，重置打滑计时器
                    if (m_slipTimerActive.value(beltNumber, false)) {
                        m_slipTimerActive[beltNumber] = false;
                        qDebug() << "   速度恢复正常区间，重置打滑计时器";
                    }
                } else if (ratio >= 0.5) {
                    // 50%~70% → 启动/检查打滑计时器
                    if (!m_slipTimerActive.value(beltNumber, false)) {
                        m_slipTimers[beltNumber].start();
                        m_slipTimerActive[beltNumber] = true;
                        qDebug() << "   进入低速区间(50%~70%)，启动打滑计时器，延时:" << slipDelay << "秒";
                    } else {
                        double slipElapsed = m_slipTimers[beltNumber].elapsed() / 1000.0;
                        if (slipElapsed >= slipDelay) {
                            // 持续超过延时 → 报低速打滑
                            qWarning() << "⚠️ [MqttProtectionMonitor] 低速打滑（50%~70%持续" << slipElapsed << "秒）";
                            exceeded = true;
                            limitDirection = AudioPathMapper::LowerLimit;
                        } else {
                            qDebug() << "   低速区间计时中:" << slipElapsed << "/" << slipDelay << "秒";
                        }
                    }
                } else {
                    // < 50% 额定速度 → 立即报低速打滑
                    qWarning() << "⚠️ [MqttProtectionMonitor] 低速打滑（<50%额定）:" << engineeringValue
                               << "<" << (ratedSpeed * 0.5);
                    exceeded = true;
                    limitDirection = AudioPathMapper::LowerLimit;
                }
            }
            // else: detectMode == "limit"，走下面的通用上下限逻辑
        }

        // 通用上下限检测（非速度保护，或速度保护的limit模式）
        if (!speedHandled) {
            if (engineeringValue > upperLimit) {
                qWarning() << "⚠️ [MqttProtectionMonitor] 模拟量保护触发（超上限）:" << protName
                           << "工程量:" << engineeringValue << ">" << upperLimit;
                exceeded = true;
                limitDirection = AudioPathMapper::UpperLimit;
            } else if (engineeringValue < lowerLimit) {
                qWarning() << "⚠️ [MqttProtectionMonitor] 模拟量保护触发（低于下限）:" << protName
                           << "工程量:" << engineeringValue << "<" << lowerLimit;
                exceeded = true;
                limitDirection = AudioPathMapper::LowerLimit;
            }
        }

        if (!exceeded) {
            continue;  // 未超限，继续检查下一个保护项
        }

        // 超限，触发报警
        // 读取播放配置
        bool useTTS = (prot.value("use_text_to_speech", 0).toInt() == 1);
        QString playMode = prot.value("play_mode", "count").toString();
        int playCount = prot.value("play_count", 3).toInt();
        double playDuration = prot.value("play_duration", 5.0).toDouble();
        QString ttsText = prot.value("tts_text", protName + "保护报警").toString();

        // 生成音频路径
        // ✅ 2026-03-05 [Phase 7.48.9]: 传递超限方向，速度/张力/电压根据方向播放不同音频
        QString audioPath;
        if (useTTS) {
            // TTS合成路径（带方向）
            audioPath = m_audioPathMapper->getAnalogAudioPath(beltNumber, protName, limitDirection);
        } else {
            // 默认音频路径（带方向）
            audioPath = m_audioPathMapper->getAnalogAudioPath(beltNumber, protName, limitDirection);
        }

        qDebug() << "🔊 [MqttProtectionMonitor] 模拟量保护触发播放:" << audioPath
                 << "模式:" << playMode << "次数:" << playCount << "时长:" << playDuration;

        // 检查音频文件是否存在
        if (!QFile::exists(audioPath)) {
            qWarning() << "⚠️ [MqttProtectionMonitor] 模拟量音频文件不存在:" << audioPath;
        }

        // 触发播放
        if (m_alarmPlaybackService) {
            m_alarmPlaybackService->playAlarm(protName, ttsText, audioPath,
                                              useTTS, playMode, playCount, playDuration);
        } else if (m_commonControl) {
            qDebug() << "🔊 [MqttProtectionMonitor] 回退到CommonControl单次播放:" << audioPath;
            m_commonControl->playAudio(audioPath);
        } else {
            qWarning() << "⚠️ [MqttProtectionMonitor] 无法播放模拟量保护音频";
        }

        // 注意：这里不 break，允许一个通道触发多个保护项（如果有的话）
    }
}
