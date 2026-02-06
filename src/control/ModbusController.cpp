// ✅ 2026-02-06: FIX 100.300.113 Phase 7.38.4 - ModbusController 实现
// MODBUS RTU 控制器类实现 - 基于 Qt SerialBus 模块

#include "ModbusController.h"
#include <QDebug>

// ========== 构造函数和析构函数 ==========

ModbusController::ModbusController(QObject *parent)
    : QObject(parent)
    , m_modbusDevice(nullptr)
    , m_portName("/dev/ttyS0")
    , m_baudRate(9600)
    , m_dataBits(8)
    , m_stopBits(1)
    , m_parity("None")
    , m_statusText("未连接")
{
    // 创建 MODBUS RTU 主站设备
    m_modbusDevice = new QModbusRtuSerialMaster(this);

    // 连接信号
    connect(m_modbusDevice, &QModbusDevice::stateChanged,
            this, &ModbusController::handleStateChanged);
    connect(m_modbusDevice, &QModbusDevice::errorOccurred,
            this, &ModbusController::handleErrorOccurred);

    qDebug() << "✅ [ModbusController] 初始化完成";
}

ModbusController::~ModbusController()
{
    if (m_modbusDevice) {
        m_modbusDevice->disconnectDevice();
    }
    qDebug() << "✅ [ModbusController] 析构完成";
}

// ========== 连接状态 ==========

bool ModbusController::isConnected() const
{
    return m_modbusDevice && m_modbusDevice->state() == QModbusDevice::ConnectedState;
}

// ========== 串口配置 ==========

void ModbusController::setPortName(const QString &portName)
{
    if (m_portName == portName) {
        return;
    }

    m_portName = portName;
    emit portNameChanged();

    qDebug() << "✅ [ModbusController] 串口名称已更新:" << portName;
}

void ModbusController::setBaudRate(int baudRate)
{
    if (m_baudRate == baudRate) {
        return;
    }

    m_baudRate = baudRate;
    emit baudRateChanged();

    qDebug() << "✅ [ModbusController] 波特率已更新:" << baudRate;
}

void ModbusController::setDataBits(int dataBits)
{
    if (m_dataBits == dataBits) {
        return;
    }

    m_dataBits = dataBits;
    emit dataBitsChanged();

    qDebug() << "✅ [ModbusController] 数据位已更新:" << dataBits;
}

void ModbusController::setStopBits(int stopBits)
{
    if (m_stopBits == stopBits) {
        return;
    }

    m_stopBits = stopBits;
    emit stopBitsChanged();

    qDebug() << "✅ [ModbusController] 停止位已更新:" << stopBits;
}

void ModbusController::setParity(const QString &parity)
{
    if (m_parity == parity) {
        return;
    }

    m_parity = parity;
    emit parityChanged();

    qDebug() << "✅ [ModbusController] 校验位已更新:" << parity;
}

// ========== MODBUS 操作 ==========

bool ModbusController::connectDevice()
{
    if (!m_modbusDevice) {
        emit errorOccurred("MODBUS 设备未初始化");
        return false;
    }

    // 如果已连接，先断开
    if (m_modbusDevice->state() == QModbusDevice::ConnectedState) {
        qDebug() << "⚠️ [ModbusController] 设备已连接，先断开";
        m_modbusDevice->disconnectDevice();
    }

    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.7]: 修复编译错误 - setConnectionParameter 需要 QVariant 参数
    // 设置串口参数（需要包装为 QVariant）
    m_modbusDevice->setConnectionParameter(QModbusDevice::SerialPortNameParameter, QVariant(m_portName));
    m_modbusDevice->setConnectionParameter(QModbusDevice::SerialBaudRateParameter, QVariant(m_baudRate));
    m_modbusDevice->setConnectionParameter(QModbusDevice::SerialDataBitsParameter, QVariant(m_dataBits));
    m_modbusDevice->setConnectionParameter(QModbusDevice::SerialStopBitsParameter, QVariant(m_stopBits));
    m_modbusDevice->setConnectionParameter(QModbusDevice::SerialParityParameter, QVariant(static_cast<int>(convertParity(m_parity))));

    // 设置超时和重试
    m_modbusDevice->setTimeout(1000);  // 1秒超时
    m_modbusDevice->setNumberOfRetries(3);  // 重试3次

    // 连接设备
    if (!m_modbusDevice->connectDevice()) {
        QString error = QString("无法连接 MODBUS 设备: %1").arg(m_modbusDevice->errorString());
        qWarning() << "⚠️ [ModbusController]" << error;
        emit errorOccurred(error);
        return false;
    }

    qDebug() << "✅ [ModbusController] 正在连接 MODBUS 设备...";
    return true;
}

