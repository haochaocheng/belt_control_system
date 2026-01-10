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

#include "risipendpoint.h"
#include "risipaccountconfiguration.h"
#include "risip.h"

#include "pjsipwrapper/pjsipendpoint.h"

// PJSUA C API for audio routing callback
#include <pjsua.h>

// ✅ PJSIP internal header for accessing global state
// This is the official way to access pjsua_var
#include <pjsua-lib/pjsua_internal.h>

// ✅ Include SipPhoneManager for video call detection
#include "../../sip_phone/SipPhoneManager.h"

#include <QDebug>
#include <QSet>

namespace risip {

// ✅ Store original PJSUA2 callback so we can call it after our audio routing
static pjsua_callback *original_pjsua2_callback = NULL;

// ✅ Track which calls have already had audio connected to prevent duplicate connections
static QSet<pjsua_call_id> calls_with_audio_connected;
static bool in_callback = false;  // Prevent recursive callback invocation

// ✅ Callback function pointer for notifying UI about call state changes
// SipPhoneManager will register itself here to receive call state updates
typedef void (*CallStateNotificationCallback)(pjsua_call_id call_id, pjsip_inv_state state, const char* state_text);
static CallStateNotificationCallback ui_call_state_callback = NULL;

// ✅ Our audio routing callback wrapper
// This is called by PJSIP whenever call media state changes
// We handle audio routing for C API calls, then delegate to PJSUA2's original callback
static void audio_routing_callback_wrapper(pjsua_call_id call_id)
{
    // ✅ Prevent recursive callback invocation
    if (in_callback) {
        return;
    }
    in_callback = true;

    pjsua_call_info ci;
    pj_status_t status = pjsua_call_get_info(call_id, &ci);

    if (status != PJ_SUCCESS) {
        qWarning() << "❌ [AUDIO CALLBACK] Failed to get call info for call" << call_id;
        in_callback = false;
        return;
    }

    // ✅ CRITICAL FIX: Detect video in media state callback (THIS is when media_cnt becomes > 0!)
    // This callback is triggered when PJSIP processes SDP and initializes media streams
    // At this point, ci.media_cnt will finally be populated with actual media information
    qDebug() << "📞 [MEDIA STATE] Call" << call_id << "media_cnt:" << ci.media_cnt
             << "state:" << ci.state << "media_status:" << ci.media_status;

    // Check for video on FIRST callback for this call (before media becomes active)
    static QSet<pjsua_call_id> calls_checked_for_video;
    if (!calls_checked_for_video.contains(call_id)) {
        calls_checked_for_video.insert(call_id);

        bool hasVideo = false;
        for (unsigned i = 0; i < ci.media_cnt; ++i) {
            qDebug() << "📞 [MEDIA STATE] Media" << i << ": type=" << ci.media[i].type
                     << "dir=" << ci.media[i].dir << "status=" << ci.media[i].status
                     << "(AUDIO=" << PJMEDIA_TYPE_AUDIO << ", VIDEO=" << PJMEDIA_TYPE_VIDEO << ")";

            if (ci.media[i].type == PJMEDIA_TYPE_VIDEO && ci.media[i].dir != PJMEDIA_DIR_NONE) {
                hasVideo = true;
                qDebug() << "✅ [MEDIA STATE] Detected video in call" << call_id;
            }
        }

        qDebug() << "📞 [MEDIA STATE] Final result for call" << call_id << ": hasVideo =" << hasVideo;

        // Notify SipPhoneManager if this is an incoming call
        if (ci.state == PJSIP_INV_STATE_INCOMING || ci.state == PJSIP_INV_STATE_EARLY) {
            if (SipPhoneManager::instance()) {
                qDebug() << "📞 [MEDIA STATE] Setting isIncomingVideoCall =" << hasVideo;
                SipPhoneManager::instance()->setIsIncomingVideoCall(hasVideo);
            }
        }
    }

    // Clean up tracking when call disconnects (must be outside the checked block)
    if (ci.state == PJSIP_INV_STATE_DISCONNECTED) {
        calls_checked_for_video.remove(call_id);
    }

    // Only connect audio when media becomes active AND not already connected
    if (ci.media_status == PJSUA_CALL_MEDIA_ACTIVE && !calls_with_audio_connected.contains(call_id)) {
        qDebug() << "✅ [AUDIO CALLBACK] Media active for call" << call_id
                 << "conf_slot:" << ci.conf_slot;

        // Connect bidirectionally (official PJSIP pattern from simple_pjsua.c)
        // Connect sound device (port 0) to call audio
        status = pjsua_conf_connect(0, ci.conf_slot);
        if (status == PJ_SUCCESS) {
            qDebug() << "✅ [AUDIO CALLBACK] Connected: sound device (0) → call (" << ci.conf_slot << ")";
        } else {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            qWarning() << "❌ [AUDIO CALLBACK] Failed to connect sound→call:" << errmsg;
        }

        // Connect call audio to sound device (port 0)
        status = pjsua_conf_connect(ci.conf_slot, 0);
        if (status == PJ_SUCCESS) {
            qDebug() << "✅ [AUDIO CALLBACK] Connected: call (" << ci.conf_slot << ") → sound device (0)";
        } else {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(status, errmsg, sizeof(errmsg));
            qWarning() << "❌ [AUDIO CALLBACK] Failed to connect call→sound:" << errmsg;
        }

        // Mark this call as connected
        calls_with_audio_connected.insert(call_id);
        qDebug() << "✅ [AUDIO CALLBACK] Audio routing completed for call" << call_id;
    }

    // Clean up tracking when call is disconnected
    if (ci.state == PJSIP_INV_STATE_DISCONNECTED) {
        calls_with_audio_connected.remove(call_id);
        qDebug() << "✅ [AUDIO CALLBACK] Removed tracking for disconnected call" << call_id;
    }

    // ✅ Call original PJSUA2 callback for C++ Call object handling
    // This is safe because we have the recursion guard
    if (original_pjsua2_callback && original_pjsua2_callback->on_call_media_state) {
        original_pjsua2_callback->on_call_media_state(call_id);
    }

    in_callback = false;
}

// ✅ Our call state callback wrapper
// This is called by PJSIP whenever call state changes (ringing, connected, disconnected, etc.)
// We notify the UI and delegate to PJSUA2's original callback
static void call_state_callback_wrapper(pjsua_call_id call_id, pjsip_event *e)
{
    qDebug() << "🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() called, call_id:" << call_id;

    static bool in_state_callback = false;

    // Prevent recursive invocation
    if (in_state_callback) {
        qDebug() << "⚠️ [PJSIP C CALLBACK] Recursive invocation detected, returning";
        return;
    }
    in_state_callback = true;

    qDebug() << "🔔 [PJSIP C CALLBACK] Getting call info...";
    pjsua_call_info ci;
    pj_status_t status = pjsua_call_get_info(call_id, &ci);
    qDebug() << "🔔 [PJSIP C CALLBACK] pjsua_call_get_info() status:" << status;

    if (status == PJ_SUCCESS) {
        // Notify UI about call state change
        if (ui_call_state_callback) {
            ui_call_state_callback(call_id, ci.state, ci.state_text.ptr);
        }

        qDebug() << "✅ [CALL STATE] Call" << call_id << "state:" << ci.state_text.ptr;

        // ✅ CRITICAL FIX: Detect video in incoming INVITE by parsing raw SDP
        // media_cnt is 0 at INCOMING state, so we must parse the INVITE SDP directly
        if (ci.state == PJSIP_INV_STATE_INCOMING) {
            qDebug() << "📞 [DEBUG] INCOMING state detected, checking event...";
            qDebug() << "📞 [DEBUG] Event pointer:" << (void*)e;

            if (e) {
                qDebug() << "📞 [DEBUG] Event type:" << e->type;
                qDebug() << "📞 [DEBUG] PJSIP_EVENT_TSX_STATE =" << PJSIP_EVENT_TSX_STATE;
                qDebug() << "📞 [DEBUG] PJSIP_EVENT_RX_MSG =" << PJSIP_EVENT_RX_MSG;

                if (e->type == PJSIP_EVENT_TSX_STATE) {
                    qDebug() << "📞 [DEBUG] tsx_state.type =" << e->body.tsx_state.type;
                }
            }

            bool hasVideo = false;
            qDebug() << "📞 [INCOMING VIDEO DETECTION] Getting remote SDP from invite session";

            // Get the invite session to access remote SDP
            // We need to use pjsua_var to access the call's invite session
            pjsip_inv_session *inv = pjsua_var.calls[call_id].inv;

            qDebug() << "📞 [DEBUG] inv session:" << (void*)inv;

            if (inv && inv->neg) {
                const pjmedia_sdp_session *remote_sdp = NULL;
                pj_status_t sdp_status = pjmedia_sdp_neg_get_neg_remote(inv->neg, &remote_sdp);
                qDebug() << "📞 [DEBUG] pjmedia_sdp_neg_get_neg_remote status:" << sdp_status << "remote_sdp:" << (void*)remote_sdp;

                if (sdp_status == PJ_SUCCESS && remote_sdp) {
                    qDebug() << "📞 [DEBUG] SDP media count:" << remote_sdp->media_count;

                    // Check each media stream for video
                    for (unsigned i = 0; i < remote_sdp->media_count; ++i) {
                        const pjmedia_sdp_media *m = remote_sdp->media[i];
                        qDebug() << "📞 [DEBUG] Media" << i << ": type=" << QString::fromUtf8(m->desc.media.ptr, m->desc.media.slen)
                                 << "port=" << m->desc.port;

                        // Check if this is video media with active port
                        if (pj_stricmp2(&m->desc.media, "video") == 0 && m->desc.port > 0) {
                            hasVideo = true;
                            qDebug() << "✅ Detected active video in remote SDP: port" << m->desc.port;
                            break;
                        }
                    }
                } else {
                    qDebug() << "📞 [DEBUG] Failed to get negotiated remote SDP or SDP is NULL";
                }
            } else {
                qDebug() << "📞 [DEBUG] inv or inv->neg is NULL";
            }

            qDebug() << "📞 [INCOMING VIDEO DETECTION] Final result: hasVideo =" << hasVideo;

            // Update SipPhoneManager's incoming video flag
            if (SipPhoneManager::instance()) {
                SipPhoneManager::instance()->setIsIncomingVideoCall(hasVideo);
            }
        }
    }

    // Call original PJSUA2 callback
    qDebug() << "🔔 [PJSIP C CALLBACK] Calling original PJSUA2 on_call_state callback...";
    if (original_pjsua2_callback && original_pjsua2_callback->on_call_state) {
        original_pjsua2_callback->on_call_state(call_id, e);
        qDebug() << "🔔 [PJSIP C CALLBACK] Original callback returned";
    } else {
        qDebug() << "⚠️ [PJSIP C CALLBACK] No original callback registered";
    }

    qDebug() << "🔔 [PJSIP C CALLBACK] call_state_callback_wrapper() completed";
    in_state_callback = false;
}

// ✅ Our incoming call callback wrapper
// This is called by PJSIP when receiving an incoming call
// We automatically answer video calls with video enabled
static void incoming_call_callback_wrapper(pjsua_acc_id acc_id, pjsua_call_id call_id, pjsip_rx_data *rdata)
{
    static bool in_incoming_callback = false;

    // Prevent recursive invocation
    if (in_incoming_callback) {
        return;
    }
    in_incoming_callback = true;

    pjsua_call_info ci;
    pj_status_t status = pjsua_call_get_info(call_id, &ci);

    if (status == PJ_SUCCESS) {
        // ✅ Parse SDP directly from INVITE message to detect video
        // media_cnt is 0 at this point because SDP negotiation happens later
        // We need to parse the incoming INVITE's SDP body directly
        bool has_video = false;

        if (rdata && rdata->msg_info.msg) {
            pjsip_msg_body *body = rdata->msg_info.msg->body;

            if (body && body->len > 0) {
                // Get SDP text
                char sdp_text[4096];
                int printed = body->print_body(body, sdp_text, sizeof(sdp_text));

                if (printed > 0 && printed < sizeof(sdp_text)) {
                    QString sdpStr = QString::fromUtf8(sdp_text, printed);
                    qDebug() << "📞 [INCOMING CALL] Parsing SDP from INVITE message";
                    qDebug() << "📞 [SDP]:\n" << sdpStr;

                    // Check if SDP contains video media line (m=video)
                    if (sdpStr.contains("m=video", Qt::CaseInsensitive)) {
                        // Check if video port is not 0 (port 0 means inactive/rejected)
                        QStringList lines = sdpStr.split('\n');
                        for (const QString &line : lines) {
                            if (line.startsWith("m=video", Qt::CaseInsensitive)) {
                                // Format: m=video <port> <transport> <formats...>
                                QStringList parts = line.split(' ');
                                if (parts.size() >= 2) {
                                    int port = parts[1].toInt();
                                    if (port > 0) {
                                        has_video = true;
                                        qDebug() << "✅ Detected video in SDP: m=video" << port;
                                    } else {
                                        qDebug() << "⚠️ Video offered but inactive (port 0)";
                                    }
                                }
                                break;
                            }
                        }
                    }
                }
            }
        }

        qDebug() << "✅ [INCOMING CALL] Call" << call_id
                 << "from:" << QString::fromUtf8(ci.remote_info.ptr, ci.remote_info.slen)
                 << (has_video ? "(Video)" : "(Audio only)");
        qDebug() << "📞 [INCOMING CALL] Final result: hasVideo =" << has_video;

        // ✅ Notify SipPhoneManager about video call status
        if (SipPhoneManager::instance()) {
            SipPhoneManager::instance()->setIsIncomingVideoCall(has_video);
        }

        // ❌ DO NOT auto-answer - let user decide via UI buttons
        // User will see three buttons for video calls or two buttons for audio calls
    }

    // Call original PJSUA2 callback
    if (original_pjsua2_callback && original_pjsua2_callback->on_incoming_call) {
        original_pjsua2_callback->on_incoming_call(acc_id, call_id, rdata);
    }

    in_incoming_callback = false;
}

class RisipEndpoint::Private
{
public:
    PjsipEndpoint *pjsipEndpoint;
    TransportId activeTransportId;
    EpConfig endpointConfig;
    Error error;
};

RisipEndpoint::RisipEndpoint(QObject *parent)
    :QObject(parent)
    ,m_data(new Private)
{
    m_data->activeTransportId = -1;
}

RisipEndpoint::~RisipEndpoint()
{
    delete PjsipEndpoint::instance();
    m_data->pjsipEndpoint = NULL;

    delete m_data;
    m_data = NULL;
}

/**
 * @brief RisipEndpoint::status
 * @return status of the SIP endpoint / engine
 *
 * Use this property to see the status of the SIP library whether it has started, stoped or
 * it has an error.
 */
int RisipEndpoint::status() const
{
    if(!m_data->pjsipEndpoint)
        return RisipEndpoint::NotStarted;

    switch (m_data->pjsipEndpoint->libGetState()) {
    case PJSUA_STATE_NULL:
    case PJSUA_STATE_CREATED:
    case PJSUA_STATE_INIT:
    case PJSUA_STATE_STARTING:
    case PJSUA_STATE_CLOSING:
        return RisipEndpoint::NotStarted;
    case PJSUA_STATE_RUNNING:
        return RisipEndpoint::Started;
    default:
        return RisipEndpoint::EngineError;
    }
}

/**
 * @brief RisipEndpoint::errorCode
 * @return the last error code if the status of SIP endpoint is EngineError
 *
 * If the status of this endpoint is EngineError @see RisipEndpoint::status then use this property
 * to errorCode get the last error code.
 */
int RisipEndpoint::errorCode() const
{
    return m_data->error.status;
}

/**
 * @brief RisipEndpoint::errorMessage
 * @return returns the last error message
 *
 * Use this property to retrieve the last error message.
 */
QString RisipEndpoint::errorMessage() const
{
    return QString::fromStdString(m_data->error.reason);
}

/**
 * @brief RisipEndpoint::errorInfo
 * @return returns the last error complete info message
 *
 * Use this property to see the complete error information
 */
QString RisipEndpoint::errorInfo() const
{
    return QString::fromStdString(m_data->error.info(true));
}

int RisipEndpoint::activeTransportId() const
{
    return m_data->activeTransportId;
}

bool RisipEndpoint::createTransportNetwork(RisipAccountConfiguration *accountConf)
{
    if(status() == NotStarted
            || status() == EngineError)
        return false;

    pjsip_transport_type_e netType;
    switch (accountConf->networkProtocol()) {
    case RisipAccountConfiguration::UDP:
        netType = PJSIP_TRANSPORT_UDP;
        break;
    case RisipAccountConfiguration::TCP:
        netType = PJSIP_TRANSPORT_TCP;
        break;
    case RisipAccountConfiguration::TLS:
        netType = PJSIP_TRANSPORT_TLS;
        break;
//    case RisipAccountConfiguration::UDP6:
//        netType = PJSIP_TRANSPORT_UDP6;
//        break;
//    case RisipAccountConfiguration::TCP6:
//        netType = PJSIP_TRANSPORT_TCP6;
//        break;
//    case RisipAccountConfiguration::TLS6:
//        netType = PJSIP_TRANSPORT_TLS6;
//        break;
    default:
        netType = PJSIP_TRANSPORT_UDP; //defaults to UDP always
        break;
    }

    try {
        m_data->activeTransportId = m_data->pjsipEndpoint->transportCreate(netType, accountConf->pjsipTransportConfig());
    } catch (Error& err) {
        setError(err);
        return false;
    }

    return true;
}

/**
 * @brief RisipEndpoint::destroyActiveTransport
 * @return true/false if transport is destoryed or not.
 *
 * Internal API.
 */
bool RisipEndpoint::destroyActiveTransport()
{
    //is there an active transport?
    if(m_data->activeTransportId == -1)
        return true;

    //closing it current active network transport.
    try {
        m_data->pjsipEndpoint->transportClose(m_data->activeTransportId);
    } catch(Error& err) {
        setError(err);
        return false;
    }

    return true;
}

PjsipEndpoint *RisipEndpoint::endpointInstance()
{
    return PjsipEndpoint::instance();
}

/**
 * @brief RisipEndpoint::start
 *
 * Use this function to start the SIP endpoint library/engine.
 * MUST call this before any other operation with Risip objects.
 */
int RisipEndpoint::start()
{
    m_data->pjsipEndpoint = PjsipEndpoint::instance();
    m_data->pjsipEndpoint->setRisipEndpointInterface(this);

    // Configure endpoint for better performance
    m_data->endpointConfig.uaConfig.maxCalls = 8;        // Increase max simultaneous calls (default: 4)
    m_data->endpointConfig.uaConfig.threadCnt = 2;       // Increase worker threads
    m_data->endpointConfig.medConfig.threadCnt = 2;      // Increase media threads
    m_data->endpointConfig.medConfig.clockRate = 16000;  // Higher clock rate for better quality
    m_data->endpointConfig.medConfig.hasIoqueue = true;  // Enable IO queue for better performance

    // ✅ FIX: Force stereo audio (2 channels) instead of mono to fix ALSA errors
    // ALSA device only supports 2 channels (stereo), but PJSIP defaults to 1 (mono)
    // Error: "Unable to set a channel count of 1 for playback device"
    m_data->endpointConfig.medConfig.channelCount = 2;   // Use stereo (2 channels) for audio

    // Video default is controlled by PJSUA_DEFAULT_VID_CNT in config_site.h (set to 0)

    // ❌ 2025-XX-XX 旧代码：运行时禁用预览窗口（无效，已废弃）
    // 问题：vidPreviewEnableNative 只禁用"native"预览，PJSIP 仍会创建 SDL 预览窗口
    // 结果：导致视频端口从 4002 变为 4006，SDP 不匹配 → 无法接收视频
    // 日志证据：pjsua_vid.c "Creating video window: type=preview, cap_id=1"
    // ✅ 2026-01-02 14:00 [修复 29]
    // 已在 pjsip_config_site.h 中添加 PJSUA_VID_PREVIEW_DISABLE 1 编译时禁用
    // 参考：docs/2026-01-02/视频端口不匹配问题-PJSIP预览窗口分析.md
    // m_data->endpointConfig.medConfig.vidPreviewEnableNative = false;  // ← 无效，已禁用

    try {
        m_data->pjsipEndpoint->libCreate();
    } catch (Error &err) {
        emit statusChanged(status());
        setError(err);
        return status();
    }

    try {
        m_data->pjsipEndpoint->libInit(m_data->endpointConfig);
    } catch (Error &err) {
        emit statusChanged(status());
        setError(err);
        return status();
    }

    try {
        m_data->pjsipEndpoint->libStart();
    } catch (Error &err) {
        emit statusChanged(status());
        setError(err);
        return status();
    }

    // ✅ CRITICAL FIX: Install callback wrappers AFTER libStart()
    // At this point PJSIP is fully initialized and PJSUA2 has set its own callbacks
    // We save the original callbacks and install our wrappers which:
    //   1. Handle audio routing for C API video calls
    //   2. Notify UI about call state changes
    //   3. Auto-answer incoming video calls with video enabled
    //   4. Call the original PJSUA2 callbacks for C++ Call objects
    // This approach works because PJSIP calls pjsua_var.ua_cfg.cb.* at runtime
    original_pjsua2_callback = &pjsua_var.ua_cfg.cb;
    pjsua_var.ua_cfg.cb.on_call_media_state = &audio_routing_callback_wrapper;
    pjsua_var.ua_cfg.cb.on_call_state = &call_state_callback_wrapper;
    pjsua_var.ua_cfg.cb.on_incoming_call = &incoming_call_callback_wrapper;
    qDebug() << "✅ RisipEndpoint: Installed audio routing, call state, and incoming call callback wrappers";

    // ✅ CRITICAL FIX: Set global default video capture device
    // PJSIP uses global default device when cap_id=-1, NOT account-level vid_cap_dev!
    // This must be done AFTER libStart() when video subsystem is ready
    unsigned vidDevCount = pjsua_vid_dev_count();
    qDebug() << "RisipEndpoint: Total video devices:" << vidDevCount;

    pjmedia_vid_dev_index firstRealCamera = -1;
    for (unsigned i = 0; i < vidDevCount; ++i) {
        pjmedia_vid_dev_info devInfo;
        if (pjsua_vid_dev_get_info(i, &devInfo) == PJ_SUCCESS) {
            qDebug() << "  Device" << i << ":" << devInfo.name << "| Dir:" << devInfo.dir
                     << "| Driver:" << devInfo.driver;

            // Find first real capture device (skip colorbar/null)
            if (firstRealCamera == -1 && (devInfo.dir & PJMEDIA_DIR_CAPTURE)) {
                QString deviceName = QString::fromUtf8(devInfo.name);
                if (!deviceName.contains("colorbar", Qt::CaseInsensitive) &&
                    !deviceName.contains("null", Qt::CaseInsensitive)) {
                    firstRealCamera = i;
                    qDebug() << "  ✅ Selected" << i << "as default capture device:" << devInfo.name;
                }
            }
        }
    }

    // ✅ NOTE: Global default device NOT needed here
    // The cap_id=-1 bug is fixed at PJSIP source level (pjsua_vid.c:1224)
    // PJSIP now uses call_med->strm.v.cap_dev (account-level config) instead of hardcoded -1

    // ✅ 2026-01-10 13:30 [修复 100.10.1] 智能选择音频设备，避免使用无效设备
    // 问题：pjsua_set_snd_dev(0, 0) 失败，错误 PJMEDIA_EAUD_INVDEV (420004)
    // 根因：ALSA 找到 11 个设备，但设备 0 不可用
    // 解决：枚举所有音频设备，找到第一个可用的设备；如果都失败，使用 null audio device
    // 证据：docs/log/voip.md "Error retrieving default audio device parameters: Invalid audio device"
    qDebug() << "🎵 [AUDIO DEV] Configuring global audio device (fix PJMEDIA_EAUD_NODEFDEV)...";

    // 枚举所有音频设备
    unsigned aud_dev_count = pjmedia_aud_dev_count();
    qDebug() << "  Total audio devices:" << aud_dev_count;

    int first_valid_dev = -1;
    for (unsigned i = 0; i < aud_dev_count; ++i) {
        pjmedia_aud_dev_info dev_info;
        pj_status_t status = pjmedia_aud_dev_get_info(i, &dev_info);
        if (status == PJ_SUCCESS) {
            QString dev_name = QString::fromUtf8(dev_info.name);
            qDebug() << "    Device" << i << ":" << dev_name
                     << "| Caps:" << dev_info.input_count << "in /" << dev_info.output_count << "out"
                     << "| Driver:" << dev_info.driver;

            // 跳过 "default" 设备（可能不工作）
            if (first_valid_dev == -1 &&
                dev_info.input_count > 0 && dev_info.output_count > 0 &&
                !dev_name.contains("default", Qt::CaseInsensitive)) {
                first_valid_dev = i;
                qDebug() << "      ✅ Selected as first valid device";
            }
        }
    }

    // 尝试设置音频设备
    pj_status_t snd_status = PJ_ENOTFOUND;

    if (first_valid_dev != -1) {
        // 尝试使用第一个有效设备
        qDebug() << "  Trying device" << first_valid_dev << "...";
        snd_status = pjsua_set_snd_dev(first_valid_dev, first_valid_dev);
        if (snd_status == PJ_SUCCESS) {
            qDebug() << "  ✅ Global audio device set:" << "capture=" << first_valid_dev << ", playback=" << first_valid_dev;
        } else {
            qDebug() << "  ⚠️ Device" << first_valid_dev << "failed (status=" << snd_status << ")";
        }
    }

    // 如果所有设备都失败，使用 null audio device
    if (snd_status != PJ_SUCCESS) {
        qDebug() << "  ⚠️ All devices failed, trying null audio device...";
        snd_status = pjsua_set_null_snd_dev();
        if (snd_status == PJ_SUCCESS) {
            qDebug() << "  ✅ Null audio device enabled (no real audio, but calls will work)";
        } else {
            qDebug() << "  ❌ Even null audio device failed (status=" << snd_status << ")";
            qDebug() << "     Video calls may fail - check ALSA configuration";
        }
    }

    // ✅ 2025-12-31 关键修复：减少音频编解码器以避免 IP 分片
    // 原因：INVITE 消息 1682 字节 > MTU 1500 字节，导致 IP 分片，PortSIP 无响应
    // 解决：保留常用的 PCMA/PCMU/Opus，禁用其他编解码器
    // 注意：用户要求保留 Opus，后续会使用 Opus 编码
    // 参考：docs/2025-12-29/IP分片问题排查与修复.md
    qDebug() << "🎵 [CODEC] Configuring audio codecs (reduced set to avoid IP fragmentation)...";

    //FIXME Codec priorities
    //TODO Codecs settings page
    // Wrap codec priority settings in try-catch to handle missing codecs gracefully
    try {
        Endpoint::instance().codecSetPriority("PCMA/8000", 215);
        qDebug() << "  ✅ PCMA/8000 enabled (priority: 215)";
    } catch (Error &err) {
        qDebug() << "Warning: Could not set PCMA codec priority:" << QString::fromStdString(err.reason);
    }

    try {
        Endpoint::instance().codecSetPriority("PCMU/8000", 214);
        qDebug() << "  ✅ PCMU/8000 enabled (priority: 214)";
    } catch (Error &err) {
        qDebug() << "Warning: Could not set PCMU codec priority:" << QString::fromStdString(err.reason);
    }

    try {
        Endpoint::instance().codecSetPriority("opus/48000/2", 213);
        qDebug() << "  ✅ opus/48000/2 enabled (priority: 213) - 用户要求保留，后续使用";
    } catch (Error &err) {
        qDebug() << "Warning: Could not set Opus codec priority:" << QString::fromStdString(err.reason);
    }

    // 2025-12-31: 禁用以下编解码器以减小 SDP 大小（避免 IP 分片）
    try {
        Endpoint::instance().codecSetPriority("GSM/8000", 0);
        qDebug() << "  ⛔ GSM/8000 disabled (to reduce SDP size)";
    } catch (Error &err) {
        qDebug() << "Warning: Could not disable GSM codec:" << QString::fromStdString(err.reason);
    }

    try {
        Endpoint::instance().codecSetPriority("iLBC/8000", 0);
        qDebug() << "  ⛔ iLBC/8000 disabled (to reduce SDP size)";
    } catch (Error &err) {
        qDebug() << "Warning: Could not disable iLBC codec:" << QString::fromStdString(err.reason);
    }

    try {
        Endpoint::instance().codecSetPriority("telephone-event/8000", 0);
        qDebug() << "  ⛔ telephone-event/8000 disabled (to reduce SDP size)";
    } catch (Error &err) {
        qDebug() << "Warning: Could not disable telephone-event 8kHz:" << QString::fromStdString(err.reason);
    }

    try {
        Endpoint::instance().codecSetPriority("telephone-event/48000", 0);
        qDebug() << "  ⛔ telephone-event/48000 disabled (to reduce SDP size)";
    } catch (Error &err) {
        qDebug() << "Warning: Could not disable telephone-event 48kHz:" << QString::fromStdString(err.reason);
    }

    try {
        Endpoint::instance().codecSetPriority("g722/16000", 0);
        qDebug() << "  ⛔ g722/16000 disabled";
    } catch (Error &err) {
        qDebug() << "Warning: Could not set G.722 codec priority:" << QString::fromStdString(err.reason);
    }

    try {
        Endpoint::instance().codecSetPriority("speex/16000", 0);
    } catch (Error &err) {
        qDebug() << "Warning: Could not set Speex 16kHz codec priority:" << QString::fromStdString(err.reason);
    }

    try {
        Endpoint::instance().codecSetPriority("speex/8000", 0);
    } catch (Error &err) {
        qDebug() << "Warning: Could not set Speex 8kHz codec priority:" << QString::fromStdString(err.reason);
    }

    try {
        Endpoint::instance().codecSetPriority("speex/32000", 0);
    } catch (Error &err) {
        qDebug() << "Warning: Could not set Speex 32kHz codec priority:" << QString::fromStdString(err.reason);
    }

    qDebug() << "✅ [CODEC] Audio codec configuration complete";
    qDebug() << "  Enabled: PCMA, PCMU, Opus (3 codecs - 用户要求保留 Opus)";
    qDebug() << "  Disabled: GSM, iLBC, telephone-event, g722, speex";
    qDebug() << "  Expected SDP reduction: ~200 bytes (from 1682 → ~1480 bytes)";
    qDebug() << "  Target: < MTU 1500 bytes to avoid IP fragmentation";


    // ✅ CRITICAL FIX: Configure H264 encoder for 25fps to fix choppy outgoing video
    // This must be done after libStart() when video subsystem is initialized
    qDebug() << "========================================";
    qDebug() << "📹 [ATTEMPT 14] Configuring H264 for 720P (1280x720)...";
    qDebug() << "========================================";

    pjmedia_vid_codec_param h264_param;
    pj_str_t h264_codec_id = pj_str((char*)"H264");
    pj_status_t vid_status = pjsua_vid_codec_get_param(&h264_codec_id, &h264_param);

    if (vid_status == PJ_SUCCESS) {
        // ✅ CRITICAL: Check if format structure is initialized before accessing det.vid
        // If detail_type is not PJMEDIA_FORMAT_DETAIL_VIDEO, calling det.vid will crash
        // This happens when default_attr() hasn't been called yet (e.g. manual codec registration)
        if (h264_param.enc_fmt.detail_type != PJMEDIA_FORMAT_DETAIL_VIDEO) {
            qDebug() << "⚠️ H264 format not initialized (detail_type=" << h264_param.enc_fmt.detail_type
                     << "), initializing manually...";

            // Initialize format structures properly
            // ❌ 2025-12-31 18:25 旧代码：25fps 编码器帧率过高，导致摄像头资源冲突
            // pjmedia_format_init_video(&h264_param.enc_fmt,
            //                          PJMEDIA_FORMAT_H264,  // H.264 format ID
            //                          1280, 720,            // 720P resolution
            //                          25, 1);               // 25 fps
            // ❌ 2025-12-31 19:15 旧代码：降低到 15fps，但测试发现 15fps 反而更糟（V4L2 驱动不稳定）
            // pjmedia_format_init_video(&h264_param.enc_fmt,
            //                          PJMEDIA_FORMAT_H264,  // H.264 format ID
            //                          1280, 720,            // 720P resolution
            //                          15, 1);               // 15 fps
            // ❌ 2025-12-31 19:50 旧代码：使用 25fps（V4L2 默认值），但 1280x720 导致 RGA 缩放失败
            // pjmedia_format_init_video(&h264_param.enc_fmt,
            //                          PJMEDIA_FORMAT_H264,  // H.264 format ID
            //                          1280, 720,            // 720P resolution
            //                          25, 1);               // 25 fps（V4L2 默认值）
            // ❌ 2025-12-31 20:20 旧代码：降低到 640x360，匹配对方实际分辨率，避免 RGA 缩放错误
            // ❌ 2026-01-11 01:45 [修复 100.29] 修改为 640x368 以满足 h264_rkmpp 的 16 像素对齐要求
            // 原因：h264_rkmpp 要求高度必须是 16 的倍数（H.264 宏块结构）
            // 360 = 16 × 22.5 ❌，368 = 16 × 23 ✅
            // 问题：V4L2 驱动不支持非标准分辨率 640x368，fallback 到 1280x720
            // ❌ 2026-01-11 03:30 [修复 100.32] 使用摄像头硬件支持的 640x480 @ 30fps
            // 根据：docs/2026-01-11/06-摄像头支持分辨率调查结果.md
            // 理由：VGA 标准分辨率，100% 硬件支持，完美 16 像素对齐（640=16×40, 480=16×30）
            // 问题：对方（PortSIP）发送 640x360，视频会议桥缩放为 768x432，编码器仍报-22错误
            // ✅ 2026-01-11 04:20 [修复 100.34] 匹配对方分辨率 640x360，测试编码器是否接受
            // 根据：docs/2026-01-11/10-Fix100.33失败分析-对方发送640x360导致缩放.md
            // 理由：对方发送640x360，本地也用640x360，避免视频会议桥缩放
            // 风险：360不是16倍数，但可以测试h264_rkmpp是否容忍
            // ✅ 2026-01-11 11:20 [修复 100.37] 改回 VGA 640x480（对方已切换到 VGA）
            // 根据：V4L2 不支持 I420@640x360（只支持 MJPEG@640x360），对方已切换到 VGA
            // 优点：YUYV@640x480 @ 30fps 未压缩格式，完美 16 像素对齐（640=16×40, 480=16×30）
            pjmedia_format_init_video(&h264_param.enc_fmt,
                                     PJMEDIA_FORMAT_H264,  // H.264 format ID
                                     640, 480,             // VGA resolution (perfect 16-aligned)
                                     30, 1);               // ✅ 30 fps

            // ❌ 2025-12-31 18:25 旧代码：30fps 解码器帧率过高
            // pjmedia_format_init_video(&h264_param.dec_fmt,
            //                          PJMEDIA_FORMAT_I420,  // Raw YUV420 for decoder
            //                          1280, 720,            // 720P resolution
            //                          30, 1);               // Support up to 30fps
            // ❌ 2025-12-31 19:15 旧代码：降低到 15fps
            // pjmedia_format_init_video(&h264_param.dec_fmt,
            //                          PJMEDIA_FORMAT_I420,  // Raw YUV420 for decoder
            //                          1280, 720,            // 720P resolution
            //                          15, 1);               // 15 fps
            // ❌ 2025-12-31 19:50 旧代码：使用 25fps，但 1280x720 导致 RGA 缩放失败
            // pjmedia_format_init_video(&h264_param.dec_fmt,
            //                          PJMEDIA_FORMAT_I420,  // Raw YUV420 for decoder
            //                          1280, 720,            // 720P resolution
            //                          25, 1);               // 25 fps（与编码器匹配）
            // ❌ 2025-12-31 20:20 旧代码：降低到 640x360，匹配对方实际分辨率
            // ❌ 2026-01-11 01:45 [修复 100.29] 修改为 640x368 以满足 16 像素对齐要求
            // ❌ 2026-01-11 03:30 [修复 100.32] 使用摄像头硬件支持的 640x480 @ 30fps
            // ✅ 2026-01-11 04:20 [修复 100.34] 匹配对方分辨率 640x360
            // ✅ 2026-01-11 11:20 [修复 100.37] 改回 VGA 640x480
            pjmedia_format_init_video(&h264_param.dec_fmt,
                                     PJMEDIA_FORMAT_I420,  // Raw YUV420 for decoder
                                     640, 480,             // VGA resolution
                                     30, 1);               // ✅ 30 fps (与编码器匹配)

            qDebug() << "✅ Format initialized: enc_fmt.detail_type=" << h264_param.enc_fmt.detail_type
                     << ", dec_fmt.detail_type=" << h264_param.dec_fmt.detail_type;
        }

        qDebug() << "  Current H264 encoder settings:";
        qDebug() << "    TX size:" << h264_param.enc_fmt.det.vid.size.w << "x" << h264_param.enc_fmt.det.vid.size.h;
        qDebug() << "    TX fps:" << h264_param.enc_fmt.det.vid.fps.num << "/" << h264_param.enc_fmt.det.vid.fps.denum;

        // ❌ 2025-12-31 18:25 旧代码：25fps 导致摄像头资源冲突，V4L2 "Device or resource busy"
        // h264_param.enc_fmt.det.vid.fps.num = 25;
        // h264_param.enc_fmt.det.vid.fps.denum = 1;
        // ❌ 2025-12-31 19:15 旧代码：降低到 15fps，但测试发现 15fps 反而更糟
        // h264_param.enc_fmt.det.vid.fps.num = 15;
        // h264_param.enc_fmt.det.vid.fps.denum = 1;
        // ❌ 2025-12-31 19:50 旧代码：使用 25fps（V4L2 默认值），驱动稳定性最佳
        // ✅ 2026-01-11 03:30 [修复 100.32] 使用摄像头硬件支持的 30fps
        h264_param.enc_fmt.det.vid.fps.num = 30;  // ✅ 30 fps（摄像头原生帧率）
        h264_param.enc_fmt.det.vid.fps.denum = 1;

        // ❌ 2025-12-31 20:20 旧代码：1280x720 导致 RGA 缩放失败（DMA buffer handle 空指针）
        // h264_param.enc_fmt.det.vid.size.w = 1280;  // 720P width
        // h264_param.enc_fmt.det.vid.size.h = 720;   // 720P height
        // ❌ 2025-12-31 20:20 旧代码：降低到 640x360，匹配对方实际分辨率，避免 RGA 缩放错误
        // ❌ 2026-01-11 01:45 [修复 100.29] 修改为 640x368 以满足 16 像素对齐要求
        // ❌ 2026-01-11 03:30 [修复 100.32] 使用摄像头硬件支持的 640x480
        // ✅ 2026-01-11 04:20 [修复 100.34] 匹配对方分辨率 640x360
        // ✅ 2026-01-11 11:20 [修复 100.37] 改回 VGA 640x480
        h264_param.enc_fmt.det.vid.size.w = 640;   // VGA width
        h264_param.enc_fmt.det.vid.size.h = 480;   // VGA height (perfect 16-aligned)

        // ❌ 2025-12-31 18:25 旧代码：30fps 解码器帧率过高
        // h264_param.dec_fmt.det.vid.fps.num = 30;
        // h264_param.dec_fmt.det.vid.fps.denum = 1;
        // ❌ 2025-12-31 19:15 旧代码：降低到 15fps
        // h264_param.dec_fmt.det.vid.fps.num = 15;
        // h264_param.dec_fmt.det.vid.fps.denum = 1;
        // ❌ 2025-12-31 19:50 旧代码：使用 25fps，与编码器帧率匹配
        // ✅ 2026-01-11 03:30 [修复 100.32] 使用 30fps，与编码器帧率匹配
        h264_param.dec_fmt.det.vid.fps.num = 30;  // ✅ 30 fps（与编码器匹配）
        h264_param.dec_fmt.det.vid.fps.denum = 1;

        vid_status = pjsua_vid_codec_set_param(&h264_codec_id, &h264_param);
        if (vid_status == PJ_SUCCESS) {
            // ❌ 2025-12-31 18:25 旧代码：日志消息未更新，与实际帧率不符
            // qDebug() << "✅ H264 video codec configured: 1280x720 (720P) @ 25fps (TX), up to 30fps (RX)";
            // ❌ 2025-12-31 19:15 旧代码：更新日志但使用 15fps
            // qDebug() << "✅ H264 video codec configured: 1280x720 (720P) @ 15fps (TX), 15fps (RX) - optimized for camera resource sharing";
            // ❌ 2025-12-31 19:50 旧代码：更新日志使用 25fps 但 1280x720
            // qDebug() << "✅ H264 video codec configured: 1280x720 (720P) @ 25fps (TX), 25fps (RX) - using V4L2 default frame rate";
            // ❌ 2025-12-31 20:20 旧代码：更新日志使用 640x360 @ 25fps
            // ❌ 2026-01-11 01:45 [修复 100.29] 更新为 640x368（16像素对齐）
            // ❌ 2026-01-11 03:30 [修复 100.32] 更新为 640x480 @ 30fps（摄像头硬件支持）
            // ✅ 2026-01-11 04:20 [修复 100.34] 更新为 640x360 @ 30fps（匹配对方分辨率）
            // ✅ 2026-01-11 11:20 [修复 100.37] 改回 VGA 640x480（对方已切换到 VGA）
            qDebug() << "✅ H264 video codec configured: 640x480 (VGA) @ 30fps (TX/RX) - standard VGA resolution";
        } else {
            char errmsg[PJ_ERR_MSG_SIZE];
            pj_strerror(vid_status, errmsg, sizeof(errmsg));
            qWarning() << "⚠️ Failed to configure H264 codec:" << errmsg;
        }
    } else {
        char errmsg[PJ_ERR_MSG_SIZE];
        pj_strerror(vid_status, errmsg, sizeof(errmsg));
        qWarning() << "⚠️ Failed to get H264 codec parameters:" << errmsg;
    }

    // PJSIP 2.15.1: codecEnum2() returns vector<CodecInfo> (values) not pointers
    CodecInfoVector2 codecs = Endpoint::instance().codecEnum2();

    qDebug() << "📹 Enumerating AUDIO codecs:";
    for(int i=0; i<codecs.size(); ++i) {
        const CodecInfo &codecInfo = codecs.at(i);
        qDebug()<<"  AUDIO CODEC: " << QString::fromStdString(codecInfo.codecId)
                << QString::fromStdString(codecInfo.desc)
                << codecInfo.priority;
    }

    // Enumerate VIDEO codecs using PJSUA C API
    qDebug() << "📹 Enumerating VIDEO codecs using pjsua_vid_enum_codecs:";
    pjsua_codec_info vid_codecs[32];
    unsigned vid_codec_count = PJ_ARRAY_SIZE(vid_codecs);
    pj_status_t vid_enum_status = pjsua_vid_enum_codecs(vid_codecs, &vid_codec_count);

    if (vid_enum_status == PJ_SUCCESS) {
        qDebug() << "  ✅ Found" << vid_codec_count << "video codecs:";
        for (unsigned i = 0; i < vid_codec_count; ++i) {
            QString codecId = QString::fromLocal8Bit(vid_codecs[i].codec_id.ptr, vid_codecs[i].codec_id.slen);
            qDebug() << "    [" << i << "]" << codecId
                     << "priority:" << vid_codecs[i].priority;
        }
    } else {
        char errmsg[PJ_ERR_MSG_SIZE];
        pj_strerror(vid_enum_status, errmsg, sizeof(errmsg));
        qWarning() << "  ❌ Failed to enumerate video codecs:" << errmsg;
    }

    emit statusChanged(status());
    return status();
}

/**
 * @brief RisipEndpoint::stop
 *
 * Call this function to stop the SIP endpoint / library
 */
int RisipEndpoint::stop()
{
    if(m_data->pjsipEndpoint && m_data->pjsipEndpoint->libGetState() != PJSUA_STATE_NULL)
        m_data->pjsipEndpoint->libDestroy();

    emit statusChanged(status());

    return status();
}

void RisipEndpoint::setError(const Error &error)
{
    qDebug()<<"ERROR: " <<"code: "<<error.status <<" info: " << QString::fromStdString(error.info(true));

    if(m_data->error.status != error.status) {

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

// ✅ Static method to register UI callback for call state notifications
void RisipEndpoint::registerCallStateCallback(CallStateNotificationCallback callback)
{
    ui_call_state_callback = callback;
    qDebug() << "✅ RisipEndpoint: UI call state callback registered";
}

} //end of risip namespace
