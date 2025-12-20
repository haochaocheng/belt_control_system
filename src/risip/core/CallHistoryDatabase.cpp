/***********************************************************************************
**    Belt Control System - Call History Database Implementation
**    Copyright (C) 2025
**
**    SQLite-based persistent storage for call history records.
**
************************************************************************************/
#include "CallHistoryDatabase.h"
#include "risipcallhistorymodel.h"  // For CallRecordSnapshot
#include "../../control/DataPathConfig.h"

#include <QSqlQuery>
#include <QSqlError>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QVariant>
#include <QCoreApplication>

namespace risip {

CallHistoryDatabase* CallHistoryDatabase::s_instance = nullptr;

CallHistoryDatabase* CallHistoryDatabase::instance()
{
    if (!s_instance) {
        s_instance = new CallHistoryDatabase();
        s_instance->initialize();
    }
    return s_instance;
}

CallHistoryDatabase::CallHistoryDatabase(QObject *parent)
    : QObject(parent)
{
}

CallHistoryDatabase::~CallHistoryDatabase()
{
    if (m_db.isOpen()) {
        m_db.close();
    }
}

QString CallHistoryDatabase::getDatabasePath()
{
    // 使用统一数据目录配置
    QString dbPath = DataPathConfig::getCallHistoryDbPath();
    qDebug() << "📁 [CALL HISTORY DB] Database path:" << dbPath;
    return dbPath;
}

bool CallHistoryDatabase::initialize()
{
    QString dbPath = getDatabasePath();
    qDebug() << "📁 [DATABASE] Initializing SQLite database at:" << dbPath;

    m_db = QSqlDatabase::addDatabase("QSQLITE", "call_history_connection");
    m_db.setDatabaseName(dbPath);

    if (!m_db.open()) {
        qCritical() << "❌ [DATABASE] Failed to open database:" << m_db.lastError().text();
        return false;
    }

    qDebug() << "✅ [DATABASE] Database opened successfully";

    if (!createTables()) {
        qCritical() << "❌ [DATABASE] Failed to create tables";
        return false;
    }

    qDebug() << "✅ [DATABASE] Database initialized, total records:" << totalRecordCount();
    return true;
}

bool CallHistoryDatabase::createTables()
{
    QSqlQuery query(m_db);

    // Create call_history table
    QString createTableSQL = R"(
        CREATE TABLE IF NOT EXISTS call_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            contact TEXT NOT NULL,
            direction INTEGER NOT NULL,
            duration INTEGER NOT NULL,
            timestamp DATETIME NOT NULL,
            account TEXT,
            is_video INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    )";

    if (!query.exec(createTableSQL)) {
        qCritical() << "❌ [DATABASE] Failed to create table:" << query.lastError().text();
        return false;
    }

    // Create index on timestamp for fast queries
    QString createIndexSQL = "CREATE INDEX IF NOT EXISTS idx_timestamp ON call_history(timestamp DESC)";
    if (!query.exec(createIndexSQL)) {
        qWarning() << "⚠️ [DATABASE] Failed to create index:" << query.lastError().text();
        // Non-critical, continue
    }

    qDebug() << "✅ [DATABASE] Tables and indexes created";
    return true;
}

void CallHistoryDatabase::saveCallRecord(const CallRecordSnapshot &record)
{
    QSqlQuery query(m_db);

    query.prepare(R"(
        INSERT INTO call_history (contact, direction, duration, timestamp)
        VALUES (:contact, :direction, :duration, :timestamp)
    )");

    query.bindValue(":contact", record.contact);
    query.bindValue(":direction", record.direction);
    query.bindValue(":duration", (qint64)record.duration);
    query.bindValue(":timestamp", record.timestamp);

    if (!query.exec()) {
        qCritical() << "❌ [DATABASE] Failed to insert record:" << query.lastError().text();
        qCritical() << "   Contact:" << record.contact;
        qCritical() << "   Direction:" << record.direction;
        qCritical() << "   Duration:" << record.duration;
        qCritical() << "   Timestamp:" << record.timestamp;
        return;
    }

    qDebug() << "✅ [DATABASE] Saved call record:"
             << "contact=" << record.contact
             << "direction=" << record.direction
             << "duration=" << (record.duration / 1000) << "s";
}

QList<CallRecordSnapshot> CallHistoryDatabase::loadRecentRecords(int limit)
{
    QList<CallRecordSnapshot> records;
    QSqlQuery query(m_db);

    query.prepare(R"(
        SELECT contact, direction, duration, timestamp
        FROM call_history
        ORDER BY timestamp DESC
        LIMIT :limit
    )");

    query.bindValue(":limit", limit);

    if (!query.exec()) {
        qCritical() << "❌ [DATABASE] Failed to load records:" << query.lastError().text();
        return records;
    }

    while (query.next()) {
        CallRecordSnapshot record;
        record.contact = query.value(0).toString();
        record.direction = query.value(1).toInt();
        record.duration = query.value(2).toLongLong();
        record.timestamp = query.value(3).toDateTime();
        records.append(record);
    }

    qDebug() << "✅ [DATABASE] Loaded" << records.count() << "records from database";
    return records;
}

void CallHistoryDatabase::clearOldRecords(int daysToKeep)
{
    QSqlQuery query(m_db);

    query.prepare(R"(
        DELETE FROM call_history
        WHERE timestamp < datetime('now', '-' || :days || ' days')
    )");

    query.bindValue(":days", daysToKeep);

    if (!query.exec()) {
        qCritical() << "❌ [DATABASE] Failed to clear old records:" << query.lastError().text();
        return;
    }

    int deletedCount = query.numRowsAffected();
    if (deletedCount > 0) {
        qDebug() << "✅ [DATABASE] Cleared" << deletedCount << "old records (older than" << daysToKeep << "days)";
    }
}

void CallHistoryDatabase::clearAllRecords()
{
    QSqlQuery query(m_db);

    if (!query.exec("DELETE FROM call_history")) {
        qCritical() << "❌ [DATABASE] Failed to clear all records:" << query.lastError().text();
        return;
    }

    qDebug() << "✅ [DATABASE] Cleared all call history records";
}

bool CallHistoryDatabase::deleteCallRecord(const CallRecordSnapshot &record)
{
    QSqlQuery query(m_db);

    query.prepare(R"(
        DELETE FROM call_history
        WHERE contact = :contact
        AND timestamp = :timestamp
        AND duration = :duration
    )");

    query.bindValue(":contact", record.contact);
    query.bindValue(":timestamp", record.timestamp);
    query.bindValue(":duration", (qint64)record.duration);

    if (!query.exec()) {
        qCritical() << "❌ [DATABASE] Failed to delete record:" << query.lastError().text();
        qCritical() << "   Contact:" << record.contact;
        qCritical() << "   Timestamp:" << record.timestamp;
        qCritical() << "   Duration:" << record.duration;
        return false;
    }

    int deleted = query.numRowsAffected();
    if (deleted > 0) {
        qDebug() << "✅ [DATABASE] Deleted" << deleted << "record(s) from database";
        return true;
    } else {
        qWarning() << "⚠️ [DATABASE] No matching record found to delete";
        return false;
    }
}

int CallHistoryDatabase::totalRecordCount()
{
    QSqlQuery query(m_db);

    if (!query.exec("SELECT COUNT(*) FROM call_history")) {
        qCritical() << "❌ [DATABASE] Failed to count records:" << query.lastError().text();
        return 0;
    }

    if (query.next()) {
        return query.value(0).toInt();
    }

    return 0;
}

} // namespace risip
