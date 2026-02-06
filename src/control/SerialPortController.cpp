// ✅ 2026-02-06: FIX 100.300.113 Phase 7.38.1 - SerialPortController 实现
// 串口控制器类实现 - 管理6个串口的配置和通信

#include "SerialPortController.h"
#include <QDebug>
#include <QSerialPortInfo>

// ========== 构造函数和析构函数 ==========

SerialPortController::SerialPortController(QObject *parent)
    : QObject(parent)
    , m_currentPortIndex(0)
    , m_currentSerialPort(nullptr)
    , m_receiveHexMode(false)
    , m_pendingSlaveAddress(0)
    , m_pendingFunctionCode(0)
{
    // 初始化串口配置
    initSerialPortConfigs();

    // 创建 MODBUS 超时定时器
    m_modbusTimer = new QTimer(this);
    m_modbusTimer->setSingleShot(true);
    connect(m_modbusTimer, &QTimer::timeout, this, &SerialPortController::handleModbusTimeout);

    // 创建 QSettings 对象
    m_settings = new QSettings("BeltControl", "SerialPort", this);

    // 加载配置
    loadConfig();

    qDebug() << "✅ [SerialPortController] 初始化完成";
}

SerialPortController::~SerialPortController()
{
    // 关闭所有打开的串口
    for (auto it = m_serialPorts.begin(); it != m_serialPorts.end(); ++it) {
        if (it.value() && it.value()->isOpen()) {
            it.value()->close();
        }
        delete it.value();
    }

    qDebug() << "✅ [SerialPortController] 析构完成";
}

// ========== 串口配置初始化 ==========

void SerialPortController::initSerialPortConfigs()
{
    // ✅ 2026-02-06: 初始化6个串口配置
    // COM1-COM2: RS422 (/dev/ttyS0, /dev/ttyS7)
    // COM3-COM4: RS232 (/dev/ttyCH9344USB0, /dev/ttyCH9344USB1)
    // COM5-COM6: RS485 (/dev/ttyCH9344USB2, /dev/ttyCH9344USB3)

    m_serialPortConfigs = {
        {"COM1", "/dev/ttyS0", "RS422", 9600, 8, 1, "None", false},
        {"COM2", "/dev/ttyS7", "RS422", 9600, 8, 1, "None", false},
        {"COM3", "/dev/ttyCH9344USB0", "RS232", 9600, 8, 1, "None", false},
        {"COM4", "/dev/ttyCH9344USB1", "RS232", 9600, 8, 1, "None", false},
        {"COM5", "/dev/ttyCH9344USB2", "RS485", 9600, 8, 1, "None", false},
        {"COM6", "/dev/ttyCH9344USB3", "RS485", 9600, 8, 1, "None", false}
    };

    qDebug() << "✅ [SerialPortController] 串口配置初始化完成 - 6个串口";
}

// ========== 串口列表 ==========

QStringList SerialPortController::serialPorts() const
{
    QStringList ports;
    for (const SerialPortConfig &config : m_serialPortConfigs) {
        ports.append(config.portName);
    }
    return ports;
}

// ========== 当前串口配置 ==========

void SerialPortController::setCurrentPortIndex(int index)
{
    if (index < 0 || index >= m_serialPortConfigs.size()) {
        qWarning() << "⚠️ [SerialPortController] 无效的串口索引:" << index;
        return;
    }

    if (m_currentPortIndex == index) {
        return;
    }

    m_currentPortIndex = index;
    emit currentPortIndexChanged();
    emit currentPortNameChanged();
    emit devicePathChanged();
    emit portTypeChanged();
    emit baudRateChanged();
    emit dataBitsChanged();
    emit stopBitsChanged();
    emit parityChanged();
    emit isOpenChanged();

    qDebug() << "✅ [SerialPortController] 切换到串口:" << currentPortName();
}

