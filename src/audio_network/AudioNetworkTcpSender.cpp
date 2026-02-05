// ✅ 2026-01-22 18:00 [TCP音频传输] TCP 模式音频发送器实现
// 文件: src/audio_network/AudioNetworkTcpSender.cpp
// 功能: TCP 模式音频传输（UDP 发现 + TCP 连接 + WebSocket + 心跳）
// 作者: Claude AI
// 日期: 2026-01-22

#include "AudioNetworkTcpSender.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkInterface>
#include <QFile>
#include <QFileInfo>  // ✅ 2026-01-22 修复编译错误: 添加 QFileInfo 头文件
#include <QElapsedTimer>

// ========== FFmpeg 和 Opus 头文件（复用 AudioNetworkSender 的编码逻辑）==========
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswresample/swresample.h>
#include <opus/opus.h>
}

// ========== 构造函数 / 析构函数 ==========

AudioNetworkTcpSender::AudioNetworkTcpSender(QObject *parent)
    : QObject(parent)
    , m_udpSocket(new QUdpSocket(this))
    , m_udpPort(8600)
    , m_wsClient(new WebSocketClient(this))
    , m_serverPort(0)
    , m_currentServerIndex(0)
    // ✅ 2026-01-22 17:15 [FIX 100.291] 初始化连接信息缓存
    , m_currentConnectedIp("")
    , m_currentConnectedPort(0)
    , m_pingTimer(new QTimer(this))
    , m_pongTimer(new QTimer(this))
    , m_currentFrameIndex(0)
    , m_totalFrames(0)
    , m_frameTimer(new QTimer(this))
    , m_sendStartTime(0)
    , m_isPlaying(false)
    // ❌ 2026-01-22 17:30 [FIX 100.291] 旧代码：存储在容器内临时目录（容器重启后丢失）
    // , m_settings(new QSettings("BeltControlSystem", "AudioNetwork", this))
    // 存储路径：/root/.config/BeltControlSystem/AudioNetwork.conf（容器重启后丢失）

    // ✅ 2026-01-22 17:30 [FIX 100.291] 新代码：存储在Docker挂载的持久化目录
    , m_settings(new QSettings("/app/appdata/audio_network_config.ini", QSettings::IniFormat, this))
    // 存储路径：/app/appdata/audio_network_config.ini
    // Docker挂载：宿主机 ~/belt-control-data/appdata/ → 容器 /app/appdata/
    // 容器重启后配置不丢失

    // ✅ 2026-01-22 20:40 [FIX 100.295] 独立发送线程初始化
    , m_senderThread(nullptr)
    , m_senderWorker(nullptr)
{
    // ❌ 2026-01-22 20:40 [FIX 100.295] 旧代码：使用主线程定时器发送（受UI/数据库干扰）
    // m_frameTimer->setTimerType(Qt::PreciseTimer);
    // qDebug() << "✅ AudioNetworkTcpSender: 使用 Qt::PreciseTimer（精确定时模式）";

    // ✅ 2026-01-22 20:40 [FIX 100.295] 新代码：创建独立发送线程（不受主线程干扰）
    // 原因：
    //   - 用户反馈："网络环境很好的状态下已经有卡顿，需要设计一个更加恶劣的环境下能正常发送的代码"
    //   - 根本原因：主线程事件循环被UI/数据库/键盘事件干扰
    //   - 解决方案：独立线程专门处理音频发送，拥有独立事件循环
    // 架构：
    //   - 主线程：音频编码（FFmpeg + Opus）
    //   - 独立线程：音频发送（WebSocket，20ms 精确定时）
    // 优势：
    //   - 完全隔离主线程干扰
    //   - 专用事件循环，无UI/数据库竞争
    //   - 适应恶劣网络环境（丢包、高延迟）
    m_senderThread = new QThread(this);
    m_senderWorker = new AudioSenderWorker(m_wsClient);

    // ✅ 2026-01-22 21:00 [FIX 100.295.1] 仅移动 worker 到独立线程
    // ❌ 不移动 WebSocketClient（需要在主线程处理 TCP 连接、心跳）
    // 原因：
    //   - UDP 服务发现在主线程
    //   - connectToServer() 在主线程调用
    //   - 心跳定时器在主线程
    //   - 跨线程访问 QTcpSocket 会导致 "connectToHost() called when already connecting"
    // 正确架构：
    //   - 主线程：WebSocketClient（连接管理）、编码、缓存
    //   - 独立线程：AudioSenderWorker（仅负责定时发送）
    //   - worker 通过 Qt 信号槽调用 WebSocketClient::sendBinaryFrame()（线程安全）
    m_senderWorker->moveToThread(m_senderThread);
    // m_wsClient->moveToThread(m_senderThread);  // ❌ 删除，保持在主线程

    // 连接 worker 信号到主线程（跨线程通信）
    // ❌ 2026-01-22 20:50 注意：不连接 sendingStarted，因为参数不兼容
    //    sendingStarted(int) vs playbackStarted(QString)
    //    playbackStarted 信号在 playAudioToNetwork() 中发送（主线程知道文件名）

    connect(m_senderWorker, &AudioSenderWorker::sendingProgress,
            this, &AudioNetworkTcpSender::playbackProgress);
    connect(m_senderWorker, &AudioSenderWorker::sendingFinished,
            this, [this]() {
        m_isPlaying = false;
        emit playbackFinished();
    });
    connect(m_senderWorker, &AudioSenderWorker::sendingError,
            this, &AudioNetworkTcpSender::playbackError);

    // 启动独立线程
    m_senderThread->start();

    qDebug() << "✅ AudioNetworkTcpSender: 独立发送线程已创建";
    qDebug() << "   主线程: WebSocket 连接管理 + 音频编码（FFmpeg + Opus）";
    qDebug() << "   独立线程: 音频发送（定时器，20ms 精确定时）";

    // ✅ 2026-01-22 18:00 [初始化] 连接信号槽

    // UDP 服务发现
    connect(m_udpSocket, &QUdpSocket::readyRead, this, &AudioNetworkTcpSender::onUdpDatagramReady);

    // WebSocket 连接
    connect(m_wsClient, &WebSocketClient::handshakeCompleted, this, &AudioNetworkTcpSender::onWebSocketReady);
    connect(m_wsClient, &WebSocketClient::textFrameReceived, this, &AudioNetworkTcpSender::onServerConfigReceived);
    connect(m_wsClient, &WebSocketClient::pongReceived, this, &AudioNetworkTcpSender::onPongReceived);
    connect(m_wsClient, &WebSocketClient::connected, this, &AudioNetworkTcpSender::tcpConnected);
    connect(m_wsClient, &WebSocketClient::disconnected, this, &AudioNetworkTcpSender::tcpDisconnected);
    connect(m_wsClient, &WebSocketClient::error, this, &AudioNetworkTcpSender::tcpError);

    // ✅ 2026-01-22 17:15 [FIX 100.291] 断开连接时清空缓存（避免下次误判）
    connect(m_wsClient, &WebSocketClient::disconnected, this, [this]() {
        // 清空当前连接信息缓存
        m_currentConnectedIp.clear();
        m_currentConnectedPort = 0;
        qDebug() << "🔌 TCP 连接已断开，清空连接信息缓存";
    });

    // 心跳定时器
    m_pingTimer->setInterval(5000);  // 5 秒
    connect(m_pingTimer, &QTimer::timeout, this, &AudioNetworkTcpSender::sendPing);

    m_pongTimer->setSingleShot(true);
    m_pongTimer->setInterval(2000);  // 2 秒超时
    connect(m_pongTimer, &QTimer::timeout, this, &AudioNetworkTcpSender::onPongTimeout);

    // 加载配置
    loadConfig();

    qDebug() << "✅ AudioNetworkTcpSender 初始化完成";
}

