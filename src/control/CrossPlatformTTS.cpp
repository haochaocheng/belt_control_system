#include "CrossPlatformTTS.h"
#include <QDebug>
#include <QFile>
#include <QStandardPaths>

CrossPlatformTTS::CrossPlatformTTS(QObject *parent)
    : QObject(parent)
    , m_backend(QtTTS)
    , m_qtTts(nullptr)
    , m_process(nullptr)
    , m_rate(0.0)
    , m_pitch(0.0)
    , m_volume(0.8)
    , m_available(false)
{
}

CrossPlatformTTS::~CrossPlatformTTS()
{
    stop();
    if (m_qtTts) {
        delete m_qtTts;
    }
    if (m_process) {
        delete m_process;
    }
}

bool CrossPlatformTTS::initialize()
{
    // 自动检测最佳TTS后端
    m_backend = detectBestBackend();

    qDebug() << "🎙️ CrossPlatformTTS: 初始化TTS引擎，后端:" << m_backend;

    switch (m_backend) {
    case QtTTS:
        m_qtTts = new QTextToSpeech(this);
        connect(m_qtTts, &QTextToSpeech::stateChanged,
                this, &CrossPlatformTTS::onQtTtsStateChanged);

        // 设置语言为中文（如果可用）
        QVector<QLocale> locales = m_qtTts->availableLocales();
        for (const QLocale &locale : locales) {
            if (locale.language() == QLocale::Chinese) {
                m_qtTts->setLocale(locale);
                qDebug() << "  设置语言为中文:" << locale.name();
                break;
            }
        }

        m_qtTts->setRate(m_rate);
        m_qtTts->setPitch(m_pitch);
        m_qtTts->setVolume(m_volume);
        m_available = true;
        qDebug() << "  Qt TTS初始化成功";
        break;

    case ESpeak:
        m_process = new QProcess(this);
        connect(m_process, QOverload<int>::of(&QProcess::finished),
                this, &CrossPlatformTTS::onProcessFinished);

        // 检查eSpeak是否可用
        QProcess checkProcess;
        checkProcess.start("espeak-ng", QStringList() << "--version");
        m_available = checkProcess.waitForFinished(1000) && checkProcess.exitCode() == 0;

        if (m_available) {
            qDebug() << "  eSpeak-NG可用";
        } else {
            qWarning() << "  eSpeak-NG不可用，请安装: sudo apt-get install espeak-ng";
        }
        break;

    case SherpaOnnx:
        m_process = new QProcess(this);
        connect(m_process, QOverload<int>::of(&QProcess::finished),
                this, &CrossPlatformTTS::onProcessFinished);

        // 检查sherpa-onnx是否可用
        // TODO: 实现sherpa-onnx检测
        m_available = QFile::exists("/usr/local/bin/sherpa-onnx-offline-tts");

        if (m_available) {
            qDebug() << "  sherpa-onnx可用";
        } else {
            qWarning() << "  sherpa-onnx不可用";
        }
        break;

    case OnlineAPI:
        qDebug() << "  使用在线TTS API";
        // TODO: 实现在线API初始化
        m_available = true;
        break;
    }

    return m_available;
}

CrossPlatformTTS::TTSBackend CrossPlatformTTS::detectBestBackend()
{
#ifdef Q_OS_WIN
    // Windows: 使用Qt TTS (SAPI)
    return QtTTS;
#elif defined(Q_OS_LINUX)
    // Linux: 根据架构和可用工具选择

    // 检查是否是ARM64平台(RK3588等)
    QProcess archCheck;
    archCheck.start("uname", QStringList() << "-m");
    if (archCheck.waitForFinished(1000)) {
        QString arch = QString(archCheck.readAllStandardOutput()).trimmed();
        qDebug() << "  检测到系统架构:" << arch;

        if (arch.contains("aarch64") || arch.contains("arm64")) {
            // ARM64平台：优先使用轻量级方案

            // 1. 检查sherpa-onnx（高质量中文）
            if (QFile::exists("/usr/local/bin/sherpa-onnx-offline-tts")) {
                qDebug() << "  检测到sherpa-onnx，将使用高质量离线TTS";
                return SherpaOnnx;
            }

            // 2. 检查eSpeak-NG（轻量级备选）
            QProcess espeak;
            espeak.start("which", QStringList() << "espeak-ng");
            if (espeak.waitForFinished(1000) && espeak.exitCode() == 0) {
                qDebug() << "  检测到eSpeak-NG，将使用轻量级TTS";
                return ESpeak;
            }

            // 3. 使用在线API作为后备
            qDebug() << "  未找到本地TTS引擎，将使用在线API";
            return OnlineAPI;
        }
    }

    // x86_64平台：尝试使用Qt TTS + speech-dispatcher
    QProcess spd;
    spd.start("which", QStringList() << "speech-dispatcher");
    if (spd.waitForFinished(1000) && spd.exitCode() == 0) {
        return QtTTS;
    }

    // 备选：eSpeak
    return ESpeak;
#else
    return QtTTS;
#endif
}

