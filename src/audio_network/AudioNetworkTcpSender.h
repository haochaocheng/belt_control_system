// ✅ 2026-01-22 17:30 [TCP音频传输] TCP 模式音频发送器
// 文件: src/audio_network/AudioNetworkTcpSender.h
// 功能: TCP 模式音频传输（UDP 发现 + TCP 连接 + WebSocket + 心跳）
// 作者: Claude AI
// 日期: 2026-01-22
// ✅ 2026-01-22 20:40 [FIX 100.295] 添加独立发送线程支持

#ifndef AUDIONETWORKTCPSENDER_H
#define AUDIONETWORKTCPSENDER_H

#include <QObject>
#include <QUdpSocket>
#include <QTimer>
#include <QSettings>
#include <QString>
#include <QByteArray>
#include <QList>
#include <QThread>
#include "WebSocketClient.h"
#include "AudioSenderWorker.h"

/**
 * @brief TCP 模式音频发送器类
 *
 * 功能描述：
 * - UDP 服务发现（监听 8600 端口）
 * - 解析 JSON 获取 TCP 服务器 IP:Port
 * - TCP 连接 + WebSocket 握手
 * - 发送设备信息 JSON
 * - Opus 数据发送（20ms 帧）
 * - 心跳机制（5秒 PING，2秒 PONG 超时）
 * - 配置持久化（QSettings）
 *
 * 使用示例：
 * @code
 * AudioNetworkTcpSender* sender = new AudioNetworkTcpSender(this);
 * sender->setUdpDiscoveryPort(8600);
 * sender->setDeviceInfo(deviceInfo);
 * sender->startDiscovery();
 *
 * // 播放音频到网络
 * sender->playAudioToNetwork("/path/to/audio.mp3");
 * @endcode
 *
 * 工作流程：
 * 1. startDiscovery() → 监听 UDP 8600 端口
 * 2. 接收 JSON：{"voiceport": 7800, "voicev4": [-1062731588]}
 * 3. 解析 IP:Port（-1062731588 → 192.168.10.188）
 * 4. connectToServer() → TCP 连接 + WebSocket 握手
 * 5. sendDeviceInfo() → 发送设备信息 JSON（cmd=1）
 * 6. startHeartbeat() → 每 5 秒发送 PING，等待 2 秒 PONG
 * 7. playAudioToNetwork() → 发送 Opus 数据（20ms 帧）
 *
 * JSON 协议：
 * - **UDP 发现**：{"voiceport": 7800, "voicev4": [-1062731588, -1062731589]}
 * - **设备信息**：{"cmd": 1, "id": 0, "uuid": "...", "name": "...", ...}
 * - **服务器配置**：cmd=1（ID/UUID 更新），cmd=2（网络配置更新）
 */