QString SerialPortController::currentPortName() const
{
    if (m_currentPortIndex >= 0 && m_currentPortIndex < m_serialPortConfigs.size()) {
        return m_serialPortConfigs[m_currentPortIndex].portName;
    }
    return QString();
}

QString SerialPortController::devicePath() const
{
    if (m_currentPortIndex >= 0 && m_currentPortIndex < m_serialPortConfigs.size()) {
        return m_serialPortConfigs[m_currentPortIndex].devicePath;
    }
    return QString();
}

QString SerialPortController::portType() const
{
    if (m_currentPortIndex >= 0 && m_currentPortIndex < m_serialPortConfigs.size()) {
        return m_serialPortConfigs[m_currentPortIndex].portType;
    }
    return QString();
}

int SerialPortController::baudRate() const
{
    if (m_currentPortIndex >= 0 && m_currentPortIndex < m_serialPortConfigs.size()) {
        return m_serialPortConfigs[m_currentPortIndex].baudRate;
    }
    return 9600;
}

void SerialPortController::setBaudRate(int rate)
{
    if (m_currentPortIndex < 0 || m_currentPortIndex >= m_serialPortConfigs.size()) {
        return;
    }

    if (m_serialPortConfigs[m_currentPortIndex].baudRate == rate) {
        return;
    }

    m_serialPortConfigs[m_currentPortIndex].baudRate = rate;
    emit baudRateChanged();

    qDebug() << "✅ [SerialPortController] 波特率已更新:" << rate;
}

int SerialPortController::dataBits() const
{
    if (m_currentPortIndex >= 0 && m_currentPortIndex < m_serialPortConfigs.size()) {
        return m_serialPortConfigs[m_currentPortIndex].dataBits;
    }
    return 8;
}

void SerialPortController::setDataBits(int bits)
{
    if (m_currentPortIndex < 0 || m_currentPortIndex >= m_serialPortConfigs.size()) {
        return;
    }

    if (m_serialPortConfigs[m_currentPortIndex].dataBits == bits) {
        return;
    }

    m_serialPortConfigs[m_currentPortIndex].dataBits = bits;
    emit dataBitsChanged();

    qDebug() << "✅ [SerialPortController] 数据位已更新:" << bits;
}

int SerialPortController::stopBits() const
{
    if (m_currentPortIndex >= 0 && m_currentPortIndex < m_serialPortConfigs.size()) {
        return m_serialPortConfigs[m_currentPortIndex].stopBits;
    }
    return 1;
}

void SerialPortController::setStopBits(int bits)
{
    if (m_currentPortIndex < 0 || m_currentPortIndex >= m_serialPortConfigs.size()) {
        return;
    }

    if (m_serialPortConfigs[m_currentPortIndex].stopBits == bits) {
        return;
    }

    m_serialPortConfigs[m_currentPortIndex].stopBits = bits;
    emit stopBitsChanged();

    qDebug() << "✅ [SerialPortController] 停止位已更新:" << bits;
}

QString SerialPortController::parity() const
{
    if (m_currentPortIndex >= 0 && m_currentPortIndex < m_serialPortConfigs.size()) {
        return m_serialPortConfigs[m_currentPortIndex].parity;
    }
    return "None";
}

void SerialPortController::setParity(const QString &parity)
{
    if (m_currentPortIndex < 0 || m_currentPortIndex >= m_serialPortConfigs.size()) {
        return;
    }

    if (m_serialPortConfigs[m_currentPortIndex].parity == parity) {
        return;
    }

    m_serialPortConfigs[m_currentPortIndex].parity = parity;
    emit parityChanged();

    qDebug() << "✅ [SerialPortController] 校验位已更新:" << parity;
}

bool SerialPortController::isOpen() const
{
    if (m_currentPortIndex >= 0 && m_currentPortIndex < m_serialPortConfigs.size()) {
        return m_serialPortConfigs[m_currentPortIndex].isOpen;
    }
    return false;
}

