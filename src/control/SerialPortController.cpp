// ✅ 2026-02-06: FIX 100.300.113 Phase 7.38.1 - SerialPortController 实现
// 串口控制器类实现 - 管理6个串口的配置和通信

#include "SerialPortController.h"
#include <QDebug>
#include <QSerialPortInfo>
#include <QDateTime>  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.11]: 添加时间戳支持

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
    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.2]: 实现串口打开功能
    if (m_currentPortIndex < 0 || m_currentPortIndex >= m_serialPortConfigs.size()) {
        QString error = QString("无效的串口索引: %1").arg(m_currentPortIndex);
        qWarning() << "⚠️ [SerialPortController]" << error;
        emit errorOccurred(error);
        return false;
    }

    SerialPortConfig &config = m_serialPortConfigs[m_currentPortIndex];

    // 如果已经打开，先关闭
    if (config.isOpen && m_currentSerialPort && m_currentSerialPort->isOpen()) {
        qDebug() << "⚠️ [SerialPortController] 串口已打开，先关闭:" << config.portName;
        closeSerialPort();
    }

    // 创建或获取串口对象
    m_currentSerialPort = getOrCreateSerialPort(m_currentPortIndex);
    if (!m_currentSerialPort) {
        QString error = QString("无法创建串口对象: %1").arg(config.portName);
        qWarning() << "⚠️ [SerialPortController]" << error;
        emit errorOccurred(error);
        return false;
    }

    // 设置串口参数
    m_currentSerialPort->setPortName(config.devicePath);
    m_currentSerialPort->setBaudRate(config.baudRate);

    // 设置数据位
    switch (config.dataBits) {
    case 5:
        m_currentSerialPort->setDataBits(QSerialPort::Data5);
        break;
    case 6:
        m_currentSerialPort->setDataBits(QSerialPort::Data6);
        break;
    case 7:
        m_currentSerialPort->setDataBits(QSerialPort::Data7);
        break;
    case 8:
    default:
        m_currentSerialPort->setDataBits(QSerialPort::Data8);
        break;
    }

    // 设置停止位
    switch (config.stopBits) {
    case 2:
        m_currentSerialPort->setStopBits(QSerialPort::TwoStop);
        break;
    case 1:
    default:
        m_currentSerialPort->setStopBits(QSerialPort::OneStop);
        break;
    }

    // 设置校验位
    if (config.parity == "None") {
        m_currentSerialPort->setParity(QSerialPort::NoParity);
    } else if (config.parity == "Even") {
        m_currentSerialPort->setParity(QSerialPort::EvenParity);
    } else if (config.parity == "Odd") {
        m_currentSerialPort->setParity(QSerialPort::OddParity);
    } else if (config.parity == "Space") {
        m_currentSerialPort->setParity(QSerialPort::SpaceParity);
    } else if (config.parity == "Mark") {
        m_currentSerialPort->setParity(QSerialPort::MarkParity);
    } else {
        m_currentSerialPort->setParity(QSerialPort::NoParity);
    }

    // 设置流控制（默认无流控制）
    m_currentSerialPort->setFlowControl(QSerialPort::NoFlowControl);

    // 打开串口
    if (!m_currentSerialPort->open(QIODevice::ReadWrite)) {
        QString error = QString("无法打开串口 %1 (%2): %3")
                        .arg(config.portName)
                        .arg(config.devicePath)
                        .arg(m_currentSerialPort->errorString());
        qWarning() << "⚠️ [SerialPortController]" << error;
        emit errorOccurred(error);
        return false;
    }

    // 更新状态
    config.isOpen = true;
    emit isOpenChanged();

    qDebug() << "✅ [SerialPortController] 串口已打开:"
             << config.portName
             << "(" << config.devicePath << ")"
             << "波特率:" << config.baudRate
             << "数据位:" << config.dataBits
             << "停止位:" << config.stopBits
             << "校验位:" << config.parity;

    return true;
}

