/***********************************************************************************
**    Belt Control System - Call History Database
**    Copyright (C) 2025
**
**    SQLite-based persistent storage for call history records.
**    Provides reliable storage that survives application restarts.
**
************************************************************************************/
#ifndef CALLHISTORYDATABASE_H
#define CALLHISTORYDATABASE_H

#include "risipsdkglobal.h"
#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QDateTime>
#include <QList>

namespace risip {

// Forward declaration
struct CallRecordSnapshot;

class RISIP_VOIPSDK_EXPORT CallHistoryDatabase : public QObject
{
    Q_OBJECT
public:
    static CallHistoryDatabase* instance();

    // Database operations
    bool initialize();
    void saveCallRecord(const CallRecordSnapshot &record);
    QList<CallRecordSnapshot> loadRecentRecords(int limit = 100);
    void clearOldRecords(int daysToKeep = 90);
    void clearAllRecords();
    bool deleteCallRecord(const CallRecordSnapshot &record);  // ✅ Delete specific record

    // Statistics
    int totalRecordCount();

private:
    explicit CallHistoryDatabase(QObject *parent = nullptr);
    ~CallHistoryDatabase();

    bool createTables();
    QString getDatabasePath();

    QSqlDatabase m_db;
    static CallHistoryDatabase* s_instance;

    Q_DISABLE_COPY(CallHistoryDatabase)
};

} // namespace risip

#endif // CALLHISTORYDATABASE_H
