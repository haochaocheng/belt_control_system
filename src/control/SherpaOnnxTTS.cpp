#include "SherpaOnnxTTS.h"
#include <QDebug>
#include <QDir>
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QEventLoop>
#include <QTimer>

SherpaOnnxTTS::SherpaOnnxTTS(QObject *parent)
    : QObject(parent)
    , m_ttsProcess(new QProcess(this))
    , m_mediaPlayer(new QMediaPlayer(this))
    , m_audioOutput(new QAudioOutput(this))
    , m_state(Ready)
    , m_available(false)
    , m_rate(1.0)
    , m_volume(0.8)
{
    qDebug() << "🎙️ SherpaOnnxTTS: 初始化TTS封装（进程通信模式）";

    // 连接媒体播放器
    m_mediaPlayer->setAudioOutput(m_audioOutput);
    m_audioOutput->setVolume(m_volume);

    connect(m_mediaPlayer, &QMediaPlayer::playbackStateChanged,
            this, &SherpaOnnxTTS::onMediaPlayerStateChanged);

    // 连接进程信号
    connect(m_ttsProcess, &QProcess::readyReadStandardOutput,
            this, &SherpaOnnxTTS::onProcessReadyRead);
    connect(m_ttsProcess, &QProcess::errorOccurred,
            this, &SherpaOnnxTTS::onProcessError);
}

SherpaOnnxTTS::~SherpaOnnxTTS()
{
    if (m_ttsProcess->state() != QProcess::NotRunning) {
        qDebug() << "🛑 SherpaOnnxTTS: 停止TTS服务进程";

        // 尝试发送停止命令（不使用事件循环等待响应）
        QJsonObject stopCmd;
        stopCmd["command"] = "stop";
        QJsonDocument doc(stopCmd);
        QByteArray jsonData = doc.toJson(QJsonDocument::Compact);
        jsonData.append('\n');

        m_ttsProcess->write(jsonData);
        m_ttsProcess->waitForBytesWritten(1000);

        // 等待进程自然退出
        if (!m_ttsProcess->waitForFinished(2000)) {
            qWarning() << "⚠️  TTS服务进程未正常退出，强制终止";
            m_ttsProcess->terminate();  // 先尝试温和终止

            if (!m_ttsProcess->waitForFinished(1000)) {
                m_ttsProcess->kill();  // 强制杀死
            }
        }
    }

    qDebug() << "✅ SherpaOnnxTTS: TTS封装已销毁";
}

bool SherpaOnnxTTS::initialize(const QString &modelDir)
{
    m_modelDir = modelDir;

    qDebug() << "🎙️ SherpaOnnxTTS: 初始化TTS引擎，模型目录:" << modelDir;

    // 检查模型目录是否存在
    QDir dir(modelDir);
    if (!dir.exists()) {
        qWarning() << "❌ 模型目录不存在:" << modelDir;
        return false;
    }

    // 查找TTS服务可执行文件（跨平台）
    QString appDir = QCoreApplication::applicationDirPath();

#ifdef _WIN32
    QString exeSuffix = ".exe";
#else
    QString exeSuffix = "";  // Linux/Unix no extension
#endif

    // 尝试几个可能的位置
    QStringList possiblePaths = {
        appDir + "/sherpa_tts_service" + exeSuffix,                      // 同目录
        appDir + "/../src/tts_service/build-msvc/Release/sherpa_tts_service" + exeSuffix,  // 开发环境(Windows)
        appDir + "/../src/tts_service/build/sherpa_tts_service" + exeSuffix,  // 开发环境(Linux)
        appDir + "/bin/sherpa_tts_service" + exeSuffix                    // 安装目录
    };

    for (const QString &path : possiblePaths) {
        if (QFile::exists(path)) {
            m_serviceExecutable = path;
            break;
        }
    }

    if (m_serviceExecutable.isEmpty()) {
        qWarning() << "❌ 未找到 Sherpa-ONNX TTS 服务可执行文件";
        qWarning() << "   搜索路径:";
        for (const QString &path : possiblePaths) {
            qWarning() << "   -" << path;
        }
        qWarning() << "   请编译 src/tts_service 并复制到应用程序目录";
        qWarning() << "   Windows: 使用 MSVC 编译";
        qWarning() << "   Linux: 使用 CMake 编译";
        return false;
    }

    qDebug() << "✅ 找到TTS服务:" << m_serviceExecutable;

    // 启动TTS服务进程
    qDebug() << "🚀 启动TTS服务进程...";
    m_ttsProcess->start(m_serviceExecutable);

    if (!m_ttsProcess->waitForStarted(5000)) {
        qWarning() << "❌ TTS服务进程启动失败:" << m_ttsProcess->errorString();
        return false;
    }

    qDebug() << "✅ TTS服务进程已启动，PID:" << m_ttsProcess->processId();

    // 发送初始化命令
    QJsonObject initCmd;
    initCmd["command"] = "init";
    initCmd["model_dir"] = modelDir;

    QJsonObject response;
    if (!sendCommand(initCmd, response, 30000)) {
        qWarning() << "❌ TTS初始化失败:" << response["message"].toString();
        m_ttsProcess->kill();
        return false;
    }

    if (!response["success"].toBool()) {
        qWarning() << "❌ TTS初始化失败:" << response["message"].toString();
        m_ttsProcess->kill();
        return false;
    }

    m_available = true;
    qDebug() << "✅ SherpaOnnxTTS初始化成功:" << response["message"].toString();
    return true;
}

