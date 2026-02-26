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

    // ✅ 2026-02-16 06:20: 添加进度更新定时器
    // 原因：初始化需要 5-10 分钟，用户需要看到进度避免以为死机
    // 效果：每 10 秒更新一次进度百分比
    QTimer progressTimer;
    int elapsedSeconds = 0;
    const int totalSeconds = 600;  // 10 分钟

    connect(&progressTimer, &QTimer::timeout, [&]() {
        elapsedSeconds += 10;
        int progress = (elapsedSeconds * 100) / totalSeconds;
        if (progress > 95) progress = 95;  // 最多显示 95%，等待实际完成

        QString progressMsg = QString("正在加载 PaddleSpeech 模型... %1% (%2/%3 秒)")
                                .arg(progress)
                                .arg(elapsedSeconds)
                                .arg(totalSeconds);
        emit initializationProgress(progressMsg);
        qDebug() << "⏳ [PaddleSpeech]" << progressMsg;
    });

    progressTimer.start(10000);  // 每 10 秒触发一次

    QJsonObject response;
    // ✅ 2026-02-16 06:10: 增加超时时间到 10 分钟
    // 原因：PaddleSpeech 首次加载模型需要 5-10 分钟（下载和初始化）
    // 效果：避免初始化超时失败
    if (!sendCommand(command, response, 600000)) {  // 初始化可能需要较长时间（10分钟）
        progressTimer.stop();
        qWarning() << "❌ [PaddleSpeech] 初始化命令失败";
        emit errorOccurred("初始化命令失败");
        stopService();
        return false;
    }

    progressTimer.stop();

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

    // ✅ 2026-02-21 22:10: 添加调试日志
    // 原因：说话人ID范围不正确，需要确认查找逻辑
    qDebug() << "🔍 [PaddleSpeech] getMaxSpeakerId - 模型索引:" << modelIndex;

    if (modelIndex < 0 || modelIndex >= models.size()) {
        qWarning() << "   ⚠️ 索引超出范围，返回 0";
        return 0;
    }

    QString modelName = models[modelIndex];
    int maxSpeakerId = MODEL_SPEAKER_COUNTS.value(modelName, 0);

    qDebug() << "   模型名称:" << modelName;
    qDebug() << "   最大说话人ID:" << maxSpeakerId;
    qDebug() << "   MODEL_SPEAKER_COUNTS 内容:" << MODEL_SPEAKER_COUNTS;

    return maxSpeakerId;
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

    // ✅ 2026-02-26 10:35 [Phase 7.47.6]: 设置 PADDLESPEECH_HOME 环境变量
    // 原因：PaddleSpeech 需要知道模型路径，避免从网络下载
    // 效果：Python 进程继承此环境变量，正确找到本地模型
    // ✅ 2026-02-26 12:30 [Phase 7.47.8]: 修复路径（移除多余的 models 层级）
    // ✅ 2026-02-26 14:30 [Phase 7.47.10]: 恢复正确路径（设备实际路径是 /home/linaro/belt-control-data/models/tts_models/）
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
#ifdef Q_OS_LINUX
    // 检测模型路径（优先 linaro，其次 pi）
    QString paddleSpeechHome;
    if (QDir("/home/linaro/belt-control-data/models/tts_models/paddlespeech").exists()) {
        paddleSpeechHome = "/home/linaro/belt-control-data/models/tts_models/paddlespeech";
    } else if (QDir("/home/pi/belt-control-data/models/tts_models/paddlespeech").exists()) {
        paddleSpeechHome = "/home/pi/belt-control-data/models/tts_models/paddlespeech";
    } else {
        paddleSpeechHome = "/app/tts_models/paddlespeech";
    }
    env.insert("PADDLESPEECH_HOME", paddleSpeechHome);
    qDebug() << "📂 [PaddleSpeech] PADDLESPEECH_HOME=" << paddleSpeechHome;
#endif
    m_process->setProcessEnvironment(env);

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

    // ✅ 2026-02-16 02:50: 临时断开 readyReadStandardOutput 信号
    // 原因：onProcessReadyRead() 会读取数据，导致 sendCommand() 读不到完整响应
    // 效果：避免响应被其他槽函数读走
    disconnect(m_process, &QProcess::readyReadStandardOutput,
               this, &PaddleSpeechAdapter::onProcessReadyRead);

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
        // ✅ 2026-02-16 02:50: 恢复信号连接
        connect(m_process, &QProcess::readyReadStandardOutput,
                this, &PaddleSpeechAdapter::onProcessReadyRead);
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
        // ✅ 2026-02-16 02:50: 恢复信号连接
        connect(m_process, &QProcess::readyReadStandardOutput,
                this, &PaddleSpeechAdapter::onProcessReadyRead);
        return false;
    }

    QString responseLine = m_responseBuffer.left(newlineIndex);
    m_responseBuffer = m_responseBuffer.mid(newlineIndex + 1);

    QJsonDocument responseDoc = QJsonDocument::fromJson(responseLine.toUtf8());
    if (responseDoc.isNull() || !responseDoc.isObject()) {
        qWarning() << "⚠️ [PaddleSpeech] 响应格式错误:" << responseLine;
        // ✅ 2026-02-16 02:50: 恢复信号连接
        connect(m_process, &QProcess::readyReadStandardOutput,
                this, &PaddleSpeechAdapter::onProcessReadyRead);
        return false;
    }

    response = responseDoc.object();
    qDebug() << "📥 [PaddleSpeech] 收到响应:" << response["status"].toString();

    // ✅ 2026-02-16 02:50: 恢复信号连接
    connect(m_process, &QProcess::readyReadStandardOutput,
            this, &PaddleSpeechAdapter::onProcessReadyRead);

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
