// ✅ 2026-01-22 17:00 [TCP音频传输] WebSocket 客户端协议实现
// 文件: src/audio_network/WebSocketClient.cpp
// 功能: WebSocket 协议实现（RFC 6455），用于 TCP 音频传输模式
// 作者: Claude AI
// 日期: 2026-01-22

#include "WebSocketClient.h"
#include <QDebug>
#include <QRandomGenerator>
#include <QCryptographicHash>

// ========== 构造函数 / 析构函数 ==========

WebSocketClient::WebSocketClient(QObject *parent)
    : QObject(parent)
    , m_socket(new QTcpSocket(this))
    , m_serverIp("")
    , m_serverPort(0)
    , m_handshakeCompleted(false)
{
    // ✅ 2026-01-22 17:00 [TCP连接] 连接 TCP 套接字信号
    connect(m_socket, &QTcpSocket::connected, this, &WebSocketClient::onTcpConnected);
    connect(m_socket, &QTcpSocket::disconnected, this, &WebSocketClient::onTcpDisconnected);
    connect(m_socket, &QTcpSocket::readyRead, this, &WebSocketClient::onReadyRead);
    connect(m_socket, &QTcpSocket::errorOccurred, this, &WebSocketClient::onTcpError);

    qDebug() << "✅ WebSocketClient 初始化完成";
}

WebSocketClient::~WebSocketClient()
{
    // ✅ 2026-01-22 17:00 [资源清理] 断开连接并清理资源
    if (m_socket->state() == QAbstractSocket::ConnectedState) {
        m_socket->disconnectFromHost();
        m_socket->waitForDisconnected(1000);
    }
    qDebug() << "✅ WebSocketClient 析构完成";
}

// ========== 连接管理 ==========

void WebSocketClient::connectToServer(const QString& ip, quint16 port)
{
    // ✅ 2026-01-22 17:00 [TCP连接] 连接到 WebSocket 服务器
    if (m_socket->state() == QAbstractSocket::ConnectedState) {
        qWarning() << "⚠️ 已经连接到服务器，先断开";
        m_socket->disconnectFromHost();
        m_socket->waitForDisconnected(1000);
    }

    m_serverIp = ip;
    m_serverPort = port;
    m_handshakeCompleted = false;
    m_receiveBuffer.clear();

    qDebug() << "📡 开始连接 WebSocket 服务器:" << ip << ":" << port;
    m_socket->connectToHost(ip, port);
}

void WebSocketClient::disconnectFromServer()
{
    // ✅ 2026-01-22 17:00 [断开连接] 主动断开连接
    if (m_socket->state() == QAbstractSocket::ConnectedState) {
        qDebug() << "📡 主动断开 WebSocket 连接";
        m_socket->disconnectFromHost();
    }
}

bool WebSocketClient::isConnected() const
{
    // ✅ 2026-01-22 17:00 [连接状态] 检查是否已连接并完成握手
    return m_socket->state() == QAbstractSocket::ConnectedState && m_handshakeCompleted;
}

// ========== 帧发送接口 ==========

void WebSocketClient::sendTextFrame(const QString& text)
{
    // ✅ 2026-01-22 17:00 [发送TEXT帧] 发送文本帧（设备信息 JSON）
    if (!m_handshakeCompleted) {
        qWarning() << "❌ WebSocket 握手未完成，无法发送 TEXT 帧";
        return;
    }

    QByteArray payload = text.toUtf8();
    QByteArray frame = encodeFrame(payload, TEXT);

    qint64 bytesSent = m_socket->write(frame);
    if (bytesSent < 0) {
        qWarning() << "❌ 发送 TEXT 帧失败:" << m_socket->errorString();
        emit error(m_socket->errorString());
    } else {
        qDebug() << "📤 发送 TEXT 帧:" << text.left(100) << "...（" << payload.size() << "字节）";
    }
}

