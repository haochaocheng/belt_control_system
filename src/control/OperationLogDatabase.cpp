#include "OperationLogDatabase.h"
#include "DataPathConfig.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QVariant>
#include <QDebug>
#include <QCoreApplication>
#include <QDir>

OperationLogDatabase::OperationLogDatabase(QObject *parent)
    : QObject(parent)
{
}

OperationLogDatabase::~OperationLogDatabase()
{
    if (m_database.isOpen()) {
        m_database.close();
    }
}

bool OperationLogDatabase::initialize()
{
    // 使用统一数据目录配置
    QString dbPath = DataPathConfig::getOperationLogDbPath();
    qDebug() << "📂 OperationLogDatabase: 数据库路径:" << dbPath;

    // 创建数据库连接
    m_database = QSqlDatabase::addDatabase("QSQLITE", "operation_logs_connection");
    m_database.setDatabaseName(dbPath);

    if (!m_database.open()) {
        qCritical() << "❌ OperationLogDatabase: 无法打开数据库:" << m_database.lastError().text();
        return false;
    }

    qDebug() << "✅ OperationLogDatabase: 数据库连接成功";

    // 创建表结构
    if (!createTables()) {
        qCritical() << "❌ OperationLogDatabase: 创建表失败";
        return false;
    }

    return true;
}

bool OperationLogDatabase::createTables()
{
    QSqlQuery query(m_database);

    // 创建运行日志表
    QString createTableSQL = R"(
        CREATE TABLE IF NOT EXISTS operation_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            work_mode TEXT NOT NULL,
            trigger_type TEXT NOT NULL,
            operation TEXT NOT NULL,
            device_name TEXT,
            detail TEXT
        )
    )";

    if (!query.exec(createTableSQL)) {
        qCritical() << "❌ OperationLogDatabase: 创建表失败:" << query.lastError().text();
        return false;
    }

    // 创建索引（按时间倒序查询优化）
    QString createIndexSQL = R"(
        CREATE INDEX IF NOT EXISTS idx_timestamp ON operation_logs(timestamp DESC)
    )";

    if (!query.exec(createIndexSQL)) {
        qWarning() << "⚠️ OperationLogDatabase: 创建索引失败:" << query.lastError().text();
    }

    qDebug() << "✅ OperationLogDatabase: 表结构创建成功";
    return true;
}

bool OperationLogDatabase::insertLog(const QString &workMode,
                                    const QString &triggerType,
                                    const QString &operation,
                                    const QString &deviceName,
                                    const QString &detail)
{
    QSqlQuery query(m_database);
    query.prepare(R"(
        INSERT INTO operation_logs (work_mode, trigger_type, operation, device_name, detail)
        VALUES (:work_mode, :trigger_type, :operation, :device_name, :detail)
    )");

    query.bindValue(":work_mode", workMode);
    query.bindValue(":trigger_type", triggerType);
    query.bindValue(":operation", operation);
    query.bindValue(":device_name", deviceName);
    query.bindValue(":detail", detail);

    if (!query.exec()) {
        qCritical() << "❌ OperationLogDatabase: 插入日志失败:" << query.lastError().text();
        return false;
    }

    // 获取当前时间戳
    QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss");

    // 发出信号通知QML
    emit logAdded(timestamp, workMode, triggerType, operation, deviceName, detail);

    return true;
}

void OperationLogDatabase::logOperation(const QString &workMode,
                                       const QString &triggerType,
                                       const QString &operation,
                                       const QString &deviceName,
                                       const QString &detail)
{
    insertLog(workMode, triggerType, operation, deviceName, detail);
    qDebug() << "📝 OperationLogDatabase: 记录操作 -"
             << "模式:" << workMode
             << "触发:" << triggerType
             << "操作:" << operation
             << "设备:" << deviceName
             << "详情:" << detail;
}

