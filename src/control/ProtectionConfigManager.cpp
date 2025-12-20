#include "ProtectionConfigManager.h"
#include "SystemConfig.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QVariant>
#include <QDebug>

ProtectionConfigManager::ProtectionConfigManager(QObject *parent)
    : QObject(parent)
    , m_systemConfig(nullptr)
{
}

ProtectionConfigManager::~ProtectionConfigManager()
{
    if (m_database.isOpen()) {
        m_database.close();
    }
}

void ProtectionConfigManager::setSystemConfig(SystemConfig *config)
{
    m_systemConfig = config;
    qDebug() << "✅ ProtectionConfigManager: SystemConfig已设置";
}

bool ProtectionConfigManager::initialize(const QString &dbPath)
{
    m_dbPath = dbPath;

    // 创建数据库连接
    m_database = QSqlDatabase::addDatabase("QSQLITE", "protection_config_db");
    m_database.setDatabaseName(m_dbPath);

    if (!m_database.open()) {
        emit databaseError("无法打开数据库: " + m_database.lastError().text());
        return false;
    }

    // 创建表
    if (!createTables()) {
        return false;
    }

    qDebug() << "保护配置数据库初始化成功:" << m_dbPath;
    return true;
}

bool ProtectionConfigManager::createTables()
{
    QSqlQuery query(m_database);

    QString createTableSQL = R"(
        CREATE TABLE IF NOT EXISTS protection_configs (
            name TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            module_type TEXT,
            register_address INTEGER,
            channel_number INTEGER,
            relay_address INTEGER,
            upper_limit REAL,
            lower_limit REAL,
            range_value REAL,
            rated_value REAL,
            unit TEXT,
            protection_delay REAL,
            play_mode TEXT DEFAULT 'count',
            play_count INTEGER,
            play_duration REAL,
            use_text_to_speech INTEGER,
            tts_text TEXT,
            audio_file TEXT,
            enable_popup_animation INTEGER
        )
    )";

    if (!query.exec(createTableSQL)) {
        emit databaseError("创建数据表失败: " + query.lastError().text());
        return false;
    }

    return true;
}

bool ProtectionConfigManager::saveConfig(const QString &name, const ProtectionConfig &config)
{
    // 检查配置是否已存在
    if (configExists(name)) {
        return updateConfig(name, config);
    } else {
        return insertConfig(name, config);
    }
}

bool ProtectionConfigManager::insertConfig(const QString &name, const ProtectionConfig &config)
{
    QSqlQuery query(m_database);

    query.prepare(R"(
        INSERT INTO protection_configs (
            name, type, module_type, register_address, channel_number, relay_address,
            upper_limit, lower_limit, range_value, rated_value, unit,
            protection_delay, play_mode, play_count, play_duration,
            use_text_to_speech, tts_text, audio_file, enable_popup_animation
        ) VALUES (
            :name, :type, :module_type, :register_address, :channel_number, :relay_address,
            :upper_limit, :lower_limit, :range_value, :rated_value, :unit,
            :protection_delay, :play_mode, :play_count, :play_duration,
            :use_text_to_speech, :tts_text, :audio_file, :enable_popup_animation
        )
    )");

    query.bindValue(":name", name);
    query.bindValue(":type", config.type);
    query.bindValue(":module_type", config.moduleType);
    query.bindValue(":register_address", config.registerAddress);
    query.bindValue(":channel_number", config.channelNumber);
    query.bindValue(":relay_address", config.relayAddress);
    query.bindValue(":upper_limit", config.upperLimit);
    query.bindValue(":lower_limit", config.lowerLimit);
    query.bindValue(":range_value", config.range);
    query.bindValue(":rated_value", config.ratedValue);
    query.bindValue(":unit", config.unit);
    query.bindValue(":protection_delay", config.protectionDelay);
    query.bindValue(":play_mode", config.playMode);
    query.bindValue(":play_count", config.playCount);
    query.bindValue(":play_duration", config.playDuration);
    query.bindValue(":use_text_to_speech", config.useTextToSpeech ? 1 : 0);
    query.bindValue(":tts_text", config.ttsText);
    query.bindValue(":audio_file", config.audioFile);
    query.bindValue(":enable_popup_animation", config.enablePopupAnimation ? 1 : 0);

    if (!query.exec()) {
        emit databaseError("插入配置失败: " + query.lastError().text());
        return false;
    }

    emit configSaved(name);
    qDebug() << "保存配置成功:" << name;
    return true;
}

