/***********************************************************************************
**    Copyright (C) 2016  Petref Saraci
**    http://risip.io
**
**    Modified 2025 - Added snapshot + database persistence
**
************************************************************************************/
#include "risipcallhistorymodel.h"
#include "risipaccount.h"
#include "risipcall.h"
#include "risipbuddy.h"
#include "risip.h"
#include "CallHistoryDatabase.h"
#include "ContactDatabase.h"  // 联系人数据库

#include <QDebug>
#include <QRegularExpression>

namespace risip {

// Helper function to extract phone number from SIP contact string
// Handles formats like:
//   - "Extension 1006" <sip:1006@server> -> returns "1006"
//   - sip:1006@server -> returns "1006"
//   - "Extension 1006" 1006 -> returns "1006"
//   - 1006 -> returns "1006"
static QString extractPhoneNumber(const QString &contact)
{
    if (contact.isEmpty()) {
        return contact;
    }

    // Try to extract number from SIP URI (sip:1006@server or <sip:1006@server>)
    QRegularExpression sipRegex(R"(sip:(\d+)@)");
    QRegularExpressionMatch match = sipRegex.match(contact);
    if (match.hasMatch()) {
        QString number = match.captured(1);
        qDebug() << "📇 [HISTORY] Extracted number" << number << "from SIP URI:" << contact;
        return number;
    }

    // Try to extract number from "Extension XXXX" XXXX format
    QRegularExpression extRegex(R"(\s+(\d+)\s*$)");
    match = extRegex.match(contact);
    if (match.hasMatch()) {
        QString number = match.captured(1);
        qDebug() << "📇 [HISTORY] Extracted number" << number << "from Extension format:" << contact;
        return number;
    }

    // If it's just a plain number, return as is
    QRegularExpression numberRegex(R"(^\d+$)");
    if (numberRegex.match(contact).hasMatch()) {
        return contact;
    }

    // Otherwise return the original (fallback)
    qDebug() << "⚠️ [HISTORY] Could not extract number from:" << contact;
    return contact;
}

RisipCallHistoryModel::RisipCallHistoryModel(QObject *parent)
    : QAbstractListModel(parent)
    ,m_account(Risip::instance()->defaultAccount())
{
    // ✅ Load call history from database
    m_snapshots = CallHistoryDatabase::instance()->loadRecentRecords(100);
    qDebug() << "✅ [HISTORY MODEL] Loaded" << m_snapshots.count() << "records from database";
}

RisipCallHistoryModel::~RisipCallHistoryModel()
{
}

RisipAccount *RisipCallHistoryModel::account()
{
    return m_account;
}

void RisipCallHistoryModel::setAccount(RisipAccount *account)
{
    if(m_account != account) {
        m_account = account;
        emit accountChanged(m_account);
    }
}

QHash<int, QByteArray> RisipCallHistoryModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[CallContactRole] = "callContact";
    roles[CallDirectionRole] = "callDirection";
    roles[CallDurationRole] = "callDuration";
    roles[CallTimestampRole] = "callTimestamp";
    return roles;
}

int RisipCallHistoryModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;

    // ✅ Use snapshot count (stable even after RisipCall objects destroyed)
    return m_snapshots.count();
}

QVariant RisipCallHistoryModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_snapshots.count())
        return QVariant();

    // ✅ CRITICAL FIX: Read from snapshot instead of RisipCall pointer
    // This prevents accessing destroyed objects and ensures data persistence
    const CallRecordSnapshot &snapshot = m_snapshots.at(index.row());

    switch (role) {
    case CallDirectionRole:
        return snapshot.direction;
    case CallDurationRole:
        return (qlonglong)snapshot.duration;
    case CallTimestampRole:
        return snapshot.timestamp;
    case CallContactRole:
        {
            // ✅ 提取号码并查询联系人名（处理数据库中的旧记录）
            QString phoneNumber = extractPhoneNumber(snapshot.contact);
            QString contactName = ContactDatabase::instance()->getContactName(phoneNumber);
            if (!contactName.isEmpty()) {
                // 返回格式：小七 (1006)
                return contactName + " (" + phoneNumber + ")";
            } else {
                // 只返回号码：1006
                return phoneNumber;
            }
        }
    }

    return QVariant();
}

