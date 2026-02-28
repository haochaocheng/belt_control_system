#include "AlarmHistoryDatabase.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QVariantMap>
#include <QDebug>

AlarmHistoryDatabase::AlarmHistoryDatabase(QObject *parent)
    : QObject(parent)
{
    qDebug() << "✅ AlarmHistoryDatabase: 报警历史数据库已创建";
}

AlarmHistoryDatabase::~AlarmHistoryDatabase()
{
    if (m_db.isOpen()) {
        m_db.close();
    }
    qDebug() << "✅ AlarmHistoryDatabase: 报警历史数据库已销毁";
}

bool AlarmHistoryDatabase::initialize(const QString &dbPath)
{
    m_dbPath = dbPath;

    // 创建数据库连接
    m_db = QSqlDatabase::addDatabase("QSQLITE", "alarm_history_connection");
    m_db.setDatabaseName(dbPath);

    if (!m_db.open()) {
        qCritical() << "❌ AlarmHistoryDatabase: 无法打开数据库:" << m_db.lastError().text();
        return false;
    }

    qDebug() << "✅ AlarmHistoryDatabase: 数据库已打开:" << dbPath;

    // 创建表
    if (!createTables()) {
        qCritical() << "❌ AlarmHistoryDatabase: 创建表失败";
        return false;
    }

    qDebug() << "✅ AlarmHistoryDatabase: 数据库初始化完成";
    return true;
}

bool AlarmHistoryDatabase::createTables()
{
    QSqlQuery query(m_db);

    // 创建报警历史表
    QString createTableSQL = R"(
        CREATE TABLE IF NOT EXISTS alarm_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            protection_name TEXT NOT NULL,
            protection_type TEXT NOT NULL,
            event_type TEXT NOT NULL,
            trigger_value REAL,
            timestamp TEXT NOT NULL,
            date TEXT NOT NULL,
            time TEXT NOT NULL
        )
    )";

    if (!query.exec(createTableSQL)) {
        qCritical() << "❌ AlarmHistoryDatabase: 创建表失败:" << query.lastError().text();
        return false;
    }

    // 创建索引以加速查询
    QString createIndexSQL1 = "CREATE INDEX IF NOT EXISTS idx_protection_name ON alarm_history(protection_name)";
    QString createIndexSQL2 = "CREATE INDEX IF NOT EXISTS idx_timestamp ON alarm_history(timestamp)";
    QString createIndexSQL3 = "CREATE INDEX IF NOT EXISTS idx_date ON alarm_history(date)";

    query.exec(createIndexSQL1);
    query.exec(createIndexSQL2);
    query.exec(createIndexSQL3);

    qDebug() << "✅ AlarmHistoryDatabase: 数据库表已创建";
    return true;
}

bool AlarmHistoryDatabase::saveAlarmTriggered(const QString &protectionName,
                                              const QString &protectionType,
                                              double triggerValue)
{
    QSqlQuery query(m_db);

    QDateTime now = QDateTime::currentDateTime();
    QString timestamp = now.toString("yyyy-MM-dd HH:mm:ss");
    QString date = now.toString("yyyy-MM-dd");
    QString time = now.toString("HH:mm:ss");

    QString insertSQL = R"(
        INSERT INTO alarm_history
        (protection_name, protection_type, event_type, trigger_value, timestamp, date, time)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    )";

    query.prepare(insertSQL);
    query.addBindValue(protectionName);
    query.addBindValue(protectionType);
    query.addBindValue("triggered");
    query.addBindValue(triggerValue);
    query.addBindValue(timestamp);
    query.addBindValue(date);
    query.addBindValue(time);

    if (!query.exec()) {
        qWarning() << "❌ AlarmHistoryDatabase: 保存报警触发事件失败:" << query.lastError().text();
        return false;
    }

    qDebug() << "📝 AlarmHistoryDatabase: 报警触发事件已保存 -" << protectionName
             << "类型:" << protectionType << "值:" << triggerValue;
    // ✅ 2026-02-28 [Phase 7.47.48]: 通知QML AlarmPage自动刷新列表
    emit alarmAdded();
    return true;
}

bool AlarmHistoryDatabase::saveAlarmRestored(const QString &protectionName)
{
    QSqlQuery query(m_db);

    QDateTime now = QDateTime::currentDateTime();
    QString timestamp = now.toString("yyyy-MM-dd HH:mm:ss");
    QString date = now.toString("yyyy-MM-dd");
    QString time = now.toString("HH:mm:ss");

    QString insertSQL = R"(
        INSERT INTO alarm_history
        (protection_name, protection_type, event_type, trigger_value, timestamp, date, time)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    )";

    query.prepare(insertSQL);
    query.addBindValue(protectionName);
    query.addBindValue("");  // 恢复事件不需要类型
    query.addBindValue("restored");
    query.addBindValue(0.0);  // 恢复事件不需要触发值
    query.addBindValue(timestamp);
    query.addBindValue(date);
    query.addBindValue(time);

    if (!query.exec()) {
        qWarning() << "❌ AlarmHistoryDatabase: 保存报警恢复事件失败:" << query.lastError().text();
        return false;
    }

    qDebug() << "📝 AlarmHistoryDatabase: 报警恢复事件已保存 -" << protectionName;
    // ✅ 2026-02-28 [Phase 7.47.48]: 通知QML AlarmPage自动刷新列表
    emit alarmAdded();
    return true;
}