bool ProtectionConfigManager::updateConfig(const QString &name, const ProtectionConfig &config)
{
    QSqlQuery query(m_database);

    query.prepare(R"(
        UPDATE protection_configs SET
            type = :type,
            module_type = :module_type,
            register_address = :register_address,
            channel_number = :channel_number,
            relay_address = :relay_address,
            upper_limit = :upper_limit,
            lower_limit = :lower_limit,
            range_value = :range_value,
            rated_value = :rated_value,
            unit = :unit,
            protection_delay = :protection_delay,
            play_mode = :play_mode,
            play_count = :play_count,
            play_duration = :play_duration,
            use_text_to_speech = :use_text_to_speech,
            tts_text = :tts_text,
            audio_file = :audio_file,
            enable_popup_animation = :enable_popup_animation
        WHERE name = :name
    )");

    query.bindValue(":name", name);
    query.bindValue(":type", config.type);
    query.bindValue(":module_type", config.moduleType);
    query.bindValue(":register_address", config.registerAddress);
    query.bindValue(":channel_number", config.channelNumber);
    query.bindValue(":relay_address", config.relayAddress);
    query.bindValue(":upper_limit", config.upperLimit);
    query.bindValue(":lower_limit", config.lowerLimit);
    query.bindValue(":range_value", config.range);
    query.bindValue(":rated_value", config.ratedValue);
    query.bindValue(":unit", config.unit);
    query.bindValue(":protection_delay", config.protectionDelay);
    query.bindValue(":play_mode", config.playMode);
    query.bindValue(":play_count", config.playCount);
    query.bindValue(":play_duration", config.playDuration);
    query.bindValue(":use_text_to_speech", config.useTextToSpeech ? 1 : 0);
    query.bindValue(":tts_text", config.ttsText);
    query.bindValue(":audio_file", config.audioFile);
    query.bindValue(":enable_popup_animation", config.enablePopupAnimation ? 1 : 0);

    if (!query.exec()) {
        emit databaseError("更新配置失败: " + query.lastError().text());
        return false;
    }

    emit configSaved(name);
    qDebug() << "更新配置成功:" << name;
    return true;
}

ProtectionConfig ProtectionConfigManager::loadConfig(const QString &name)
{
    return queryConfig(name);
}

ProtectionConfig ProtectionConfigManager::queryConfig(const QString &name)
{
    QSqlQuery query(m_database);

    query.prepare("SELECT * FROM protection_configs WHERE name = :name");
    query.bindValue(":name", name);

    if (!query.exec() || !query.next()) {
        qWarning() << "查询配置失败:" << name << query.lastError().text();
        return ProtectionConfig();
    }

    ProtectionConfig config;
    config.name = query.value("name").toString();
    config.type = query.value("type").toString();
    config.moduleType = query.value("module_type").toString();
    config.registerAddress = query.value("register_address").toInt();
    config.channelNumber = query.value("channel_number").toInt();
    config.relayAddress = query.value("relay_address").toInt();
    config.upperLimit = query.value("upper_limit").toDouble();
    config.lowerLimit = query.value("lower_limit").toDouble();
    config.range = query.value("range_value").toDouble();
    config.ratedValue = query.value("rated_value").toDouble();
    config.unit = query.value("unit").toString();
    config.protectionDelay = query.value("protection_delay").toDouble();

    // 读取播放模式，如果为空则使用默认值
    QString playMode = query.value("play_mode").toString();
    if (playMode.isEmpty()) {
        playMode = "count";  // 默认按次数播放
        qDebug() << "  ⚠️ 配置" << name << "的播放模式为空，使用默认值: count";
    }
    config.playMode = playMode;

    // 读取播放次数，如果为0或旧默认值3则使用新默认值2
    int playCount = query.value("play_count").toInt();
    if (playCount == 0 || playCount == 3) {
        playCount = 2;  // 新默认值2次
        qDebug() << "  ⚠️ 配置" << name << "的播放次数为" << query.value("play_count").toInt()
                 << "，更新为默认值: 2";
    }
    config.playCount = playCount;

    config.playDuration = query.value("play_duration").toDouble();
    config.useTextToSpeech = query.value("use_text_to_speech").toInt() == 1;
    config.ttsText = query.value("tts_text").toString();
    config.audioFile = query.value("audio_file").toString();
    config.enablePopupAnimation = query.value("enable_popup_animation").toInt() == 1;

    emit configLoaded(name);
    return config;
}