void ModbusController::disconnectDevice()
{
    if (!m_modbusDevice) {
        return;
    }

    m_modbusDevice->disconnectDevice();
    qDebug() << "✅ [ModbusController] 已断开 MODBUS 设备";
}

void ModbusController::readHoldingRegisters(int serverAddress, int startAddress, int count)
{
    if (!m_modbusDevice || m_modbusDevice->state() != QModbusDevice::ConnectedState) {
        emit errorOccurred("MODBUS 设备未连接");
        return;
    }

    // 创建读取请求
    QModbusDataUnit readUnit(QModbusDataUnit::HoldingRegisters, startAddress, count);

    // 发送读取请求
    QModbusReply *reply = m_modbusDevice->sendReadRequest(readUnit, serverAddress);
    if (!reply) {
        emit errorOccurred("发送读取请求失败");
        return;
    }

    if (reply->isFinished()) {
        // 立即完成（不太可能）
        delete reply;
        return;
    }

    // 连接完成信号
    connect(reply, &QModbusReply::finished, this, [this, reply, serverAddress, startAddress]() {
        if (reply->error() == QModbusDevice::NoError) {
            QModbusDataUnit unit = reply->result();
            QList<int> values;
            for (int i = 0; i < unit.valueCount(); i++) {
                values.append(unit.value(i));
            }

            qDebug() << "✅ [ModbusController] 读取成功 - 从站:" << serverAddress
                     << "起始地址:" << startAddress
                     << "数量:" << values.size();

            emit readRegistersFinished(serverAddress, startAddress, values);
        } else {
            QString error = QString("读取失败: %1").arg(reply->errorString());
            qWarning() << "⚠️ [ModbusController]" << error;
            emit errorOccurred(error);
        }

        reply->deleteLater();
    });

    qDebug() << "✅ [ModbusController] 发送读取请求 - 从站:" << serverAddress
             << "起始地址:" << startAddress << "数量:" << count;
}

void ModbusController::writeSingleRegister(int serverAddress, int address, int value)
{
    if (!m_modbusDevice || m_modbusDevice->state() != QModbusDevice::ConnectedState) {
        emit errorOccurred("MODBUS 设备未连接");
        return;
    }

    // 创建写入请求
    QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, address, 1);
    writeUnit.setValue(0, value);

    // 发送写入请求
    QModbusReply *reply = m_modbusDevice->sendWriteRequest(writeUnit, serverAddress);
    if (!reply) {
        emit errorOccurred("发送写入请求失败");
        return;
    }

    if (reply->isFinished()) {
        delete reply;
        return;
    }

    // 连接完成信号
    connect(reply, &QModbusReply::finished, this, [this, reply, serverAddress, address]() {
        bool success = (reply->error() == QModbusDevice::NoError);

        if (success) {
            qDebug() << "✅ [ModbusController] 写入成功 - 从站:" << serverAddress
                     << "地址:" << address;
        } else {
            QString error = QString("写入失败: %1").arg(reply->errorString());
            qWarning() << "⚠️ [ModbusController]" << error;
            emit errorOccurred(error);
        }

        emit writeRegisterFinished(serverAddress, address, success);
        reply->deleteLater();
    });

    qDebug() << "✅ [ModbusController] 发送写入请求 - 从站:" << serverAddress
             << "地址:" << address << "值:" << value;
}