QVariantList AlarmHistoryDatabase::queryAlarmHistory(int limit, int offset)
{
    QString queryStr = QString("SELECT * FROM alarm_history ORDER BY timestamp DESC LIMIT %1 OFFSET %2")
                          .arg(limit).arg(offset);
    return queryToVariantList(queryStr);
}

QVariantList AlarmHistoryDatabase::queryAlarmByProtection(const QString &protectionName, int limit)
{
    QString queryStr = QString(
        "SELECT * FROM alarm_history WHERE protection_name = '%1' "
        "ORDER BY timestamp DESC LIMIT %2"
    ).arg(protectionName).arg(limit);

    return queryToVariantList(queryStr);
}

QVariantList AlarmHistoryDatabase::queryAlarmByDateRange(const QDateTime &startDate,
                                                         const QDateTime &endDate)
{
    QString startStr = startDate.toString("yyyy-MM-dd HH:mm:ss");
    QString endStr = endDate.toString("yyyy-MM-dd HH:mm:ss");

    QString queryStr = QString(
        "SELECT * FROM alarm_history WHERE timestamp BETWEEN '%1' AND '%2' "
        "ORDER BY timestamp DESC"
    ).arg(startStr).arg(endStr);

    return queryToVariantList(queryStr);
}

int AlarmHistoryDatabase::countAlarmsByProtection(const QString &protectionName)
{
    QSqlQuery query(m_db);

    QString queryStr = QString(
        "SELECT COUNT(*) FROM alarm_history WHERE protection_name = '%1' AND event_type = 'triggered'"
    ).arg(protectionName);

    if (!query.exec(queryStr)) {
        qWarning() << "❌ AlarmHistoryDatabase: 统计报警次数失败:" << query.lastError().text();
        return 0;
    }

    if (query.next()) {
        return query.value(0).toInt();
    }

    return 0;
}

int AlarmHistoryDatabase::countAlarmsToday()
{
    QSqlQuery query(m_db);

    QString today = QDate::currentDate().toString("yyyy-MM-dd");
    QString queryStr = QString(
        "SELECT COUNT(*) FROM alarm_history WHERE date = '%1' AND event_type = 'triggered'"
    ).arg(today);

    if (!query.exec(queryStr)) {
        qWarning() << "❌ AlarmHistoryDatabase: 统计今日报警次数失败:" << query.lastError().text();
        return 0;
    }

    if (query.next()) {
        return query.value(0).toInt();
    }

    return 0;
}

// ✅ 2026-02-28 [Phase 7.47.50]: 新增 - 统计全部记录总数（不受过滤影响）
int AlarmHistoryDatabase::countAllAlarms()
{
    QSqlQuery query(m_db);

    if (!query.exec("SELECT COUNT(*) FROM alarm_history")) {
        qWarning() << "❌ AlarmHistoryDatabase: 统计全部记录数失败:" << query.lastError().text();
        return 0;
    }

    if (query.next()) {
        return query.value(0).toInt();
    }

    return 0;
}

bool AlarmHistoryDatabase::clearHistory()
{
    QSqlQuery query(m_db);

    if (!query.exec("DELETE FROM alarm_history")) {
        qWarning() << "❌ AlarmHistoryDatabase: 清空历史记录失败:" << query.lastError().text();
        return false;
    }

    qDebug() << "✅ AlarmHistoryDatabase: 历史记录已清空";
    return true;
}

bool AlarmHistoryDatabase::deleteOldRecords(int daysToKeep)
{
    QSqlQuery query(m_db);

    QDateTime cutoffDate = QDateTime::currentDateTime().addDays(-daysToKeep);
    QString cutoffStr = cutoffDate.toString("yyyy-MM-dd HH:mm:ss");

    QString deleteSQL = QString(
        "DELETE FROM alarm_history WHERE timestamp < '%1'"
    ).arg(cutoffStr);

    if (!query.exec(deleteSQL)) {
        qWarning() << "❌ AlarmHistoryDatabase: 删除旧记录失败:" << query.lastError().text();
        return false;
    }

    int deletedCount = query.numRowsAffected();
    qDebug() << "✅ AlarmHistoryDatabase: 已删除" << deletedCount << "条旧记录（保留最近" << daysToKeep << "天）";
    return true;
}

QVariantList AlarmHistoryDatabase::queryToVariantList(const QString &queryStr)
{
    QVariantList result;
    QSqlQuery query(m_db);

    if (!query.exec(queryStr)) {
        qWarning() << "❌ AlarmHistoryDatabase: 查询失败:" << query.lastError().text();
        return result;
    }

    while (query.next()) {
        QVariantMap record;
        record["id"] = query.value("id").toInt();
        record["protectionName"] = query.value("protection_name").toString();
        record["protectionType"] = query.value("protection_type").toString();
        record["eventType"] = query.value("event_type").toString();
        record["triggerValue"] = query.value("trigger_value").toDouble();
        record["timestamp"] = query.value("timestamp").toString();
        record["date"] = query.value("date").toString();
        record["time"] = query.value("time").toString();
        result.append(record);
    }

    qDebug() << "📊 AlarmHistoryDatabase: 查询返回" << result.size() << "条记录";
    return result;
}