AudioNetworkTcpSender::~AudioNetworkTcpSender()
{
    // ✅ 2026-01-22 20:40 [FIX 100.295] 清理独立发送线程
    if (m_senderThread) {
        qDebug() << "📡 停止独立发送线程...";

        // 停止发送任务
        if (m_senderWorker) {
            QMetaObject::invokeMethod(m_senderWorker, "stopSending", Qt::QueuedConnection);
        }

        // 停止线程
        m_senderThread->quit();
        if (!m_senderThread->wait(3000)) {
            qWarning() << "⚠️ 独立发送线程未在 3 秒内退出，强制终止";
            m_senderThread->terminate();
            m_senderThread->wait();
        }

        // 删除 worker（必须在线程停止后）
        if (m_senderWorker) {
            m_senderWorker->deleteLater();
            m_senderWorker = nullptr;
        }

        qDebug() << "✅ 独立发送线程已停止";
    }

    // ✅ 2026-01-22 18:00 [资源清理] 停止所有服务
    stopAll();
    qDebug() << "✅ AudioNetworkTcpSender 析构完成";
}

// ========== 配置接口 ==========

void AudioNetworkTcpSender::setUdpDiscoveryPort(quint16 port)
{
    m_udpPort = port;
    qDebug() << "📡 设置 UDP 发现端口:" << port;
}

void AudioNetworkTcpSender::setDeviceInfo(const DeviceInfo& info)
{
    m_deviceInfo = info;
    qDebug() << "📋 设置设备信息:";
    qDebug() << "   - 名称:" << info.name;
    qDebug() << "   - 型号:" << info.plain;
    qDebug() << "   - UUID:" << info.uuid;
}

AudioNetworkTcpSender::DeviceInfo AudioNetworkTcpSender::getDeviceInfo() const
{
    return m_deviceInfo;
}

// ========== 启动 / 停止 ==========

void AudioNetworkTcpSender::startDiscovery()
{
    // ✅ 2026-01-22 18:00 [UDP发现] 绑定 UDP 端口，等待上位机广播
    if (!m_udpSocket->bind(QHostAddress::AnyIPv4, m_udpPort)) {
        QString error = QString("UDP 绑定失败（端口 %1）: %2").arg(m_udpPort).arg(m_udpSocket->errorString());
        qWarning() << "❌" << error;
        emit discoveryFailed(error);
        return;
    }

    qDebug() << "✅ UDP 服务发现已启动（端口" << m_udpPort << "）";
    qDebug() << "   等待上位机广播配置 JSON...";
}

void AudioNetworkTcpSender::stopAll()
{
    // ✅ 2026-01-22 18:00 [停止服务] 停止所有服务
    qDebug() << "📡 停止所有服务";

    // 停止 UDP 监听
    if (m_udpSocket->state() == QUdpSocket::BoundState) {
        m_udpSocket->close();
    }

    // 断开 TCP 连接
    m_wsClient->disconnectFromServer();

    // 停止心跳
    stopHeartbeat();

    // 停止播放
    stopPlayback();
}

// ========== 播放接口 ==========

