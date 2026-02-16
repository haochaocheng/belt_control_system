#include "PaddleSpeechAdapter.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QDir>
#include <QThread>
#include <QEventLoop>
#include <QTimer>

// ✅ 2026-02-13 [Phase 7.46.3]: 实现 PaddleSpeech 适配器

// 模型说话人数量映射
const QMap<QString, int> PaddleSpeechAdapter::MODEL_SPEAKER_COUNTS = {
    {"fastspeech2_csmsc", 0},       // 单说话人（女声）
    {"fastspeech2_aishell3", 173},  // 174 个说话人
    {"fastspeech2_ljspeech", 0},    // 单说话人（英文女声）
    {"fastspeech2_vctk", 107}       // 108 个说话人（英文）
};

PaddleSpeechAdapter::PaddleSpeechAdapter(QObject *parent)
    : TTSEngineAdapter(parent)
    , m_process(nullptr)
{
    m_engineName = "PaddleSpeech";
    m_engineType = TTSEngineType::PaddleSpeech;

    // 设置服务脚本路径
#ifdef Q_OS_LINUX
    m_serviceScript = "/app/tts_engines/paddlespeech/paddle_tts_service.py";
#else
    m_serviceScript = "docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py";
#endif

    qDebug() << "✅ [PaddleSpeech] 适配器创建";
}

PaddleSpeechAdapter::~PaddleSpeechAdapter()
{
    stopService();
    qDebug() << "🔴 [PaddleSpeech] 适配器销毁";
}

bool PaddleSpeechAdapter::initialize(const QString &modelPath)
{
    QMutexLocker locker(&m_mutex);

    qDebug() << "🔧 [PaddleSpeech] 初始化 - 模型:" << modelPath;

    // 检查服务脚本是否存在
    if (!QFile::exists(m_serviceScript)) {
        qWarning() << "❌ [PaddleSpeech] 服务脚本不存在:" << m_serviceScript;
        emit errorOccurred("服务脚本不存在");
        return false;
    }

    // 启动服务进程
    if (!startService()) {
        qWarning() << "❌ [PaddleSpeech] 启动服务失败";
        emit errorOccurred("启动服务失败");
        return false;
    }

    // 发送初始化命令
    QJsonObject command;
    command["command"] = "initialize";
    command["model"] = modelPath;

    emit initializationProgress("正在加载 PaddleSpeech 模型...");

    QJsonObject response;
    if (!sendCommand(command, response, 120000)) {  // 初始化可能需要较长时间（2分钟）
        qWarning() << "❌ [PaddleSpeech] 初始化命令失败";
        emit errorOccurred("初始化命令失败");
        stopService();
        return false;
    }

    if (response["status"].toString() != "success") {
        QString error = response["error"].toString();
        qWarning() << "❌ [PaddleSpeech] 初始化失败:" << error;
        emit errorOccurred(error);
        stopService();
        return false;
    }

    m_isInitialized = true;
    qDebug() << "✅ [PaddleSpeech] 初始化成功";
    emit initializationProgress("PaddleSpeech 初始化完成");

    return true;
}

bool PaddleSpeechAdapter::synthesize(const QString &text, const QString &outputPath, const TTSParameters &params)
{
    QMutexLocker locker(&m_mutex);

    if (!m_isInitialized) {
        qWarning() << "⚠️ [PaddleSpeech] 未初始化";
        emit errorOccurred("引擎未初始化");
        return false;
    }

    qDebug() << "🎙️ [PaddleSpeech] 合成语音 - 文本:" << text
             << "说话人ID:" << params.speakerId
             << "语速:" << params.rate
             << "音量:" << params.volume;

    // 发送合成命令
    QJsonObject command;
    command["command"] = "synthesize";
    command["text"] = text;
    command["output_path"] = outputPath;
    command["speaker_id"] = params.speakerId;
    command["speed"] = params.rate;
    command["volume"] = params.volume;

    emit synthesisProgress(0);

    QJsonObject response;
    if (!sendCommand(command, response, 60000)) {  // 合成超时 60 秒
        qWarning() << "❌ [PaddleSpeech] 合成命令失败";
        emit errorOccurred("合成命令失败");
        return false;
    }

    if (response["status"].toString() != "success") {
        QString error = response["error"].toString();
        qWarning() << "❌ [PaddleSpeech] 合成失败:" << error;
        emit errorOccurred(error);
        return false;
    }

    emit synthesisProgress(100);
    qDebug() << "✅ [PaddleSpeech] 合成成功:" << outputPath;
    return true;
}

QStringList PaddleSpeechAdapter::getModelList() const
{
    return QStringList()
        << "fastspeech2_csmsc (中文女声)"
        << "fastspeech2_aishell3 (中文多说话人)"
        << "fastspeech2_ljspeech (英文女声)"
        << "fastspeech2_vctk (英文多说话人)";
}

int PaddleSpeechAdapter::getMaxSpeakerId(int modelIndex) const
{
    QStringList models = QStringList()
        << "fastspeech2_csmsc"
        << "fastspeech2_aishell3"
        << "fastspeech2_ljspeech"
        << "fastspeech2_vctk";

    if (modelIndex < 0 || modelIndex >= models.size()) {
        return 0;
    }

    QString modelName = models[modelIndex];
    return MODEL_SPEAKER_COUNTS.value(modelName, 0);
}

void PaddleSpeechAdapter::stop()
{
    QMutexLocker locker(&m_mutex);

    if (m_process && m_process->state() == QProcess::Running) {
        // 发送停止命令
        QJsonObject command;
        command["command"] = "stop";

        QJsonObject response;
        sendCommand(command, response, 5000);

        qDebug() << "🛑 [PaddleSpeech] 停止合成";
    }
}

