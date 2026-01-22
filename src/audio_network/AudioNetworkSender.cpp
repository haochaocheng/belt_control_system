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
#include <QNetworkInterface>  // ✅ 2026-01-22 11:00 [动态计算] 获取本地 IP 地址

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
    // ❌ 2026-01-22 11:00 [旧代码] 硬编码组播地址（错误）
    // , m_multicastAddress("224.1.1.1")
    // ✅ 2026-01-22 11:00 [动态计算] 根据本地 IP 计算组播地址
    , m_multicastAddress()  // 稍后在构造函数体中计算
    , m_multicastPort(8800)            // 默认组播端口（音频模块预定义）
    , m_opusEncoder(nullptr)
    , m_opusBitrate(16000)             // 默认 16kbps（清晰）
    , m_currentFrameIndex(0)
    , m_frameTimer(nullptr)
    , m_isPlaying(false)
    , m_totalFrames(0)
    , m_sendStartTime(0)               // ✅ 2026-01-22 14:30 [绝对时间戳控制] 初始化发送开始时间
{
    // ========== 动态计算组播地址 ==========
    // ✅ 2026-01-22 11:00 [动态计算] 根据本地 IP 的第3字节计算组播地址
    // 音频模块计算规则：DIP[2] = tnet->ConfigMsg.lip[2]
    // 组播地址格式：224.1.{IP[2]}.1

    // 1. 获取本地 IP 地址
    QHostAddress localIP = getLocalIPAddress();

    // 2. 提取第3字节（IP[2]）
    quint32 ipv4 = localIP.toIPv4Address();
    quint8 thirdByte = (ipv4 >> 8) & 0xFF;  // 右移8位，掩码0xFF得到第3字节

    // 3. 计算组播地址：224.1.{IP[2]}.1
    QString multicastAddr = QString("224.1.%1.1").arg(thirdByte);
    m_multicastAddress = QHostAddress(multicastAddr);

    qDebug() << "[AudioNetworkSender] 初始化音频网络发送器";
    qDebug() << "   本地 IP:" << localIP.toString();
    qDebug() << "   第3字节（IP[2]）:" << thirdByte;
    qDebug() << "   组播地址（动态计算）:" << m_multicastAddress.toString() << ":" << m_multicastPort;
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

        // ✅ 2026-01-22 14:30 [绝对时间戳控制] 记录发送开始时间，改用 singleShot
        m_isPlaying = true;
        m_sendStartTime = m_playbackTimer.elapsed();  // 记录发送开始的绝对时间

        // 立即发送第一帧（不等待定时器）
        sendNextFrame();

        qDebug() << "   ✅ 发送已启动（绝对时间戳控制模式）";

    } catch (const std::exception& e) {
        qWarning() << "❌ 播放失败:" << e.what();
        emit playbackError(QString::fromUtf8(e.what()));
    }
}