void AudioNetworkTcpSender::playAudioToNetwork(const QString& filePath)
{
    // ✅ 2026-01-22 18:00 [播放音频] 播放音频到网络
    if (m_isPlaying) {
        qWarning() << "⚠️ 正在播放中，请先停止";
        return;
    }

    if (!m_wsClient->isConnected()) {
        QString error = "WebSocket 未连接，无法播放音频";
        qWarning() << "❌" << error;
        emit playbackError(error);
        return;
    }

    // 检查文件是否存在
    if (!QFile::exists(filePath)) {
        QString error = QString("音频文件不存在: %1").arg(filePath);
        qWarning() << "❌" << error;
        emit playbackError(error);
        return;
    }

    qDebug() << "🎵 开始播放音频到网络:" << filePath;

    // ✅ 2026-01-22 19:00 [FIX 100.292] 检查 Opus 帧缓存（避免重复编码）
    if (m_opusCache.contains(filePath)) {
        // 缓存命中
        m_currentFrames = m_opusCache[filePath];
        qDebug() << "   ✅ 缓存命中，跳过编码";
        qDebug() << "   总帧数:" << m_currentFrames.size() << "帧";
        qDebug() << "   音频时长:" << (m_currentFrames.size() * 20) << "ms";
    } else {
        // 缓存未命中，需要编码
        qDebug() << "   ⏳ 缓存未命中，开始编码...";
        m_currentFrames = encodeAudioFile(filePath);

        if (m_currentFrames.isEmpty()) {
            QString error = "音频编码失败";
            qWarning() << "❌" << error;
            emit playbackError(error);
            return;
        }

        // 保存到缓存
        m_opusCache.insert(filePath, m_currentFrames);
        qDebug() << "   ✅ 已添加到缓存（当前缓存文件数:" << m_opusCache.size() << "）";
    }

    // ❌ 2026-01-22 20:40 [FIX 100.295] 旧代码：主线程发送（受UI/数据库干扰）
    // sendOpusFrames(m_currentFrames);

    // ✅ 2026-01-22 20:40 [FIX 100.295] 新代码：独立线程发送（不受主线程干扰）
    // 设置播放状态（防止重复播放）
    m_isPlaying = true;

    // 跨线程调用 worker 的 startSending()（Qt::QueuedConnection 自动处理线程安全）
    QMetaObject::invokeMethod(m_senderWorker, "startSending",
                              Qt::QueuedConnection,
                              Q_ARG(QList<QByteArray>, m_currentFrames));

    qDebug() << "   📡 已将 Opus 帧发送到独立线程处理";

    // ✅ 2026-01-22 20:50 [FIX 100.295] 在主线程发送 playbackStarted 信号
    // 原因：主线程知道文件名，worker 线程不知道
    QFileInfo fileInfo(filePath);
    emit playbackStarted(fileInfo.fileName());
}

void AudioNetworkTcpSender::stopPlayback()
{
    // ✅ 2026-01-22 20:40 [FIX 100.295] 停止独立线程的音频播放
    if (!m_isPlaying) {
        return;
    }

    qDebug() << "🛑 停止音频播放";
    m_isPlaying = false;

    // 跨线程调用 worker 的 stopSending()
    QMetaObject::invokeMethod(m_senderWorker, "stopSending", Qt::QueuedConnection);

    // ❌ 2026-01-22 20:40 旧代码：停止主线程定时器（已移除）
    // m_frameTimer->stop();
    // m_currentFrames.clear();
    // m_currentFrameIndex = 0;
    // m_totalFrames = 0;
    // m_sendStartTime = 0;
}

bool AudioNetworkTcpSender::isPlaying() const
{
    return m_isPlaying;
}

// ✅ 2026-01-22 修复编译错误: 添加 isConnected() 方法实现
bool AudioNetworkTcpSender::isConnected() const
{
    return m_wsClient->isConnected();
}

// ========== UDP 服务发现 ==========

void AudioNetworkTcpSender::onUdpDatagramReady()
{
    // ✅ 2026-01-22 18:00 [UDP接收] 接收 UDP 数据报，解析 JSON
    while (m_udpSocket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(int(m_udpSocket->pendingDatagramSize()));

        QHostAddress sender;
        quint16 senderPort;

        m_udpSocket->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);

        qDebug() << "📥 接收 UDP 数据报（来自" << sender.toString() << ":" << senderPort << "）";
        qDebug() << "   内容:" << QString::fromUtf8(datagram);

        // 解析 JSON
        parseDiscoveryJson(datagram);
    }
}

void AudioNetworkTcpSender::parseDiscoveryJson(const QByteArray& data)
{
    // ✅ 2026-01-22 18:00 [JSON解析] 解析 UDP 发现 JSON
    // JSON 格式：{"voiceport": 7800, "voicev4": [-1062731588, -1062731589]}

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        QString error = QString("JSON 解析失败: %1").arg(parseError.errorString());
        qWarning() << "❌" << error;
        emit discoveryFailed(error);
        return;
    }

    QJsonObject json = doc.object();

    // 解析端口
    if (!json.contains("voiceport")) {
        QString error = "JSON 中缺少 'voiceport' 字段";
        qWarning() << "❌" << error;
        emit discoveryFailed(error);
        return;
    }
    m_serverPort = static_cast<quint16>(json["voiceport"].toInt());

    // 解析 IP 地址列表
    if (!json.contains("voicev4")) {
        QString error = "JSON 中缺少 'voicev4' 字段";
        qWarning() << "❌" << error;
        emit discoveryFailed(error);
        return;
    }

    QJsonArray ipArray = json["voicev4"].toArray();
    m_serverIpList.clear();
    for (int i = 0; i < ipArray.size(); i++) {
        qint32 ipValue = ipArray[i].toInt();
        QString ip = convertIpAddress(ipValue);
        m_serverIpList.append(ip);
    }

    if (m_serverIpList.isEmpty()) {
        QString error = "未解析到任何服务器 IP 地址";
        qWarning() << "❌" << error;
        emit discoveryFailed(error);
        return;
    }

    qDebug() << "✅ UDP 服务发现成功:";
    qDebug() << "   - 端口:" << m_serverPort;
    qDebug() << "   - IP 列表:" << m_serverIpList;

    emit discoverySucceeded(m_serverIpList[0], m_serverPort);

    // ✅ 2026-01-22 17:15 [FIX 100.291] 修复频繁重连问题
    // 原因：每次收到 UDP 广播都无条件重连，导致每 30 秒重连一次
    // 影响：音频帧丢失（日志 1777 行：WebSocket 握手未完成，无法发送 BINARY 帧）
    // 修复：检查是否已连接到同一服务器，如果是则忽略 UDP 广播
    QString targetIp = m_serverIpList[0];
    quint16 targetPort = m_serverPort;

    // 检查是否已经连接到同一服务器
    if (m_wsClient->isConnected()) {
        // 获取当前连接的服务器信息（从成员变量缓存）
        if (m_currentConnectedIp == targetIp && m_currentConnectedPort == targetPort) {
            qDebug() << "✅ 已连接到相同服务器，忽略 UDP 广播";
            qDebug() << "   服务器:" << targetIp << ":" << targetPort;
            return;  // ← 关键修复：避免不必要的重连
        } else {
            qDebug() << "📡 检测到服务器变更";
            qDebug() << "   旧服务器:" << m_currentConnectedIp << ":" << m_currentConnectedPort;
            qDebug() << "   新服务器:" << targetIp << ":" << targetPort;
            qDebug() << "   断开旧连接，连接新服务器...";
        }
    }

    // 尝试连接第一个 IP
    m_currentServerIndex = 0;
    connectToServer(targetIp, targetPort);
}