void OperationLogDatabase::logWarning(const QString &workMode, const QString &detail)
{
    insertLog(workMode, "系统", "起车预警", "", detail);
    qDebug() << "⚠️ OperationLogDatabase: 记录预警 - 模式:" << workMode << "详情:" << detail;
}

void OperationLogDatabase::logDeviceStart(const QString &workMode, const QString &deviceName)
{
    insertLog(workMode, "系统", "设备启动", deviceName, "");
    qDebug() << "▶️ OperationLogDatabase: 记录设备启动 - 模式:" << workMode << "设备:" << deviceName;
}

void OperationLogDatabase::logDeviceStop(const QString &workMode, const QString &deviceName)
{
    insertLog(workMode, "系统", "设备停止", deviceName, "");
    qDebug() << "⏹️ OperationLogDatabase: 记录设备停止 - 模式:" << workMode << "设备:" << deviceName;
}

QVariantList OperationLogDatabase::getRecentLogs(int limit)
{
    QVariantList logs;
    QSqlQuery query(m_database);

    query.prepare(R"(
        SELECT timestamp, work_mode, trigger_type, operation, device_name, detail
        FROM operation_logs
        ORDER BY timestamp DESC
        LIMIT :limit
    )");
    query.bindValue(":limit", limit);

    if (!query.exec()) {
        qCritical() << "❌ OperationLogDatabase: 查询失败:" << query.lastError().text();
        return logs;
    }

    while (query.next()) {
        QVariantMap log;
        log["timestamp"] = query.value(0).toString();
        log["workMode"] = query.value(1).toString();
        log["triggerType"] = query.value(2).toString();
        log["operation"] = query.value(3).toString();
        log["deviceName"] = query.value(4).toString();
        log["detail"] = query.value(5).toString();
        logs.append(log);
    }

    return logs;
}

QVariantList OperationLogDatabase::getLogsByDateRange(const QDateTime &startDate,
                                                      const QDateTime &endDate)
{
    QVariantList logs;
    QSqlQuery query(m_database);

    query.prepare(R"(
        SELECT timestamp, work_mode, trigger_type, operation, device_name, detail
        FROM operation_logs
        WHERE timestamp BETWEEN :start_date AND :end_date
        ORDER BY timestamp DESC
    )");
    query.bindValue(":start_date", startDate.toString(Qt::ISODate));
    query.bindValue(":end_date", endDate.toString(Qt::ISODate));

    if (!query.exec()) {
        qCritical() << "❌ OperationLogDatabase: 查询失败:" << query.lastError().text();
        return logs;
    }

    while (query.next()) {
        QVariantMap log;
        log["timestamp"] = query.value(0).toString();
        log["workMode"] = query.value(1).toString();
        log["triggerType"] = query.value(2).toString();
        log["operation"] = query.value(3).toString();
        log["deviceName"] = query.value(4).toString();
        log["detail"] = query.value(5).toString();
        logs.append(log);
    }

    return logs;
}

void OperationLogDatabase::clearOldLogs(int daysToKeep)
{
    QSqlQuery query(m_database);
    QDateTime cutoffDate = QDateTime::currentDateTime().addDays(-daysToKeep);

    query.prepare(R"(
        DELETE FROM operation_logs
        WHERE timestamp < :cutoff_date
    )");
    query.bindValue(":cutoff_date", cutoffDate.toString(Qt::ISODate));

    if (!query.exec()) {
        qCritical() << "❌ OperationLogDatabase: 清理旧日志失败:" << query.lastError().text();
        return;
    }

    int deletedCount = query.numRowsAffected();
    qDebug() << "🗑️ OperationLogDatabase: 已清理" << deletedCount << "条旧日志（保留" << daysToKeep << "天）";
}

int OperationLogDatabase::getLogCount()
{
    QSqlQuery query(m_database);
    query.prepare("SELECT COUNT(*) FROM operation_logs");

    if (!query.exec() || !query.next()) {
        qCritical() << "❌ OperationLogDatabase: 查询日志总数失败:" << query.lastError().text();
        return 0;
    }

    return query.value(0).toInt();
}
