#include "AudioPathMapper.h"
// #include "tts/VoiceFileList.h"  // ⚠️ 2026-02-28 [Phase 7.47.42]: 已废弃，不再使用
#include "TTSConfigManager.h"
#include <QDir>
#include <QDebug>

// ✅ 2026-02-27 10:00 [Phase 7.47.35]: 实现音频文件路径映射器
// ✅ 2026-02-28 [Phase 7.47.42]: 重构保护名称映射，使用真实DI位定义

// ✅ 2026-02-28 [Phase 7.47.49]: 默认音频文件名映射（通道号 → 1#PD实际文件名.mp3）
// 文件来源：AUDIO/1#PD/ 目录，与设备端 /home/{user}/belt-control-data/audio/{belt}#PD/ 内容一致
QMap<int, QString> AudioPathMapper::initDefaultAudioFileMap()
{
    QMap<int, QString> map;
    map[0] = "沿线急停.mp3";   // 急停  → AUDIO/1#PD/沿线急停.mp3
    map[1] = "跑偏.mp3";       // 跑偏  → AUDIO/1#PD/跑偏.mp3
    map[2] = "撕裂.mp3";       // 撕裂  → AUDIO/1#PD/撕裂.mp3
    map[3] = "烟雾.mp3";       // 烟雾  → AUDIO/1#PD/烟雾.mp3
    map[4] = "温度.mp3";       // 温度  → AUDIO/1#PD/温度.mp3
    map[5] = "护网.mp3";       // 护网  → AUDIO/1#PD/护网.mp3
    map[6] = "堆煤.mp3";       // 堆煤  → AUDIO/1#PD/堆煤.mp3
    map[7] = "主机急停.mp3";   // 主机急停 → AUDIO/1#PD/主机急停.mp3
    return map;
}

// ✅ 2026-02-28 [Phase 7.47.49]: 保护短名称映射（通道号 → UI/DB名称）
// 与 SwitchInputPage.qml 的 digitalProtectionModel name 字段一致（用于DB查询 use_text_to_speech）
QMap<int, QString> AudioPathMapper::initShortNameMap()
{
    QMap<int, QString> map;
    map[0] = "急停";
    map[1] = "跑偏";
    map[2] = "撕裂";
    map[3] = "烟雾";
    map[4] = "温度";
    map[5] = "护网";
    map[6] = "堆煤";
    map[7] = "主机急停";
    return map;
}

// 初始化保护名称映射表
QMap<int, QString> AudioPathMapper::initProtectionNameMap()
{
    QMap<int, QString> map;

    // ✅ 2026-02-28 [Phase 7.47.42]: 8位DI保护名称（短名，用作音频文件名）
    // 来源：docs/2026-02-24/01-TTS语音文件批量生成清单.md 第二章
    // 与SwitchInputPage.qml的channelNumber定义一致
    // 规则：文件名 = 去掉"X号皮带"前缀 + 去掉"保护"后缀
    // 对应关系：
    //   TTS合成文本："{belt}号皮带沿线急停保护"
    //   音频文件名：  "沿线急停.wav"
    //   触发查找文件："沿线急停.wav"  ← 三者一致

    // 旧代码（从VoiceFileList.h的33项中提取，但名称不正确）已废弃：
    // const QStringList &items = SwitchInputVoice::PROTECTION_ITEMS;
    // for (int i = 0; i < items.size(); ++i) { ... }

    map[0] = "沿线急停";    // channelNumber: 0 (急停)  TTS: "X号皮带沿线急停保护"
    map[1] = "沿线跑偏";    // channelNumber: 1 (跑偏)  TTS: "X号皮带沿线跑偏保护"
    map[2] = "沿线撕裂";    // channelNumber: 2 (撕裂)  TTS: "X号皮带沿线撕裂保护"
    map[3] = "烟雾";        // channelNumber: 3 (烟雾)  TTS: "X号皮带烟雾保护"
    map[4] = "温度";        // channelNumber: 4 (温度)  TTS: "X号皮带温度保护"
    map[5] = "护网";        // channelNumber: 5 (护网)  TTS: "X号皮带护网保护"
    map[6] = "堆煤";        // channelNumber: 6 (堆煤)  TTS: "X号皮带堆煤保护"
    map[7] = "主机急停";    // channelNumber: 7 (主机急停) TTS: "X号皮带主机急停保护"

    return map;
}

// 静态成员初始化
const QMap<int, QString> AudioPathMapper::PROTECTION_NAME_MAP = AudioPathMapper::initProtectionNameMap();
// ✅ 2026-02-28 [Phase 7.47.49]: 新增静态成员初始化
const QMap<int, QString> AudioPathMapper::DEFAULT_AUDIO_FILE_MAP = AudioPathMapper::initDefaultAudioFileMap();
const QMap<int, QString> AudioPathMapper::SHORT_NAME_MAP = AudioPathMapper::initShortNameMap();

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

// ✅ 2026-02-28 [Phase 7.47.49]: 获取默认音频文件路径（1#PD预置MP3）
QString AudioPathMapper::getDefaultAudioPath(int beltNumber, int channelNumber) const
{
    // 从DEFAULT_AUDIO_FILE_MAP获取文件名
    QString filename = DEFAULT_AUDIO_FILE_MAP.value(channelNumber,
                           QString("未知保护%1.mp3").arg(channelNumber));

    // 路径格式：{baseDir}/{belt}#PD/{filename}
    // 例：/home/linaro/belt-control-data/audio/1#PD/沿线急停.mp3
    QString path = QString("%1/%2#PD/%3").arg(m_baseDir).arg(beltNumber).arg(filename);

    qDebug() << "🎵 [AudioPathMapper] 默认音频路径:" << path;
    return path;
}