QString AudioNetworkTcpSender::convertIpAddress(qint32 ipValue)
{
    // ✅ 2026-01-22 18:00 [IP转换] 32位有符号整数 → 点分十进制字符串
    // 例如：-1062731588 (有符号) = 0xC0A80ABC (无符号) = 192.168.10.188

    quint32 ipUnsigned = static_cast<quint32>(ipValue);
    QString ip = QString("%1.%2.%3.%4")
        .arg((ipUnsigned >> 24) & 0xFF)
        .arg((ipUnsigned >> 16) & 0xFF)
        .arg((ipUnsigned >> 8) & 0xFF)
        .arg(ipUnsigned & 0xFF);

    return ip;
}

// ========== TCP 连接 ==========

void AudioNetworkTcpSender::connectToServer(const QString& ip, quint16 port)
{
    // ✅ 2026-01-22 18:00 [TCP连接] 连接到 TCP 服务器
    qDebug() << "📡 连接到 TCP 服务器:" << ip << ":" << port;

    // ✅ 2026-01-22 17:15 [FIX 100.291] 缓存目标服务器信息（连接成功后会更新）
    // 注意：连接可能失败，所以在 onWebSocketReady() 中才真正更新缓存
    m_currentConnectedIp = ip;
    m_currentConnectedPort = port;

    m_wsClient->connectToServer(ip, port);
}

void AudioNetworkTcpSender::onWebSocketReady()
{
    // ✅ 2026-01-22 18:00 [握手完成] WebSocket 握手完成，发送设备信息
    qDebug() << "✅ WebSocket 握手完成";
    emit webSocketReady();

    // 发送设备信息 JSON
    sendDeviceInfo();

    // 启动心跳机制
    startHeartbeat();
}

void AudioNetworkTcpSender::sendDeviceInfo()
{
    // ✅ 2026-01-22 18:00 [发送设备信息] 构建并发送设备信息 JSON
    // JSON 格式参考示例代码 VoiceInternet.c 的 SendOneInfo() 函数

    QJsonObject json;
    json["cmd"] = 1;
    json["state"] = 1;
    json["id"] = m_deviceInfo.id;
    json["uuid"] = m_deviceInfo.uuid;
    json["type"] = 2;  // 设备类型（固定值）
    json["name"] = m_deviceInfo.name;
    json["plain"] = m_deviceInfo.plain;

    // IP 地址（转换为 32 位有符号整数）
    QStringList ipParts = m_deviceInfo.ip.split(".");
    if (ipParts.size() == 4) {
        qint32 ipValue = (ipParts[0].toInt() << 24) |
                         (ipParts[1].toInt() << 16) |
                         (ipParts[2].toInt() << 8) |
                         ipParts[3].toInt();
        json["ip"] = ipValue;
    }

    // MAC 地址（分为高 3 字节和低 3 字节）
    QStringList macParts = m_deviceInfo.mac.split(":");
    if (macParts.size() == 6) {
        qint32 mach = (macParts[5].toInt(nullptr, 16) << 16) |
                      (macParts[4].toInt(nullptr, 16) << 8) |
                      macParts[3].toInt(nullptr, 16);
        qint32 macl = (macParts[2].toInt(nullptr, 16) << 16) |
                      (macParts[1].toInt(nullptr, 16) << 8) |
                      macParts[0].toInt(nullptr, 16);
        json["mach"] = mach;
        json["macl"] = macl;
    }

    // 子网掩码
    QStringList maskParts = m_deviceInfo.subnetMask.split(".");
    if (maskParts.size() == 4) {
        qint32 maskValue = (maskParts[0].toInt() << 24) |
                           (maskParts[1].toInt() << 16) |
                           (maskParts[2].toInt() << 8) |
                           maskParts[3].toInt();
        json["mask"] = maskValue;
    }

    // 网关
    QStringList gateParts = m_deviceInfo.gatewayIp.split(".");
    if (gateParts.size() == 4) {
        qint32 gateValue = (gateParts[0].toInt() << 24) |
                           (gateParts[1].toInt() << 16) |
                           (gateParts[2].toInt() << 8) |
                           gateParts[3].toInt();
        json["gate"] = gateValue;
    }

    // 硬件和软件版本
    json["hard"] = m_deviceInfo.hardwareVersion;
    json["soft"] = m_deviceInfo.softwareVersion;

    // 转换为 JSON 字符串
    QJsonDocument doc(json);
    QString jsonString = QString::fromUtf8(doc.toJson(QJsonDocument::Compact));

    qDebug() << "📤 发送设备信息 JSON:";
    qDebug() << jsonString;

    m_wsClient->sendTextFrame(jsonString);
}

void AudioNetworkTcpSender::onServerConfigReceived(const QString& text)
{
    // ✅ 2026-01-22 18:00 [接收配置] 接收服务器配置 JSON
    qDebug() << "📥 接收服务器配置 JSON:" << text;
    handleServerConfig(text);
}

