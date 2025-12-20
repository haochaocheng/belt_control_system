/***********************************************************************************
**    Belt Control System - Contact Database Implementation
**    Copyright (C) 2025
**
************************************************************************************/
#include "ContactDatabase.h"
#include "../../control/DataPathConfig.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QDir>
#include <QStandardPaths>
#include <QCoreApplication>

namespace risip {

ContactDatabase* ContactDatabase::s_instance = nullptr;

ContactDatabase* ContactDatabase::instance()
{
    if (!s_instance) {
        s_instance = new ContactDatabase();
        s_instance->initialize();
    }
    return s_instance;
}

ContactDatabase::ContactDatabase(QObject *parent)
    : QObject(parent)
{
}

ContactDatabase::~ContactDatabase()
{
    if (m_db.isOpen()) {
        m_db.close();
    }
}

QString ContactDatabase::getDatabasePath()
{
    // 使用统一数据目录配置
    QString dbPath = DataPathConfig::getContactsDbPath();
    qDebug() << "📁 [CONTACT DB] Database path:" << dbPath;
    return dbPath;
}

bool ContactDatabase::initialize()
{
    qDebug() << "🔧 [CONTACT DB] Initializing contact database...";

    QString dbPath = getDatabasePath();

    // Create database connection with unique name
    m_db = QSqlDatabase::addDatabase("QSQLITE", "ContactDatabase");
    m_db.setDatabaseName(dbPath);

    if (!m_db.open()) {
        qCritical() << "❌ [CONTACT DB] Failed to open database:" << m_db.lastError().text();
        return false;
    }

    qDebug() << "✅ [CONTACT DB] Database opened successfully";

    if (!createTables()) {
        return false;
    }

    // Load contacts into cache for fast lookup
    loadContactCache();

    qDebug() << "✅ [CONTACT DB] Initialization complete, loaded" << m_contactCache.size() << "contacts";
    return true;
}

bool ContactDatabase::createTables()
{
    QSqlQuery query(m_db);

    QString createTableSQL = R"(
        CREATE TABLE IF NOT EXISTS contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            number TEXT NOT NULL UNIQUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    )";

    if (!query.exec(createTableSQL)) {
        qCritical() << "❌ [CONTACT DB] Failed to create table:" << query.lastError().text();
        return false;
    }

    // Create index on number for fast lookups
    QString createIndexSQL = "CREATE INDEX IF NOT EXISTS idx_number ON contacts(number)";
    if (!query.exec(createIndexSQL)) {
        qWarning() << "⚠️ [CONTACT DB] Failed to create index:" << query.lastError().text();
    }

    qDebug() << "✅ [CONTACT DB] Tables and indexes created";
    return true;
}

void ContactDatabase::loadContactCache()
{
    m_contactCache.clear();

    QSqlQuery query(m_db);
    if (!query.exec("SELECT number, name FROM contacts")) {
        qWarning() << "⚠️ [CONTACT DB] Failed to load cache:" << query.lastError().text();
        return;
    }

    while (query.next()) {
        QString number = query.value(0).toString();
        QString name = query.value(1).toString();
        m_contactCache[number] = name;
    }

    qDebug() << "✅ [CONTACT DB] Loaded" << m_contactCache.size() << "contacts into cache";
}

bool ContactDatabase::addContact(const QString &name, const QString &number)
{
    QSqlQuery query(m_db);

    // ✅ Use INSERT OR REPLACE to update existing contacts with same number
    query.prepare(R"(
        INSERT OR REPLACE INTO contacts (name, number)
        VALUES (:name, :number)
    )");

    query.bindValue(":name", name);
    query.bindValue(":number", number);

    if (!query.exec()) {
        qCritical() << "❌ [CONTACT DB] Failed to add contact:" << query.lastError().text();
        return false;
    }

    // Update cache
    m_contactCache[number] = name;

    qDebug() << "✅ [CONTACT DB] Added/Updated contact:" << name << "(" << number << ")";
    return true;
}

bool ContactDatabase::updateContact(int id, const QString &name, const QString &number)
{
    QSqlQuery query(m_db);

    // Get old number first
    query.prepare("SELECT number FROM contacts WHERE id = :id");
    query.bindValue(":id", id);
    QString oldNumber;
    if (query.exec() && query.next()) {
        oldNumber = query.value(0).toString();
    }

    // Update contact
    query.prepare(R"(
        UPDATE contacts
        SET name = :name, number = :number
        WHERE id = :id
    )");

    query.bindValue(":name", name);
    query.bindValue(":number", number);
    query.bindValue(":id", id);

    if (!query.exec()) {
        qCritical() << "❌ [CONTACT DB] Failed to update contact:" << query.lastError().text();
        return false;
    }

    // Update cache
    if (!oldNumber.isEmpty()) {
        m_contactCache.remove(oldNumber);
    }
    m_contactCache[number] = name;

    qDebug() << "✅ [CONTACT DB] Updated contact:" << name << "(" << number << ")";
    return true;
}

bool ContactDatabase::deleteContact(int id)
{
    QSqlQuery query(m_db);

    // Get number first for cache removal
    query.prepare("SELECT number FROM contacts WHERE id = :id");
    query.bindValue(":id", id);
    QString number;
    if (query.exec() && query.next()) {
        number = query.value(0).toString();
    }

    // Delete contact
    query.prepare("DELETE FROM contacts WHERE id = :id");
    query.bindValue(":id", id);

    if (!query.exec()) {
        qCritical() << "❌ [CONTACT DB] Failed to delete contact:" << query.lastError().text();
        return false;
    }

    // Update cache
    if (!number.isEmpty()) {
        m_contactCache.remove(number);
    }

    qDebug() << "✅ [CONTACT DB] Deleted contact ID:" << id;
    return true;
}

QString ContactDatabase::getContactName(const QString &number)
{
    // Fast lookup from cache
    return m_contactCache.value(number, QString());
}

Contact ContactDatabase::getContact(const QString &number)
{
    Contact contact;
    QSqlQuery query(m_db);

    query.prepare("SELECT id, name, number FROM contacts WHERE number = :number");
    query.bindValue(":number", number);

    if (query.exec() && query.next()) {
        contact.id = query.value(0).toInt();
        contact.name = query.value(1).toString();
        contact.number = query.value(2).toString();
    }

    return contact;
}

QList<Contact> ContactDatabase::getAllContacts()
{
    QList<Contact> contacts;
    QSqlQuery query(m_db);

    if (!query.exec("SELECT id, name, number FROM contacts ORDER BY name")) {
        qCritical() << "❌ [CONTACT DB] Failed to load contacts:" << query.lastError().text();
        return contacts;
    }

    while (query.next()) {
        Contact contact;
        contact.id = query.value(0).toInt();
        contact.name = query.value(1).toString();
        contact.number = query.value(2).toString();
        contacts.append(contact);
    }

    return contacts;
}

void ContactDatabase::clearAllContacts()
{
    QSqlQuery query(m_db);

    if (!query.exec("DELETE FROM contacts")) {
        qCritical() << "❌ [CONTACT DB] Failed to clear contacts:" << query.lastError().text();
        return;
    }

    m_contactCache.clear();
    qDebug() << "✅ [CONTACT DB] Cleared all contacts";
}

} // namespace risip