void WebSocketClient::sendBinaryFrame(const QByteArray& data)
{
    // ✅ 2026-01-22 17:00 [发送BINARY帧] 发送二进制帧（Opus 音频数据）
    if (!m_handshakeCompleted) {
        qWarning() << "❌ WebSocket 握手未完成，无法发送 BINARY 帧";
        return;
    }

    QByteArray frame = encodeFrame(data, BINARY);

    qint64 bytesSent = m_socket->write(frame);
    if (bytesSent < 0) {
        qWarning() << "❌ 发送 BINARY 帧失败:" << m_socket->errorString();
        emit error(m_socket->errorString());
    }
    // Opus 数据发送频繁，不打印调试日志
}

void WebSocketClient::sendPing()
{
    // ✅ 2026-01-22 17:00 [发送PING帧] 发送心跳 PING 帧
    if (!m_handshakeCompleted) {
        qWarning() << "❌ WebSocket 握手未完成，无法发送 PING 帧";
        return;
    }

    QByteArray emptyPayload;  // PING 帧通常没有载荷
    QByteArray frame = encodeFrame(emptyPayload, PING);

    qint64 bytesSent = m_socket->write(frame);
    if (bytesSent < 0) {
        qWarning() << "❌ 发送 PING 帧失败:" << m_socket->errorString();
        emit error(m_socket->errorString());
    } else {
        qDebug() << "💓 发送 PING 帧（心跳）";
    }
}

void WebSocketClient::sendPong()
{
    // ✅ 2026-01-22 17:00 [发送PONG帧] 发送心跳 PONG 帧
    if (!m_handshakeCompleted) {
        qWarning() << "❌ WebSocket 握手未完成，无法发送 PONG 帧";
        return;
    }

    QByteArray emptyPayload;  // PONG 帧通常没有载荷
    QByteArray frame = encodeFrame(emptyPayload, PONG);

    qint64 bytesSent = m_socket->write(frame);
    if (bytesSent < 0) {
        qWarning() << "❌ 发送 PONG 帧失败:" << m_socket->errorString();
        emit error(m_socket->errorString());
    } else {
        qDebug() << "💓 发送 PONG 帧（心跳响应）";
    }
}

// ========== TCP 槽函数 ==========

void WebSocketClient::onTcpConnected()
{
    // ✅ 2026-01-22 17:00 [TCP连接成功] TCP 连接成功，发送 WebSocket 握手请求
    qDebug() << "✅ TCP 连接成功:" << m_serverIp << ":" << m_serverPort;
    emit connected();

    // 发送 WebSocket 握手请求
    sendHandshake();
}

void WebSocketClient::onTcpDisconnected()
{
    // ✅ 2026-01-22 17:00 [TCP断开连接] TCP 连接断开
    qDebug() << "📡 TCP 连接断开";
    m_handshakeCompleted = false;
    m_receiveBuffer.clear();
    emit disconnected();
}

void WebSocketClient::onReadyRead()
{
    // ✅ 2026-01-22 17:00 [接收数据] TCP 数据到达，解析 WebSocket 帧
    QByteArray data = m_socket->readAll();
    m_receiveBuffer.append(data);

    if (!m_handshakeCompleted) {
        // ========== 检测握手响应 ==========
        // 握手响应格式：HTTP/1.1 101 Switching Protocols\r\n...\r\n\r\n
        int handshakeEndIndex = m_receiveBuffer.indexOf("\r\n\r\n");
        if (handshakeEndIndex >= 0) {
            // 提取握手响应
            QByteArray handshakeResponse = m_receiveBuffer.left(handshakeEndIndex + 4);
            m_receiveBuffer.remove(0, handshakeEndIndex + 4);

            // 检查响应状态码
            QString responseStr = QString::fromUtf8(handshakeResponse);
            if (responseStr.contains("101 Switching Protocols")) {
                qDebug() << "✅ WebSocket 握手成功";
                m_handshakeCompleted = true;
                emit handshakeCompleted();
            } else {
                qWarning() << "❌ WebSocket 握手失败，响应:" << responseStr;
                emit error("WebSocket 握手失败");
                m_socket->disconnectFromHost();
                return;
            }
        } else {
            // 握手响应还未完整接收
            return;
        }
    }

    // ========== 解析 WebSocket 帧 ==========
    decodeFrame(m_receiveBuffer);
}

