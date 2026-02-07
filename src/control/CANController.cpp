// ✅ 2026-02-07: Phase 7.39.1 - CANController 基础框架
// CAN 控制器实现

#include "CANController.h"
#include <QDebug>
#include <QDateTime>
#include <QRegularExpression>

CANController::CANController(QObject *parent)
    : QObject(parent)
    , m_currentCanIndex(0)
    , m_receiveProcess(nullptr)
    , m_settings(nullptr)
{
    qDebug() << "✅ [CANController] 构造函数开始";

    // 初始化配置
    initializeConfigs();

    // 初始化 QSettings
    initSettings();

    // 加载配置
    loadConfig();

    qDebug() << "✅ [CANController] 构造函数完成";
}

CANController::~CANController()
{
    qDebug() << "✅ [CANController] 析构函数开始";

    // 关闭 CAN 接口
    if (isUp()) {
        closeCAN();
    }

    // 清理接收进程
    if (m_receiveProcess) {
        m_receiveProcess->kill();
        m_receiveProcess->waitForFinished();
        delete m_receiveProcess;
        m_receiveProcess = nullptr;
    }

    // 清理 QSettings
    if (m_settings) {
        delete m_settings;
        m_settings = nullptr;
    }

    qDebug() << "✅ [CANController] 析构函数完成";
}

// ========== 初始化配置 ==========
void CANController::initializeConfigs()
{
    qDebug() << "✅ [CANController] 初始化配置";

    m_canConfigs.clear();

    // CAN0 配置
    CANConfig can0;
    can0.canName = "CAN0";
    can0.canInterface = "can0";
    can0.bitrate = 500000;  // 默认 500kbps
    can0.frameType = "标准帧";
    can0.isUp = false;
    m_canConfigs.append(can0);

    // CAN1 配置
    CANConfig can1;
    can1.canName = "CAN1";
    can1.canInterface = "can1";
    can1.bitrate = 250000;  // 默认 250kbps
    can1.frameType = "标准帧";
    can1.isUp = false;
    m_canConfigs.append(can1);

    qDebug() << "✅ [CANController] 配置初始化完成，CAN 数量:" << m_canConfigs.size();
}

// ========== 初始化 QSettings ==========
void CANController::initSettings()
{
    m_settings = new QSettings("BeltControlSystem", "CANController", this);
    qDebug() << "✅ [CANController] QSettings 初始化完成";
}

// ========== CAN 列表 ==========
QStringList CANController::canInterfaces() const
{
    QStringList list;
    for (const CANConfig &config : m_canConfigs) {
        list.append(config.canName);
    }
    return list;
}

// ========== 当前 CAN 配置 ==========
void CANController::setCurrentCanIndex(int index)
{
    if (index < 0 || index >= m_canConfigs.size()) {
        qWarning() << "⚠️ [CANController] 无效的 CAN 索引:" << index;
        return;
    }

    if (m_currentCanIndex != index) {
        // 如果当前 CAN 已启动，先关闭
        if (isUp()) {
            closeCAN();
        }

        m_currentCanIndex = index;
        emit currentCanIndexChanged();
        emit currentCanNameChanged();
        emit canInterfaceChanged();
        emit bitrateChanged();
        emit frameTypeChanged();
        emit isUpChanged();
        emit statusChanged();

        qDebug() << "✅ [CANController] 切换到 CAN" << index << ":" << currentCanName();
    }
}

QString CANController::currentCanName() const
{
    if (m_currentCanIndex >= 0 && m_currentCanIndex < m_canConfigs.size()) {
        return m_canConfigs[m_currentCanIndex].canName;
    }
    return "";
}

QString CANController::canInterface() const
{
    if (m_currentCanIndex >= 0 && m_currentCanIndex < m_canConfigs.size()) {
        return m_canConfigs[m_currentCanIndex].canInterface;
    }
    return "";
}

int CANController::bitrate() const
{
    if (m_currentCanIndex >= 0 && m_currentCanIndex < m_canConfigs.size()) {
        return m_canConfigs[m_currentCanIndex].bitrate;
    }
    return 500000;  // 默认值
}

