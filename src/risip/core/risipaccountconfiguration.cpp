/***********************************************************************************
**    Copyright (C) 2016  Petref Saraci
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

#include "risipaccountconfiguration.h"
#include "risipaccount.h"

#include <QDebug>

namespace risip {

class RisipAccountConfiguration::Private
{
public:
    RisipAccount *risipAccount;
    AccountConfig accountConfig;
    AuthCredInfo accountCredentials;
    TransportConfig transportConfiguration;
    int networkProtocol;
    QString proxyAddress;
    int proxyPort;
    bool randomLocalPort;
};

RisipAccountConfiguration::RisipAccountConfiguration(QObject *parent)
    :QObject(parent)
    ,m_data(new Private)
{
    m_data->risipAccount = NULL;
    m_data->networkProtocol = UDP;
    m_data->randomLocalPort = true;

    setTransportId(-1);
    setLocalPort(0); //setting port to 0 means that any available random port will be used
//    setEncryptCalls(true);
}

RisipAccountConfiguration::~RisipAccountConfiguration()
{
    delete m_data;
    m_data = NULL;
}

RisipAccount *RisipAccountConfiguration::account() const
{
    return m_data->risipAccount;
}

void RisipAccountConfiguration::setAccount(RisipAccount *account)
{
    if(m_data->risipAccount != account) {
        m_data->risipAccount = account;

        if(m_data->risipAccount != NULL)
            m_data->risipAccount->setConfiguration(this);

        emit accountChanged(m_data->risipAccount);
    }
}

QString RisipAccountConfiguration::uri()
{
    if(m_data->accountConfig.idUri.empty()) {
        QString uri = QString("sip:") + userName() + QString("@") + serverAddress();
        setUri(uri);
        return uri;
    }

    return QString::fromStdString(m_data->accountConfig.idUri);
}

void RisipAccountConfiguration::setUri(const QString &accountUri)
{
    string accountUristr = accountUri.toStdString();
    if(m_data->accountConfig.idUri != accountUristr) {
        m_data->accountConfig.idUri = accountUristr;
        emit uriChanged(accountUri);
    }
}

QString RisipAccountConfiguration::userName()
{
    QString username;
    if(!m_data->accountCredentials.username.empty())
        username = QString::fromStdString(m_data->accountCredentials.username);

    return username;
}

void RisipAccountConfiguration::setUserName(const QString &name)
{
    if(userName() != name) {
        m_data->accountCredentials.username = name.toStdString();
        emit userNameChanged(name);
    }
}

QString RisipAccountConfiguration::password() const
{
    if(!m_data->accountCredentials.data.empty())
        return QString::fromStdString(m_data->accountCredentials.data);

    return QString();
}

void RisipAccountConfiguration::setPassword(const QString &pass)
{
    if(password() != pass) {
        m_data->accountCredentials.data = pass.toStdString();
        m_data->accountCredentials.dataType = 0; //0 is for plain password
        emit passwordChanged(pass);
    }
}

QString RisipAccountConfiguration::scheme() const
{
    if(!m_data->accountCredentials.scheme.empty())
        return QString::fromStdString(m_data->accountCredentials.scheme);

    return QString();
}

void RisipAccountConfiguration::setScheme(const QString &credScheme)
{
    if(scheme() != credScheme) {
        m_data->accountCredentials.scheme = credScheme.toStdString();
        emit schemeChanged(credScheme);
    }
}

QString RisipAccountConfiguration::serverAddress()
{
    //server address always is stored as a "sip:serveraddress" format in pjsip, so removing "sip:"
    //comes in handy for passing the just the server address around
    if(!m_data->accountConfig.regConfig.registrarUri.empty())
        return (QString::fromStdString(m_data->accountConfig.regConfig.registrarUri)).remove("sip:");

    return QString();
}

void RisipAccountConfiguration::setServerAddress(const QString &address)
{
    //always add the "sip:" prefix to properly store server address inside pjsip.
    if(serverAddress() != address) {
        m_data->accountConfig.regConfig.registrarUri = "sip:" + address.toStdString();
        emit serverAddressChanged(address);
    }
}

QString RisipAccountConfiguration::proxyServer() const
{
    return m_data->proxyAddress;
}

void RisipAccountConfiguration::setProxyServer(const QString &proxy)
{
    if(m_data->proxyAddress != proxy) {
        m_data->proxyAddress = proxy;
        emit proxyServerChanged(proxy);
    }
}

int RisipAccountConfiguration::proxyPort() const
{
    return m_data->proxyPort;
}

void RisipAccountConfiguration::setProxyPort(int port)
{
    if(m_data->proxyPort != port) {
        m_data->proxyPort = port;
        emit proxyPortChanged(m_data->proxyPort);
    }
}

int RisipAccountConfiguration::networkProtocol() const
{
    return m_data->networkProtocol;
}

void RisipAccountConfiguration::setNetworkProtocol(int protocol)
{
    if(m_data->networkProtocol != protocol) {
        m_data->networkProtocol = protocol;
        emit networkProtocolChanged(m_data->networkProtocol);
    }
}

int RisipAccountConfiguration::localPort() const
{
    return (int)m_data->transportConfiguration.port;
}

/**
 * @brief RisipAccountConfiguration::setLocalPort
 * @param port is local port that the engine will bind to for sending/accepting data
 *
 * Use this function to bind the sip client to a desired port and also make sure to disable
 * "randomLocalPort property. @see RisipAccountConfiguration::randomLocalPort
 *
 * Setting the port to 0 will simply enable the randomLocalPort property and the sip engine will
 * use any available port.
 */