void WebSocketClient::onTcpError(QAbstractSocket::SocketError socketError)
{
    // ✅ 2026-01-22 17:00 [TCP错误] TCP 错误处理
    QString errorString = m_socket->errorString();
    qWarning() << "❌ TCP 错误（" << socketError << "）:" << errorString;
    emit error(errorString);
}

// ========== WebSocket 协议实现 ==========

void WebSocketClient::sendHandshake()
{
    // ✅ 2026-01-22 17:00 [WebSocket握手] 发送 HTTP Upgrade 请求
    // 握手请求格式（参考示例代码 ws.c）：
    /*
     * GET / HTTP/1.1
     * Host: 192.168.10.100:7800
     * Upgrade: websocket
     * Connection: Upgrade
     * Sec-WebSocket-Key: IOOrTAccqgbLY8uExs7JBA==
     * Sec-WebSocket-Version: 13
     *
     */

    QString handshake = QString(
        "GET / HTTP/1.1\r\n"
        "Host: %1:%2\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        "Sec-WebSocket-Key: IOOrTAccqgbLY8uExs7JBA==\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        "\r\n"
    ).arg(m_serverIp).arg(m_serverPort);

    qDebug() << "📤 发送 WebSocket 握手请求:";
    qDebug() << handshake;

    m_socket->write(handshake.toUtf8());
    m_socket->flush();
}

QByteArray WebSocketClient::encodeFrame(const QByteArray& payload, quint8 opcode)
{
    // ✅ 2026-01-22 17:00 [帧编码] 编码 WebSocket 帧（RFC 6455）
    // 参考示例代码 ws.c 的 ws_sendData() 函数

    QByteArray frame;
    int payloadLen = payload.size();

    // ========== 1. FIN + Opcode (1 字节) ==========
    // FIN=1（最后一帧），Opcode（帧类型）
    frame.append(static_cast<char>(0x80 | opcode));

    // ========== 2. MASK + Length (1-9 字节) ==========
    // MASK=1（客户端必须掩码），Length（载荷长度）
    if (payloadLen < 126) {
        // 短载荷（< 126 字节）：直接编码长度
        frame.append(static_cast<char>(0x80 | payloadLen));
    } else if (payloadLen < 65536) {
        // 中等载荷（126-65535 字节）：使用 2 字节扩展长度
        frame.append(static_cast<char>(0x80 | 126));
        frame.append(static_cast<char>((payloadLen >> 8) & 0xFF));
        frame.append(static_cast<char>(payloadLen & 0xFF));
    } else {
        // 长载荷（>= 65536 字节）：使用 8 字节扩展长度
        frame.append(static_cast<char>(0x80 | 127));
        frame.append(static_cast<char>(0));  // 高 4 字节（通常为 0）
        frame.append(static_cast<char>(0));
        frame.append(static_cast<char>(0));
        frame.append(static_cast<char>(0));
        frame.append(static_cast<char>((payloadLen >> 24) & 0xFF));
        frame.append(static_cast<char>((payloadLen >> 16) & 0xFF));
        frame.append(static_cast<char>((payloadLen >> 8) & 0xFF));
        frame.append(static_cast<char>(payloadLen & 0xFF));
    }

    // ========== 3. Mask Key (4 字节) ==========
    // 客户端必须使用随机掩码（RFC 6455 要求）
    quint8 mask[4];
    generateMask(mask);
    for (int i = 0; i < 4; i++) {
        frame.append(static_cast<char>(mask[i]));
    }

    // ========== 4. Payload（载荷，XOR 掩码）==========
    // 每个字节与掩码异或：payload[i] ^ mask[i % 4]
    for (int i = 0; i < payloadLen; i++) {
        frame.append(static_cast<char>(payload[i] ^ mask[i % 4]));
    }

    return frame;
}

