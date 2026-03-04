#include "DeviceConfigManager.h"
#include "DataPathConfig.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QSqlRecord>
#include <QVariant>
#include <QDebug>
#include <QDateTime>

// ✅ 2026-01-25 [设备参数永久存储] 设备配置管理器实现

DeviceConfigManager::DeviceConfigManager(QObject *parent)
    : QObject(parent)
{
}

DeviceConfigManager::~DeviceConfigManager()
{
    if (m_database.isOpen()) {
        m_database.close();
    }
}

// ========== 数据库初始化 ==========

bool DeviceConfigManager::initDatabase(const QString &dbPath)
{
    m_dbPath = dbPath;

    // 创建数据库连接
    m_database = QSqlDatabase::addDatabase("QSQLITE", "device_config_db");
    m_database.setDatabaseName(m_dbPath);

    if (!m_database.open()) {
        QString error = "无法打开设备配置数据库: " + m_database.lastError().text();
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    qDebug() << "✅ [DeviceConfigManager] 数据库连接成功:" << m_dbPath;

    // 创建表
    if (!createTables()) {
        return false;
    }

    // ✅ 2026-02-28 [Phase 7.47.52]: 运行数据库迁移（用于修复历史数据）
    runMigrations();

    // 初始化默认数据
    if (!initDefaultData()) {
        return false;
    }

    qDebug() << "✅ [DeviceConfigManager] 数据库初始化完成";
    return true;
}

bool DeviceConfigManager::createTables()
{
    QSqlQuery query(m_database);

    // 1. 设备表
    QString createDevicesTable = R"(
        CREATE TABLE IF NOT EXISTS devices (
            device_id INTEGER PRIMARY KEY,
            device_name TEXT NOT NULL,
            device_type TEXT DEFAULT 'belt',
            position_row INTEGER,
            position_col INTEGER,
            enabled BOOLEAN DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    )";

    if (!query.exec(createDevicesTable)) {
        QString error = "创建devices表失败: " + query.lastError().text();
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    // 创建索引
    query.exec("CREATE INDEX IF NOT EXISTS idx_devices_position ON devices(position_row, position_col)");

    // 2. 基本配置表
    QString createBasicConfigTable = R"(
        CREATE TABLE IF NOT EXISTS device_basic_config (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER NOT NULL,
            param_name TEXT NOT NULL,
            param_value TEXT,
            param_type TEXT DEFAULT 'string',
            description TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE,
            UNIQUE(device_id, param_name)
        )
    )";

    if (!query.exec(createBasicConfigTable)) {
        QString error = "创建device_basic_config表失败: " + query.lastError().text();
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    query.exec("CREATE INDEX IF NOT EXISTS idx_basic_config_device ON device_basic_config(device_id)");

    // 3. 开关量保护表
    QString createDigitalProtectionsTable = R"(
        CREATE TABLE IF NOT EXISTS device_digital_protections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER NOT NULL,
            protection_name TEXT NOT NULL,
            active BOOLEAN DEFAULT 0,
            module_type TEXT DEFAULT '输入模块1',
            register_address INTEGER DEFAULT 2,
            channel_number INTEGER DEFAULT 0,
            protection_delay REAL DEFAULT 1.0,
            play_count INTEGER DEFAULT 3,
            play_duration REAL DEFAULT 5.0,
            // ✅ 2026-02-28 [Phase 7.47.52]: 默认改为0（默认音频），旧值1导致新建保护默认TTS
            use_text_to_speech BOOLEAN DEFAULT 0,
            tts_text TEXT,
            audio_file TEXT,
            enabled BOOLEAN DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE,
            UNIQUE(device_id, protection_name)
        )
    )";

    if (!query.exec(createDigitalProtectionsTable)) {
        QString error = "创建device_digital_protections表失败: " + query.lastError().text();
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    query.exec("CREATE INDEX IF NOT EXISTS idx_digital_protections_device ON device_digital_protections(device_id)");
    query.exec("CREATE INDEX IF NOT EXISTS idx_digital_protections_active ON device_digital_protections(active)");

    // ✅ 2026-03-04 [Phase 7.47.94]: 迁移 - 添加 play_mode 列（已有数据库不会重建表，需要 ALTER TABLE）
    // SQLite 的 ALTER TABLE 对已存在的列会报错但不影响，直接忽略错误即可
    query.exec("ALTER TABLE device_digital_protections ADD COLUMN play_mode TEXT DEFAULT 'count'");

    // 4. 模拟量保护表
    QString createAnalogProtectionsTable = R"(
        CREATE TABLE IF NOT EXISTS device_analog_protections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER NOT NULL,
            protection_name TEXT NOT NULL,
            active BOOLEAN DEFAULT 0,
            current_value REAL DEFAULT 0.0,
            module_type TEXT DEFAULT '模拟量模块1',
            register_address INTEGER DEFAULT 5,
            upper_limit REAL DEFAULT 100.0,
            lower_limit REAL DEFAULT 0.0,
            range_value REAL DEFAULT 100.0,
            rated_value REAL DEFAULT 50.0,
            unit TEXT DEFAULT 'm/s',
            protection_delay REAL DEFAULT 1.0,
            play_count INTEGER DEFAULT 3,
            play_duration REAL DEFAULT 5.0,
            // ✅ 2026-02-28 [Phase 7.47.52]: 默认改为0（默认音频）
            use_text_to_speech BOOLEAN DEFAULT 0,
            tts_text TEXT,
            audio_file TEXT,
            enabled BOOLEAN DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE,
            UNIQUE(device_id, protection_name)
        )
    )";

    if (!query.exec(createAnalogProtectionsTable)) {
        QString error = "创建device_analog_protections表失败: " + query.lastError().text();
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    query.exec("CREATE INDEX IF NOT EXISTS idx_analog_protections_device ON device_analog_protections(device_id)");
    query.exec("CREATE INDEX IF NOT EXISTS idx_analog_protections_active ON device_analog_protections(active)");

    // ✅ 2026-03-04 [Phase 7.47.94]: 迁移 - 添加 play_mode 列（与开关量保护表一致）
    query.exec("ALTER TABLE device_analog_protections ADD COLUMN play_mode TEXT DEFAULT 'count'");

    // ✅ 2026-02-02 [参数持久化]: 添加电机配置表
    // 5. 电机配置表
    QString createMotorConfigTable = R"(
        CREATE TABLE IF NOT EXISTS device_motor_config (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER NOT NULL,
            motor_index INTEGER NOT NULL,
            tab_index INTEGER NOT NULL,
            tab_name TEXT NOT NULL,
            protection_name TEXT,
            protection_delay INTEGER DEFAULT 0,
            upper_limit REAL,
            lower_limit REAL,
            unit TEXT,
            voice_alarm_enabled BOOLEAN DEFAULT 0,
            voice_alarm_type TEXT DEFAULT 'tts',
            tts_text TEXT,
            audio_file TEXT,
            play_count INTEGER DEFAULT 1,
            play_duration INTEGER DEFAULT 5,
            enabled BOOLEAN DEFAULT 1,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE,
            UNIQUE(device_id, motor_index, tab_index)
        )
    )";

    if (!query.exec(createMotorConfigTable)) {
        QString error = "创建device_motor_config表失败: " + query.lastError().text();
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    query.exec("CREATE INDEX IF NOT EXISTS idx_motor_config_device ON device_motor_config(device_id)");
    query.exec("CREATE INDEX IF NOT EXISTS idx_motor_config_motor ON device_motor_config(device_id, motor_index)");

    // ✅ 2026-02-02 [参数持久化]: 添加制动器配置表
    // 6. 制动器配置表
    QString createBrakeConfigTable = R"(
        CREATE TABLE IF NOT EXISTS device_brake_config (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER NOT NULL,
            brake_index INTEGER NOT NULL,
            brake_name TEXT,
            brake_delay INTEGER DEFAULT 0,
            brake_force REAL,
            temperature_upper_limit REAL,
            temperature_lower_limit REAL,
            pressure_upper_limit REAL,
            pressure_lower_limit REAL,
            voice_alarm_enabled BOOLEAN DEFAULT 0,
            voice_alarm_type TEXT DEFAULT 'tts',
            tts_text TEXT,
            audio_file TEXT,
            play_count INTEGER DEFAULT 1,
            play_duration INTEGER DEFAULT 5,
            enabled BOOLEAN DEFAULT 1,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE,
            UNIQUE(device_id, brake_index)
        )
    )";

    if (!query.exec(createBrakeConfigTable)) {
        QString error = "创建device_brake_config表失败: " + query.lastError().text();
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    query.exec("CREATE INDEX IF NOT EXISTS idx_brake_config_device ON device_brake_config(device_id)");

    // ✅ 2026-02-02 [参数持久化]: 添加张紧控制配置表
    // 7. 张紧控制配置表
    QString createTensionConfigTable = R"(
        CREATE TABLE IF NOT EXISTS device_tension_config (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER NOT NULL,
            tension_index INTEGER NOT NULL,
            tension_name TEXT,
            tension_force REAL,
            position_upper_limit REAL,
            position_lower_limit REAL,
            pressure_upper_limit REAL,
            pressure_lower_limit REAL,
            temperature_upper_limit REAL,
            temperature_lower_limit REAL,
            voice_alarm_enabled BOOLEAN DEFAULT 0,
            voice_alarm_type TEXT DEFAULT 'tts',
            tts_text TEXT,
            audio_file TEXT,
            play_count INTEGER DEFAULT 1,
            play_duration INTEGER DEFAULT 5,
            enabled BOOLEAN DEFAULT 1,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE,
            UNIQUE(device_id, tension_index)
        )
    )";

    if (!query.exec(createTensionConfigTable)) {
        QString error = "创建device_tension_config表失败: " + query.lastError().text();
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    query.exec("CREATE INDEX IF NOT EXISTS idx_tension_config_device ON device_tension_config(device_id)");

    qDebug() << "✅ [DeviceConfigManager] 数据库表创建成功（包含电机/制动器/张紧控制表）";
    return true;
}

