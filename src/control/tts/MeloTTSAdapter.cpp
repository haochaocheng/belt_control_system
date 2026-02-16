#include "MeloTTSAdapter.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QDir>
#include <QThread>
#include <QEventLoop>
#include <QTimer>

// ✅ 2026-02-13 [Phase 7.46.2]: 实现 MeloTTS 适配器

// 模型说话人数量映射
const QMap<QString, int> MeloTTSAdapter::MODEL_SPEAKER_COUNTS = {
    {"ZH", 0},      // 中文（单说话人）
    {"EN", 0},      // 英文（单说话人）
    {"ZH-EN", 0}    // 中英文混合（单说话人）
};

MeloTTSAdapter::MeloTTSAdapter(QObject *parent)
    : TTSEngineAdapter(parent)
    , m_process(nullptr)
{
    m_engineName = "MeloTTS";
    m_engineType = TTSEngineType::MeloTTS;

    // 设置服务脚本路径
#ifdef Q_OS_LINUX
    m_serviceScript = "/app/tts_engines/melotts/melo_tts_service.py";
#else
    m_serviceScript = "docker/rk3588/tts_engines/melotts/melo_tts_service.py";
#endif

    qDebug() << "✅ [MeloTTS] 适配器创建";
}

MeloTTSAdapter::~MeloTTSAdapter()
{
    stopService();
    qDebug() << "🔴 [MeloTTS] 适配器销毁";
}

bool MeloTTSAdapter::initialize(const QString &modelPath)
{
    QMutexLocker locker(&m_mutex);

    qDebug() << "🔧 [MeloTTS] 初始化 - 模型:" << modelPath;

    // 检查服务脚本是否存在
    if (!QFile::exists(m_serviceScript)) {
        qWarning() << "❌ [MeloTTS] 服务脚本不存在:" << m_serviceScript;
        emit errorOccurred("服务脚本不存在");
        return false;
    }

    // 启动服务进程
    if (!startService()) {
        qWarning() << "❌ [MeloTTS] 启动服务失败";
        emit errorOccurred("启动服务失败");
        return false;
    }

    // 发送初始化命令
    QJsonObject command;
    command["command"] = "initialize";
    command["model"] = modelPath;

    emit initializationProgress("正在加载 MeloTTS 模型...");

    QJsonObject response;
    if (!sendCommand(command, response, 60000)) {  // 初始化可能需要较长时间（1分钟）
        qWarning() << "❌ [MeloTTS] 初始化命令失败";
        emit errorOccurred("初始化命令失败");
        stopService();
        return false;
    }

    if (response["status"].toString() != "success") {
        QString error = response["error"].toString();
        qWarning() << "❌ [MeloTTS] 初始化失败:" << error;
        emit errorOccurred(error);
        stopService();
        return false;
    }

    m_isInitialized = true;
    qDebug() << "✅ [MeloTTS] 初始化成功";
    emit initializationProgress("MeloTTS 初始化完成");

    return true;
}

bool MeloTTSAdapter::synthesize(const QString &text, const QString &outputPath, const TTSParameters &params)
{
    QMutexLocker locker(&m_mutex);

    if (!m_isInitialized) {
        qWarning() << "⚠️ [MeloTTS] 未初始化";
        emit errorOccurred("引擎未初始化");
        return false;
    }

    qDebug() << "🎙️ [MeloTTS] 合成语音 - 文本:" << text
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
    if (!sendCommand(command, response, 30000)) {  // 合成超时 30 秒
        qWarning() << "❌ [MeloTTS] 合成命令失败";
        emit errorOccurred("合成命令失败");
        return false;
    }

    if (response["status"].toString() != "success") {
        QString error = response["error"].toString();
        qWarning() << "❌ [MeloTTS] 合成失败:" << error;
        emit errorOccurred(error);
        return false;
    }

    emit synthesisProgress(100);
    qDebug() << "✅ [MeloTTS] 合成成功:" << outputPath;
    return true;
}

QStringList MeloTTSAdapter::getModelList() const
{
    return QStringList()
        << "ZH (中文)"
        << "EN (英文)"
        << "ZH-EN (中英文混合)";
}

int MeloTTSAdapter::getMaxSpeakerId(int modelIndex) const
{
    // MeloTTS 默认模型只有 1 个说话人
    Q_UNUSED(modelIndex);
    return 0;  // 说话人ID范围: 0-0
}

void MeloTTSAdapter::stop()
{
    QMutexLocker locker(&m_mutex);

    if (m_process && m_process->state() == QProcess::Running) {
        // 发送停止命令
        QJsonObject command;
        command["command"] = "stop";

        QJsonObject response;
        sendCommand(command, response, 5000);

        qDebug() << "🛑 [MeloTTS] 停止合成";
    }
}