class AudioNetworkTcpSender : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief 设备信息结构体
     */
    struct DeviceInfo {
        int id;                      ///< 设备 ID（默认 0，服务器分配后保存）
        QString uuid;                ///< 设备 UUID（默认 "Init"，服务器分配后保存）
        QString name;                ///< 设备名称（例如："皮带控制系统"）
        QString plain;               ///< 设备型号（例如："RK3588"）
        QString ip;                  ///< 本机 IP（点分十进制字符串）
        QString mac;                 ///< 本机 MAC（6 字节十六进制字符串，用冒号分隔）
        QString hardwareVersion;     ///< 硬件版本（例如："RK3588-EVB-V1.0"）
        QString softwareVersion;     ///< 软件版本（例如："Belt-Control-v1.0.0"）

        // 网络配置（服务器分配）
        QString gatewayIp;           ///< 网关 IP
        QString subnetMask;          ///< 子网掩码
    };

    /**
     * @brief 构造函数
     * @param parent 父对象
     */
    explicit AudioNetworkTcpSender(QObject *parent = nullptr);

    /**
     * @brief 析构函数
     */
    ~AudioNetworkTcpSender();

    // ========== 配置接口 ==========

    /**
     * @brief 设置 UDP 服务发现端口
     * @param port UDP 监听端口（默认 8600）
     */
    void setUdpDiscoveryPort(quint16 port);

    /**
     * @brief 设置设备信息
     * @param info 设备信息结构体
     */
    void setDeviceInfo(const DeviceInfo& info);

    /**
     * @brief 获取当前设备信息
     * @return 设备信息结构体
     */
    DeviceInfo getDeviceInfo() const;

    // ========== 启动 / 停止 ==========

    /**
     * @brief 启动 UDP 服务发现
     *
     * 说明：
     * - 绑定 UDP 端口 8600（或自定义端口）
     * - 等待上位机广播配置 JSON
     */
    void startDiscovery();

    /**
     * @brief 停止所有服务
     *
     * 说明：
     * - 停止 UDP 监听
     * - 断开 TCP 连接
     * - 停止心跳定时器
     */
    void stopAll();

    // ========== 播放接口（复用 AudioNetworkSender 的编码逻辑）==========

    /**
     * @brief 播放音频到网络
     * @param filePath 音频文件路径（MP3, WAV, OGG 等）
     *
     * 说明：
     * - FFmpeg 解码 → PCM（16kHz, 16bit, mono）
     * - Opus 编码 → 20ms 帧（16kbps）
     * - WebSocket BINARY 帧发送
     * - ✅ 2026-01-22 [FIX 100.292] 添加 Opus 帧缓存（避免重复编码）
     */
    void playAudioToNetwork(const QString& filePath);

    /**
     * @brief 停止播放
     */
    void stopPlayback();

    /**
     * @brief 检查是否正在播放
     * @return true=正在播放，false=未播放
     */
    bool isPlaying() const;

    /**
     * @brief 检查是否已连接到服务器
     * @return true=已连接，false=未连接
     * // ✅ 2026-01-22 修复编译错误: 添加 isConnected() 方法
     */
    bool isConnected() const;

    // ========== 性能优化接口 ==========

    /**
     * @brief 预加载音频文件（提前编码到缓存）
     * @param filePath 音频文件路径
     *
     * 说明：
     * - ✅ 2026-01-22 [FIX 100.292] 预加载常用音频文件
     * - 在启动时调用，避免首次播放延迟
     * - 示例：preloadAudioFile("/app/appdata/audio/alarm_slip.mp3");
     */
    void preloadAudioFile(const QString& filePath);

    /**
     * @brief 批量预加载音频文件
     * @param filePaths 音频文件路径列表
     *
     * 说明：
     * - ✅ 2026-01-22 [FIX 100.292] 批量预加载
     * - 示例：preloadAudioFiles({"alarm1.mp3", "alarm2.mp3"});
     */
    void preloadAudioFiles(const QStringList& filePaths);

    /**
     * @brief 清空 Opus 帧缓存
     *
     * 说明：
     * - 释放内存
     * - 音频文件更新后需要清空缓存
     */
    void clearOpusCache();

    /**
     * @brief 获取缓存统计信息
     * @return 缓存文件数量
     */
    int getCachedFilesCount() const;

signals:
    // ========== UDP 服务发现信号 ==========

    /**
     * @brief UDP 服务发现成功信号
     * @param ip 服务器 IP
     * @param port 服务器端口
     */
    void discoverySucceeded(const QString& ip, quint16 port);

    /**
     * @brief UDP 服务发现失败信号
     * @param error 错误描述
     */
    void discoveryFailed(const QString& error);

    // ========== TCP 连接信号 ==========

    /**
     * @brief TCP 连接成功信号
     */
    void tcpConnected();

    /**
     * @brief WebSocket 握手完成信号
     */
    void webSocketReady();

    /**
     * @brief TCP 连接断开信号
     */
    void tcpDisconnected();

    /**
     * @brief TCP 连接错误信号
     * @param error 错误描述
     */
    void tcpError(const QString& error);

    // ========== 心跳信号 ==========

    /**
     * @brief 心跳超时信号
     *
     * 说明：2 秒内未收到 PONG，标记为离线
     */
    void heartbeatTimeout();

    // ========== 播放信号 ==========

    /**
     * @brief 播放开始信号
     * @param fileName 音频文件名
     */
    void playbackStarted(const QString& fileName);

    /**
     * @brief 播放进度信号
     * @param framesSent 已发送帧数
     * @param totalFrames 总帧数
     */
    void playbackProgress(int framesSent, int totalFrames);

    /**
     * @brief 播放完成信号
     */
    void playbackFinished();

    /**
     * @brief 播放错误信号
     * @param error 错误描述
     */
    void playbackError(const QString& error);