QVariantMap ProtectionConfigManager::loadConfigAsMap(const QString &name)
{
    ProtectionConfig config = loadConfig(name);
    QVariantMap map;

    // 基本信息
    map["name"] = config.name;
    map["type"] = config.type;

    // 硬件配置
    map["moduleType"] = config.moduleType;
    map["registerAddress"] = config.registerAddress;
    map["channelNumber"] = config.channelNumber;
    map["relayAddress"] = config.relayAddress;

    // 模拟量参数
    map["upperLimit"] = config.upperLimit;
    map["lowerLimit"] = config.lowerLimit;
    map["range"] = config.range;
    map["ratedValue"] = config.ratedValue;
    map["unit"] = config.unit;

    // 报警参数
    map["protectionDelay"] = config.protectionDelay;
    map["playMode"] = config.playMode;
    map["playCount"] = config.playCount;
    map["playDuration"] = config.playDuration;

    // 语音报警配置
    map["useTextToSpeech"] = config.useTextToSpeech;
    map["ttsText"] = config.ttsText;
    map["audioFile"] = config.audioFile;

    // UI配置
    map["enablePopupAnimation"] = config.enablePopupAnimation;

    return map;
}

bool ProtectionConfigManager::saveConfigFromMap(const QString &name, const QVariantMap &configMap)
{
    ProtectionConfig config;

    // 基本信息
    config.name = configMap.value("name", name).toString();
    config.type = configMap.value("type", "analog").toString();

    // 硬件配置
    config.moduleType = configMap.value("moduleType", "模拟量模块1").toString();
    config.registerAddress = configMap.value("registerAddress", 5).toInt();
    config.channelNumber = configMap.value("channelNumber", 0).toInt();
    config.relayAddress = configMap.value("relayAddress", 50).toInt();

    // 模拟量参数
    config.upperLimit = configMap.value("upperLimit", 100.0).toDouble();
    config.lowerLimit = configMap.value("lowerLimit", 0.0).toDouble();
    config.range = configMap.value("range", 100.0).toDouble();
    config.ratedValue = configMap.value("ratedValue", 50.0).toDouble();
    config.unit = configMap.value("unit", "m/s").toString();

    // 报警参数
    config.protectionDelay = configMap.value("protectionDelay", 1.0).toDouble();
    config.playMode = configMap.value("playMode", "count").toString();
    config.playCount = configMap.value("playCount", 2).toInt();
    config.playDuration = configMap.value("playDuration", 5.0).toDouble();

    // 语音报警配置
    config.useTextToSpeech = configMap.value("useTextToSpeech", true).toBool();
    config.ttsText = configMap.value("ttsText", "").toString();
    config.audioFile = configMap.value("audioFile", "").toString();

    // UI配置
    config.enablePopupAnimation = configMap.value("enablePopupAnimation", true).toBool();

    return saveConfig(name, config);
}

bool ProtectionConfigManager::deleteConfig(const QString &name)
{
    QSqlQuery query(m_database);

    query.prepare("DELETE FROM protection_configs WHERE name = :name");
    query.bindValue(":name", name);

    if (!query.exec()) {
        emit databaseError("删除配置失败: " + query.lastError().text());
        return false;
    }

    emit configDeleted(name);
    qDebug() << "删除配置成功:" << name;
    return true;
}

QStringList ProtectionConfigManager::getAllProtectionNames()
{
    QStringList names;
    QSqlQuery query("SELECT name FROM protection_configs ORDER BY name", m_database);

    while (query.next()) {
        names << query.value(0).toString();
    }

    return names;
}

