// ✅ 2026-02-06: FIX 100.300.113 Phase 7.40 - ModbusSlaveController RTU 从站实现
// MODBUS RTU 从站控制器实现 - 基于 Qt SerialBus 模块

#include "ModbusSlaveController.h"
#include <QDebug>

ModbusSlaveController::ModbusSlaveController(QObject *parent)
    : QObject(parent)
    , m_modbusServer(nullptr)
    , m_portName("/dev/ttyS0")
    , m_baudRate(9600)
    , m_dataBits(8)
    , m_stopBits(1)
    , m_parity("None")
    , m_slaveAddress(1)
    , m_statusText("未连接")
{
    qDebug() << "✅ [ModbusSlaveController] 构造函数";

    // 创建 MODBUS RTU 从站设备
    m_modbusServer = new QModbusRtuSerialServer(this);

    // 连接信号
    connect(m_modbusServer, &QModbusServer::stateChanged,
            this, &ModbusSlaveController::handleStateChanged);
    connect(m_modbusServer, &QModbusServer::errorOccurred,
            this, &ModbusSlaveController::handleErrorOccurred);
    connect(m_modbusServer, &QModbusServer::dataWritten,
            this, &ModbusSlaveController::handleDataWritten);

    // 初始化寄存器（默认100个寄存器）
    initializeRegisters(100, 100, 100, 100);
}

ModbusSlaveController::~ModbusSlaveController()
{
    qDebug() << "✅ [ModbusSlaveController] 析构函数";
    if (m_modbusServer) {
        stopSlave();
        delete m_modbusServer;
        m_modbusServer = nullptr;
    }
}

// ========== 连接状态 ==========

bool ModbusSlaveController::isConnected() const
{
    return m_modbusServer && m_modbusServer->state() == QModbusDevice::ConnectedState;
}

// ========== 串口配置 ==========

void ModbusSlaveController::setPortName(const QString &portName)
{
    if (m_portName != portName) {
        m_portName = portName;
        emit portNameChanged();
        qDebug() << "✅ [ModbusSlaveController] 设置串口名称:" << m_portName;
    }
}

void ModbusSlaveController::setBaudRate(int baudRate)
{
    if (m_baudRate != baudRate) {
        m_baudRate = baudRate;
        emit baudRateChanged();
        qDebug() << "✅ [ModbusSlaveController] 设置波特率:" << m_baudRate;
    }
}

void ModbusSlaveController::setDataBits(int dataBits)
{
    if (m_dataBits != dataBits) {
        m_dataBits = dataBits;
        emit dataBitsChanged();
        qDebug() << "✅ [ModbusSlaveController] 设置数据位:" << m_dataBits;
    }
}

void ModbusSlaveController::setStopBits(int stopBits)
{
    if (m_stopBits != stopBits) {
        m_stopBits = stopBits;
        emit stopBitsChanged();
        qDebug() << "✅ [ModbusSlaveController] 设置停止位:" << m_stopBits;
    }
}

void ModbusSlaveController::setParity(const QString &parity)
{
    if (m_parity != parity) {
        m_parity = parity;
        emit parityChanged();
        qDebug() << "✅ [ModbusSlaveController] 设置校验位:" << m_parity;
    }
}

// ========== 从站地址 ==========

void ModbusSlaveController::setSlaveAddress(int address)
{
    if (m_slaveAddress != address) {
        m_slaveAddress = address;
        emit slaveAddressChanged();
        qDebug() << "✅ [ModbusSlaveController] 设置从站地址:" << m_slaveAddress;

        // 如果从站已连接，更新从站地址
        if (isConnected()) {
            m_modbusServer->setServerAddress(m_slaveAddress);
        }
    }
}

// ========== 从站操作 ==========

