#include "AudioPathMapper.h"
#include "tts/VoiceFileList.h"
#include "TTSConfigManager.h"
#include <QDir>
#include <QDebug>

// ✅ 2026-02-27 10:00 [Phase 7.47.35]: 实现音频文件路径映射器

// 初始化保护名称映射表
QMap<int, QString> AudioPathMapper::initProtectionNameMap()
{
    QMap<int, QString> map;

    // ✅ 从VoiceFileList.h中的SwitchInputVoice::PROTECTION_ITEMS提取保护名称
    // 去掉模板中的"%1号皮带"前缀，只保留保护类型
    const QStringList &items = SwitchInputVoice::PROTECTION_ITEMS;

    for (int i = 0; i < items.size(); ++i) {
        QString item = items[i];
        // 移除"%1号皮带"前缀
        QString protectionName = item;
        protectionName.replace("%1号皮带", "");
        map[i] = protectionName;
    }

    return map;
}

// 静态成员初始化
const QMap<int, QString> AudioPathMapper::PROTECTION_NAME_MAP = AudioPathMapper::initProtectionNameMap();

AudioPathMapper::AudioPathMapper(const QString &baseDir)
    : m_baseDir(baseDir)
{
    qDebug() << "✅ [AudioPathMapper] 音频路径映射器已创建，基础目录:" << m_baseDir;
}

void AudioPathMapper::setBaseDirectory(const QString &baseDir)
{
    m_baseDir = baseDir;
    qDebug() << "📁 [AudioPathMapper] 设置基础目录:" << m_baseDir;
}

QString AudioPathMapper::getAudioPath(const QString &engineName,
                                      const QString &modelName,
                                      int speakerId,
                                      int beltNumber,
                                      const QString &protectionName) const
{
    // 生成文件夹路径：{engine}-{model}-spk{id}/{belt}#PD
    QString folderPath = getFolderPath(engineName, modelName, speakerId, beltNumber);

    // 生成完整路径：{folderPath}/{protectionName}.wav
    QString audioPath = QString("%1/%2.wav").arg(folderPath, protectionName);

    qDebug() << "🎵 [AudioPathMapper] 生成音频路径:" << audioPath;

    return audioPath;
}

QString AudioPathMapper::getAudioPath(int beltNumber, const QString &protectionName) const
{
    // ✅ 从TTSConfigManager读取当前测试场景的TTS配置
    TTSConfigManager *config = TTSConfigManager::instance();

    // 获取当前引擎索引（假设使用PaddleSpeech，索引为0）
    // TODO: 如果需要支持多引擎，需要从配置中读取当前引擎
    int engineIndex = 0;  // 0 = PaddleSpeech
    QString engineName = "paddlespeech";

    // 获取模型索引和名称
    int modelIndex = config->modelIndex(TTSConfigManager::Test);
    QString modelName = config->modelName(modelIndex);

    // 获取说话人ID
    int speakerId = config->speakerId(TTSConfigManager::Test);

    qDebug() << "📋 [AudioPathMapper] 使用当前TTS配置:";
    qDebug() << "   引擎:" << engineName;
    qDebug() << "   模型:" << modelName << "(索引:" << modelIndex << ")";
    qDebug() << "   说话人ID:" << speakerId;
    qDebug() << "   皮带编号:" << beltNumber;
    qDebug() << "   保护名称:" << protectionName;

    return getAudioPath(engineName, modelName, speakerId, beltNumber, protectionName);
}

QString AudioPathMapper::getProtectionName(int bitIndex) const
{
    if (PROTECTION_NAME_MAP.contains(bitIndex)) {
        return PROTECTION_NAME_MAP[bitIndex];
    }

    qWarning() << "⚠️ [AudioPathMapper] 未找到位索引" << bitIndex << "对应的保护名称";
    return QString("未知保护%1").arg(bitIndex);
}

QString AudioPathMapper::getFolderPath(const QString &engineName,
                                       const QString &modelName,
                                       int speakerId,
                                       int beltNumber) const
{
    // 格式：{baseDir}/{engine}-{model}-spk{id}/{belt}#PD
    QString folderPath = QString("%1/%2-%3-spk%4/%5#PD")
                            .arg(m_baseDir)
                            .arg(engineName)
                            .arg(modelName)
                            .arg(speakerId)
                            .arg(beltNumber);

    return folderPath;
}