void CANController::setBitrate(int rate)
{
    if (m_currentCanIndex >= 0 && m_currentCanIndex < m_canConfigs.size()) {
        if (m_canConfigs[m_currentCanIndex].bitrate != rate) {
            m_canConfigs[m_currentCanIndex].bitrate = rate;
            emit bitrateChanged();
            qDebug() << "✅ [CANController] 波特率已更新:" << rate;
        }
    }
}

QString CANController::frameType() const
{
    if (m_currentCanIndex >= 0 && m_currentCanIndex < m_canConfigs.size()) {
        return m_canConfigs[m_currentCanIndex].frameType;
    }
    return "标准帧";
}

void CANController::setFrameType(const QString &type)
{
    if (m_currentCanIndex >= 0 && m_currentCanIndex < m_canConfigs.size()) {
        if (m_canConfigs[m_currentCanIndex].frameType != type) {
            m_canConfigs[m_currentCanIndex].frameType = type;
            emit frameTypeChanged();
            qDebug() << "✅ [CANController] 帧类型已更新:" << type;
        }
    }
}

bool CANController::isUp() const
{
    if (m_currentCanIndex >= 0 && m_currentCanIndex < m_canConfigs.size()) {
        return m_canConfigs[m_currentCanIndex].isUp;
    }
    return false;
}

QString CANController::status() const
{
    return isUp() ? "UP" : "DOWN";
}

// ========== CAN 操作 ==========
bool CANController::openCAN()
{
    qDebug() << "✅ [CANController] 打开 CAN 接口:" << canInterface();

    if (isUp()) {
        qWarning() << "⚠️ [CANController] CAN 接口已经启动";
        return true;
    }

    // 检查 CAN 接口是否存在
    if (!checkCANInterface(canInterface())) {
        QString error = QString("CAN 接口 %1 不存在").arg(canInterface());
        qCritical() << "❌ [CANController]" << error;
        emit errorOccurred(error);
        return false;
    }

    // 1. 配置波特率
    QProcess configProcess;
    QStringList configArgs;
    configArgs << "ip" << "link" << "set" << canInterface()
               << "type" << "can" << "bitrate" << QString::number(bitrate());

    qDebug() << "✅ [CANController] 执行命令: sudo" << configArgs.join(" ");
    configProcess.start("sudo", configArgs);
    configProcess.waitForFinished(5000);

    if (configProcess.exitCode() != 0) {
        QString error = QString("配置 CAN 波特率失败: %1").arg(QString::fromUtf8(configProcess.readAllStandardError()));
        qCritical() << "❌ [CANController]" << error;
        emit errorOccurred(error);
        return false;
    }

    // 2. 启动接口
    QProcess upProcess;
    QStringList upArgs;
    upArgs << "ip" << "link" << "set" << canInterface() << "up";

    qDebug() << "✅ [CANController] 执行命令: sudo" << upArgs.join(" ");
    upProcess.start("sudo", upArgs);
    upProcess.waitForFinished(5000);

    if (upProcess.exitCode() != 0) {
        QString error = QString("启动 CAN 接口失败: %1").arg(QString::fromUtf8(upProcess.readAllStandardError()));
        qCritical() << "❌ [CANController]" << error;
        emit errorOccurred(error);
        return false;
    }

    // 3. 启动接收进程
    if (!m_receiveProcess) {
        m_receiveProcess = new QProcess(this);
        connect(m_receiveProcess, &QProcess::readyReadStandardOutput, this, &CANController::handleReceiveData);
        connect(m_receiveProcess, &QProcess::errorOccurred, this, &CANController::handleReceiveError);
        connect(m_receiveProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, &CANController::handleReceiveFinished);
    }

    m_receiveProcess->start("candump", QStringList() << canInterface());

    if (!m_receiveProcess->waitForStarted(5000)) {
        QString error = "启动 candump 进程失败";
        qCritical() << "❌ [CANController]" << error;
        emit errorOccurred(error);
        return false;
    }

    // 更新状态
    if (m_currentCanIndex >= 0 && m_currentCanIndex < m_canConfigs.size()) {
        m_canConfigs[m_currentCanIndex].isUp = true;
        emit isUpChanged();
        emit statusChanged();
    }

    qDebug() << "✅ [CANController] CAN 接口已启动";
    return true;
}

