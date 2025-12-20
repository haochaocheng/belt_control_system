#include "ModbusTcpClient.h"
#include <QDebug>
#include <QVariant>

ModbusTcpClient::ModbusTcpClient(QObject *parent)
    : QObject(parent)
    , m_modbusClient(new QModbusTcpClient(this))
    , m_serverPort(502)
    , m_isConnected(false)
{
    qDebug() << "✅ ModbusTcpClient: Modbus TCP客户端已创建";

    // 连接信号
    connect(m_modbusClient, &QModbusClient::stateChanged,
            this, &ModbusTcpClient::onStateChanged);
    connect(m_modbusClient, &QModbusClient::errorOccurred,
            this, &ModbusTcpClient::onErrorOccurred);

    // 设置超时时间（毫秒） - 增加到3秒以适应批量读取
    m_modbusClient->setTimeout(3000);

    // 设置重试次数 - 减少重试避免堆积
    m_modbusClient->setNumberOfRetries(1);
}

ModbusTcpClient::~ModbusTcpClient()
{
    disconnectFromServer();
    qDebug() << "✅ ModbusTcpClient: Modbus TCP客户端已销毁";
}

bool ModbusTcpClient::connectToServer(const QString &host, int port)
{
    if (m_isConnected) {
        qDebug() << "⚠️  ModbusTcpClient: 已经连接到服务器，先断开";
        disconnectFromServer();
    }

    m_serverAddress = host;
    m_serverPort = port;

    // 设置连接参数
    m_modbusClient->setConnectionParameter(QModbusDevice::NetworkAddressParameter, QVariant(host));
    m_modbusClient->setConnectionParameter(QModbusDevice::NetworkPortParameter, QVariant(port));

    qDebug() << "🔌 ModbusTcpClient: 正在连接到" << host << ":" << port;

    // 连接到设备
    if (!m_modbusClient->connectDevice()) {
        qWarning() << "❌ ModbusTcpClient: 连接失败:" << m_modbusClient->errorString();
        return false;
    }

    return true;
}

void ModbusTcpClient::disconnectFromServer()
{
    if (m_modbusClient->state() != QModbusDevice::UnconnectedState) {
        qDebug() << "🔌 ModbusTcpClient: 断开连接";
        m_modbusClient->disconnectDevice();
    }
}

bool ModbusTcpClient::isConnected() const
{
    return m_isConnected;
}

void ModbusTcpClient::readHoldingRegisters(int startAddress, int count)
{
    if (!m_isConnected) {
        qWarning() << "❌ ModbusTcpClient: 未连接到服务器";
        emit readError("未连接到服务器");
        return;
    }

    // 创建读取请求（功能码0x03 - 读取保持寄存器）
    QModbusDataUnit readUnit(QModbusDataUnit::HoldingRegisters, startAddress, count);

    // 发送读取请求（服务器地址：1）
    if (auto *reply = m_modbusClient->sendReadRequest(readUnit, 1)) {
        if (!reply->isFinished()) {
            // 连接完成信号
            connect(reply, &QModbusReply::finished, this, &ModbusTcpClient::onReadReady);
        } else {
            // 请求立即完成
            delete reply;
        }
    } else {
        qWarning() << "❌ ModbusTcpClient: 发送读取请求失败:" << m_modbusClient->errorString();
        emit readError(m_modbusClient->errorString());
    }
}

void ModbusTcpClient::writeSingleRegister(int address, quint16 value)
{
    if (!m_isConnected) {
        qWarning() << "❌ ModbusTcpClient: 未连接到服务器";
        emit writeError("未连接到服务器");
        return;
    }

    // 创建写入请求（功能码0x06 - 写入单个寄存器）
    QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, address, 1);
    writeUnit.setValue(0, value);

    // 发送写入请求（服务器地址：1）
    if (auto *reply = m_modbusClient->sendWriteRequest(writeUnit, 1)) {
        if (!reply->isFinished()) {
            connect(reply, &QModbusReply::finished, this, [this, reply, address]() {
                reply->deleteLater();

                if (reply->error() == QModbusDevice::NoError) {
                    qDebug() << "✅ ModbusTcpClient: 写入寄存器成功, 地址:" << address;
                    emit writeSuccess(address);
                } else {
                    qWarning() << "❌ ModbusTcpClient: 写入寄存器失败:" << reply->errorString();
                    emit writeError(reply->errorString());
                }
            });
        } else {
            delete reply;
        }
    } else {
        qWarning() << "❌ ModbusTcpClient: 发送写入请求失败:" << m_modbusClient->errorString();
        emit writeError(m_modbusClient->errorString());
    }
}

void ModbusTcpClient::onStateChanged(QModbusDevice::State state)
{
    bool wasConnected = m_isConnected;

    switch (state) {
    case QModbusDevice::UnconnectedState:
        m_isConnected = false;
        qDebug() << "🔴 ModbusTcpClient: 未连接";
        break;
    case QModbusDevice::ConnectingState:
        qDebug() << "🟡 ModbusTcpClient: 正在连接...";
        break;
    case QModbusDevice::ConnectedState:
        m_isConnected = true;
        qDebug() << "🟢 ModbusTcpClient: 已连接到" << m_serverAddress << ":" << m_serverPort;
        break;
    case QModbusDevice::ClosingState:
        qDebug() << "🟡 ModbusTcpClient: 正在断开连接...";
        break;
    }

    if (wasConnected != m_isConnected) {
        emit connectionStateChanged(m_isConnected);
    }
}

void ModbusTcpClient::onReadReady()
{
    auto reply = qobject_cast<QModbusReply *>(sender());
    if (!reply)
        return;

    reply->deleteLater();

    if (reply->error() == QModbusDevice::NoError) {
        const QModbusDataUnit unit = reply->result();
        QVector<quint16> values;

        for (int i = 0; i < unit.valueCount(); ++i) {
            values.append(unit.value(i));
        }

        // 移除详细读取日志，由 NetworkTask 在值变化时打印
        // qDebug() << "✅ ModbusTcpClient: 读取成功, 地址:" << unit.startAddress()
        //          << ", 数量:" << unit.valueCount()
        //          << ", 值:" << values;

        emit readSuccess(unit.startAddress(), values);
    } else {
        qWarning() << "❌ ModbusTcpClient: 读取失败:" << reply->errorString();
        emit readError(reply->errorString());
    }
}

void ModbusTcpClient::onErrorOccurred(QModbusDevice::Error error)
{
    qWarning() << "❌ ModbusTcpClient: 发生错误:" << m_modbusClient->errorString();
}