void AudioNetworkTcpSender::handleServerConfig(const QString& json)
{
    // ✅ 2026-01-22 18:00 [处理配置] 处理服务器配置 JSON
    // 参考示例代码 VoiceInternet.c 的 Netsysconfig_TCPApp() 函数

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8(), &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        qWarning() << "❌ JSON 解析失败:" << parseError.errorString();
        return;
    }

    QJsonObject jsonObj = doc.object();
    if (!jsonObj.contains("cmd")) {
        qWarning() << "❌ JSON 中缺少 'cmd' 字段";
        return;
    }

    int cmd = jsonObj["cmd"].toInt();

    if (cmd == 1) {
        // ========== cmd=1: 更新 ID 和 UUID ==========
        bool needSave = false;

        if (jsonObj.contains("id")) {
            int newId = jsonObj["id"].toInt();
            if (newId != m_deviceInfo.id) {
                qDebug() << "📋 更新设备 ID:" << m_deviceInfo.id << "→" << newId;
                m_deviceInfo.id = newId;
                needSave = true;
            }
        }

        if (jsonObj.contains("uuid")) {
            QString newUuid = jsonObj["uuid"].toString();
            if (newUuid != m_deviceInfo.uuid) {
                qDebug() << "📋 更新设备 UUID:" << m_deviceInfo.uuid << "→" << newUuid;
                m_deviceInfo.uuid = newUuid;
                needSave = true;
            }
        }

        if (needSave) {
            saveConfig();
        }

    } else if (cmd == 2) {
        // ========== cmd=2: 更新网络配置 ==========
        bool needSave = false;

        // IP 地址
        if (jsonObj.contains("ip")) {
            qint32 ipValue = jsonObj["ip"].toInt();
            QString newIp = convertIpAddress(ipValue);
            if (newIp != m_deviceInfo.ip) {
                qDebug() << "📋 更新本机 IP:" << m_deviceInfo.ip << "→" << newIp;
                m_deviceInfo.ip = newIp;
                needSave = true;
            }
        }

        // 网关
        if (jsonObj.contains("gate")) {
            qint32 gateValue = jsonObj["gate"].toInt();
            QString newGate = convertIpAddress(gateValue);
            if (newGate != m_deviceInfo.gatewayIp) {
                qDebug() << "📋 更新网关 IP:" << m_deviceInfo.gatewayIp << "→" << newGate;
                m_deviceInfo.gatewayIp = newGate;
                needSave = true;
            }
        }

        // 子网掩码
        if (jsonObj.contains("mask")) {
            qint32 maskValue = jsonObj["mask"].toInt();
            QString newMask = convertIpAddress(maskValue);
            if (newMask != m_deviceInfo.subnetMask) {
                qDebug() << "📋 更新子网掩码:" << m_deviceInfo.subnetMask << "→" << newMask;
                m_deviceInfo.subnetMask = newMask;
                needSave = true;
            }
        }

        // MAC 地址
        if (jsonObj.contains("mach") && jsonObj.contains("macl")) {
            quint32 mach = static_cast<quint32>(jsonObj["mach"].toInt());
            quint32 macl = static_cast<quint32>(jsonObj["macl"].toInt());

            QString newMac = QString("%1:%2:%3:%4:%5:%6")
                .arg((macl >> 0) & 0xFF, 2, 16, QChar('0'))
                .arg((macl >> 8) & 0xFF, 2, 16, QChar('0'))
                .arg((macl >> 16) & 0xFF, 2, 16, QChar('0'))
                .arg((mach >> 0) & 0xFF, 2, 16, QChar('0'))
                .arg((mach >> 8) & 0xFF, 2, 16, QChar('0'))
                .arg((mach >> 16) & 0xFF, 2, 16, QChar('0'));

            if (newMac != m_deviceInfo.mac) {
                qDebug() << "📋 更新 MAC 地址:" << m_deviceInfo.mac << "→" << newMac;
                m_deviceInfo.mac = newMac;
                needSave = true;
            }
        }

        // 设备名称
        if (jsonObj.contains("name")) {
            QString newName = jsonObj["name"].toString();
            if (newName != m_deviceInfo.name) {
                qDebug() << "📋 更新设备名称:" << m_deviceInfo.name << "→" << newName;
                m_deviceInfo.name = newName;
                needSave = true;
            }
        }

        // 设备型号
        if (jsonObj.contains("plain")) {
            QString newPlain = jsonObj["plain"].toString();
            if (newPlain != m_deviceInfo.plain) {
                qDebug() << "📋 更新设备型号:" << m_deviceInfo.plain << "→" << newPlain;
                m_deviceInfo.plain = newPlain;
                needSave = true;
            }
        }

        if (needSave) {
            saveConfig();
        }
    }
}

// ========== 心跳机制 ==========

void AudioNetworkTcpSender::startHeartbeat()
{
    // ✅ 2026-01-22 18:00 [启动心跳] 启动心跳机制（5秒 PING，2秒 PONG 超时）
    qDebug() << "💓 启动心跳机制";
    m_pingTimer->start();
}

void AudioNetworkTcpSender::stopHeartbeat()
{
    // ✅ 2026-01-22 18:00 [停止心跳] 停止心跳机制
    m_pingTimer->stop();
    m_pongTimer->stop();
}

void AudioNetworkTcpSender::sendPing()
{
    // ✅ 2026-01-22 18:00 [发送PING] 发送 PING 帧，启动 PONG 超时定时器
    m_wsClient->sendPing();
    m_pongTimer->start();  // 启动 2 秒超时定时器
}

void AudioNetworkTcpSender::onPongReceived()
{
    // ✅ 2026-01-22 18:00 [接收PONG] 接收到 PONG，取消超时定时器
    m_pongTimer->stop();
    qDebug() << "💓 心跳正常（收到 PONG）";
}

void AudioNetworkTcpSender::onPongTimeout()
{
    // ✅ 2026-01-22 18:00 [PONG超时] 2秒内未收到 PONG，标记为离线
    qWarning() << "❌ 心跳超时（2秒未收到 PONG），标记为离线";
    emit heartbeatTimeout();

    // 重新连接
    stopHeartbeat();
    m_wsClient->disconnectFromServer();

    // 尝试连接下一个 IP（如果有多个 IP）
    m_currentServerIndex++;
    if (m_currentServerIndex < m_serverIpList.size()) {
        qDebug() << "📡 尝试连接下一个 IP:" << m_serverIpList[m_currentServerIndex];
        connectToServer(m_serverIpList[m_currentServerIndex], m_serverPort);
    } else {
        qWarning() << "❌ 所有服务器 IP 连接失败";
        m_currentServerIndex = 0;  // 重置索引
    }
}