bool ProtectionConfigManager::configExists(const QString &name)
{
    QSqlQuery query(m_database);

    query.prepare("SELECT COUNT(*) FROM protection_configs WHERE name = :name");
    query.bindValue(":name", name);

    if (query.exec() && query.next()) {
        return query.value(0).toInt() > 0;
    }

    return false;
}

bool ProtectionConfigManager::saveAllConfigs(const QMap<QString, ProtectionConfig> &configs)
{
    m_database.transaction();

    for (auto it = configs.constBegin(); it != configs.constEnd(); ++it) {
        if (!saveConfig(it.key(), it.value())) {
            m_database.rollback();
            return false;
        }
    }

    m_database.commit();
    return true;
}

QMap<QString, ProtectionConfig> ProtectionConfigManager::loadAllConfigs()
{
    QMap<QString, ProtectionConfig> configs;
    QStringList names = getAllProtectionNames();

    for (const QString &name : names) {
        configs[name] = loadConfig(name);
    }

    return configs;
}

void ProtectionConfigManager::loadDefaultConfigs()
{
    qDebug() << "加载默认保护配置...";

    // 开关量保护 - 输入模块1, 寄存器2, 通道0-7
    saveConfig("急停", createDefaultDigitalConfig("急停", 0));
    saveConfig("跑偏", createDefaultDigitalConfig("跑偏", 1));
    saveConfig("撕裂", createDefaultDigitalConfig("撕裂", 2));
    saveConfig("烟雾", createDefaultDigitalConfig("烟雾", 3));
    saveConfig("温度", createDefaultDigitalConfig("温度", 4));
    saveConfig("护网", createDefaultDigitalConfig("护网", 5));
    saveConfig("堆煤", createDefaultDigitalConfig("堆煤", 6));
    saveConfig("主机急停", createDefaultDigitalConfig("主机急停", 7));

    // 模拟量保护 - 模拟量模块1 (寄存器5-12)
    saveConfig("速度", createDefaultAnalogConfig("速度", 5, "m/s"));
    saveConfig("张力", createDefaultAnalogConfig("张力", 6, "T"));
    saveConfig("红外温度一", createDefaultAnalogConfig("红外温度一", 7, "℃"));
    saveConfig("红外温度二", createDefaultAnalogConfig("红外温度二", 8, "℃"));
    saveConfig("电流一", createDefaultAnalogConfig("电流一", 9, "A"));
    saveConfig("电流二", createDefaultAnalogConfig("电流二", 10, "A"));
    saveConfig("电压", createDefaultAnalogConfig("电压", 11, "V"));
    saveConfig("1号电机温度", createDefaultAnalogConfig("1号电机温度", 12, "℃"));

    // 模拟量保护 - 模拟量模块2 (寄存器13-20)
    saveConfig("2号电机温度", createDefaultAnalogConfig("2号电机温度", 13, "℃"));
    saveConfig("1号电机X振动", createDefaultAnalogConfig("1号电机X振动", 14, "mm/s"));
    saveConfig("1号电机Y振动", createDefaultAnalogConfig("1号电机Y振动", 15, "mm/s"));
    saveConfig("2号电机X振动", createDefaultAnalogConfig("2号电机X振动", 16, "mm/s"));
    saveConfig("2号电机Y振动", createDefaultAnalogConfig("2号电机Y振动", 17, "mm/s"));
    saveConfig("1号电机第一项绕组", createDefaultAnalogConfig("1号电机第一项绕组", 18, "℃"));
    saveConfig("1号电机第二项绕组", createDefaultAnalogConfig("1号电机第二项绕组", 19, "℃"));
    saveConfig("1号电机第三项绕组", createDefaultAnalogConfig("1号电机第三项绕组", 20, "℃"));

    // 模拟量保护 - 模拟量模块3 (寄存器21-23)
    saveConfig("2号电机第一项绕组", createDefaultAnalogConfig("2号电机第一项绕组", 21, "℃"));
    saveConfig("2号电机第二项绕组", createDefaultAnalogConfig("2号电机第二项绕组", 22, "℃"));
    saveConfig("2号电机第三项绕组", createDefaultAnalogConfig("2号电机第三项绕组", 23, "℃"));

    qDebug() << "默认保护配置加载完成";
}