bool ModbusSlaveController::startSlave()
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return false;
    }

    if (isConnected()) {
        qWarning() << "⚠️ [ModbusSlaveController] 从站已经连接";
        return true;
    }

    qDebug() << "✅ [ModbusSlaveController] 启动 MODBUS RTU 从站";
    qDebug() << "   - 串口:" << m_portName;
    qDebug() << "   - 波特率:" << m_baudRate;
    qDebug() << "   - 数据位:" << m_dataBits;
    qDebug() << "   - 停止位:" << m_stopBits;
    qDebug() << "   - 校验位:" << m_parity;
    qDebug() << "   - 从站地址:" << m_slaveAddress;

    // 配置串口参数
    m_modbusServer->setConnectionParameter(QModbusDevice::SerialPortNameParameter, m_portName);
    m_modbusServer->setConnectionParameter(QModbusDevice::SerialBaudRateParameter, m_baudRate);
    m_modbusServer->setConnectionParameter(QModbusDevice::SerialDataBitsParameter, convertDataBits(m_dataBits));
    m_modbusServer->setConnectionParameter(QModbusDevice::SerialStopBitsParameter, convertStopBits(m_stopBits));
    m_modbusServer->setConnectionParameter(QModbusDevice::SerialParityParameter, convertParity(m_parity));

    // 设置从站地址
    m_modbusServer->setServerAddress(m_slaveAddress);

    // 连接从站
    if (!m_modbusServer->connectDevice()) {
        QString error = m_modbusServer->errorString();
        qWarning() << "❌ [ModbusSlaveController] 启动从站失败:" << error;
        emit errorOccurred(error);
        return false;
    }

    qDebug() << "✅ [ModbusSlaveController] 从站启动成功";
    return true;
}

void ModbusSlaveController::stopSlave()
{
    if (!m_modbusServer) {
        return;
    }

    if (isConnected()) {
        qDebug() << "✅ [ModbusSlaveController] 停止 MODBUS RTU 从站";
        m_modbusServer->disconnectDevice();
    }
}

// ========== 寄存器操作 ==========

// ========== 保持寄存器（Holding Registers）==========

bool ModbusSlaveController::setHoldingRegister(int address, int value)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::HoldingRegisters, address, 1);
    unit.setValue(0, static_cast<quint16>(value));

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusSlaveController] 设置保持寄存器失败 - 地址:" << address;
        return false;
    }

    qDebug() << "✅ [ModbusSlaveController] 设置保持寄存器 - 地址:" << address << "值:" << value;
    return true;
}

int ModbusSlaveController::getHoldingRegister(int address)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return 0;
    }

    QModbusDataUnit unit(QModbusDataUnit::HoldingRegisters, address, 1);
    if (!m_modbusServer->data(&unit)) {
        qWarning() << "❌ [ModbusSlaveController] 读取保持寄存器失败 - 地址:" << address;
        return 0;
    }

    int value = unit.value(0);
    qDebug() << "✅ [ModbusSlaveController] 读取保持寄存器 - 地址:" << address << "值:" << value;
    return value;
}

bool ModbusSlaveController::setHoldingRegisters(int startAddress, const QList<int> &values)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::HoldingRegisters, startAddress, values.size());
    for (int i = 0; i < values.size(); ++i) {
        unit.setValue(i, static_cast<quint16>(values[i]));
    }

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusSlaveController] 设置保持寄存器失败 - 起始地址:" << startAddress;
        return false;
    }

    qDebug() << "✅ [ModbusSlaveController] 设置保持寄存器 - 起始地址:" << startAddress << "数量:" << values.size();
    return true;
}

QList<int> ModbusSlaveController::getHoldingRegisters(int startAddress, int count)
{
    QList<int> result;

    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return result;
    }

    QModbusDataUnit unit(QModbusDataUnit::HoldingRegisters, startAddress, count);
    if (!m_modbusServer->data(&unit)) {
        qWarning() << "❌ [ModbusSlaveController] 读取保持寄存器失败 - 起始地址:" << startAddress;
        return result;
    }

    for (int i = 0; i < count; ++i) {
        result.append(unit.value(i));
    }

    qDebug() << "✅ [ModbusSlaveController] 读取保持寄存器 - 起始地址:" << startAddress << "数量:" << count;
    return result;
}

// ========== 输入寄存器（Input Registers）==========