void CrossPlatformTTS::say(const QString &text)
{
    if (!m_available) {
        qWarning() << "❌ TTS不可用";
        return;
    }

    switch (m_backend) {
    case QtTTS:
        sayWithQt(text);
        break;
    case ESpeak:
        sayWithESpeak(text);
        break;
    case SherpaOnnx:
        sayWithSherpa(text);
        break;
    case OnlineAPI:
        sayWithOnlineAPI(text);
        break;
    }
}

void CrossPlatformTTS::stop()
{
    switch (m_backend) {
    case QtTTS:
        stopQt();
        break;
    case ESpeak:
    case SherpaOnnx:
        stopESpeak();
        break;
    case OnlineAPI:
        // TODO: 停止在线播放
        break;
    }
}

void CrossPlatformTTS::sayWithQt(const QString &text)
{
    if (m_qtTts) {
        qDebug() << "🗣️ Qt TTS播放:" << text;
        m_qtTts->say(text);
    }
}

void CrossPlatformTTS::stopQt()
{
    if (m_qtTts && m_qtTts->state() != QTextToSpeech::Ready) {
        m_qtTts->stop();
    }
}

void CrossPlatformTTS::sayWithESpeak(const QString &text)
{
    if (!m_process) return;

    qDebug() << "🗣️ eSpeak-NG播放:" << text;

    // eSpeak-NG命令行参数
    QStringList args;
    args << "-v" << "zh";  // 中文语音
    args << "-s" << QString::number(150 + m_rate * 50);  // 语速 (100-200)
    args << "-p" << QString::number(50 + m_pitch * 25);  // 音调 (0-99)
    args << "-a" << QString::number(m_volume * 200);     // 音量 (0-200)
    args << text;

    m_process->start("espeak-ng", args);
}

void CrossPlatformTTS::stopESpeak()
{
    if (m_process && m_process->state() == QProcess::Running) {
        m_process->kill();
    }
}

void CrossPlatformTTS::sayWithSherpa(const QString &text)
{
    if (!m_process) return;

    qDebug() << "🗣️ sherpa-onnx播放:" << text;

    // sherpa-onnx命令行示例
    // 需要预先下载中文TTS模型
    QStringList args;
    args << "--vits-model" << "/path/to/model.onnx";
    args << "--vits-lexicon" << "/path/to/lexicon.txt";
    args << "--vits-tokens" << "/path/to/tokens.txt";
    args << "--output-filename" << "/tmp/tts_output.wav";
    args << text;

    // TODO: 完善sherpa-onnx参数配置
    m_process->start("sherpa-onnx-offline-tts", args);
}

void CrossPlatformTTS::sayWithOnlineAPI(const QString &text)
{
    qDebug() << "🗣️ 在线API播放:" << text;

    // TODO: 实现在线TTS API调用
    // 可选方案：
    // 1. 百度TTS API
    // 2. 讯飞TTS API
    // 3. 阿里云TTS API

    qWarning() << "在线TTS API功能待实现";
}

void CrossPlatformTTS::setRate(double rate)
{
    m_rate = rate;
    if (m_qtTts) {
        m_qtTts->setRate(rate);
    }
}

void CrossPlatformTTS::setPitch(double pitch)
{
    m_pitch = pitch;
    if (m_qtTts) {
        m_qtTts->setPitch(pitch);
    }
}

void CrossPlatformTTS::setVolume(double volume)
{
    m_volume = volume;
    if (m_qtTts) {
        m_qtTts->setVolume(volume);
    }
}

bool CrossPlatformTTS::isAvailable() const
{
    return m_available;
}

void CrossPlatformTTS::onQtTtsStateChanged(QTextToSpeech::State state)
{
    emit stateChanged(static_cast<int>(state));
}

void CrossPlatformTTS::onProcessFinished(int exitCode)
{
    qDebug() << "  TTS进程结束，退出码:" << exitCode;
    emit stateChanged(0);  // QTextToSpeech::Ready
}