// ✅ 2026-02-28 [Phase 7.47.52]: 数据库迁移 - 修复历史数据
// 原因：建表时 use_text_to_speech DEFAULT 1，导致所有旧记录默认为TTS合成
// 修复：将所有 use_text_to_speech=1 的记录重置为 0（默认音频）
void DeviceConfigManager::runMigrations()
{
    QSqlQuery query(m_database);

    // 检查是否已执行过此迁移（用 schema_migrations 表记录）
    if (!query.exec(R"(
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version TEXT PRIMARY KEY,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    )")) {
        qWarning() << "⚠️ [DeviceConfigManager] 创建 schema_migrations 表失败:" << query.lastError().text();
    }

    // 迁移 001：将 use_text_to_speech 默认值从 1 改为 0（开关量保护）
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 001（开关量保护）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '001_reset_audio_source_digital'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        QSqlQuery fix(m_database);
        if (fix.exec("UPDATE device_digital_protections SET use_text_to_speech = 0 WHERE use_text_to_speech = 1")) {
            int affected = fix.numRowsAffected();
            qDebug() << "✅ [DeviceConfigManager] 迁移001: 重置" << affected << "条开关量保护的音频来源为默认(0)";
            query.exec("INSERT INTO schema_migrations (version) VALUES ('001_reset_audio_source_digital')");
        } else {
            qWarning() << "⚠️ [DeviceConfigManager] 迁移001(开关量)失败:" << fix.lastError().text();
        }
    } else if (!query.exec()) {
        qWarning() << "⚠️ [DeviceConfigManager] 迁移001查询失败:" << query.lastError().text();
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移001已执行过，跳过";
    }

    // 迁移 002：将 use_text_to_speech 默认值从 1 改为 0（模拟量保护）
    // ✅ 2026-02-28 [Phase 7.47.53]: 新增 - 也需要修复模拟量保护
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 002（模拟量保护）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '002_reset_audio_source_analog'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        QSqlQuery fix(m_database);
        if (fix.exec("UPDATE device_analog_protections SET use_text_to_speech = 0 WHERE use_text_to_speech = 1")) {
            int affected = fix.numRowsAffected();
            qDebug() << "✅ [DeviceConfigManager] 迁移002: 重置" << affected << "条模拟量保护的音频来源为默认(0)";
            query.exec("INSERT INTO schema_migrations (version) VALUES ('002_reset_audio_source_analog')");
        } else {
            qWarning() << "⚠️ [DeviceConfigManager] 迁移002(模拟量)失败:" << fix.lastError().text();
        }
    } else if (!query.exec()) {
        qWarning() << "⚠️ [DeviceConfigManager] 迁移002查询失败:" << query.lastError().text();
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移002已执行过，跳过";
    }
}

