/***********************************************************************************
**    Belt Control System - Contact Database
**    Copyright (C) 2025
**
**    SQLite-based persistent storage for contact information.
**    Maps phone numbers to contact names (e.g., 1006 -> "小七").
**
************************************************************************************/
#ifndef CONTACTDATABASE_H
#define CONTACTDATABASE_H

#include "risipsdkglobal.h"
#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QMap>

namespace risip {

struct Contact {
    int id = -1;
    QString name;
    QString number;
};

class RISIP_VOIPSDK_EXPORT ContactDatabase : public QObject
{
    Q_OBJECT
public:
    static ContactDatabase* instance();

    // Database operations
    bool initialize();

    // Contact management
    bool addContact(const QString &name, const QString &number);
    bool updateContact(int id, const QString &name, const QString &number);
    bool deleteContact(int id);

    // Query operations
    QString getContactName(const QString &number);  // Returns name for number, or empty if not found
    Contact getContact(const QString &number);      // Get full contact info
    QList<Contact> getAllContacts();

    void clearAllContacts();

private:
    explicit ContactDatabase(QObject *parent = nullptr);
    ~ContactDatabase();

    bool createTables();
    QString getDatabasePath();
    void loadContactCache();  // Load all contacts into memory for fast lookup

    QSqlDatabase m_db;
    QMap<QString, QString> m_contactCache;  // number -> name mapping for fast lookup
    static ContactDatabase* s_instance;

    Q_DISABLE_COPY(ContactDatabase)
};

} // namespace risip

#endif // CONTACTDATABASE_H
