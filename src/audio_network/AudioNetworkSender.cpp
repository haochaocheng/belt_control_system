// ========================================
// AudioNetworkSender.cpp
// ========================================
// 日期: 2026-01-21 19:45
// 作者: Claude AI
// 目的: 音频网络传输核心类实现
// 参考: docs/2026-01-21/12-音频网络传输实施计划-最终版.md
// ========================================

#include "AudioNetworkSender.h"

#include <QDebug>
#include <QFileInfo>
#include <QUrl>

#include <stdexcept>
#include <numeric>

// FFmpeg 头文件
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/opt.h>
#include <libswresample/swresample.h>
}

// Opus 头文件
#include <opus/opus.h>

// ========================================
// 构造函数
// ========================================

AudioNetworkSender::AudioNetworkSender(QObject *parent)
    : QObject(parent)
    , m_udpSocket(nullptr)
    , m_multicastAddress("224.1.1.1")  // 默认组播地址（音频模块预定义）
    , m_multicastPort(8800)            // 默认组播端口（音频模块预定义）
    , m_opusEncoder(nullptr)
    , m_opusBitrate(16000)             // 默认 16kbps（清晰）
    , m_currentFrameIndex(0)
    , m_frameTimer(nullptr)
    , m_isPlaying(false)
    , m_totalFrames(0)
{
    qDebug() << "[AudioNetworkSender] 初始化音频网络发送器";
    qDebug() << "   组播地址:" << m_multicastAddress.toString() << ":" << m_multicastPort;
    qDebug() << "   Opus 比特率:" << m_opusBitrate << "bps";

    // ========== 初始化 UDP Socket ==========
    m_udpSocket = new QUdpSocket(this);

    // 绑定到任意端口（用于发送）
    // 注意：发送方不需要加入组播组（joinMulticastGroup），只有接收方需要
    if (!m_udpSocket->bind(QHostAddress::AnyIPv4, 0, QUdpSocket::ShareAddress)) {
        qWarning() << "❌ UDP socket 绑定失败:" << m_udpSocket->errorString();
    } else {
        qDebug() << "   ✅ UDP socket 绑定成功";
    }

    // 设置组播 TTL（Time To Live）
    // TTL=1: 只在局域网内转发（推荐）
    // TTL=32: 可跨多个子网（如需要更大范围）
    m_udpSocket->setSocketOption(QAbstractSocket::MulticastTtlOption, 1);

    // ========== 初始化定时器 ==========
    m_frameTimer = new QTimer(this);
    m_frameTimer->setTimerType(Qt::PreciseTimer);  // 精确定时器（20ms 精度）
    connect(m_frameTimer, &QTimer::timeout, this, &AudioNetworkSender::onFrameTimerTimeout);

    qDebug() << "   ✅ 音频网络发送器初始化完成";
}

// ========================================
// 析构函数
// ========================================

AudioNetworkSender::~AudioNetworkSender()
{
    qDebug() << "[AudioNetworkSender] 销毁音频网络发送器";

    // 停止播放
    stopPlayback();

    // 销毁 Opus 编码器
    if (m_opusEncoder) {
        opus_encoder_destroy(m_opusEncoder);
        m_opusEncoder = nullptr;
        qDebug() << "   ✅ Opus 编码器已销毁";
    }
}

// ========================================
// 配置接口实现
// ========================================

void AudioNetworkSender::setUdpMulticastAddress(const QString& address, quint16 port)
{
    m_multicastAddress = QHostAddress(address);
    m_multicastPort = port;

    qDebug() << "[AudioNetworkSender] 设置组播地址:" << m_multicastAddress.toString() << ":" << m_multicastPort;
}

void AudioNetworkSender::setOpusBitrate(int bitrate)
{
    // 验证比特率范围
    if (bitrate < 16000 || bitrate > 32000) {
        qWarning() << "⚠️  Opus 比特率超出推荐范围（16000-32000），使用默认值 16000";
        bitrate = 16000;
    }

    m_opusBitrate = bitrate;

    // 如果编码器已初始化，更新比特率
    if (m_opusEncoder) {
        opus_encoder_ctl(m_opusEncoder, OPUS_SET_BITRATE(m_opusBitrate));
        qDebug() << "[AudioNetworkSender] 更新 Opus 比特率:" << m_opusBitrate;
    }
}

