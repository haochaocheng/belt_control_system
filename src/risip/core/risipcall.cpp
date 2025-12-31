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

#include "risipcall.h"
#include "risipendpoint.h"
#include "risipaccountconfiguration.h"
#include "risipmodels.h"
#include "risipcallmanager.h"
#include "risipglobals.h"
#include "risip.h"

#include "pjsipwrapper/pjsipaccount.h"
#include "pjsipwrapper/pjsipcall.h"

#include <QDebug>

namespace risip {

class RisipCall::Private
{
public:
    int callType;
    int callDirection;
    RisipAccount *account;
    RisipBuddy *buddy;
    QDateTime timestamp;
    RisipMedia *risipMedia;
    PjsipCall *pjsipCall;
    Error error;
    int lastSipResponseCode;
    bool enableVideo;  // ⭐ 添加视频标志
};

RisipCall::RisipCall(QObject *parent)
    :QObject(parent)
    ,m_data(new Private)
{
    m_data->account = NULL;
    m_data->buddy = NULL;
    m_data->risipMedia = NULL;
    m_data->pjsipCall = NULL;
    m_data->callType = RisipCall::Sip;
    m_data->callDirection = Unknown;
    m_data->lastSipResponseCode = Risip::PJSIP_SC_OK;
    m_data->enableVideo = false;  // ⭐ 初始化为 false
}

RisipCall::~RisipCall()
{
    disconnect(this);

    delete m_data;
    m_data = NULL;
}

RisipAccount *RisipCall::account() const
{
    return m_data->account;
}

void RisipCall::setAccount(RisipAccount *acc)
{
    if(m_data->account != acc ) {
        m_data->account = acc;
        emit accountChanged(m_data->account);
    }
}

RisipBuddy *RisipCall::buddy() const
{
    return m_data->buddy;
}

void RisipCall::setBuddy(RisipBuddy *buddy)
{
    if(m_data->buddy != buddy) {
        m_data->buddy = buddy;
        emit buddyChanged(m_data->buddy);
    }

    setCallType(Sip);
}

RisipMedia *RisipCall::media() const
{
    return m_data->risipMedia;
}

void RisipCall::setMedia(RisipMedia *med)
{
    if(m_data->risipMedia != med) {
        if(m_data->risipMedia) {
            delete m_data->risipMedia;
            m_data->risipMedia = NULL;
        }

        m_data->risipMedia = med;
        if(m_data->risipMedia) {
            m_data->risipMedia->setActiveCall(this);
        }

        emit mediaChanged(m_data->risipMedia);
    }
}

int RisipCall::callId() const
{
    if(m_data->pjsipCall)
        return m_data->pjsipCall->getId();  // CRITICAL FIX: Added missing return!

    return -1;
}

/**
 * @brief RisipCall::setPjsipCall
 * @param call
 *
 * Internal API. Initiates the call
 */
void RisipCall::setPjsipCall(PjsipCall *call)
{
    if(m_data->pjsipCall != NULL) {
        delete m_data->pjsipCall;
        m_data->pjsipCall = NULL;
    }

    m_data->pjsipCall = call;
    setMedia(NULL);

    if(m_data->pjsipCall != NULL) {
        m_data->pjsipCall->setRisipCall(this);
    }

    emit statusChanged();
}

/**
 * @brief RisipCall::pjsipCall
 * @return pjsip object
 *
 * Internal API.
 */
PjsipCall *RisipCall::pjsipCall() const
{
    return m_data->pjsipCall;
}

int RisipCall::callType() const
{
    return m_data->callType;
}

void RisipCall::setCallType(int type)
{
    if(m_data->callType != type) {
        m_data->callType = type;
        emit callTypeChanged(m_data->callType);
    }
}

int RisipCall::status() const
{
    qDebug() << "🔍 [RisipCall::status] Called";

    if(m_data->pjsipCall == NULL) {
        qDebug() << "🔍 [RisipCall::status] pjsipCall is NULL, returning Null";
        return Null;
    }

    if(m_data->pjsipCall->isActive()) {
        qDebug() << "🔍 [RisipCall::status] Call is active, getting info...";
        CallInfo callInfo = m_data->pjsipCall->getInfo();
        qDebug() << "🔍 [RisipCall::status] PJSIP state:" << callInfo.state;

        switch (callInfo.state) {
        case PJSIP_INV_STATE_CALLING:
            qDebug() << "🔍 [RisipCall::status] Returning OutgoingCallStarted";
            return RisipCall::OutgoingCallStarted;
        case PJSIP_INV_STATE_CONNECTING:
            qDebug() << "🔍 [RisipCall::status] Returning ConnectingToCall";
            return RisipCall::ConnectingToCall;
        case PJSIP_INV_STATE_CONFIRMED:
            qDebug() << "🔍 [RisipCall::status] Returning CallConfirmed";
            return RisipCall::CallConfirmed;
        case PJSIP_INV_STATE_DISCONNECTED:
            qDebug() << "🔍 [RisipCall::status] Returning CallDisconnected";
            return RisipCall::CallDisconnected;
        case PJSIP_INV_STATE_EARLY:
            qDebug() << "🔍 [RisipCall::status] Returning CallEarly";
            return RisipCall::CallEarly;
        case PJSIP_INV_STATE_INCOMING:
            qDebug() << "🔍 [RisipCall::status] Returning IncomingCallStarted";
            return RisipCall::IncomingCallStarted;
        case PJSIP_INV_STATE_NULL:
            qDebug() << "🔍 [RisipCall::status] Returning Null (PJSIP_INV_STATE_NULL)";
            return RisipCall::Null;
        default:
            qDebug() << "🔍 [RisipCall::status] Unknown state, returning Null";
            return RisipCall::Null;
        }
    } else {
        qDebug() << "🔍 [RisipCall::status] Call not active, returning Null";
        return RisipCall::Null;
    }
}

QDateTime RisipCall::timestamp() const
{
    return m_data->timestamp;
}

/**
 * @brief RisipCall::createTimestamp
 *
 * Internal API.
 */
void RisipCall::createTimestamp()
{
    m_data->timestamp = QDateTime::currentDateTime();
    emit timestampChanged(m_data->timestamp);
}

int RisipCall::callDirection() const
{
    return m_data->callDirection;
}

/**
 * @brief RisipCall::setCallDirection
 * @param direction
 *
 * Internal API.
 */
void RisipCall::setCallDirection(int direction)
{
    if(m_data->callDirection != direction) {
        m_data->callDirection = direction;
        emit callDirectionChanged(m_data->callDirection);
    }
}

/**
 * @brief RisipCall::callDuration
 * @return call duration in msec
 *
 * Retuns the duration of the call in milliseconds.
 *
 * ✅ FIXED: After call ends, PJSIP session is destroyed, so we can't call getInfo().
 * Solution: Check for cached duration in Qt dynamic property first.
 */
long RisipCall::callDuration() const
{
    // ✅ CRITICAL FIX: Check cached duration first (set when call ends)
    // This prevents crash when accessing destroyed PJSIP session
    QVariant cachedDuration = this->property("cachedDuration");
    if (cachedDuration.isValid()) {
        return cachedDuration.toLongLong();
    }

    // If no cache, try to get real-time duration (only works during active call)
    if(!m_data->pjsipCall)
        return 0;

    try {
        // ✅ CRITICAL FIX: Return TOTAL milliseconds (sec * 1000 + msec)
        // PJSIP connectDuration has two fields: sec and msec
        CallInfo info = m_data->pjsipCall->getInfo();
        return (long)(info.connectDuration.sec * 1000 + info.connectDuration.msec);
    } catch (...) {
        // ✅ Catch any exceptions if session is already destroyed
        qWarning() << "Failed to get call duration (session may be destroyed)";
        return 0;
    }
}

int RisipCall::errorCode() const
{
    return m_data->error.status;
}

QString RisipCall::errorMessage()
{
    return QString::fromStdString(m_data->error.reason);
}

QString RisipCall::errorInfo() const
{
    return QString::fromStdString(m_data->error.info(true));
}

int RisipCall::lastResponseCode() const
{
    return m_data->lastSipResponseCode;
}

void RisipCall::setLastResponseCode(int response)
{
    if(m_data->lastSipResponseCode != response) {
        m_data->lastSipResponseCode = response;
        emit lastResponseCodeChanged(response);
    }
}

/**
 * @brief RisipCall::initializeMediaHandler
 *
 * Internal API.
 *
 * Initializes media objects for an active call that has been established and answered.
 */
void RisipCall::initializeMediaHandler()
{
    qDebug() << "✅ [RisipCall] initializeMediaHandler() called";

    if(!m_data->risipMedia) {
        qDebug() << "✅ [RisipCall] Creating new RisipMedia...";
        setMedia(new RisipMedia);
        qDebug() << "✅ [RisipCall] RisipMedia created";
    } else {
        qDebug() << "✅ [RisipCall] RisipMedia already exists";
    }

    qDebug() << "✅ [RisipCall] Calling startCallMedia()...";
    m_data->risipMedia->startCallMedia();
    qDebug() << "✅ [RisipCall] startCallMedia() returned";
}

/**
 * @brief RisipCall::answer
 *
 * Answers an incoming call.
 *
 * @see RisipCallManager how incoming are handled.
 */
void RisipCall::answer()
{
    if(!m_data->account)
        return;

    if(m_data->pjsipCall != NULL) { //check if call object is set
        RisipCallManager::instance()->setActiveCall(this);
        CallOpParam prm;
        prm.statusCode = PJSIP_SC_OK;
        try {
            m_data->pjsipCall->answer(prm);
        } catch (Error &err) {
            setError(err);
        }
    } else {
        qDebug()<<"no account set or call id!";
    }
}

void RisipCall::hangup()
{
    if(m_data->pjsipCall == NULL
            || !m_data->pjsipCall->isActive()) {
        qDebug()<<"no call exists/active";

        emit statusChanged();
        return;
    }

    CallOpParam prm;
    try {
        m_data->pjsipCall->hangup(prm);
    } catch (Error &err) {
        setError(err);
    }

    emit statusChanged();
    RisipCallManager::instance()->setActiveCall(NULL);
}

/**
 * @brief RisipCall::call
 *
 * Internal API.
 * Use may use it with caution. @see RisipCallManager
 */
void RisipCall::call()
{
    if(m_data->callType == Undefined
            || !m_data->account
            || !m_data->buddy)
        return;

    if(m_data->account->status() != RisipAccount::SignedIn)
        return;

    setCallDirection(RisipCall::Outgoing);
    createTimestamp();
    setPjsipCall(new PjsipCall(*m_data->account->pjsipAccount()));
    CallOpParam prm(true);

    // ⭐ 禁用 text 媒体（减小 INVITE 包大小，避免 IP 分片）
    prm.opt.textCount = 0;

    // ⭐ 新增：根据 enableVideo 标志设置视频参数
    if (m_data->enableVideo) {
        prm.opt.videoCount = 1;  // ✅ 启用 1 个视频流（PJSUA2 API）
        prm.opt.audioCount = 1;  // 同时启用音频
        // ❌ 2025-12-31 删除：PJSUA_CALL_INCLUDE_DISABLED_MEDIA 会强制包含禁用的 text 媒体
        // 问题：这个标志会让 PJSIP 在 SDP 中包含所有禁用的媒体（m=text 0），增加 50 字节
        // 原因：videoCount=1 时视频已启用，不需要这个标志
        // prm.opt.flag |= PJSUA_CALL_INCLUDE_DISABLED_MEDIA;  // ← 旧代码（2025-12-31 删除）
        qDebug() << "✅ RisipCall: Enabling video with RKMPP hardware encoding";
    }

    try {
        m_data->pjsipCall->makeCall(m_data->buddy->uri().toStdString(), prm);
    } catch (Error err) {
        setError(err);
    }
}

void RisipCall::invite(const QString &uri)
{
    setCallType(RisipCall::Sip);
    if(!m_data->account && uri.isEmpty())
        return;

    if(m_data->account->status() != RisipAccount::SignedIn)
        return;

    setCallDirection(RisipCall::Outgoing);
    createTimestamp();
    setPjsipCall(new PjsipCall(*m_data->account->pjsipAccount()));
    CallOpParam prm(true);

    // ⭐ 禁用 text 媒体（减小 INVITE 包大小，避免 IP 分片）
    prm.opt.textCount = 0;

    // ⭐ 新增：根据 enableVideo 标志设置视频参数
    if (m_data->enableVideo) {
        prm.opt.videoCount = 1;  // ✅ 启用 1 个视频流（PJSUA2 API）
        prm.opt.audioCount = 1;  // 同时启用音频
        // ❌ 2025-12-31 删除：PJSUA_CALL_INCLUDE_DISABLED_MEDIA 会强制包含禁用的 text 媒体
        // 问题：这个标志会让 PJSIP 在 SDP 中包含所有禁用的媒体（m=text 0），增加 50 字节
        // 原因：videoCount=1 时视频已启用，不需要这个标志
        // prm.opt.flag |= PJSUA_CALL_INCLUDE_DISABLED_MEDIA;  // ← 旧代码（2025-12-31 删除）
        qDebug() << "✅ RisipCall: Enabling video with RKMPP hardware encoding";
    }

    try {
        m_data->pjsipCall->makeCall(uri.toStdString(), prm);
    } catch (Error err) {
        setError(err);
    }
}

void RisipCall::reinvite()
{

}

void RisipCall::transferDirect(const QString &destUri)
{

}

void RisipCall::transferAttendedCall(const QString &destUri)
{

}

/**
 * @brief RisipCall::hold
 * @param hold
 *
 * Use this function to hold/unhold an active call.
 */
void RisipCall::hold(bool hold)
{
    if(m_data->pjsipCall == NULL
            || !m_data->pjsipCall->isActive()) {
        qDebug()<<"no call exists nor is active";
        return;
    }

    if(hold) {
        CallOpParam prm;
        prm.options = PJSUA_CALL_UPDATE_CONTACT;
        try {
            m_data->pjsipCall->setHold(prm);
        } catch (Error &err) {
            setError(err);
        }
    } else {
        CallOpParam prm;
        prm.opt.flag = PJSUA_CALL_UNHOLD;
        try {
            m_data->pjsipCall->reinvite(prm);
        } catch (Error &err) {
            setError(err);
        }
    }
}

/**
 * @brief RisipCall::initiateIncomingCall
 *
 * Internal API.
 *
 * Used for initiating/handling an incoming call from the account.
 *
 * @see RisipCallManager how it is used.
 */
void RisipCall::initiateIncomingCall()
{
    if(!m_data->account)
        return;

    if(m_data->account->status() == RisipAccount::SignedIn) {
        setPjsipCall(m_data->account->incomingPjsipCall());
        createTimestamp();
        setCallDirection(RisipCall::Incoming);
    }
}

void RisipCall::setError(const Error &error)
{
    if(m_data->error.status != error.status) {
        qWarning()<<" ERROR: " <<"code: "<<error.status <<" info: " << QString::fromStdString(error.info(true));

        m_data->error.status = error.status;
        m_data->error.reason = error.reason;
        m_data->error.srcFile = error.srcFile;
        m_data->error.srcLine = error.srcLine;
        m_data->error.title = error.title;

        emit errorCodeChanged(m_data->error.status);
        emit errorMessageChanged(QString::fromStdString(m_data->error.reason));
        emit errorInfoChanged(QString::fromStdString(m_data->error.info(true)));
    }
}

/**
 * @brief RisipCall::enableVideo
 * @return true if video is enabled for this call
 *
 * ⭐ 新增：视频通话支持
 */
bool RisipCall::enableVideo() const
{
    return m_data->enableVideo;
}

/**
 * @brief RisipCall::setEnableVideo
 * @param enable - true to enable video for this call
 *
 * ⭐ 新增：设置是否启用视频
 * 必须在 call() 或 invite() 之前调用才能生效
 */
void RisipCall::setEnableVideo(bool enable)
{
    if(m_data->enableVideo != enable) {
        m_data->enableVideo = enable;
        emit enableVideoChanged(m_data->enableVideo);
    }
}

} //end of risip namespace