// ========== Opus 编码和发送 ==========

QList<QByteArray> AudioNetworkTcpSender::encodeAudioFile(const QString& filePath)
{
    // ✅ 2026-01-22 18:30 [Opus编码] 编码音频文件为 Opus 帧列表
    // 复用 AudioNetworkSender 的解码和编码逻辑

    QList<QByteArray> opusFrames;

    // ========== 1. FFmpeg 解码音频文件 ==========
    AVFormatContext* formatCtx = nullptr;
    AVCodecContext* codecCtx = nullptr;
    SwrContext* swrCtx = nullptr;
    AVPacket* packet = nullptr;
    AVFrame* frame = nullptr;

    try {
        // 打开音频文件
        QByteArray filePathUtf8 = filePath.toUtf8();
        if (avformat_open_input(&formatCtx, filePathUtf8.constData(), nullptr, nullptr) < 0) {
            throw std::runtime_error("Failed to open audio file: " + filePath.toStdString());
        }

        // 查找音频流
        if (avformat_find_stream_info(formatCtx, nullptr) < 0) {
            throw std::runtime_error("Failed to find stream info");
        }

        int audioStreamIndex = -1;
        for (unsigned i = 0; i < formatCtx->nb_streams; i++) {
            AVCodecParameters* codecpar = formatCtx->streams[i]->codecpar;
            if (codecpar && codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
                audioStreamIndex = i;
                break;
            }
        }

        if (audioStreamIndex == -1) {
            throw std::runtime_error("No audio stream found");
        }

        // 初始化解码器
        AVCodecParameters* codecParams = formatCtx->streams[audioStreamIndex]->codecpar;
        const AVCodec* codec = avcodec_find_decoder(codecParams->codec_id);
        if (!codec) {
            throw std::runtime_error("Codec not found");
        }

        codecCtx = avcodec_alloc_context3(codec);
        if (!codecCtx) {
            throw std::runtime_error("Failed to allocate codec context");
        }

        if (avcodec_parameters_to_context(codecCtx, codecParams) < 0) {
            throw std::runtime_error("Failed to copy codec parameters");
        }

        if (avcodec_open2(codecCtx, codec, nullptr) < 0) {
            throw std::runtime_error("Failed to open codec");
        }

        qDebug() << "   📂 音频文件信息:";
        qDebug() << "      采样率:" << codecCtx->sample_rate << "Hz";
        qDebug() << "      声道数:" << codecCtx->channels;
        qDebug() << "      格式:" << av_get_sample_fmt_name(codecCtx->sample_fmt);

        // 初始化重采样器（转换为 16kHz, 16bit, mono）
        uint64_t in_channel_layout = codecCtx->channel_layout;
        if (in_channel_layout == 0) {
            in_channel_layout = av_get_default_channel_layout(codecCtx->channels);
        }

        swrCtx = swr_alloc_set_opts(
                nullptr,
                AV_CH_LAYOUT_MONO,           // 输出：单声道
                AV_SAMPLE_FMT_S16,           // 输出：16bit PCM
                16000,                       // 输出：16kHz
                in_channel_layout,           // 输入：原始声道
                codecCtx->sample_fmt,        // 输入：原始格式
                codecCtx->sample_rate,       // 输入：原始采样率
                0, nullptr);

        if (!swrCtx || swr_init(swrCtx) < 0) {
            throw std::runtime_error("Failed to initialize resampler");
        }

        // 解码和重采样
        packet = av_packet_alloc();
        frame = av_frame_alloc();
        QByteArray pcmBuffer;

        while (av_read_frame(formatCtx, packet) >= 0) {
            if (packet->stream_index == audioStreamIndex) {
                if (avcodec_send_packet(codecCtx, packet) < 0) {
                    av_packet_unref(packet);
                    continue;
                }

                while (avcodec_receive_frame(codecCtx, frame) >= 0) {
                    int outSamples = av_rescale_rnd(
                        swr_get_delay(swrCtx, codecCtx->sample_rate) + frame->nb_samples,
                        16000, codecCtx->sample_rate, AV_ROUND_UP
                    );

                    uint8_t* outBuffer = nullptr;
                    if (av_samples_alloc(&outBuffer, nullptr, 1, outSamples, AV_SAMPLE_FMT_S16, 0) >= 0) {
                        int convertedSamples = swr_convert(
                            swrCtx, &outBuffer, outSamples,
                            (const uint8_t**)frame->data, frame->nb_samples
                        );

                        if (convertedSamples > 0) {
                            pcmBuffer.append((const char*)outBuffer, convertedSamples * 2);
                        }

                        av_freep(&outBuffer);
                    }
                }
            }
            av_packet_unref(packet);
        }

        // 刷新重采样器
        uint8_t* outBuffer = nullptr;
        int outSamples = av_rescale_rnd(swr_get_delay(swrCtx, codecCtx->sample_rate), 16000, codecCtx->sample_rate, AV_ROUND_UP);
        if (outSamples > 0 && av_samples_alloc(&outBuffer, nullptr, 1, outSamples, AV_SAMPLE_FMT_S16, 0) >= 0) {
            int convertedSamples = swr_convert(swrCtx, &outBuffer, outSamples, nullptr, 0);
            if (convertedSamples > 0) {
                pcmBuffer.append((const char*)outBuffer, convertedSamples * 2);
            }
            av_freep(&outBuffer);
        }

        qDebug() << "   ✅ 音频解码完成";
        qDebug() << "      PCM 大小:" << pcmBuffer.size() << "字节";
        qDebug() << "      音频时长:" << ((pcmBuffer.size() / 2) * 1000 / 16000) << "ms";

        // 清理 FFmpeg 资源
        av_frame_free(&frame);
        av_packet_free(&packet);
        swr_free(&swrCtx);
        if (codecCtx) avcodec_free_context(&codecCtx);
        avformat_close_input(&formatCtx);

        // ========== 2. Opus 编码 ==========
        int error;
        OpusEncoder* opusEncoder = opus_encoder_create(
            16000,                      // 采样率 16kHz
            1,                          // 单声道
            OPUS_APPLICATION_VOIP,      // 语音模式（低延迟）
            &error
        );

        if (error != OPUS_OK || !opusEncoder) {
            qWarning() << "❌ Opus 编码器初始化失败:" << opus_strerror(error);
            return opusFrames;
        }

        // 设置比特率（16kbps）
        opus_encoder_ctl(opusEncoder, OPUS_SET_BITRATE(16000));

        qDebug() << "   📦 开始 Opus 编码";

        // 将 PCM 数据切分为 20ms 帧
        const int samplesPerFrame = 320;        // 20ms @ 16kHz = 320 样本
        const int bytesPerFrame = samplesPerFrame * 2;  // 2 字节/样本（16bit）
        const char* pcmPtr = pcmBuffer.constData();
        int pcmSize = pcmBuffer.size();
        int frameCount = pcmSize / bytesPerFrame;

        // 逐帧编码
        for (int i = 0; i < frameCount; i++) {
            const opus_int16* pcmFrame = reinterpret_cast<const opus_int16*>(pcmPtr + i * bytesPerFrame);

            unsigned char opusBuffer[256];
            int encodedBytes = opus_encode(
                opusEncoder,
                pcmFrame,
                samplesPerFrame,
                opusBuffer,
                sizeof(opusBuffer)
            );

            if (encodedBytes > 0) {
                QByteArray opusFrame(reinterpret_cast<const char*>(opusBuffer), encodedBytes);
                opusFrames.append(opusFrame);
            }
        }

        opus_encoder_destroy(opusEncoder);

        qDebug() << "   ✅ Opus 编码完成";
        qDebug() << "      总帧数:" << opusFrames.size() << "帧";

        return opusFrames;

    } catch (const std::exception& e) {
        // 异常时清理资源
        if (frame) av_frame_free(&frame);
        if (packet) av_packet_free(&packet);
        if (swrCtx) swr_free(&swrCtx);
        if (codecCtx) avcodec_free_context(&codecCtx);
        if (formatCtx) avformat_close_input(&formatCtx);

        QString error = QString("音频编码失败: %1").arg(e.what());
        qWarning() << "❌" << error;
        emit playbackError(error);
        return opusFrames;
    }
}

