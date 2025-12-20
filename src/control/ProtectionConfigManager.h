#ifndef PROTECTIONCONFIGMANAGER_H
#define PROTECTIONCONFIGMANAGER_H

#include <QObject>
#include <QSqlDatabase>
#include <QMap>
#include "ProtectionConfig.h"

class SystemConfig;  // 前向声明

/**
 * @brief 保护配置管理器 - 负责保护配置的持久化存储和管理
 *
 * 功能：
 * - 使用 SQLite 数据库存储保护配置
 * - 提供保存、加载、查询、更新、删除接口
 * - 支持 QML 调用
 */
class ProtectionConfigManager : public QObject
{
    Q_OBJECT

public:
    explicit ProtectionConfigManager(QObject *parent = nullptr);
    ~ProtectionConfigManager();

    // 初始化数据库
    bool initialize(const QString &dbPath = "protection_config.db");

    // 设置系统配置（用于获取皮带号）
    void setSystemConfig(SystemConfig *config);

    // 配置管理接口
    Q_INVOKABLE bool saveConfig(const QString &name, const ProtectionConfig &config);
    Q_INVOKABLE ProtectionConfig loadConfig(const QString &name);
    Q_INVOKABLE bool deleteConfig(const QString &name);
    Q_INVOKABLE QStringList getAllProtectionNames();
    Q_INVOKABLE bool configExists(const QString &name);

    // QML友好接口 - 使用QVariantMap传递配置数据
    Q_INVOKABLE QVariantMap loadConfigAsMap(const QString &name);
    Q_INVOKABLE bool saveConfigFromMap(const QString &name, const QVariantMap &configMap);

    // 批量操作
    Q_INVOKABLE bool saveAllConfigs(const QMap<QString, ProtectionConfig> &configs);
    Q_INVOKABLE QMap<QString, ProtectionConfig> loadAllConfigs();

    // 加载默认配置（首次使用时）
    Q_INVOKABLE void loadDefaultConfigs();

    // 迁移音频文件路径（修复旧数据）
    Q_INVOKABLE void migrateAudioFilePaths();

signals:
    void configSaved(const QString &name);
    void configLoaded(const QString &name);
    void configDeleted(const QString &name);
    void databaseError(const QString &error);

private:
    QSqlDatabase m_database;
    QString m_dbPath;
    SystemConfig *m_systemConfig;  // 系统配置（用于获取皮带号）

    // 数据库操作辅助函数
    bool createTables();
    bool insertConfig(const QString &name, const ProtectionConfig &config);
    bool updateConfig(const QString &name, const ProtectionConfig &config);
    ProtectionConfig queryConfig(const QString &name);

    // 创建默认保护配置
    ProtectionConfig createDefaultDigitalConfig(const QString &name, int channel);
    ProtectionConfig createDefaultAnalogConfig(const QString &name, int registerAddr, const QString &unit);
};

#endif // PROTECTIONCONFIGMANAGER_H
