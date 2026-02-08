// ModbusTCPMasterController.cpp
// Modbus TCP 主站控制器实现
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现 - 基于 Qt SerialBus 模块
// TODO: 完善功能实现

#include "ModbusTCPMasterController.h"
#include <QDebug>

ModbusTCPMasterController::ModbusTCPMasterController(QObject *parent)
    : QObject(parent)
    , m_modbusClient(nullptr)
    , m_targetIP("192.168.1.1")
    , m_port(502)
    , m_slaveAddress(1)
    , m_pollInterval(1000)
    , m_timeout(3000)
    , m_retryCount(3)
    , m_pollTimer(new QTimer(this))
    , m_statusText("未连接")
{
    // 创建 Modbus TCP 客户端
    m_modbusClient = new QModbusTcpClient(this);

    // 连接信号
    connect(m_modbusClient, &QModbusClient::stateChanged,
            this, &ModbusTCPMasterController::handleStateChanged);
    connect(m_modbusClient, &QModbusClient::errorOccurred,
            this, &ModbusTCPMasterController::handleErrorOccurred);

    // 配置轮询定时器
    connect(m_pollTimer, &QTimer::timeout,
            this, &ModbusTCPMasterController::handlePollTimeout);

    qDebug() << "✅ [ModbusTCPMasterController] 初始化完成";
}

ModbusTCPMasterController::~ModbusTCPMasterController()
{
    if (m_modbusClient) {
        disconnectFromServer();
        delete m_modbusClient;
    }
}

// ========== 连接状态 ==========
bool ModbusTCPMasterController::isConnected() const
{
    return m_modbusClient && m_modbusClient->state() == QModbusDevice::ConnectedState;
}

// ========== TCP配置 ==========
void ModbusTCPMasterController::setTargetIP(const QString &ip)
{
    if (m_targetIP != ip) {
        m_targetIP = ip;
        emit targetIPChanged();
    }
}

void ModbusTCPMasterController::setPort(int port)
{
    if (m_port != port) {
        m_port = port;
        emit portChanged();
    }
}

void ModbusTCPMasterController::setSlaveAddress(int address)
{
    if (m_slaveAddress != address) {
        m_slaveAddress = address;
        emit slaveAddressChanged();
    }
}

// ========== 轮询配置 ==========
void ModbusTCPMasterController::setPollInterval(int interval)
{
    if (m_pollInterval != interval) {
        m_pollInterval = interval;
        emit pollIntervalChanged();
    }
}

void ModbusTCPMasterController::setTimeout(int timeout)
{
    if (m_timeout != timeout) {
        m_timeout = timeout;
        emit timeoutChanged();
    }
}

void ModbusTCPMasterController::setRetryCount(int count)
{
    if (m_retryCount != count) {
        m_retryCount = count;
        emit retryCountChanged();
    }
}

// ========== 主站操作 ==========
bool ModbusTCPMasterController::connectToServer()
{
    if (!m_modbusClient) {
        qWarning() << "❌ [ModbusTCPMasterController] Modbus客户端未初始化";
        return false;
    }

    if (isConnected()) {
        qDebug() << "⚠️ [ModbusTCPMasterController] 已经连接";
        return true;
    }

    // 配置连接参数
    m_modbusClient->setConnectionParameter(QModbusDevice::NetworkAddressParameter, m_targetIP);
    m_modbusClient->setConnectionParameter(QModbusDevice::NetworkPortParameter, m_port);
    m_modbusClient->setTimeout(m_timeout);
    m_modbusClient->setNumberOfRetries(m_retryCount);

    qDebug() << "✅ [ModbusTCPMasterController] 连接到服务器:" << m_targetIP << ":" << m_port;

    return m_modbusClient->connectDevice();
}

void ModbusTCPMasterController::disconnectFromServer()
{
    if (m_modbusClient && isConnected()) {
        stopPolling();
        m_modbusClient->disconnectDevice();
        qDebug() << "✅ [ModbusTCPMasterController] 已断开连接";
    }
}