void RisipCallHistoryModel::addCallRecord(RisipCall *call)
{
    if(!call) {
        qWarning() << "⚠️ [HISTORY] addCallRecord called with null call";
        return;
    }

    // ✅ CRITICAL FIX: Create initial snapshot with available data
    // Direction and duration will be updated when call status changes
    QString contact = call->buddy() ? call->buddy()->contact() : QString("Unknown");
    int direction = call->callDirection();  // May be Unknown(2) initially
    long duration = 0;  // Will be updated when call ends
    QDateTime timestamp = call->timestamp();

    // ✅ 提取纯号码，然后查询联系人名
    QString phoneNumber = extractPhoneNumber(contact);
    QString contactName = ContactDatabase::instance()->getContactName(phoneNumber);
    if (!contactName.isEmpty()) {
        qDebug() << "📇 [HISTORY] Found contact name:" << contactName << "for" << phoneNumber;
        contact = contactName + " (" + phoneNumber + ")";  // 显示为：小七 (1006)
    } else {
        contact = phoneNumber;  // 显示为：1006
    }

    qDebug() << "📝 [HISTORY] Adding initial call record:";
    qDebug() << "   Contact:" << contact;
    qDebug() << "   Direction:" << direction << "(1=Incoming, 2=Outgoing, -1=Unknown)";
    qDebug() << "   Duration:" << duration << "ms (will update when call ends)";
    qDebug() << "   Timestamp:" << timestamp.toString("yyyy-MM-dd HH:mm:ss");

    // Create initial snapshot
    CallRecordSnapshot snapshot(contact, direction, duration, timestamp);

    // ✅ FIX: Insert at beginning (newest records first)
    beginInsertRows(QModelIndex(), 0, 0);
    m_calls.prepend(call);  // Keep pointer for compatibility
    m_snapshots.prepend(snapshot);  // Add snapshot at beginning
    m_callIndexMap.insert(call, 0);  // Map call to index 0
    endInsertRows();

    // Update all other indices in the map
    for (auto it = m_callIndexMap.begin(); it != m_callIndexMap.end(); ++it) {
        if (it.key() != call) {
            it.value()++;  // Increment all other indices
        }
    }

    qDebug() << "✅ [HISTORY] Initial record added, total count:" << m_snapshots.count();

    // ✅ Connect to statusChanged signal to update snapshot later
    connect(call, &RisipCall::statusChanged, this, &RisipCallHistoryModel::onCallStatusChanged, Qt::UniqueConnection);
}

void RisipCallHistoryModel::removeCallRecord(RisipCall *call)
{
    if(!call) {
        return;
    }

    int index = m_calls.indexOf(call);
    if (index < 0) {
        return;
    }

    beginRemoveRows(QModelIndex(), index, index);
    m_calls.removeAt(index);
    m_snapshots.removeAt(index);
    m_callIndexMap.remove(call);
    endRemoveRows();

    // Update indices in map
    for (auto it = m_callIndexMap.begin(); it != m_callIndexMap.end(); ++it) {
        if (it.value() > index) {
            it.value()--;
        }
    }

    qDebug() << "✅ [HISTORY] Record removed, total count:" << m_snapshots.count();
}

// ✅ Remove call record by index (for UI delete button)
void RisipCallHistoryModel::removeRecordAtIndex(int index)
{
    if (index < 0 || index >= m_snapshots.count()) {
        qWarning() << "❌ [HISTORY] Invalid index for delete:" << index << "/ count:" << m_snapshots.count();
        return;
    }

    const CallRecordSnapshot &snapshot = m_snapshots[index];
    qDebug() << "🗑️ [HISTORY] Deleting record at index:" << index;
    qDebug() << "   Contact:" << snapshot.contact;
    qDebug() << "   Direction:" << snapshot.direction;
    qDebug() << "   Duration:" << snapshot.duration << "ms";
    qDebug() << "   Timestamp:" << snapshot.timestamp;

    // Delete from database using CallHistoryDatabase singleton
    CallHistoryDatabase::instance()->deleteCallRecord(snapshot);

    beginRemoveRows(QModelIndex(), index, index);

    // Remove from m_calls list if the call pointer still exists
    if (index < m_calls.count()) {
        RisipCall *call = m_calls[index];
        m_callIndexMap.remove(call);
        m_calls.removeAt(index);
    }

    // Remove snapshot
    m_snapshots.removeAt(index);

    endRemoveRows();

    // Update indices in map for remaining items
    for (auto it = m_callIndexMap.begin(); it != m_callIndexMap.end(); ++it) {
        if (it.value() > index) {
            it.value()--;
        }
    }

    qDebug() << "✅ [HISTORY] Record deleted, remaining count:" << m_snapshots.count();
}