void AudioNetworkTcpSender::sendOpusFrames(const QList<QByteArray>& frames)
{
    // ✅ 2026-01-22 18:40 [发送Opus] 发送 Opus 帧列表（绝对时间戳控制）
    m_currentFrames = frames;
    m_currentFrameIndex = 0;
    m_totalFrames = frames.size();
    m_isPlaying = true;

    // 记录发送开始的绝对时间
    static QElapsedTimer timer;
    if (!timer.isValid()) {
        timer.start();
    }
    // ✅ 2026-01-22 19:30 [FIX 100.293] 预缓冲机制（延迟 40ms 开始发送）
    // 原因：
    //   - 日志显示：前 0.6 秒正常，0.6-1.8 秒出现 11-24ms 延迟
    //   - 根本原因：TCP 发送缓冲区积压（前期发送过快）
    // 解决方案：
    //   - 延迟 40ms 再开始发送，让 TCP 连接和缓冲区充分准备
    //   - 避免前期发送过快导致后期积压
    // 副作用：
    //   - 音频播放延迟增加 40ms（可接受，用户无感知）
    m_sendStartTime = timer.elapsed() + 40;  // 延迟 40ms 开始

    qDebug() << "📡 开始发送 Opus 帧（总" << m_totalFrames << "帧）";
    qDebug() << "   ⏱️ 预缓冲 40ms（防止 TCP 缓冲区积压）";

    // ❌ 2026-01-22 19:30 旧代码：立即发送第一帧（导致后期延迟）
    // sendNextFrame();

    // ✅ 2026-01-22 19:30 新代码：延迟 40ms 后开始发送
    QTimer::singleShot(40, this, &AudioNetworkTcpSender::sendNextFrame);
}

void AudioNetworkTcpSender::sendNextFrame()
{
    // ✅ 2026-01-22 18:40 [发送单帧] 发送下一帧（绝对时间戳控制）
    // 复用 AudioNetworkSender 的绝对时间戳控制算法

    // 检查是否已播放完成
    if (!m_isPlaying || m_currentFrameIndex >= m_currentFrames.size()) {
        qDebug() << "✅ 所有帧发送完成";
        stopPlayback();
        emit playbackFinished();
        return;
    }

    // 发送当前帧（WebSocket BINARY 帧）
    static QElapsedTimer timer;
    if (!timer.isValid()) {
        timer.start();
    }
    qint64 currentTime = timer.elapsed();

    const QByteArray& opusFrame = m_currentFrames[m_currentFrameIndex];
    m_wsClient->sendBinaryFrame(opusFrame);

    // 计算下一帧的绝对发送时间
    m_currentFrameIndex++;

    // 核心公式：下一帧应该发送的绝对时间戳
    // 公式：startTime + frameIndex * 20ms
    qint64 nextFrameAbsoluteTime = m_sendStartTime + m_currentFrameIndex * 20;
    qint64 delay = nextFrameAbsoluteTime - currentTime;

    // 调试日志（每 50 帧打印一次）
    if ((m_currentFrameIndex - 1) % 50 == 0) {
        qDebug() << "   📡 已发送:" << (m_currentFrameIndex - 1) << "/" << m_totalFrames
                 << "帧（" << currentTime << "ms）";
        qDebug() << "      下一帧延迟:" << delay << "ms";
    }

    // 触发进度信号
    emit playbackProgress(m_currentFrameIndex, m_totalFrames);

    // 调度下一帧发送
    if (delay > 0) {
        // 延迟发送（正常情况）
        QTimer::singleShot(delay, this, &AudioNetworkTcpSender::sendNextFrame);
    } else {
        // 已经延迟了，立即发送
        if (delay < -10) {
            qWarning() << "⚠️ 严重延迟（帧" << m_currentFrameIndex << "）: 已延迟" << (-delay) << "ms";
        }
        QTimer::singleShot(0, this, &AudioNetworkTcpSender::sendNextFrame);
    }
}

