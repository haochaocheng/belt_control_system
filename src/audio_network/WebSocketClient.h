// ✅ 2026-01-22 16:45 [TCP音频传输] WebSocket 客户端协议封装
// 文件: src/audio_network/WebSocketClient.h
// 功能: WebSocket 协议实现（RFC 6455），用于 TCP 音频传输模式
// 作者: Claude AI
// 日期: 2026-01-22

#ifndef WEBSOCKETCLIENT_H
#define WEBSOCKETCLIENT_H

#include <QObject>
#include <QTcpSocket>
#include <QByteArray>
#include <QString>
#include <QTimer>

/**
 * @brief WebSocket 客户端协议封装类
 *
 * 功能描述：
 * - TCP 连接到服务器
 * - WebSocket 握手（HTTP Upgrade）
 * - 帧编码（TEXT, BINARY, PING, PONG）
 * - 帧解码（接收服务器数据）
 * - 客户端掩码处理（RFC 6455 要求）
 *
 * 使用示例：
 * @code
 * WebSocketClient* client = new WebSocketClient(this);
 * connect(client, &WebSocketClient::handshakeCompleted, this, [this, client]() {
 *     // 握手成功后发送设备信息
 *     QString deviceInfo = "{\"cmd\":1,\"name\":\"Belt-Control\"}";
 *     client->sendTextFrame(deviceInfo);
 * });
 * client->connectToServer("192.168.10.100", 7800);
 * @endcode
 *
 * WebSocket 帧结构（RFC 6455）：
 * @code
 * ┌──────┬──────┬────────┬────────┬──────────────┐
 * │ FIN  │ Len  │ Len Ex │ Mask   │   Payload    │
 * │ Opc  │ Mask │ (0/2/8)│ (4B)   │ (Data)       │
 * └──────┴──────┴────────┴────────┴──────────────┘
 *   1B     1B     0/2/8B    4B       N bytes
 * @endcode
 *
 * 帧类型（Opcode）：
 * - 0x01: TEXT    文本帧（设备信息 JSON）
 * - 0x02: BINARY  二进制帧（Opus 音频数据）
 * - 0x08: CLOSE   关闭连接
 * - 0x09: PING    心跳检测（客户端发送）
 * - 0x0A: PONG    心跳响应（服务器发送）
 */
class WebSocketClient : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief 构造函数
     * @param parent 父对象
     */
    explicit WebSocketClient(QObject *parent = nullptr);

    /**
     * @brief 析构函数
     */
    ~WebSocketClient();

    // ========== 连接管理 ==========

    /**
     * @brief 连接到 WebSocket 服务器
     * @param ip 服务器 IP 地址（例如："192.168.10.100"）
     * @param port 服务器端口（例如：7800）
     *
     * 连接流程：
     * 1. TCP 连接到服务器
     * 2. 发送 HTTP Upgrade 请求（WebSocket 握手）
     * 3. 等待 "101 Switching Protocols" 响应
     * 4. 握手成功后发送 handshakeCompleted 信号
     */
    void connectToServer(const QString& ip, quint16 port);

    /**
     * @brief 断开连接
     */
    void disconnectFromServer();

    /**
     * @brief 检查是否已连接
     * @return true=已连接，false=未连接
     */
    bool isConnected() const;

    // ========== 帧发送接口 ==========

    /**
     * @brief 发送文本帧（TEXT）
     * @param text 文本内容（通常是 JSON 字符串）
     *
     * 用途：
     * - 发送设备信息 JSON（cmd=1）
     * - 接收服务器配置指令
     */
    void sendTextFrame(const QString& text);

    /**
     * @brief 发送 PING 帧（心跳）
     *
     * 用途：
     * - 每 5 秒发送一次心跳
     * - 检测连接是否存活
     */
    void sendPing();

    /**
     * @brief 发送 PONG 帧（心跳响应）
     *
     * 用途：
     * - 响应服务器的 PING 帧
     */
    void sendPong();

public slots:
    // ✅ 2026-01-22 21:05 [FIX 100.295.1] 改为 slot，支持跨线程调用
    /**
     * @brief 发送二进制帧（BINARY）
     * @param data 二进制数据（通常是 Opus 音频帧）
     *
     * 用途：
     * - 发送 Opus 编码的音频数据
     * - ✅ 支持跨线程调用（Qt::AutoConnection 自动处理）
     */
    void sendBinaryFrame(const QByteArray& data);