bool DeviceConfigManager::initDefaultData()
{
    // 检查是否已初始化
    QSqlQuery query(m_database);
    query.prepare("SELECT COUNT(*) FROM devices");
    if (!query.exec() || !query.next() || query.value(0).toInt() > 0) {
        qDebug() << "⏭️ [DeviceConfigManager] 数据已初始化，跳过";
        return true;  // 已初始化，跳过
    }

    qDebug() << "🔄 [DeviceConfigManager] 开始初始化12个设备的默认数据...";

    // 初始化12个设备
    for (int i = 1; i <= 12; i++) {
        int row = (i - 1) / 3;  // 0-3
        int col = (i - 1) % 3;  // 0-2
        QString deviceName = QString("%1号皮带").arg(i);

        query.prepare("INSERT INTO devices (device_id, device_name, position_row, position_col) "
                      "VALUES (?, ?, ?, ?)");
        query.addBindValue(i);
        query.addBindValue(deviceName);
        query.addBindValue(row);
        query.addBindValue(col);

        if (!query.exec()) {
            QString error = QString("初始化设备%1失败: %2").arg(i).arg(query.lastError().text());
            qCritical() << error;
            emit databaseError(error);
            return false;
        }

        qDebug() << QString("  ✅ 设备%1: %2 (行%3, 列%4)").arg(i).arg(deviceName).arg(row).arg(col);

        // 初始化默认的开关量保护
        if (!initDefaultDigitalProtections(i)) {
            return false;
        }

        // 初始化默认的模拟量保护
        if (!initDefaultAnalogProtections(i)) {
            return false;
        }

        // ✅ 2026-02-02 [参数持久化]: 初始化电机/制动器/张紧控制配置
        // 初始化默认的电机配置
        if (!initDefaultMotorConfigs(i)) {
            return false;
        }

        // 初始化默认的制动器配置
        if (!initDefaultBrakeConfigs(i)) {
            return false;
        }

        // 初始化默认的张紧控制配置
        if (!initDefaultTensionConfigs(i)) {
            return false;
        }
    }

    qDebug() << "✅ [DeviceConfigManager] 12个设备初始化完成（包含电机/制动器/张紧控制）";
    return true;
}

bool DeviceConfigManager::initDefaultDigitalProtections(int deviceId)
{
    // 8个默认开关量保护
    QStringList protectionNames = {
        "急停", "跑偏", "撕裂", "烟雾", "温度", "护网", "堆煤", "主机急停"
    };

    QSqlQuery query(m_database);
    for (int i = 0; i < protectionNames.size(); i++) {
        QString name = protectionNames[i];
        // ✅ 2026-02-28 [Phase 7.47.53]: 修复 - 添加 use_text_to_speech = 0（默认为默认音频）
        // 旧代码：不指定 use_text_to_speech，导致使用表的DEFAULT值（旧版本DEFAULT为1，导致新建保护默认为TTS）
        // 新代码：显式设置为0，确保新建的所有保护默认使用默认音频
        query.prepare(R"(
            INSERT INTO device_digital_protections
            (device_id, protection_name, module_type, register_address, channel_number, tts_text, use_text_to_speech)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        )");
        query.addBindValue(deviceId);
        query.addBindValue(name);
        query.addBindValue("输入模块1");
        query.addBindValue(2);
        query.addBindValue(i);  // 通道编号 0-7
        query.addBindValue(name + "保护报警");
        query.addBindValue(0);  // ✅ 默认为0（使用默认音频）

        if (!query.exec()) {
            QString error = QString("初始化设备%1的开关量保护'%2'失败: %3")
                .arg(deviceId).arg(name).arg(query.lastError().text());
            qCritical() << error;
            emit databaseError(error);
            return false;
        }
    }

    return true;
}

