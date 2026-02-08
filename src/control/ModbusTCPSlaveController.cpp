// ModbusTCPSlaveController.cpp
// Modbus TCP 从站控制器实现
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现 - 基于 Qt SerialBus 模块
// TODO: 完善功能实现

#include "ModbusTCPSlaveController.h"
#include <QDebug>

ModbusTCPSlaveController::ModbusTCPSlaveController(QObject *parent)
    : QObject(parent)
    , m_modbusServer(nullptr)
    , m_port(502)
    , m_slaveAddress(1)
    , m_maxConnections(5)
    , m_statusText("未启动")
{
    // 创建 Modbus TCP 服务器
    m_modbusServer = new QModbusTcpServer(this);

    // 连接信号
    connect(m_modbusServer, &QModbusServer::stateChanged,
            this, &ModbusTCPSlaveController::handleStateChanged);
    connect(m_modbusServer, &QModbusServer::errorOccurred,
            this, &ModbusTCPSlaveController::handleErrorOccurred);
    connect(m_modbusServer, &QModbusServer::dataWritten,
            this, &ModbusTCPSlaveController::handleDataWritten);

    qDebug() << "✅ [ModbusTCPSlaveController] 初始化完成";
}

ModbusTCPSlaveController::~ModbusTCPSlaveController()
{
    if (m_modbusServer) {
        stopServer();
        delete m_modbusServer;
    }
}

// ========== 连接状态 ==========
bool ModbusTCPSlaveController::isConnected() const
{
    return m_modbusServer && m_modbusServer->state() == QModbusDevice::ConnectedState;
}

// ========== TCP配置 ==========
void ModbusTCPSlaveController::setPort(int port)
{
    if (m_port != port) {
        m_port = port;
        emit portChanged();
    }
}

void ModbusTCPSlaveController::setSlaveAddress(int address)
{
    if (m_slaveAddress != address) {
        m_slaveAddress = address;
        if (m_modbusServer) {
            m_modbusServer->setServerAddress(address);
        }
        emit slaveAddressChanged();
    }
}

void ModbusTCPSlaveController::setMaxConnections(int max)
{
    if (m_maxConnections != max) {
        m_maxConnections = max;
        emit maxConnectionsChanged();
    }
}

// ========== 从站操作 ==========
bool ModbusTCPSlaveController::startServer()
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] Modbus服务器未初始化";
        return false;
    }

    if (isConnected()) {
        qDebug() << "⚠️ [ModbusTCPSlaveController] 服务器已经启动";
        return true;
    }

    // 配置服务器参数
    m_modbusServer->setConnectionParameter(QModbusDevice::NetworkPortParameter, m_port);
    m_modbusServer->setServerAddress(m_slaveAddress);

    // 初始化寄存器（如果还没有初始化）
    initializeRegisters();

    qDebug() << "✅ [ModbusTCPSlaveController] 启动服务器 - 端口:" << m_port << "从站地址:" << m_slaveAddress;

    return m_modbusServer->connectDevice();
}

void ModbusTCPSlaveController::stopServer()
{
    if (m_modbusServer && isConnected()) {
        m_modbusServer->disconnectDevice();
        qDebug() << "✅ [ModbusTCPSlaveController] 服务器已停止";
    }
}

// ========== 寄存器操作 ==========
// ✅ 2026-02-08 [Phase 7.42]: 完善保持寄存器操作
bool ModbusTCPSlaveController::setHoldingRegister(int address, int value)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::HoldingRegisters, address, 1);
    unit.setValue(0, static_cast<quint16>(value));

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusTCPSlaveController] 设置保持寄存器失败:" << address;
        return false;
    }

    qDebug() << "✅ [ModbusTCPSlaveController] 设置保持寄存器:" << address << "值:" << value;
    return true;
}

int ModbusTCPSlaveController::getHoldingRegister(int address)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return 0;
    }

    quint16 value = 0;
    if (!m_modbusServer->data(QModbusDataUnit::HoldingRegisters, address, &value)) {
        qWarning() << "❌ [ModbusTCPSlaveController] 获取保持寄存器失败:" << address;
        return 0;
    }

    return static_cast<int>(value);
}

bool ModbusTCPSlaveController::setHoldingRegisters(int startAddress, const QList<int> &values)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return false;
    }

    if (values.isEmpty()) {
        return true;
    }

    QModbusDataUnit unit(QModbusDataUnit::HoldingRegisters, startAddress, values.size());
    for (int i = 0; i < values.size(); ++i) {
        unit.setValue(i, static_cast<quint16>(values[i]));
    }

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusTCPSlaveController] 设置多个保持寄存器失败:" << startAddress;
        return false;
    }

    qDebug() << "✅ [ModbusTCPSlaveController] 设置多个保持寄存器:" << startAddress << "数量:" << values.size();
    return true;
}