void SerialPortController::setReceiveHexMode(bool hexMode)
{
    if (m_receiveHexMode == hexMode) {
        return;
    }

    m_receiveHexMode = hexMode;
    emit receiveHexModeChanged();

    qDebug() << "✅ [SerialPortController] 接收模式已更新:" << (hexMode ? "HEX" : "ASCII");
}

// ========== 辅助函数 ==========

QSerialPort* SerialPortController::getOrCreateSerialPort(int portIndex)
{
    if (portIndex < 0 || portIndex >= m_serialPortConfigs.size()) {
        return nullptr;
    }

    // 如果串口对象已存在，直接返回
    if (m_serialPorts.contains(portIndex)) {
        return m_serialPorts[portIndex];
    }

    // 创建新的串口对象
    QSerialPort *serialPort = new QSerialPort(this);

    // 连接信号
    connect(serialPort, &QSerialPort::readyRead, this, &SerialPortController::handleReadyRead);
    connect(serialPort, &QSerialPort::errorOccurred, this, &SerialPortController::handleError);

    // 保存到映射
    m_serialPorts[portIndex] = serialPort;

    qDebug() << "✅ [SerialPortController] 创建串口对象:" << m_serialPortConfigs[portIndex].portName;

    return serialPort;
}

// ========== 串口操作（待实现） ==========

bool SerialPortController::openSerialPort()
{
    // ✅ 2026-02-06: 待实现 - Phase 2
    qDebug() << "⚠️ [SerialPortController] openSerialPort() 待实现";
    return false;
}

void SerialPortController::closeSerialPort()
{
    // ✅ 2026-02-06: 待实现 - Phase 2
    qDebug() << "⚠️ [SerialPortController] closeSerialPort() 待实现";
}

void SerialPortController::sendData(const QString &data, bool isHex)
{
    // ✅ 2026-02-06: 待实现 - Phase 3
    Q_UNUSED(data)
    Q_UNUSED(isHex)
    qDebug() << "⚠️ [SerialPortController] sendData() 待实现";
}

void SerialPortController::clearReceiveBuffer()
{
    m_receiveBuffer.clear();
    emit receiveBufferChanged();
    qDebug() << "✅ [SerialPortController] 接收缓冲区已清空";
}

// ========== MODBUS RTU 操作（待实现） ==========

void SerialPortController::readHoldingRegisters(int slaveAddress, int startAddress, int quantity)
{
    // ✅ 2026-02-06: 待实现 - Phase 4
    Q_UNUSED(slaveAddress)
    Q_UNUSED(startAddress)
    Q_UNUSED(quantity)
    qDebug() << "⚠️ [SerialPortController] readHoldingRegisters() 待实现";
}

void SerialPortController::writeSingleRegister(int slaveAddress, int address, int value)
{
    // ✅ 2026-02-06: 待实现 - Phase 4
    Q_UNUSED(slaveAddress)
    Q_UNUSED(address)
    Q_UNUSED(value)
    qDebug() << "⚠️ [SerialPortController] writeSingleRegister() 待实现";
}

void SerialPortController::writeMultipleRegisters(int slaveAddress, int startAddress, const QList<int> &values)
{
    // ✅ 2026-02-06: 待实现 - Phase 4
    Q_UNUSED(slaveAddress)
    Q_UNUSED(startAddress)
    Q_UNUSED(values)
    qDebug() << "⚠️ [SerialPortController] writeMultipleRegisters() 待实现";
}

// ========== 数据持久化 ==========

void SerialPortController::saveConfig()
{
    m_settings->beginGroup("SerialPorts");

    for (int i = 0; i < m_serialPortConfigs.size(); i++) {
        const SerialPortConfig &config = m_serialPortConfigs[i];

        m_settings->beginGroup(config.portName);
        m_settings->setValue("baudRate", config.baudRate);
        m_settings->setValue("dataBits", config.dataBits);
        m_settings->setValue("stopBits", config.stopBits);
        m_settings->setValue("parity", config.parity);
        m_settings->endGroup();
    }

    m_settings->endGroup();
    m_settings->sync();

    qDebug() << "✅ [SerialPortController] 配置已保存";
}