void SherpaOnnxTTS::say(const QString &text)
{
    if (!m_available || m_ttsProcess->state() != QProcess::Running) {
        qWarning() << "❌ TTS引擎不可用";
        return;
    }

    if (text.isEmpty()) {
        qWarning() << "❌ TTS文本为空";
        return;
    }

    qDebug() << "🗣️  SherpaOnnxTTS播放:" << text;

    setState(Speaking);

    // 生成临时文件路径
    QTemporaryFile tempFile(QDir::tempPath() + "/tts_XXXXXX.wav");
    tempFile.setAutoRemove(false);  // 播放完再删除
    if (!tempFile.open()) {
        qWarning() << "❌ 无法创建临时文件";
        setState(Error);
        return;
    }
    QString outputPath = tempFile.fileName();
    tempFile.close();

    // 发送合成命令
    QMutexLocker locker(&m_mutex);
    if (synthesize(text, outputPath)) {
        // 播放生成的音频
        m_mediaPlayer->setSource(QUrl::fromLocalFile(outputPath));
        m_mediaPlayer->play();
    } else {
        setState(Error);
        QFile::remove(outputPath);  // 删除失败的文件
    }
}

void SherpaOnnxTTS::stop()
{
    if (m_mediaPlayer->playbackState() != QMediaPlayer::StoppedState) {
        m_mediaPlayer->stop();
    }
    setState(Ready);
}

bool SherpaOnnxTTS::synthesizeToFile(const QString &text, const QString &outputFile)
{
    if (!m_available || m_ttsProcess->state() != QProcess::Running) {
        qWarning() << "❌ TTS引擎不可用";
        return false;
    }

    if (text.isEmpty()) {
        qWarning() << "❌ TTS文本为空";
        return false;
    }

    // 调用私有synthesize方法
    QMutexLocker locker(&m_mutex);
    return synthesize(text, outputFile);
}