QList<int> ModbusTCPSlaveController::getHoldingRegisters(int startAddress, int count)
{
    QList<int> result;
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return result;
    }

    for (int i = 0; i < count; ++i) {
        quint16 value = 0;
        if (m_modbusServer->data(QModbusDataUnit::HoldingRegisters, startAddress + i, &value)) {
            result.append(static_cast<int>(value));
        } else {
            result.append(0);
        }
    }

    return result;
}

// ✅ 2026-02-08 [Phase 7.42]: 完善输入寄存器操作
bool ModbusTCPSlaveController::setInputRegister(int address, int value)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::InputRegisters, address, 1);
    unit.setValue(0, static_cast<quint16>(value));

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusTCPSlaveController] 设置输入寄存器失败:" << address;
        return false;
    }

    qDebug() << "✅ [ModbusTCPSlaveController] 设置输入寄存器:" << address << "值:" << value;
    return true;
}

int ModbusTCPSlaveController::getInputRegister(int address)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return 0;
    }

    quint16 value = 0;
    if (!m_modbusServer->data(QModbusDataUnit::InputRegisters, address, &value)) {
        qWarning() << "❌ [ModbusTCPSlaveController] 获取输入寄存器失败:" << address;
        return 0;
    }

    return static_cast<int>(value);
}

bool ModbusTCPSlaveController::setInputRegisters(int startAddress, const QList<int> &values)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return false;
    }

    if (values.isEmpty()) {
        return true;
    }

    QModbusDataUnit unit(QModbusDataUnit::InputRegisters, startAddress, values.size());
    for (int i = 0; i < values.size(); ++i) {
        unit.setValue(i, static_cast<quint16>(values[i]));
    }

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusTCPSlaveController] 设置多个输入寄存器失败:" << startAddress;
        return false;
    }

    qDebug() << "✅ [ModbusTCPSlaveController] 设置多个输入寄存器:" << startAddress << "数量:" << values.size();
    return true;
}

QList<int> ModbusTCPSlaveController::getInputRegisters(int startAddress, int count)
{
    QList<int> result;
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return result;
    }

    for (int i = 0; i < count; ++i) {
        quint16 value = 0;
        if (m_modbusServer->data(QModbusDataUnit::InputRegisters, startAddress + i, &value)) {
            result.append(static_cast<int>(value));
        } else {
            result.append(0);
        }
    }

    return result;
}

// ✅ 2026-02-08 [Phase 7.42]: 完善线圈操作
bool ModbusTCPSlaveController::setCoil(int address, bool value)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::Coils, address, 1);
    unit.setValue(0, value ? 1 : 0);

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusTCPSlaveController] 设置线圈失败:" << address;
        return false;
    }

    qDebug() << "✅ [ModbusTCPSlaveController] 设置线圈:" << address << "值:" << value;
    return true;
}

bool ModbusTCPSlaveController::getCoil(int address)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return false;
    }

    quint16 value = 0;
    if (!m_modbusServer->data(QModbusDataUnit::Coils, address, &value)) {
        qWarning() << "❌ [ModbusTCPSlaveController] 获取线圈失败:" << address;
        return false;
    }

    return value != 0;
}

bool ModbusTCPSlaveController::setCoils(int startAddress, const QList<bool> &values)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return false;
    }

    if (values.isEmpty()) {
        return true;
    }

    QModbusDataUnit unit(QModbusDataUnit::Coils, startAddress, values.size());
    for (int i = 0; i < values.size(); ++i) {
        unit.setValue(i, values[i] ? 1 : 0);
    }

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusTCPSlaveController] 设置多个线圈失败:" << startAddress;
        return false;
    }

    qDebug() << "✅ [ModbusTCPSlaveController] 设置多个线圈:" << startAddress << "数量:" << values.size();
    return true;
}

QList<bool> ModbusTCPSlaveController::getCoils(int startAddress, int count)
{
    QList<bool> result;
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return result;
    }

    for (int i = 0; i < count; ++i) {
        quint16 value = 0;
        if (m_modbusServer->data(QModbusDataUnit::Coils, startAddress + i, &value)) {
            result.append(value != 0);
        } else {
            result.append(false);
        }
    }

    return result;
}

// ✅ 2026-02-08 [Phase 7.42]: 完善离散输入操作
bool ModbusTCPSlaveController::setDiscreteInput(int address, bool value)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::DiscreteInputs, address, 1);
    unit.setValue(0, value ? 1 : 0);

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusTCPSlaveController] 设置离散输入失败:" << address;
        return false;
    }

    qDebug() << "✅ [ModbusTCPSlaveController] 设置离散输入:" << address << "值:" << value;
    return true;
}

bool ModbusTCPSlaveController::getDiscreteInput(int address)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return false;
    }

    quint16 value = 0;
    if (!m_modbusServer->data(QModbusDataUnit::DiscreteInputs, address, &value)) {
        qWarning() << "❌ [ModbusTCPSlaveController] 获取离散输入失败:" << address;
        return false;
    }

    return value != 0;
}