void ProtectionConfigManager::migrateAudioFilePaths()
{
    qDebug() << "🔄 开始迁移音频文件路径...";

    // 获取皮带号
    int beltNumber = (m_systemConfig != nullptr) ? m_systemConfig->machineNumber() : 1;
    QString folderName = QString("%1#PD").arg(beltNumber);

    // 需要修复的音频文件路径映射
    QMap<QString, QString> pathMigrations;
    pathMigrations["急停"] = QString("AUDIO/%1/沿线急停.mp3").arg(folderName);

    // 查询并更新每个需要迁移的配置
    int updatedCount = 0;
    for (auto it = pathMigrations.constBegin(); it != pathMigrations.constEnd(); ++it) {
        const QString &protectionName = it.key();
        const QString &newAudioPath = it.value();

        // 检查配置是否存在
        if (!configExists(protectionName)) {
            qDebug() << "  ⚠️ 保护配置不存在:" << protectionName;
            continue;
        }

        // 加载当前配置
        ProtectionConfig config = loadConfig(protectionName);

        // 检查是否需要更新
        if (config.audioFile == newAudioPath) {
            qDebug() << "  ✅" << protectionName << ": 音频路径已是最新，无需迁移";
            continue;
        }

        // 更新音频路径
        qDebug() << "  🔧" << protectionName << ": 更新音频路径";
        qDebug() << "     旧路径:" << config.audioFile;
        qDebug() << "     新路径:" << newAudioPath;

        config.audioFile = newAudioPath;

        // 保存到数据库
        if (saveConfig(protectionName, config)) {
            updatedCount++;
            qDebug() << "     ✅ 更新成功";
        } else {
            qWarning() << "     ❌ 更新失败";
        }
    }

    qDebug() << "✅ 音频文件路径迁移完成，共更新" << updatedCount << "个配置";
}

ProtectionConfig ProtectionConfigManager::createDefaultDigitalConfig(const QString &name, int channel)
{
    ProtectionConfig config(name, "digital");
    config.moduleType = "输入模块1";
    config.registerAddress = 2;
    config.channelNumber = channel;
    config.relayAddress = 50;
    config.protectionDelay = 1.0;
    config.playMode = "count";        // 默认按次数播放
    config.playCount = 2;             // 默认2遍
    config.playDuration = 5.0;
    config.useTextToSpeech = true;
    config.ttsText = name + "保护报警";

    // 获取皮带号（默认为1号）
    int beltNumber = (m_systemConfig != nullptr) ? m_systemConfig->machineNumber() : 1;
    QString folderName = QString("%1#PD").arg(beltNumber);

    // 特殊音频文件映射
    if (name == "急停") {
        config.audioFile = QString("AUDIO/%1/沿线急停.mp3").arg(folderName);
    } else {
        config.audioFile = QString("AUDIO/%1/%2.mp3").arg(folderName).arg(name);
    }

    config.enablePopupAnimation = true;

    return config;
}

ProtectionConfig ProtectionConfigManager::createDefaultAnalogConfig(const QString &name, int registerAddr, const QString &unit)
{
    ProtectionConfig config(name, "analog");

    // 根据寄存器地址确定模块类型
    if (registerAddr >= 5 && registerAddr <= 12) {
        config.moduleType = "模拟量模块1";
    } else if (registerAddr >= 13 && registerAddr <= 20) {
        config.moduleType = "模拟量模块2";
    } else if (registerAddr >= 21 && registerAddr <= 28) {
        config.moduleType = "模拟量模块3";
    } else {
        config.moduleType = "模拟量模块4";
    }

    config.registerAddress = registerAddr;
    config.relayAddress = 50;
    config.upperLimit = 100.0;
    config.lowerLimit = 0.0;
    config.range = 100.0;
    config.ratedValue = 50.0;
    config.unit = unit;
    config.protectionDelay = 1.0;
    config.playMode = "count";        // 默认按次数播放
    config.playCount = 2;             // 默认2遍
    config.playDuration = 5.0;
    config.useTextToSpeech = true;
    config.ttsText = name + "保护报警";
    config.audioFile = "AUDIO/DJ/" + name + ".mp3";
    config.enablePopupAnimation = true;

    return config;
}