void RisipCallHistoryModel::onCallStatusChanged()
{
    // Get the RisipCall object that emitted the signal
    RisipCall *call = qobject_cast<RisipCall*>(sender());
    if (!call) {
        qWarning() << "⚠️ [HISTORY] onCallStatusChanged: sender is not RisipCall";
        return;
    }

    // Check if this call is in our map
    if (!m_callIndexMap.contains(call)) {
        // Not in our history (might be removed already)
        return;
    }

    int index = m_callIndexMap.value(call);
    if (index < 0 || index >= m_snapshots.count()) {
        qWarning() << "⚠️ [HISTORY] Invalid index:" << index;
        return;
    }

    int status = call->status();
    qDebug() << "🔄 [HISTORY] Call status changed for index" << index << "status:" << status;

    // Update snapshot based on call status
    if (status == RisipCall::CallDisconnected || status == RisipCall::Null) {
        // ✅ Call ended - capture final snapshot and save to database
        QString contact = call->buddy() ? call->buddy()->contact() : m_snapshots[index].contact;
        int direction = call->callDirection();
        long duration = call->callDuration();  // Use cached duration if available
        QDateTime timestamp = call->timestamp();

        // ✅ 提取纯号码，然后查询联系人名字
        QString phoneNumber = extractPhoneNumber(contact);
        QString contactName = ContactDatabase::instance()->getContactName(phoneNumber);
        if (!contactName.isEmpty()) {
            qDebug() << "📇 [HISTORY] Found contact name:" << contactName << "for" << phoneNumber;
            contact = contactName + " (" + phoneNumber + ")";  // 显示为：小七 (1006)
        } else {
            contact = phoneNumber;  // 显示为：1006
        }

        qDebug() << "📝 [HISTORY] Call ended, updating final snapshot:";
        qDebug() << "   Contact:" << contact;
        qDebug() << "   Direction:" << direction;
        qDebug() << "   Duration:" << duration << "ms (" << (duration/1000) << "s)";
        qDebug() << "   Timestamp:" << timestamp.toString("yyyy-MM-dd HH:mm:ss");

        // Update snapshot
        m_snapshots[index] = CallRecordSnapshot(contact, direction, duration, timestamp);

        // ✅ Save to database for persistence
        CallHistoryDatabase::instance()->saveCallRecord(m_snapshots[index]);

        // Notify view that data changed
        QModelIndex modelIndex = createIndex(index, 0);
        emit dataChanged(modelIndex, modelIndex);

        // Disconnect signal to avoid multiple updates
        disconnect(call, &RisipCall::statusChanged, this, &RisipCallHistoryModel::onCallStatusChanged);
        m_callIndexMap.remove(call);

        qDebug() << "✅ [HISTORY] Final snapshot saved to database";
    }
    else if (status == RisipCall::CallConfirmed) {
        // ✅ Call connected - update direction if it was Unknown
        // Risip SDK enum: Incoming=1, Outgoing=2, Unknown=-1
        if (m_snapshots[index].direction == -1) {  // Unknown
            int direction = call->callDirection();
            if (direction != -1) {  // If we got a valid direction
                qDebug() << "🔄 [HISTORY] Updating direction from Unknown to" << direction;
                m_snapshots[index].direction = direction;

                QModelIndex modelIndex = createIndex(index, 0);
                emit dataChanged(modelIndex, modelIndex);
            }
        }
    }
}

} //end of risip namespace
