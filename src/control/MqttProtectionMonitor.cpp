#include "MqttProtectionMonitor.h"
#include "../mqtt/DIDataManager.h"
#include "CommonControl.h"
#include "DataPathConfig.h"      // ✅ 2026-02-28 [Phase 7.47.43]: 统一音频路径
#include "DeviceConfigManager.h" // ✅ 2026-02-28 [Phase 7.47.49]: 查询use_text_to_speech
#include <QDebug>
#include <QFile>

// ✅ 2026-02-27 10:30 [Phase 7.47.35]: 实现MQTT开关量保护监控器

MqttProtectionMonitor::MqttProtectionMonitor(DIDataManager *diManager,
                                             CommonControl *commonControl,
                                             QObject *parent)
    : QObject(parent)
    , m_diManager(diManager)
    , m_commonControl(commonControl)
    // ✅ 2026-02-27 11:00 [Phase 7.47.35]: 修复编译错误，AudioPathMapper不是QObject，不接受parent参数
    // ⚠️ 2026-02-28 [Phase 7.47.43]: 先用默认构造，构造体内再设置正确路径（见下方）
    // 旧值（错误）：new AudioPathMapper("/app/audio")
    // 原因：Docker挂载的是 /home/{user}/belt-control-data/audio，不是 /app/audio
    //       AudioPathMapper("/app/audio") 会查找不存在的路径，导致音频文件找不到
    , m_audioPathMapper(new AudioPathMapper())
    , m_deviceConfigMgr(nullptr)  // ✅ 2026-02-28 [Phase 7.47.49]: 由main.cpp通过setDeviceConfigManager注入
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
    m_beltMapping[0] = 1;  // 模块0 → 1号皮带
    m_beltMapping[1] = 2;  // 模块1 → 2号皮带

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

    if (m_deviceConfigMgr) {
        // 查询DB获取该保护的音频来源设置
        QString shortName = m_audioPathMapper->getShortProtectionName(bitIndex);
        QVariantMap protection = m_deviceConfigMgr->loadDigitalProtection(beltNumber, shortName);
        if (!protection.isEmpty()) {
            useTTS = (protection.value("use_text_to_speech", 1).toInt() == 1);
            qDebug() << "📋 [MqttProtectionMonitor] 保护" << shortName
                     << "音频来源:" << (useTTS ? "TTS合成" : "默认(1#PD MP3)");
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
    if (m_commonControl) {
        qDebug() << "🔊 [MqttProtectionMonitor] 触发音频播放:" << audioPath;
        m_commonControl->playAudio(audioPath);
    } else {
        qWarning() << "⚠️ [MqttProtectionMonitor] CommonControl为空，无法播放音频";
    }
}
