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
#include "pjsipcall.h"

#include "risipcall.h"

#include <QDebug>

namespace risip {

PjsipCall::PjsipCall(PjsipAccount &account, int callId)
    :Call(account, callId)
{
    setRisipCall(NULL);
}

PjsipCall::~PjsipCall()
{
}

/**
 * @brief PjsipCall::onCallState
 * @param prm
 *
 * Pjsip callback each time the state of the call is updated.
 * A call is active when a session has been initiated.
 */
void PjsipCall::onCallState(OnCallStateParam &prm)
{
    Q_UNUSED(prm)
    qDebug() << "🔔 [PJSIP CALLBACK] onCallState() triggered";

    // NOTE: This callback is only triggered for calls created via PJSUA2 C++ API
    // Calls made with pjsua_call_make_call() C API (as in SipPhoneManager::makeCall)
    // do NOT trigger this callback because no PjsipCall C++ object is created

    // Video encoder now starts automatically via vid_out_auto_transmit = PJ_TRUE config
    // No manual intervention needed here

    if(m_risipCall != NULL) {
        qDebug() << "🔔 [PJSIP CALLBACK] Emitting statusChanged signal...";
        m_risipCall->statusChanged();
        qDebug() << "🔔 [PJSIP CALLBACK] statusChanged signal emitted";
    } else {
        qWarning() << "❌ [PJSIP CALLBACK] m_risipCall is NULL!";
    }
}

void PjsipCall::onCallTsxState(OnCallTsxStateParam &prm)
{
    if(m_risipCall != NULL)
        m_risipCall->setLastResponseCode(prm.e.body.tsxState.tsx.statusCode);
}

/**
 * @brief PjsipCall::onCallMediaState
 * @param prm
 *
 * This callback from Pjsip is triggered each time Pjsip intializes the media, in practice this means when the
 * call is being answered and Audio/Video is ready to be transmitted.
 *
 * See more details on @see RisipCall::initalizeMediaHandler
 */
void PjsipCall::onCallMediaState(OnCallMediaStateParam &prm)
{
    Q_UNUSED(prm)
    qDebug() << "✅ [PJSIP CALLBACK] onCallMediaState() callback triggered";

    try {
        if(m_risipCall) {
            qDebug() << "✅ [PJSIP CALLBACK] m_risipCall is valid, calling initializeMediaHandler()...";
            m_risipCall->initializeMediaHandler();
            qDebug() << "✅ [PJSIP CALLBACK] initializeMediaHandler() returned successfully";
        } else {
            qWarning() << "❌ [PJSIP CALLBACK] ERROR: m_risipCall is NULL!";
        }
    } catch (const std::exception &e) {
        qCritical() << "❌ [PJSIP CALLBACK] Exception in onCallMediaState:" << e.what();
    } catch (...) {
        qCritical() << "❌ [PJSIP CALLBACK] Unknown exception in onCallMediaState!";
    }

    qDebug() << "✅ [PJSIP CALLBACK] onCallMediaState() returning...";
}

//logging purpose
void PjsipCall::onCallSdpCreated(OnCallSdpCreatedParam &prm)
{
    Q_UNUSED(prm)
}

//logging purpose
void PjsipCall::onStreamCreated(OnStreamCreatedParam &prm)
{
    qDebug() << "🔔 [PJSIP CALLBACK] onStreamCreated() triggered";
    qDebug() << "🔔 [PJSIP CALLBACK] Stream index:" << prm.streamIdx;
    qDebug() << "🔔 [PJSIP CALLBACK] Stream pointer:" << prm.stream;
    Q_UNUSED(prm)
    qDebug() << "🔔 [PJSIP CALLBACK] onStreamCreated() returning...";
}

//logging purpose
void PjsipCall::onStreamDestroyed(OnStreamDestroyedParam &prm)
{
    Q_UNUSED(prm)
}

//logging purpose
void PjsipCall::onDtmfDigit(OnDtmfDigitParam &prm)
{
    Q_UNUSED(prm)
}

//logging purpose
void PjsipCall::onCallTransferRequest(OnCallTransferRequestParam &prm)
{
    Q_UNUSED(prm)
}

//logging purpose
void PjsipCall::onCallTransferStatus(OnCallTransferStatusParam &prm)
{
    Q_UNUSED(prm)
}

//logging purpose
void PjsipCall::onCallReplaceRequest(OnCallReplaceRequestParam &prm)
{
    Q_UNUSED(prm)
}

//logging purpose
void PjsipCall::onCallReplaced(OnCallReplacedParam &prm)
{
    Q_UNUSED(prm)
}

//logging purpose
void PjsipCall::onCallRxOffer(OnCallRxOfferParam &prm)
{
    Q_UNUSED(prm)
}

//logging purpose
void PjsipCall::onCallTxOffer(OnCallTxOfferParam &prm)
{
    Q_UNUSED(prm)
}

//logging purpose
void PjsipCall::onInstantMessage(OnInstantMessageParam &prm)
{
    Q_UNUSED(prm)
}

//logging purpose
void PjsipCall::onInstantMessageStatus(OnInstantMessageStatusParam &prm)
{
    Q_UNUSED(prm)
}

//logging purpose
void PjsipCall::onTypingIndication(OnTypingIndicationParam &prm)
{
    Q_UNUSED(prm)
}

//logging purpose
pjsip_redirect_op PjsipCall::onCallRedirected(OnCallRedirectedParam &prm)
{
    Q_UNUSED(prm)
    return PJSIP_REDIRECT_ACCEPT;
}

//logging purpose
void PjsipCall::onCallMediaTransportState(OnCallMediaTransportStateParam &prm)
{
    Q_UNUSED(prm)
}

//logging purpose
void PjsipCall::onCallMediaEvent(OnCallMediaEventParam &prm)
{

    Q_UNUSED(prm)
}

//logging purpose
void PjsipCall::onCreateMediaTransport(OnCreateMediaTransportParam &prm)
{
    Q_UNUSED(prm)
}

void PjsipCall::setRisipCall(RisipCall *risipcall)
{
    m_risipCall = risipcall;
}

} //end of risip namespace