bool DeviceConfigManager::initDefaultAnalogProtections(int deviceId)
{
    // 7个主要模拟量保护（可根据需要扩展）
    struct AnalogProtection {
        QString name;
        QString unit;
        int registerAddress;
        double upperLimit;
        double lowerLimit;
        double range;
        double rated;
    };

    QList<AnalogProtection> protections = {
        {"速度", "m/s", 5, 3.0, 0.0, 3.0, 2.5},
        {"张力", "T", 6, 100.0, 0.0, 100.0, 50.0},
        {"红外温度一", "℃", 7, 80.0, 0.0, 100.0, 40.0},
        {"红外温度二", "℃", 8, 80.0, 0.0, 100.0, 40.0},
        {"电流一", "A", 9, 100.0, 0.0, 100.0, 50.0},
        {"电流二", "A", 10, 100.0, 0.0, 100.0, 50.0},
        {"电压", "V", 11, 500.0, 0.0, 500.0, 380.0}
    };

    QSqlQuery query(m_database);
    for (const auto &p : protections) {
        // ✅ 2026-02-28 [Phase 7.47.53]: 修复 - 添加 use_text_to_speech = 0（默认为默认音频）
        // 与initDefaultDigitalProtections保持一致
        query.prepare(R"(
            INSERT INTO device_analog_protections
            (device_id, protection_name, module_type, register_address, unit,
             upper_limit, lower_limit, range_value, rated_value, tts_text, use_text_to_speech)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        )");
        query.addBindValue(deviceId);
        query.addBindValue(p.name);
        query.addBindValue("模拟量模块1");
        query.addBindValue(p.registerAddress);
        query.addBindValue(p.unit);
        query.addBindValue(p.upperLimit);
        query.addBindValue(p.lowerLimit);
        query.addBindValue(p.range);
        query.addBindValue(p.rated);
        query.addBindValue(p.name + "保护报警");
        query.addBindValue(0);  // ✅ 默认为0（使用默认音频）

        if (!query.exec()) {
            QString error = QString("初始化设备%1的模拟量保护'%2'失败: %3")
                .arg(deviceId).arg(p.name).arg(query.lastError().text());
            qCritical() << error;
            emit databaseError(error);
            return false;
        }
    }

    return true;
}

// ========== 设备管理 ==========

bool DeviceConfigManager::saveDevice(int deviceId, const QString &deviceName)
{
    QSqlQuery query(m_database);
    query.prepare("UPDATE devices SET device_name = ?, updated_at = ? WHERE device_id = ?");
    query.addBindValue(deviceName);
    query.addBindValue(QDateTime::currentDateTime());
    query.addBindValue(deviceId);

    if (!query.exec()) {
        QString error = QString("保存设备%1失败: %2").arg(deviceId).arg(query.lastError().text());
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    emit deviceConfigChanged(deviceId);
    return true;
}

QVariantMap DeviceConfigManager::loadDevice(int deviceId)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM devices WHERE device_id = ?");
    query.addBindValue(deviceId);

    if (!query.exec() || !query.next()) {
        qWarning() << "加载设备" << deviceId << "失败:" << query.lastError().text();
        return QVariantMap();
    }

    return queryToMap(query);
}

QVariantList DeviceConfigManager::loadAllDevices()
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM devices ORDER BY device_id");

    if (!query.exec()) {
        qWarning() << "加载所有设备失败:" << query.lastError().text();
        return QVariantList();
    }

    return queryToList(query);
}

// ========== 基本配置 ==========

bool DeviceConfigManager::saveBasicConfig(int deviceId, const QString &paramName, const QVariant &value)
{
    QSqlQuery query(m_database);

    // 使用 INSERT OR REPLACE 语法
    query.prepare(R"(
        INSERT OR REPLACE INTO device_basic_config
        (device_id, param_name, param_value, updated_at)
        VALUES (?, ?, ?, ?)
    )");
    query.addBindValue(deviceId);
    query.addBindValue(paramName);
    query.addBindValue(value.toString());
    query.addBindValue(QDateTime::currentDateTime());

    if (!query.exec()) {
        QString error = QString("保存设备%1的参数'%2'失败: %3")
            .arg(deviceId).arg(paramName).arg(query.lastError().text());
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    emit deviceConfigChanged(deviceId);
    return true;
}

QVariant DeviceConfigManager::loadBasicConfig(int deviceId, const QString &paramName)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT param_value FROM device_basic_config WHERE device_id = ? AND param_name = ?");
    query.addBindValue(deviceId);
    query.addBindValue(paramName);

    if (!query.exec() || !query.next()) {
        return QVariant();
    }

    return query.value(0);
}

QVariantMap DeviceConfigManager::loadAllBasicConfig(int deviceId)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT param_name, param_value FROM device_basic_config WHERE device_id = ?");
    query.addBindValue(deviceId);

    if (!query.exec()) {
        qWarning() << "加载设备" << deviceId << "的基本配置失败:" << query.lastError().text();
        return QVariantMap();
    }

    QVariantMap config;
    while (query.next()) {
        config[query.value(0).toString()] = query.value(1);
    }

    return config;
}

// ========== 开关量保护 ==========

