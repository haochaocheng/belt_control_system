#include "MqttProtectionMonitor.h"
#include "../mqtt/DIDataManager.h"
#include "../mqtt/AIDataManager.h"  // ✅ 2026-03-05 [Phase 7.48.5]
#include "../mqtt/MQTTController.h" // ✅ 2026-03-09 [Phase 7.48.26]: 洒水控制
#include "../mqtt/CSDataManager.h"  // ✅ 2026-03-18 [Phase 7.48.56]: 沿线点位保护
#include "CommonControl.h"
#include "DataPathConfig.h"      // ✅ 2026-02-28 [Phase 7.47.43]: 统一音频路径
#include "DeviceConfigManager.h" // ✅ 2026-02-28 [Phase 7.47.49]: 查询use_text_to_speech
#include "AlarmPlaybackService.h" // ✅ 2026-03-04 [Phase 7.47.95]: 按次数/按时长播放
#include <QDebug>
#include <QFile>
#include <QJsonDocument>  // ✅ 2026-03-09 [Phase 7.48.26]: JSON命令格式
#include <QJsonObject>    // ✅ 2026-03-09 [Phase 7.48.26]
#include <QDateTime>

// ✅ 2026-02-27 10:30 [Phase 7.47.35]: 实现MQTT开关量保护监控器