// ========================================
// 播放接口实现
// ========================================

void AudioNetworkSender::playAudioToNetwork(const QString& filePath)
{
    // 检查是否正在播放
    if (m_isPlaying) {
        qWarning() << "⚠️  正在播放，停止当前播放";
        stopPlayback();
    }

    // 记录播放开始时间
    m_playbackTimer.start();
    m_currentFileName = QFileInfo(filePath).fileName();

    qDebug() << "[AudioNetworkSender] 播放音频到网络:" << m_currentFileName;
    qDebug() << "   文件路径:" << filePath;

    try {
        // ========== 阶段 1：解码音频文件 ==========
        qDebug() << "   [1/3] 解码音频文件...";
        AudioData audio = decodeAudioFile(filePath);

        // ========== 阶段 2：编码为 Opus ==========
        qDebug() << "   [2/3] 编码为 Opus...";
        m_currentFrames = encodeToOpus(audio);

        if (m_currentFrames.isEmpty()) {
            emit playbackError("Opus 编码失败：未生成任何帧");
            return;
        }

        m_totalFrames = m_currentFrames.size();
        m_currentFrameIndex = 0;

        // ========== 阶段 3：开始发送 ==========
        qDebug() << "   [3/3] 开始发送 UDP 组播...";
        qDebug() << "   总帧数:" << m_totalFrames << "帧";
        qDebug() << "   预计时长:" << (m_totalFrames * 20) << "ms";
        qDebug() << "   目标地址:" << m_multicastAddress.toString() << ":" << m_multicastPort;

        emit playbackStarted(m_currentFileName);

        // 启动定时器（20ms 间隔）
        m_isPlaying = true;
        m_frameTimer->start(20);

        qDebug() << "   ✅ 发送已启动";

    } catch (const std::exception& e) {
        qWarning() << "❌ 播放失败:" << e.what();
        emit playbackError(QString::fromUtf8(e.what()));
    }
}

void AudioNetworkSender::stopPlayback()
{
    if (m_isPlaying) {
        m_frameTimer->stop();
        m_isPlaying = false;
        m_currentFrames.clear();
        m_currentFrameIndex = 0;

        qDebug() << "[AudioNetworkSender] 🛑 停止播放";
    }
}

bool AudioNetworkSender::isPlaying() const
{
    return m_isPlaying;
}

// ========================================
// 内部槽函数实现
// ========================================

void AudioNetworkSender::onFrameTimerTimeout()
{
    // 检查是否已播放完成
    if (!m_isPlaying || m_currentFrameIndex >= m_currentFrames.size()) {
        qDebug() << "   ✅ 所有帧发送完成，总耗时:" << m_playbackTimer.elapsed() << "ms";
        stopPlayback();
        emit playbackFinished();
        return;
    }

    // 发送下一帧
    sendNextFrame();
}

// ========================================
// 音频处理私有方法（待实现）
// ========================================