bool DeviceConfigManager::saveDigitalProtection(int deviceId, const QVariantMap &protection)
{
    QString protectionName = protection.value("protection_name").toString();
    if (protectionName.isEmpty()) {
        protectionName = protection.value("name").toString();
    }

    if (protectionName.isEmpty()) {
        qWarning() << "保护名称为空，无法保存";
        return false;
    }

    QSqlQuery query(m_database);
    query.prepare(R"(
        INSERT OR REPLACE INTO device_digital_protections
        (device_id, protection_name, module_type, register_address, channel_number,
         protection_delay, play_count, play_duration, use_text_to_speech, tts_text, audio_file,
         play_mode, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    )");

    query.addBindValue(deviceId);
    query.addBindValue(protectionName);
    query.addBindValue(protection.value("module_type", "输入模块1").toString());
    query.addBindValue(protection.value("register_address", 2).toInt());
    query.addBindValue(protection.value("channel_number", 0).toInt());
    query.addBindValue(protection.value("protection_delay", 1.0).toDouble());
    query.addBindValue(protection.value("play_count", 3).toInt());
    query.addBindValue(protection.value("play_duration", 5.0).toDouble());
    // ✅ 2026-02-28 [Phase 7.47.52]: 默认改为false（默认音频），旧值true导致新建保护默认TTS
    // 旧：protection.value("use_text_to_speech", true).toBool() ? 1 : 0
    query.addBindValue(protection.value("use_text_to_speech", false).toBool() ? 1 : 0);
    query.addBindValue(protection.value("tts_text", protectionName + "保护报警").toString());
    query.addBindValue(protection.value("audio_file", "").toString());
    // ✅ 2026-03-04 [Phase 7.47.94]: 新增播放方式字段（count=按次数, duration=按时长）
    query.addBindValue(protection.value("play_mode", "count").toString());
    query.addBindValue(QDateTime::currentDateTime());

    if (!query.exec()) {
        QString error = QString("保存设备%1的开关量保护'%2'失败: %3")
            .arg(deviceId).arg(protectionName).arg(query.lastError().text());
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    qDebug() << "✅ [DeviceConfigManager] 保存开关量保护:" << deviceId << protectionName;
    emit deviceConfigChanged(deviceId);
    return true;
}

QVariantMap DeviceConfigManager::loadDigitalProtection(int deviceId, const QString &protectionName)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM device_digital_protections WHERE device_id = ? AND protection_name = ?");
    query.addBindValue(deviceId);
    query.addBindValue(protectionName);

    if (!query.exec() || !query.next()) {
        qWarning() << "加载设备" << deviceId << "的开关量保护" << protectionName << "失败";
        return QVariantMap();
    }

    return queryToMap(query);
}

QVariantList DeviceConfigManager::loadAllDigitalProtections(int deviceId)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM device_digital_protections WHERE device_id = ? ORDER BY channel_number");
    query.addBindValue(deviceId);

    if (!query.exec()) {
        qWarning() << "加载设备" << deviceId << "的所有开关量保护失败:" << query.lastError().text();
        return QVariantList();
    }

    return queryToList(query);
}