bool ModbusTCPSlaveController::setDiscreteInputs(int startAddress, const QList<bool> &values)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return false;
    }

    if (values.isEmpty()) {
        return true;
    }

    QModbusDataUnit unit(QModbusDataUnit::DiscreteInputs, startAddress, values.size());
    for (int i = 0; i < values.size(); ++i) {
        unit.setValue(i, values[i] ? 1 : 0);
    }

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusTCPSlaveController] 设置多个离散输入失败:" << startAddress;
        return false;
    }

    qDebug() << "✅ [ModbusTCPSlaveController] 设置多个离散输入:" << startAddress << "数量:" << values.size();
    return true;
}

QList<bool> ModbusTCPSlaveController::getDiscreteInputs(int startAddress, int count)
{
    QList<bool> result;
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusTCPSlaveController] 服务器未初始化";
        return result;
    }

    for (int i = 0; i < count; ++i) {
        quint16 value = 0;
        if (m_modbusServer->data(QModbusDataUnit::DiscreteInputs, startAddress + i, &value)) {
            result.append(value != 0);
        } else {
            result.append(false);
        }
    }

    return result;
}

// ========== 寄存器映射管理 ==========
// ✅ 2026-02-08 [Phase 7.42]: 完善寄存器初始化
void ModbusTCPSlaveController::initializeRegisters(int holdingCount, int inputCount,
                                                    int coilCount, int discreteCount)
{
    if (!m_modbusServer) {
        return;
    }

    // 创建寄存器映射
    QModbusDataUnitMap reg;
    reg.insert(QModbusDataUnit::Coils, { QModbusDataUnit::Coils, 0, static_cast<quint16>(coilCount) });
    reg.insert(QModbusDataUnit::DiscreteInputs, { QModbusDataUnit::DiscreteInputs, 0, static_cast<quint16>(discreteCount) });
    reg.insert(QModbusDataUnit::InputRegisters, { QModbusDataUnit::InputRegisters, 0, static_cast<quint16>(inputCount) });
    reg.insert(QModbusDataUnit::HoldingRegisters, { QModbusDataUnit::HoldingRegisters, 0, static_cast<quint16>(holdingCount) });

    if (!m_modbusServer->setMap(reg)) {
        qWarning() << "❌ [ModbusTCPSlaveController] 初始化寄存器映射失败";
        return;
    }

    qDebug() << "✅ [ModbusTCPSlaveController] 初始化寄存器映射成功:"
             << "保持寄存器:" << holdingCount
             << "输入寄存器:" << inputCount
             << "线圈:" << coilCount
             << "离散输入:" << discreteCount;
}

void ModbusTCPSlaveController::clearAllRegisters()
{
    if (!m_modbusServer) {
        return;
    }

    // 重新初始化寄存器（清零）
    initializeRegisters();
    qDebug() << "✅ [ModbusTCPSlaveController] 清除所有寄存器完成";
}

// ========== 私有槽函数 ==========
void ModbusTCPSlaveController::handleStateChanged(QModbusDevice::State state)
{
    qDebug() << "✅ [ModbusTCPSlaveController] 状态变化:" << state;
    updateStatusText();
    emit isConnectedChanged();
}

void ModbusTCPSlaveController::handleErrorOccurred(QModbusDevice::Error error)
{
    QString errorString = m_modbusServer->errorString();
    qWarning() << "❌ [ModbusTCPSlaveController] 错误:" << error << errorString;
    emit errorOccurred(errorString);
}

// ✅ 2026-02-08 [Phase 7.42]: 完善数据写入处理
void ModbusTCPSlaveController::handleDataWritten(QModbusDataUnit::RegisterType table, int address, int size)
{
    qDebug() << "✅ [ModbusTCPSlaveController] 数据写入 - 表:" << table << "地址:" << address << "大小:" << size;

    // 发送数据写入信号，获取实际值
    if (table == QModbusDataUnit::HoldingRegisters) {
        for (int i = 0; i < size; ++i) {
            int value = getHoldingRegister(address + i);
            emit holdingRegisterWritten(address + i, value);
        }
    } else if (table == QModbusDataUnit::Coils) {
        for (int i = 0; i < size; ++i) {
            bool value = getCoil(address + i);
            emit coilWritten(address + i, value);
        }
    }
}

// ========== 辅助函数 ==========
void ModbusTCPSlaveController::updateStatusText()
{
    QString newStatus;
    if (!m_modbusServer) {
        newStatus = "未初始化";
    } else {
        switch (m_modbusServer->state()) {
        case QModbusDevice::UnconnectedState:
            newStatus = "未启动";
            break;
        case QModbusDevice::ConnectingState:
            newStatus = "启动中...";
            break;
        case QModbusDevice::ConnectedState:
            newStatus = QString("运行中 (端口:%1)").arg(m_port);
            break;
        case QModbusDevice::ClosingState:
            newStatus = "停止中...";
            break;
        }
    }

    if (m_statusText != newStatus) {
        m_statusText = newStatus;
        emit statusTextChanged();
    }
}