void CANController::closeCAN()
{
    qDebug() << "✅ [CANController] 关闭 CAN 接口:" << canInterface();

    if (!isUp()) {
        qWarning() << "⚠️ [CANController] CAN 接口已经关闭";
        return;
    }

    // 1. 停止接收进程
    if (m_receiveProcess) {
        m_receiveProcess->kill();
        m_receiveProcess->waitForFinished(3000);
        delete m_receiveProcess;
        m_receiveProcess = nullptr;
    }

    // 2. 关闭接口
    QProcess downProcess;
    QStringList downArgs;
    downArgs << "ip" << "link" << "set" << canInterface() << "down";

    qDebug() << "✅ [CANController] 执行命令: sudo" << downArgs.join(" ");
    downProcess.start("sudo", downArgs);
    downProcess.waitForFinished(5000);

    if (downProcess.exitCode() != 0) {
        QString error = QString("关闭 CAN 接口失败: %1").arg(QString::fromUtf8(downProcess.readAllStandardError()));
        qWarning() << "⚠️ [CANController]" << error;
        emit errorOccurred(error);
    }

    // 更新状态
    if (m_currentCanIndex >= 0 && m_currentCanIndex < m_canConfigs.size()) {
        m_canConfigs[m_currentCanIndex].isUp = false;
        emit isUpChanged();
        emit statusChanged();
    }

    qDebug() << "✅ [CANController] CAN 接口已关闭";
}

bool CANController::sendData(const QString &canId, const QString &data)
{
    qDebug() << "✅ [CANController] 发送数据 - CAN ID:" << canId << "数据:" << data;

    if (!isUp()) {
        QString error = "CAN 接口未启动，无法发送数据";
        qWarning() << "⚠️ [CANController]" << error;
        emit errorOccurred(error);
        return false;
    }

    // 格式：cansend can0 123#DEADBEEF
    QString frame = canId + "#" + data;

    QProcess sendProcess;
    sendProcess.start("cansend", QStringList() << canInterface() << frame);
    sendProcess.waitForFinished(3000);

    if (sendProcess.exitCode() != 0) {
        QString error = QString("发送 CAN 数据失败: %1").arg(QString::fromUtf8(sendProcess.readAllStandardError()));
        qCritical() << "❌ [CANController]" << error;
        emit errorOccurred(error);
        return false;
    }

    qDebug() << "✅ [CANController] 数据发送成功";
    return true;
}

void CANController::clearReceiveBuffer()
{
    m_receiveBuffer.clear();
    emit receiveBufferChanged();
    qDebug() << "✅ [CANController] 接收缓冲区已清空";
}

// ========== 接收数据处理 ==========
void CANController::handleReceiveData()
{
    if (!m_receiveProcess) {
        return;
    }

    QByteArray data = m_receiveProcess->readAllStandardOutput();
    QString lines = QString::fromUtf8(data);

    // 解析每一行
    QStringList lineList = lines.split('\n', Qt::SkipEmptyParts);
    for (const QString &line : lineList) {
        QString canId, canData;
        QString timestamp = parseCANFrame(line, canId, canData);

        if (!canId.isEmpty()) {
            // 添加到接收缓冲区
            QString formattedLine = QString("[%1] %2 | %3\n").arg(timestamp, canId, canData);
            m_receiveBuffer.append(formattedLine);
            emit receiveBufferChanged();

            // 发送信号
            emit dataReceived(canId, canData, timestamp);

            qDebug() << "✅ [CANController] 接收数据 - CAN ID:" << canId << "数据:" << canData;
        }
    }
}

void CANController::handleReceiveError()
{
    if (m_receiveProcess) {
        QString error = QString("candump 进程错误: %1").arg(m_receiveProcess->errorString());
        qCritical() << "❌ [CANController]" << error;
        emit errorOccurred(error);
    }
}