bool MeloTTSAdapter::startService()
{
    if (m_process && m_process->state() == QProcess::Running) {
        qDebug() << "⚠️ [MeloTTS] 服务已在运行";
        return true;
    }

    // 创建进程
    m_process = new QProcess(this);

    // 连接信号
    connect(m_process, &QProcess::readyReadStandardOutput,
            this, &MeloTTSAdapter::onProcessReadyRead);
    connect(m_process, &QProcess::readyReadStandardError, this, [this]() {
        // ✅ 2026-02-16 00:35: 捕获 Python 进程的 stderr 输出
        QByteArray data = m_process->readAllStandardError();
        QString error = QString::fromUtf8(data).trimmed();
        if (!error.isEmpty()) {
            qWarning() << "[MeloTTS Error]" << error;
        }
    });
    connect(m_process, &QProcess::errorOccurred,
            this, &MeloTTSAdapter::onProcessError);
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &MeloTTSAdapter::onProcessFinished);

    // 启动 Python 服务
    qDebug() << "🚀 [MeloTTS] 启动服务:" << m_serviceScript;

#ifdef Q_OS_LINUX
    m_process->start("python3", QStringList() << m_serviceScript);
#else
    m_process->start("python", QStringList() << m_serviceScript);
#endif

    // 等待启动
    if (!m_process->waitForStarted(10000)) {
        qWarning() << "❌ [MeloTTS] 启动超时";
        delete m_process;
        m_process = nullptr;
        return false;
    }

    qDebug() << "✅ [MeloTTS] 服务启动成功";
    return true;
}

void MeloTTSAdapter::stopService()
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
            qWarning() << "⚠️ [MeloTTS] 进程未正常退出，强制终止";
            m_process->kill();
            m_process->waitForFinished(2000);
        }
    }

    m_process->deleteLater();
    m_process = nullptr;
    m_isInitialized = false;

    qDebug() << "🔴 [MeloTTS] 服务已停止";
}

bool MeloTTSAdapter::sendCommand(const QJsonObject &command, QJsonObject &response, int timeoutMs)
{
    if (!m_process || m_process->state() != QProcess::Running) {
        qWarning() << "⚠️ [MeloTTS] 进程未运行";
        return false;
    }

    // 清空响应缓冲区
    m_responseBuffer.clear();

    // 发送 JSON 命令
    QJsonDocument doc(command);
    QString commandStr = doc.toJson(QJsonDocument::Compact) + "\n";

    qDebug() << "📤 [MeloTTS] 发送命令:" << command["command"].toString();

    m_process->write(commandStr.toUtf8());
    m_process->waitForBytesWritten(1000);

    // 等待响应
    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);

    bool responseReceived = false;

    // 连接超时定时器
    connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);

    // 连接进程输出信号
    auto connection = connect(m_process, &QProcess::readyReadStandardOutput, [&]() {
        // 读取输出
        QByteArray data = m_process->readAllStandardOutput();
        m_responseBuffer.append(QString::fromUtf8(data));

        // 检查是否收到完整的 JSON 响应
        if (m_responseBuffer.contains('\n')) {
            responseReceived = true;
            loop.quit();
        }
    });

    // 启动超时定时器
    timer.start(timeoutMs);

    // 进入事件循环
    loop.exec();

    // 断开连接
    disconnect(connection);

    if (!responseReceived) {
        qWarning() << "⚠️ [MeloTTS] 响应超时";
        return false;
    }

    // 解析 JSON 响应
    QString responseLine = m_responseBuffer.split('\n').first().trimmed();
    QJsonDocument responseDoc = QJsonDocument::fromJson(responseLine.toUtf8());

    if (responseDoc.isNull() || !responseDoc.isObject()) {
        qWarning() << "⚠️ [MeloTTS] 无效的 JSON 响应:" << responseLine;
        return false;
    }

    response = responseDoc.object();
    qDebug() << "📥 [MeloTTS] 收到响应:" << response["status"].toString();

    return true;
}

void MeloTTSAdapter::onProcessReadyRead()
{
    // 读取标准错误输出（日志）
    QByteArray errorData = m_process->readAllStandardError();
    if (!errorData.isEmpty()) {
        QString errorStr = QString::fromUtf8(errorData).trimmed();
        qDebug() << "[MeloTTS Python]" << errorStr;
    }
}

void MeloTTSAdapter::onProcessError(QProcess::ProcessError error)
{
    QString errorStr;
    switch (error) {
    case QProcess::FailedToStart:
        errorStr = "进程启动失败";
        break;
    case QProcess::Crashed:
        errorStr = "进程崩溃";
        break;
    case QProcess::Timedout:
        errorStr = "进程超时";
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

    qWarning() << "❌ [MeloTTS] 进程错误:" << errorStr;
    emit errorOccurred(errorStr);
}

void MeloTTSAdapter::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    QString statusStr = (exitStatus == QProcess::NormalExit) ? "正常退出" : "崩溃退出";
    qDebug() << "🔴 [MeloTTS] 进程结束 - 退出码:" << exitCode << "状态:" << statusStr;

    m_isInitialized = false;
}