bool ModbusSlaveController::setInputRegister(int address, int value)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::InputRegisters, address, 1);
    unit.setValue(0, static_cast<quint16>(value));

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusSlaveController] 设置输入寄存器失败 - 地址:" << address;
        return false;
    }

    qDebug() << "✅ [ModbusSlaveController] 设置输入寄存器 - 地址:" << address << "值:" << value;
    return true;
}

int ModbusSlaveController::getInputRegister(int address)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return 0;
    }

    QModbusDataUnit unit(QModbusDataUnit::InputRegisters, address, 1);
    if (!m_modbusServer->data(&unit)) {
        qWarning() << "❌ [ModbusSlaveController] 读取输入寄存器失败 - 地址:" << address;
        return 0;
    }

    int value = unit.value(0);
    qDebug() << "✅ [ModbusSlaveController] 读取输入寄存器 - 地址:" << address << "值:" << value;
    return value;
}

bool ModbusSlaveController::setInputRegisters(int startAddress, const QList<int> &values)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::InputRegisters, startAddress, values.size());
    for (int i = 0; i < values.size(); ++i) {
        unit.setValue(i, static_cast<quint16>(values[i]));
    }

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusSlaveController] 设置输入寄存器失败 - 起始地址:" << startAddress;
        return false;
    }

    qDebug() << "✅ [ModbusSlaveController] 设置输入寄存器 - 起始地址:" << startAddress << "数量:" << values.size();
    return true;
}

QList<int> ModbusSlaveController::getInputRegisters(int startAddress, int count)
{
    QList<int> result;

    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return result;
    }

    QModbusDataUnit unit(QModbusDataUnit::InputRegisters, startAddress, count);
    if (!m_modbusServer->data(&unit)) {
        qWarning() << "❌ [ModbusSlaveController] 读取输入寄存器失败 - 起始地址:" << startAddress;
        return result;
    }

    for (int i = 0; i < count; ++i) {
        result.append(unit.value(i));
    }

    qDebug() << "✅ [ModbusSlaveController] 读取输入寄存器 - 起始地址:" << startAddress << "数量:" << count;
    return result;
}

// ========== 线圈（Coils）==========

bool ModbusSlaveController::setCoil(int address, bool value)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::Coils, address, 1);
    unit.setValue(0, value ? 1 : 0);

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusSlaveController] 设置线圈失败 - 地址:" << address;
        return false;
    }

    qDebug() << "✅ [ModbusSlaveController] 设置线圈 - 地址:" << address << "值:" << value;
    return true;
}

bool ModbusSlaveController::getCoil(int address)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::Coils, address, 1);
    if (!m_modbusServer->data(&unit)) {
        qWarning() << "❌ [ModbusSlaveController] 读取线圈失败 - 地址:" << address;
        return false;
    }

    bool value = unit.value(0) != 0;
    qDebug() << "✅ [ModbusSlaveController] 读取线圈 - 地址:" << address << "值:" << value;
    return value;
}

bool ModbusSlaveController::setCoils(int startAddress, const QList<bool> &values)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::Coils, startAddress, values.size());
    for (int i = 0; i < values.size(); ++i) {
        unit.setValue(i, values[i] ? 1 : 0);
    }

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusSlaveController] 设置线圈失败 - 起始地址:" << startAddress;
        return false;
    }

    qDebug() << "✅ [ModbusSlaveController] 设置线圈 - 起始地址:" << startAddress << "数量:" << values.size();
    return true;
}

QList<bool> ModbusSlaveController::getCoils(int startAddress, int count)
{
    QList<bool> result;

    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return result;
    }

    QModbusDataUnit unit(QModbusDataUnit::Coils, startAddress, count);
    if (!m_modbusServer->data(&unit)) {
        qWarning() << "❌ [ModbusSlaveController] 读取线圈失败 - 起始地址:" << startAddress;
        return result;
    }

    for (int i = 0; i < count; ++i) {
        result.append(unit.value(i) != 0);
    }

    qDebug() << "✅ [ModbusSlaveController] 读取线圈 - 起始地址:" << startAddress << "数量:" << count;
    return result;
}

