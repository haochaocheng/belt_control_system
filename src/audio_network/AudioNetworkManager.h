// ========================================
// AudioNetworkManager.h
// ========================================
// 日期: 2026-01-22 22:40
// 作者: Claude AI
// 目的: 音频网络传输管理器 - TCP/UDP 自动切换
// 参考: docs/2026-01-22/31-TCP-UDP自动切换架构设计.md
//
// 功能：
// 1. 统一的音频网络传输接口
// 2. TCP 优先,失败自动降级到 UDP
// 3. 透明切换,上层无感知
// 4. 支持强制模式(仅 TCP 或仅 UDP)
//
// 架构：适配器模式 + 状态机
// - 内部持有 AudioNetworkTcpSender 和 AudioNetworkSender
// - 提供统一接口给上层(CommonControl)
// - 自动检测 TCP 失败并降级到 UDP
// ========================================

#ifndef AUDIONETWORKMANAGER_H
#define AUDIONETWORKMANAGER_H

#include <QObject>
#include <QString>
#include <QTimer>
#include "AudioNetworkTcpSender.h"
#include "AudioNetworkSender.h"

/**
 * @brief 音频网络传输管理器
 *
 * 核心功能：
 * - TCP/UDP 自动切换（TCP 优先,失败降级）
 * - 统一的播放接口（上层无需关心底层协议）
 * - 失败检测机制（连接超时、心跳超时、发送错误）
 * - 可选的自动恢复机制（TCP 恢复后可切回）
 *
 * 使用示例：
 * @code
 * AudioNetworkManager* mgr = new AudioNetworkManager(this);
 * mgr->setTransmissionMode(AudioNetworkManager::AUTO_MODE);  // 自动模式
 * mgr->setDeviceInfo(deviceInfo);  // 设置设备信息(用于 TCP)
 * mgr->playAudioToNetwork("/app/audio/alarm.mp3");  // 自动选择 TCP/UDP
 * @endcode
 */
class AudioNetworkManager : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief 传输模式枚举
     */
    enum TransmissionMode {
        TCP_MODE,      ///< TCP 模式（强制使用 TCP,失败报错）
        UDP_MODE,      ///< UDP 模式（强制使用 UDP）
        AUTO_MODE      ///< 自动模式（TCP 优先,失败降级到 UDP,默认）
    };
    Q_ENUM(TransmissionMode)

    /**
     * @brief 构造函数
     * @param parent 父对象
     */
    explicit AudioNetworkManager(QObject *parent = nullptr);

    /**
     * @brief 析构函数
     */
    ~AudioNetworkManager();

    // ========== 配置接口 ==========

    /**
     * @brief 设置传输模式
     * @param mode 传输模式
     *
     * - TCP_MODE:  强制使用 TCP（不降级,失败直接报错）
     * - UDP_MODE:  强制使用 UDP（简单可靠）
     * - AUTO_MODE: 自动切换（默认,推荐）
     *
     * 默认：AUTO_MODE
     */
    void setTransmissionMode(TransmissionMode mode);

    /**
     * @brief 获取用户配置的模式
     * @return 用户配置的模式
     */
    TransmissionMode getConfiguredMode() const;

    /**
     * @brief 获取当前实际使用的模式
     * @return 当前使用的模式
     *
     * 注意：
     * - AUTO_MODE 下,实际模式可能是 TCP_MODE 或 UDP_MODE
     * - 例如：配置 AUTO_MODE,TCP 失败后实际使用 UDP_MODE
     */
    TransmissionMode getCurrentMode() const;

    /**
     * @brief 设置 TCP 连接超时时间
     * @param seconds 超时秒数（默认 5 秒）
     *
     * 超时后自动降级到 UDP（仅 AUTO_MODE 下生效）
     */
    void setTcpConnectionTimeout(int seconds);

    /**
     * @brief 设置是否启用自动恢复 TCP
     * @param enable true=TCP 恢复后自动切回,false=保持 UDP
     *
     * 默认：false（不自动切回,避免频繁切换）
     *
     * 注意：
     * - 启用后,会定期检查 TCP 是否恢复（每 30 秒）
     * - 仅在空闲时切回（不在播放中切换）
     */
    void setAutoRecoveryEnabled(bool enable);

    /**
     * @brief 设置设备信息（用于 TCP 模式）
     * @param info 设备信息
     *
     * 注意：
     * - TCP 模式需要设备信息发送到服务器
     * - UDP 模式不需要设备信息
     */
    void setDeviceInfo(const AudioNetworkTcpSender::DeviceInfo& info);

    // ========== 播放接口（统一）==========

    /**
     * @brief 播放音频到网络
     * @param filePath 音频文件路径（MP3、WAV 等）
     *
     * 工作流程：
     * 1. 根据当前模式选择 TCP 或 UDP
     * 2. 如果 TCP 失败且配置为 AUTO_MODE,自动降级到 UDP
     * 3. 解码音频文件 → Opus 编码 → 网络发送
     * 4. 发送完成触发 playbackFinished() 信号
     */
    void playAudioToNetwork(const QString& filePath);

    /**
     * @brief 停止播放
     *
     * 停止当前活动的发送器（TCP 或 UDP）
     */
    void stopPlayback();

    /**
     * @brief 查询是否正在播放
     * @return true=正在播放,false=空闲
     */
    bool isPlaying() const;