void WebSocketClient::decodeFrame(const QByteArray& data)
{
    // ✅ 2026-01-22 17:00 [帧解码] 解码 WebSocket 帧（RFC 6455）
    // 参考示例代码 ws.c 的 ws_recvData() 函数

    int sindex = 0;  // 数据读取索引
    int eindex = m_receiveBuffer.size();  // 数据结束索引

    while (eindex >= sindex + 2) {
        // ========== 1. 解析 FIN + Opcode ==========
        quint8 firstByte = static_cast<quint8>(m_receiveBuffer[sindex]);
        quint8 opcode = firstByte & 0x0F;

        // ========== 2. 解析 MASK + Length ==========
        quint8 secondByte = static_cast<quint8>(m_receiveBuffer[sindex + 1]);
        quint8 mask = secondByte & 0x80;  // 掩码位
        int payloadLen = secondByte & 0x7F;
        int headsize = 2;  // 头部大小

        // ========== 2.1 解析扩展长度 ==========
        if (payloadLen == 126) {
            if (eindex < sindex + 4) return;  // 数据不足，等待更多数据
            headsize = 4;
            payloadLen = (static_cast<quint8>(m_receiveBuffer[sindex + 2]) << 8) |
                         static_cast<quint8>(m_receiveBuffer[sindex + 3]);
        } else if (payloadLen == 127) {
            if (eindex < sindex + 10) return;  // 数据不足，等待更多数据
            headsize = 10;
            // 只取低 4 字节（假设载荷不会超过 4GB）
            payloadLen = (static_cast<quint8>(m_receiveBuffer[sindex + 6]) << 24) |
                         (static_cast<quint8>(m_receiveBuffer[sindex + 7]) << 16) |
                         (static_cast<quint8>(m_receiveBuffer[sindex + 8]) << 8) |
                         static_cast<quint8>(m_receiveBuffer[sindex + 9]);
        }

        // ========== 2.2 限制载荷大小（防止内存溢出）==========
        if (payloadLen >= 2048) {
            qWarning() << "⚠️ 载荷过大（" << payloadLen << "字节），跳过该帧";
            sindex += payloadLen + headsize;
            continue;
        }

        // ========== 3. 检查数据是否完整 ==========
        if (eindex - sindex < payloadLen + headsize) {
            // 数据不完整，等待更多数据
            return;
        }

        // ========== 4. 提取载荷 ==========
        sindex += headsize;
        QByteArray payload;
        for (int i = 0; i < payloadLen; i++) {
            payload.append(m_receiveBuffer[sindex++]);
        }

        // ========== 5. 根据 Opcode 处理帧 ==========
        if (opcode == TEXT) {
            // 文本帧（设备配置 JSON）
            QString text = QString::fromUtf8(payload);
            qDebug() << "📥 接收 TEXT 帧:" << text.left(100) << "...";
            emit textFrameReceived(text);
        } else if (opcode == BINARY) {
            // 二进制帧（Opus 音频数据）
            // 不打印调试日志（数据量大）
            emit binaryFrameReceived(payload);
        } else if (opcode == PING) {
            // PING 帧（服务器心跳）
            qDebug() << "💓 接收 PING 帧";
            emit pingReceived();
            sendPong();  // 自动回复 PONG
        } else if (opcode == PONG) {
            // PONG 帧（心跳响应）
            qDebug() << "💓 接收 PONG 帧";
            emit pongReceived();
        } else if (opcode == CLOSE) {
            // CLOSE 帧（关闭连接）
            qDebug() << "📡 接收 CLOSE 帧，服务器关闭连接";
            m_socket->disconnectFromHost();
        } else {
            qWarning() << "⚠️ 未知帧类型（Opcode=" << opcode << "）";
        }
    }

    // ========== 6. 清理已处理的数据 ==========
    if (sindex > 0) {
        m_receiveBuffer.remove(0, sindex);
    }
}

void WebSocketClient::generateMask(quint8 mask[4])
{
    // ✅ 2026-01-22 17:00 [生成掩码] 生成随机掩码（RFC 6455 要求客户端必须掩码）
    // 参考示例代码 ws.c 的固定掩码：{0x35, 0x58, 0x85, 0x69}
    // 这里使用 Qt 的随机数生成器

    quint32 randomValue = QRandomGenerator::global()->generate();
    mask[0] = (randomValue >> 24) & 0xFF;
    mask[1] = (randomValue >> 16) & 0xFF;
    mask[2] = (randomValue >> 8) & 0xFF;
    mask[3] = randomValue & 0xFF;
}