void RisipAccountConfiguration::setLocalPort(int port)
{
    if(m_data->transportConfiguration.port != port) {
        m_data->transportConfiguration.port = port;
        emit localPortChanged(port);
    }
}

bool RisipAccountConfiguration::randomLocalPort() const
{
    return m_data->randomLocalPort;
}

void RisipAccountConfiguration::setRandomLocalPort(bool random)
{
    if(m_data->randomLocalPort != random) {
        m_data->randomLocalPort = random;
        emit randomLocalPortChanged(random);
    }
}

bool RisipAccountConfiguration::encryptCalls() const
{
    if(m_data->accountConfig.mediaConfig.srtpUse == PJMEDIA_SRTP_DISABLED)
        return false;
    else if(m_data->accountConfig.mediaConfig.srtpUse == PJMEDIA_SRTP_OPTIONAL )
        return true;

    return false;
}

void RisipAccountConfiguration::setEncryptCalls(bool encrypt)
{
    if(m_data->accountConfig.mediaConfig.srtpUse != encrypt) {
        if(encrypt)
            m_data->accountConfig.mediaConfig.srtpUse = PJMEDIA_SRTP_OPTIONAL;
        else
            m_data->accountConfig.mediaConfig.srtpUse = PJMEDIA_SRTP_DISABLED;

        emit encryptCallsChanged(encrypt);
    }
}

bool RisipAccountConfiguration::valid()
{
    if(serverAddress().isEmpty()
            || uri().isEmpty()
            || userName().isEmpty()
            || password().isEmpty()) {

        qDebug()<<"Invalid Configuration: " << serverAddress() <<uri() <<userName() << password();
        return false;
    }

    return true;
}

int RisipAccountConfiguration::transportId() const
{
    return m_data->accountConfig.sipConfig.transportId;
}

void RisipAccountConfiguration::setTransportId(int transId)
{
    if(transportId() != transId) {
        m_data->accountConfig.sipConfig.transportId = transId;
        emit transportIdChanged(transId);
    }
}

/**
 * @brief RisipAccountConfiguration::pjsipAccountConfig
 * @return AccountConfig
 *
 * An internal function that actually returns an AccountConfig object, that the C++ PJSIP API understands and we can
 * pass around in PJSIP library.
 *
 * Basically the RisipAccountConfiguration class has an internal AccountConfig object that populates it with the
 * respective account settings.
 */