signals:
    // ========== 模式切换信号 ==========

    /**
     * @brief 模式切换信号
     * @param from 切换前的模式
     * @param to 切换后的模式
     * @param reason 切换原因
     *
     * 场景：
     * - TCP 连接失败 → UDP
     * - TCP 心跳超时 → UDP
     * - TCP 恢复 → TCP（可选,需启用自动恢复）
     */
    void modeChanged(TransmissionMode from, TransmissionMode to, const QString& reason);

    // ========== 播放信号（统一）==========

    /**
     * @brief 播放开始信号
     * @param fileName 文件名（不含路径）
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
    // ========== TCP 模式槽函数（失败检测）==========

    /**
     * @brief TCP UDP 服务发现失败槽函数
     * @param error 错误描述
     *
     * 触发条件：5 秒内未发现 UDP 广播
     * 处理：AUTO_MODE 下自动降级到 UDP
     */
    void onTcpDiscoveryFailed(const QString& error);

    /**
     * @brief TCP 连接成功槽函数
     *
     * 标记 TCP 曾经连接成功（用于自动恢复判断）
     */
    void onTcpConnected();

    /**
     * @brief WebSocket 握手完成槽函数
     *
     * 停止连接超时定时器
     */
    void onWebSocketReady();

    /**
     * @brief TCP 连接断开槽函数
     *
     * 可能原因：网络中断、服务器关闭
     * 处理：AUTO_MODE 下自动降级到 UDP
     */
    void onTcpDisconnected();

    /**
     * @brief TCP 连接错误槽函数
     * @param error 错误描述
     *
     * 处理：AUTO_MODE 下自动降级到 UDP
     */
    void onTcpError(const QString& error);

    /**
     * @brief TCP 心跳超时槽函数
     *
     * 触发条件：2 秒内未收到 PONG
     * 处理：AUTO_MODE 下自动降级到 UDP
     */
    void onHeartbeatTimeout();

    // ========== 播放状态转发槽函数 ==========

    /**
     * @brief 播放开始槽函数（转发）
     * @param fileName 文件名
     */
    void onPlaybackStarted(const QString& fileName);

    /**
     * @brief 播放进度槽函数（转发）
     * @param framesSent 已发送帧数
     * @param totalFrames 总帧数
     */
    void onPlaybackProgress(int framesSent, int totalFrames);

    /**
     * @brief 播放完成槽函数（转发）
     */
    void onPlaybackFinished();

    /**
     * @brief 播放错误槽函数（转发）
     * @param error 错误描述
     */
    void onPlaybackError(const QString& error);

    // ========== 超时检测槽函数 ==========

    /**
     * @brief TCP 连接超时槽函数
     *
     * 触发条件：5 秒内未完成连接
     * 处理：AUTO_MODE 下自动降级到 UDP
     */
    void onConnectionTimeout();

private:
    // ========== 模式切换逻辑 ==========

    /**
     * @brief 切换到 TCP 模式
     *
     * 工作流程：
     * 1. 断开 UDP 信号
     * 2. 连接 TCP 信号
     * 3. 更新当前模式
     * 4. 触发 modeChanged 信号
     */
    void switchToTcpMode();

    /**
     * @brief 切换到 UDP 模式
     * @param reason 切换原因
     *
     * 工作流程：
     * 1. 断开 TCP 信号
     * 2. 连接 UDP 信号
     * 3. 停止 TCP 发送器
     * 4. 更新当前模式
     * 5. 触发 modeChanged 信号
     *
     * 如果正在播放：
     * - 保存当前文件路径
     * - 停止 TCP 播放
     * - 使用 UDP 重新播放
     */
    void switchToUdpMode(const QString& reason);

    /**
     * @brief 检查是否可以切回 TCP
     * @return true=可以尝试切回,false=不可以
     *
     * 条件：
     * - 启用了自动恢复
     * - 当前是 UDP 模式
     * - 不在播放中（避免中断）
     * - TCP 曾经连接成功
     */
    bool canRecoverToTcp() const;

    /**
     * @brief 连接 TCP 信号
     *
     * 连接所有 TCP 相关信号到槽函数
     */
    void connectTcpSignals();

    /**
     * @brief 断开 TCP 信号
     *
     * 断开所有 TCP 信号连接
     */
    void disconnectTcpSignals();

    /**
     * @brief 连接 UDP 信号
     *
     * 连接所有 UDP 相关信号到槽函数
     */
    void connectUdpSignals();

    /**
     * @brief 断开 UDP 信号
     *
     * 断开所有 UDP 信号连接
     */
    void disconnectUdpSignals();

    // ========== 成员变量 ==========

    // 两个发送器实例
    AudioNetworkTcpSender* m_tcpSender;  ///< TCP 发送器
    AudioNetworkSender* m_udpSender;     ///< UDP 发送器

    // 状态管理
    TransmissionMode m_configuredMode;   ///< 用户配置的模式（AUTO/TCP/UDP）
    TransmissionMode m_currentMode;      ///< 当前实际使用的模式
    bool m_autoRecoveryEnabled;          ///< 是否启用自动恢复

    // TCP 连接状态
    QTimer* m_connectionTimer;           ///< 连接超时定时器（5 秒）
    int m_connectionTimeoutSeconds;      ///< 连接超时秒数（默认 5）
    bool m_tcpEverConnected;             ///< TCP 是否曾经连接成功

    // 播放状态
    QString m_lastPlayedFile;            ///< 最后播放的文件路径（用于切换时重播）
};

#endif // AUDIONETWORKMANAGER_H