AudioNetworkSender::AudioData AudioNetworkSender::decodeAudioFile(const QString& filePath)
{
    // ✅ 2026-01-21 20:00 [阶段 1.2] 实现 FFmpeg 音频解码
    // 功能：解码 MP3/WAV 文件到 PCM (16kHz, 16bit, mono)
    // 参考：docs/2026-01-21/12-音频网络传输实施计划-最终版.md Line 188-294

    AudioData result;
    AVFormatContext* formatCtx = nullptr;
    AVCodecContext* codecCtx = nullptr;
    SwrContext* swrCtx = nullptr;
    AVPacket* packet = nullptr;
    AVFrame* frame = nullptr;

    try {
        // ========== 1. 打开音频文件 ==========
        QByteArray filePathUtf8 = filePath.toUtf8();
        if (avformat_open_input(&formatCtx, filePathUtf8.constData(), nullptr, nullptr) < 0) {
            throw std::runtime_error("Failed to open audio file: " + filePath.toStdString());
        }

        // ========== 2. 查找音频流 ==========
        if (avformat_find_stream_info(formatCtx, nullptr) < 0) {
            throw std::runtime_error("Failed to find stream info");
        }

        int audioStreamIndex = -1;
        for (unsigned i = 0; i < formatCtx->nb_streams; i++) {
            if (formatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
                audioStreamIndex = i;
                break;
            }
        }

        if (audioStreamIndex == -1) {
            throw std::runtime_error("No audio stream found");
        }

        // ========== 3. 初始化解码器 ==========
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

        qDebug() << "      原始音频格式:";
        qDebug() << "         采样率:" << codecCtx->sample_rate << "Hz";
        qDebug() << "         声道数:" << codecCtx->ch_layout.nb_channels;
        qDebug() << "         格式:" << av_get_sample_fmt_name(codecCtx->sample_fmt);

        // ========== 4. 初始化重采样器（统一转换为 16kHz, 16bit, mono）==========

        // 输入声道布局（兼容 FFmpeg 6.x ch_layout 和旧版 channel_layout）
        AVChannelLayout in_ch_layout = codecCtx->ch_layout;

        // 输出声道布局（单声道）
        AVChannelLayout out_ch_layout = AV_CHANNEL_LAYOUT_MONO;

        // 创建重采样器上下文
        if (swr_alloc_set_opts2(
                &swrCtx,
                &out_ch_layout,              // 输出：单声道
                AV_SAMPLE_FMT_S16,           // 输出：16bit PCM
                16000,                       // 输出：16kHz
                &in_ch_layout,               // 输入：原始声道
                codecCtx->sample_fmt,        // 输入：原始格式
                codecCtx->sample_rate,       // 输入：原始采样率
                0, nullptr) < 0) {
            throw std::runtime_error("Failed to allocate resampler");
        }

        if (swr_init(swrCtx) < 0) {
            throw std::runtime_error("Failed to initialize resampler");
        }

        qDebug() << "      目标音频格式:";
        qDebug() << "         采样率: 16000 Hz";
        qDebug() << "         声道数: 1 (mono)";
        qDebug() << "         格式: 16bit PCM";

        // ========== 5. 解码音频帧 ==========
        packet = av_packet_alloc();
        frame = av_frame_alloc();
        if (!packet || !frame) {
            throw std::runtime_error("Failed to allocate packet or frame");
        }

        QByteArray pcmBuffer;
        int frameCount = 0;

        while (av_read_frame(formatCtx, packet) >= 0) {
            if (packet->stream_index == audioStreamIndex) {
                if (avcodec_send_packet(codecCtx, packet) >= 0) {
                    while (avcodec_receive_frame(codecCtx, frame) >= 0) {
                        // 计算输出样本数（重采样后）
                        int outSamples = av_rescale_rnd(
                            swr_get_delay(swrCtx, codecCtx->sample_rate) + frame->nb_samples,
                            16000, codecCtx->sample_rate, AV_ROUND_UP
                        );

                        // 分配输出缓冲区
                        uint8_t* outBuffer = nullptr;
                        if (av_samples_alloc(&outBuffer, nullptr, 1, outSamples, AV_SAMPLE_FMT_S16, 0) < 0) {
                            qWarning() << "      ⚠️  Failed to allocate output buffer (frame" << frameCount << ")";
                            continue;
                        }

                        // 重采样
                        int convertedSamples = swr_convert(
                            swrCtx, &outBuffer, outSamples,
                            (const uint8_t**)frame->data, frame->nb_samples
                        );

                        if (convertedSamples > 0) {
                            // 追加到 PCM 缓冲区（每样本 2 字节 = 16bit）
                            pcmBuffer.append((const char*)outBuffer, convertedSamples * 2);
                            frameCount++;
                        }

                        av_freep(&outBuffer);
                    }
                }
            }
            av_packet_unref(packet);
        }

        // 刷新解码器（获取剩余帧）
        avcodec_send_packet(codecCtx, nullptr);
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
                    frameCount++;
                }

                av_freep(&outBuffer);
            }
        }

        // 刷新重采样器（获取剩余样本）
        uint8_t* outBuffer = nullptr;
        int outSamples = av_rescale_rnd(swr_get_delay(swrCtx, codecCtx->sample_rate), 16000, codecCtx->sample_rate, AV_ROUND_UP);
        if (outSamples > 0 && av_samples_alloc(&outBuffer, nullptr, 1, outSamples, AV_SAMPLE_FMT_S16, 0) >= 0) {
            int convertedSamples = swr_convert(swrCtx, &outBuffer, outSamples, nullptr, 0);
            if (convertedSamples > 0) {
                pcmBuffer.append((const char*)outBuffer, convertedSamples * 2);
            }
            av_freep(&outBuffer);
        }

        // ========== 6. 清理资源 ==========
        av_frame_free(&frame);
        av_packet_free(&packet);
        swr_free(&swrCtx);
        avcodec_free_context(&codecCtx);
        avformat_close_input(&formatCtx);

        // ========== 7. 返回结果 ==========
        result.pcmData = pcmBuffer;
        result.sampleRate = 16000;
        result.channels = 1;
        result.durationMs = (pcmBuffer.size() / 2) * 1000 / 16000;  // 样本数 × 1000 / 采样率

        qDebug() << "      ✅ 音频解码完成";
        qDebug() << "         PCM 大小:" << pcmBuffer.size() << "字节";
        qDebug() << "         解码帧数:" << frameCount << "帧";
        qDebug() << "         音频时长:" << result.durationMs << "ms";

        return result;

    } catch (...) {
        // 异常时清理资源
        if (frame) av_frame_free(&frame);
        if (packet) av_packet_free(&packet);
        if (swrCtx) swr_free(&swrCtx);
        if (codecCtx) avcodec_free_context(&codecCtx);
        if (formatCtx) avformat_close_input(&formatCtx);
        throw;  // 重新抛出异常
    }
}