AccountConfig& RisipAccountConfiguration::pjsipAccountConfig()
{
    qDebug() << "[CONFIG] 🔹 pjsipAccountConfig() called";

    // ✅ 关键修复：清空 authCreds，避免重复累积
    qDebug() << "[CONFIG] 🔸 Clearing authCreds...";
    m_data->accountConfig.sipConfig.authCreds.clear();
    qDebug() << "[CONFIG] ✅ authCreds cleared";

    //setting the final sip account URI in a proper SIP format
    qDebug() << "[CONFIG] 🔸 Setting URI...";
    if(uri().isEmpty())
        setUri(QString("sip:") + userName() + QString("@") + serverAddress());

    // 设置 URI 字段
    qDebug() << "[CONFIG] 🔸 Setting idUri and registrarUri...";
    qDebug() << "[CONFIG]    URI:" << uri();
    qDebug() << "[CONFIG]    Server:" << serverAddress();
    m_data->accountConfig.idUri = uri().toStdString();
    m_data->accountConfig.regConfig.registrarUri = "sip:" + serverAddress().toStdString();
    qDebug() << "[CONFIG] ✅ URI fields set";

    //add the proxy and relevant network type
    if(!m_data->proxyAddress.isEmpty() || !m_data->proxyAddress.isNull()) {
        QString proxyUri = QString("sip:") + proxyServer() + QString(";transport=");
        switch (networkProtocol()) {
        case UDP:
            proxyUri = proxyUri + QString("udp");
            break;
        case TCP:
            proxyUri = proxyUri + QString("tcp");
            break;
        case TLS:
            proxyUri = proxyUri + QString("tls");
            break;
        default:
            break;
        }

        m_data->accountConfig.sipConfig.proxies = { proxyUri.toStdString() }; //FIXME add proxy port
    }

    //adding the account credentials (username + password)
    m_data->accountConfig.sipConfig.authCreds.push_back(m_data->accountCredentials);

    m_data->accountConfig.callConfig.timerMinSESec = 1200;
    m_data->accountConfig.callConfig.timerSessExpiresSec = 22000;

    // ✅ CRITICAL FIX: Disable account-level Keep-alive timer to prevent PJSIP race condition bug
    // Official PJSIP Bug: Ticket #2079 - Race condition in keep_alive_timer_cb()
    // Root cause: Timer callback accesses freed timer or NULL ka_transport after registration
    // Solution: Set udpKaIntervalSec to 0 (official PJSIP method to disable keep-alive)
    // Reference: https://www.pjsip.org/pjsip/docs/html/structpj_1_1AccountNatConfig.html
    qDebug() << "[CONFIG] 🔸 Disabling account Keep-alive timer (PJSIP bug #2079 workaround)...";
    qDebug() << "[CONFIG]    Bug: Race condition in keep_alive_timer_cb() causes crash after 200 OK";
    qDebug() << "[CONFIG]    Fix: udpKaIntervalSec = 0 (prevents timer from starting)";

    m_data->accountConfig.natConfig.udpKaIntervalSec = 0;          // ⭐ 禁用账户级 Keep-alive（防止race condition崩溃）
    m_data->accountConfig.natConfig.iceEnabled = false;            // 禁用 ICE
    m_data->accountConfig.natConfig.turnEnabled = false;           // 禁用 TURN
    m_data->accountConfig.natConfig.sipStunUse = PJSUA_STUN_USE_DISABLED;    // 禁用 STUN for SIP
    m_data->accountConfig.natConfig.mediaStunUse = PJSUA_STUN_USE_DISABLED;  // 禁用 STUN for media

    qDebug() << "[CONFIG] ✅ Account Keep-alive disabled (udpKaIntervalSec=0, ICE=false, TURN=false, STUN=disabled)";
    qDebug() << "[CONFIG]    Expected: NO 'Keep-alive timer started' message after registration";


//    m_data->accountConfig.natConfig.iceEnabled = true;

    // ✅ 视频配置：使用默认设备，避免指定不存在的设备导致崩溃
    m_data->accountConfig.videoConfig.defaultCaptureDevice = PJMEDIA_VID_DEFAULT_CAPTURE_DEV;  // 使用 PJSIP 自动选择的默认摄像头
    m_data->accountConfig.videoConfig.defaultRenderDevice = PJMEDIA_VID_DEFAULT_RENDER_DEV;    // 使用默认渲染设备

    // 视频窗口配置：禁用 PJSIP 自动弹出的视频窗口，我们使用 QML 界面
    m_data->accountConfig.videoConfig.autoShowIncoming = false;       // 不自动显示来电视频窗口
    m_data->accountConfig.videoConfig.autoTransmitOutgoing = false;   // ✅ 关键修复：账户创建时不自动传输视频，避免设备初始化问题

    // 视频窗口标志（虽然我们不使用 PJSIP 的窗口，但仍需设置）
    m_data->accountConfig.videoConfig.windowFlags = PJMEDIA_VID_DEV_WND_BORDER | PJMEDIA_VID_DEV_WND_RESIZABLE;

    // ✅ 2025-12-31 关键修复：添加 PortSIP 需要的额外 RTCP-FB 参数
    // 原因：PortSIP UC Client 要求完整的 RTCP-FB 参数，否则返回 a=inactive 拒绝视频流
    // Wireshark 抓包对比：
    //   成功 (1005→1006): rtcp-fb:125 goog-remb, transport-cc, ccm fir, nack, nack pli
    //   失败 (1002→1006): rtcp-fb:* nack pli (只有这一个)
    // 注意：PJSIP 已默认添加 nack pli（因为 PJMEDIA_STREAM_ENABLE_RTCP_FB=1）
    //       我们只需要添加 PJSIP 默认没有的 4 个参数
    qDebug() << "[CONFIG] 🔸 Configuring additional RTCP-FB capabilities for PortSIP compatibility...";

    // 启用 RTCP-FB（使用 RTP/AVP 而不是 RTP/AVPF 以兼容旧设备）
    m_data->accountConfig.mediaConfig.rtcpFbConfig.dontUseAvpf = PJ_TRUE;

    // 配置额外的 RTCP-FB 能力（PJSIP 默认没有的）
    pj::RtcpFbCap cap;

    // 注意：删除了 "nack pli"，因为 PJSIP 已经自动添加（避免重复）
    // 2025-12-31 16:00: 发现 SDP 中 nack pli 重复，导致 PortSIP 拒绝

    // 1. NACK - Generic NACK（通用否定应答）
    cap.codecId = "*";
    cap.type = PJMEDIA_RTCP_FB_NACK;
    cap.param = "";
    m_data->accountConfig.mediaConfig.rtcpFbConfig.caps.push_back(cap);

    // 2. CCM FIR - Codec Control Message, Full Intra Request（完整内帧请求）
    cap.codecId = "*";
    cap.type = PJMEDIA_RTCP_FB_OTHER;
    cap.typeName = "ccm";
    cap.param = "fir";
    m_data->accountConfig.mediaConfig.rtcpFbConfig.caps.push_back(cap);

    // ❌ 2025-12-31 删除：GOOG-REMB 和 TRANSPORT-CC（为了减小 SDP 大小到 MTU 1500 以下）
    // 原因：INVITE 消息大小 1566 字节超过 MTU 1500，导致 IP 分片，miniSIP 服务器无法处理
    // 删除这两个非必需的 Google 扩展参数可减少约 110 字节，使 INVITE < 1500 字节
    // goog-remb: Google 带宽估计扩展（非 RFC 标准，可选）
    // transport-cc: 传输层拥塞控制扩展（非 RFC 标准，可选）
    // 保留：nack, ccm fir（RFC 标准，必需）
    /*
    // 3. GOOG-REMB - Google Receiver Estimated Maximum Bitrate（带宽估计）
    cap.codecId = "*";
    cap.type = PJMEDIA_RTCP_FB_OTHER;
    cap.typeName = "goog-remb";
    cap.param = "";
    m_data->accountConfig.mediaConfig.rtcpFbConfig.caps.push_back(cap);

    // 4. TRANSPORT-CC - Transport-wide Congestion Control（传输层拥塞控制）
    cap.codecId = "*";
    cap.type = PJMEDIA_RTCP_FB_OTHER;
    cap.typeName = "transport-cc";
    cap.param = "";
    m_data->accountConfig.mediaConfig.rtcpFbConfig.caps.push_back(cap);
    */

    qDebug() << "[CONFIG] ✅ RTCP-FB configured with" << m_data->accountConfig.mediaConfig.rtcpFbConfig.caps.size() << "essential capabilities (optimized for MTU):";
    qDebug() << "[CONFIG]    (nack pli - already added by PJSIP)";
    qDebug() << "[CONFIG]    1. nack (Generic NACK) - RFC standard";
    qDebug() << "[CONFIG]    2. ccm fir (Full Intra Request) - RFC standard";
    qDebug() << "[CONFIG]    ❌ Removed: goog-remb (Google extension, ~55 bytes saved)";
    qDebug() << "[CONFIG]    ❌ Removed: transport-cc (Google extension, ~55 bytes saved)";
    qDebug() << "[CONFIG]    Expected INVITE size reduction: ~110 bytes (1566 → ~1456 < MTU 1500)";

    // ✅ 2025-12-31 关键修复：禁用 Lock Codec（避免通话后自动 re-INVITE）
    // 问题：PJSIP 在通话建立后会自动发送 re-INVITE/UPDATE 锁定单一编解码器
    // 原因：对方响应多个编解码器时，PJSIP 会尝试优化到单一编解码器
    // 结果：miniSIP/PortSIP 收到 re-INVITE 后误判，将视频设为 a=inactive
    // 解决：禁用 Lock Codec 功能，保持初始协商的多编解码器状态
    // 参考：pjsip/include/pjsua2/account.hpp:1098 (lockCodecEnabled in AccountMediaConfig)
    qDebug() << "[CONFIG] 🔸 Disabling Lock Codec to prevent post-call re-INVITE...";
    m_data->accountConfig.mediaConfig.lockCodecEnabled = false;
    qDebug() << "[CONFIG] ✅ Lock Codec disabled (lockCodecEnabled=false)";
    qDebug() << "[CONFIG]    Expected: NO automatic re-INVITE after call setup";
    qDebug() << "[CONFIG]    Expected: Video remains a=sendrecv (not a=inactive)";

    return m_data->accountConfig;
}

void RisipAccountConfiguration::setPjsipAccountConfig(AccountConfig pjsipConfig)
{
    m_data->accountConfig = pjsipConfig;
}

TransportConfig& RisipAccountConfiguration::pjsipTransportConfig()
{
    if(!m_data->randomLocalPort && localPort() != 0)
        m_data->transportConfiguration.port = localPort();
    else if(m_data->randomLocalPort)
        m_data->transportConfiguration.port = 0;

//    m_data->accountConfig.natConfig.sipStunUse
    return m_data->transportConfiguration;
}

void RisipAccountConfiguration::setPjsipTransportConfig(TransportConfig pjsipConfig)
{
    m_data->transportConfiguration = pjsipConfig;
}

} //end of risip namespace