MqttProtectionMonitor::MqttProtectionMonitor(DIDataManager *diManager,
                                             CommonControl *commonControl,
                                             QObject *parent)
    : QObject(parent)
    , m_diManager(diManager)
    , m_aiManager(nullptr)  // ✅ 2026-03-05 [Phase 7.48.5]: 由main.cpp通过setAIDataManager注入
    , m_csDataManager(nullptr)  // ✅ 2026-03-18 [Phase 7.48.56]: 由main.cpp通过setCSDataManager注入
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
    , m_mqttController(nullptr)  // ✅ 2026-03-09 [Phase 7.48.26]: 由main.cpp通过setMQTTController注入
    // ✅ 2026-03-09 [Phase 7.48.28]: m_sprinklerActive 改为 QMap<int,bool>，无需初始化（默认空map）
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

    // ✅ 2026-03-09 [Phase 7.48.23]: 清理报警状态，下次启动时重新检测
    m_protectionAlarmActive.clear();
    // ✅ 2026-03-18 [Phase 7.48.56]: 清理CS保护报警状态
    m_csProtectionAlarmActive.clear();
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
    // ✅ 2026-03-09 [Phase 7.48.26]: 位从1→0时检查洒水恢复
    if (!value) {
        // 位从1→0，保护恢复
        int beltNumber = getBeltMapping(moduleIndex);
        QString protectionName = m_audioPathMapper->getShortProtectionName(bitIndex);
        checkSprinklerActivation(beltNumber, protectionName, false);
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

    // ✅ 2026-03-09 [Phase 7.48.26]: DI保护触发时检查洒水
    {
        QString shortName = m_audioPathMapper->getShortProtectionName(bitIndex);
        checkSprinklerActivation(beltNumber, shortName, true);
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

    // ✅ 2026-03-07 [Phase 7.48.19]: 修复moduleIndex偏移量不一致问题
    // AIDataManager::channelChanged信号使用 dataIndex+2 (2=模拟量模块1, 3=模拟量模块2)
    // 本地AI索引应为 0=模拟量模块1, 1=模拟量模块2
    // 旧代码直接使用 moduleIndex（值为2或3），导致模块匹配全部失败
    int aiLocalIndex = moduleIndex - 2;
    if (aiLocalIndex < 0 || aiLocalIndex > 1) {
        qWarning() << "⚠️ [MqttProtectionMonitor] 无效的AI模块索引:" << moduleIndex << "→ 本地:" << aiLocalIndex;
        return;
    }

    // 获取皮带编号（使用本地索引查询映射）
    // 旧代码：m_aiBeltMapping.value(moduleIndex, 1)，moduleIndex=2查不到映射
    int beltNumber = m_aiBeltMapping.value(aiLocalIndex, 1);

    // ✅ 2026-03-06 [Phase 7.48.14]: 临时屏蔽AI通道变化日志（日志量过大）
    // qDebug() << "📊 [MqttProtectionMonitor] AI通道变化 - 模块:" << moduleIndex
    //          << "通道:" << channelIndex << "AD值:" << data.adValue
    //          << "→ 皮带" << beltNumber;

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
        QString moduleType = prot.value("module_type").toString();

        // ✅ 2026-03-06 [Phase 7.48.12]: 通道匹配逻辑重构
        // ✅ 2026-03-07 [Phase 7.48.19]: 修复模块匹配 — 使用 aiLocalIndex 而非 moduleIndex
        // 旧代码：(moduleIndex == 0) ? "模拟量模块1" : "模拟量模块2"  ← moduleIndex=2时永远返回"模拟量模块2"
        // 新代码：aiLocalIndex 0=模拟量模块1, 1=模拟量模块2
        if (regAddr < 0) {
            continue;  // 未分配的保护项（风速等），跳过
        }
        // ✅ 2026-03-09 [Phase 7.48.27]: 跳过禁用的保护项
        int enabledFlag = prot.value("enabled", 1).toInt();
        if (enabledFlag != 1) {
            continue;  // 保护已禁用，跳过
        }
        // 判断模块是否匹配
        QString expectedModule = (aiLocalIndex == 0) ? "模拟量模块1" : "模拟量模块2";
        if (moduleType != expectedModule) {
            continue;  // 模块不匹配
        }
        // 判断通道号是否匹配
        if (regAddr != channelIndex) {
            continue;  // 通道号不匹配
        }

        QString protName = prot.value("protection_name").toString();
        double upperLimit = prot.value("upper_limit").toDouble();
        double lowerLimit = prot.value("lower_limit").toDouble();
        double rangeValue = prot.value("range_value").toDouble();

        // AD值转工程量（简化公式：线性映射）
        // 工程量 = 下限 + (AD值 / 65535) × 范围值
        // ✅ 2026-03-05 [Phase 7.48.5]: 从 ChannelData 获取 AD 值
        double engineeringValue = lowerLimit + (data.adValue / 65535.0) * rangeValue;

        // ✅ 2026-03-06 [Phase 7.48.14]: 临时屏蔽保护检测日志（日志量过大）
        // qDebug() << "   保护:" << protName << "工程量:" << engineeringValue
        //          << "阈值:[" << lowerLimit << "," << upperLimit << "]";

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
            // ✅ 2026-03-07 [Phase 7.48.19]: 修复上下限比较运算符
            // 旧代码：engineeringValue > upperLimit（严格大于）
            // 问题：当 upper_limit = lower_limit + range_value 时（13项保护），
            //       工程量最大值 = 上限值，严格大于永远不成立，报警永远无法触发
            // 修复：改为 >= （大于等于），同时下限改为 <=（仅 lowerLimit > 0 时检测）
            if (engineeringValue >= upperLimit) {
                // ✅ 2026-03-09 [Phase 7.48.28]: 移除此处的 qWarning，改到边沿触发内部
                // 原因：每次MQTT数据到来且超限时都打印，导致日志重复刷屏
                // qWarning() << "⚠️ [MqttProtectionMonitor] 模拟量保护触发（超上限）:" << protName
                //            << "工程量:" << engineeringValue << ">=" << upperLimit;
                exceeded = true;
                limitDirection = AudioPathMapper::UpperLimit;
            } else if (lowerLimit > 0 && engineeringValue <= lowerLimit) {
                // 下限检测：仅 lowerLimit > 0 时检测（lowerLimit=0 表示无下限报警）
                // ✅ 2026-03-09 [Phase 7.48.28]: 同上，移除重复日志
                // qWarning() << "⚠️ [MqttProtectionMonitor] 模拟量保护触发（低于下限）:" << protName
                //            << "工程量:" << engineeringValue << "<=" << lowerLimit;
                exceeded = true;
                limitDirection = AudioPathMapper::LowerLimit;
            }
        }

        // ✅ 2026-03-09 [Phase 7.48.23]: 边沿触发 — 只在状态转换时触发报警
        // 解决问题：持续超限时反复调用playAlarm()，多保护互相替代导致音频无限循环
        // 原理：只在"正常→超限"的边沿触发一次报警，"超限→正常"时清除状态
        QString alarmKey = QString("%1:%2").arg(beltNumber).arg(protName);

        if (!exceeded) {
            // 值在正常范围内
            if (m_protectionAlarmActive.value(alarmKey, false)) {
                // 状态转换：超限 → 正常（报警恢复）
                m_protectionAlarmActive[alarmKey] = false;
                qDebug() << "✅ [MqttProtectionMonitor] 模拟量保护恢复:" << protName
                         << "皮带" << beltNumber << "工程量:" << engineeringValue;
                // ✅ 2026-03-09 [Phase 7.48.24]: 发射恢复信号，记录到报警历史数据库
                emit analogProtectionRestored(beltNumber, protName, engineeringValue);
                // ✅ 2026-03-09 [Phase 7.48.26]: 检查洒水恢复
                checkSprinklerActivation(beltNumber, protName, false);
            }
            continue;  // 未超限，继续检查下一个保护项
        }

        // 值超限 — 检查是否是新触发（边沿检测）
        if (m_protectionAlarmActive.value(alarmKey, false)) {
            // 持续超限，已触发过报警，不重复播放
            continue;
        }

        // 首次超限（正常→超限转换），标记状态并触发报警
        m_protectionAlarmActive[alarmKey] = true;
        // ✅ 2026-03-09 [Phase 7.48.28]: 超限日志移到此处，只在首次触发时打印一次
        // 原因：之前在上下限检测处打印，每次MQTT数据到来都重复输出
        if (limitDirection == AudioPathMapper::UpperLimit) {
            qWarning() << "⚠️ [MqttProtectionMonitor] 模拟量保护触发（超上限）:" << protName
                       << "工程量:" << engineeringValue << ">=" << upperLimit;
        } else {
            qWarning() << "⚠️ [MqttProtectionMonitor] 模拟量保护触发（低于下限）:" << protName
                       << "工程量:" << engineeringValue << "<=" << lowerLimit;
        }
        qDebug() << "🔔 [MqttProtectionMonitor] 模拟量保护首次触发:" << protName
                 << "皮带" << beltNumber;

        // ✅ 2026-03-09 [Phase 7.48.24]: 发射触发信号，记录到报警历史数据库
        QString limitType = (limitDirection == AudioPathMapper::UpperLimit) ? "超上限" : "低于下限";
        emit analogProtectionTriggered(beltNumber, protName, engineeringValue, limitType);

        // ✅ 2026-03-09 [Phase 7.48.26]: 检查洒水触发
        checkSprinklerActivation(beltNumber, protName, true);

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

// ✅ 2026-03-09 [Phase 7.48.26]: 洒水控制逻辑
// ✅ 2026-03-09 [Phase 7.48.28]: 改为多洒水支持（8个独立洒水装置）
void MqttProtectionMonitor::checkSprinklerActivation(int beltNumber, const QString &protectionName, bool exceeded)
{
    if (!m_deviceConfigMgr) {
        return;
    }

    // 查询该保护项的 sprinkler_enabled 和 sprinkler_index 字段
    // 先查模拟量保护
    QVariantMap aiProt = m_deviceConfigMgr->loadAnalogProtection(beltNumber, protectionName);
    int sprinklerEnabled = 0;
    int sprinklerIndex = 0;
    if (!aiProt.isEmpty()) {
        sprinklerEnabled = aiProt.value("sprinkler_enabled", 0).toInt();
        sprinklerIndex = aiProt.value("sprinkler_index", 0).toInt();
    } else {
        // 再查开关量保护
        QVariantMap diProt = m_deviceConfigMgr->loadDigitalProtection(beltNumber, protectionName);
        if (!diProt.isEmpty()) {
            sprinklerEnabled = diProt.value("sprinkler_enabled", 0).toInt();
            sprinklerIndex = diProt.value("sprinkler_index", 0).toInt();
        }
    }

    if (sprinklerEnabled != 1) {
        return;  // 该保护未启用洒水，跳过
    }

    // ✅ Phase 7.48.28: sprinkler_index 必须在 1-8 范围内
    if (sprinklerIndex < 1 || sprinklerIndex > 8) {
        // 向后兼容：如果 sprinkler_enabled=1 但 sprinkler_index=0，默认连接洒水1
        if (sprinklerIndex == 0) {
            sprinklerIndex = 1;
        } else {
            qWarning() << "⚠️ [MqttProtectionMonitor] 无效的洒水索引:" << sprinklerIndex
                       << "保护:" << protectionName << "皮带:" << beltNumber;
            return;
        }
    }

    QString triggerKey = QString("%1:%2").arg(beltNumber).arg(protectionName);

    if (exceeded) {
        // 保护触发 → 添加到该洒水的触发源
        if (!m_sprinklerTriggerSources[sprinklerIndex].value(triggerKey, false)) {
            m_sprinklerTriggerSources[sprinklerIndex][triggerKey] = true;
            qDebug() << "🚿 [MqttProtectionMonitor] 洒水" << sprinklerIndex << "触发源添加:" << triggerKey
                     << "当前触发源数:" << m_sprinklerTriggerSources[sprinklerIndex].count();

            // 如果该洒水未激活，立即启动
            if (!m_sprinklerActive.value(sprinklerIndex, false)) {
                publishSprinklerCommand(sprinklerIndex, true);
            }
        }
    } else {
        // 保护恢复 → 从该洒水的触发源移除
        if (m_sprinklerTriggerSources[sprinklerIndex].value(triggerKey, false)) {
            m_sprinklerTriggerSources[sprinklerIndex].remove(triggerKey);
            qDebug() << "🚿 [MqttProtectionMonitor] 洒水" << sprinklerIndex << "触发源移除:" << triggerKey
                     << "剩余触发源数:" << m_sprinklerTriggerSources[sprinklerIndex].count();

            // 检查该洒水是否所有触发源都已恢复
            bool anyActive = false;
            for (auto it = m_sprinklerTriggerSources[sprinklerIndex].begin();
                 it != m_sprinklerTriggerSources[sprinklerIndex].end(); ++it) {
                if (it.value()) {
                    anyActive = true;
                    break;
                }
            }

            if (!anyActive && m_sprinklerActive.value(sprinklerIndex, false)) {
                // 该洒水所有触发源已恢复，停止该洒水
                publishSprinklerCommand(sprinklerIndex, false);
            }
        }
    }
}

// ✅ 2026-03-09 [Phase 7.48.28]: 改为多洒水版本，每个洒水装置独立配置
void MqttProtectionMonitor::publishSprinklerCommand(int sprinklerIndex, bool activate)
{
    if (!m_mqttController) {
        qWarning() << "⚠️ [MqttProtectionMonitor] MQTTController未设置，无法发布洒水命令";
        return;
    }

    if (!m_deviceConfigMgr) {
        qWarning() << "⚠️ [MqttProtectionMonitor] DeviceConfigManager未设置，无法读取洒水配置";
        return;
    }

    // ✅ Phase 7.48.28: 读取该洒水装置的独立配置（1-8）
    QVariantMap config = m_deviceConfigMgr->loadSprinklerConfig(sprinklerIndex);
    if (config.value("enabled", 1).toInt() != 1) {
        qDebug() << "⏭️ [MqttProtectionMonitor] 洒水" << sprinklerIndex << "已禁用，跳过";
        return;
    }

    QString topic = config.value("mqtt_topic", "belt_control/relay/module1/control").toString();
    int channel = config.value("channel", sprinklerIndex - 1).toInt();  // 默认通道 = 洒水索引-1

    // 构建JSON命令
    QJsonObject cmd;
    cmd["cmd"] = "write";
    cmd["channel"] = channel;
    cmd["value"] = activate ? 1 : 0;
    cmd["timestamp"] = QDateTime::currentSecsSinceEpoch();

    QString message = QJsonDocument(cmd).toJson(QJsonDocument::Compact);

    if (m_mqttController->publish(topic, message, 1, false)) {
        m_sprinklerActive[sprinklerIndex] = activate;
        qDebug() << (activate ? "🚿 [MqttProtectionMonitor] 洒水启动命令已发布"
                              : "🚿 [MqttProtectionMonitor] 洒水停止命令已发布")
                 << "洒水:" << sprinklerIndex
                 << "topic:" << topic << "channel:" << channel;
    } else {
        qWarning() << "⚠️ [MqttProtectionMonitor] 洒水" << sprinklerIndex
                   << "命令发布失败 topic:" << topic;
    }
}

// ✅ 2026-03-10 [Phase 7.48.31]: 电机控制 MQTT 命令发布
// 参考 DO 模块文档：docs/2026-03-10/02-Luckfox-Lyra-RK3506-IO模块部署记录.md
// DO 模块（设备5, Luckfox Lyra RK3506-5）：8路继电器输出 + 8路反馈输入 + 1路急停
void MqttProtectionMonitor::publishMotorCommand(int deviceId, int motorIndex, bool activate)
{
    if (!m_mqttController) {
        qWarning() << "⚠️ [MqttProtectionMonitor] MQTTController未设置，无法发布电机控制命令";
        return;
    }

    if (!m_deviceConfigMgr) {
        qWarning() << "⚠️ [MqttProtectionMonitor] DeviceConfigManager未设置，无法读取电机配置";
        return;
    }

    // 读取电机基本配置（Tab 0）
    QVariantMap config = m_deviceConfigMgr->loadMotorConfig(deviceId, motorIndex, 0);
    if (config.isEmpty()) {
        qWarning() << "⚠️ [MqttProtectionMonitor] 电机" << (motorIndex + 1) << "基本配置为空";
        return;
    }

    // 检查运行状态是否为"投入"
    QString runningState = config.value("running_state", "投入").toString();
    if (runningState != "投入") {
        qDebug() << "⏭️ [MqttProtectionMonitor] 电机" << (motorIndex + 1) << "运行状态为" << runningState << "，跳过";
        return;
    }

    int outputChannel = config.value("output_channel", -1).toInt();
    if (outputChannel < 0 || outputChannel > 7) {
        qWarning() << "⚠️ [MqttProtectionMonitor] 电机" << (motorIndex + 1) << "输出通道无效:" << outputChannel;
        return;
    }

    int moduleAddress = config.value("motor_module_address", 1).toInt();
    // DO 模块 MQTT 主题：belt_control/do/module{N}/cmd
    QString topic = QString("belt_control/do/module%1/cmd").arg(moduleAddress);

    // 构建 JSON 命令（匹配 DO 模块 mqtt_do_publisher.py 的命令格式）
    QJsonObject cmd;
    cmd["action"] = "set";
    cmd["channel"] = outputChannel;
    cmd["value"] = activate ? 1 : 0;

    QString message = QJsonDocument(cmd).toJson(QJsonDocument::Compact);

    if (m_mqttController->publish(topic, message, 1, false)) {
        qDebug() << (activate ? "🔌 [MqttProtectionMonitor] 电机启动命令已发布"
                              : "🔌 [MqttProtectionMonitor] 电机停止命令已发布")
                 << "电机:" << (motorIndex + 1)
                 << "topic:" << topic << "channel:" << outputChannel;
    } else {
        qWarning() << "⚠️ [MqttProtectionMonitor] 电机" << (motorIndex + 1)
                   << "控制命令发布失败 topic:" << topic;
    }
}

// ✅ 2026-03-13: PT100温度转换
// 公式来自嵌入式代码：temperature = rawValue × 250 / 4096 - 50
// 范围：-50℃ ~ +200℃
double MqttProtectionMonitor::convertPT100(quint16 rawValue)
{
    return (double)(rawValue * 250) / 4096.0 - 50.0;
}

// ✅ 2026-03-13: 4-20mA电流型转换
// 公式来自嵌入式代码：value = (rawValue - 819) × Range / (4096 - 819)
// 4mA对应rawValue=819, 20mA对应rawValue=4096
// rawValue < 819 表示欠量程（传感器断线）
double MqttProtectionMonitor::convert420mA(quint16 rawValue, double range)
{
    if (rawValue < 819) return 0.0;  // 欠量程
    return ((double)(rawValue - 819) * range) / (double)(4096 - 819);
}

// ✅ 2026-03-13: 电机保护Modbus TCP数据接收处理
// 从NetworkTask接收motorRegisterReceived信号
// 流程：加载device_motor_config → PT100/4-20mA转换 → 对比阈值 → 触发报警
void MqttProtectionMonitor::onMotorRegisterReceived(int motorIndex, int tabIndex, quint16 rawValue)
{
    if (!m_isRunning) return;
    if (!m_deviceConfigMgr) {
        qWarning() << "⚠️ [MqttProtectionMonitor] onMotorRegisterReceived: DeviceConfigManager未设置";
        return;
    }
    if (motorIndex < 0 || motorIndex > 7) return;
    if (tabIndex < 1 || tabIndex > 9) return;

    // 使用AI模块0对应的皮带编号（电机保护测试模式下，所有电机属于同一皮带）
    int beltNumber = m_aiBeltMapping.value(0, 1);

    // 从device_motor_config加载该电机该Tab的保护配置
    QVariantMap config = m_deviceConfigMgr->loadMotorConfig(beltNumber, motorIndex, tabIndex);
    if (config.isEmpty()) {
        return;  // 无配置，跳过
    }

    // 检查保护级别（0=禁用）— 不提前返回，需要先转换值供QML显示
    // ✅ 2026-03-13 [Phase 7.48.43]: 移到转换后检查，保证motorValueUpdated信号始终发射
    int protLevel = config.value("protection_level", 0).toInt();
    // 旧：if (protLevel <= 0) return;  // 2026-03-13 注释：移到转换后

    // 读取保护配置参数
    QString inputType = config.value("input_type", "4-20mA电流型").toString();
    double rangeValue = config.value("range_value", 100.0).toDouble();
    double upperLimit = config.value("upper_limit", 100.0).toDouble();
    double lowerLimit = config.value("lower_limit", 0.0).toDouble();
    QString protectionName = config.value("protection_name", "").toString();
    QString unit = config.value("unit", "").toString();

    // 根据输入类型选择转换公式
    double engineeringValue = 0.0;
    if (inputType.contains("PT100")) {
        engineeringValue = convertPT100(rawValue);
    } else {
        // 4-20mA / 0-20mA / 0-5V / 0-10V / 1-5V 统一使用4-20mA公式
        engineeringValue = convert420mA(rawValue, rangeValue);
    }

    // ✅ 2026-03-13 [Phase 7.48.43]: 发射实时值更新信号（供QML显示，无论保护是否启用）
    bool isExceeded = (engineeringValue > upperLimit) ||
                      (engineeringValue < lowerLimit && rawValue > 0);
    emit motorValueUpdated(motorIndex, tabIndex, engineeringValue, unit, protectionName, isExceeded);

    // 保护级别检查（0=禁用时不触发报警，但上面的值更新信号仍然发射）
    if (protLevel <= 0) return;

    // 边沿触发报警键
    QString alarmKey = QString("motor:%1:%2").arg(motorIndex).arg(tabIndex);

    // 超限检测
    bool exceeded = false;
    QString limitType;
    if (engineeringValue > upperLimit) {
        exceeded = true;
        limitType = "超上限";
    } else if (engineeringValue < lowerLimit && rawValue > 0) {
        // rawValue > 0 排除传感器断线情况（断线时rawValue=0，不应报下限）
        exceeded = true;
        limitType = "低于下限";
    }

    bool wasActive = m_motorProtectionAlarmActive.value(alarmKey, false);

    if (exceeded && !wasActive) {
        // ===== 正常→超限（触发报警）=====
        m_motorProtectionAlarmActive[alarmKey] = true;

        // ✅ 2026-03-13 [Phase 7.48.43]: displayName加皮带号，TTS播报更完整
        // 旧：QString displayName = QString("电机%1 %2").arg(motorIndex + 1).arg(protectionName);
        QString displayName = QString("%1号皮带%2号电机%3")
            .arg(beltNumber).arg(motorIndex + 1).arg(protectionName);
        qWarning() << "🔴 [电机保护] " << displayName << limitType
                   << "当前值:" << engineeringValue << unit
                   << "上限:" << upperLimit << "下限:" << lowerLimit
                   << "原始值:" << rawValue;

        // 触发报警播放
        if (m_alarmPlaybackService) {
            bool useTTS = config.value("use_text_to_speech", false).toBool();
            // ✅ 2026-03-13 [Phase 7.48.43]: 使用AudioPathMapper生成预生成音频路径
            // 音频文件名格式：X号电机+描述（如"1号电机甲相绕组温度过高"）
            // 映射保护名→音频文件描述后缀
            QString audioDesc;
            if (protectionName.contains("绕组"))       audioDesc = protectionName + "温度过高";
            else if (protectionName.contains("轴承"))   audioDesc = protectionName + "过高";
            else if (protectionName.contains("振动"))   audioDesc = protectionName + "过大";
            else if (protectionName.contains("电流"))   audioDesc = "电流过载";
            else if (protectionName.contains("电机温度")) audioDesc = "温度过高";
            else                                        audioDesc = protectionName;

            QString motorAudioName = QString("%1号电机%2").arg(motorIndex + 1).arg(audioDesc);
            QString audioFile = m_audioPathMapper->getAudioPath(beltNumber, motorAudioName);
            qDebug() << "🔊 [电机保护] 音频路径:" << audioFile;

            QString ttsText = config.value("tts_text", "").toString();
            QString playMode = config.value("play_mode", "count").toString();
            int playCount = config.value("play_count", 3).toInt();
            double playDuration = config.value("play_duration", 10.0).toDouble();

            // 如果没有自定义TTS文字，自动生成
            if (ttsText.isEmpty()) {
                ttsText = QString("%1%2，当前值%3%4")
                    .arg(displayName).arg(limitType)
                    .arg(QString::number(engineeringValue, 'f', 1)).arg(unit);
            }

            m_alarmPlaybackService->playAlarm(displayName, ttsText, audioFile,
                                                useTTS, playMode, playCount, playDuration);
        }

        // 发射保护触发信号（用于报警历史记录）
        emit analogProtectionTriggered(beltNumber, QString("电机%1 %2").arg(motorIndex + 1).arg(protectionName),
                                        engineeringValue, limitType);

    } else if (!exceeded && wasActive) {
        // ===== 超限→正常（恢复）=====
        m_motorProtectionAlarmActive[alarmKey] = false;

        // ✅ 2026-03-13 [Phase 7.48.43]: displayName加皮带号
        // 旧：QString displayName = QString("电机%1 %2").arg(motorIndex + 1).arg(protectionName);
        QString displayName = QString("%1号皮带%2号电机%3")
            .arg(beltNumber).arg(motorIndex + 1).arg(protectionName);
        qDebug() << "🟢 [电机保护] " << displayName << "恢复正常"
                 << "当前值:" << engineeringValue << unit;

        // 恢复时不停止播放（AlarmPlaybackService按次数/时长自动结束）
        // 如需停止可在此添加停止逻辑

        emit analogProtectionRestored(beltNumber, QString("电机%1 %2").arg(motorIndex + 1).arg(protectionName),
                                       engineeringValue);
    }
}

// ✅ 2026-03-18 [Phase 7.48.56]: CS模块位变化槽函数（沿线急停/跑偏/撕裂）
void MqttProtectionMonitor::onCSBitChanged(int protType, int pointIndex, bool value)
{
    if (!m_isRunning) {
        return;
    }

    // 保护类型名称映射
    static const QStringList protTypeNames = {"沿线急停", "沿线跑偏", "沿线撕裂"};
    if (protType < 0 || protType >= protTypeNames.size()) {
        qWarning() << "⚠️ [MqttProtectionMonitor] 无效的CS保护类型:" << protType;
        return;
    }

    QString protTypeName = protTypeNames[protType];
    int pointNumber = pointIndex + 1;  // 点位编号从1开始
    QString protectionName = QString("%1号%2").arg(pointNumber).arg(protTypeName);

    // 边沿触发：使用 m_csProtectionAlarmActive 追踪状态
    QString alarmKey = QString("cs:%1:%2").arg(protType).arg(pointIndex);
    bool wasActive = m_csProtectionAlarmActive.value(alarmKey, false);

    if (value && !wasActive) {
        // ===== 正常→触发（0→1）=====
        m_csProtectionAlarmActive[alarmKey] = true;

        qDebug() << "🚨 [CS保护] " << protectionName << "触发！"
                 << "protType:" << protType << "pointIndex:" << pointIndex;

        // 计算 channel_number = protType * 100 + pointIndex
        int channelNumber = protType * 100 + pointIndex;

        // 查询数据库获取保护配置
        QString audioPath;
        bool useTTS = false;
        QString playMode = "count";
        int playCount = 3;
        double playDuration = 5.0;
        QString ttsText;

        if (m_deviceConfigMgr) {
            QVariantMap protection = m_deviceConfigMgr->loadDigitalProtectionByChannel("CS模块", channelNumber);
            if (!protection.isEmpty()) {
                useTTS = (protection.value("use_text_to_speech", 0).toInt() == 1);
                playMode = protection.value("play_mode", "count").toString();
                playCount = protection.value("play_count", 3).toInt();
                playDuration = protection.value("play_duration", 5.0).toDouble();
                ttsText = protection.value("tts_text", "").toString();
                // 优先使用数据库中的音频文件路径
                QString dbAudioFile = protection.value("audio_file", "").toString();
                if (!dbAudioFile.isEmpty()) {
                    // 构建完整路径：{audioBaseDir}/{beltNumber}#PD/{audioFile}
                    int beltNumber = m_beltMapping.value(0, 1);  // CS模块使用默认皮带映射
                    QString audioBaseDir = m_audioPathMapper->baseDirectory();
                    audioPath = QString("%1/%2#PD/%3").arg(audioBaseDir).arg(beltNumber).arg(dbAudioFile);
                }
                qDebug() << "📋 [CS保护] " << protectionName
                         << "音频来源:" << (useTTS ? "TTS" : "默认")
                         << "播放方式:" << playMode
                         << "次数:" << playCount << "时长:" << playDuration;
            } else {
                qWarning() << "⚠️ [CS保护] 未找到保护配置: module_type=CS模块, channel=" << channelNumber;
            }
        }

        // 如果没有从DB获取到路径，使用默认命名
        if (audioPath.isEmpty()) {
            int beltNumber = m_beltMapping.value(0, 1);
            QString audioBaseDir = m_audioPathMapper->baseDirectory();
            audioPath = QString("%1/%2#PD/%3.wav").arg(audioBaseDir).arg(beltNumber).arg(protectionName);
        }

        // 播放报警音频
        if (m_alarmPlaybackService) {
            qDebug() << "🔊 [CS保护] 触发播放:" << audioPath << "模式:" << playMode;
            m_alarmPlaybackService->playAlarm(protectionName, ttsText, audioPath,
                                              useTTS, playMode, playCount, playDuration);
        } else if (m_commonControl) {
            qDebug() << "🔊 [CS保护] 回退到CommonControl单次播放:" << audioPath;
            m_commonControl->playAudio(audioPath);
        }

        // 发射保护触发信号（用于报警历史记录）
        int beltNumber = m_beltMapping.value(0, 1);
        emit protectionTriggered(5, pointIndex, beltNumber, protectionName, audioPath);

    } else if (!value && wasActive) {
        // ===== 触发→恢复（1→0）=====
        m_csProtectionAlarmActive[alarmKey] = false;
        qDebug() << "🟢 [CS保护] " << protectionName << "恢复正常";
    }
}
