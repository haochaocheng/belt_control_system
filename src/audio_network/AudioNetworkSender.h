// ========================================
// AudioNetworkSender.h
// ========================================
// 日期: 2026-01-21 19:45
// 作者: Claude AI
// 目的: 音频网络传输核心类 - UDP 组播 Opus 音频发送
// 参考: docs/2026-01-21/12-音频网络传输实施计划-最终版.md
//
// 功能：
// 1. 解码 MP3/WAV 文件到 PCM (16kHz, 16bit, mono)
// 2. 编码 PCM 到 Opus (20ms 帧, 16-32kbps)
// 3. UDP 组播发送到音频模块 (224.1.1.1:8800)
//
// 网络参数（音频模块预定义，不可更改）：
// - 组播地址: 224.1.1.1
// - 组播端口: 8800
// - 组播 MAC: {0x01,0x00,0x5e,0x01,0x01,0x01}
// - 数据格式: 纯 Opus 帧（无协议头）
// ========================================

#ifndef AUDIONETWORKSENDER_H
#define AUDIONETWORKSENDER_H

#include <QObject>
#include <QByteArray>
#include <QList>
#include <QString>
#include <QUdpSocket>
#include <QHostAddress>
#include <QTimer>
#include <QElapsedTimer>

// FFmpeg 前置声明（避免头文件污染）
struct AVFormatContext;
struct AVCodecContext;
struct SwrContext;

// Opus 前置声明
struct OpusEncoder;

class AudioNetworkSender : public QObject
{
    Q_OBJECT

public:
    // ========== 构造/析构 ==========
    explicit AudioNetworkSender(QObject *parent = nullptr);
    ~AudioNetworkSender();

    // ========== 配置接口 ==========

    /**
     * @brief 设置 UDP 组播地址和端口
     * @param address 组播地址（默认：224.1.1.1）
     * @param port 组播端口（默认：8800）
     *
     * 注意：音频模块预定义参数，通常不需要修改
     */
    void setUdpMulticastAddress(const QString& address, quint16 port);

    /**
     * @brief 设置 Opus 编码比特率
     * @param bitrate 比特率（16000-32000）
     *                16000 = 清晰（推荐）
     *                24000 = 良好
     *                32000 = 高质量
     *
     * 注意：比特率越高，音质越好但带宽占用越大
     */
    void setOpusBitrate(int bitrate);

    // ========== 播放接口 ==========

    /**
     * @brief 播放音频到网络
     * @param filePath 音频文件路径（支持 MP3、WAV）
     *
     * 流程：
     * 1. 解码音频文件 → PCM (16kHz, 16bit, mono)
     * 2. 编码 PCM → Opus (20ms 帧)
     * 3. 启动 20ms 定时器，逐帧发送到 UDP 组播
     *
     * 发送完成后触发 playbackFinished() 信号
     * 发送错误时触发 playbackError() 信号
     */
    void playAudioToNetwork(const QString& filePath);

    /**
     * @brief 停止当前播放
     *
     * 停止定时器，清空帧缓冲，重置播放状态
     */
    void stopPlayback();

    /**
     * @brief 查询是否正在播放
     * @return true 正在发送音频帧，false 空闲
     */
    bool isPlaying() const;

signals:
    // ========== 播放状态信号 ==========

    /**
     * @brief 播放开始信号
     * @param fileName 文件名（不含路径）
     *
     * 在成功解码和编码音频，准备发送第一帧时触发
     */
    void playbackStarted(const QString& fileName);

    /**
     * @brief 播放进度信号
     * @param framesSent 已发送帧数
     * @param totalFrames 总帧数
     *
     * 每次发送帧后触发（可用于进度条显示）
     */
    void playbackProgress(int framesSent, int totalFrames);

    /**
     * @brief 播放完成信号
     *
     * 所有帧发送完成后触发
     */
    void playbackFinished();

    /**
     * @brief 播放错误信号
     * @param error 错误描述
     *
     * 解码失败、编码失败时触发
     */
    void playbackError(const QString& error);

    /**
     * @brief 网络错误信号
     * @param error 错误描述
     *
     * UDP 发送失败时触发（如网络不可达）
     */
    void networkError(const QString& error);

private slots:
    // ========== 内部槽函数 ==========

    /**
     * @brief 定时器超时槽函数（每 20ms 触发）
     *
     * 发送下一帧 Opus 数据到 UDP 组播
     * 所有帧发送完成后停止定时器并触发 playbackFinished()
     */
    void onFrameTimerTimeout();

private:
    // ========== 音频处理私有方法 ==========

    /**
     * @brief 音频数据结构（内部使用）
     */
    struct AudioData {
        QByteArray pcmData;      ///< PCM 数据（16kHz, 16bit, mono）
        int sampleRate;          ///< 实际采样率（应为 16000）
        int channels;            ///< 实际声道数（应为 1）
        qint64 durationMs;       ///< 音频时长（毫秒）
    };

    /**
     * @brief 解码音频文件到 PCM
     * @param filePath 音频文件路径
     * @return AudioData 结构（包含 PCM 数据）
     * @throws std::runtime_error 解码失败时抛出异常
     *
     * 使用 FFmpeg 解码，支持：
     * - 所有 FFmpeg 支持的格式（MP3, WAV, OGG 等）
     * - 自动重采样到 16kHz
     * - 自动转换为单声道
     * - 自动转换为 16bit PCM
     */
    AudioData decodeAudioFile(const QString& filePath);

    /**
     * @brief 编码 PCM 到 Opus 帧列表
     * @param audio 音频数据（必须是 16kHz, 16bit, mono）
     * @return Opus 帧列表（每帧 20ms，约 40 字节 @ 16kbps）
     *
     * 将 PCM 数据切分为 20ms 帧（320 样本），逐帧编码为 Opus
     * 编码失败的帧会跳过并记录警告日志
     */
    QList<QByteArray> encodeToOpus(const AudioData& audio);

    // ========== 网络发送私有方法 ==========

    /**
     * @brief 启动帧发送流程
     * @param frames Opus 帧列表
     *
     * 保存帧列表到成员变量，启动 20ms 定时器
     */
    void sendOpusFrames(const QList<QByteArray>& frames);

    /**
     * @brief 发送下一帧
     *
     * 从帧列表中取出下一帧，通过 UDP 组播发送
     * 更新帧索引，触发进度信号
     */
    void sendNextFrame();

    // ========== 成员变量 ==========

    // --- 网络 ---
    QUdpSocket* m_udpSocket;           ///< UDP socket
    QHostAddress m_multicastAddress;   ///< 组播地址（224.1.1.1）
    quint16 m_multicastPort;           ///< 组播端口（8800）

    // --- Opus 编码器 ---
    OpusEncoder* m_opusEncoder;        ///< Opus 编码器实例
    int m_opusBitrate;                 ///< Opus 比特率（16000-32000）

    // --- 播放状态 ---
    QList<QByteArray> m_currentFrames; ///< 当前播放的 Opus 帧列表
    int m_currentFrameIndex;           ///< 当前发送到第几帧（0-based）
    QTimer* m_frameTimer;              ///< 20ms 定时器（50 帧/秒）
    bool m_isPlaying;                  ///< 是否正在播放

    // --- 统计信息 ---
    QString m_currentFileName;         ///< 当前播放文件名
    int m_totalFrames;                 ///< 总帧数
    QElapsedTimer m_playbackTimer;     ///< 播放计时器（用于日志）
};

#endif // AUDIONETWORKSENDER_H