// ========== 离散输入（Discrete Inputs）==========

bool ModbusSlaveController::setDiscreteInput(int address, bool value)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::DiscreteInputs, address, 1);
    unit.setValue(0, value ? 1 : 0);

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusSlaveController] 设置离散输入失败 - 地址:" << address;
        return false;
    }

    qDebug() << "✅ [ModbusSlaveController] 设置离散输入 - 地址:" << address << "值:" << value;
    return true;
}

bool ModbusSlaveController::getDiscreteInput(int address)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::DiscreteInputs, address, 1);
    if (!m_modbusServer->data(&unit)) {
        qWarning() << "❌ [ModbusSlaveController] 读取离散输入失败 - 地址:" << address;
        return false;
    }

    bool value = unit.value(0) != 0;
    qDebug() << "✅ [ModbusSlaveController] 读取离散输入 - 地址:" << address << "值:" << value;
    return value;
}

bool ModbusSlaveController::setDiscreteInputs(int startAddress, const QList<bool> &values)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return false;
    }

    QModbusDataUnit unit(QModbusDataUnit::DiscreteInputs, startAddress, values.size());
    for (int i = 0; i < values.size(); ++i) {
        unit.setValue(i, values[i] ? 1 : 0);
    }

    if (!m_modbusServer->setData(unit)) {
        qWarning() << "❌ [ModbusSlaveController] 设置离散输入失败 - 起始地址:" << startAddress;
        return false;
    }

    qDebug() << "✅ [ModbusSlaveController] 设置离散输入 - 起始地址:" << startAddress << "数量:" << values.size();
    return true;
}

QList<bool> ModbusSlaveController::getDiscreteInputs(int startAddress, int count)
{
    QList<bool> result;

    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return result;
    }

    QModbusDataUnit unit(QModbusDataUnit::DiscreteInputs, startAddress, count);
    if (!m_modbusServer->data(&unit)) {
        qWarning() << "❌ [ModbusSlaveController] 读取离散输入失败 - 起始地址:" << startAddress;
        return result;
    }

    for (int i = 0; i < count; ++i) {
        result.append(unit.value(i) != 0);
    }

    qDebug() << "✅ [ModbusSlaveController] 读取离散输入 - 起始地址:" << startAddress << "数量:" << count;
    return result;
}

// ========== 寄存器映射管理 ==========

void ModbusSlaveController::initializeRegisters(int holdingCount, int inputCount,
                                                 int coilCount, int discreteCount)
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return;
    }

    qDebug() << "✅ [ModbusSlaveController] 初始化寄存器映射";
    qDebug() << "   - 保持寄存器数量:" << holdingCount;
    qDebug() << "   - 输入寄存器数量:" << inputCount;
    qDebug() << "   - 线圈数量:" << coilCount;
    qDebug() << "   - 离散输入数量:" << discreteCount;

    // 初始化保持寄存器（可读写）
    QModbusDataUnitMap registerMap;
    registerMap.insert(QModbusDataUnit::HoldingRegisters,
                       QModbusDataUnit(QModbusDataUnit::HoldingRegisters, 0, holdingCount));

    // 初始化输入寄存器（只读）
    registerMap.insert(QModbusDataUnit::InputRegisters,
                       QModbusDataUnit(QModbusDataUnit::InputRegisters, 0, inputCount));

    // 初始化线圈（可读写）
    registerMap.insert(QModbusDataUnit::Coils,
                       QModbusDataUnit(QModbusDataUnit::Coils, 0, coilCount));

    // 初始化离散输入（只读）
    registerMap.insert(QModbusDataUnit::DiscreteInputs,
                       QModbusDataUnit(QModbusDataUnit::DiscreteInputs, 0, discreteCount));

    // 设置寄存器映射
    m_modbusServer->setMap(registerMap);

    qDebug() << "✅ [ModbusSlaveController] 寄存器映射初始化完成";
}