bool SherpaOnnxTTS::sendCommand(const QJsonObject &command, QJsonObject &response, int timeoutMs)
{
    if (m_ttsProcess->state() != QProcess::Running) {
        qWarning() << "❌ TTS服务进程未运行";
        response["success"] = false;
        response["message"] = "Service process not running";
        return false;
    }

    // 转换为JSON字符串
    QJsonDocument doc(command);
    QByteArray jsonData = doc.toJson(QJsonDocument::Compact);
    jsonData.append('\n');

    qDebug() << "📤 发送命令:" << jsonData;

    // 清空响应缓冲区
    m_responseBuffer.clear();

    // 写入命令
    m_ttsProcess->write(jsonData);
    m_ttsProcess->waitForBytesWritten(1000);

    // 等待响应
    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);

    bool responseReceived = false;

    // 当收到响应时停止循环
    connect(m_ttsProcess, &QProcess::readyReadStandardOutput, &loop, [&]() {
        onProcessReadyRead();
        if (!m_responseBuffer.isEmpty() && m_responseBuffer.contains('\n')) {
            responseReceived = true;
            loop.quit();
        }
    });

    // 超时退出
    connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);

    timeout.start(timeoutMs);
    loop.exec();

    if (!responseReceived) {
        qWarning() << "⏱️  等待TTS响应超时";
        response["success"] = false;
        response["message"] = "Timeout waiting for response";
        return false;
    }

    // 解析响应
    QString responseLine = m_responseBuffer.left(m_responseBuffer.indexOf('\n'));
    m_responseBuffer.remove(0, responseLine.length() + 1);

    qDebug() << "📥 收到响应:" << responseLine;

    QJsonDocument responseDoc = QJsonDocument::fromJson(responseLine.toUtf8());
    if (responseDoc.isNull() || !responseDoc.isObject()) {
        qWarning() << "❌ 响应JSON解析失败";
        response["success"] = false;
        response["message"] = "Invalid JSON response";
        return false;
    }

    response = responseDoc.object();
    return response["success"].toBool();
}

bool SherpaOnnxTTS::synthesize(const QString &text, const QString &outputPath)
{
    qDebug() << "  合成语音到文件:" << outputPath;

    // 发送合成命令
    QJsonObject synthCmd;
    synthCmd["command"] = "synthesize";
    synthCmd["text"] = text;
    synthCmd["output_path"] = outputPath;
    synthCmd["rate"] = m_rate;
    synthCmd["speaker_id"] = 0;

    QJsonObject response;
    if (!sendCommand(synthCmd, response, 30000)) {
        qWarning() << "  ❌ 语音合成失败:" << response["message"].toString();
        return false;
    }

    if (!response["success"].toBool()) {
        qWarning() << "  ❌ 语音合成失败:" << response["message"].toString();
        return false;
    }

    qDebug() << "  ✅ 语音合成成功:" << response["message"].toString();
    return true;
}

void SherpaOnnxTTS::setRate(double rate)
{
    m_rate = qBound(0.5, rate, 2.0);  // 限制在0.5-2.0之间
    qDebug() << "设置语速:" << m_rate;
}

void SherpaOnnxTTS::setPitch(double pitch)
{
    Q_UNUSED(pitch);
    // sherpa-onnx VITS模型暂不支持音调调整
}

void SherpaOnnxTTS::setVolume(double volume)
{
    m_volume = qBound(0.0, volume, 1.0);
    if (m_audioOutput) {
        m_audioOutput->setVolume(m_volume);
    }
}

void SherpaOnnxTTS::setState(State newState)
{
    if (m_state != newState) {
        m_state = newState;
        emit stateChanged(newState);
    }
}

void SherpaOnnxTTS::onMediaPlayerStateChanged(QMediaPlayer::PlaybackState state)
{
    qDebug() << "📻 媒体播放器状态:" << state;

    switch (state) {
    case QMediaPlayer::StoppedState:
        setState(Ready);

        // 删除临时文件
        if (!m_mediaPlayer->source().isEmpty()) {
            QString filePath = m_mediaPlayer->source().toLocalFile();
            if (filePath.contains("/tts_") && filePath.endsWith(".wav")) {
                QFile::remove(filePath);
                qDebug() << "  删除临时文件:" << filePath;
            }
        }
        break;

    case QMediaPlayer::PlayingState:
        setState(Speaking);
        break;

    case QMediaPlayer::PausedState:
        setState(Paused);
        break;
    }
}

void SherpaOnnxTTS::onProcessReadyRead()
{
    // 读取进程输出
    QByteArray output = m_ttsProcess->readAllStandardOutput();
    m_responseBuffer.append(QString::fromUtf8(output));
}

void SherpaOnnxTTS::onProcessError(QProcess::ProcessError error)
{
    qWarning() << "❌ TTS服务进程错误:" << error << m_ttsProcess->errorString();
    m_available = false;
    setState(Error);
}