QList<QByteArray> AudioNetworkSender::encodeToOpus(const AudioData& audio)
{
    // ✅ 2026-01-21 20:05 [阶段 1.3] 实现 Opus 编码
    // 功能：PCM (16kHz, 16bit, mono) → Opus 帧 (20ms, 16-32kbps)
    // 参考：docs/2026-01-21/12-音频网络传输实施计划-最终版.md Line 306-388

    QList<QByteArray> opusFrames;

    // ========== 1. 检查音频参数 ==========
    if (audio.sampleRate != 16000 || audio.channels != 1) {
        qWarning() << "❌ 音频参数错误，必须是 16kHz 单声道";
        qWarning() << "   实际参数：采样率" << audio.sampleRate << "Hz，声道数" << audio.channels;
        return opusFrames;
    }

    // ========== 2. 初始化 Opus 编码器（如果还没初始化）==========
    if (!m_opusEncoder) {
        int error;
        m_opusEncoder = opus_encoder_create(
            16000,                      // 采样率 16kHz
            1,                          // 单声道
            OPUS_APPLICATION_VOIP,      // 语音模式（低延迟）
            &error
        );

        if (error != OPUS_OK || !m_opusEncoder) {
            qWarning() << "❌ Opus 编码器初始化失败:" << opus_strerror(error);
            return opusFrames;
        }

        // 设置比特率
        opus_encoder_ctl(m_opusEncoder, OPUS_SET_BITRATE(m_opusBitrate));

        qDebug() << "      ✅ Opus 编码器初始化成功";
        qDebug() << "         比特率:" << m_opusBitrate << "bps";
        qDebug() << "         模式: OPUS_APPLICATION_VOIP (低延迟)";
    }

    // ========== 3. 将 PCM 数据切分为 20ms 帧 ==========
    const int samplesPerFrame = 320;        // 20ms @ 16kHz = 320 样本
    const int bytesPerFrame = samplesPerFrame * 2;  // 2 字节/样本（16bit）

    const char* pcmPtr = audio.pcmData.constData();
    int pcmSize = audio.pcmData.size();
    int frameCount = pcmSize / bytesPerFrame;

    qDebug() << "      📦 开始 Opus 编码";
    qDebug() << "         PCM 数据大小:" << pcmSize << "字节";
    qDebug() << "         预计帧数:" << frameCount << "帧（每帧 20ms）";

    // ========== 4. 逐帧编码 ==========
    for (int i = 0; i < frameCount; i++) {
        // 获取当前帧的 PCM 数据（opus_int16 = int16_t）
        const opus_int16* pcmFrame = reinterpret_cast<const opus_int16*>(pcmPtr + i * bytesPerFrame);

        // 准备 Opus 输出缓冲区
        // 根据 Opus 文档，最大帧大小约 1275 字节（保守估计 256 字节足够）
        unsigned char opusBuffer[256];

        // 编码单个帧
        int encodedBytes = opus_encode(
            m_opusEncoder,
            pcmFrame,
            samplesPerFrame,
            opusBuffer,
            sizeof(opusBuffer)
        );

        if (encodedBytes < 0) {
            qWarning() << "      ❌ Opus 编码失败，帧" << i << ":" << opus_strerror(encodedBytes);
            continue;
        }

        // 保存 Opus 帧
        QByteArray opusFrame(reinterpret_cast<const char*>(opusBuffer), encodedBytes);
        opusFrames.append(opusFrame);

        // 日志（每 50 帧打印一次，即每秒）
        if (i % 50 == 0 && i > 0) {
            qDebug() << "         已编码:" << i << "/" << frameCount << "帧";
        }
    }

    // ========== 5. 统计信息 ==========
    if (opusFrames.isEmpty()) {
        qWarning() << "      ❌ Opus 编码失败：未生成任何帧";
        return opusFrames;
    }

    // 计算平均帧大小
    int totalBytes = 0;
    for (const QByteArray& frame : opusFrames) {
        totalBytes += frame.size();
    }
    int avgFrameSize = totalBytes / opusFrames.size();

    qDebug() << "      ✅ Opus 编码完成";
    qDebug() << "         总帧数:" << opusFrames.size() << "帧";
    qDebug() << "         总大小:" << totalBytes << "字节";
    qDebug() << "         平均帧大小:" << avgFrameSize << "字节/帧";
    qDebug() << "         预计比特率:" << (avgFrameSize * 8 * 50) << "bps（每秒 50 帧）";

    return opusFrames;
}

