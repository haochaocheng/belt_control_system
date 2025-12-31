/***********************************************************************************
**    Copyright (C) 2016  Petref Saraci
**    http://risip.io
**
**    This program is free software: you can redistribute it and/or modify
**    it under the terms of the GNU General Public License as published by
**    the Free Software Foundation, either version 3 of the License, or
**    (at your option) any later version.
**
**    This program is distributed in the hope that it will be useful,
**    but WITHOUT ANY WARRANTY; without even the implied warranty of
**    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**    GNU General Public License for more details.
**
**    You have received a copy of the GNU General Public License
**    along with this program. See LICENSE.GPLv3
**    A copy of the license can be found also here <http://www.gnu.org/licenses/>.
**
************************************************************************************/
#include "pjsipaccount.h"

#include "risipaccount.h"
#include "risipbuddy.h"
#include "risipmessage.h"

#include "pjsipcall.h"

#include <QDebug>
#include <QMetaObject>
#include <QPointer>

namespace risip {

/**
 * @class PjsipAccount class
 * @brief The PjsipAccount class
 * This is an internal class. It inherits the Account class from Pjsip and implements the respective
 * callbacks, see Pjsip Account C++ API reference.
 *
 * Instances of this class are created from RisipAccount class, which is the Qt wrapper representative.
 * PjsipAccount contains the pointer to the RisipAccount which created it, in order to
 * in order to send messages/callbacks to the wrapper class.
 *
 */
PjsipAccount::PjsipAccount()
    :Account()
    ,m_risipAccount(NULL)
{}

PjsipAccount::~PjsipAccount()
{}

void PjsipAccount::onRegState(OnRegStateParam &prm)
{
    qDebug() << "[PJSIP] 🔹 onRegState() called (thread-safe version v4 - compile-time Keep-alive disable)";
    qDebug() << "[PJSIP]    Response code:" << prm.code;
    qDebug() << "[PJSIP]    m_risipAccount pointer:" << (void*)m_risipAccount;

    // ⚠️ NOTE: Keep-alive disabling attempted via compile-time config (pjsip_config_site.h)
    // However, this project uses precompiled PJSIP libraries, so the fix may not work.
    // See docs/2025-12-25/Keep-alive崩溃深度分析与修复.md for details.
    //
    // Runtime config modification was attempted but:
    // 1. getInfo() in callbacks causes crashes (Bug #2117)
    // 2. setConfig() may not work with precompiled libraries
    // 3. Keep-alive timer starts before we can disable it at runtime
    //
    // If crashes persist, the only solution is to recompile PJSIP from source with
    // PJSUA_UDP_KA_INTERVAL=0 in pjsip_config_site.h

    if(m_risipAccount != NULL) {
        // ✅ FIX: Use prm.code directly instead of getInfo() to avoid AccountInfo destructor issues
        qDebug() << "[PJSIP] 🔸 Determining status from response code (no AccountInfo)...";

        // ✅ THREAD SAFETY: Determine new status first
        RisipAccount::Status newStatus;
        switch (prm.code) {
        case PJSIP_SC_OK:
            qDebug() << "[PJSIP] ✅ Registration successful (200 OK)";
            newStatus = RisipAccount::SignedIn;  // 200 OK means signed in
            break;
        case PJSIP_SC_TRYING:
            qDebug() << "[PJSIP] ⏳ Registration trying (100)";
            newStatus = RisipAccount::Registering;  // 100 Trying means registering
            break;
        default:
            qDebug() << "[PJSIP] ❌ Registration failed, code:" << prm.code;
            newStatus = RisipAccount::AccountError;
            break;
        }

        // ✅ CRITICAL FIX: Queue ALL Qt object modifications to main thread
        // Including setLastResponseCode() which was previously called directly
        qDebug() << "[PJSIP] 🔸 Queuing ALL updates to main thread (including response code)...";

        // ✅ SAFETY FIX: Use QPointer to prevent dangling pointer access
        // If RisipAccount is deleted before lambda executes, QPointer becomes null
        QPointer<RisipAccount> account = m_risipAccount;
        RisipAccount::Status statusToSet = newStatus;
        int responseCode = prm.code;

        QMetaObject::invokeMethod(account.data(), [account, statusToSet, responseCode]() {
            // ✅ Check if object still exists before accessing
            if (!account) {
                qDebug() << "[PJSIP-MainThread] ⚠️ RisipAccount was deleted, skipping update";
                return;
            }
            qDebug() << "[PJSIP-MainThread] 🔸 Setting last response code:" << responseCode;
            account->setLastResponseCode(responseCode);
            qDebug() << "[PJSIP-MainThread] 🔸 Setting status to" << statusToSet;
            account->setStatus(statusToSet);
            qDebug() << "[PJSIP-MainThread] ✅ All updates completed";
        }, Qt::QueuedConnection);

        qDebug() << "[PJSIP] ✅ onRegState() completed (all updates queued)";
    } else {
        qDebug() << "[PJSIP] ⚠️ m_risipAccount is NULL, skipping status update";
    }

    // ✅ FIX: Return immediately to allow Qt event loop to process queued updates
    qDebug() << "[PJSIP] 🔚 onRegState() returning immediately (no blocking, no AccountInfo)...";
    qDebug() << "[PJSIP] 🔚 About to return from onRegState()...";
    // PJSIP 可能在此函数返回后继续执行其他操作（包括启动 Keep-alive 定时器）
}

void PjsipAccount::onRegStarted(OnRegStartedParam &prm)
{
    qDebug() << "[PJSIP] 🔹 onRegStarted() called (thread-safe version)";
    qDebug() << "[PJSIP]    renew:" << prm.renew;

    if(!m_risipAccount) {
        qDebug() << "[PJSIP] ⚠️ m_risipAccount is NULL in onRegStarted";
        return;
    }

    // ✅ THREAD SAFETY: Determine status first
    RisipAccount::Status newStatus = prm.renew ?
        RisipAccount::Registering : RisipAccount::UnRegistering;

    // ✅ CRITICAL: Queue status change to main thread
    qDebug() << "[PJSIP] 🔸 Queuing status change to" << newStatus << "for main thread...";

    // ✅ SAFETY FIX: Use QPointer to prevent dangling pointer access
    QPointer<RisipAccount> account = m_risipAccount;
    RisipAccount::Status statusToSet = newStatus;

    QMetaObject::invokeMethod(account.data(), [account, statusToSet]() {
        if (!account) {
            qDebug() << "[PJSIP-MainThread] ⚠️ RisipAccount was deleted, skipping status update";
            return;
        }
        qDebug() << "[PJSIP-MainThread] 🔸 onRegStarted: Setting status to" << statusToSet;
        account->setStatus(statusToSet);
        qDebug() << "[PJSIP-MainThread] ✅ onRegStarted: Status set successfully";
    }, Qt::QueuedConnection);

    qDebug() << "[PJSIP] ✅ onRegStarted() completed (status change queued)";
}

/**
 * @brief PjsipAccount::onIncomingCall
 * @param prm
 *
 * Callback from the PJSIP library, an incoming call.
 */
void PjsipAccount::onIncomingCall(OnIncomingCallParam &prm)
{
    qDebug() << "[PJSIP] 🔹 onIncomingCall() called (thread-safe version)";
    qDebug() << "[PJSIP]    callId:" << prm.callId;

    if(!m_risipAccount) {
        qDebug() << "[PJSIP] ⚠️ m_risipAccount is NULL in onIncomingCall";
        return;
    }

    // ✅ THREAD SAFETY: Create call in main thread
    qDebug() << "[PJSIP] 🔸 Queuing incoming call creation to main thread...";

    // ✅ SAFETY FIX: Use QPointer to prevent dangling pointer access
    QPointer<RisipAccount> account = m_risipAccount;
    int callId = prm.callId;

    QMetaObject::invokeMethod(account.data(), [account, callId]() {
        if (!account) {
            qDebug() << "[PJSIP-MainThread] ⚠️ RisipAccount was deleted, skipping incoming call";
            return;
        }
        qDebug() << "[PJSIP-MainThread] 🔸 Creating incoming call, callId:" << callId;
        PjsipCall* call = new PjsipCall(*account->pjsipAccount(), callId);
        account->setIncomingPjsipCall(call);
        qDebug() << "[PJSIP-MainThread] ✅ Incoming call created successfully";
    }, Qt::QueuedConnection);

    qDebug() << "[PJSIP] ✅ onIncomingCall() completed (call creation queued)";
}

void PjsipAccount::onIncomingSubscribe(OnIncomingSubscribeParam &prm)
{
    Q_UNUSED(prm)
}

void PjsipAccount::onInstantMessage(OnInstantMessageParam &prm)
{
    qDebug() << "[PJSIP] 🔹 onInstantMessage() called (thread-safe version)";
    qDebug() << "[PJSIP]    from:" << QString::fromStdString(prm.fromUri);

    if(!m_risipAccount) {
        qDebug() << "[PJSIP] ⚠️ m_risipAccount is NULL in onInstantMessage";
        return;
    }

    // ✅ THREAD SAFETY: Process message in main thread
    qDebug() << "[PJSIP] 🔸 Queuing instant message processing to main thread...";

    // ✅ SAFETY FIX: Use QPointer to prevent dangling pointer access
    QPointer<RisipAccount> account = m_risipAccount;
    std::string fromUri = prm.fromUri;
    std::string msgBody = prm.msgBody;
    std::string contentType = prm.contentType;

    QMetaObject::invokeMethod(account.data(), [account, fromUri, msgBody, contentType]() {
        if (!account) {
            qDebug() << "[PJSIP-MainThread] ⚠️ RisipAccount was deleted, skipping message";
            return;
        }
        qDebug() << "[PJSIP-MainThread] 🔸 Processing instant message from:" << QString::fromStdString(fromUri);

        // Creating the buddy if needed or simply reuse it
        RisipBuddy *buddy = account->findBuddy(QString::fromStdString(fromUri));
        if(!buddy) {
            buddy = new RisipBuddy;
            buddy->setAccount(account);
            buddy->setUri(QString::fromStdString(fromUri));
        }

        // Constructing a risip message to be passed around
        RisipMessage *message = new RisipMessage;
        message->setBuddy(buddy);
        message->setDirection(RisipMessage::Incoming);

        // Create QString variables (not temporaries) for setMessageBody/setContentType
        QString messageBody = QString::fromStdString(msgBody);
        QString messageContentType = QString::fromStdString(contentType);
        message->setMessageBody(messageBody);
        message->setContentType(messageContentType);

        account->incomingMessage(message);

        qDebug() << "[PJSIP-MainThread] ✅ Instant message processed successfully";
    }, Qt::QueuedConnection);

    qDebug() << "[PJSIP] ✅ onInstantMessage() completed (message processing queued)";
}

void PjsipAccount::onInstantMessageStatus(OnInstantMessageStatusParam &prm)
{
    RisipMessage *message = static_cast<RisipMessage *>(prm.userData);
    switch (prm.code) {
    case PJSIP_SC_OK:
    case PJSIP_SC_ACCEPTED:
        message->setStatus(RisipMessage::Sent);
        qDebug()<<"Message delivered: " <<message->messageBody();
        break;
    default:
        message->setStatus(RisipMessage::Failed);
        break;
    }
}

void PjsipAccount::onTypingIndication(OnTypingIndicationParam &prm)
{
    Q_UNUSED(prm)
}

//buddy subscribe / notify callbacks
void PjsipAccount::onMwiInfo(OnMwiInfoParam &prm)
{
    Q_UNUSED(prm)
}

void PjsipAccount::setRisipInterface(RisipAccount *acc)
{
    m_risipAccount = acc;
}

} //end of risip namespace