bool DeviceConfigManager::deleteDigitalProtection(int deviceId, const QString &protectionName)
{
    QSqlQuery query(m_database);
    query.prepare("DELETE FROM device_digital_protections WHERE device_id = ? AND protection_name = ?");
    query.addBindValue(deviceId);
    query.addBindValue(protectionName);

    if (!query.exec()) {
        QString error = QString("删除设备%1的开关量保护'%2'失败: %3")
            .arg(deviceId).arg(protectionName).arg(query.lastError().text());
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    emit deviceConfigChanged(deviceId);
    return true;
}

// ========== 模拟量保护 ==========

bool DeviceConfigManager::saveAnalogProtection(int deviceId, const QVariantMap &protection)
{
    QString protectionName = protection.value("protection_name").toString();
    if (protectionName.isEmpty()) {
        protectionName = protection.value("name").toString();
    }

    if (protectionName.isEmpty()) {
        qWarning() << "保护名称为空，无法保存";
        return false;
    }

    QSqlQuery query(m_database);
    query.prepare(R"(
        INSERT OR REPLACE INTO device_analog_protections
        (device_id, protection_name, module_type, register_address, unit,
         upper_limit, lower_limit, range_value, rated_value,
         protection_delay, play_count, play_duration, use_text_to_speech, tts_text, audio_file, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    )");

    query.addBindValue(deviceId);
    query.addBindValue(protectionName);
    query.addBindValue(protection.value("module_type", "模拟量模块1").toString());
    query.addBindValue(protection.value("register_address", 5).toInt());
    query.addBindValue(protection.value("unit", "m/s").toString());
    query.addBindValue(protection.value("upper_limit", 100.0).toDouble());
    query.addBindValue(protection.value("lower_limit", 0.0).toDouble());
    query.addBindValue(protection.value("range_value", 100.0).toDouble());
    query.addBindValue(protection.value("rated_value", 50.0).toDouble());
    query.addBindValue(protection.value("protection_delay", 1.0).toDouble());
    query.addBindValue(protection.value("play_count", 3).toInt());
    query.addBindValue(protection.value("play_duration", 5.0).toDouble());
    // ✅ 2026-02-28 [Phase 7.47.52]: 默认改为false（默认音频）
    // 旧：protection.value("use_text_to_speech", true).toBool() ? 1 : 0
    query.addBindValue(protection.value("use_text_to_speech", false).toBool() ? 1 : 0);
    query.addBindValue(protection.value("tts_text", protectionName + "保护报警").toString());
    query.addBindValue(protection.value("audio_file", "").toString());
    query.addBindValue(QDateTime::currentDateTime());

    if (!query.exec()) {
        QString error = QString("保存设备%1的模拟量保护'%2'失败: %3")
            .arg(deviceId).arg(protectionName).arg(query.lastError().text());
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    qDebug() << "✅ [DeviceConfigManager] 保存模拟量保护:" << deviceId << protectionName;
    emit deviceConfigChanged(deviceId);
    return true;
}

QVariantMap DeviceConfigManager::loadAnalogProtection(int deviceId, const QString &protectionName)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM device_analog_protections WHERE device_id = ? AND protection_name = ?");
    query.addBindValue(deviceId);
    query.addBindValue(protectionName);

    if (!query.exec() || !query.next()) {
        qWarning() << "加载设备" << deviceId << "的模拟量保护" << protectionName << "失败";
        return QVariantMap();
    }

    return queryToMap(query);
}

QVariantList DeviceConfigManager::loadAllAnalogProtections(int deviceId)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM device_analog_protections WHERE device_id = ? ORDER BY register_address");
    query.addBindValue(deviceId);

    if (!query.exec()) {
        qWarning() << "加载设备" << deviceId << "的所有模拟量保护失败:" << query.lastError().text();
        return QVariantList();
    }

    return queryToList(query);
}

bool DeviceConfigManager::deleteAnalogProtection(int deviceId, const QString &protectionName)
{
    QSqlQuery query(m_database);
    query.prepare("DELETE FROM device_analog_protections WHERE device_id = ? AND protection_name = ?");
    query.addBindValue(deviceId);
    query.addBindValue(protectionName);

    if (!query.exec()) {
        QString error = QString("删除设备%1的模拟量保护'%2'失败: %3")
            .arg(deviceId).arg(protectionName).arg(query.lastError().text());
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    emit deviceConfigChanged(deviceId);
    return true;
}

// ========== 实时状态更新 ==========

bool DeviceConfigManager::updateProtectionActive(int deviceId, const QString &protectionName, bool active)
{
    // 尝试更新开关量保护
    QSqlQuery query(m_database);
    query.prepare("UPDATE device_digital_protections SET active = ? WHERE device_id = ? AND protection_name = ?");
    query.addBindValue(active ? 1 : 0);
    query.addBindValue(deviceId);
    query.addBindValue(protectionName);

    if (query.exec() && query.numRowsAffected() > 0) {
        emit protectionActiveChanged(deviceId, protectionName, active);
        return true;
    }

    // 尝试更新模拟量保护
    query.prepare("UPDATE device_analog_protections SET active = ? WHERE device_id = ? AND protection_name = ?");
    query.addBindValue(active ? 1 : 0);
    query.addBindValue(deviceId);
    query.addBindValue(protectionName);

    if (query.exec() && query.numRowsAffected() > 0) {
        emit protectionActiveChanged(deviceId, protectionName, active);
        return true;
    }

    qWarning() << "更新保护激活状态失败:" << deviceId << protectionName;
    return false;
}

bool DeviceConfigManager::updateAnalogValue(int deviceId, const QString &protectionName, double value)
{
    QSqlQuery query(m_database);
    query.prepare("UPDATE device_analog_protections SET current_value = ? WHERE device_id = ? AND protection_name = ?");
    query.addBindValue(value);
    query.addBindValue(deviceId);
    query.addBindValue(protectionName);

    if (!query.exec()) {
        qWarning() << "更新模拟量值失败:" << deviceId << protectionName << query.lastError().text();
        return false;
    }

    emit analogValueChanged(deviceId, protectionName, value);
    return true;
}

// ========== 辅助函数 ==========

bool DeviceConfigManager::executeQuery(const QString &queryStr, const QVariantList &params)
{
    QSqlQuery query(m_database);
    query.prepare(queryStr);

    for (const QVariant &param : params) {
        query.addBindValue(param);
    }

    if (!query.exec()) {
        QString error = "SQL执行失败: " + query.lastError().text();
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    return true;
}

QVariantMap DeviceConfigManager::queryToMap(QSqlQuery &query)
{
    QVariantMap map;
    QSqlRecord record = query.record();

    for (int i = 0; i < record.count(); i++) {
        QString fieldName = record.fieldName(i);
        QVariant value = query.value(i);
        map[fieldName] = value;
    }

    return map;
}

QVariantList DeviceConfigManager::queryToList(QSqlQuery &query)
{
    QVariantList list;

    while (query.next()) {
        QVariantMap map;
        QSqlRecord record = query.record();

        for (int i = 0; i < record.count(); i++) {
            QString fieldName = record.fieldName(i);
            QVariant value = query.value(i);
            map[fieldName] = value;
        }

        list.append(map);
    }

    return list;
}

// ========== 电机配置 ==========
// ✅ 2026-02-02 [参数持久化]: 实现电机配置管理方法

bool DeviceConfigManager::saveMotorConfig(int deviceId, int motorIndex, int tabIndex, const QVariantMap &config)
{
    QSqlQuery query(m_database);
    query.prepare(R"(
        INSERT OR REPLACE INTO device_motor_config
        (device_id, motor_index, tab_index, tab_name, protection_name, protection_delay,
         upper_limit, lower_limit, unit, voice_alarm_enabled, voice_alarm_type,
         tts_text, audio_file, play_count, play_duration, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    )");

    query.addBindValue(deviceId);
    query.addBindValue(motorIndex);
    query.addBindValue(tabIndex);
    query.addBindValue(config.value("tab_name", "").toString());
    query.addBindValue(config.value("protection_name", "").toString());
    query.addBindValue(config.value("protection_delay", 0).toInt());
    query.addBindValue(config.value("upper_limit", 0.0).toDouble());
    query.addBindValue(config.value("lower_limit", 0.0).toDouble());
    query.addBindValue(config.value("unit", "").toString());
    query.addBindValue(config.value("voice_alarm_enabled", false).toBool() ? 1 : 0);
    query.addBindValue(config.value("voice_alarm_type", "tts").toString());
    query.addBindValue(config.value("tts_text", "").toString());
    query.addBindValue(config.value("audio_file", "").toString());
    query.addBindValue(config.value("play_count", 1).toInt());
    query.addBindValue(config.value("play_duration", 5).toInt());
    query.addBindValue(QDateTime::currentDateTime());

    if (!query.exec()) {
        QString error = QString("保存设备%1电机%2 Tab%3配置失败: %4")
            .arg(deviceId).arg(motorIndex).arg(tabIndex).arg(query.lastError().text());
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    qDebug() << "✅ [DeviceConfigManager] 保存电机配置:" << deviceId << motorIndex << tabIndex;
    emit deviceConfigChanged(deviceId);
    return true;
}

QVariantMap DeviceConfigManager::loadMotorConfig(int deviceId, int motorIndex, int tabIndex)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM device_motor_config WHERE device_id = ? AND motor_index = ? AND tab_index = ?");
    query.addBindValue(deviceId);
    query.addBindValue(motorIndex);
    query.addBindValue(tabIndex);

    if (!query.exec() || !query.next()) {
        qWarning() << "加载设备" << deviceId << "电机" << motorIndex << "Tab" << tabIndex << "配置失败";
        return QVariantMap();
    }

    return queryToMap(query);
}

QVariantList DeviceConfigManager::loadAllMotorConfigs(int deviceId, int motorIndex)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM device_motor_config WHERE device_id = ? AND motor_index = ? ORDER BY tab_index");
    query.addBindValue(deviceId);
    query.addBindValue(motorIndex);

    if (!query.exec()) {
        qWarning() << "加载设备" << deviceId << "电机" << motorIndex << "所有配置失败:" << query.lastError().text();
        return QVariantList();
    }

    return queryToList(query);
}

bool DeviceConfigManager::initDefaultMotorConfigs(int deviceId)
{
    // 8个电机，每个电机10个Tab
    QStringList tabNames = {
        "基本配置", "电流保护", "前轴承温度", "后轴承温度", "A相绕组",
        "B相绕组", "C相绕组", "电机温度", "X轴振动", "Y轴振动"
    };

    QSqlQuery query(m_database);
    for (int motorIndex = 0; motorIndex < 8; motorIndex++) {
        for (int tabIndex = 0; tabIndex < tabNames.size(); tabIndex++) {
            QString tabName = tabNames[tabIndex];
            QString protectionName = QString("电机%1-%2").arg(motorIndex + 1).arg(tabName);

            query.prepare(R"(
                INSERT INTO device_motor_config
                (device_id, motor_index, tab_index, tab_name, protection_name, upper_limit, lower_limit, unit, tts_text)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            )");
            query.addBindValue(deviceId);
            query.addBindValue(motorIndex);
            query.addBindValue(tabIndex);
            query.addBindValue(tabName);
            query.addBindValue(protectionName);
            query.addBindValue(100.0);  // 默认上限
            query.addBindValue(0.0);    // 默认下限
            query.addBindValue("A");    // 默认单位
            query.addBindValue(protectionName + "报警");

            if (!query.exec()) {
                QString error = QString("初始化设备%1电机%2 Tab%3配置失败: %4")
                    .arg(deviceId).arg(motorIndex).arg(tabIndex).arg(query.lastError().text());
                qCritical() << error;
                emit databaseError(error);
                return false;
            }
        }
    }

    return true;
}

// ========== 制动器配置 ==========
// ✅ 2026-02-02 [参数持久化]: 实现制动器配置管理方法

bool DeviceConfigManager::saveBrakeConfig(int deviceId, int brakeIndex, const QVariantMap &config)
{
    QSqlQuery query(m_database);
    query.prepare(R"(
        INSERT OR REPLACE INTO device_brake_config
        (device_id, brake_index, brake_name, brake_delay, brake_force,
         temperature_upper_limit, temperature_lower_limit, pressure_upper_limit, pressure_lower_limit,
         voice_alarm_enabled, voice_alarm_type, tts_text, audio_file, play_count, play_duration, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    )");

    query.addBindValue(deviceId);
    query.addBindValue(brakeIndex);
    query.addBindValue(config.value("brake_name", "").toString());
    query.addBindValue(config.value("brake_delay", 0).toInt());
    query.addBindValue(config.value("brake_force", 0.0).toDouble());
    query.addBindValue(config.value("temperature_upper_limit", 80.0).toDouble());
    query.addBindValue(config.value("temperature_lower_limit", 0.0).toDouble());
    query.addBindValue(config.value("pressure_upper_limit", 10.0).toDouble());
    query.addBindValue(config.value("pressure_lower_limit", 0.0).toDouble());
    query.addBindValue(config.value("voice_alarm_enabled", false).toBool() ? 1 : 0);
    query.addBindValue(config.value("voice_alarm_type", "tts").toString());
    query.addBindValue(config.value("tts_text", "").toString());
    query.addBindValue(config.value("audio_file", "").toString());
    query.addBindValue(config.value("play_count", 1).toInt());
    query.addBindValue(config.value("play_duration", 5).toInt());
    query.addBindValue(QDateTime::currentDateTime());

    if (!query.exec()) {
        QString error = QString("保存设备%1制动器%2配置失败: %3")
            .arg(deviceId).arg(brakeIndex).arg(query.lastError().text());
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    qDebug() << "✅ [DeviceConfigManager] 保存制动器配置:" << deviceId << brakeIndex;
    emit deviceConfigChanged(deviceId);
    return true;
}

QVariantMap DeviceConfigManager::loadBrakeConfig(int deviceId, int brakeIndex)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM device_brake_config WHERE device_id = ? AND brake_index = ?");
    query.addBindValue(deviceId);
    query.addBindValue(brakeIndex);

    if (!query.exec() || !query.next()) {
        qWarning() << "加载设备" << deviceId << "制动器" << brakeIndex << "配置失败";
        return QVariantMap();
    }

    return queryToMap(query);
}

QVariantList DeviceConfigManager::loadAllBrakeConfigs(int deviceId)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM device_brake_config WHERE device_id = ? ORDER BY brake_index");
    query.addBindValue(deviceId);

    if (!query.exec()) {
        qWarning() << "加载设备" << deviceId << "所有制动器配置失败:" << query.lastError().text();
        return QVariantList();
    }

    return queryToList(query);
}

bool DeviceConfigManager::initDefaultBrakeConfigs(int deviceId)
{
    // 默认4个制动器
    QSqlQuery query(m_database);
    for (int brakeIndex = 0; brakeIndex < 4; brakeIndex++) {
        QString brakeName = QString("制动器%1").arg(brakeIndex + 1);

        query.prepare(R"(
            INSERT INTO device_brake_config
            (device_id, brake_index, brake_name, brake_force, temperature_upper_limit, temperature_lower_limit,
             pressure_upper_limit, pressure_lower_limit, tts_text)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        )");
        query.addBindValue(deviceId);
        query.addBindValue(brakeIndex);
        query.addBindValue(brakeName);
        query.addBindValue(50.0);   // 默认制动力
        query.addBindValue(80.0);   // 温度上限
        query.addBindValue(0.0);    // 温度下限
        query.addBindValue(10.0);   // 压力上限
        query.addBindValue(0.0);    // 压力下限
        query.addBindValue(brakeName + "报警");

        if (!query.exec()) {
            QString error = QString("初始化设备%1制动器%2配置失败: %3")
                .arg(deviceId).arg(brakeIndex).arg(query.lastError().text());
            qCritical() << error;
            emit databaseError(error);
            return false;
        }
    }

    return true;
}

// ========== 张紧控制配置 ==========
// ✅ 2026-02-02 [参数持久化]: 实现张紧控制配置管理方法

bool DeviceConfigManager::saveTensionConfig(int deviceId, int tensionIndex, const QVariantMap &config)
{
    QSqlQuery query(m_database);
    query.prepare(R"(
        INSERT OR REPLACE INTO device_tension_config
        (device_id, tension_index, tension_name, tension_force,
         position_upper_limit, position_lower_limit, pressure_upper_limit, pressure_lower_limit,
         temperature_upper_limit, temperature_lower_limit,
         voice_alarm_enabled, voice_alarm_type, tts_text, audio_file, play_count, play_duration, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    )");

    query.addBindValue(deviceId);
    query.addBindValue(tensionIndex);
    query.addBindValue(config.value("tension_name", "").toString());
    query.addBindValue(config.value("tension_force", 0.0).toDouble());
    query.addBindValue(config.value("position_upper_limit", 100.0).toDouble());
    query.addBindValue(config.value("position_lower_limit", 0.0).toDouble());
    query.addBindValue(config.value("pressure_upper_limit", 10.0).toDouble());
    query.addBindValue(config.value("pressure_lower_limit", 0.0).toDouble());
    query.addBindValue(config.value("temperature_upper_limit", 80.0).toDouble());
    query.addBindValue(config.value("temperature_lower_limit", 0.0).toDouble());
    query.addBindValue(config.value("voice_alarm_enabled", false).toBool() ? 1 : 0);
    query.addBindValue(config.value("voice_alarm_type", "tts").toString());
    query.addBindValue(config.value("tts_text", "").toString());
    query.addBindValue(config.value("audio_file", "").toString());
    query.addBindValue(config.value("play_count", 1).toInt());
    query.addBindValue(config.value("play_duration", 5).toInt());
    query.addBindValue(QDateTime::currentDateTime());

    if (!query.exec()) {
        QString error = QString("保存设备%1张紧装置%2配置失败: %3")
            .arg(deviceId).arg(tensionIndex).arg(query.lastError().text());
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    qDebug() << "✅ [DeviceConfigManager] 保存张紧控制配置:" << deviceId << tensionIndex;
    emit deviceConfigChanged(deviceId);
    return true;
}

QVariantMap DeviceConfigManager::loadTensionConfig(int deviceId, int tensionIndex)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM device_tension_config WHERE device_id = ? AND tension_index = ?");
    query.addBindValue(deviceId);
    query.addBindValue(tensionIndex);

    if (!query.exec() || !query.next()) {
        qWarning() << "加载设备" << deviceId << "张紧装置" << tensionIndex << "配置失败";
        return QVariantMap();
    }

    return queryToMap(query);
}

QVariantList DeviceConfigManager::loadAllTensionConfigs(int deviceId)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM device_tension_config WHERE device_id = ? ORDER BY tension_index");
    query.addBindValue(deviceId);

    if (!query.exec()) {
        qWarning() << "加载设备" << deviceId << "所有张紧控制配置失败:" << query.lastError().text();
        return QVariantList();
    }

    return queryToList(query);
}

bool DeviceConfigManager::initDefaultTensionConfigs(int deviceId)
{
    // 默认2个张紧装置
    QSqlQuery query(m_database);
    for (int tensionIndex = 0; tensionIndex < 2; tensionIndex++) {
        QString tensionName = QString("张紧装置%1").arg(tensionIndex + 1);

        query.prepare(R"(
            INSERT INTO device_tension_config
            (device_id, tension_index, tension_name, tension_force,
             position_upper_limit, position_lower_limit, pressure_upper_limit, pressure_lower_limit,
             temperature_upper_limit, temperature_lower_limit, tts_text)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        )");
        query.addBindValue(deviceId);
        query.addBindValue(tensionIndex);
        query.addBindValue(tensionName);
        query.addBindValue(50.0);   // 默认张紧力
        query.addBindValue(100.0);  // 位置上限
        query.addBindValue(0.0);    // 位置下限
        query.addBindValue(10.0);   // 压力上限
        query.addBindValue(0.0);    // 压力下限
        query.addBindValue(80.0);   // 温度上限
        query.addBindValue(0.0);    // 温度下限
        query.addBindValue(tensionName + "报警");

        if (!query.exec()) {
            QString error = QString("初始化设备%1张紧装置%2配置失败: %3")
                .arg(deviceId).arg(tensionIndex).arg(query.lastError().text());
            qCritical() << error;
            emit databaseError(error);
            return false;
        }
    }

    return true;
}