void CANController::handleReceiveFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    qDebug() << "✅ [CANController] candump 进程结束 - 退出码:" << exitCode << "状态:" << exitStatus;

    if (exitStatus == QProcess::CrashExit) {
        QString error = "candump 进程崩溃";
        qCritical() << "❌ [CANController]" << error;
        emit errorOccurred(error);
    }
}

// ========== 辅助函数 ==========
bool CANController::checkCANInterface(const QString &interface)
{
    QProcess checkProcess;
    checkProcess.start("ip", QStringList() << "link" << "show" << interface);
    checkProcess.waitForFinished(3000);

    return checkProcess.exitCode() == 0;
}

QString CANController::parseCANFrame(const QString &line, QString &canId, QString &data)
{
    // candump 输出格式：can0  123   [8]  DE AD BE EF 01 02 03 04
    // 或：(1234567890.123456) can0  123   [8]  DE AD BE EF 01 02 03 04

    // 使用正则表达式解析
    QRegularExpression re(R"((?:\((\d+\.\d+)\)\s+)?(\w+)\s+([0-9A-Fa-f]+)\s+\[(\d+)\]\s+((?:[0-9A-Fa-f]{2}\s*)*))");
    QRegularExpressionMatch match = re.match(line);

    if (match.hasMatch()) {
        QString timestampStr = match.captured(1);  // 时间戳（可选）
        // QString interface = match.captured(2);     // CAN 接口
        canId = match.captured(3);                  // CAN ID
        // QString length = match.captured(4);        // 数据长度
        data = match.captured(5).trimmed();         // 数据内容

        // 移除数据中的空格
        data.remove(' ');

        // 生成时间戳
        QString timestamp;
        if (!timestampStr.isEmpty()) {
            // 使用 candump 的时间戳
            timestamp = timestampStr;
        } else {
            // 使用当前时间
            timestamp = QDateTime::currentDateTime().toString("hh:mm:ss.zzz");
        }

        return timestamp;
    }

    return "";
}

// ========== 数据持久化 ==========
void CANController::saveConfig()
{
    qDebug() << "✅ [CANController] 保存配置";
    saveConfigToSettings();
}

void CANController::loadConfig()
{
    qDebug() << "✅ [CANController] 加载配置";
    loadConfigFromSettings();
}

void CANController::resetConfig()
{
    qDebug() << "✅ [CANController] 重置配置";

    // 重新初始化配置
    initializeConfigs();

    // 发送信号
    emit bitrateChanged();
    emit frameTypeChanged();
    emit statusChanged();

    qDebug() << "✅ [CANController] 配置已重置为默认值";
}

void CANController::loadConfigFromSettings()
{
    if (!m_settings) {
        return;
    }

    // 加载每个 CAN 的配置
    for (int i = 0; i < m_canConfigs.size(); ++i) {
        QString prefix = QString("CAN%1/").arg(i);

        m_canConfigs[i].bitrate = m_settings->value(prefix + "bitrate", m_canConfigs[i].bitrate).toInt();
        m_canConfigs[i].frameType = m_settings->value(prefix + "frameType", m_canConfigs[i].frameType).toString();
    }

    // 加载当前 CAN 索引
    m_currentCanIndex = m_settings->value("currentCanIndex", 0).toInt();

    qDebug() << "✅ [CANController] 配置加载完成";
}

void CANController::saveConfigToSettings()
{
    if (!m_settings) {
        return;
    }

    // 保存每个 CAN 的配置
    for (int i = 0; i < m_canConfigs.size(); ++i) {
        QString prefix = QString("CAN%1/").arg(i);

        m_settings->setValue(prefix + "bitrate", m_canConfigs[i].bitrate);
        m_settings->setValue(prefix + "frameType", m_canConfigs[i].frameType);
    }

    // 保存当前 CAN 索引
    m_settings->setValue("currentCanIndex", m_currentCanIndex);

    m_settings->sync();

    qDebug() << "✅ [CANController] 配置保存完成";
}