void SerialPortController::closeSerialPort()
{
    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.2]: 实现串口关闭功能
    if (!m_currentSerialPort) {
        qDebug() << "⚠️ [SerialPortController] 串口对象不存在，无需关闭";
        return;
    }

    if (!m_currentSerialPort->isOpen()) {
        qDebug() << "⚠️ [SerialPortController] 串口未打开，无需关闭";
        return;
    }

    // 关闭串口
    m_currentSerialPort->close();

    // 更新状态
    if (m_currentPortIndex >= 0 && m_currentPortIndex < m_serialPortConfigs.size()) {
        SerialPortConfig &config = m_serialPortConfigs[m_currentPortIndex];
        config.isOpen = false;
        emit isOpenChanged();

        qDebug() << "✅ [SerialPortController] 串口已关闭:"
                 << config.portName
                 << "(" << config.devicePath << ")";
    }
}

void SerialPortController::sendData(const QString &data, bool isHex)
{
    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.3]: 实现数据发送功能
    if (!m_currentSerialPort || !m_currentSerialPort->isOpen()) {
        QString error = "串口未打开，无法发送数据";
        qWarning() << "⚠️ [SerialPortController]" << error;
        emit errorOccurred(error);
        return;
    }

    QByteArray sendData;

    if (isHex) {
        // HEX 模式：将十六进制字符串转换为字节数组
        sendData = hexStringToByteArray(data);
        if (sendData.isEmpty() && !data.isEmpty()) {
            QString error = "HEX 数据转换失败";
            qWarning() << "⚠️ [SerialPortController]" << error;
            emit errorOccurred(error);
            return;
        }
    } else {
        // ASCII 模式：直接转换为字节数组
        sendData = data.toUtf8();
    }

    // 发送数据
    qint64 bytesWritten = m_currentSerialPort->write(sendData);

    if (bytesWritten == -1) {
        QString error = QString("发送数据失败: %1").arg(m_currentSerialPort->errorString());
        qWarning() << "⚠️ [SerialPortController]" << error;
        emit errorOccurred(error);
    } else if (bytesWritten < sendData.size()) {
        QString warning = QString("部分数据发送失败: 已发送 %1/%2 字节").arg(bytesWritten).arg(sendData.size());
        qWarning() << "⚠️ [SerialPortController]" << warning;
        emit errorOccurred(warning);
    } else {
        qDebug() << "✅ [SerialPortController] 数据已发送:"
                 << bytesWritten << "字节"
                 << (isHex ? "[HEX]" : "[ASCII]")
                 << (isHex ? byteArrayToHexString(sendData) : data);
    }
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
    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.3]: 实现数据接收处理
    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.11]: 添加时间戳和自动换行
    if (!m_currentSerialPort) {
        return;
    }

    // 读取所有可用数据
    QByteArray data = m_currentSerialPort->readAll();

    if (data.isEmpty()) {
        return;
    }

    // 发送原始数据信号
    emit dataReceived(data);

    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.11]: 生成时间戳
    QString timestamp = QDateTime::currentDateTime().toString("[yyyy-MM-dd HH:mm:ss.zzz] ");

    // 更新接收缓冲区（添加时间戳和换行）
    if (m_receiveHexMode) {
        // HEX 模式：转换为十六进制字符串
        QString hexData = byteArrayToHexString(data);
        m_receiveBuffer += timestamp + hexData + "\n";
    } else {
        // ASCII 模式：直接转换为字符串
        QString asciiData = QString::fromUtf8(data);
        m_receiveBuffer += timestamp + asciiData + "\n";
    }

    emit receiveBufferChanged();

    // 如果是 MODBUS 响应，添加到 MODBUS 缓冲区
    if (m_modbusTimer->isActive()) {
        m_modbusBuffer.append(data);

        // 检查是否接收完整（简单检查：至少5字节 = 地址+功能码+数据长度+CRC）
        if (isModbusResponseComplete(m_modbusBuffer)) {
            m_modbusTimer->stop();
            parseAndEmitModbusResponse();
        }
    }

    qDebug() << "✅ [SerialPortController] 接收数据:"
             << data.size() << "字节"
             << (m_receiveHexMode ? "[HEX]" : "[ASCII]")
             << (m_receiveHexMode ? byteArrayToHexString(data) : QString::fromUtf8(data));
}

