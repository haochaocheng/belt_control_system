#include "TTSConfigManager.h"
#include <QDebug>

// ✅ 2026-01-23 09:30 [FIX 100.299] TTS模型信息表
// ✅ 2026-02-28 09:50 [Phase 7.47.40]: 更新为PaddleSpeech实际模型名
// 原因：旧的vits模型名(vits-zh-aishell3等)已废弃，现在使用PaddleSpeech引擎
//       AudioPathMapper读取此表生成音频路径，必须与批量生成的文件夹名一致
// 旧值：{0, "vits-zh-aishell3"}, {1, "vits-zh-hf-fanchen-wnj"}, ...
// 模型名称映射
static const QMap<int, QString> MODEL_NAMES = {
    {0, "fastspeech2_csmsc"},
    {1, "fastspeech2_aishell3"}
};

// 模型路径映射
// 旧值：{0, "/app/tts_models/vits-zh-aishell3"}, ...
static const QMap<int, QString> MODEL_PATHS = {
    {0, "/app/tts_models/paddlespeech/fastspeech2_csmsc"},
    {1, "/app/tts_models/paddlespeech/fastspeech2_aishell3"}
};

// 模型最大说话人ID映射
// 旧值：{0, 173}, {1, 0}, {2, 186}, {3, 803}, {4, 803}, {5, 4}, {6, 0}
static const QMap<int, int> MODEL_MAX_SPEAKER_IDS = {
    {0, 0},     // fastspeech2_csmsc: 单说话人（中文女声）
    {1, 173}    // fastspeech2_aishell3: 174 speakers (0-173)
};

TTSConfigManager* TTSConfigManager::instance()
{
    static TTSConfigManager *inst = new TTSConfigManager();
    return inst;
}

TTSConfigManager::TTSConfigManager(QObject *parent)
    : QObject(parent)
    , m_settings(new QSettings("BeltControlSystem", "TTS", this))
{
    qDebug() << "📋 [TTSConfig] 初始化TTS配置管理器";
    loadConfig();
}

void TTSConfigManager::loadConfig()
{
    qDebug() << "📂 [TTSConfig] 加载TTS配置";

    // 加载三个场景的配置
    for (int i = StartupWarning; i <= Test; ++i) {
        Scene scene = static_cast<Scene>(i);
        QString key = sceneKey(scene);

        SceneConfig config;
        config.modelIndex = m_settings->value(key + "/modelIndex", 0).toInt();
        // ✅ 2026-02-28 09:50 [Phase 7.47.40]: 防止旧配置的模型索引超出范围
        // 原因：旧版本有7个vits模型(0-6)，现在只有2个PaddleSpeech模型(0-1)
        if (config.modelIndex >= MODEL_NAMES.size()) {
            qWarning() << "⚠️ [TTSConfig] 模型索引" << config.modelIndex
                       << "超出范围，重置为0";
            config.modelIndex = 0;
        }
        config.modelPath = m_settings->value(key + "/modelPath", MODEL_PATHS[0]).toString();
        config.speakerId = m_settings->value(key + "/speakerId", 0).toInt();
        config.rate = m_settings->value(key + "/rate", 1.0).toDouble();
        // 旧：config.volume = m_settings->value(key + "/volume", 0.8).toDouble();
        // ✅ 2026-03-25 [Phase 7.48.88.10]: 默认音量改为1.0（最大值），确保预警语音清晰
        config.volume = m_settings->value(key + "/volume", 1.0).toDouble();
        // ✅ 2026-02-26 [Phase 7.47.19]: 加载采样率配置
        // ❌ 2026-03-04 18:30 [Phase 7.47.91]: 旧默认值 24000 — dmix 需重采样且 ES8388 不支持 24kHz
        // ✅ 2026-03-04 18:30 [Phase 7.47.91]: 新默认值 48000 — 与 dmix/硬件一致，全链路零重采样
        config.sampleRate = m_settings->value(key + "/sampleRate", 48000).toInt();

        m_configs[scene] = config;

        qDebug() << "  -" << key << ": model=" << config.modelIndex
                 << ", speaker=" << config.speakerId
                 << ", rate=" << config.rate;
    }
}