// ========================================
// 网络发送私有方法实现
// ========================================

void AudioNetworkSender::sendOpusFrames(const QList<QByteArray>& frames)
{
    // ⏳ TODO: 阶段 1.4 - 实现批量发送逻辑（如需要）
    // 当前使用定时器逐帧发送（简单模式）

    qDebug() << "   [sendOpusFrames] 准备发送" << frames.size() << "帧";
}

void AudioNetworkSender::sendNextFrame()
{
    const QByteArray& opusFrame = m_currentFrames[m_currentFrameIndex];

    // 发送 UDP 组播
    qint64 bytesSent = m_udpSocket->writeDatagram(
        opusFrame.constData(),
        opusFrame.size(),
        m_multicastAddress,
        m_multicastPort
    );

    if (bytesSent < 0) {
        qWarning() << "❌ UDP 发送失败（帧" << m_currentFrameIndex << "）:" << m_udpSocket->errorString();
        emit networkError(m_udpSocket->errorString());
    } else {
        // 日志（每 50 帧打印一次，即每秒）
        if (m_currentFrameIndex % 50 == 0) {
            qDebug() << "   📡 已发送:" << m_currentFrameIndex << "/" << m_totalFrames
                     << "帧（" << m_playbackTimer.elapsed() << "ms）";
        }
    }

    // 更新索引和进度
    m_currentFrameIndex++;
    emit playbackProgress(m_currentFrameIndex, m_totalFrames);
}