private slots:
    // ========== UDP 服务发现槽函数 ==========

    /**
     * @brief UDP 数据到达槽函数
     */
    void onUdpDatagramReady();

    // ========== WebSocket 槽函数 ==========

    /**
     * @brief WebSocket 握手完成槽函数
     */
    void onWebSocketReady();

    /**
     * @brief 接收 TEXT 帧槽函数（服务器配置）
     * @param text 文本内容（JSON）
     */
    void onServerConfigReceived(const QString& text);

    /**
     * @brief 接收 PONG 槽函数（心跳响应）
     */
    void onPongReceived();

    // ========== 心跳定时器槽函数 ==========

    /**
     * @brief 发送 PING 槽函数（每 5 秒）
     */
    void sendPing();

    /**
     * @brief PONG 超时槽函数（2 秒未收到 PONG）
     */
    void onPongTimeout();

    // ========== Opus 发送定时器槽函数 ==========

    /**
     * @brief 发送下一帧槽函数（每 20ms）
     */
    void sendNextFrame();

private:
    // ========== UDP 服务发现 ==========

    /**
     * @brief 解析 UDP 发现 JSON
     * @param data JSON 数据
     *
     * JSON 格式：
     * @code
     * {
     *   "voiceport": 7800,
     *   "voicev4": [-1062731588, -1062731589]
     * }
     * @endcode
     *
     * IP 地址转换：
     * -1062731588 (有符号32位) = 0xC0A80ABC = 192.168.10.188
     */
    void parseDiscoveryJson(const QByteArray& data);

    /**
     * @brief 转换 IP 地址（32位有符号整数 → 点分十进制字符串）
     * @param ipValue 32 位有符号整数
     * @return 点分十进制字符串（例如："192.168.10.188"）
     */
    QString convertIpAddress(qint32 ipValue);

    // ========== TCP 连接 ==========

    /**
     * @brief 连接到 TCP 服务器
     * @param ip 服务器 IP
     * @param port 服务器端口
     */
    void connectToServer(const QString& ip, quint16 port);

    /**
     * @brief 发送设备信息 JSON
     *
     * JSON 格式：
     * @code
     * {
     *   "cmd": 1,
     *   "state": 1,
     *   "id": 0,
     *   "uuid": "Belt-Control-System-001",
     *   "type": 2,
     *   "name": "皮带控制系统",
     *   "plain": "RK3588",
     *   "ip": -1062731588,
     *   "mach": 12345,
     *   "macl": 67890,
     *   "mask": -256,
     *   "gate": -1062731519,
     *   "hard": "RK3588-EVB-V1.0",
     *   "soft": "Belt-Control-v1.0.0"
     * }
     * @endcode
     */
    void sendDeviceInfo();

    /**
     * @brief 处理服务器配置 JSON
     * @param json JSON 字符串
     *
     * 支持的命令：
     * - cmd=1: 更新 ID 和 UUID
     * - cmd=2: 更新网络配置（IP, 网关, 子网掩码, MAC, 名称）
     */
    void handleServerConfig(const QString& json);

    // ========== 心跳机制 ==========

    /**
     * @brief 启动心跳机制
     *
     * 说明：
     * - m_pingTimer: 每 5 秒发送 PING
     * - m_pongTimer: 2 秒超时检测
     */
    void startHeartbeat();

    /**
     * @brief 停止心跳机制
     */
    void stopHeartbeat();

    // ========== Opus 编码和发送 ==========

    /**
     * @brief 编码音频文件为 Opus 帧列表
     * @param filePath 音频文件路径
     * @return Opus 帧列表（每帧 20ms）
     *
     * 说明：
     * - FFmpeg 解码 → PCM（16kHz, 16bit, mono）
     * - Opus 编码 → 20ms 帧（16kbps）
     * - 复用 AudioNetworkSender 的编码逻辑
     */
    QList<QByteArray> encodeAudioFile(const QString& filePath);

    /**
     * @brief 发送 Opus 帧列表
     * @param frames Opus 帧列表
     *
     * 说明：
     * - 使用绝对时间戳控制（20ms 精确定时）
     * - WebSocket BINARY 帧发送
     */
    void sendOpusFrames(const QList<QByteArray>& frames);

    // ========== 配置持久化 ==========

    /**
     * @brief 加载配置（从 QSettings）
     *
     * 配置项：
     * - audio/deviceId: 设备 ID
     * - audio/deviceUuid: 设备 UUID
     * - audio/deviceName: 设备名称
     * - audio/devicePlain: 设备型号
     * - audio/networkIp: 本机 IP
     * - audio/networkGateway: 网关 IP
     * - audio/networkMask: 子网掩码
     * - audio/networkMac: MAC 地址
     */
    void loadConfig();

    /**
     * @brief 保存配置（到 QSettings）
     */
    void saveConfig();

    // ========== 成员变量 ==========

    // UDP 服务发现
    QUdpSocket* m_udpSocket;           ///< UDP 套接字
    quint16 m_udpPort;                 ///< UDP 监听端口（默认 8600）

    // TCP + WebSocket
    WebSocketClient* m_wsClient;       ///< WebSocket 客户端
    QList<QString> m_serverIpList;     ///< 服务器 IP 列表（从 UDP JSON 解析）
    quint16 m_serverPort;              ///< 服务器端口
    int m_currentServerIndex;          ///< 当前尝试连接的服务器索引

    // ✅ 2026-01-22 17:15 [FIX 100.291] 缓存当前连接的服务器信息（用于重连检查）
    QString m_currentConnectedIp;      ///< 当前连接的服务器 IP
    quint16 m_currentConnectedPort;    ///< 当前连接的服务器端口

    // 心跳机制
    QTimer* m_pingTimer;               ///< PING 定时器（5 秒）
    QTimer* m_pongTimer;               ///< PONG 超时定时器（2 秒）

    // 设备信息
    DeviceInfo m_deviceInfo;           ///< 设备信息

    // Opus 播放状态
    QList<QByteArray> m_currentFrames; ///< 当前播放的 Opus 帧列表
    int m_currentFrameIndex;           ///< 当前发送帧索引
    int m_totalFrames;                 ///< 总帧数
    QTimer* m_frameTimer;              ///< 帧发送定时器（20ms）
    qint64 m_sendStartTime;            ///< 发送开始时间戳（绝对时间戳控制）
    bool m_isPlaying;                  ///< 是否正在播放

    // ✅ 2026-01-22 19:00 [FIX 100.292] Opus 帧缓存（性能优化）
    QHash<QString, QList<QByteArray>> m_opusCache;  ///< Opus 帧缓存（文件路径 → 帧列表）

    // ✅ 2026-01-22 20:40 [FIX 100.295] 独立发送线程（恶劣网络环境优化）
    QThread* m_senderThread;           ///< 独立发送线程
    AudioSenderWorker* m_senderWorker; ///< 音频发送工作对象（运行在独立线程）

    // 配置持久化
    QSettings* m_settings;             ///< QSettings 对象
};

#endif // AUDIONETWORKTCPSENDER_H