signals:
    // ========== 连接状态信号 ==========

    /**
     * @brief TCP 连接成功信号
     */
    void connected();

    /**
     * @brief WebSocket 握手完成信号
     *
     * 说明：握手成功后可以开始发送数据
     */
    void handshakeCompleted();

    /**
     * @brief 连接断开信号
     */
    void disconnected();

    /**
     * @brief 连接错误信号
     * @param error 错误描述
     */
    void error(const QString& error);

    // ========== 帧接收信号 ==========

    /**
     * @brief 接收到文本帧信号
     * @param text 文本内容（通常是服务器配置 JSON）
     */
    void textFrameReceived(const QString& text);

    /**
     * @brief 接收到二进制帧信号
     * @param data 二进制数据
     */
    void binaryFrameReceived(const QByteArray& data);

    /**
     * @brief 接收到 PONG 信号（心跳响应）
     *
     * 用途：
     * - 取消心跳超时定时器
     * - 确认连接存活
     */
    void pongReceived();

    /**
     * @brief 接收到 PING 信号（服务器心跳）
     *
     * 用途：
     * - 自动回复 PONG 帧
     */
    void pingReceived();

private slots:
    /**
     * @brief TCP 连接成功槽函数
     */
    void onTcpConnected();

    /**
     * @brief TCP 连接断开槽函数
     */
    void onTcpDisconnected();

    /**
     * @brief TCP 数据到达槽函数
     */
    void onReadyRead();

    /**
     * @brief TCP 错误槽函数
     * @param socketError 错误类型
     */
    void onTcpError(QAbstractSocket::SocketError socketError);

private:
    // ========== WebSocket 协议实现 ==========

    /**
     * @brief 发送 WebSocket 握手请求
     *
     * HTTP 请求格式：
     * @code
     * GET / HTTP/1.1
     * Host: 192.168.10.100:7800
     * Upgrade: websocket
     * Connection: Upgrade
     * Sec-WebSocket-Key: IOOrTAccqgbLY8uExs7JBA==
     * Sec-WebSocket-Version: 13
     *
     * @endcode
     */
    void sendHandshake();

    /**
     * @brief 编码 WebSocket 帧
     * @param payload 有效载荷数据
     * @param opcode 帧类型（0x01=TEXT, 0x02=BINARY, 0x09=PING, 0x0A=PONG）
     * @return 编码后的完整帧数据
     *
     * 帧结构：
     * 1. FIN + Opcode (1 字节)：0x80 | opcode
     * 2. MASK + Length (1-9 字节)：
     *    - Len < 126: 0x80 | len
     *    - 126 <= Len < 65536: 0xFE, len_high, len_low
     *    - Len >= 65536: 0xFF, 8 字节长度
     * 3. Mask Key (4 字节)：随机生成
     * 4. Payload (N 字节)：数据异或掩码
     */
    QByteArray encodeFrame(const QByteArray& payload, quint8 opcode);

    /**
     * @brief 解码 WebSocket 帧
     * @param data 接收到的数据
     *
     * 解码流程：
     * 1. 解析 FIN + Opcode
     * 2. 解析 MASK + Length
     * 3. 提取 Payload
     * 4. 根据 Opcode 发送相应信号
     */
    void decodeFrame(const QByteArray& data);

    /**
     * @brief 生成随机掩码
     * @param mask 掩码数组（4 字节）
     */
    void generateMask(quint8 mask[4]);

    // ========== 成员变量 ==========

    QTcpSocket* m_socket;              ///< TCP 套接字
    QString m_serverIp;                ///< 服务器 IP
    quint16 m_serverPort;              ///< 服务器端口

    bool m_handshakeCompleted;         ///< 握手是否完成

    QByteArray m_receiveBuffer;        ///< 接收缓冲区（用于处理粘包）

    // ========== 帧类型枚举 ==========

    /**
     * @brief WebSocket 帧类型枚举
     */
    enum FrameType {
        TEXT = 0x01,      ///< 文本帧
        BINARY = 0x02,    ///< 二进制帧
        CLOSE = 0x08,     ///< 关闭帧
        PING = 0x09,      ///< PING 帧
        PONG = 0x0A       ///< PONG 帧
    };
};

#endif // WEBSOCKETCLIENT_H