void AudioNetworkSender::stopPlayback()
{
    if (m_isPlaying) {
        // ❌ 2026-01-22 14:30 [已废弃] 不再使用周期性定时器，无需 stop()
        // m_frameTimer->stop();
        // ✅ 2026-01-22 14:30 [绝对时间戳控制] 只需设置状态，singleShot 会自动停止
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
    // ❌ 2026-01-22 14:30 [已废弃] 不再使用此函数，改用 sendNextFrame() 递归调用
    // 保留此函数仅为兼容性，实际不会被调用
    qWarning() << "⚠️ onFrameTimerTimeout() 被调用（此函数已废弃，不应被调用）";

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
    // ❌ 2026-01-22 08:00 [诊断代码] 函数入口版本标记（改用 fprintf 确保输出）
    // 原因：av_log(nullptr, ...) 可能被过滤，改用 fprintf(stderr, ...)
    fprintf(stderr, "\n");
    fprintf(stderr, "╔═════════════════════════════════════════════════════════════════════╗\n");
    fprintf(stderr, "║ [APP-VERSION-CHECK] decodeAudioFile() 函数入口                     ║\n");
    fprintf(stderr, "║ 代码版本: 2026-01-22-08:00-ENTRY-v2                                ║\n");
    fprintf(stderr, "║ 文件: %-60s║\n", qPrintable(filePath));
    fprintf(stderr, "╚═════════════════════════════════════════════════════════════════════╝\n");
    fprintf(stderr, "\n");
    fflush(stderr);

    // ✅ 2026-01-21 20:00 [阶段 1.2] 实现 FFmpeg 音频解码
    // 功能：解码 MP3/WAV 文件到 PCM (16kHz, 16bit, mono)
    // 参考：docs/2026-01-21/12-音频网络传输实施计划-最终版.md Line 188-294

    AudioData result;
    AVFormatContext* formatCtx = nullptr;
    AVCodecContext* codecCtx = nullptr;
    SwrContext* swrCtx = nullptr;
    AVPacket* packet = nullptr;
    AVFrame* frame = nullptr;
    // ❌ 2026-01-22 10:30 [FFmpeg 6.0 清理] 移除 using_legacy_api 标志（不再需要）
    // bool using_legacy_api = false;

    try {
        // ❌ 2026-01-22 08:30 [密集诊断] 定位 Line 230-279 崩溃点
        fprintf(stderr, "[TRACE] Step 1: 准备打开音频文件...\n");
        fflush(stderr);

        // ========== 1. 打开音频文件 ==========
        QByteArray filePathUtf8 = filePath.toUtf8();

        fprintf(stderr, "[TRACE] Step 2: 调用 avformat_open_input...\n");
        fflush(stderr);

        if (avformat_open_input(&formatCtx, filePathUtf8.constData(), nullptr, nullptr) < 0) {
            throw std::runtime_error("Failed to open audio file: " + filePath.toStdString());
        }

        fprintf(stderr, "[TRACE] Step 3: 音频文件打开成功，查找流信息...\n");
        fflush(stderr);

        // ========== 2. 查找音频流 ==========
        if (avformat_find_stream_info(formatCtx, nullptr) < 0) {
            throw std::runtime_error("Failed to find stream info");
        }

        fprintf(stderr, "[TRACE] Step 4: 流信息查找成功，查找音频流索引...\n");
        fflush(stderr);

        // ❌ 2026-01-22 08:50 [详细诊断 v2] 定位音频流搜索循环崩溃点
        fprintf(stderr, "\n╔════════════════════════════════════════════════╗\n");
        fprintf(stderr, "║ [CRASH-DEBUG] 检查 formatCtx 结构           ║\n");
        fprintf(stderr, "╠════════════════════════════════════════════════╣\n");
        fprintf(stderr, "║  formatCtx 指针: %p                    ║\n", (void*)formatCtx);
        fprintf(stderr, "║  nb_streams: %u                                ║\n", formatCtx->nb_streams);
        fprintf(stderr, "║  streams 数组指针: %p                  ║\n", (void*)formatCtx->streams);
        fprintf(stderr, "╚════════════════════════════════════════════════╝\n");
        fflush(stderr);

        int audioStreamIndex = -1;
        for (unsigned i = 0; i < formatCtx->nb_streams; i++) {
            // ❌ 2026-01-22 08:50 [详细诊断 v2] 每次循环检查指针
            fprintf(stderr, "[TRACE] Step 4.%u: 检查流 %u/%u...\n", i+1, i, formatCtx->nb_streams);
            fprintf(stderr, "   streams[%u] 指针: %p\n", i, (void*)formatCtx->streams[i]);
            fflush(stderr);

            if (!formatCtx->streams[i]) {
                fprintf(stderr, "   ❌ streams[%u] is NULL! 跳过\n", i);
                fflush(stderr);
                continue;
            }

            fprintf(stderr, "   codecpar 指针: %p\n", (void*)formatCtx->streams[i]->codecpar);
            fflush(stderr);

            // ✅ 2026-01-22 10:10 [FFmpeg 6.0 修复完成] 头文件已正确更新到 v60
            // rk3588-libs/include 的 FFmpeg 头文件已从 v58 更新到 v60
            // codecpar 指针现在有效，不再需要 legacy API 回退

            AVCodecParameters* codecpar = formatCtx->streams[i]->codecpar;

            if (!codecpar) {
                fprintf(stderr, "   ❌ codecpar is NULL! 跳过此流\n");
                fflush(stderr);
                continue;
            }

            fprintf(stderr, "   codec_type: %d (AUDIO=%d)\n",
                    codecpar->codec_type, AVMEDIA_TYPE_AUDIO);
            fflush(stderr);

            if (codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
                audioStreamIndex = i;
                fprintf(stderr, "   ✅ 找到音频流: index=%d\n", i);
                fflush(stderr);
                break;
            }
        }

        fprintf(stderr, "\n[TRACE] Step 4 循环完成，audioStreamIndex = %d\n", audioStreamIndex);
        fflush(stderr);

        if (audioStreamIndex == -1) {
            throw std::runtime_error("No audio stream found");
        }

        fprintf(stderr, "[TRACE] Step 5: 找到音频流 %d，初始化解码器...\n", audioStreamIndex);
        fflush(stderr);

        // ========== 3. 初始化解码器 ==========
        // ✅ 2026-01-22 10:30 [FFmpeg 6.0 清理] 移除旧版 API 回退，只使用 codecpar
        // rk3588-libs/include 头文件已更新为 v60，codecpar 现在有效
        AVCodecParameters* codecParams = formatCtx->streams[audioStreamIndex]->codecpar;
        if (!codecParams) {
            throw std::runtime_error("codecParams is NULL");
        }

        fprintf(stderr, "[TRACE] Step 6: 查找解码器...\n");
        fprintf(stderr, "   使用 API: 新版 (codecpar)\n");
        fflush(stderr);

        const AVCodec* codec = avcodec_find_decoder(codecParams->codec_id);
        if (!codec) {
            throw std::runtime_error("Codec not found");
        }

        fprintf(stderr, "[TRACE] Step 7: 找到解码器 %s，分配上下文...\n", codec->name);
        fflush(stderr);

        codecCtx = avcodec_alloc_context3(codec);
        if (!codecCtx) {
            throw std::runtime_error("Failed to allocate codec context");
        }

        fprintf(stderr, "[TRACE] Step 8: 上下文分配成功，复制参数...\n");
        fflush(stderr);

        if (avcodec_parameters_to_context(codecCtx, codecParams) < 0) {
            throw std::runtime_error("Failed to copy codec parameters");
        }

        fprintf(stderr, "[TRACE] Step 9: 参数复制成功，准备调用 avcodec_open2...\n");
        fflush(stderr);

        // ❌ 2026-01-22 08:10 [紧急修复 v5] 完全改用 fprintf(stderr, ...)
        // 原因：av_log(codecCtx, ...) 仍然不显示（voip.md 实测证明）
        // 结论：只有 fprintf(stderr, ...) + fflush() 可靠输出应用层日志
        fprintf(stderr, "\n╔═══════════════════════════════════════════════════════════════╗\n");
        fprintf(stderr, "║ [APP-TRACE] avcodec_open2() 调用前 - VERSION 2026-01-22-08:10 ║\n");
        fprintf(stderr, "╠═══════════════════════════════════════════════════════════════╣\n");
        fprintf(stderr, "║   codecCtx 指针: %p                                          ║\n", (void*)codecCtx);
        fprintf(stderr, "║   codec 指针: %p                                             ║\n", (void*)codec);
        fprintf(stderr, "║   codec->name: %s                                              ║\n", codec->name);
        fprintf(stderr, "╚═══════════════════════════════════════════════════════════════╝\n");
        fflush(stderr);

        int openResult = avcodec_open2(codecCtx, codec, nullptr);

        fprintf(stderr, "\n╔═══════════════════════════════════════════════════════════════╗\n");
        fprintf(stderr, "║ [APP-TRACE] avcodec_open2() 调用后                            ║\n");
        fprintf(stderr, "╠═══════════════════════════════════════════════════════════════╣\n");
        fprintf(stderr, "║   返回值: %d                                                  ║\n", openResult);
        fprintf(stderr, "╚═══════════════════════════════════════════════════════════════╝\n");
        fflush(stderr);

        if (openResult < 0) {
            char errBuf[AV_ERROR_MAX_STRING_SIZE];
            av_strerror(openResult, errBuf, sizeof(errBuf));
            fprintf(stderr, "❌ avcodec_open2() 失败: %s\n", errBuf);
            fflush(stderr);
            throw std::runtime_error(std::string("Failed to open codec: ") + errBuf);
        }

        fprintf(stderr, "\n╔═══════════════════════════════════════════════════════════════╗\n");
        fprintf(stderr, "║ [APP-TRACE] 准备读取 codecCtx 成员                            ║\n");
        fprintf(stderr, "╠═══════════════════════════════════════════════════════════════╣\n");
        fprintf(stderr, "║   sizeof(AVCodecContext): %zu bytes                           ║\n", sizeof(AVCodecContext));
        fprintf(stderr, "║   codecCtx 指针: %p                                          ║\n", (void*)codecCtx);

        // ❌ 2026-01-21 21:45 [安全检查] 先检查指针有效性
        if (!codecCtx) {
            fprintf(stderr, "║   ❌ codecCtx is NULL!                                       ║\n");
            fprintf(stderr, "╚═══════════════════════════════════════════════════════════════╝\n");
            fflush(stderr);
            throw std::runtime_error("codecCtx is null after avcodec_open2");
        }

        fprintf(stderr, "║   ✅ codecCtx 指针有效                                        ║\n");
        fprintf(stderr, "╠═══════════════════════════════════════════════════════════════╣\n");
        fprintf(stderr, "║   尝试读取 sample_rate（offset 可能因版本而异）...           ║\n");
        fprintf(stderr, "╚═══════════════════════════════════════════════════════════════╝\n");
        fflush(stderr);

        // ❌ 2026-01-22 08:10 [诊断日志] 使用 fprintf 确保输出
        fprintf(stderr, "\n[APP] 原始音频格式:\n");
        fprintf(stderr, "   采样率: %d Hz\n", codecCtx->sample_rate);
        fprintf(stderr, "   声道数: %d\n", codecCtx->channels);
        fprintf(stderr, "   格式: %s\n", av_get_sample_fmt_name(codecCtx->sample_fmt));
        fflush(stderr);

        // ❌ 2026-01-21 21:45 [兼容性保留] qDebug 输出（如果能执行到这里）
        qDebug() << "      原始音频格式:";
        qDebug() << "         采样率:" << codecCtx->sample_rate << "Hz";
        // ❌ 2026-01-21 20:50 [FFmpeg 兼容性] 旧版 API 不支持 ch_layout.nb_channels，改用 channels
        // qDebug() << "         声道数:" << codecCtx->ch_layout.nb_channels;
        qDebug() << "         声道数:" << codecCtx->channels;
        qDebug() << "         格式:" << av_get_sample_fmt_name(codecCtx->sample_fmt);

        // ========== 4. 初始化重采样器（统一转换为 16kHz, 16bit, mono）==========

        // ❌ 2026-01-21 20:50 [FFmpeg 兼容性] 旧版 API 使用 uint64_t channel_layout，不支持 AVChannelLayout
        // 输入声道布局（兼容 FFmpeg 4.x/5.x channel_layout）
        // AVChannelLayout in_ch_layout = codecCtx->ch_layout;
        uint64_t in_channel_layout = codecCtx->channel_layout;

        // 如果 channel_layout 为 0，则根据声道数推断（自动适配单声道、立体声等）
        if (in_channel_layout == 0) {
            in_channel_layout = av_get_default_channel_layout(codecCtx->channels);
        }

        // 输出声道布局（单声道）
        // AVChannelLayout out_ch_layout = AV_CHANNEL_LAYOUT_MONO;
        uint64_t out_channel_layout = AV_CH_LAYOUT_MONO;

        // ❌ 2026-01-21 20:50 [FFmpeg 兼容性] 旧版 API 使用 swr_alloc_set_opts()，不支持 swr_alloc_set_opts2()
        // 创建重采样器上下文（旧版 API）
        // if (swr_alloc_set_opts2(...) < 0) { ... }
        swrCtx = swr_alloc_set_opts(
                nullptr,                     // 新分配上下文
                out_channel_layout,          // 输出：单声道
                AV_SAMPLE_FMT_S16,           // 输出：16bit PCM
                16000,                       // 输出：16kHz
                in_channel_layout,           // 输入：原始声道
                codecCtx->sample_fmt,        // 输入：原始格式
                codecCtx->sample_rate,       // 输入：原始采样率
                0, nullptr);

        if (!swrCtx) {
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

        // ✅ 2026-01-22 10:30 [FFmpeg 6.0 清理] 始终释放 codecCtx（新版 API 分配）
        if (codecCtx) {
            avcodec_free_context(&codecCtx);
        }

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

        // ✅ 2026-01-22 10:30 [FFmpeg 6.0 清理] 始终释放 codecCtx（新版 API 分配）
        if (codecCtx) {
            avcodec_free_context(&codecCtx);
        }

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
    // ✅ 2026-01-22 14:00 [调试日志] 统计编码失败的帧
    int encodedSuccessCount = 0;
    int encodedFailCount = 0;

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
            // ✅ 2026-01-22 14:00 [调试日志] 记录失败帧号
            qWarning() << "      ❌ Opus 编码失败，帧" << i << ":" << opus_strerror(encodedBytes);
            encodedFailCount++;
            continue;
        }

        // 保存 Opus 帧
        QByteArray opusFrame(reinterpret_cast<const char*>(opusBuffer), encodedBytes);
        opusFrames.append(opusFrame);
        encodedSuccessCount++;

        // 日志（每 50 帧打印一次，即每秒）
        if (i % 50 == 0 && i > 0) {
            qDebug() << "         已编码:" << i << "/" << frameCount << "帧";
        }
    }

    // ✅ 2026-01-22 14:00 [调试日志] 报告编码失败统计
    if (encodedFailCount > 0) {
        qWarning() << "      ⚠️ Opus 编码统计：成功" << encodedSuccessCount << "帧，失败" << encodedFailCount << "帧";
        qWarning() << "      ⚠️ 失败率：" << QString::number(encodedFailCount * 100.0 / frameCount, 'f', 2) << "%";
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

    // ✅ 2026-01-22 14:00 [调试日志] 检查帧数是否匹配
    if (opusFrames.size() != frameCount) {
        qWarning() << "      ⚠️ 预期帧数不匹配！";
        qWarning() << "      预期帧数:" << frameCount << "帧";
        qWarning() << "      实际帧数:" << opusFrames.size() << "帧";
        qWarning() << "      丢失帧数:" << (frameCount - opusFrames.size()) << "帧";
        qWarning() << "      丢失率:" << QString::number((frameCount - opusFrames.size()) * 100.0 / frameCount, 'f', 2) << "%";
    }

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
    // ✅ 2026-01-22 14:30 [绝对时间戳控制] 完全重构发送逻辑
    // 使用绝对时间戳计算每帧发送时机，解决定时器精度问题

    // 检查是否已播放完成
    if (!m_isPlaying || m_currentFrameIndex >= m_currentFrames.size()) {
        qDebug() << "   ✅ 所有帧发送完成，总耗时:" << m_playbackTimer.elapsed() << "ms";
        stopPlayback();
        emit playbackFinished();
        return;
    }

    // ========== 发送当前帧 ==========
    qint64 currentTime = m_playbackTimer.elapsed();
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
    } else if (bytesSent != opusFrame.size()) {
        // ✅ 2026-01-22 14:00 [调试日志] 检查发送字节数是否匹配
        qWarning() << "⚠️ UDP 发送字节数不匹配（帧" << m_currentFrameIndex << "）:";
        qWarning() << "   期望:" << opusFrame.size() << "字节";
        qWarning() << "   实际:" << bytesSent << "字节";
    }

    // ========== 计算下一帧的绝对发送时间 ==========
    m_currentFrameIndex++;  // 先递增索引

    // 计算下一帧应该发送的绝对时间戳
    // 公式：startTime + frameIndex * 20ms
    qint64 nextFrameAbsoluteTime = m_sendStartTime + m_currentFrameIndex * 20;
    qint64 delay = nextFrameAbsoluteTime - currentTime;

    // ========== 调试日志（每 50 帧打印一次）==========
    if ((m_currentFrameIndex - 1) % 50 == 0) {
        qDebug() << "   📡 已发送:" << (m_currentFrameIndex - 1) << "/" << m_totalFrames
                 << "帧（" << currentTime << "ms）";
        qDebug() << "      当前帧大小:" << opusFrame.size() << "字节";
        qDebug() << "      下一帧延迟:" << delay << "ms（绝对时间:" << nextFrameAbsoluteTime << "ms）";
    }

    // 触发进度信号
    emit playbackProgress(m_currentFrameIndex, m_totalFrames);

    // ========== 调度下一帧发送 ==========
    if (delay > 0) {
        // 延迟发送（正常情况）
        QTimer::singleShot(delay, this, &AudioNetworkSender::sendNextFrame);
    } else {
        // 已经延迟了，立即发送
        if (delay < -10) {
            qWarning() << "⚠️ 严重延迟（帧" << m_currentFrameIndex << "）: 已延迟" << (-delay) << "ms";
        }
        QTimer::singleShot(0, this, &AudioNetworkSender::sendNextFrame);
    }
}

// ========================================
// 辅助方法实现
// ========================================
// ✅ 2026-01-22 11:00 [动态计算] 获取本地 IP 地址

QHostAddress AudioNetworkSender::getLocalIPAddress()
{
    // 获取所有网络接口的地址
    const QList<QHostAddress> addresses = QNetworkInterface::allAddresses();

    // ========== 策略 1: 优先选择 192.168.x.x 网段 ==========
    // 这是最常见的局域网地址段，音频模块通常部署在此网段
    for (const QHostAddress& address : addresses) {
        if (address.protocol() == QAbstractSocket::IPv4Protocol &&
            !address.isLoopback() &&
            address.toString().startsWith("192.168.")) {
            qDebug() << "   ✅ 找到 192.168.x.x 网段地址:" << address.toString();
            return address;
        }
    }

    // ========== 策略 2: 选择第一个非回环 IPv4 地址 ==========
    // 如果没有 192.168.x.x，选择任意非回环地址（如 10.x.x.x、172.16-31.x.x）
    for (const QHostAddress& address : addresses) {
        if (address.protocol() == QAbstractSocket::IPv4Protocol &&
            !address.isLoopback()) {
            qDebug() << "   ⚠️ 未找到 192.168.x.x，使用备选地址:" << address.toString();
            return address;
        }
    }

    // ========== 策略 3: 兜底 - 返回 localhost ==========
    // 这种情况通常不会发生，除非网络完全不可用
    qWarning() << "   ❌ 无法获取本地 IP，使用 127.0.0.1（localhost）";
    qWarning() << "   ⚠️ 组播地址将计算为 224.1.0.1（可能不正确）";
    return QHostAddress::LocalHost;
}