// ✅ 2026-02-28 [Phase 7.47.49]: 获取保护短名称（用于DB查询）
QString AudioPathMapper::getShortProtectionName(int bitIndex) const
{
    return SHORT_NAME_MAP.value(bitIndex, QString("未知保护%1").arg(bitIndex));
}

// ✅ 2026-03-02 [Phase 7.47.69]: 模块在线状态 - 静态路径方法
// ✅ 2026-03-02 [Phase 7.47.71 修复]: 与 BatchAudioGenerator 路径一致，包含引擎子目录
//    路径格式：{audioBaseDir}/paddlespeech-{modelName}-spk{speakerId}/Status/{name}.wav
//    与 BatchSynthesisContent.qml 的 outputFolder 构造逻辑一致：
//    "paddlespeech-" + TTSConfig.modelName(...) + "-spk" + TTSConfig.speakerId(...)

static QString buildStatusEngineFolder()
{
    TTSConfigManager *config = TTSConfigManager::instance();
    int modelIndex = config->modelIndex(TTSConfigManager::Test);
    QString modelName = config->modelName(modelIndex);
    int speakerId = config->speakerId(TTSConfigManager::Test);
    return QString("paddlespeech-%1-spk%2").arg(modelName).arg(speakerId);
}

// 获取"连接服务器失败"语音文件路径
QString AudioPathMapper::getBrokerConnectionFailedPath()
{
    QString engineFolder = buildStatusEngineFolder();
    return DataPathConfig::getAudioBaseDirectory() + "/" + engineFolder + "/Status/连接服务器失败.wav";
}

// 获取模块离线语音文件路径
// moduleIndex: 0=开关量模块一, 1=开关量模块二, 2=模拟量模块一, 3=模拟量模块二
QString AudioPathMapper::getModuleOfflinePath(int moduleIndex)
{
    static const QStringList NAMES = {
        "开关量模块一离线",
        "开关量模块二离线",
        "模拟量模块一离线",
        "模拟量模块二离线"
    };
    if (moduleIndex < 0 || moduleIndex >= NAMES.size()) {
        qWarning() << "⚠️ [AudioPathMapper] getModuleOfflinePath: 无效模块索引" << moduleIndex;
        return QString();
    }
    QString engineFolder = buildStatusEngineFolder();
    return DataPathConfig::getAudioBaseDirectory() + "/" + engineFolder + "/Status/" + NAMES[moduleIndex] + ".wav";
}

// ✅ 2026-03-05 [Phase 7.48.5]: 模拟量保护音频路径映射

// 初始化模拟量保护名称映射表（DB保护名 → 音频文件名）
QMap<QString, QString> initAnalogProtectionAudioMap()
{
    QMap<QString, QString> map;
    // 设备运行保护（10项）
    map["速度超速"] = "速度超速";
    map["低速打滑"] = "低速打滑";
    map["张力上限"] = "张力上限";
    map["张力下限"] = "张力下限";
    map["煤流"]     = "煤流";
    map["煤仓高度"] = "煤仓高度";
    map["温度一"]   = "温度一";
    map["温度二"]   = "温度二";
    map["电压过压"] = "电压过压";
    map["电压欠压"] = "电压欠压";
    // 环境安全监测（8项）
    map["温度"]     = "温度";
    map["湿度"]     = "湿度";
    map["烟雾"]     = "烟雾浓度";  // 注意：DB名"烟雾" → 文件名"烟雾浓度"
    map["气压"]     = "气压";
    map["氧气"]     = "氧气";
    map["甲烷"]     = "甲烷";
    map["一氧化碳"] = "一氧化碳";
    map["硫化氢"]   = "硫化氢";
    // 安全规程补充（3项）
    map["二氧化碳"] = "二氧化碳";
    map["风速"]     = "风速";
    map["粉尘浓度"] = "粉尘浓度";
    return map;
}

// 静态成员初始化
const QMap<QString, QString> AudioPathMapper::ANALOG_PROTECTION_AUDIO_MAP = initAnalogProtectionAudioMap();

// 获取模拟量保护音频文件名（从DB保护名映射到文件名）
QString AudioPathMapper::getAnalogAudioFileName(const QString &dbProtectionName)
{
    // 查找映射表
    if (ANALOG_PROTECTION_AUDIO_MAP.contains(dbProtectionName)) {
        return ANALOG_PROTECTION_AUDIO_MAP[dbProtectionName];
    }

    // 未找到映射，直接使用DB名称
    qWarning() << "⚠️ [AudioPathMapper] getAnalogAudioFileName: 未找到映射，使用DB名称:" << dbProtectionName;
    return dbProtectionName;
}

// 获取模拟量保护音频路径（使用当前TTS配置）
QString AudioPathMapper::getAnalogAudioPath(int beltNumber, const QString &dbProtectionName) const
{
    // 获取音频文件名
    QString audioFileName = getAnalogAudioFileName(dbProtectionName);

    // 使用当前TTS配置生成路径
    return getAudioPath(beltNumber, audioFileName);
}