bool PaddleSpeechAdapter::startService()
{
    if (m_process && m_process->state() == QProcess::Running) {
        qDebug() << "⚠️ [PaddleSpeech] 服务已在运行";
        return true;
    }

    // 创建进程
    m_process = new QProcess(this);

    // 连接信号
    connect(m_process, &QProcess::readyReadStandardOutput,
            this, &PaddleSpeechAdapter::onProcessReadyRead);
    connect(m_process, &QProcess::readyReadStandardError, this, [this]() {
        // ✅ 2026-02-16 00:35: 捕获 Python 进程的 stderr 输出
        QByteArray data = m_process->readAllStandardError();
        QString error = QString::fromUtf8(data).trimmed();
        if (!error.isEmpty()) {
            qWarning() << "[PaddleSpeech Error]" << error;
        }
    });
    connect(m_process, &QProcess::errorOccurred,
            this, &PaddleSpeechAdapter::onProcessError);
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &PaddleSpeechAdapter::onProcessFinished);

    // 启动 Python 服务
    qDebug() << "🚀 [PaddleSpeech] 启动服务:" << m_serviceScript;

#ifdef Q_OS_LINUX
    m_process->start("python3", QStringList() << m_serviceScript);
#else
    m_process->start("python", QStringList() << m_serviceScript);
#endif

    // 等待启动
    if (!m_process->waitForStarted(10000)) {
        qWarning() << "❌ [PaddleSpeech] 启动超时";
        delete m_process;
        m_process = nullptr;
        return false;
    }

    qDebug() << "✅ [PaddleSpeech] 服务启动成功";
    return true;
}

void PaddleSpeechAdapter::stopService()
{
    if (!m_process) {
        return;
    }

    if (m_process->state() == QProcess::Running) {
        // 发送关闭命令
        QJsonObject command;
        command["command"] = "shutdown";

        QJsonObject response;
        sendCommand(command, response, 5000);

        // 等待进程退出
        if (!m_process->waitForFinished(5000)) {
            qWarning() << "⚠️ [PaddleSpeech] 进程未正常退出，强制终止";
            m_process->kill();
            m_process->waitForFinished(2000);
        }
    }

    m_process->deleteLater();
    m_process = nullptr;

    qDebug() << "🔴 [PaddleSpeech] 服务已停止";
}

bool PaddleSpeechAdapter::sendCommand(const QJsonObject &command, QJsonObject &response, int timeoutMs)
{
    if (!m_process || m_process->state() != QProcess::Running) {
        qWarning() << "⚠️ [PaddleSpeech] 服务未运行";
        return false;
    }

    // 清空响应缓冲区
    m_responseBuffer.clear();

    // 发送命令
    QJsonDocument doc(command);
    QByteArray data = doc.toJson(QJsonDocument::Compact) + "\n";

    qDebug() << "📤 [PaddleSpeech] 发送命令:" << command["command"].toString();

    m_process->write(data);
    m_process->waitForBytesWritten(1000);

    // 等待响应
    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);

    connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    connect(m_process, &QProcess::readyReadStandardOutput, &loop, &QEventLoop::quit);

    timer.start(timeoutMs);
    loop.exec();

    if (!timer.isActive()) {
        qWarning() << "⚠️ [PaddleSpeech] 命令超时";
        return false;
    }

    timer.stop();

    // 读取响应
    QByteArray responseData = m_process->readAllStandardOutput();
    m_responseBuffer += QString::fromUtf8(responseData);

    // 解析 JSON 响应
    int newlineIndex = m_responseBuffer.indexOf('\n');
    if (newlineIndex == -1) {
        qWarning() << "⚠️ [PaddleSpeech] 响应不完整";
        return false;
    }

    QString responseLine = m_responseBuffer.left(newlineIndex);
    m_responseBuffer = m_responseBuffer.mid(newlineIndex + 1);

    QJsonDocument responseDoc = QJsonDocument::fromJson(responseLine.toUtf8());
    if (responseDoc.isNull() || !responseDoc.isObject()) {
        qWarning() << "⚠️ [PaddleSpeech] 响应格式错误:" << responseLine;
        return false;
    }

    response = responseDoc.object();
    qDebug() << "📥 [PaddleSpeech] 收到响应:" << response["status"].toString();

    return true;
}

void PaddleSpeechAdapter::onProcessReadyRead()
{
    // 读取标准输出（用于调试）
    QByteArray data = m_process->readAllStandardOutput();
    QString output = QString::fromUtf8(data).trimmed();

    if (!output.isEmpty()) {
        qDebug() << "[PaddleSpeech Output]" << output;
    }
}

void PaddleSpeechAdapter::onProcessError(QProcess::ProcessError error)
{
    QString errorStr;
    switch (error) {
    case QProcess::FailedToStart:
        errorStr = "启动失败";
        break;
    case QProcess::Crashed:
        errorStr = "进程崩溃";
        break;
    case QProcess::Timedout:
        errorStr = "超时";
        break;
    case QProcess::WriteError:
        errorStr = "写入错误";
        break;
    case QProcess::ReadError:
        errorStr = "读取错误";
        break;
    default:
        errorStr = "未知错误";
        break;
    }

    qWarning() << "❌ [PaddleSpeech] 进程错误:" << errorStr;
    emit errorOccurred(errorStr);
}

void PaddleSpeechAdapter::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    QString statusStr = (exitStatus == QProcess::NormalExit) ? "正常退出" : "崩溃退出";
    qDebug() << "🔴 [PaddleSpeech] 进程结束 - 退出码:" << exitCode << "状态:" << statusStr;

    if (exitStatus == QProcess::CrashExit) {
        emit errorOccurred("服务进程崩溃");
    }

    m_isInitialized = false;
}