void ModbusTCPMasterController::startPolling()
{
    if (m_pollInterval > 0) {
        m_pollTimer->start(m_pollInterval);
        qDebug() << "✅ [ModbusTCPMasterController] 开始轮询 - 间隔:" << m_pollInterval << "ms";
    }
}

void ModbusTCPMasterController::stopPolling()
{
    m_pollTimer->stop();
    qDebug() << "✅ [ModbusTCPMasterController] 停止轮询";
}

// ========== 读取操作 ==========
bool ModbusTCPMasterController::readHoldingRegisters(int startAddress, int count)
{
    // TODO: 实现读取保持寄存器
    qDebug() << "TODO: readHoldingRegisters" << startAddress << count;
    return false;
}

bool ModbusTCPMasterController::readInputRegisters(int startAddress, int count)
{
    // TODO: 实现读取输入寄存器
    qDebug() << "TODO: readInputRegisters" << startAddress << count;
    return false;
}

bool ModbusTCPMasterController::readCoils(int startAddress, int count)
{
    // TODO: 实现读取线圈
    qDebug() << "TODO: readCoils" << startAddress << count;
    return false;
}

bool ModbusTCPMasterController::readDiscreteInputs(int startAddress, int count)
{
    // TODO: 实现读取离散输入
    qDebug() << "TODO: readDiscreteInputs" << startAddress << count;
    return false;
}

// ========== 写入操作 ==========
bool ModbusTCPMasterController::writeHoldingRegister(int address, int value)
{
    // TODO: 实现写入单个保持寄存器
    qDebug() << "TODO: writeHoldingRegister" << address << value;
    return false;
}

bool ModbusTCPMasterController::writeHoldingRegisters(int startAddress, const QList<int> &values)
{
    // TODO: 实现写入多个保持寄存器
    qDebug() << "TODO: writeHoldingRegisters" << startAddress << values.size();
    return false;
}

bool ModbusTCPMasterController::writeCoil(int address, bool value)
{
    // TODO: 实现写入单个线圈
    qDebug() << "TODO: writeCoil" << address << value;
    return false;
}

bool ModbusTCPMasterController::writeCoils(int startAddress, const QList<bool> &values)
{
    // TODO: 实现写入多个线圈
    qDebug() << "TODO: writeCoils" << startAddress << values.size();
    return false;
}

// ========== 私有槽函数 ==========
void ModbusTCPMasterController::handleStateChanged(QModbusDevice::State state)
{
    qDebug() << "✅ [ModbusTCPMasterController] 状态变化:" << state;
    updateStatusText();
    emit isConnectedChanged();
}

void ModbusTCPMasterController::handleErrorOccurred(QModbusDevice::Error error)
{
    QString errorString = m_modbusClient->errorString();
    qWarning() << "❌ [ModbusTCPMasterController] 错误:" << error << errorString;
    emit errorOccurred(errorString);
}

void ModbusTCPMasterController::handleReadReady()
{
    // TODO: 处理读取完成
    qDebug() << "TODO: handleReadReady";
}

void ModbusTCPMasterController::handlePollTimeout()
{
    // TODO: 处理轮询超时
    // qDebug() << "TODO: handlePollTimeout";
}

// ========== 辅助函数 ==========
void ModbusTCPMasterController::updateStatusText()
{
    QString newStatus;
    if (!m_modbusClient) {
        newStatus = "未初始化";
    } else {
        switch (m_modbusClient->state()) {
        case QModbusDevice::UnconnectedState:
            newStatus = "未连接";
            break;
        case QModbusDevice::ConnectingState:
            newStatus = "连接中...";
            break;
        case QModbusDevice::ConnectedState:
            newStatus = QString("已连接 (%1:%2)").arg(m_targetIP).arg(m_port);
            break;
        case QModbusDevice::ClosingState:
            newStatus = "断开中...";
            break;
        }
    }

    if (m_statusText != newStatus) {
        m_statusText = newStatus;
        emit statusTextChanged();
    }
}