// ========== 配置持久化 ==========

void AudioNetworkTcpSender::loadConfig()
{
    // ✅ 2026-01-22 18:00 [加载配置] 从 QSettings 加载配置
    m_deviceInfo.id = m_settings->value("audio/deviceId", 0).toInt();
    m_deviceInfo.uuid = m_settings->value("audio/deviceUuid", "Init").toString();
    m_deviceInfo.name = m_settings->value("audio/deviceName", "皮带控制系统").toString();
    m_deviceInfo.plain = m_settings->value("audio/devicePlain", "RK3588").toString();
    m_deviceInfo.ip = m_settings->value("audio/networkIp", "192.168.10.188").toString();
    m_deviceInfo.gatewayIp = m_settings->value("audio/networkGateway", "192.168.10.1").toString();
    m_deviceInfo.subnetMask = m_settings->value("audio/networkMask", "255.255.255.0").toString();
    m_deviceInfo.mac = m_settings->value("audio/networkMac", "00:00:00:00:00:00").toString();
    m_deviceInfo.hardwareVersion = m_settings->value("audio/hardwareVersion", "RK3588-EVB-V1.0").toString();
    m_deviceInfo.softwareVersion = m_settings->value("audio/softwareVersion", "Belt-Control-v1.0.0").toString();

    qDebug() << "📋 加载配置完成:";
    qDebug() << "   - ID:" << m_deviceInfo.id;
    qDebug() << "   - UUID:" << m_deviceInfo.uuid;
    qDebug() << "   - 名称:" << m_deviceInfo.name;
}

void AudioNetworkTcpSender::saveConfig()
{
    // ✅ 2026-01-22 18:00 [保存配置] 保存配置到 QSettings
    m_settings->setValue("audio/deviceId", m_deviceInfo.id);
    m_settings->setValue("audio/deviceUuid", m_deviceInfo.uuid);
    m_settings->setValue("audio/deviceName", m_deviceInfo.name);
    m_settings->setValue("audio/devicePlain", m_deviceInfo.plain);
    m_settings->setValue("audio/networkIp", m_deviceInfo.ip);
    m_settings->setValue("audio/networkGateway", m_deviceInfo.gatewayIp);
    m_settings->setValue("audio/networkMask", m_deviceInfo.subnetMask);
    m_settings->setValue("audio/networkMac", m_deviceInfo.mac);
    m_settings->setValue("audio/hardwareVersion", m_deviceInfo.hardwareVersion);
    m_settings->setValue("audio/softwareVersion", m_deviceInfo.softwareVersion);

    m_settings->sync();
    qDebug() << "✅ 配置已保存";
}

// ========== 性能优化方法 ==========

void AudioNetworkTcpSender::preloadAudioFile(const QString& filePath)
{
    // ✅ 2026-01-22 19:00 [FIX 100.292] 预加载音频文件（避免首次播放延迟）

    // 检查文件是否存在
    if (!QFile::exists(filePath)) {
        qWarning() << "⚠️ 预加载失败，文件不存在:" << filePath;
        return;
    }

    // 检查是否已缓存
    if (m_opusCache.contains(filePath)) {
        qDebug() << "ℹ️ 文件已在缓存中，跳过预加载:" << filePath;
        return;
    }

    qDebug() << "🔄 开始预加载音频文件:" << filePath;

    // 编码音频文件
    QList<QByteArray> opusFrames = encodeAudioFile(filePath);

    if (!opusFrames.isEmpty()) {
        // 保存到缓存
        m_opusCache.insert(filePath, opusFrames);
        qDebug() << "   ✅ 预加载成功（总帧数:" << opusFrames.size() << "帧）";
        qDebug() << "   ✅ 当前缓存文件数:" << m_opusCache.size();
    } else {
        qWarning() << "   ❌ 预加载失败：编码失败";
    }
}

void AudioNetworkTcpSender::preloadAudioFiles(const QStringList& filePaths)
{
    // ✅ 2026-01-22 19:00 [FIX 100.292] 批量预加载音频文件

    if (filePaths.isEmpty()) {
        qWarning() << "⚠️ 预加载列表为空";
        return;
    }

    qDebug() << "🔄 开始批量预加载" << filePaths.size() << "个音频文件";

    int successCount = 0;
    int failCount = 0;

    for (const QString& filePath : filePaths) {
        if (!QFile::exists(filePath)) {
            qWarning() << "   ⚠️ 文件不存在，跳过:" << filePath;
            failCount++;
            continue;
        }

        if (m_opusCache.contains(filePath)) {
            qDebug() << "   ℹ️ 已缓存，跳过:" << filePath;
            continue;
        }

        // 编码音频文件
        QList<QByteArray> opusFrames = encodeAudioFile(filePath);

        if (!opusFrames.isEmpty()) {
            m_opusCache.insert(filePath, opusFrames);
            successCount++;
            qDebug() << "   ✅ 预加载成功:" << filePath << "（" << opusFrames.size() << "帧）";
        } else {
            failCount++;
            qWarning() << "   ❌ 预加载失败:" << filePath;
        }
    }

    qDebug() << "✅ 批量预加载完成";
    qDebug() << "   成功:" << successCount << "个";
    qDebug() << "   失败:" << failCount << "个";
    qDebug() << "   当前缓存文件数:" << m_opusCache.size();
}

void AudioNetworkTcpSender::clearOpusCache()
{
    // ✅ 2026-01-22 19:00 [FIX 100.292] 清空 Opus 帧缓存

    int count = m_opusCache.size();
    m_opusCache.clear();

    qDebug() << "🗑️ Opus 缓存已清空（释放了" << count << "个文件的缓存）";
}

int AudioNetworkTcpSender::getCachedFilesCount() const
{
    // ✅ 2026-01-22 19:00 [FIX 100.292] 获取缓存统计信息
    return m_opusCache.size();
}
