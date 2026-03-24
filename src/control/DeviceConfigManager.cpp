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
            -- 2026-02-28 Phase 7.47.52: 默认改为0（默认音频），旧值1导致新建保护默认TTS
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
        // ✅ 2026-03-04 [Phase 7.48.3]: 表已存在时不中断，允许后续 ALTER TABLE 迁移执行
        // 旧代码：return false; 导致 ALTER TABLE 永远不执行，新列无法添加
        QString error = "创建device_digital_protections表失败: " + query.lastError().text();
        qCritical() << error;
        emit databaseError(error);
        // return false;  // ✅ 2026-03-04: 不再提前退出，继续执行迁移
    }

    query.exec("CREATE INDEX IF NOT EXISTS idx_digital_protections_device ON device_digital_protections(device_id)");
    query.exec("CREATE INDEX IF NOT EXISTS idx_digital_protections_active ON device_digital_protections(active)");

    // ✅ 2026-03-04 [Phase 7.47.94]: 迁移 - 添加 play_mode 列（已有数据库不会重建表，需要 ALTER TABLE）
    // SQLite 的 ALTER TABLE 对已存在的列会报错但不影响，直接忽略错误即可
    query.exec("ALTER TABLE device_digital_protections ADD COLUMN play_mode TEXT DEFAULT 'count'");
    // ✅ 2026-03-04 [Phase 7.47.96]: 迁移 - 添加 protection_level 列（0=紧急停车预警 1=正常停车预警 2=仅预警 3=不处理）
    query.exec("ALTER TABLE device_digital_protections ADD COLUMN protection_level INTEGER DEFAULT 1");

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
            -- 2026-02-28 Phase 7.47.52: 默认改为0（默认音频）
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
        // ✅ 2026-03-04 [Phase 7.48.3]: 与 digital_protections 表一致，不提前退出
        QString error = "创建device_analog_protections表失败: " + query.lastError().text();
        qCritical() << error;
        emit databaseError(error);
        // return false;  // ✅ 2026-03-04: 不再提前退出，继续执行迁移
    }

    query.exec("CREATE INDEX IF NOT EXISTS idx_analog_protections_device ON device_analog_protections(device_id)");
    query.exec("CREATE INDEX IF NOT EXISTS idx_analog_protections_active ON device_analog_protections(active)");

    // ✅ 2026-03-04 [Phase 7.47.94]: 迁移 - 添加 play_mode 列（与开关量保护表一致）
    query.exec("ALTER TABLE device_analog_protections ADD COLUMN play_mode TEXT DEFAULT 'count'");
    // ✅ 2026-03-04 [Phase 7.47.96]: 迁移 - 添加 protection_level 列（与开关量保护表一致）
    query.exec("ALTER TABLE device_analog_protections ADD COLUMN protection_level INTEGER DEFAULT 1");
    // ✅ 2026-03-05 [Phase 7.48.5]: 迁移 - 添加模拟量特有的3个新列
    // ✅ 2026-03-07 [Phase 7.48.19]: 审核后更新默认值 data_timeout 30.0→2.0, connection_timeout 60.0→10.0
    // 旧：query.exec("ALTER TABLE device_analog_protections ADD COLUMN data_timeout REAL DEFAULT 30.0");
    // 旧：query.exec("ALTER TABLE device_analog_protections ADD COLUMN connection_timeout REAL DEFAULT 60.0");
    query.exec("ALTER TABLE device_analog_protections ADD COLUMN data_timeout REAL DEFAULT 2.0");
    query.exec("ALTER TABLE device_analog_protections ADD COLUMN connection_timeout REAL DEFAULT 10.0");
    query.exec("ALTER TABLE device_analog_protections ADD COLUMN input_type TEXT DEFAULT '4-20mA'");
    // ✅ 2026-03-05 [Phase 7.48.10]: 速度保护专用字段（延时启动 + 额定速度百分比检测模式）
    query.exec("ALTER TABLE device_analog_protections ADD COLUMN speed_start_delay REAL DEFAULT 0.0");
    query.exec("ALTER TABLE device_analog_protections ADD COLUMN speed_detect_mode TEXT DEFAULT 'limit'");
    query.exec("ALTER TABLE device_analog_protections ADD COLUMN rated_speed REAL DEFAULT 0.0");
    query.exec("ALTER TABLE device_analog_protections ADD COLUMN slip_delay REAL DEFAULT 10.0");

    // ✅ 2026-03-09 [Phase 7.48.26]: 添加洒水使能列
    query.exec("ALTER TABLE device_analog_protections ADD COLUMN sprinkler_enabled BOOLEAN DEFAULT 0");
    query.exec("ALTER TABLE device_digital_protections ADD COLUMN sprinkler_enabled BOOLEAN DEFAULT 0");

    // ✅ 2026-03-09 [Phase 7.48.26]: 洒水输出配置表
    query.exec(R"(
        CREATE TABLE IF NOT EXISTS sprinkler_output_config (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            module_type TEXT DEFAULT '继电器模块',
            channel INTEGER DEFAULT 7,
            mqtt_topic TEXT DEFAULT 'belt_control/relay/module1/control',
            enabled BOOLEAN DEFAULT 1,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    )");

    // ✅ 2026-03-09: 扩展洒水输出配置表，支持8个独立洒水装置
    query.exec("ALTER TABLE sprinkler_output_config ADD COLUMN sprinkler_index INTEGER DEFAULT 1");
    query.exec("ALTER TABLE sprinkler_output_config ADD COLUMN sprinkler_name TEXT DEFAULT '洒水1'");
    query.exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_sprinkler_config_index ON sprinkler_output_config(sprinkler_index)");

    // ✅ 2026-03-09: 添加洒水索引列到保护表（0=无洒水, 1-8=洒水1-8）
    query.exec("ALTER TABLE device_analog_protections ADD COLUMN sprinkler_index INTEGER DEFAULT 0");
    query.exec("ALTER TABLE device_digital_protections ADD COLUMN sprinkler_index INTEGER DEFAULT 0");

    // 2026-03-14 [Phase 7.48.45]: 制动器配置表新增列（松闸/抱闸输出通道、反馈配置、启用状态）
    query.exec("ALTER TABLE device_brake_config ADD COLUMN enabled BOOLEAN DEFAULT 1");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN release_output_channel INTEGER DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN brake_output_channel INTEGER DEFAULT -1");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN use_release_feedback BOOLEAN DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN release_feedback_channel INTEGER DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN release_feedback_timeout INTEGER DEFAULT 10");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN use_brake_feedback BOOLEAN DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN brake_feedback_channel INTEGER DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN brake_feedback_timeout INTEGER DEFAULT 10");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN hold_time REAL DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN release_time REAL DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN brake_delay REAL DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN release_delay REAL DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN detect_delay REAL DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN fault_delay REAL DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN brake_current REAL DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN release_current REAL DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN brake_voltage REAL DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN release_voltage REAL DEFAULT 0");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN release_warning_voice TEXT DEFAULT ''");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN release_failure_voice TEXT DEFAULT ''");
    query.exec("ALTER TABLE device_brake_config ADD COLUMN brake_failure_voice TEXT DEFAULT ''");

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

    // ✅ 2026-03-10 [Phase 7.48.29]: 电机保护参数扩展 - 新增11列（与模拟量保护对齐）
    query.exec("ALTER TABLE device_motor_config ADD COLUMN module_type TEXT DEFAULT '模拟量模块1'");
    query.exec("ALTER TABLE device_motor_config ADD COLUMN register_address INTEGER DEFAULT -1");
    query.exec("ALTER TABLE device_motor_config ADD COLUMN range_value REAL DEFAULT 100.0");
    query.exec("ALTER TABLE device_motor_config ADD COLUMN input_type TEXT DEFAULT '4-20mA电流型'");
    query.exec("ALTER TABLE device_motor_config ADD COLUMN data_timeout REAL DEFAULT 2.0");
    query.exec("ALTER TABLE device_motor_config ADD COLUMN connection_timeout REAL DEFAULT 10.0");
    query.exec("ALTER TABLE device_motor_config ADD COLUMN play_mode TEXT DEFAULT 'count'");
    query.exec("ALTER TABLE device_motor_config ADD COLUMN protection_level INTEGER DEFAULT 1");
    query.exec("ALTER TABLE device_motor_config ADD COLUMN sprinkler_enabled BOOLEAN DEFAULT 0");
    query.exec("ALTER TABLE device_motor_config ADD COLUMN filter_delay REAL DEFAULT 5.0");
    query.exec("ALTER TABLE device_motor_config ADD COLUMN use_text_to_speech BOOLEAN DEFAULT 0");

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
    // 2026-03-14 [Phase 7.48.45]: 添加UNIQUE约束，确保INSERT OR REPLACE按(device_id, brake_index)更新
    // 先清理可能存在的重复行（保留最新的一条）
    query.exec(R"(
        DELETE FROM device_brake_config WHERE id NOT IN (
            SELECT MAX(id) FROM device_brake_config GROUP BY device_id, brake_index
        )
    )");
    query.exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_brake_config_unique ON device_brake_config(device_id, brake_index)");

    // ✅ 2026-02-02 [参数持久化]: 添加张紧控制配置表
    // ✅ 2026-03-16 [Phase 7.48.46]: 重写表结构，统一QML/C++字段名，新增反馈/输出/语音字段
    // 7. 张紧控制配置表
    // ✅ 2026-03-18 [Phase 7.48.53]: 新增startup_delay和audio_source字段
    QString createTensionConfigTable = R"(
        CREATE TABLE IF NOT EXISTS device_tension_config (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER NOT NULL,
            tension_index INTEGER NOT NULL,
            enabled INTEGER DEFAULT 1,
            protection_name TEXT DEFAULT '',
            unit TEXT DEFAULT 'kN',
            protection_type TEXT DEFAULT '上限报警',
            protection_delay REAL DEFAULT 10.0,
            module_type TEXT DEFAULT '模拟量模块1',
            play_count INTEGER DEFAULT 1,
            register_address INTEGER DEFAULT -1,
            play_duration REAL DEFAULT 5.0,
            channel_number INTEGER DEFAULT 0,
            upper_limit REAL DEFAULT 100.0,
            lower_limit REAL DEFAULT 0.0,
            range_value REAL DEFAULT 100.0,
            rated_value REAL DEFAULT 50.0,
            output_channel INTEGER DEFAULT 0,
            use_feedback INTEGER DEFAULT 0,
            feedback_channel INTEGER DEFAULT 0,
            feedback_timeout INTEGER DEFAULT 10,
            use_text_to_speech INTEGER DEFAULT 0,
            tts_text TEXT DEFAULT '',
            audio_file TEXT DEFAULT '',
            warning_voice TEXT DEFAULT '',
            failure_voice TEXT DEFAULT '',
            startup_delay INTEGER DEFAULT 5,
            audio_source TEXT DEFAULT 'default',
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

    // 迁移 003：扩展模拟量保护从7-8项到18项
    // ✅ 2026-03-05 [Phase 7.48.8]: 修改 - 速度/张力/电压为单一保护项，根据上下限播放不同音频
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 003（模拟量保护扩展至18项）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '003_expand_analog_protections'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        qDebug() << "🔄 [DeviceConfigManager] 开始执行迁移003...";

        // 1. 删除旧的"电流一"和"电流二"保护项
        QSqlQuery deleteQuery(m_database);
        deleteQuery.exec("DELETE FROM device_analog_protections WHERE protection_name IN ('电流一', '电流二')");
        int deletedCount = deleteQuery.numRowsAffected();
        qDebug() << "  ✅ 删除旧保护项（电流一/电流二）:" << deletedCount << "条";

        // 2. 删除可能存在的拆分保护项（速度超速/低速打滑/张力上限/张力下限/电压过压/电压欠压）
        deleteQuery.exec("DELETE FROM device_analog_protections WHERE protection_name IN ('速度超速', '低速打滑', '张力上限', '张力下限', '电压过压', '电压欠压')");
        int deletedSplitCount = deleteQuery.numRowsAffected();
        qDebug() << "  ✅ 删除拆分保护项:" << deletedSplitCount << "条";

        // 3. 更新旧保护项名称（保持单一保护项）
        QSqlQuery updateQuery(m_database);
        updateQuery.exec("UPDATE device_analog_protections SET protection_name = '温度一' WHERE protection_name = '红外温度一'");
        updateQuery.exec("UPDATE device_analog_protections SET protection_name = '温度二' WHERE protection_name = '红外温度二'");
        // 速度、张力、电压保持原名不变
        qDebug() << "  ✅ 更新旧保护项名称完成";

        // 4. 为每个设备补充缺失的保护项
        QSqlQuery deviceQuery(m_database);
        deviceQuery.exec("SELECT device_id FROM devices ORDER BY device_id");

        // 定义需要补充的保护项（11项新增）
        struct NewProtection {
            QString name;
            QString unit;
            int registerAddress;
            double upperLimit;
            double lowerLimit;
            double range;
            double rated;
        };

        QList<NewProtection> newProtections = {
            // 设备运行保护（2项新增）
            {"煤流",       "t/h",  7, 2000.0, 0.0, 2000.0, 500.0},
            {"煤仓高度",   "m",    8, 30.0, 0.0, 30.0, 15.0},
            // 环境安全监测（8项新增）
            {"温度",       "℃",   12, 50.0, 0.0, 50.0, 26.0},
            {"湿度",       "%RH",  13, 100.0, 0.0, 100.0, 95.0},
            {"烟雾",       "mg/m³",14, 1000.0, 0.0, 1000.0, 500.0},
            {"气压",       "kPa",  15, 120.0, 80.0, 40.0, 101.0},
            {"氧气",       "%O₂",  16, 25.0, 0.0, 25.0, 20.0},
            {"甲烷",       "%CH₄", 17, 4.0, 0.0, 4.0, 1.0},
            {"一氧化碳",   "ppm",  18, 1000.0, 0.0, 1000.0, 24.0},
            {"硫化氢",     "ppm",  19, 100.0, 0.0, 100.0, 6.6},
            // 安全规程补充（3项新增）
            {"二氧化碳",   "%CO₂", 20, 5.0, 0.0, 5.0, 1.5},
            {"风速",       "m/s",  21, 15.0, 0.3, 14.7, 4.0},
            {"粉尘浓度",   "mg/m³",22, 1000.0, 0.0, 1000.0, 100.0}
        };

        int deviceCount = 0;
        int totalAdded = 0;
        while (deviceQuery.next()) {
            int deviceId = deviceQuery.value(0).toInt();
            deviceCount++;

            for (const auto &p : newProtections) {
                // 检查是否已存在
                QSqlQuery checkQuery(m_database);
                checkQuery.prepare("SELECT COUNT(*) FROM device_analog_protections WHERE device_id = ? AND protection_name = ?");
                checkQuery.addBindValue(deviceId);
                checkQuery.addBindValue(p.name);

                if (checkQuery.exec() && checkQuery.next() && checkQuery.value(0).toInt() == 0) {
                    // 不存在，插入新保护项
                    QSqlQuery insertQuery(m_database);
                    insertQuery.prepare(R"(
                        INSERT INTO device_analog_protections
                        (device_id, protection_name, module_type, register_address, unit,
                         upper_limit, lower_limit, range_value, rated_value, tts_text, use_text_to_speech)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    )");
                    insertQuery.addBindValue(deviceId);
                    insertQuery.addBindValue(p.name);
                    insertQuery.addBindValue("模拟量模块1");
                    insertQuery.addBindValue(p.registerAddress);
                    insertQuery.addBindValue(p.unit);
                    insertQuery.addBindValue(p.upperLimit);
                    insertQuery.addBindValue(p.lowerLimit);
                    insertQuery.addBindValue(p.range);
                    insertQuery.addBindValue(p.rated);
                    insertQuery.addBindValue(p.name + "保护报警");
                    insertQuery.addBindValue(0);  // 默认使用默认音频

                    if (insertQuery.exec()) {
                        totalAdded++;
                    } else {
                        qWarning() << "  ⚠️ 设备" << deviceId << "添加保护项" << p.name << "失败:" << insertQuery.lastError().text();
                    }
                }
            }
        }

        qDebug() << "  ✅ 为" << deviceCount << "个设备补充了" << totalAdded << "条新保护项";
        qDebug() << "✅ [DeviceConfigManager] 迁移003完成";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('003_expand_analog_protections')");
    } else if (!query.exec()) {
        qWarning() << "⚠️ [DeviceConfigManager] 迁移003查询失败:" << query.lastError().text();
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移003已执行过，跳过";
    }

    // ✅ 2026-03-05 [Phase 7.48.10]: 迁移004 - 速度保护专用字段默认值
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 004（速度保护额定速度+延时字段）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '004_speed_protection_fields'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        qDebug() << "🔧 [DeviceConfigManager] 执行迁移004: 设置速度保护默认值";
        QSqlQuery fix(m_database);
        // 将已有速度保护的 rated_speed 设为 rated_value（2.5），speed_start_delay 设为 30秒
        fix.exec("UPDATE device_analog_protections SET rated_speed = rated_value, speed_start_delay = 30.0 WHERE protection_name = '速度' AND rated_speed = 0.0");
        int affected = fix.numRowsAffected();
        qDebug() << "  ✅ 迁移004: 更新" << affected << "条速度保护的额定速度和启动延时";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('004_speed_protection_fields')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移004已执行过，跳过";
    }

    // ✅ 2026-03-06 [Phase 7.48.12]: 迁移005 - 修正模拟量保护通道号和模块类型
    // 旧映射：registerAddress 5-22，全部"模拟量模块1"
    // 新映射：模块1通道0-7（速度~温度），模块2通道0-7（湿度~二氧化碳），风速/粉尘浓度=-1/未分配
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 005（修正通道号和模块类型）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '005_fix_channel_mapping'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        qDebug() << "🔧 [DeviceConfigManager] 执行迁移005: 修正通道号和模块类型";
        QSqlQuery fix(m_database);
        int totalAffected = 0;

        // 模拟量模块1：通道0-7
        struct ChannelFix { QString name; QString moduleType; int regAddr; };
        QList<ChannelFix> fixes = {
            {"速度",     "模拟量模块1", 0},
            {"张力",     "模拟量模块1", 1},
            {"煤流",     "模拟量模块1", 2},
            {"煤仓高度", "模拟量模块1", 3},
            {"温度一",   "模拟量模块1", 4},
            {"温度二",   "模拟量模块1", 5},
            {"电压",     "模拟量模块1", 6},
            {"温度",     "模拟量模块1", 7},
            {"湿度",     "模拟量模块2", 0},
            {"烟雾",     "模拟量模块2", 1},
            {"气压",     "模拟量模块2", 2},
            {"氧气",     "模拟量模块2", 3},
            {"甲烷",     "模拟量模块2", 4},
            {"一氧化碳", "模拟量模块2", 5},
            {"硫化氢",   "模拟量模块2", 6},
            {"二氧化碳", "模拟量模块2", 7},
            {"风速",     "未分配",     -1},
            {"粉尘浓度", "未分配",     -1}
        };

        for (const auto &f : fixes) {
            fix.prepare("UPDATE device_analog_protections SET module_type = ?, register_address = ? WHERE protection_name = ?");
            fix.addBindValue(f.moduleType);
            fix.addBindValue(f.regAddr);
            fix.addBindValue(f.name);
            if (fix.exec()) {
                totalAffected += fix.numRowsAffected();
            }
        }

        qDebug() << "  ✅ 迁移005: 更新" << totalAffected << "条保护项的通道号和模块类型";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('005_fix_channel_mapping')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移005已执行过，跳过";
    }

    // ✅ 2026-03-06 [Phase 7.48.13]: 迁移006 - 删除旧的拆分保护项
    // 原因：早期版本可能创建了速度超速/低速打滑/张力上限/张力下限/电压过压/电压欠压
    //       这些项在 Phase 7.48.9 已合并为单一保护项（速度/张力/电压）
    //       迁移003在某些设备上执行时还没有删除逻辑，导致旧项残留
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 006（删除旧拆分保护项）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '006_remove_split_protections'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        qDebug() << "🔧 [DeviceConfigManager] 执行迁移006: 删除旧拆分保护项";
        QSqlQuery deleteQuery(m_database);
        deleteQuery.exec("DELETE FROM device_analog_protections WHERE protection_name IN ('速度超速', '低速打滑', '张力上限', '张力下限', '电压过压', '电压欠压')");
        int deletedCount = deleteQuery.numRowsAffected();
        qDebug() << "  ✅ 迁移006: 删除" << deletedCount << "条旧拆分保护项";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('006_remove_split_protections')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移006已执行过，跳过";
    }

    // ✅ 2026-03-06 [Phase 7.48.14]: 迁移007 - 重新排序模拟量保护项（修正id顺序）
    // 问题：Phase 7.48.13 改用 ORDER BY id，但数据库中的 id 是按最初插入顺序分配的
    //       迁移003-006只更新了字段值，没有改变id顺序，导致设备显示顺序错误
    // 解决：删除所有保护项，按正确顺序重新插入（获得新的连续id）
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 007（重新排序模拟量保护项）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '007_reorder_analog_protections'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        qDebug() << "🔧 [DeviceConfigManager] 执行迁移007: 重新排序模拟量保护项";

        // 1. 获取所有设备
        QSqlQuery deviceQuery(m_database);
        deviceQuery.exec("SELECT device_id FROM devices ORDER BY device_id");

        int deviceCount = 0;
        int totalReordered = 0;

        while (deviceQuery.next()) {
            int deviceId = deviceQuery.value(0).toInt();
            deviceCount++;

            // 2. 读取该设备的所有模拟量保护项（保存到临时列表）
            QSqlQuery loadQuery(m_database);
            loadQuery.prepare("SELECT * FROM device_analog_protections WHERE device_id = ?");
            loadQuery.addBindValue(deviceId);

            QList<QVariantMap> protections;
            if (loadQuery.exec()) {
                while (loadQuery.next()) {
                    QVariantMap prot;
                    prot["protection_name"] = loadQuery.value("protection_name");
                    prot["module_type"] = loadQuery.value("module_type");
                    prot["register_address"] = loadQuery.value("register_address");
                    prot["unit"] = loadQuery.value("unit");
                    prot["upper_limit"] = loadQuery.value("upper_limit");
                    prot["lower_limit"] = loadQuery.value("lower_limit");
                    prot["range_value"] = loadQuery.value("range_value");
                    prot["rated_value"] = loadQuery.value("rated_value");
                    prot["tts_text"] = loadQuery.value("tts_text");
                    prot["use_text_to_speech"] = loadQuery.value("use_text_to_speech");
                    prot["play_mode"] = loadQuery.value("play_mode");
                    prot["play_count"] = loadQuery.value("play_count");
                    prot["play_duration"] = loadQuery.value("play_duration");
                    prot["speed_start_delay"] = loadQuery.value("speed_start_delay");
                    prot["speed_detect_mode"] = loadQuery.value("speed_detect_mode");
                    prot["rated_speed"] = loadQuery.value("rated_speed");
                    prot["slip_delay"] = loadQuery.value("slip_delay");
                    protections.append(prot);
                }
            }

            if (protections.isEmpty()) {
                continue;  // 该设备没有保护项，跳过
            }

            // 3. 删除该设备的所有模拟量保护项
            QSqlQuery deleteQuery(m_database);
            deleteQuery.prepare("DELETE FROM device_analog_protections WHERE device_id = ?");
            deleteQuery.addBindValue(deviceId);
            deleteQuery.exec();

            // 4. 按正确顺序重新插入（使用 initDefaultAnalogProtections 的顺序）
            // 定义正确的顺序（与 initDefaultAnalogProtections 一致）
            // ✅ 2026-03-06 [Phase 7.48.14 修复]: 补充缺失的"电压"项（共18项）
            QStringList correctOrder = {
                // 常用项（皮带机头）
                "速度", "张力", "温度一", "温度二", "温度", "湿度", "甲烷", "粉尘浓度",
                // 其余项
                "煤流", "煤仓高度", "电压", "烟雾", "气压", "氧气", "一氧化碳", "硫化氢", "二氧化碳", "风速"
            };

            // 按正确顺序重新插入
            for (const QString &name : correctOrder) {
                // 在临时列表中查找该保护项
                QVariantMap prot;
                bool found = false;
                for (const QVariantMap &p : protections) {
                    if (p["protection_name"].toString() == name) {
                        prot = p;
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    continue;  // 该设备没有这个保护项，跳过
                }

                // 重新插入（获得新的连续id）
                QSqlQuery insertQuery(m_database);
                insertQuery.prepare(R"(
                    INSERT INTO device_analog_protections
                    (device_id, protection_name, module_type, register_address, unit,
                     upper_limit, lower_limit, range_value, rated_value, tts_text, use_text_to_speech,
                     play_mode, play_count, play_duration,
                     speed_start_delay, speed_detect_mode, rated_speed, slip_delay)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                )");
                insertQuery.addBindValue(deviceId);
                insertQuery.addBindValue(prot["protection_name"]);
                insertQuery.addBindValue(prot["module_type"]);
                insertQuery.addBindValue(prot["register_address"]);
                insertQuery.addBindValue(prot["unit"]);
                insertQuery.addBindValue(prot["upper_limit"]);
                insertQuery.addBindValue(prot["lower_limit"]);
                insertQuery.addBindValue(prot["range_value"]);
                insertQuery.addBindValue(prot["rated_value"]);
                insertQuery.addBindValue(prot["tts_text"]);
                insertQuery.addBindValue(prot["use_text_to_speech"]);
                insertQuery.addBindValue(prot["play_mode"]);
                insertQuery.addBindValue(prot["play_count"]);
                insertQuery.addBindValue(prot["play_duration"]);
                insertQuery.addBindValue(prot["speed_start_delay"]);
                insertQuery.addBindValue(prot["speed_detect_mode"]);
                insertQuery.addBindValue(prot["rated_speed"]);
                insertQuery.addBindValue(prot["slip_delay"]);

                if (insertQuery.exec()) {
                    totalReordered++;
                } else {
                    qWarning() << "  ⚠️ 设备" << deviceId << "重新插入保护项" << name << "失败:" << insertQuery.lastError().text();
                }
            }
        }

        qDebug() << "  ✅ 迁移007: 为" << deviceCount << "个设备重新排序了" << totalReordered << "条保护项";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('007_reorder_analog_protections')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移007已执行过，跳过";
    }

    // ✅ 2026-03-06 [Phase 7.48.14 修复]: 迁移008 - 修复迁移007的排序问题
    // 问题：迁移007的correctOrder列表完整但执行时可能有问题，导致顺序仍然错误
    // 解决：重新执行一次完整的排序逻辑，确保所有设备的保护项顺序正确
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 008（修复模拟量保护项排序）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '008_fix_analog_protections_order'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        qDebug() << "🔧 [DeviceConfigManager] 执行迁移008: 修复模拟量保护项排序";

        // 1. 获取所有设备
        QSqlQuery deviceQuery(m_database);
        deviceQuery.exec("SELECT device_id FROM devices ORDER BY device_id");

        int deviceCount = 0;
        int totalReordered = 0;

        while (deviceQuery.next()) {
            int deviceId = deviceQuery.value(0).toInt();
            deviceCount++;

            // 2. 读取该设备的所有模拟量保护项（保存到临时列表）
            QSqlQuery loadQuery(m_database);
            loadQuery.prepare("SELECT * FROM device_analog_protections WHERE device_id = ?");
            loadQuery.addBindValue(deviceId);

            QList<QVariantMap> protections;
            if (loadQuery.exec()) {
                while (loadQuery.next()) {
                    QVariantMap prot;
                    prot["protection_name"] = loadQuery.value("protection_name");
                    prot["module_type"] = loadQuery.value("module_type");
                    prot["register_address"] = loadQuery.value("register_address");
                    prot["unit"] = loadQuery.value("unit");
                    prot["upper_limit"] = loadQuery.value("upper_limit");
                    prot["lower_limit"] = loadQuery.value("lower_limit");
                    prot["range_value"] = loadQuery.value("range_value");
                    prot["rated_value"] = loadQuery.value("rated_value");
                    prot["tts_text"] = loadQuery.value("tts_text");
                    prot["use_text_to_speech"] = loadQuery.value("use_text_to_speech");
                    prot["play_mode"] = loadQuery.value("play_mode");
                    prot["play_count"] = loadQuery.value("play_count");
                    prot["play_duration"] = loadQuery.value("play_duration");
                    prot["speed_start_delay"] = loadQuery.value("speed_start_delay");
                    prot["speed_detect_mode"] = loadQuery.value("speed_detect_mode");
                    prot["rated_speed"] = loadQuery.value("rated_speed");
                    prot["slip_delay"] = loadQuery.value("slip_delay");
                    prot["audio_file"] = loadQuery.value("audio_file");
                    prot["protection_level"] = loadQuery.value("protection_level");
                    protections.append(prot);
                }
            }

            if (protections.isEmpty()) {
                continue;  // 该设备没有保护项，跳过
            }

            // 3. 删除该设备的所有模拟量保护项
            QSqlQuery deleteQuery(m_database);
            deleteQuery.prepare("DELETE FROM device_analog_protections WHERE device_id = ?");
            deleteQuery.addBindValue(deviceId);
            deleteQuery.exec();

            // 4. 按正确顺序重新插入（与 initDefaultAnalogProtections 完全一致）
            QStringList correctOrder = {
                // 常用项（皮带机头）
                "速度", "张力", "温度一", "温度二", "温度", "湿度", "甲烷", "粉尘浓度",
                // 其余项
                "煤流", "煤仓高度", "电压", "烟雾", "气压", "氧气", "一氧化碳", "硫化氢", "二氧化碳", "风速"
            };

            // 按正确顺序重新插入
            for (const QString &name : correctOrder) {
                // 在临时列表中查找该保护项
                QVariantMap prot;
                bool found = false;
                for (const QVariantMap &p : protections) {
                    if (p["protection_name"].toString() == name) {
                        prot = p;
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    continue;  // 该设备没有这个保护项，跳过
                }

                // 重新插入（获得新的连续id）
                QSqlQuery insertQuery(m_database);
                insertQuery.prepare(R"(
                    INSERT INTO device_analog_protections
                    (device_id, protection_name, module_type, register_address, unit,
                     upper_limit, lower_limit, range_value, rated_value, tts_text, use_text_to_speech,
                     play_mode, play_count, play_duration,
                     speed_start_delay, speed_detect_mode, rated_speed, slip_delay,
                     audio_file, protection_level)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                )");
                insertQuery.addBindValue(deviceId);
                insertQuery.addBindValue(prot["protection_name"]);
                insertQuery.addBindValue(prot["module_type"]);
                insertQuery.addBindValue(prot["register_address"]);
                insertQuery.addBindValue(prot["unit"]);
                insertQuery.addBindValue(prot["upper_limit"]);
                insertQuery.addBindValue(prot["lower_limit"]);
                insertQuery.addBindValue(prot["range_value"]);
                insertQuery.addBindValue(prot["rated_value"]);
                insertQuery.addBindValue(prot["tts_text"]);
                insertQuery.addBindValue(prot["use_text_to_speech"]);
                insertQuery.addBindValue(prot["play_mode"]);
                insertQuery.addBindValue(prot["play_count"]);
                insertQuery.addBindValue(prot["play_duration"]);
                insertQuery.addBindValue(prot["speed_start_delay"]);
                insertQuery.addBindValue(prot["speed_detect_mode"]);
                insertQuery.addBindValue(prot["rated_speed"]);
                insertQuery.addBindValue(prot["slip_delay"]);
                insertQuery.addBindValue(prot["audio_file"]);
                insertQuery.addBindValue(prot["protection_level"]);

                if (insertQuery.exec()) {
                    totalReordered++;
                } else {
                    qWarning() << "  ⚠️ 设备" << deviceId << "重新插入保护项" << name << "失败:" << insertQuery.lastError().text();
                }
            }
        }

        qDebug() << "  ✅ 迁移008: 为" << deviceCount << "个设备重新排序了" << totalReordered << "条保护项";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('008_fix_analog_protections_order')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移008已执行过，跳过";
    }

    // ✅ 2026-03-06 [Phase 7.48.14 紧急修复]: 迁移009 - 恢复丢失的速度和张力保护项
    // 问题：迁移007/008执行后，速度和张力保护项从数据库中消失
    // 原因：迁移逻辑依赖数据库现有数据，如果保护项不存在就跳过，导致永久丢失
    // 解决：不依赖现有数据，直接从initDefaultAnalogProtections的定义重新创建所有18项保护
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 009（恢复完整的18项模拟量保护）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '009_restore_all_analog_protections'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        qDebug() << "🔧 [DeviceConfigManager] 执行迁移009: 恢复完整的18项模拟量保护";

        // 定义完整的18项保护（与initDefaultAnalogProtections完全一致）
        struct AnalogProtection {
            QString name;
            QString unit;
            QString moduleType;
            int registerAddress;
            double upperLimit;
            double lowerLimit;
            double range;
            double rated;
        };

        QList<AnalogProtection> defaultProtections = {
            // 常用项（皮带机头）
            {"速度",       "m/s",   "模拟量模块1", 0, 10.0,  0.5, 9.5, 2.5},
            {"张力",       "T",     "模拟量模块1", 1, 100.0, 10.0, 90.0, 50.0},
            {"温度一",     "℃",    "模拟量模块1", 4, 150.0, 0.0, 150.0, 40.0},
            {"温度二",     "℃",    "模拟量模块1", 5, 150.0, 0.0, 150.0, 40.0},
            {"温度",       "℃",    "模拟量模块1", 7, 50.0, 0.0, 50.0, 26.0},
            {"湿度",       "%RH",   "模拟量模块2", 0, 100.0, 0.0, 100.0, 95.0},
            {"甲烷",       "%CH₄",  "模拟量模块2", 4, 4.0, 0.0, 4.0, 1.0},
            {"粉尘浓度",   "mg/m³", "未分配", -1, 1000.0, 0.0, 1000.0, 100.0},
            // 其余项
            {"煤流",       "t/h",   "模拟量模块1", 2, 2000.0, 0.0, 2000.0, 500.0},
            {"煤仓高度",   "m",     "模拟量模块1", 3, 30.0, 0.0, 30.0, 15.0},
            {"电压",       "V",     "模拟量模块1", 6, 450.0, 320.0, 130.0, 380.0},
            {"烟雾",       "mg/m³", "模拟量模块2", 1, 1000.0, 0.0, 1000.0, 500.0},
            {"气压",       "kPa",   "模拟量模块2", 2, 120.0, 80.0, 40.0, 101.0},
            {"氧气",       "%O₂",   "模拟量模块2", 3, 25.0, 0.0, 25.0, 20.0},
            {"一氧化碳",   "ppm",   "模拟量模块2", 5, 1000.0, 0.0, 1000.0, 24.0},
            {"硫化氢",     "ppm",   "模拟量模块2", 6, 100.0, 0.0, 100.0, 6.6},
            {"二氧化碳",   "%CO₂",  "模拟量模块2", 7, 5.0, 0.0, 5.0, 1.5},
            {"风速",       "m/s",   "未分配", -1, 15.0, 0.3, 14.7, 4.0}
        };

        // 获取所有设备
        QSqlQuery deviceQuery(m_database);
        deviceQuery.exec("SELECT device_id FROM devices ORDER BY device_id");

        int deviceCount = 0;
        int totalRestored = 0;

        while (deviceQuery.next()) {
            int deviceId = deviceQuery.value(0).toInt();
            deviceCount++;

            // 1. 删除该设备的所有模拟量保护项（清空旧数据）
            QSqlQuery deleteQuery(m_database);
            deleteQuery.prepare("DELETE FROM device_analog_protections WHERE device_id = ?");
            deleteQuery.addBindValue(deviceId);
            deleteQuery.exec();

            // 2. 按正确顺序插入完整的18项保护（不依赖旧数据）
            for (const auto &p : defaultProtections) {
                QSqlQuery insertQuery(m_database);

                // 速度保护需要额外的4个字段
                if (p.name == "速度") {
                    insertQuery.prepare(R"(
                        INSERT INTO device_analog_protections
                        (device_id, protection_name, module_type, register_address, unit,
                         upper_limit, lower_limit, range_value, rated_value, tts_text, use_text_to_speech,
                         play_mode, play_count, play_duration,
                         speed_start_delay, speed_detect_mode, rated_speed, slip_delay,
                         audio_file, protection_level)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    )");
                    insertQuery.addBindValue(deviceId);
                    insertQuery.addBindValue(p.name);
                    insertQuery.addBindValue(p.moduleType);
                    insertQuery.addBindValue(p.registerAddress);
                    insertQuery.addBindValue(p.unit);
                    insertQuery.addBindValue(p.upperLimit);
                    insertQuery.addBindValue(p.lowerLimit);
                    insertQuery.addBindValue(p.range);
                    insertQuery.addBindValue(p.rated);
                    insertQuery.addBindValue(p.name + "保护报警");
                    insertQuery.addBindValue(0);  // use_text_to_speech: 默认音频
                    insertQuery.addBindValue("count");  // play_mode
                    insertQuery.addBindValue(3);  // play_count
                    insertQuery.addBindValue(10.0);  // play_duration
                    insertQuery.addBindValue(30.0);  // speed_start_delay
                    insertQuery.addBindValue("limit");  // speed_detect_mode
                    insertQuery.addBindValue(p.rated);  // rated_speed
                    insertQuery.addBindValue(10.0);  // slip_delay
                    insertQuery.addBindValue("");  // audio_file
                    insertQuery.addBindValue(1);  // protection_level
                } else {
                    insertQuery.prepare(R"(
                        INSERT INTO device_analog_protections
                        (device_id, protection_name, module_type, register_address, unit,
                         upper_limit, lower_limit, range_value, rated_value, tts_text, use_text_to_speech,
                         play_mode, play_count, play_duration,
                         audio_file, protection_level)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    )");
                    insertQuery.addBindValue(deviceId);
                    insertQuery.addBindValue(p.name);
                    insertQuery.addBindValue(p.moduleType);
                    insertQuery.addBindValue(p.registerAddress);
                    insertQuery.addBindValue(p.unit);
                    insertQuery.addBindValue(p.upperLimit);
                    insertQuery.addBindValue(p.lowerLimit);
                    insertQuery.addBindValue(p.range);
                    insertQuery.addBindValue(p.rated);
                    insertQuery.addBindValue(p.name + "保护报警");
                    insertQuery.addBindValue(0);  // use_text_to_speech: 默认音频
                    insertQuery.addBindValue("count");  // play_mode
                    insertQuery.addBindValue(3);  // play_count
                    insertQuery.addBindValue(10.0);  // play_duration
                    insertQuery.addBindValue("");  // audio_file
                    insertQuery.addBindValue(1);  // protection_level
                }

                if (insertQuery.exec()) {
                    totalRestored++;
                } else {
                    qWarning() << "  ⚠️ 设备" << deviceId << "恢复保护项" << p.name << "失败:" << insertQuery.lastError().text();
                }
            }
        }

        qDebug() << "  ✅ 迁移009: 为" << deviceCount << "个设备恢复了" << totalRestored << "条保护项（应为" << (deviceCount * 18) << "条）";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('009_restore_all_analog_protections')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移009已执行过，跳过";
    }

    // ✅ 2026-03-07 [Phase 7.48.19]: 迁移010 - 审核后更新所有模拟量保护默认值和通道映射
    // 变更内容：37项参数修改（见 docs/2026-03-07/01-模拟量保护参数默认值清单-待审核.md v2.0 第六节）
    // 策略：直接删除旧数据，用审核后的新值重新插入（用户要求"直接代替新参数"）
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 010（审核后更新模拟量保护默认值）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '010_reviewed_analog_defaults'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        qDebug() << "🔧 [DeviceConfigManager] 执行迁移010: 审核后更新所有模拟量保护默认值和通道映射";

        // 审核后的18项保护定义（与initDefaultAnalogProtections完全一致）
        struct AnalogProtection {
            QString name;
            QString unit;
            QString moduleType;
            int registerAddress;
            double upperLimit;
            double lowerLimit;
            double range;
            double rated;
        };

        // ✅ 2026-03-07 [Phase 7.48.22]: 通道按截图从上到下顺序分配
        //   前8项 = 模拟量模块1 CH0-CH7，后8项 = 模拟量模块2 CH0-CH7
        QList<AnalogProtection> reviewedProtections = {
            // 模拟量模块1 CH0-CH7（截图第1-8项）
            {"速度",       "m/s",   "模拟量模块1", 0, 3.0,    0.5,   5.0,    2.5},   // 模块1 CH0
            {"张力",       "T",     "模拟量模块1", 1, 8.0,    3.0,   20.0,   0.0},   // 模块1 CH1
            {"温度一",     "℃",    "模拟量模块1", 2, 42.0,   0.0,   100.0,  0.0},   // 模块1 CH2
            {"温度二",     "℃",    "模拟量模块1", 3, 42.0,   0.0,   100.0,  0.0},   // 模块1 CH3
            {"电压",       "V",     "模拟量模块1", 4, 700.0,  500.0, 660.0,  0.0},   // 模块1 CH4
            {"甲烷",       "%CH₄",  "模拟量模块1", 5, 1.0,    0.0,   4.0,    0.0},   // 模块1 CH5
            {"一氧化碳",   "ppm",   "模拟量模块1", 6, 24.0,   0.0,   1000.0, 0.0},   // 模块1 CH6
            {"二氧化碳",   "%CO₂",  "模拟量模块1", 7, 1.5,    0.0,   5.0,    0.0},   // 模块1 CH7
            // 模拟量模块2 CH0-CH7（截图第9-16项）
            {"硫化氢",     "ppm",   "模拟量模块2", 0, 6.6,    0.0,   100.0,  6.6},   // 模块2 CH0
            {"氧气",       "%O₂",   "模拟量模块2", 1, 23.5,   0.0,   25.0,   20.0},  // 模块2 CH1
            {"烟雾",       "mg/m³", "模拟量模块2", 2, 100.0,  0.0,   1000.0, 500.0}, // 模块2 CH2
            {"粉尘浓度",   "mg/m³", "模拟量模块2", 3, 4.0,    0.0,   1000.0, 100.0}, // 模块2 CH3
            {"温度",       "℃",    "模拟量模块2", 4, 34.0,   0.0,   50.0,   26.0},  // 模块2 CH4
            {"湿度",       "%RH",   "模拟量模块2", 5, 95.0,   0.0,   100.0,  95.0},  // 模块2 CH5
            {"煤流",       "t/h",   "模拟量模块2", 6, 1500.0, 0.0,   2000.0, 500.0}, // 模块2 CH6
            {"煤仓高度",   "m",     "模拟量模块2", 7, 25.0,   0.0,   30.0,   15.0},  // 模块2 CH7
            {"气压",       "kPa",   "未分配", -1, 110.0,      80.0,  40.0,   101.0}, // 未分配
            {"风速",       "m/s",   "未分配", -1, 4.0,        0.3,   14.7,   4.0}    // 未分配
        };

        // 获取所有设备
        QSqlQuery deviceQuery(m_database);
        deviceQuery.exec("SELECT device_id FROM devices ORDER BY device_id");

        int deviceCount = 0;
        int totalRestored = 0;

        while (deviceQuery.next()) {
            int deviceId = deviceQuery.value(0).toInt();
            deviceCount++;

            // 1. 删除该设备的所有模拟量保护项（清空旧数据，直接替代）
            QSqlQuery deleteQuery(m_database);
            deleteQuery.prepare("DELETE FROM device_analog_protections WHERE device_id = ?");
            deleteQuery.addBindValue(deviceId);
            deleteQuery.exec();

            // 2. 用审核后的新默认值重新插入18项保护
            for (const auto &p : reviewedProtections) {
                QSqlQuery insertQuery(m_database);

                // 速度保护需要额外的4个字段
                if (p.name == "速度") {
                    insertQuery.prepare(R"(
                        INSERT INTO device_analog_protections
                        (device_id, protection_name, module_type, register_address, unit,
                         upper_limit, lower_limit, range_value, rated_value, tts_text, use_text_to_speech,
                         play_mode, play_count, play_duration,
                         speed_start_delay, speed_detect_mode, rated_speed, slip_delay,
                         audio_file, protection_level, data_timeout, connection_timeout, input_type)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    )");
                    insertQuery.addBindValue(deviceId);
                    insertQuery.addBindValue(p.name);
                    insertQuery.addBindValue(p.moduleType);
                    insertQuery.addBindValue(p.registerAddress);
                    insertQuery.addBindValue(p.unit);
                    insertQuery.addBindValue(p.upperLimit);
                    insertQuery.addBindValue(p.lowerLimit);
                    insertQuery.addBindValue(p.range);
                    insertQuery.addBindValue(p.rated);
                    insertQuery.addBindValue(p.name + "保护报警");
                    insertQuery.addBindValue(0);       // use_text_to_speech: 默认音频
                    insertQuery.addBindValue("count");  // play_mode
                    insertQuery.addBindValue(3);        // play_count
                    insertQuery.addBindValue(5.0);      // play_duration: 审核值5.0秒
                    insertQuery.addBindValue(30.0);     // speed_start_delay
                    insertQuery.addBindValue("limit");  // speed_detect_mode
                    insertQuery.addBindValue(p.rated);  // rated_speed: 等于rated_value（2.5 m/s）
                    insertQuery.addBindValue(10.0);     // slip_delay
                    insertQuery.addBindValue("");       // audio_file
                    insertQuery.addBindValue(1);        // protection_level
                    insertQuery.addBindValue(2.0);      // data_timeout: 审核值2.0秒（旧30.0）
                    insertQuery.addBindValue(10.0);     // connection_timeout: 审核值10.0秒（旧60.0）
                    insertQuery.addBindValue("4-20mA"); // input_type
                } else {
                    insertQuery.prepare(R"(
                        INSERT INTO device_analog_protections
                        (device_id, protection_name, module_type, register_address, unit,
                         upper_limit, lower_limit, range_value, rated_value, tts_text, use_text_to_speech,
                         play_mode, play_count, play_duration,
                         audio_file, protection_level, data_timeout, connection_timeout, input_type)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    )");
                    insertQuery.addBindValue(deviceId);
                    insertQuery.addBindValue(p.name);
                    insertQuery.addBindValue(p.moduleType);
                    insertQuery.addBindValue(p.registerAddress);
                    insertQuery.addBindValue(p.unit);
                    insertQuery.addBindValue(p.upperLimit);
                    insertQuery.addBindValue(p.lowerLimit);
                    insertQuery.addBindValue(p.range);
                    insertQuery.addBindValue(p.rated);
                    insertQuery.addBindValue(p.name + "保护报警");
                    insertQuery.addBindValue(0);       // use_text_to_speech: 默认音频
                    insertQuery.addBindValue("count");  // play_mode
                    insertQuery.addBindValue(3);        // play_count
                    insertQuery.addBindValue(5.0);      // play_duration: 审核值5.0秒
                    insertQuery.addBindValue("");       // audio_file
                    insertQuery.addBindValue(1);        // protection_level
                    insertQuery.addBindValue(2.0);      // data_timeout: 审核值2.0秒（旧30.0）
                    insertQuery.addBindValue(10.0);     // connection_timeout: 审核值10.0秒（旧60.0）
                    insertQuery.addBindValue("4-20mA"); // input_type
                }

                if (insertQuery.exec()) {
                    totalRestored++;
                } else {
                    qWarning() << "  ⚠️ 设备" << deviceId << "更新保护项" << p.name << "失败:" << insertQuery.lastError().text();
                }
            }
        }

        qDebug() << "  ✅ 迁移010: 为" << deviceCount << "个设备更新了" << totalRestored << "条保护项（应为" << (deviceCount * 18) << "条）";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('010_reviewed_analog_defaults')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移010已执行过，跳过";
    }

    // ✅ 2026-03-07 [Phase 7.48.20]: 迁移011 - 修正13项模拟量保护上限值
    // 问题：旧上限 = 传感器量程满量程，导致 engineeringValue >= upperLimit 只有在 AD=65535 时才触发
    // 修正：按煤矿安全规程（2022年修正版，应急管理部令第8号）设置合理报警上限
    // 适用场景：设备已执行迁移010但上限值仍是满量程的情况
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 011（修正模拟量保护上限值为安全规程标准）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '011_fix_analog_upper_limits'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        qDebug() << "🔧 [DeviceConfigManager] 执行迁移011: 修正13项模拟量保护上限值";

        // 13项上限修正表：{保护名称, 新上限值, 旧上限值, 依据}
        struct UpperLimitFix {
            QString name;
            double newUpperLimit;
            double oldUpperLimit;  // 用于匹配条件（仅更新还没被用户手动修改的值）
        };

        QList<UpperLimitFix> fixes = {
            // B. 危害气体监测（依据：煤矿安全规程）
            {"甲烷",       1.0,    4.0},     // 煤矿安全规程：≥1.0%报警
            {"一氧化碳",   24.0,   1000.0},  // 煤矿安全规程：≥24ppm报警
            {"二氧化碳",   1.5,    5.0},     // 煤矿安全规程：>1.5%报警
            {"硫化氢",     6.6,    100.0},   // 煤矿安全规程：≥6.6ppm报警
            {"氧气",       23.5,   25.0},    // GB/T 50493-2019：>23.5%富氧报警
            {"烟雾",       100.0,  1000.0},  // 烟雾传感器典型报警值
            {"粉尘浓度",   4.0,    1000.0},  // GBZ 2.1-2019：煤尘总尘>4mg/m³
            // C. 环境监测
            {"温度",       34.0,   50.0},    // 煤矿安全规程：机电硐室>34℃停工
            {"湿度",       95.0,   100.0},   // 高湿预警
            {"煤流",       1500.0, 2000.0},  // 额定500的3倍预警
            {"煤仓高度",   25.0,   30.0},    // 接近满仓预警
            {"气压",       110.0,  120.0},   // 正常大气压上限
            {"风速",       4.0,    15.0}     // 煤矿安全规程：采煤工作面>4m/s
        };

        int totalUpdated = 0;
        for (const auto &fix : fixes) {
            // 只更新上限值仍为旧值（满量程）的记录，保护用户已手动修改的值
            QSqlQuery updateQuery(m_database);
            updateQuery.prepare(R"(
                UPDATE device_analog_protections
                SET upper_limit = ?
                WHERE protection_name = ? AND upper_limit = ?
            )");
            updateQuery.addBindValue(fix.newUpperLimit);
            updateQuery.addBindValue(fix.name);
            updateQuery.addBindValue(fix.oldUpperLimit);
            if (updateQuery.exec()) {
                int affected = updateQuery.numRowsAffected();
                if (affected > 0) {
                    qDebug() << "  ✅" << fix.name << ": 上限" << fix.oldUpperLimit << "→" << fix.newUpperLimit
                             << "（更新" << affected << "条）";
                    totalUpdated += affected;
                }
            }
        }

        qDebug() << "  ✅ 迁移011: 共更新" << totalUpdated << "条上限值";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('011_fix_analog_upper_limits')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移011已执行过，跳过";
    }

    // ✅ 2026-03-07 [Phase 7.48.22]: 迁移012 - 完整通道重映射（截图顺序分配CH0-CH7）
    // 旧映射：甲烷/一氧化碳/二氧化碳在模块2，温度/煤流/煤仓高度在模块1
    // 新映射：前8项=模块1 CH0-7，后8项=模块2 CH0-7
    // 变更项：甲烷(模块2→模块1)，一氧化碳(模块2→模块1)，二氧化碳(模块2→模块1)
    //         温度(模块1 CH5→模块2 CH4)，湿度(模块2 CH4→CH5)，煤流(模块1→模块2)，煤仓高度(模块1→模块2)
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 012（完整通道重映射：截图顺序分配CH0-CH7）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '012_fix_channel_conflicts'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        qDebug() << "🔧 [DeviceConfigManager] 执行迁移012: 完整通道重映射（7项变更）";

        struct ChannelRemap {
            QString name;
            QString oldModule;
            int oldCh;
            QString newModule;
            int newCh;
        };

        QList<ChannelRemap> remaps = {
            {"甲烷",       "模拟量模块2", 5, "模拟量模块1", 5},
            {"一氧化碳",   "模拟量模块2", 6, "模拟量模块1", 6},
            {"二氧化碳",   "模拟量模块2", 7, "模拟量模块1", 7},
            {"温度",       "模拟量模块1", 5, "模拟量模块2", 4},
            {"湿度",       "模拟量模块2", 4, "模拟量模块2", 5},
            {"煤流",       "模拟量模块1", 6, "模拟量模块2", 6},
            {"煤仓高度",   "模拟量模块1", 7, "模拟量模块2", 7},
        };

        int totalRemapped = 0;
        for (const auto &r : remaps) {
            QSqlQuery fixQuery(m_database);
            fixQuery.prepare(R"(
                UPDATE device_analog_protections
                SET module_type = ?, register_address = ?
                WHERE protection_name = ? AND module_type = ? AND register_address = ?
            )");
            fixQuery.addBindValue(r.newModule);
            fixQuery.addBindValue(r.newCh);
            fixQuery.addBindValue(r.name);
            fixQuery.addBindValue(r.oldModule);
            fixQuery.addBindValue(r.oldCh);
            if (fixQuery.exec()) {
                int affected = fixQuery.numRowsAffected();
                totalRemapped += affected;
                qDebug() << "  ✅" << r.name << ":" << r.oldModule << "CH" + QString::number(r.oldCh)
                         << "→" << r.newModule << "CH" + QString::number(r.newCh)
                         << "，更新" << affected << "条";
            }
        }

        // 同时修复气压的module_type（从模拟量模块2改为未分配）
        QSqlQuery fixPressure(m_database);
        fixPressure.prepare(R"(
            UPDATE device_analog_protections
            SET module_type = '未分配', register_address = -1
            WHERE protection_name = '气压' AND module_type = '模拟量模块2' AND register_address = -1
        )");
        if (fixPressure.exec()) {
            int affected = fixPressure.numRowsAffected();
            if (affected > 0) {
                totalRemapped += affected;
                qDebug() << "  ✅ 气压: 模拟量模块2→未分配，更新" << affected << "条";
            }
        }

        qDebug() << "  ✅ 迁移012: 共重映射" << totalRemapped << "条通道记录";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('012_fix_channel_conflicts')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移012已执行过，跳过";
    }

    // ✅ 2026-03-09 [Phase 7.48.26]: 迁移013 - 设置洒水使能默认值 + 初始化洒水输出配置
    // 模拟量保护：烟雾、温度一、温度二、温度 默认启用洒水
    // 开关量保护：烟雾、温度 默认启用洒水
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 013（洒水使能默认值）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '013_sprinkler_defaults'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        qDebug() << "🔧 [DeviceConfigManager] 执行迁移013: 设置洒水使能默认值";
        QSqlQuery fix(m_database);

        // 模拟量保护：烟雾、温度一、温度二、温度 启用洒水
        fix.exec("UPDATE device_analog_protections SET sprinkler_enabled = 1 WHERE protection_name IN ('烟雾', '温度一', '温度二', '温度')");
        int aiAffected = fix.numRowsAffected();
        qDebug() << "  ✅ 模拟量保护洒水使能:" << aiAffected << "条";

        // 开关量保护：烟雾、温度 启用洒水
        fix.exec("UPDATE device_digital_protections SET sprinkler_enabled = 1 WHERE protection_name IN ('烟雾', '温度')");
        int diAffected = fix.numRowsAffected();
        qDebug() << "  ✅ 开关量保护洒水使能:" << diAffected << "条";

        // 初始化洒水输出配置（不存在才插入）
        fix.exec(R"(
            INSERT INTO sprinkler_output_config (module_type, channel, mqtt_topic, enabled)
            SELECT '继电器模块', 7, 'belt_control/relay/module1/control', 1
            WHERE NOT EXISTS (SELECT 1 FROM sprinkler_output_config)
        )");
        qDebug() << "  ✅ 洒水输出配置初始化完成";

        query.exec("INSERT INTO schema_migrations (version) VALUES ('013_sprinkler_defaults')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移013已执行过，跳过";
    }

    // ✅ 2026-03-09: 迁移014 - 扩展洒水控制为8个独立洒水装置
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 014（8个独立洒水）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '014_eight_sprinklers'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        qDebug() << "🔧 [DeviceConfigManager] 执行迁移014: 初始化8个独立洒水配置";
        QSqlQuery fix(m_database);

        // 更新现有行为洒水1（如果sprinkler_index未设置）
        fix.exec("UPDATE sprinkler_output_config SET sprinkler_index = 1, sprinkler_name = '洒水1' WHERE sprinkler_index IS NULL OR sprinkler_index = 0");
        qDebug() << "  ✅ 现有洒水配置更新为洒水1";

        // 插入洒水2-8（不存在才插入）
        for (int i = 2; i <= 8; i++) {
            fix.prepare(R"(
                INSERT INTO sprinkler_output_config (sprinkler_index, sprinkler_name, module_type, channel, mqtt_topic, enabled)
                SELECT ?, ?, '继电器模块', ?, 'belt_control/relay/module1/control', 1
                WHERE NOT EXISTS (SELECT 1 FROM sprinkler_output_config WHERE sprinkler_index = ?)
            )");
            fix.addBindValue(i);
            fix.addBindValue(QString("洒水%1").arg(i));
            fix.addBindValue(i - 1);  // channel: 洒水N使用通道N-1
            fix.addBindValue(i);
            fix.exec();
        }
        qDebug() << "  ✅ 洒水2-8初始化完成";

        // 向后兼容：已启用洒水但未设置洒水索引的保护项，默认连接洒水1
        fix.exec("UPDATE device_analog_protections SET sprinkler_index = 1 WHERE sprinkler_enabled = 1 AND (sprinkler_index IS NULL OR sprinkler_index = 0)");
        int aiFixed = fix.numRowsAffected();
        fix.exec("UPDATE device_digital_protections SET sprinkler_index = 1 WHERE sprinkler_enabled = 1 AND (sprinkler_index IS NULL OR sprinkler_index = 0)");
        int diFixed = fix.numRowsAffected();
        qDebug() << "  ✅ 向后兼容: 模拟量" << aiFixed << "条, 开关量" << diFixed << "条 → 默认洒水1";

        query.exec("INSERT INTO schema_migrations (version) VALUES ('014_eight_sprinklers')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移014已执行过，跳过";
    }

    // ✅ 2026-03-10 [Phase 7.48.31]: 迁移015 - 电机基本配置新增4列（输出通道/反馈通道/模块地址/运行状态）
    // 原因：BasicConfigTab.qml 已有UI控件，但数据库缺少对应列，配置无法持久化
    // 用途：与 DO 模块（Luckfox Lyra RK3506 设备5）的 MQTT 继电器输出关联
    qDebug() << "🔄 [DeviceConfigManager] 检查迁移 015（电机基本配置输出通道）...";
    query.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = '015_motor_output_channel'");
    if (query.exec() && query.next() && query.value(0).toInt() == 0) {
        qDebug() << "🔧 [DeviceConfigManager] 执行迁移015: 电机基本配置新增4列";
        QSqlQuery fix(m_database);

        // 新增4列（ALTER TABLE ADD COLUMN 不会影响现有数据）
        fix.exec("ALTER TABLE device_motor_config ADD COLUMN running_state TEXT DEFAULT '投入'");
        fix.exec("ALTER TABLE device_motor_config ADD COLUMN motor_module_address INTEGER DEFAULT 1");
        fix.exec("ALTER TABLE device_motor_config ADD COLUMN output_channel INTEGER DEFAULT -1");
        fix.exec("ALTER TABLE device_motor_config ADD COLUMN feedback_channel INTEGER DEFAULT -1");

        // 为已有的 Tab 0（基本配置）记录设置默认值：output_channel = motor_index, feedback_channel = motor_index
        fix.exec("UPDATE device_motor_config SET output_channel = motor_index, feedback_channel = motor_index WHERE tab_index = 0 AND output_channel = -1");
        int updated = fix.numRowsAffected();
        qDebug() << "  ✅ 迁移015: 新增4列，更新" << updated << "条基本配置的默认输出/反馈通道";

        query.exec("INSERT INTO schema_migrations (version) VALUES ('015_motor_output_channel')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移015已执行过，跳过";
    }

    // ✅ 2026-03-10 [Phase 7.48.37]: 迁移016 - 新增启动延时、预警语音、失败语音、启动键
    query.exec("SELECT version FROM schema_migrations WHERE version = '016_motor_startup_params'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移016: 新增电机启动参数...";
        QSqlQuery fix(m_database);

        fix.exec("ALTER TABLE device_motor_config ADD COLUMN startup_delay INTEGER DEFAULT 5");
        fix.exec("ALTER TABLE device_motor_config ADD COLUMN warning_voice TEXT DEFAULT ''");
        fix.exec("ALTER TABLE device_motor_config ADD COLUMN failure_voice TEXT DEFAULT ''");
        fix.exec("ALTER TABLE device_motor_config ADD COLUMN startup_key TEXT DEFAULT '无'");

        // ✅ 2026-03-11 [Phase 7.48.37]: 改为音频文件名格式（电机X启动/电机X失败）
        // 旧：warning_voice='电机X启动预警', failure_voice='电机X运行失败'
        fix.exec("UPDATE device_motor_config SET "
                 "warning_voice = '电机' || (motor_index + 1) || '启动', "
                 "failure_voice = '电机' || (motor_index + 1) || '失败' "
                 "WHERE tab_index = 0 AND warning_voice = ''");
        int updated016 = fix.numRowsAffected();
        qDebug() << "  ✅ 迁移016: 新增4列，更新" << updated016 << "条基本配置的默认语音文字";

        query.exec("INSERT INTO schema_migrations (version) VALUES ('016_motor_startup_params')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移016已执行过，跳过";
    }

    // ✅ 2026-03-12: 迁移017 - 新增音频来源列，启动延时默认改为8秒
    query.exec("SELECT version FROM schema_migrations WHERE version = '017_motor_audio_source'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移017: 新增音频来源列...";
        QSqlQuery fix(m_database);

        fix.exec("ALTER TABLE device_motor_config ADD COLUMN audio_source TEXT DEFAULT 'tts'");
        // 启动延时默认从5改为8秒
        fix.exec("UPDATE device_motor_config SET startup_delay = 8 WHERE tab_index = 0 AND startup_delay = 5");
        int updated017 = fix.numRowsAffected();
        qDebug() << "  ✅ 迁移017: 新增audio_source列，更新" << updated017 << "条基本配置启动延时为8秒";

        query.exec("INSERT INTO schema_migrations (version) VALUES ('017_motor_audio_source')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移017已执行过，跳过";
    }

    // ✅ 2026-03-13 [Phase 7.48.43]: 迁移018 - 填充device_motor_config默认数据
    // 原因：initDefaultData()仅在devices表为空时执行，旧数据库升级后motor_config表为空
    query.exec("SELECT version FROM schema_migrations WHERE version = '018_populate_motor_configs'");
    if (!query.next()) {
        QSqlQuery countQuery(m_database);
        countQuery.exec("SELECT COUNT(*) FROM device_motor_config");
        int existingCount = 0;
        if (countQuery.next()) existingCount = countQuery.value(0).toInt();

        if (existingCount == 0) {
            qDebug() << "🔄 [DeviceConfigManager] 执行迁移018: 填充电机保护默认配置...";
            QSqlQuery deviceQuery(m_database);
            deviceQuery.exec("SELECT device_id FROM devices ORDER BY device_id");
            int totalInserted = 0;
            while (deviceQuery.next()) {
                int devId = deviceQuery.value(0).toInt();
                if (initDefaultMotorConfigs(devId)) {
                    totalInserted++;
                }
            }
            qDebug() << "  ✅ 迁移018: 为" << totalInserted << "个设备填充了电机保护默认配置";
        } else {
            qDebug() << "  ⏭️ 迁移018: device_motor_config已有" << existingCount << "条数据，跳过";
        }
        query.exec("INSERT INTO schema_migrations (version) VALUES ('018_populate_motor_configs')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移018已执行过，跳过";
    }

    // ✅ 2026-03-13 [Phase 7.48.43]: 迁移019 - 重命名电机保护参数（英文→中文，TTS兼容）
    query.exec("SELECT version FROM schema_migrations WHERE version = '019_rename_motor_protections_cn'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移019: 重命名电机保护参数为中文...";
        QSqlQuery fix(m_database);
        // A/B/C相绕组 → 甲/乙/丙相绕组（TTS无法播报英文字母）
        fix.exec("UPDATE device_motor_config SET protection_name = '甲相绕组' WHERE protection_name = 'A相绕组'");
        int r1 = fix.numRowsAffected();
        fix.exec("UPDATE device_motor_config SET protection_name = '乙相绕组' WHERE protection_name = 'B相绕组'");
        int r2 = fix.numRowsAffected();
        fix.exec("UPDATE device_motor_config SET protection_name = '丙相绕组' WHERE protection_name = 'C相绕组'");
        int r3 = fix.numRowsAffected();
        // X/Y轴振动 → 水��/垂直振动
        fix.exec("UPDATE device_motor_config SET protection_name = '水平振动' WHERE protection_name = 'X轴振动'");
        int r4 = fix.numRowsAffected();
        fix.exec("UPDATE device_motor_config SET protection_name = '垂直振动' WHERE protection_name = 'Y轴振动'");
        int r5 = fix.numRowsAffected();
        qDebug() << "  ✅ 迁移019: 重命名完成 甲相:" << r1 << "乙相:" << r2 << "丙相:" << r3
                 << "水平振动:" << r4 << "垂直振动:" << r5;
        query.exec("INSERT INTO schema_migrations (version) VALUES ('019_rename_motor_protections_cn')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移019已执行过，跳过";
    }

    // ✅ 2026-03-13 [Phase 7.48.43]: 迁移020 - 去掉protection_name的"电机X-"前缀 + 重命名英文
    // 原因：initDefaultMotorConfigs存了"电机1-后轴承温度"，导致音频路径变成"1号电机电机1-后轴承温度过高.wav"
    query.exec("SELECT version FROM schema_migrations WHERE version = '020_fix_motor_protection_names'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移020: 去掉protection_name的电机前缀+重命名英文...";
        QSqlQuery fix(m_database);
        int total = 0;

        // 1. 去掉"电机X-"前缀（电机1-后轴承温度 → 后轴承温度）
        for (int m = 1; m <= 8; m++) {
            QString prefix = QString("电机%1-").arg(m);
            QString sql = QString("UPDATE device_motor_config SET protection_name = REPLACE(protection_name, '%1', '') "
                                  "WHERE protection_name LIKE '%1%'").arg(prefix);
            fix.exec(sql);
            total += fix.numRowsAffected();
        }
        qDebug() << "  ✅ 去掉电机前缀:" << total << "条";

        // 2. 重命名英文→中文（可能019已处理部分，这里兜底）
        fix.exec("UPDATE device_motor_config SET protection_name = '甲相绕组' WHERE protection_name = 'A相绕组'");
        fix.exec("UPDATE device_motor_config SET protection_name = '乙相绕组' WHERE protection_name = 'B相绕组'");
        fix.exec("UPDATE device_motor_config SET protection_name = '丙相绕组' WHERE protection_name = 'C相绕组'");
        fix.exec("UPDATE device_motor_config SET protection_name = '水平振动' WHERE protection_name = 'X轴振动'");
        fix.exec("UPDATE device_motor_config SET protection_name = '垂直振动' WHERE protection_name = 'Y轴振动'");
        qDebug() << "  ✅ 迁移020完成";

        query.exec("INSERT INTO schema_migrations (version) VALUES ('020_fix_motor_protection_names')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移020已执行过，跳过";
    }

    // ✅ 2026-03-16 [Phase 7.48.46]: 迁移021 - 重建张紧控制配置表（字段与QML完全对齐）
    // 原因：旧表字段(tension_name/tension_force/position_upper_limit等)与QML collectConfig()字段完全不匹配
    // 策略：删除旧表数据，用新结构重新初始化
    query.exec("SELECT version FROM schema_migrations WHERE version = '021_rebuild_tension_config'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移021: 重建张紧控制配置表...";
        QSqlQuery fix(m_database);

        // 1. 删除旧表
        fix.exec("DROP TABLE IF EXISTS device_tension_config");
        qDebug() << "  ✅ 删除旧张紧配置表";

        // 2. 创建新表（与建表语句一致）
        // ✅ 2026-03-18 [Phase 7.48.53]: 新增startup_delay和audio_source字段
        fix.exec(R"(
            CREATE TABLE IF NOT EXISTS device_tension_config (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id INTEGER NOT NULL,
                tension_index INTEGER NOT NULL,
                enabled INTEGER DEFAULT 1,
                protection_name TEXT DEFAULT '',
                unit TEXT DEFAULT 'kN',
                protection_type TEXT DEFAULT '上限报警',
                protection_delay REAL DEFAULT 10.0,
                module_type TEXT DEFAULT '模拟量模块1',
                play_count INTEGER DEFAULT 1,
                register_address INTEGER DEFAULT -1,
                play_duration REAL DEFAULT 5.0,
                channel_number INTEGER DEFAULT 0,
                upper_limit REAL DEFAULT 100.0,
                lower_limit REAL DEFAULT 0.0,
                range_value REAL DEFAULT 100.0,
                rated_value REAL DEFAULT 50.0,
                output_channel INTEGER DEFAULT 0,
                use_feedback INTEGER DEFAULT 0,
                feedback_channel INTEGER DEFAULT 0,
                feedback_timeout INTEGER DEFAULT 10,
                use_text_to_speech INTEGER DEFAULT 0,
                tts_text TEXT DEFAULT '',
                audio_file TEXT DEFAULT '',
                warning_voice TEXT DEFAULT '',
                failure_voice TEXT DEFAULT '',
                startup_delay INTEGER DEFAULT 5,
                audio_source TEXT DEFAULT 'default',
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE,
                UNIQUE(device_id, tension_index)
            )
        )");
        fix.exec("CREATE INDEX IF NOT EXISTS idx_tension_config_device ON device_tension_config(device_id)");
        qDebug() << "  ✅ 创建新张紧配置表";

        // 3. 为所有设备重新初始化默认数据
        QSqlQuery deviceQuery(m_database);
        deviceQuery.exec("SELECT device_id FROM devices ORDER BY device_id");
        int deviceCount = 0;
        while (deviceQuery.next()) {
            int deviceId = deviceQuery.value(0).toInt();
            initDefaultTensionConfigs(deviceId);
            deviceCount++;
        }
        qDebug() << "  ✅ 迁移021: 为" << deviceCount << "个设备重新初始化张紧配置";

        query.exec("INSERT INTO schema_migrations (version) VALUES ('021_rebuild_tension_config')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移021已执行过，跳过";
    }

    // ✅ 2026-03-18 [Phase 7.48.53]: 迁移022 - 张紧配置表新增startup_delay和audio_source列
    query.exec("SELECT version FROM schema_migrations WHERE version = '022_tension_startup_audio'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移022: 张紧配置新增startup_delay和audio_source...";
        QSqlQuery fix(m_database);
        fix.exec("ALTER TABLE device_tension_config ADD COLUMN startup_delay INTEGER DEFAULT 5");
        fix.exec("ALTER TABLE device_tension_config ADD COLUMN audio_source TEXT DEFAULT 'default'");
        qDebug() << "  ✅ 迁移022: 新增startup_delay和audio_source列";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('022_tension_startup_audio')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移022已执行过，跳过";
    }

    // ✅ 2026-03-18 [Phase 7.48.53]: 迁移023 - 模拟量保护通道重置，只保留速度/张力/温度一/温度二/电压
    query.exec("SELECT version FROM schema_migrations WHERE version = '023_analog_channel_reset'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移023: 重置环境监测类模拟量通道为未分配...";
        QSqlQuery fix(m_database);
        // 将甲烷~煤仓高度（原模块1 CH5-7 + 模块2 CH0-7）设为未分配
        QStringList envNames = {"甲烷", "一氧化碳", "二氧化碳", "硫化氢", "氧气", "烟雾",
                                "粉尘浓度", "温度", "湿度", "煤流", "煤仓高度"};
        int updated = 0;
        for (const QString &name : envNames) {
            fix.prepare("UPDATE device_analog_protections SET module_type = '未分配', register_address = -1 WHERE protection_name = ?");
            fix.addBindValue(name);
            if (fix.exec()) updated += fix.numRowsAffected();
        }
        qDebug() << "  ✅ 迁移023: 重置" << updated << "条环境监测通道为未分配";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('023_analog_channel_reset')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移023已执行过，跳过";
    }

    // ✅ 2026-03-18 [Phase 7.48.54]: 迁移024 - 删除模拟量保护中的张力项（已移至张紧控制TensionSensorConfigPanel）
    query.exec("SELECT version FROM schema_migrations WHERE version = '024_remove_analog_tension'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移024: 删除模拟量保护中的张力项...";
        QSqlQuery fix(m_database);
        fix.exec("DELETE FROM device_analog_protections WHERE protection_name = '张力'");
        int deleted = fix.numRowsAffected();
        qDebug() << "  ✅ 迁移024: 删除" << deleted << "条张力保护记录";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('024_remove_analog_tension')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移024已执行过，跳过";
    }

    // ✅ 2026-03-18 [Phase 7.48.55]: 迁移025 - 洒水2-8默认禁用（只保留洒水1启用）
    query.exec("SELECT version FROM schema_migrations WHERE version = '025_sprinkler_default_disabled'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移025: 洒水2-8默认禁用...";
        QSqlQuery fix(m_database);
        fix.exec("UPDATE sprinkler_output_config SET enabled = 0 WHERE sprinkler_index > 1");
        int updated = fix.numRowsAffected();
        qDebug() << "  ✅ 迁移025: 禁用" << updated << "个洒水装置(洒水2-8)";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('025_sprinkler_default_disabled')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移025已执行过，跳过";
    }

    // ✅ 2026-03-18 [Phase 7.48.55]: 迁移026 - 开关量保护新增洒水延时字段
    query.exec("SELECT version FROM schema_migrations WHERE version = '026_digital_sprinkler_delay'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移026: 开关量保护新增sprinkler_delay列...";
        QSqlQuery fix(m_database);
        fix.exec("ALTER TABLE device_digital_protections ADD COLUMN sprinkler_delay INTEGER DEFAULT 30");
        qDebug() << "  ✅ 迁移026: sprinkler_delay列已添加(默认30秒)";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('026_digital_sprinkler_delay')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移026已执行过，跳过";
    }

    // ✅ 2026-03-18 [Phase 7.48.56]: 迁移027 - 初始化沿线点位保护默认记录（3种×64点位=192条）
    query.exec("SELECT version FROM schema_migrations WHERE version = '027_line_position_protections'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移027: 初始化沿线点位保护默认记录...";
        QSqlQuery fix(m_database);

        // 3种保护类型：急停(base=0), 跑偏(base=100), 撕裂(base=200)
        struct LineProtDef { int channelBase; QString name; QString file; };
        QList<LineProtDef> defs = {
            {0,   "沿线急停", "沿线急停"},
            {100, "沿线跑偏", "沿线跑偏"},
            {200, "沿线撕裂", "沿线撕裂"},
        };

        int insertCount = 0;
        for (const auto &def : defs) {
            for (int pos = 1; pos <= 64; ++pos) {
                fix.prepare(R"(
                    INSERT INTO device_digital_protections (
                        device_id, protection_name, module_type, register_address,
                        channel_number, tts_text, use_text_to_speech, audio_file,
                        protection_delay, play_count, play_duration, play_mode, protection_level
                    ) SELECT ?, ?, 'CS模块', 5, ?, ?, 1, ?, 1.0, 3, 5.0, 'count', 1
                    WHERE NOT EXISTS (
                        SELECT 1 FROM device_digital_protections
                        WHERE module_type = 'CS模块' AND channel_number = ?
                    )
                )");
                fix.addBindValue(1);
                fix.addBindValue(QString("%1号%2").arg(pos).arg(def.name));
                fix.addBindValue(def.channelBase + pos - 1);
                fix.addBindValue(QString("%1号%2保护").arg(pos).arg(def.name));
                fix.addBindValue(QString("%1号%2.wav").arg(pos).arg(def.file));
                fix.addBindValue(def.channelBase + pos - 1);
                if (fix.exec() && fix.numRowsAffected() > 0) insertCount++;
            }
        }
        qDebug() << "  ✅ 迁移027: 插入" << insertCount << "条沿线点位保护记录";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('027_line_position_protections')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移027已执行过，跳过";
    }

    // ✅ 2026-03-21 [Phase 7.48.66]: 迁移028 - 修复张紧控制反馈默认值
    // 原因：initDefaultTensionConfigs 创建记录时 use_feedback=0，导致启动序列中
    //       张紧设备的反馈检测从未启动，运行失败音频无法播放
    query.exec("SELECT version FROM schema_migrations WHERE version = '028_fix_tension_feedback_default'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移028: 修复张紧控制反馈默认值...";
        QSqlQuery fix(m_database);
        // 将所有张紧配置的 use_feedback 从 0 改为 1
        fix.exec("UPDATE device_tension_config SET use_feedback = 1 WHERE use_feedback = 0");
        int updated = fix.numRowsAffected();
        qDebug() << "  ✅ 迁移028: 更新" << updated << "条张紧配置的 use_feedback 为1";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('028_fix_tension_feedback_default')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移028已执行过，跳过";
    }

    // ✅ 2026-03-21 [Phase 7.48.68]: 迁移029 - 制动器新增启动延时字段
    // 原因：制动器缺少松闸启动延时和抱闸启动延时参数，逻辑控制需要读取这些延时
    query.exec("SELECT version FROM schema_migrations WHERE version = '029_brake_startup_delay'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移029: 制动器新增启动延时字段...";
        QSqlQuery alter(m_database);
        alter.exec("ALTER TABLE device_brake_config ADD COLUMN release_startup_delay REAL DEFAULT 1.0");
        alter.exec("ALTER TABLE device_brake_config ADD COLUMN brake_startup_delay REAL DEFAULT 1.0");
        qDebug() << "  ✅ 迁移029: 新增 release_startup_delay, brake_startup_delay 列";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('029_brake_startup_delay')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移029已执行过，跳过";
    }

    // ✅ 2026-03-21 [Phase 7.48.68]: 迁移030 - 创建设备逻辑控制配置表
    // 原因：每个设备（12个设备卡片）需要独立的启停逻辑控制配置
    query.exec("SELECT version FROM schema_migrations WHERE version = '030_device_logic_configs'");
    if (!query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移030: 创建设备逻辑控制配置表...";
        QSqlQuery create(m_database);
        create.exec("CREATE TABLE IF NOT EXISTS device_logic_configs ("
                     "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                     "device_id INTEGER NOT NULL, "
                     "startup_sequence TEXT DEFAULT '[]', "
                     "stop_sequence TEXT DEFAULT '[]', "
                     "warning_time REAL DEFAULT 10.0, "
                     "default_delay REAL DEFAULT 1.0, "
                     "UNIQUE(device_id))");
        // 初始化12条设备默认记录
        // device_id=1（1号皮带）预设默认启停序列
        create.exec("INSERT OR IGNORE INTO device_logic_configs (device_id, startup_sequence, stop_sequence) VALUES "
                     "(1, '[\"张紧控制\",\"1号制动器\",\"1号电机\",\"2号电机\"]', '[\"2号电机\",\"1号电机\",\"1号制动器\",\"张紧控制\"]')");
        for (int i = 2; i <= 12; i++) {
            create.exec(QString("INSERT OR IGNORE INTO device_logic_configs (device_id) VALUES (%1)").arg(i));
        }
        qDebug() << "  ✅ 迁移030: 创建 device_logic_configs 表并初始化12条记录";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('030_device_logic_configs')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移030已执行过，跳过";
    }

    // ✅ 2026-03-21 [Phase 7.48.69]: 迁移031 - 电机配置新增use_feedback列
    // 原因：device_motor_config 表没有 use_feedback 列，loadMotorConfig() 返回 undefined，
    //       ParameterSettings.qml 默认 true，导致用户关闭反馈后仍被检查
    if (!query.exec("SELECT 1 FROM schema_migrations WHERE version = '031_motor_use_feedback'") || !query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移031: 电机配置新增use_feedback列...";
        QSqlQuery fix(m_database);
        fix.exec("ALTER TABLE device_motor_config ADD COLUMN use_feedback INTEGER DEFAULT 0");
        // 默认0（关闭反馈），用户需要在设备设置中手动开启
        qDebug() << "  ✅ 迁移031: 新增 use_feedback 列(默认0=关闭)";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('031_motor_use_feedback')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移031已执行过，跳过";
    }

    // ✅ 2026-03-22 [Phase 7.48.74]: 迁移032 - 所有设备新增独立停止延时字段
    // 原因：启动延时和停止延时共用一个值不够灵活，需要独立配置
    if (!query.exec("SELECT 1 FROM schema_migrations WHERE version = '032_add_stop_delay'") || !query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移032: 所有设备新增独立停止延时...";
        QSqlQuery fix(m_database);
        // 电机表新增停止延时
        fix.exec("ALTER TABLE device_motor_config ADD COLUMN stop_delay INTEGER DEFAULT 8");
        // 制动器表新增停止延时（松闸停止延时 + 抱闸停止延时）
        fix.exec("ALTER TABLE device_brake_config ADD COLUMN release_stop_delay REAL DEFAULT 1.0");
        fix.exec("ALTER TABLE device_brake_config ADD COLUMN brake_stop_delay REAL DEFAULT 1.0");
        // 张紧表新增停止延时
        fix.exec("ALTER TABLE device_tension_config ADD COLUMN stop_delay INTEGER DEFAULT 5");
        // 洒水表新增启动延时和停止延时
        fix.exec("ALTER TABLE sprinkler_output_config ADD COLUMN startup_delay INTEGER DEFAULT 1");
        fix.exec("ALTER TABLE sprinkler_output_config ADD COLUMN stop_delay INTEGER DEFAULT 1");
        qDebug() << "  ✅ 迁移032: 电机/制动器/张紧/洒水表均新增停止延时字段";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('032_add_stop_delay')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移032已执行过，跳过";
    }

    // ✅ 2026-03-24 [Phase 7.48.88.5]: 迁移033 - 输出通道默认配置不冲突
    // 原因：电机/制动器/张紧/洒水的输出通道全部默认为0或motorIndex，互相冲突
    // 新方案：张紧=0, 制动器=brakeIndex+1, 电机=motorIndex+3, 洒水=sprinklerIndex+5
    if (!query.exec("SELECT 1 FROM schema_migrations WHERE version = '033_fix_output_channel_conflicts'") || !query.next()) {
        qDebug() << "🔄 [DeviceConfigManager] 执行迁移033: 修复输出通道冲突...";
        QSqlQuery fix(m_database);
        int totalUpdated = 0;

        // 1. 电机：output_channel = motor_index + 3（仅Tab0基本配置）
        // 旧默认：output_channel = motor_index（0,1,2...与张紧/制动器冲突）
        fix.exec("UPDATE device_motor_config SET output_channel = motor_index + 3 "
                 "WHERE tab_index = 0 AND output_channel = motor_index");
        totalUpdated += fix.numRowsAffected();
        qDebug() << "  电机: 更新" << fix.numRowsAffected() << "条（output_channel = motor_index + 3）";

        // 2. 制动器：release_output_channel = brake_index + 1, brake_output_channel = -1
        // 旧默认：release_output_channel = 0（所有制动器共用通道0，与张紧冲突）
        fix.exec("UPDATE device_brake_config SET release_output_channel = brake_index + 1 "
                 "WHERE release_output_channel = 0");
        totalUpdated += fix.numRowsAffected();
        qDebug() << "  制动器松闸: 更新" << fix.numRowsAffected() << "条（release = brake_index + 1）";

        // 抱闸通道：旧默认0改为-1（不使用）
        fix.exec("UPDATE device_brake_config SET brake_output_channel = -1 "
                 "WHERE brake_output_channel = 0");
        totalUpdated += fix.numRowsAffected();
        qDebug() << "  制动器抱闸: 更新" << fix.numRowsAffected() << "条（brake = -1）";

        // 3. 张紧：output_channel = 0（已经是0，无需更新）
        // 跳过

        // 4. 洒水：channel = sprinkler_index + 5（字段名是 sprinkler_index，从1开始）
        // 旧默认：channel = sprinkler_index - 1（0,1,2...与张紧/制动器/电机冲突）
        // sprinkler_output_config 表的 sprinkler_index 从1开始
        fix.exec("UPDATE sprinkler_output_config SET channel = sprinkler_index + 4 "
                 "WHERE channel = sprinkler_index - 1");
        totalUpdated += fix.numRowsAffected();
        qDebug() << "  洒水: 更新" << fix.numRowsAffected() << "条（channel = sprinkler_index + 4）";

        qDebug() << "  ✅ 迁移033: 共更新" << totalUpdated << "条输出通道配置";
        query.exec("INSERT INTO schema_migrations (version) VALUES ('033_fix_output_channel_conflicts')");
    } else {
        qDebug() << "⏭️ [DeviceConfigManager] 迁移033已执行过，跳过";
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
    // ✅ 2026-03-09 [Phase 7.48.26]: 烟雾、温度 默认启用洒水
    QStringList protectionNames = {
        "急停", "跑偏", "撕裂", "烟雾", "温度", "护网", "堆煤", "主机急停"
    };

    QSqlQuery query(m_database);
    for (int i = 0; i < protectionNames.size(); i++) {
        QString name = protectionNames[i];
        // ✅ 2026-02-28 [Phase 7.47.53]: 修复 - 添加 use_text_to_speech = 0（默认为默认音频）
        // 旧代码：不指定 use_text_to_speech，导致使用表的DEFAULT值（旧版本DEFAULT为1，导致新建保护默认为TTS）
        // 新代码：显式设置为0，确保新建的所有保护默认使用默认音频
        // ✅ 2026-03-09 [Phase 7.48.26]: 添加 sprinkler_enabled（烟雾、温度=1, 其余=0）
        int sprinklerEnabled = (name == "烟雾" || name == "温度") ? 1 : 0;
        query.prepare(R"(
            INSERT INTO device_digital_protections
            (device_id, protection_name, module_type, register_address, channel_number, tts_text, use_text_to_speech, sprinkler_enabled)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        )");
        query.addBindValue(deviceId);
        query.addBindValue(name);
        query.addBindValue("输入模块1");
        query.addBindValue(2);
        query.addBindValue(i);  // 通道编号 0-7
        query.addBindValue(name + "保护报警");
        query.addBindValue(0);  // ✅ 默认为0（使用默认音频）
        query.addBindValue(sprinklerEnabled);  // ✅ 2026-03-09 [Phase 7.48.26]: 洒水使能

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
        // ✅ 2026-03-06 [Phase 7.48.12]: 新增 moduleType 字段，支持模拟量模块1/2分配
        QString moduleType;
        int registerAddress;
        double upperLimit;
        double lowerLimit;
        double range;
        double rated;
        // ✅ 2026-03-09 [Phase 7.48.26]: 洒水使能（0=禁用, 1=启用）
        int sprinklerEnabled;
    };

    // ✅ 2026-03-07 [Phase 7.48.22]: 通道按截图从上到下顺序分配
    //   前8项 = 模拟量模块1 CH0-CH7，后8项 = 模拟量模块2 CH0-CH7
    //   截图顺序：速度→张力→温度一→温度二→电压→甲烷→一氧化碳→二氧化碳
    //             →硫化氢→氧气→烟雾→粉尘浓度→温度→湿度→煤流→煤仓高度
    // 上限值：Phase 7.48.20 按煤矿安全规程修正
    // 旧映射（Phase 7.48.21）：甲烷/一氧化碳/二氧化碳在模块2，温度/煤流/煤仓高度在模块1，通道号不连续
    // ✅ 2026-03-09 [Phase 7.48.26]: 新增 sprinklerEnabled 字段（烟雾/温度一/温度二/温度=1, 其余=0）
    // ✅ 2026-03-18 [Phase 7.48.53]: 只保留速度/张力/温度一/温度二/电压通道，其余设为未分配(-1)
    //   顺序调整为分组显示：运行参数→温度保护→环境监测
    // ✅ 2026-03-18 [Phase 7.48.54]: 删除张力监测分组（张力已在张紧控制大类的TensionSensorConfigPanel中管理）
    QList<AnalogProtection> protections = {
        // ── 运行参数 ──
        {"速度",       "m/s",   "模拟量模块1", 0, 3.0,    0.5,   5.0,    2.5,   0},  // 模块1 CH0
        {"电压",       "V",     "模拟量模块1", 4, 700.0,  500.0, 660.0,  0.0,   0},  // 模块1 CH4
        // ── 温度保护 ──
        {"温度一",     "℃",    "模拟量模块1", 2, 42.0,   0.0,   100.0,  0.0,   1},  // 模块1 CH2 | 洒水使能
        {"温度二",     "℃",    "模拟量模块1", 3, 42.0,   0.0,   100.0,  0.0,   1},  // 模块1 CH3 | 洒水使能
        // 旧：{"张力", "T", "模拟量模块1", 1, ...}  // 2026-03-18 删除：张力已在张紧控制TensionSensorConfigPanel管理
        // ── 环境监测（默认未分配，按需启用）──
        {"甲烷",       "%CH₄",  "未分配", -1, 1.0,    0.0,   4.0,    0.0,   0},  // 规程≥1.0%
        {"一氧化碳",   "ppm",   "未分配", -1, 24.0,   0.0,   1000.0, 0.0,   0},  // 规程≥24ppm
        {"二氧化碳",   "%CO₂",  "未分配", -1, 1.5,    0.0,   5.0,    0.0,   0},  // 规程>1.5%
        {"硫化氢",     "ppm",   "未分配", -1, 6.6,    0.0,   100.0,  6.6,   0},  // 规程≥6.6ppm
        {"氧气",       "%O₂",   "未分配", -1, 23.5,   0.0,   25.0,   20.0,  0},  // >23.5%富氧
        {"烟雾",       "mg/m³", "未分配", -1, 100.0,  0.0,   1000.0, 500.0, 1},  // 洒水使能
        {"粉尘浓度",   "mg/m³", "未分配", -1, 4.0,    0.0,   1000.0, 100.0, 0},  // 总尘>4mg/m³
        {"温度",       "℃",    "未分配", -1, 34.0,   0.0,   50.0,   26.0,  1},  // 规程>34℃ | 洒水使能
        {"湿度",       "%RH",   "未分配", -1, 95.0,   0.0,   100.0,  95.0,  0},
        {"煤流",       "t/h",   "未分配", -1, 1500.0, 0.0,   2000.0, 500.0, 0},
        {"煤仓高度",   "m",     "未分配", -1, 25.0,   0.0,   30.0,   15.0,  0},
        {"气压",       "kPa",   "未分配", -1, 110.0,  80.0,  40.0,   101.0, 0},
        {"风速",       "m/s",   "未分配", -1, 4.0,    0.3,   14.7,   4.0,   0}
    };

    QSqlQuery query(m_database);
    for (const auto &p : protections) {
        // ✅ 2026-02-28 [Phase 7.47.53]: 修复 - 添加 use_text_to_speech = 0（默认为默认音频）
        // 与initDefaultDigitalProtections保持一致
        // ✅ 2026-03-05 [Phase 7.48.10]: 速度保护额外写入4个专用字段
        if (p.name == "速度") {
            query.prepare(R"(
                INSERT INTO device_analog_protections
                (device_id, protection_name, module_type, register_address, unit,
                 upper_limit, lower_limit, range_value, rated_value, tts_text, use_text_to_speech,
                 speed_start_delay, speed_detect_mode, rated_speed, slip_delay, sprinkler_enabled)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            )");
            query.addBindValue(deviceId);
            query.addBindValue(p.name);
            // ✅ 2026-03-06 [Phase 7.48.12]: 使用结构体中的 moduleType（旧值硬编码"模拟量模块1"）
            query.addBindValue(p.moduleType);
            query.addBindValue(p.registerAddress);
            query.addBindValue(p.unit);
            query.addBindValue(p.upperLimit);
            query.addBindValue(p.lowerLimit);
            query.addBindValue(p.range);
            query.addBindValue(p.rated);
            query.addBindValue(p.name + "保护报警");
            query.addBindValue(0);  // 默认音频
            query.addBindValue(30.0);   // speed_start_delay: 电机启动后延时30秒开始检测
            query.addBindValue("limit"); // speed_detect_mode: 默认上下限模式
            query.addBindValue(p.rated); // rated_speed: 默认等于rated_value（2.5 m/s）
            query.addBindValue(10.0);   // slip_delay: 低速打滑延时10秒
            query.addBindValue(p.sprinklerEnabled);  // ✅ 2026-03-09 [Phase 7.48.26]: 洒水使能
        } else {
            query.prepare(R"(
                INSERT INTO device_analog_protections
                (device_id, protection_name, module_type, register_address, unit,
                 upper_limit, lower_limit, range_value, rated_value, tts_text, use_text_to_speech,
                 sprinkler_enabled)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            )");
            query.addBindValue(deviceId);
            query.addBindValue(p.name);
            // ✅ 2026-03-06 [Phase 7.48.12]: 使用结构体中的 moduleType（旧值硬编码"模拟量模块1"）
            query.addBindValue(p.moduleType);
            query.addBindValue(p.registerAddress);
            query.addBindValue(p.unit);
            query.addBindValue(p.upperLimit);
            query.addBindValue(p.lowerLimit);
            query.addBindValue(p.range);
            query.addBindValue(p.rated);
            query.addBindValue(p.name + "保护报警");
            query.addBindValue(0);  // ✅ 默认为0（使用默认音频）
            query.addBindValue(p.sprinklerEnabled);  // ✅ 2026-03-09 [Phase 7.48.26]: 洒水使能
        }

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
    // ✅ 2026-03-09 [Phase 7.48.26]: 扩展INSERT语句，添加 sprinkler_enabled 列
    // ✅ 2026-03-09: 扩展INSERT语句，添加 sprinkler_index 列
    query.prepare(R"(
        INSERT OR REPLACE INTO device_digital_protections
        (device_id, protection_name, module_type, register_address, channel_number,
         protection_delay, play_count, play_duration, use_text_to_speech, tts_text, audio_file,
         play_mode, protection_level, sprinkler_enabled, sprinkler_index, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
    // ✅ 2026-03-04 [Phase 7.47.96]: 新增保护级别字段（0=紧急停车预警 1=正常停车预警 2=仅预警 3=不处理）
    query.addBindValue(protection.value("protection_level", 1).toInt());
    // ✅ 2026-03-09 [Phase 7.48.26]: 洒水使能
    query.addBindValue(protection.value("sprinkler_enabled", 0).toInt());
    // ✅ 2026-03-09: 洒水索引（0=无洒水, 1-8=洒水1-8）
    query.addBindValue(protection.value("sprinkler_index", 0).toInt());
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

// ✅ 2026-03-18 [Phase 7.48.56]: 按模块类型和通道号加载保护配置（沿线点位保护用）
QVariantMap DeviceConfigManager::loadDigitalProtectionByChannel(const QString &moduleType, int channelNumber)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM device_digital_protections WHERE module_type = ? AND channel_number = ?");
    query.addBindValue(moduleType);
    query.addBindValue(channelNumber);

    if (!query.exec() || !query.next()) {
        return QVariantMap();
    }

    return queryToMap(query);
}

// ✅ 2026-03-18 [Phase 7.48.56]: 加载指定模块类型的所有保护配置（沿线点位保护列表用）
QVariantList DeviceConfigManager::loadDigitalProtectionsByModuleType(const QString &moduleType)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM device_digital_protections WHERE module_type = ? ORDER BY channel_number");
    query.addBindValue(moduleType);

    if (!query.exec()) {
        qWarning() << "加载模块类型" << moduleType << "的保护配置失败:" << query.lastError().text();
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
    // ✅ 2026-03-05 [Phase 7.48.5]: 扩展INSERT语句，添加3个新列
    // ✅ 2026-03-05 [Phase 7.48.10]: 扩展INSERT语句，添加4个速度保护专用列（共25列）
    // ✅ 2026-03-09 [Phase 7.48.26]: 扩展INSERT语句，添加 sprinkler_enabled 列（共26列）
    // ✅ 2026-03-09 [Phase 7.48.27]: 扩展INSERT语句，添加 enabled 列（共27列）
    // ✅ 2026-03-09: 扩展INSERT语句，添加 sprinkler_index 列（共28列）
    query.prepare(R"(
        INSERT OR REPLACE INTO device_analog_protections
        (device_id, protection_name, module_type, register_address, unit,
         upper_limit, lower_limit, range_value, rated_value,
         protection_delay, play_count, play_duration, use_text_to_speech, tts_text, audio_file,
         play_mode, protection_level, data_timeout, connection_timeout, input_type,
         speed_start_delay, speed_detect_mode, rated_speed, slip_delay,
         sprinkler_enabled, enabled, sprinkler_index,
         updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
    // ✅ 2026-03-05 [Phase 7.48.5]: 新增字段
    query.addBindValue(protection.value("play_mode", "count").toString());
    query.addBindValue(protection.value("protection_level", 1).toInt());
    // ✅ 2026-03-07 [Phase 7.48.19]: 审核后更新默认值 data_timeout 30.0→2.0, connection_timeout 60.0→10.0
    // 旧：query.addBindValue(protection.value("data_timeout", 30.0).toDouble());
    // 旧：query.addBindValue(protection.value("connection_timeout", 60.0).toDouble());
    query.addBindValue(protection.value("data_timeout", 2.0).toDouble());
    query.addBindValue(protection.value("connection_timeout", 10.0).toDouble());
    query.addBindValue(protection.value("input_type", "4-20mA").toString());
    // ✅ 2026-03-05 [Phase 7.48.10]: 速度保护专用字段
    query.addBindValue(protection.value("speed_start_delay", 0.0).toDouble());
    query.addBindValue(protection.value("speed_detect_mode", "limit").toString());
    query.addBindValue(protection.value("rated_speed", 0.0).toDouble());
    query.addBindValue(protection.value("slip_delay", 10.0).toDouble());
    // ✅ 2026-03-09 [Phase 7.48.26]: 洒水使能
    query.addBindValue(protection.value("sprinkler_enabled", 0).toInt());
    // ✅ 2026-03-09 [Phase 7.48.27]: 保护启用/禁用
    query.addBindValue(protection.value("enabled", 1).toInt());
    // ✅ 2026-03-09: 洒水索引（0=无洒水, 1-8=洒水1-8）
    query.addBindValue(protection.value("sprinkler_index", 0).toInt());
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
    // ✅ 2026-03-06 [Phase 7.48.13]: 改为 ORDER BY id 保持插入顺序
    // 旧值：ORDER BY register_address（导致 register_address=-1 的风速/粉尘浓度排在最前面）
    query.prepare("SELECT * FROM device_analog_protections WHERE device_id = ? ORDER BY id");
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

// ========== 洒水输出配置 ==========
// ✅ 2026-03-09 [Phase 7.48.26]: 洒水输出配置管理

QVariantMap DeviceConfigManager::loadSprinklerOutputConfig()
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM sprinkler_output_config LIMIT 1");

    if (!query.exec() || !query.next()) {
        // 返回默认配置
        QVariantMap defaultConfig;
        defaultConfig["module_type"] = "继电器模块";
        defaultConfig["channel"] = 7;
        defaultConfig["mqtt_topic"] = "belt_control/relay/module1/control";
        defaultConfig["enabled"] = 1;
        qDebug() << "⚠️ [DeviceConfigManager] 洒水输出配置不存在，返回默认值";
        return defaultConfig;
    }

    return queryToMap(query);
}

bool DeviceConfigManager::saveSprinklerOutputConfig(const QVariantMap &config)
{
    QSqlQuery query(m_database);
    // 先尝试更新，如果不存在则插入
    query.prepare(R"(
        INSERT OR REPLACE INTO sprinkler_output_config
        (id, module_type, channel, mqtt_topic, enabled, updated_at)
        VALUES (1, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    )");
    query.addBindValue(config.value("module_type", "继电器模块").toString());
    query.addBindValue(config.value("channel", 7).toInt());
    query.addBindValue(config.value("mqtt_topic", "belt_control/relay/module1/control").toString());
    query.addBindValue(config.value("enabled", 1).toInt());

    if (!query.exec()) {
        QString error = "保存洒水输出配置失败: " + query.lastError().text();
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    qDebug() << "✅ [DeviceConfigManager] 洒水输出配置已保存";
    return true;
}

// ✅ 2026-03-09: 8个独立洒水装置配置管理

QVariantMap DeviceConfigManager::loadSprinklerConfig(int sprinklerIndex)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM sprinkler_output_config WHERE sprinkler_index = ?");
    query.addBindValue(sprinklerIndex);

    if (!query.exec() || !query.next()) {
        // 返回默认配置
        QVariantMap defaultConfig;
        defaultConfig["sprinkler_index"] = sprinklerIndex;
        defaultConfig["sprinkler_name"] = QString("洒水%1").arg(sprinklerIndex);
        defaultConfig["module_type"] = QString("继电器模块");
        defaultConfig["channel"] = sprinklerIndex - 1;
        defaultConfig["mqtt_topic"] = QString("belt_control/relay/module1/control");
        defaultConfig["enabled"] = 1;
        qDebug() << "⚠️ [DeviceConfigManager] 洒水" << sprinklerIndex << "配置不存在，返回默认值";
        return defaultConfig;
    }

    return queryToMap(query);
}

bool DeviceConfigManager::saveSprinklerConfig(int sprinklerIndex, const QVariantMap &config)
{
    QSqlQuery query(m_database);
    // 先尝试更新
    // ✅ 2026-03-22 [Phase 7.48.74]: 新增startup_delay和stop_delay字段
    // 旧：UPDATE ... SET sprinkler_name = ?, module_type = ?, channel = ?, mqtt_topic = ?, enabled = ?
    query.prepare(R"(
        UPDATE sprinkler_output_config
        SET sprinkler_name = ?, module_type = ?, channel = ?, mqtt_topic = ?, enabled = ?,
            startup_delay = ?, stop_delay = ?, updated_at = CURRENT_TIMESTAMP
        WHERE sprinkler_index = ?
    )");
    query.addBindValue(config.value("sprinkler_name", QString("洒水%1").arg(sprinklerIndex)).toString());
    query.addBindValue(config.value("module_type", "继电器模块").toString());
    query.addBindValue(config.value("channel", sprinklerIndex - 1).toInt());
    query.addBindValue(config.value("mqtt_topic", "belt_control/relay/module1/control").toString());
    query.addBindValue(config.value("enabled", 1).toInt());
    query.addBindValue(config.value("startup_delay", 1).toInt());
    query.addBindValue(config.value("stop_delay", 1).toInt());
    query.addBindValue(sprinklerIndex);

    if (!query.exec()) {
        QString error = QString("保存洒水%1配置失败: %2").arg(sprinklerIndex).arg(query.lastError().text());
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    if (query.numRowsAffected() == 0) {
        // 不存在，插入新记录
        // ✅ 2026-03-22 [Phase 7.48.74]: 新增startup_delay和stop_delay字段
        // 旧：INSERT INTO ... (sprinkler_index, sprinkler_name, module_type, channel, mqtt_topic, enabled)
        query.prepare(R"(
            INSERT INTO sprinkler_output_config (sprinkler_index, sprinkler_name, module_type, channel, mqtt_topic, enabled, startup_delay, stop_delay)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        )");
        query.addBindValue(sprinklerIndex);
        query.addBindValue(config.value("sprinkler_name", QString("洒水%1").arg(sprinklerIndex)).toString());
        query.addBindValue(config.value("module_type", "继电器模块").toString());
        query.addBindValue(config.value("channel", sprinklerIndex - 1).toInt());
        query.addBindValue(config.value("mqtt_topic", "belt_control/relay/module1/control").toString());
        query.addBindValue(config.value("enabled", 1).toInt());
        query.addBindValue(config.value("startup_delay", 1).toInt());
        query.addBindValue(config.value("stop_delay", 1).toInt());

        if (!query.exec()) {
            QString error = QString("插入洒水%1配置失败: %2").arg(sprinklerIndex).arg(query.lastError().text());
            qCritical() << error;
            emit databaseError(error);
            return false;
        }
    }

    qDebug() << "✅ [DeviceConfigManager] 洒水" << sprinklerIndex << "配置已保存";
    return true;
}

QVariantList DeviceConfigManager::loadAllSprinklerConfigs()
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM sprinkler_output_config ORDER BY sprinkler_index");

    if (!query.exec()) {
        qWarning() << "加载所有洒水配置失败:" << query.lastError().text();
        return QVariantList();
    }

    return queryToList(query);
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
    // ✅ 2026-03-10 [Phase 7.48.31]: 扩展为31列（原27列 + 新增4列：running_state, motor_module_address, output_channel, feedback_channel）
    // ✅ 2026-03-10 [Phase 7.48.37]: 扩展为35列（新增4列：startup_delay, warning_voice, failure_voice, startup_key）
    // ✅ 2026-03-12: 扩展为36列（新增1列：audio_source）
    // ✅ 2026-03-21 [Phase 7.48.69]: 扩展为37列（新增1列：use_feedback）
    // 旧：36列 INSERT OR REPLACE
    query.prepare(R"(
        INSERT OR REPLACE INTO device_motor_config
        (device_id, motor_index, tab_index, tab_name, protection_name, protection_delay,
         upper_limit, lower_limit, unit, voice_alarm_enabled, voice_alarm_type,
         tts_text, audio_file, play_count, play_duration,
         module_type, register_address, range_value, input_type,
         data_timeout, connection_timeout, play_mode, protection_level,
         sprinkler_enabled, filter_delay, use_text_to_speech,
         running_state, motor_module_address, output_channel, feedback_channel,
         startup_delay, warning_voice, failure_voice, startup_key,
         audio_source,
         use_feedback,
         stop_delay,
         updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
    // ✅ 2026-03-10 [Phase 7.48.29]: 新增11列绑定值
    query.addBindValue(config.value("module_type", "模拟量模块1").toString());
    query.addBindValue(config.value("register_address", -1).toInt());
    query.addBindValue(config.value("range_value", 100.0).toDouble());
    query.addBindValue(config.value("input_type", "4-20mA电流型").toString());
    query.addBindValue(config.value("data_timeout", 2.0).toDouble());
    query.addBindValue(config.value("connection_timeout", 10.0).toDouble());
    query.addBindValue(config.value("play_mode", "count").toString());
    query.addBindValue(config.value("protection_level", 1).toInt());
    query.addBindValue(config.value("sprinkler_enabled", false).toBool() ? 1 : 0);
    query.addBindValue(config.value("filter_delay", 5.0).toDouble());
    query.addBindValue(config.value("use_text_to_speech", false).toBool() ? 1 : 0);
    // ✅ 2026-03-10 [Phase 7.48.31]: 新增4列绑定值（电机基本配置）
    query.addBindValue(config.value("running_state", "投入").toString());
    query.addBindValue(config.value("motor_module_address", 1).toInt());
    query.addBindValue(config.value("output_channel", -1).toInt());
    query.addBindValue(config.value("feedback_channel", -1).toInt());
    // ✅ 2026-03-10 [Phase 7.48.37]: 新增4列绑定值（启动参数）
    query.addBindValue(config.value("startup_delay", 8).toInt());  // ✅ 2026-03-12: 默认8秒（原5秒）
    query.addBindValue(config.value("warning_voice", "").toString());
    query.addBindValue(config.value("failure_voice", "").toString());
    query.addBindValue(config.value("startup_key", "无").toString());
    // ✅ 2026-03-12: 新增音频来源
    query.addBindValue(config.value("audio_source", "tts").toString());
    // ✅ 2026-03-21 [Phase 7.48.69]: 新增use_feedback
    // 原因：INSERT OR REPLACE 会删除旧行再插入，缺少此列导致use_feedback被重置为DEFAULT 0
    query.addBindValue(config.value("use_feedback", false).toBool() ? 1 : 0);
    // ✅ 2026-03-22 [Phase 7.48.74]: 新增独立停止延时
    query.addBindValue(config.value("stop_delay", 8).toInt());
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
        // ✅ 2026-03-13 [Phase 7.48.43]: 降级为qDebug，避免高频轮询时刷大量WARNING日志
        // 旧：qWarning() << "加载设备" << deviceId << "电机" << motorIndex << "Tab" << tabIndex << "配置失败";
        qDebug() << "加载设备" << deviceId << "电机" << motorIndex << "Tab" << tabIndex << "配置失败";
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

// ✅ 2026-03-10 [Phase 7.48.31]: 删除电机配置（恢复默认值用）
bool DeviceConfigManager::deleteMotorConfig(int deviceId, int motorIndex, int tabIndex)
{
    QSqlQuery query(m_database);
    query.prepare("DELETE FROM device_motor_config WHERE device_id = ? AND motor_index = ? AND tab_index = ?");
    query.addBindValue(deviceId);
    query.addBindValue(motorIndex);
    query.addBindValue(tabIndex);

    if (!query.exec()) {
        qWarning() << "删除设备" << deviceId << "电机" << motorIndex << "Tab" << tabIndex << "配置失败:" << query.lastError().text();
        return false;
    }

    qDebug() << "✅ [DeviceConfigManager] 删除电机配置:" << deviceId << motorIndex << tabIndex;
    emit deviceConfigChanged(deviceId);
    return true;
}

bool DeviceConfigManager::initDefaultMotorConfigs(int deviceId)
{
    // ✅ 2026-03-10 [Phase 7.48.29]: 扩展为14个Tab（原10个 + 新增4个保护类型）
    // 旧：8个电机，每个电机10个Tab
    // 新：8个电机，每个电机14个Tab
    struct MotorTabDefault {
        QString tabName;
        QString unit;
        double upperLimit;
        double lowerLimit;
        double rangeValue;
        QString inputType;
        int protectionDelay;
        double filterDelay;
        int protectionLevel;  // 0=无, 1=预警, 2=预警+正常停车, 3=预警+紧急停车
        bool sprinklerEnabled;
    };

    QList<MotorTabDefault> tabDefaults = {
        // Tab 0: 基本配置（无保护参数）
        {"基本配置",    "A",    0,   0,   100,  "4-20mA电流型",  0,   0,   0, false},
        // Tab 1: 电流保护
        {"电流保护",    "A",    80,  0,   100,  "4-20mA电流型",  30,  5.0,  3, false},
        // Tab 2: 前轴承温度
        {"前轴承温度",  "℃",   60,  0,   150,  "PT100热电阻",   50,  10.0, 3, true},
        // Tab 3: 后轴承温度
        {"后轴承温度",  "℃",   60,  0,   150,  "PT100热电阻",   50,  10.0, 3, true},
        // Tab 4: A相绕组
        // ✅ 2026-03-13 [Phase 7.48.43]: 改为中文名称，TTS无法播报英文字母
        // 旧：{"A相绕组", ...}  {"B相绕组", ...}  {"C相绕组", ...}
        {"甲相绕组",    "℃",   130, 0,   200,  "PT100热电阻",   50,  10.0, 3, false},
        // Tab 5: B相绕组
        {"乙相绕组",    "℃",   130, 0,   200,  "PT100热电阻",   50,  10.0, 3, false},
        // Tab 6: C相绕组
        {"丙相绕组",    "℃",   130, 0,   200,  "PT100热电阻",   50,  10.0, 3, false},
        // Tab 7: 电机温度
        {"电机温度",    "℃",   80,  0,   150,  "PT100热电阻",   50,  10.0, 2, true},
        // Tab 8: X轴振动
        // ✅ 2026-03-13 [Phase 7.48.43]: 改为中文名称，TTS无法播报英文字母
        // 旧：{"X轴振动", ...}  {"Y轴振动", ...}
        {"水平振动",    "mm/s", 7,   0,   20,   "4-20mA电流型",  100, 20.0, 2, false},
        // Tab 9: Y轴振动
        {"垂直振动",    "mm/s", 7,   0,   20,   "4-20mA电流型",  100, 20.0, 2, false},
        // Tab 10: 堵转保护（新增）
        {"堵转保护",    "A",    500, 0,   1000, "4-20mA电流型",  80,  5.0,  3, false},
        // Tab 11: 起动超时（新增）
        {"起动超时",    "A",    300, 0,   500,  "4-20mA电流型",  300, 10.0, 3, false},
        // Tab 12: 功率保护（新增）
        {"功率保护",    "kW",   150, 10,  500,  "4-20mA电流型",  100, 20.0, 2, false},
        // Tab 13: 三相不平衡（新增）
        {"三相不平衡",  "%",    30,  0,   100,  "4-20mA电流型",  100, 20.0, 2, false},
    };

    QSqlQuery query(m_database);
    for (int motorIndex = 0; motorIndex < 8; motorIndex++) {
        for (int tabIndex = 0; tabIndex < tabDefaults.size(); tabIndex++) {
            const auto &def = tabDefaults[tabIndex];
            // ✅ 2026-03-13 [Phase 7.48.43]: protection_name不加电机前缀，避免音频路径重复
            // 旧：QString protectionName = QString("电机%1-%2").arg(motorIndex + 1).arg(def.tabName);
            QString protectionName = def.tabName;

            // ✅ 2026-03-10 [Phase 7.48.31]: 扩展 INSERT 语句，包含基本配置字段
            // ✅ 2026-03-10 [Phase 7.48.37]: 扩展 INSERT 语句，新增启动参数4列
            query.prepare(R"(
                INSERT INTO device_motor_config
                (device_id, motor_index, tab_index, tab_name, protection_name,
                 upper_limit, lower_limit, unit, range_value, input_type,
                 protection_delay, filter_delay, protection_level,
                 sprinkler_enabled, tts_text,
                 running_state, motor_module_address, output_channel, feedback_channel,
                 startup_delay, warning_voice, failure_voice, startup_key)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            )");
            query.addBindValue(deviceId);
            query.addBindValue(motorIndex);
            query.addBindValue(tabIndex);
            query.addBindValue(def.tabName);
            query.addBindValue(protectionName);
            query.addBindValue(def.upperLimit);
            query.addBindValue(def.lowerLimit);
            query.addBindValue(def.unit);
            query.addBindValue(def.rangeValue);
            query.addBindValue(def.inputType);
            query.addBindValue(def.protectionDelay);
            query.addBindValue(def.filterDelay);
            query.addBindValue(def.protectionLevel);
            query.addBindValue(def.sprinklerEnabled ? 1 : 0);
            query.addBindValue(protectionName + "报警");
            // ✅ Phase 7.48.31: Tab 0（基本配置）设置默认输出/反馈通道 = motorIndex
            query.addBindValue("投入");                                    // running_state
            query.addBindValue(1);                                         // motor_module_address
            query.addBindValue(tabIndex == 0 ? motorIndex : -1);           // output_channel
            query.addBindValue(tabIndex == 0 ? motorIndex : -1);           // feedback_channel
            // ✅ Phase 7.48.37: Tab 0（基本配置）设置默认启动参数
            // ✅ 2026-03-11: 改为音频文件名格式（电机X启动/电机X失败）
            query.addBindValue(5);                                                                          // startup_delay
            query.addBindValue(tabIndex == 0 ? QString("电机%1启动").arg(motorIndex + 1) : QString(""));    // warning_voice
            query.addBindValue(tabIndex == 0 ? QString("电机%1失败").arg(motorIndex + 1) : QString(""));    // failure_voice
            query.addBindValue("无");                                                                       // startup_key

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
         voice_alarm_enabled, voice_alarm_type, tts_text, audio_file, play_count, play_duration, updated_at,
         enabled, release_output_channel, brake_output_channel,
         use_release_feedback, release_feedback_channel, release_feedback_timeout,
         use_brake_feedback, brake_feedback_channel, brake_feedback_timeout,
         hold_time, release_time, brake_delay_time, release_delay,
         detect_delay, fault_delay, brake_current, release_current,
         brake_voltage, release_voltage,
         release_warning_voice, release_failure_voice, brake_failure_voice,
         release_startup_delay, brake_startup_delay,
         release_stop_delay, brake_stop_delay)
        -- 旧：VALUES占位符38个，与42列不匹配导致Parameter count mismatch
        -- ✅ 2026-03-22 [Phase 7.48.74.2]: 修正VALUES占位符为42个
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                ?, ?, ?, ?,
                ?, ?)
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
    // 2026-03-14 [Phase 7.48.45]: 新增制动器配置列绑定值
    query.addBindValue(config.value("enabled", true).toBool() ? 1 : 0);
    query.addBindValue(config.value("release_output_channel", 0).toInt());
    query.addBindValue(config.value("brake_output_channel", -1).toInt());
    query.addBindValue(config.value("use_release_feedback", 0).toInt());
    query.addBindValue(config.value("release_feedback_channel", 0).toInt());
    query.addBindValue(config.value("release_feedback_timeout", 10).toInt());
    query.addBindValue(config.value("use_brake_feedback", 0).toInt());
    query.addBindValue(config.value("brake_feedback_channel", 0).toInt());
    query.addBindValue(config.value("brake_feedback_timeout", 10).toInt());
    query.addBindValue(config.value("hold_time", 0).toDouble());
    query.addBindValue(config.value("release_time", 0).toDouble());
    query.addBindValue(config.value("brake_delay", 0).toDouble());
    query.addBindValue(config.value("release_delay", 0).toDouble());
    query.addBindValue(config.value("detect_delay", 0).toDouble());
    query.addBindValue(config.value("fault_delay", 0).toDouble());
    query.addBindValue(config.value("brake_current", 0).toDouble());
    query.addBindValue(config.value("release_current", 0).toDouble());
    query.addBindValue(config.value("brake_voltage", 0).toDouble());
    query.addBindValue(config.value("release_voltage", 0).toDouble());
    query.addBindValue(config.value("release_warning_voice", "").toString());
    query.addBindValue(config.value("release_failure_voice", "").toString());
    query.addBindValue(config.value("brake_failure_voice", "").toString());
    // ✅ 2026-03-21 [Phase 7.48.68]: 新增制动器启动延时字段
    query.addBindValue(config.value("release_startup_delay", 1.0).toDouble());
    query.addBindValue(config.value("brake_startup_delay", 1.0).toDouble());
    // ✅ 2026-03-22 [Phase 7.48.74]: 新增制动器独立停止延时字段
    query.addBindValue(config.value("release_stop_delay", 1.0).toDouble());
    query.addBindValue(config.value("brake_stop_delay", 1.0).toDouble());

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

// ✅ 2026-03-21 [Phase 7.48.68]: 设备逻辑控制配置 CRUD
// 原因：每个设备（12个设备卡片）需要独立的启停逻辑控制配置

QVariantMap DeviceConfigManager::loadDeviceLogicConfig(int deviceId)
{
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM device_logic_configs WHERE device_id = ?");
    query.addBindValue(deviceId);

    if (!query.exec() || !query.next()) {
        qWarning() << "加载设备" << deviceId << "逻辑控制配置失败，返回默认值";
        QVariantMap defaults;
        defaults["device_id"] = deviceId;
        defaults["startup_sequence"] = "[]";
        defaults["stop_sequence"] = "[]";
        defaults["warning_time"] = 10.0;
        defaults["default_delay"] = 1.0;
        return defaults;
    }

    return queryToMap(query);
}

bool DeviceConfigManager::saveDeviceLogicConfig(int deviceId, const QVariantMap &config)
{
    QSqlQuery query(m_database);
    query.prepare(R"(
        INSERT OR REPLACE INTO device_logic_configs
        (device_id, startup_sequence, stop_sequence, warning_time, default_delay)
        VALUES (?, ?, ?, ?, ?)
    )");
    query.addBindValue(deviceId);
    query.addBindValue(config.value("startup_sequence", "[]").toString());
    query.addBindValue(config.value("stop_sequence", "[]").toString());
    query.addBindValue(config.value("warning_time", 10.0).toDouble());
    query.addBindValue(config.value("default_delay", 1.0).toDouble());

    if (!query.exec()) {
        QString error = QString("保存设备%1逻辑控制配置失败: %2")
            .arg(deviceId).arg(query.lastError().text());
        qCritical() << error;
        emit databaseError(error);
        return false;
    }

    qDebug() << "✅ [DeviceConfigManager] 保存设备逻辑控制配置:" << deviceId;
    return true;
}

// ✅ 2026-03-21 [Phase 7.48.68]: 启动延时快捷更新方法
// 原因：逻辑控制面板修改延时时需要同步写回设备配置表

bool DeviceConfigManager::updateMotorStartupDelay(int deviceId, int motorIndex, double delay)
{
    QSqlQuery query(m_database);
    query.prepare("UPDATE device_motor_config SET startup_delay = ? WHERE device_id = ? AND motor_index = ? AND tab_index = 0");
    query.addBindValue(delay);
    query.addBindValue(deviceId);
    query.addBindValue(motorIndex);
    bool ok = query.exec();
    if (ok) qDebug() << "✅ 更新电机启动延时:" << deviceId << motorIndex << delay;
    else qWarning() << "❌ 更新电机启动延时失败:" << query.lastError().text();
    return ok;
}

bool DeviceConfigManager::updateBrakeStartupDelay(int deviceId, int brakeIndex, double delay, const QString &type)
{
    QSqlQuery query(m_database);
    if (type == "release") {
        query.prepare("UPDATE device_brake_config SET release_startup_delay = ? WHERE device_id = ? AND brake_index = ?");
    } else {
        query.prepare("UPDATE device_brake_config SET brake_startup_delay = ? WHERE device_id = ? AND brake_index = ?");
    }
    query.addBindValue(delay);
    query.addBindValue(deviceId);
    query.addBindValue(brakeIndex);
    bool ok = query.exec();
    if (ok) qDebug() << "✅ 更新制动器启动延时:" << deviceId << brakeIndex << type << delay;
    else qWarning() << "❌ 更新制动器启动延时失败:" << query.lastError().text();
    return ok;
}

bool DeviceConfigManager::updateTensionStartupDelay(int deviceId, int tensionIndex, double delay)
{
    QSqlQuery query(m_database);
    query.prepare("UPDATE device_tension_config SET startup_delay = ? WHERE device_id = ? AND tension_index = ?");
    query.addBindValue(delay);
    query.addBindValue(deviceId);
    query.addBindValue(tensionIndex);
    bool ok = query.exec();
    if (ok) qDebug() << "✅ 更新张紧启动延时:" << deviceId << tensionIndex << delay;
    else qWarning() << "❌ 更新张紧启动延时失败:" << query.lastError().text();
    return ok;
}

// ✅ 2026-03-22 [Phase 7.48.74]: 停止延时快捷更新方法
// 原因：逻辑控制面板修改停止延时时需要同步写回设备配置表

bool DeviceConfigManager::updateMotorStopDelay(int deviceId, int motorIndex, double delay)
{
    QSqlQuery query(m_database);
    query.prepare("UPDATE device_motor_config SET stop_delay = ? WHERE device_id = ? AND motor_index = ? AND tab_index = 0");
    query.addBindValue(delay);
    query.addBindValue(deviceId);
    query.addBindValue(motorIndex);
    bool ok = query.exec();
    if (ok) qDebug() << "✅ 更新电机停止延时:" << deviceId << motorIndex << delay;
    else qWarning() << "❌ 更新电机停止延时失败:" << query.lastError().text();
    return ok;
}

bool DeviceConfigManager::updateBrakeStopDelay(int deviceId, int brakeIndex, double delay, const QString &type)
{
    QSqlQuery query(m_database);
    if (type == "release") {
        query.prepare("UPDATE device_brake_config SET release_stop_delay = ? WHERE device_id = ? AND brake_index = ?");
    } else {
        query.prepare("UPDATE device_brake_config SET brake_stop_delay = ? WHERE device_id = ? AND brake_index = ?");
    }
    query.addBindValue(delay);
    query.addBindValue(deviceId);
    query.addBindValue(brakeIndex);
    bool ok = query.exec();
    if (ok) qDebug() << "✅ 更新制动器停止延时:" << deviceId << brakeIndex << type << delay;
    else qWarning() << "❌ 更新制动器停止延时失败:" << query.lastError().text();
    return ok;
}

bool DeviceConfigManager::updateTensionStopDelay(int deviceId, int tensionIndex, double delay)
{
    QSqlQuery query(m_database);
    query.prepare("UPDATE device_tension_config SET stop_delay = ? WHERE device_id = ? AND tension_index = ?");
    query.addBindValue(delay);
    query.addBindValue(deviceId);
    query.addBindValue(tensionIndex);
    bool ok = query.exec();
    if (ok) qDebug() << "✅ 更新张紧停止延时:" << deviceId << tensionIndex << delay;
    else qWarning() << "❌ 更新张紧停止延时失败:" << query.lastError().text();
    return ok;
}

bool DeviceConfigManager::updateSprinklerStartupDelay(int sprinklerIndex, double delay)
{
    QSqlQuery query(m_database);
    query.prepare("UPDATE sprinkler_output_config SET startup_delay = ? WHERE sprinkler_index = ?");
    query.addBindValue(delay);
    query.addBindValue(sprinklerIndex);
    bool ok = query.exec();
    if (ok) qDebug() << "✅ 更新洒水启动延时:" << sprinklerIndex << delay;
    else qWarning() << "❌ 更新洒水启动延时失败:" << query.lastError().text();
    return ok;
}

bool DeviceConfigManager::updateSprinklerStopDelay(int sprinklerIndex, double delay)
{
    QSqlQuery query(m_database);
    query.prepare("UPDATE sprinkler_output_config SET stop_delay = ? WHERE sprinkler_index = ?");
    query.addBindValue(delay);
    query.addBindValue(sprinklerIndex);
    bool ok = query.exec();
    if (ok) qDebug() << "✅ 更新洒水停止延时:" << sprinklerIndex << delay;
    else qWarning() << "❌ 更新洒水停止延时失败:" << query.lastError().text();
    return ok;
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
    // 2026-03-16 [Phase 7.48.46]: 重写保存函数，字段与QML collectConfig()完全对应
    // ✅ 2026-03-18 [Phase 7.48.53]: 新增startup_delay和audio_source字段
    query.prepare(R"(
        INSERT OR REPLACE INTO device_tension_config
        (device_id, tension_index, enabled, protection_name, unit, protection_type, protection_delay,
         module_type, play_count, register_address, play_duration, channel_number,
         upper_limit, lower_limit, range_value, rated_value,
         output_channel, use_feedback, feedback_channel, feedback_timeout,
         use_text_to_speech, tts_text, audio_file, warning_voice, failure_voice,
         startup_delay, audio_source, stop_delay, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    )");

    query.addBindValue(deviceId);
    query.addBindValue(tensionIndex);
    query.addBindValue(config.value("enabled", true).toBool() ? 1 : 0);
    query.addBindValue(config.value("protection_name", "").toString());
    query.addBindValue(config.value("unit", "kN").toString());
    query.addBindValue(config.value("protection_type", "上限报警").toString());
    query.addBindValue(config.value("protection_delay", 10.0).toDouble());
    query.addBindValue(config.value("module_type", "模拟量模块1").toString());
    query.addBindValue(config.value("play_count", 1).toInt());
    query.addBindValue(config.value("register_address", -1).toInt());
    query.addBindValue(config.value("play_duration", 5.0).toDouble());
    query.addBindValue(config.value("channel_number", 0).toInt());
    query.addBindValue(config.value("upper_limit", 100.0).toDouble());
    query.addBindValue(config.value("lower_limit", 0.0).toDouble());
    query.addBindValue(config.value("range_value", 100.0).toDouble());
    query.addBindValue(config.value("rated_value", 50.0).toDouble());
    query.addBindValue(config.value("output_channel", 0).toInt());
    query.addBindValue(config.value("use_feedback", false).toBool() ? 1 : 0);
    query.addBindValue(config.value("feedback_channel", 0).toInt());
    query.addBindValue(config.value("feedback_timeout", 10).toInt());
    query.addBindValue(config.value("use_text_to_speech", false).toBool() ? 1 : 0);
    query.addBindValue(config.value("tts_text", "").toString());
    query.addBindValue(config.value("audio_file", "").toString());
    query.addBindValue(config.value("warning_voice", "").toString());
    query.addBindValue(config.value("failure_voice", "").toString());
    // ✅ 2026-03-18 [Phase 7.48.53]: 新增字段
    query.addBindValue(config.value("startup_delay", 5).toInt());
    query.addBindValue(config.value("audio_source", "default").toString());
    // ✅ 2026-03-22 [Phase 7.48.74]: 新增独立停止延时
    query.addBindValue(config.value("stop_delay", 5).toInt());
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
    // 2026-03-16 [Phase 7.48.46]: 重写默认配置，与新表结构对应
    QSqlQuery query(m_database);
    for (int tensionIndex = 0; tensionIndex < 2; tensionIndex++) {
        QString tensionName = QString("张紧装置%1").arg(tensionIndex + 1);

        query.prepare(R"(
            INSERT INTO device_tension_config
            (device_id, tension_index, enabled, protection_name, unit, protection_type,
             protection_delay, module_type, play_count, register_address, play_duration,
             channel_number, upper_limit, lower_limit, range_value, rated_value,
             output_channel, use_feedback, feedback_channel, feedback_timeout,
             use_text_to_speech, tts_text, warning_voice, failure_voice)
            VALUES (?, ?, 1, ?, 'kN', '上限报警', 10.0, '模拟量模块1', 1, -1, 5.0,
                    0, 100.0, 0.0, 100.0, 50.0, 0, 1, 0, 10, 0, ?, '', '')
        )");
        // ✅ 2026-03-21 [Phase 7.48.66]: use_feedback 改为 1（原来是0，导致反馈检测不启动）
        query.addBindValue(deviceId);
        query.addBindValue(tensionIndex);
        query.addBindValue(tensionName);
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
