#ifndef DEVICECONFIGMANAGER_H
#define DEVICECONFIGMANAGER_H

#include <QObject>
#include <QSqlDatabase>
#include <QVariantMap>
#include <QVariantList>

/**
 * @brief 设备配置管理器 - 负责12个设备的独立配置持久化存储
 *
 * 功能：
 * - 使用 SQLite 数据库存储设备配置
 * - 支持12个设备（4x3网格）的独立配置
 * - 管理基本配置、开关量保护、模拟量保护
 * - 提供 QML 友好的接口
 *
 * 数据库表结构：
 * - devices: 设备基本信息
 * - device_basic_config: 基本配置参数
 * - device_digital_protections: 开关量保护配置
 * - device_analog_protections: 模拟量保护配置
 *
 * @date 2026-01-25
 * @version 1.0
 */
class DeviceConfigManager : public QObject
{
    Q_OBJECT

public:
    explicit DeviceConfigManager(QObject *parent = nullptr);
    ~DeviceConfigManager();

    // ========== 数据库初始化 ==========

    /**
     * @brief 初始化数据库
     * @param dbPath 数据库文件路径
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool initDatabase(const QString &dbPath = "device_config.db");

    /**
     * @brief 创建数据库表
     * @return 成功返回true，失败返回false
     */
    bool createTables();

    // ✅ 2026-02-28 [Phase 7.47.52]: 数据库迁移，修复历史数据
    void runMigrations();

    /**
     * @brief 初始化12个设备的默认数据
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool initDefaultData();

    // ========== 设备管理 ==========

    /**
     * @brief 保存设备信息
     * @param deviceId 设备ID（1-12）
     * @param deviceName 设备名称
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool saveDevice(int deviceId, const QString &deviceName);

    /**
     * @brief 加载设备信息
     * @param deviceId 设备ID（1-12）
     * @return 设备信息（QVariantMap）
     */
    Q_INVOKABLE QVariantMap loadDevice(int deviceId);

    /**
     * @brief 加载所有设备信息
     * @return 设备列表（QVariantList）
     */
    Q_INVOKABLE QVariantList loadAllDevices();

    // ========== 基本配置 ==========

    /**
     * @brief 保存基本配置参数
     * @param deviceId 设备ID（1-12）
     * @param paramName 参数名称
     * @param value 参数值
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool saveBasicConfig(int deviceId, const QString &paramName, const QVariant &value);

    /**
     * @brief 加载基本配置参数
     * @param deviceId 设备ID（1-12）
     * @param paramName 参数名称
     * @return 参数值
     */
    Q_INVOKABLE QVariant loadBasicConfig(int deviceId, const QString &paramName);

    /**
     * @brief 加载设备的所有基本配置
     * @param deviceId 设备ID（1-12）
     * @return 配置参数（QVariantMap）
     */
    Q_INVOKABLE QVariantMap loadAllBasicConfig(int deviceId);

    // ========== 开关量保护 ==========

    /**
     * @brief 保存开关量保护配置
     * @param deviceId 设备ID（1-12）
     * @param protection 保护配置（QVariantMap）
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool saveDigitalProtection(int deviceId, const QVariantMap &protection);

    /**
     * @brief 加载开关量保护配置
     * @param deviceId 设备ID（1-12）
     * @param protectionName 保护名称
     * @return 保护配置（QVariantMap）
     */
    Q_INVOKABLE QVariantMap loadDigitalProtection(int deviceId, const QString &protectionName);

    /**
     * @brief 加载设备的所有开关量保护配置
     * @param deviceId 设备ID（1-12）
     * @return 保护配置列表（QVariantList）
     */
    Q_INVOKABLE QVariantList loadAllDigitalProtections(int deviceId);

    /**
     * @brief 按模块类型和通道号加载开关量保护配置
     * @param moduleType 模块类型（如"CS模块"）
     * @param channelNumber 通道号
     * @return 保护配置（QVariantMap）
     * @date 2026-03-18 [Phase 7.48.56]
     */
    Q_INVOKABLE QVariantMap loadDigitalProtectionByChannel(const QString &moduleType, int channelNumber);

    /**
     * @brief 加载指定模块类型的所有保护配置
     * @param moduleType 模块类型（如"CS模块"）
     * @return 保护配置列表（QVariantList）
     * @date 2026-03-18 [Phase 7.48.56]
     */
    Q_INVOKABLE QVariantList loadDigitalProtectionsByModuleType(const QString &moduleType);

    /**
     * @brief 删除开关量保护配置
     * @param deviceId 设备ID（1-12）
     * @param protectionName 保护名称
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool deleteDigitalProtection(int deviceId, const QString &protectionName);

    // ========== 模拟量保护 ==========

    /**
     * @brief 保存模拟量保护配置
     * @param deviceId 设备ID（1-12）
     * @param protection 保护配置（QVariantMap）
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool saveAnalogProtection(int deviceId, const QVariantMap &protection);

    /**
     * @brief 加载模拟量保护配置
     * @param deviceId 设备ID（1-12）
     * @param protectionName 保护名称
     * @return 保护配置（QVariantMap）
     */
    Q_INVOKABLE QVariantMap loadAnalogProtection(int deviceId, const QString &protectionName);