void TTSConfigManager::saveConfig()
{
    qDebug() << "💾 [TTSConfig] 保存TTS配置";

    for (auto it = m_configs.begin(); it != m_configs.end(); ++it) {
        Scene scene = it.key();
        const SceneConfig &config = it.value();
        QString key = sceneKey(scene);

        m_settings->setValue(key + "/modelIndex", config.modelIndex);
        m_settings->setValue(key + "/modelPath", config.modelPath);
        m_settings->setValue(key + "/speakerId", config.speakerId);
        m_settings->setValue(key + "/rate", config.rate);
        m_settings->setValue(key + "/volume", config.volume);
        // ✅ 2026-02-26 [Phase 7.47.19]: 保存采样率配置
        m_settings->setValue(key + "/sampleRate", config.sampleRate);
    }

    m_settings->sync();
}

QString TTSConfigManager::sceneKey(Scene scene) const
{
    switch (scene) {
    case StartupWarning: return "startup_warning";
    case FaultAlarm: return "fault_alarm";
    case Test: return "test";
    default: return "unknown";
    }
}

int TTSConfigManager::modelIndex(Scene scene) const
{
    return m_configs.value(scene).modelIndex;
}

void TTSConfigManager::setModelIndex(Scene scene, int index)
{
    if (m_configs[scene].modelIndex != index) {
        m_configs[scene].modelIndex = index;
        m_configs[scene].modelPath = MODEL_PATHS[index];
        emit configChanged(scene);
    }
}

QString TTSConfigManager::modelPath(Scene scene) const
{
    return m_configs.value(scene).modelPath;
}

void TTSConfigManager::setModelPath(Scene scene, const QString &path)
{
    if (m_configs[scene].modelPath != path) {
        m_configs[scene].modelPath = path;
        emit configChanged(scene);
    }
}

int TTSConfigManager::speakerId(Scene scene) const
{
    return m_configs.value(scene).speakerId;
}

void TTSConfigManager::setSpeakerId(Scene scene, int id)
{
    if (m_configs[scene].speakerId != id) {
        m_configs[scene].speakerId = id;
        emit configChanged(scene);
    }
}

double TTSConfigManager::rate(Scene scene) const
{
    return m_configs.value(scene).rate;
}

void TTSConfigManager::setRate(Scene scene, double rate)
{
    if (m_configs[scene].rate != rate) {
        m_configs[scene].rate = rate;
        emit configChanged(scene);
    }
}

double TTSConfigManager::volume(Scene scene) const
{
    return m_configs.value(scene).volume;
}

void TTSConfigManager::setVolume(Scene scene, double volume)
{
    if (m_configs[scene].volume != volume) {
        m_configs[scene].volume = volume;
        emit configChanged(scene);
    }
}

// ✅ 2026-02-26 [Phase 7.47.19]: 采样率配置
int TTSConfigManager::sampleRate(Scene scene) const
{
    return m_configs.value(scene).sampleRate;
}

void TTSConfigManager::setSampleRate(Scene scene, int rate)
{
    if (m_configs[scene].sampleRate != rate) {
        m_configs[scene].sampleRate = rate;
        emit configChanged(scene);
    }
}

QString TTSConfigManager::modelName(int index) const
{
    return MODEL_NAMES.value(index, "unknown");
}

int TTSConfigManager::maxSpeakerId(int modelIndex) const
{
    return MODEL_MAX_SPEAKER_IDS.value(modelIndex, 0);
}

QStringList TTSConfigManager::modelNames() const
{
    QStringList names;
    for (int i = 0; i < MODEL_NAMES.size(); ++i) {
        names << MODEL_NAMES[i];
    }
    return names;
}

// ✅ 2026-02-27 02:10 [Phase 7.47.28]: 通用键值存储（供QML批量合成参数持久化）
void TTSConfigManager::setValue(const QString &key, const QVariant &value)
{
    m_settings->setValue(key, value);
    m_settings->sync();
}

QVariant TTSConfigManager::getValue(const QString &key, const QVariant &defaultValue) const
{
    return m_settings->value(key, defaultValue);
}