void SerialPortController::handleError(QSerialPort::SerialPortError error)
{
    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.2]: 完善错误处理
    if (error == QSerialPort::NoError) {
        return;
    }

    QString errorString;
    QString errorType;

    // 根据错误类型提供详细的错误信息
    switch (error) {
    case QSerialPort::DeviceNotFoundError:
        errorType = "设备未找到";
        errorString = QString("串口设备未找到: %1").arg(m_currentSerialPort ? m_currentSerialPort->portName() : "未知");
        break;
    case QSerialPort::PermissionError:
        errorType = "权限错误";
        errorString = QString("无权限访问串口设备: %1 (请检查用户是否在 dialout 组中)").arg(m_currentSerialPort ? m_currentSerialPort->portName() : "未知");
        break;
    case QSerialPort::OpenError:
        errorType = "打开错误";
        errorString = QString("无法打开串口设备: %1").arg(m_currentSerialPort ? m_currentSerialPort->errorString() : "未知");
        break;
    case QSerialPort::WriteError:
        errorType = "写入错误";
        errorString = QString("写入串口数据失败: %1").arg(m_currentSerialPort ? m_currentSerialPort->errorString() : "未知");
        break;
    case QSerialPort::ReadError:
        errorType = "读取错误";
        errorString = QString("读取串口数据失败: %1").arg(m_currentSerialPort ? m_currentSerialPort->errorString() : "未知");
        break;
    case QSerialPort::ResourceError:
        errorType = "资源错误";
        errorString = QString("串口资源错误（设备可能被拔出）: %1").arg(m_currentSerialPort ? m_currentSerialPort->errorString() : "未知");
        // 资源错误通常意味着设备被拔出，自动关闭串口
        if (m_currentPortIndex >= 0 && m_currentPortIndex < m_serialPortConfigs.size()) {
            m_serialPortConfigs[m_currentPortIndex].isOpen = false;
            emit isOpenChanged();
        }
        break;
    case QSerialPort::UnsupportedOperationError:
        errorType = "不支持的操作";
        errorString = QString("串口不支持此操作: %1").arg(m_currentSerialPort ? m_currentSerialPort->errorString() : "未知");
        break;
    case QSerialPort::TimeoutError:
        errorType = "超时错误";
        errorString = QString("串口操作超时: %1").arg(m_currentSerialPort ? m_currentSerialPort->errorString() : "未知");
        break;
    case QSerialPort::NotOpenError:
        errorType = "未打开错误";
        errorString = QString("串口未打开: %1").arg(m_currentSerialPort ? m_currentSerialPort->errorString() : "未知");
        break;
    default:
        errorType = "未知错误";
        errorString = m_currentSerialPort ? m_currentSerialPort->errorString() : "未知错误";
        break;
    }

    qWarning() << "⚠️ [SerialPortController] 串口错误 [" << errorType << "]:" << errorString;
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
    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.3]: 实现HEX字符串转字节数组
    QByteArray result;

    // 移除空格和其他分隔符
    QString cleanHex = hex.simplified().remove(' ').remove('-').remove(':');

    // 确保是偶数长度（每两个字符代表一个字节）
    if (cleanHex.length() % 2 != 0) {
        qWarning() << "⚠️ [SerialPortController] HEX字符串长度不是偶数:" << hex;
        // 在前面补0
        cleanHex.prepend('0');
    }

    // 转换每两个字符为一个字节
    for (int i = 0; i < cleanHex.length(); i += 2) {
        QString byteString = cleanHex.mid(i, 2);
        bool ok;
        quint8 byte = byteString.toUInt(&ok, 16);
        if (ok) {
            result.append(byte);
        } else {
            qWarning() << "⚠️ [SerialPortController] 无效的HEX字符:" << byteString;
        }
    }

    qDebug() << "✅ [SerialPortController] HEX转换:" << hex << "→" << result.size() << "字节";
    return result;
}

QString SerialPortController::byteArrayToHexString(const QByteArray &data)
{
    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.3]: 实现字节数组转HEX字符串
    QString result;

    for (quint8 byte : data) {
        // 每个字节转换为两位十六进制（大写，前导0）
        result += QString("%1 ").arg(byte, 2, 16, QChar('0')).toUpper();
    }

    // 移除末尾的空格
    return result.trimmed();
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