    /**
     * @brief 加载设备的所有模拟量保护配置
     * @param deviceId 设备ID（1-12）
     * @return 保护配置列表（QVariantList）
     */
    Q_INVOKABLE QVariantList loadAllAnalogProtections(int deviceId);

    /**
     * @brief 删除模拟量保护配置
     * @param deviceId 设备ID（1-12）
     * @param protectionName 保护名称
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool deleteAnalogProtection(int deviceId, const QString &protectionName);

    // ========== 洒水输出配置 ==========
    // ✅ 2026-03-09 [Phase 7.48.26]: 洒水输出配置管理

    /**
     * @brief 加载洒水输出配置
     * @return 洒水输出配置（QVariantMap）
     */
    Q_INVOKABLE QVariantMap loadSprinklerOutputConfig();

    /**
     * @brief 保存洒水输出配置
     * @param config 配置参数（QVariantMap）
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool saveSprinklerOutputConfig(const QVariantMap &config);

    // ✅ 2026-03-09: 洒水控制系统（8个独立洒水装置）

    /**
     * @brief 加载指定洒水配置（1-8）
     * @param sprinklerIndex 洒水索引（1-8）
     * @return 洒水配置（QVariantMap）
     */
    Q_INVOKABLE QVariantMap loadSprinklerConfig(int sprinklerIndex);

    /**
     * @brief 保存指定洒水配置（1-8）
     * @param sprinklerIndex 洒水索引（1-8）
     * @param config 配置参数（QVariantMap）
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool saveSprinklerConfig(int sprinklerIndex, const QVariantMap &config);

    /**
     * @brief 加载所有8个洒水配置
     * @return 洒水配置列表（QVariantList）
     */
    Q_INVOKABLE QVariantList loadAllSprinklerConfigs();

    // ========== 实时状态更新 ==========

    /**
     * @brief 更新保护激活状态
     * @param deviceId 设备ID（1-12）
     * @param protectionName 保护名称
     * @param active 激活状态
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool updateProtectionActive(int deviceId, const QString &protectionName, bool active);

    /**
     * @brief 更新模拟量当前值
     * @param deviceId 设备ID（1-12）
     * @param protectionName 保护名称
     * @param value 当前值
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool updateAnalogValue(int deviceId, const QString &protectionName, double value);

    // ========== 电机配置 ==========
    // ✅ 2026-02-02 [参数持久化]: 添加电机配置管理方法

    /**
     * @brief 保存电机配置
     * @param deviceId 设备ID（1-12）
     * @param motorIndex 电机索引（0-7，对应1-8号电机）
     * @param tabIndex Tab索引（0-9）
     * @param config 配置参数（QVariantMap）
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool saveMotorConfig(int deviceId, int motorIndex, int tabIndex, const QVariantMap &config);

    /**
     * @brief 加载电机配置
     * @param deviceId 设备ID（1-12）
     * @param motorIndex 电机索引（0-7）
     * @param tabIndex Tab索引（0-9）
     * @return 配置参数（QVariantMap）
     */
    Q_INVOKABLE QVariantMap loadMotorConfig(int deviceId, int motorIndex, int tabIndex);

    /**
     * @brief 加载电机的所有Tab配置
     * @param deviceId 设备ID（1-12）
     * @param motorIndex 电机索引（0-7）
     * @return 配置列表（QVariantList）
     */
    Q_INVOKABLE QVariantList loadAllMotorConfigs(int deviceId, int motorIndex);

    // ✅ 2026-03-10 [Phase 7.48.31]: 删除电机配置（恢复默认值用）
    Q_INVOKABLE bool deleteMotorConfig(int deviceId, int motorIndex, int tabIndex);

    // ========== 制动器配置 ==========
    // ✅ 2026-02-02 [参数持久化]: 添加制动器配置管理方法

    /**
     * @brief 保存制动器配置
     * @param deviceId 设备ID（1-12）
     * @param brakeIndex 制动器索引（0-3）
     * @param config 配置参数（QVariantMap）
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool saveBrakeConfig(int deviceId, int brakeIndex, const QVariantMap &config);

    /**
     * @brief 加载制动器配置
     * @param deviceId 设备ID（1-12）
     * @param brakeIndex 制动器索引（0-3）
     * @return 配置参数（QVariantMap）
     */
    Q_INVOKABLE QVariantMap loadBrakeConfig(int deviceId, int brakeIndex);

    /**
     * @brief 加载设备的所有制动器配置
     * @param deviceId 设备ID（1-12）
     * @return 配置列表（QVariantList）
     */
    Q_INVOKABLE QVariantList loadAllBrakeConfigs(int deviceId);

    // ✅ 2026-03-21 [Phase 7.48.68]: 设备逻辑控制配置
    Q_INVOKABLE QVariantMap loadDeviceLogicConfig(int deviceId);
    Q_INVOKABLE bool saveDeviceLogicConfig(int deviceId, const QVariantMap &config);