void ModbusController::writeMultipleRegisters(int serverAddress, int startAddress, const QList<int> &values)
{
    if (!m_modbusDevice || m_modbusDevice->state() != QModbusDevice::ConnectedState) {
        emit errorOccurred("MODBUS 设备未连接");
        return;
    }

    // 创建写入请求
    QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, startAddress, values.size());
    for (int i = 0; i < values.size(); i++) {
        writeUnit.setValue(i, values[i]);
    }

    // 发送写入请求
    QModbusReply *reply = m_modbusDevice->sendWriteRequest(writeUnit, serverAddress);
    if (!reply) {
        emit errorOccurred("发送写入请求失败");
        return;
    }

    if (reply->isFinished()) {
        delete reply;
        return;
    }

    // 连接完成信号
    connect(reply, &QModbusReply::finished, this, [this, reply, serverAddress, startAddress]() {
        bool success = (reply->error() == QModbusDevice::NoError);

        if (success) {
            qDebug() << "✅ [ModbusController] 批量写入成功 - 从站:" << serverAddress
                     << "起始地址:" << startAddress;
        } else {
            QString error = QString("批量写入失败: %1").arg(reply->errorString());
            qWarning() << "⚠️ [ModbusController]" << error;
            emit errorOccurred(error);
        }

        emit writeRegistersFinished(serverAddress, startAddress, success);
        reply->deleteLater();
    });

    qDebug() << "✅ [ModbusController] 发送批量写入请求 - 从站:" << serverAddress
             << "起始地址:" << startAddress << "数量:" << values.size();
}

// ========== 私有槽函数 ==========

void ModbusController::handleStateChanged(QModbusDevice::State state)
{
    switch (state) {
    case QModbusDevice::UnconnectedState:
        m_statusText = "未连接";
        qDebug() << "✅ [ModbusController] 状态: 未连接";
        break;
    case QModbusDevice::ConnectingState:
        m_statusText = "正在连接...";
        qDebug() << "✅ [ModbusController] 状态: 正在连接";
        break;
    case QModbusDevice::ConnectedState:
        m_statusText = "已连接";
        qDebug() << "✅ [ModbusController] 状态: 已连接";
        break;
    case QModbusDevice::ClosingState:
        m_statusText = "正在关闭...";
        qDebug() << "✅ [ModbusController] 状态: 正在关闭";
        break;
    }

    emit statusTextChanged();
    emit isConnectedChanged();
}

void ModbusController::handleErrorOccurred(QModbusDevice::Error error)
{
    if (error == QModbusDevice::NoError) {
        return;
    }

    QString errorString = m_modbusDevice ? m_modbusDevice->errorString() : "未知错误";
    qWarning() << "⚠️ [ModbusController] MODBUS 错误:" << errorString;
    emit errorOccurred(errorString);
}

void ModbusController::handleReadReady()
{
    // 预留：处理读取完成
}

void ModbusController::handleWriteReady()
{
    // 预留：处理写入完成
}

// ========== 辅助函数 ==========

void ModbusController::updateStatusText()
{
    // 更新状态文本（已在 handleStateChanged 中实现）
}

QSerialPort::Parity ModbusController::convertParity(const QString &parity)
{
    if (parity == "None") {
        return QSerialPort::NoParity;
    } else if (parity == "Even") {
        return QSerialPort::EvenParity;
    } else if (parity == "Odd") {
        return QSerialPort::OddParity;
    } else if (parity == "Space") {
        return QSerialPort::SpaceParity;
    } else if (parity == "Mark") {
        return QSerialPort::MarkParity;
    }
    return QSerialPort::NoParity;
}
