#include "TTSConfigManager.h"
#include <QDebug>

// ✅ 2026-01-23 09:30 [FIX 100.299] TTS模型信息表
// 模型名称映射
static const QMap<int, QString> MODEL_NAMES = {
    {0, "vits-zh-aishell3"},
    {1, "vits-zh-hf-fanchen-wnj"},
    {2, "vits-zh-hf-fanchen-C"},
    {3, "vits-zh-hf-theresa"},
    {4, "vits-zh-hf-eula"},
    {5, "sherpa-onnx-vits-zh-ll"},
    {6, "vits-melo-tts-zh_en"}
};

// 模型路径映射
static const QMap<int, QString> MODEL_PATHS = {
    {0, "/app/tts_models/vits-zh-aishell3"},
    {1, "/app/tts_models/vits-zh-hf-fanchen-wnj"},
    {2, "/app/tts_models/vits-zh-hf-fanchen-C"},
    {3, "/app/tts_models/vits-zh-hf-theresa"},
    {4, "/app/tts_models/vits-zh-hf-eula"},
    {5, "/app/tts_models/sherpa-onnx-vits-zh-ll"},
    {6, "/app/tts_models/vits-melo-tts-zh_en"}
};

// 模型最大说话人ID映射
static const QMap<int, int> MODEL_MAX_SPEAKER_IDS = {
    {0, 173},   // aishell3: 174 speakers (0-173)
    {1, 0},     // fanchen-wnj: 1 speaker (0)
    {2, 186},   // fanchen-C: 187 speakers (0-186)
    {3, 803},   // theresa: 804 speakers (0-803)
    {4, 803},   // eula: 804 speakers (0-803)
    {5, 4},     // zh-ll: 5 speakers (0-4)
    {6, 0}      // melo-tts: 1 speaker (0)
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
        config.modelPath = m_settings->value(key + "/modelPath", MODEL_PATHS[0]).toString();
        config.speakerId = m_settings->value(key + "/speakerId", 0).toInt();
        config.rate = m_settings->value(key + "/rate", 1.0).toDouble();
        config.volume = m_settings->value(key + "/volume", 0.8).toDouble();
        // ✅ 2026-02-26 [Phase 7.47.19]: 加载采样率配置，默认 24000
        config.sampleRate = m_settings->value(key + "/sampleRate", 24000).toInt();

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