    // ✅ 2026-03-21 [Phase 7.48.68]: 启动延时快捷更新（逻辑控制↔设备配置双向同步）
    Q_INVOKABLE bool updateMotorStartupDelay(int deviceId, int motorIndex, double delay);
    Q_INVOKABLE bool updateBrakeStartupDelay(int deviceId, int brakeIndex, double delay, const QString &type = "release");
    Q_INVOKABLE bool updateTensionStartupDelay(int deviceId, int tensionIndex, double delay);

    // ✅ 2026-03-22 [Phase 7.48.74]: 停止延时快捷更新
    Q_INVOKABLE bool updateMotorStopDelay(int deviceId, int motorIndex, double delay);
    Q_INVOKABLE bool updateBrakeStopDelay(int deviceId, int brakeIndex, double delay, const QString &type = "release");
    Q_INVOKABLE bool updateTensionStopDelay(int deviceId, int tensionIndex, double delay);
    Q_INVOKABLE bool updateSprinklerStartupDelay(int sprinklerIndex, double delay);
    Q_INVOKABLE bool updateSprinklerStopDelay(int sprinklerIndex, double delay);

    // ========== 张紧控制配置 ==========
    // ✅ 2026-02-02 [参数持久化]: 添加张紧控制配置管理方法

    /**
     * @brief 保存张紧控制配置
     * @param deviceId 设备ID（1-12）
     * @param tensionIndex 张紧装置索引（0-1）
     * @param config 配置参数（QVariantMap）
     * @return 成功返回true，失败返回false
     */
    Q_INVOKABLE bool saveTensionConfig(int deviceId, int tensionIndex, const QVariantMap &config);

    /**
     * @brief 加载张紧控制配置
     * @param deviceId 设备ID（1-12）
     * @param tensionIndex 张紧装置索引（0-1）
     * @return 配置参数（QVariantMap）
     */
    Q_INVOKABLE QVariantMap loadTensionConfig(int deviceId, int tensionIndex);

    /**
     * @brief 加载设备的所有张紧控制配置
     * @param deviceId 设备ID（1-12）
     * @return 配置列表（QVariantList）
     */
    Q_INVOKABLE QVariantList loadAllTensionConfigs(int deviceId);

signals:
    /**
     * @brief 设备配置变化信号
     * @param deviceId 设备ID
     */
    void deviceConfigChanged(int deviceId);

    /**
     * @brief 保护激活状态变化信号
     * @param deviceId 设备ID
     * @param protectionName 保护名称
     * @param active 激活状态
     */
    void protectionActiveChanged(int deviceId, QString protectionName, bool active);

    /**
     * @brief 模拟量值变化信号
     * @param deviceId 设备ID
     * @param protectionName 保护名称
     * @param value 当前值
     */
    void analogValueChanged(int deviceId, QString protectionName, double value);

    /**
     * @brief 数据库错误信号
     * @param error 错误信息
     */
    void databaseError(const QString &error);

private:
    QSqlDatabase m_database;
    QString m_dbPath;

    // ========== 辅助函数 ==========

    /**
     * @brief 执行SQL查询
     * @param query SQL查询语句
     * @param params 参数列表
     * @return 成功返回true，失败返回false
     */
    bool executeQuery(const QString &query, const QVariantList &params = QVariantList());

    /**
     * @brief 将查询结果转换为QVariantMap
     * @param query SQL查询对象
     * @return QVariantMap
     */
    QVariantMap queryToMap(class QSqlQuery &query);

    /**
     * @brief 将查询结果转换为QVariantList
     * @param query SQL查询对象
     * @return QVariantList
     */
    QVariantList queryToList(class QSqlQuery &query);

    /**
     * @brief 初始化设备的默认开关量保护
     * @param deviceId 设备ID（1-12）
     * @return 成功返回true，失败返回false
     */
    bool initDefaultDigitalProtections(int deviceId);

    /**
     * @brief 初始化设备的默认模拟量保护
     * @param deviceId 设备ID（1-12）
     * @return 成功返回true，失败返回false
     */
    bool initDefaultAnalogProtections(int deviceId);

    /**
     * @brief 初始化设备的默认电机配置
     * @param deviceId 设备ID（1-12）
     * @return 成功返回true，失败返回false
     * @note 2026-02-02 [参数持久化]: 新增电机配置初始化
     */
    bool initDefaultMotorConfigs(int deviceId);

    /**
     * @brief 初始化设备的默认制动器配置
     * @param deviceId 设备ID（1-12）
     * @return 成功返回true，失败返回false
     * @note 2026-02-02 [参数持久化]: 新增制动器配置初始化
     */
    bool initDefaultBrakeConfigs(int deviceId);

    /**
     * @brief 初始化设备的默认张紧控制配置
     * @param deviceId 设备ID（1-12）
     * @return 成功返回true，失败返回false
     * @note 2026-02-02 [参数持久化]: 新增张紧控制配置初始化
     */
    bool initDefaultTensionConfigs(int deviceId);
};

#endif // DEVICECONFIGMANAGER_H