void ModbusSlaveController::clearAllRegisters()
{
    if (!m_modbusServer) {
        qWarning() << "❌ [ModbusSlaveController] MODBUS 从站设备未初始化";
        return;
    }

    qDebug() << "✅ [ModbusSlaveController] 清除所有寄存器";

    // 重新初始化寄存器（所有值归零）
    initializeRegisters(100, 100, 100, 100);
}

// ========== 私有槽函数 ==========

void ModbusSlaveController::handleStateChanged(QModbusDevice::State state)
{
    qDebug() << "✅ [ModbusSlaveController] 状态变化:" << state;

    switch (state) {
    case QModbusDevice::UnconnectedState:
        qDebug() << "   - 状态: 未连接";
        break;
    case QModbusDevice::ConnectingState:
        qDebug() << "   - 状态: 正在连接";
        break;
    case QModbusDevice::ConnectedState:
        qDebug() << "   - 状态: 已连接";
        break;
    case QModbusDevice::ClosingState:
        qDebug() << "   - 状态: 正在关闭";
        break;
    }

    emit isConnectedChanged();
    updateStatusText();
}

void ModbusSlaveController::handleErrorOccurred(QModbusDevice::Error error)
{
    if (error == QModbusDevice::NoError) {
        return;
    }

    QString errorString = m_modbusServer->errorString();
    qWarning() << "❌ [ModbusSlaveController] 错误:" << errorString;

    emit errorOccurred(errorString);
    updateStatusText();
}

void ModbusSlaveController::handleDataWritten(QModbusDataUnit::RegisterType table, int address, int size)
{
    qDebug() << "✅ [ModbusSlaveController] 数据被写入 - 表类型:" << table << "地址:" << address << "数量:" << size;

    // 根据表类型发送相应的信号
    switch (table) {
    case QModbusDataUnit::HoldingRegisters:
        for (int i = 0; i < size; ++i) {
            int value = getHoldingRegister(address + i);
            emit holdingRegisterWritten(address + i, value);
        }
        break;
    case QModbusDataUnit::Coils:
        for (int i = 0; i < size; ++i) {
            bool value = getCoil(address + i);
            emit coilWritten(address + i, value);
        }
        break;
    default:
        break;
    }
}

// ========== 辅助函数 ==========

void ModbusSlaveController::updateStatusText()
{
    QString newStatus;

    if (!m_modbusServer) {
        newStatus = "未初始化";
    } else {
        switch (m_modbusServer->state()) {
        case QModbusDevice::UnconnectedState:
            newStatus = "未连接";
            break;
        case QModbusDevice::ConnectingState:
            newStatus = "正在连接";
            break;
        case QModbusDevice::ConnectedState:
            newStatus = QString("已连接 (从站地址: %1)").arg(m_slaveAddress);
            break;
        case QModbusDevice::ClosingState:
            newStatus = "正在关闭";
            break;
        }

        if (m_modbusServer->error() != QModbusDevice::NoError) {
            newStatus += " - 错误: " + m_modbusServer->errorString();
        }
    }

    if (m_statusText != newStatus) {
        m_statusText = newStatus;
        emit statusTextChanged();
    }
}

QSerialPort::Parity ModbusSlaveController::convertParity(const QString &parity)
{
    if (parity == "Even") {
        return QSerialPort::EvenParity;
    } else if (parity == "Odd") {
        return QSerialPort::OddParity;
    } else if (parity == "Space") {
        return QSerialPort::SpaceParity;
    } else if (parity == "Mark") {
        return QSerialPort::MarkParity;
    } else {
        return QSerialPort::NoParity;
    }
}

QSerialPort::DataBits ModbusSlaveController::convertDataBits(int dataBits)
{
    switch (dataBits) {
    case 5:
        return QSerialPort::Data5;
    case 6:
        return QSerialPort::Data6;
    case 7:
        return QSerialPort::Data7;
    case 8:
    default:
        return QSerialPort::Data8;
    }
}

QSerialPort::StopBits ModbusSlaveController::convertStopBits(int stopBits)
{
    switch (stopBits) {
    case 1:
        return QSerialPort::OneStop;
    case 2:
        return QSerialPort::TwoStop;
    default:
        return QSerialPort::OneStop;
    }
}
