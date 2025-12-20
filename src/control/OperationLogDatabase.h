#ifndef OPERATIONLOGDATABASE_H
#define OPERATIONLOGDATABASE_H

#include <QObject>
#include <QSqlDatabase>
#include <QDateTime>
#include <QVariantList>

/**
 * @brief 运行日志数据库类 - 永久保存设备运行操作记录
 *
 * 功能：
 * - 记录工作模式（检修、就地、点动、集控）
 * - 记录启动方式（按键、远程等）
 * - 记录预警时间
 * - 记录设备启动/停止时间
 * - 提供查询接口给QML显示
 */
class OperationLogDatabase : public QObject
{
    Q_OBJECT

public:
    explicit OperationLogDatabase(QObject *parent = nullptr);
    ~OperationLogDatabase();

    // 初始化数据库（创建表等）
    bool initialize();

public slots:
    // 记录日志的方法（供C++调用）
    void logOperation(const QString &workMode,
                     const QString &triggerType,
                     const QString &operation,
                     const QString &deviceName = "",
                     const QString &detail = "");

    // 记录预警
    void logWarning(const QString &workMode, const QString &detail = "");

    // 记录设备启动
    void logDeviceStart(const QString &workMode, const QString &deviceName);

    // 记录设备停止
    void logDeviceStop(const QString &workMode, const QString &deviceName);

    // 查询最近的日志（供QML调用）
    Q_INVOKABLE QVariantList getRecentLogs(int limit = 100);

    // 按日期范围查询
    Q_INVOKABLE QVariantList getLogsByDateRange(const QDateTime &startDate,
                                                const QDateTime &endDate);

    // 清除旧日志（保留最近N天）
    Q_INVOKABLE void clearOldLogs(int daysToKeep = 30);

    // 获取日志总数
    Q_INVOKABLE int getLogCount();

signals:
    // 新日志添加信号（供QML监听更新）
    void logAdded(const QString &timestamp,
                  const QString &workMode,
                  const QString &triggerType,
                  const QString &operation,
                  const QString &deviceName,
                  const QString &detail);

private:
    QSqlDatabase m_database;

    // 创建表结构
    bool createTables();

    // 插入日志记录
    bool insertLog(const QString &workMode,
                   const QString &triggerType,
                   const QString &operation,
                   const QString &deviceName,
                   const QString &detail);
};

#endif // OPERATIONLOGDATABASE_H
