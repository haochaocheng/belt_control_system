#ifndef ALARMHISTORYDATABASE_H
#define ALARMHISTORYDATABASE_H

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>
#include <QDateTime>

/**
 * @brief 报警历史数据库 - 记录和查询报警事件
 *
 * 功能：
 * - 初始化SQLite数据库
 * - 保存报警触发事件
 * - 保存报警恢复事件
 * - 查询报警历史记录
 * - 统计报警次数
 */
class AlarmHistoryDatabase : public QObject
{
    Q_OBJECT

public:
    explicit AlarmHistoryDatabase(QObject *parent = nullptr);
    ~AlarmHistoryDatabase();

    // 初始化数据库
    bool initialize(const QString &dbPath = "alarm_history.db");

    // 保存报警触发事件
    Q_INVOKABLE bool saveAlarmTriggered(const QString &protectionName,
                                        const QString &protectionType,
                                        double triggerValue);

    // 保存报警恢复事件
    Q_INVOKABLE bool saveAlarmRestored(const QString &protectionName);

    // 查询报警历史记录（最近N条）
    Q_INVOKABLE QVariantList queryAlarmHistory(int limit = 100, int offset = 0);

    // 查询指定保护的历史记录
    Q_INVOKABLE QVariantList queryAlarmByProtection(const QString &protectionName,
                                                     int limit = 100);

    // 查询指定日期范围的历史记录
    Q_INVOKABLE QVariantList queryAlarmByDateRange(const QDateTime &startDate,
                                                    const QDateTime &endDate);

    // 统计指定保护的报警次数
    Q_INVOKABLE int countAlarmsByProtection(const QString &protectionName);

    // 统计今日报警总次数
    Q_INVOKABLE int countAlarmsToday();

    // 清空历史记录（谨慎使用）
    Q_INVOKABLE bool clearHistory();

    // 删除旧记录（保留最近N天）
    Q_INVOKABLE bool deleteOldRecords(int daysToKeep = 90);

private:
    // 创建数据库表
    bool createTables();

    // 将查询结果转换为QVariantList
    QVariantList queryToVariantList(const QString &queryStr);

private:
    QSqlDatabase m_db;
    QString m_dbPath;
};

#endif // ALARMHISTORYDATABASE_H