void SerialPortController::loadConfig()
{
    m_settings->beginGroup("SerialPorts");

    for (int i = 0; i < m_serialPortConfigs.size(); i++) {
        SerialPortConfig &config = m_serialPortConfigs[i];

        m_settings->beginGroup(config.portName);
        config.baudRate = m_settings->value("baudRate", 9600).toInt();
        config.dataBits = m_settings->value("dataBits", 8).toInt();
        config.stopBits = m_settings->value("stopBits", 1).toInt();
        config.parity = m_settings->value("parity", "None").toString();
        m_settings->endGroup();
    }

    m_settings->endGroup();

    qDebug() << "✅ [SerialPortController] 配置已加载";
}

void SerialPortController::resetConfig()
{
    // 重置为默认配置
    initSerialPortConfigs();

    // 通知所有属性变化
    emit baudRateChanged();
    emit dataBitsChanged();
    emit stopBitsChanged();
    emit parityChanged();

    qDebug() << "✅ [SerialPortController] 配置已重置为默认值";
}

// ========== 私有槽函数（待实现） ==========

void SerialPortController::handleReadyRead()
{
    // ✅ 2026-02-06: 待实现 - Phase 3
    qDebug() << "⚠️ [SerialPortController] handleReadyRead() 待实现";
}

void SerialPortController::handleError(QSerialPort::SerialPortError error)
{
    if (error == QSerialPort::NoError) {
        return;
    }

    QString errorString = m_currentSerialPort ? m_currentSerialPort->errorString() : "未知错误";
    qWarning() << "⚠️ [SerialPortController] 串口错误:" << errorString;
    emit errorOccurred(errorString);
}

void SerialPortController::handleModbusTimeout()
{
    qWarning() << "⚠️ [SerialPortController] MODBUS 响应超时";
    emit errorOccurred("MODBUS 响应超时");
    m_modbusBuffer.clear();
}

// ========== MODBUS 协议辅助函数（待实现） ==========

QByteArray SerialPortController::hexStringToByteArray(const QString &hex)
{
    // ✅ 2026-02-06: 待实现 - Phase 3
    Q_UNUSED(hex)
    return QByteArray();
}

QString SerialPortController::byteArrayToHexString(const QByteArray &data)
{
    // ✅ 2026-02-06: 待实现 - Phase 3
    Q_UNUSED(data)
    return QString();
}

QByteArray SerialPortController::buildModbusRequest(int slaveAddress, int functionCode,
                                                     int startAddress, int quantity,
                                                     const QList<int> &values)
{
    // ✅ 2026-02-06: 待实现 - Phase 4
    Q_UNUSED(slaveAddress)
    Q_UNUSED(functionCode)
    Q_UNUSED(startAddress)
    Q_UNUSED(quantity)
    Q_UNUSED(values)
    return QByteArray();
}

bool SerialPortController::parseModbusResponse(const QByteArray &response,
                                                int &slaveAddress, int &functionCode,
                                                QByteArray &data)
{
    // ✅ 2026-02-06: 待实现 - Phase 4
    Q_UNUSED(response)
    Q_UNUSED(slaveAddress)
    Q_UNUSED(functionCode)
    Q_UNUSED(data)
    return false;
}

quint16 SerialPortController::calculateCRC16(const QByteArray &data)
{
    // ✅ 2026-02-06: 待实现 - Phase 4
    Q_UNUSED(data)
    return 0;
}

bool SerialPortController::isModbusResponseComplete(const QByteArray &buffer)
{
    // ✅ 2026-02-06: 待实现 - Phase 4
    Q_UNUSED(buffer)
    return false;
}

void SerialPortController::parseAndEmitModbusResponse()
{
    // ✅ 2026-02-06: 待实现 - Phase 4
    qDebug() << "⚠️ [SerialPortController] parseAndEmitModbusResponse() 待实现";
}
