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
    , m_startRegister(0)
    , m_registerCount(10)
    , m_statusText("未连接")
    , m_settings(nullptr)
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

    // 初始化配置
    initSettings();

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
// ✅ 2026-02-08 [Phase 7.42]: 完善读取保持寄存器功能
bool ModbusTCPMasterController::readHoldingRegisters(int startAddress, int count)
{
    if (!isConnected()) {
        qWarning() << "❌ [ModbusTCPMasterController] 未连接，无法读取保持寄存器";
        emit errorOccurred("未连接到服务器");
        return false;
    }

    QModbusDataUnit readUnit(QModbusDataUnit::HoldingRegisters, startAddress, count);
    QModbusReply *reply = m_modbusClient->sendReadRequest(readUnit, m_slaveAddress);

    if (!reply) {
        qWarning() << "❌ [ModbusTCPMasterController] 发送读取请求失败";
        emit errorOccurred("发送读取请求失败");
        return false;
    }

    if (reply->isFinished()) {
        // 同步完成（不太可能，但处理一下）
        if (reply->error() == QModbusDevice::NoError) {
            const QModbusDataUnit unit = reply->result();
            QList<int> values;
            for (int i = 0; i < unit.valueCount(); ++i) {
                values.append(unit.value(i));
            }
            emit holdingRegistersRead(startAddress, values);
            qDebug() << "✅ [ModbusTCPMasterController] 读取保持寄存器成功:" << startAddress << "数量:" << count;
        } else {
            emit errorOccurred(reply->errorString());
        }
        reply->deleteLater();
    } else {
        // 异步完成
        connect(reply, &QModbusReply::finished, this, [this, reply, startAddress]() {
            if (reply->error() == QModbusDevice::NoError) {
                const QModbusDataUnit unit = reply->result();
                QList<int> values;
                for (uint i = 0; i < unit.valueCount(); ++i) {
                    values.append(unit.value(i));
                }
                emit holdingRegistersRead(startAddress, values);
                qDebug() << "✅ [ModbusTCPMasterController] 读取保持寄存器成功:" << startAddress << "数量:" << unit.valueCount();
            } else {
                qWarning() << "❌ [ModbusTCPMasterController] 读取保持寄存器失败:" << reply->errorString();
                emit errorOccurred(reply->errorString());
            }
            reply->deleteLater();
        });
    }

    return true;
}

// ✅ 2026-02-08 [Phase 7.42]: 完善读取输入寄存器功能
bool ModbusTCPMasterController::readInputRegisters(int startAddress, int count)
{
    if (!isConnected()) {
        qWarning() << "❌ [ModbusTCPMasterController] 未连接，无法读取输入寄存器";
        emit errorOccurred("未连接到服务器");
        return false;
    }

    QModbusDataUnit readUnit(QModbusDataUnit::InputRegisters, startAddress, count);
    QModbusReply *reply = m_modbusClient->sendReadRequest(readUnit, m_slaveAddress);

    if (!reply) {
        qWarning() << "❌ [ModbusTCPMasterController] 发送读取请求失败";
        emit errorOccurred("发送读取请求失败");
        return false;
    }

    if (reply->isFinished()) {
        if (reply->error() == QModbusDevice::NoError) {
            const QModbusDataUnit unit = reply->result();
            QList<int> values;
            for (uint i = 0; i < unit.valueCount(); ++i) {
                values.append(unit.value(i));
            }
            emit inputRegistersRead(startAddress, values);
            qDebug() << "✅ [ModbusTCPMasterController] 读取输入寄存器成功:" << startAddress << "数量:" << count;
        } else {
            emit errorOccurred(reply->errorString());
        }
        reply->deleteLater();
    } else {
        connect(reply, &QModbusReply::finished, this, [this, reply, startAddress]() {
            if (reply->error() == QModbusDevice::NoError) {
                const QModbusDataUnit unit = reply->result();
                QList<int> values;
                for (uint i = 0; i < unit.valueCount(); ++i) {
                    values.append(unit.value(i));
                }
                emit inputRegistersRead(startAddress, values);
                qDebug() << "✅ [ModbusTCPMasterController] 读取输入寄存器成功:" << startAddress << "数量:" << unit.valueCount();
            } else {
                qWarning() << "❌ [ModbusTCPMasterController] 读取输入寄存器失败:" << reply->errorString();
                emit errorOccurred(reply->errorString());
            }
            reply->deleteLater();
        });
    }

    return true;
}

// ✅ 2026-02-08 [Phase 7.42]: 完善读取线圈功能
bool ModbusTCPMasterController::readCoils(int startAddress, int count)
{
    if (!isConnected()) {
        qWarning() << "❌ [ModbusTCPMasterController] 未连接，无法读取线圈";
        emit errorOccurred("未连接到服务器");
        return false;
    }

    QModbusDataUnit readUnit(QModbusDataUnit::Coils, startAddress, count);
    QModbusReply *reply = m_modbusClient->sendReadRequest(readUnit, m_slaveAddress);

    if (!reply) {
        qWarning() << "❌ [ModbusTCPMasterController] 发送读取请求失败";
        emit errorOccurred("发送读取请求失败");
        return false;
    }

    if (reply->isFinished()) {
        if (reply->error() == QModbusDevice::NoError) {
            const QModbusDataUnit unit = reply->result();
            QList<bool> values;
            for (uint i = 0; i < unit.valueCount(); ++i) {
                values.append(unit.value(i) != 0);
            }
            emit coilsRead(startAddress, values);
            qDebug() << "✅ [ModbusTCPMasterController] 读取线圈成功:" << startAddress << "数量:" << count;
        } else {
            emit errorOccurred(reply->errorString());
        }
        reply->deleteLater();
    } else {
        connect(reply, &QModbusReply::finished, this, [this, reply, startAddress]() {
            if (reply->error() == QModbusDevice::NoError) {
                const QModbusDataUnit unit = reply->result();
                QList<bool> values;
                for (uint i = 0; i < unit.valueCount(); ++i) {
                    values.append(unit.value(i) != 0);
                }
                emit coilsRead(startAddress, values);
                qDebug() << "✅ [ModbusTCPMasterController] 读取线圈成功:" << startAddress << "数量:" << unit.valueCount();
            } else {
                qWarning() << "❌ [ModbusTCPMasterController] 读取线圈失败:" << reply->errorString();
                emit errorOccurred(reply->errorString());
            }
            reply->deleteLater();
        });
    }

    return true;
}

// ✅ 2026-02-08 [Phase 7.42]: 完善读取离散输入功能
bool ModbusTCPMasterController::readDiscreteInputs(int startAddress, int count)
{
    if (!isConnected()) {
        qWarning() << "❌ [ModbusTCPMasterController] 未连接，无法读取离散输入";
        emit errorOccurred("未连接到服务器");
        return false;
    }

    QModbusDataUnit readUnit(QModbusDataUnit::DiscreteInputs, startAddress, count);
    QModbusReply *reply = m_modbusClient->sendReadRequest(readUnit, m_slaveAddress);

    if (!reply) {
        qWarning() << "❌ [ModbusTCPMasterController] 发送读取请求失败";
        emit errorOccurred("发送读取请求失败");
        return false;
    }

    if (reply->isFinished()) {
        if (reply->error() == QModbusDevice::NoError) {
            const QModbusDataUnit unit = reply->result();
            QList<bool> values;
            for (uint i = 0; i < unit.valueCount(); ++i) {
                values.append(unit.value(i) != 0);
            }
            emit discreteInputsRead(startAddress, values);
            qDebug() << "✅ [ModbusTCPMasterController] 读取离散输入成功:" << startAddress << "数量:" << count;
        } else {
            emit errorOccurred(reply->errorString());
        }
        reply->deleteLater();
    } else {
        connect(reply, &QModbusReply::finished, this, [this, reply, startAddress]() {
            if (reply->error() == QModbusDevice::NoError) {
                const QModbusDataUnit unit = reply->result();
                QList<bool> values;
                for (uint i = 0; i < unit.valueCount(); ++i) {
                    values.append(unit.value(i) != 0);
                }
                emit discreteInputsRead(startAddress, values);
                qDebug() << "✅ [ModbusTCPMasterController] 读取离散输入成功:" << startAddress << "数量:" << unit.valueCount();
            } else {
                qWarning() << "❌ [ModbusTCPMasterController] 读取离散输入失败:" << reply->errorString();
                emit errorOccurred(reply->errorString());
            }
            reply->deleteLater();
        });
    }

    return true;
}

// ========== 写入操作 ==========
// ✅ 2026-02-08 [Phase 7.42]: 完善写入单个保持寄存器功能
bool ModbusTCPMasterController::writeHoldingRegister(int address, int value)
{
    if (!isConnected()) {
        qWarning() << "❌ [ModbusTCPMasterController] 未连接，无法写入保持寄存器";
        emit errorOccurred("未连接到服务器");
        return false;
    }

    QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, address, 1);
    writeUnit.setValue(0, static_cast<quint16>(value));

    QModbusReply *reply = m_modbusClient->sendWriteRequest(writeUnit, m_slaveAddress);

    if (!reply) {
        qWarning() << "❌ [ModbusTCPMasterController] 发送写入请求失败";
        emit errorOccurred("发送写入请求失败");
        return false;
    }

    if (reply->isFinished()) {
        if (reply->error() == QModbusDevice::NoError) {
            emit holdingRegisterWritten(address, value);
            qDebug() << "✅ [ModbusTCPMasterController] 写入保持寄存器成功:" << address << "值:" << value;
        } else {
            emit errorOccurred(reply->errorString());
        }
        reply->deleteLater();
    } else {
        connect(reply, &QModbusReply::finished, this, [this, reply, address, value]() {
            if (reply->error() == QModbusDevice::NoError) {
                emit holdingRegisterWritten(address, value);
                qDebug() << "✅ [ModbusTCPMasterController] 写入保持寄存器成功:" << address << "值:" << value;
            } else {
                qWarning() << "❌ [ModbusTCPMasterController] 写入保持寄存器失败:" << reply->errorString();
                emit errorOccurred(reply->errorString());
            }
            reply->deleteLater();
        });
    }

    return true;
}

// ✅ 2026-02-08 [Phase 7.42]: 完善写入多个保持寄存器功能
bool ModbusTCPMasterController::writeHoldingRegisters(int startAddress, const QList<int> &values)
{
    if (!isConnected()) {
        qWarning() << "❌ [ModbusTCPMasterController] 未连接，无法写入保持寄存器";
        emit errorOccurred("未连接到服务器");
        return false;
    }

    if (values.isEmpty()) {
        qWarning() << "❌ [ModbusTCPMasterController] 写入值列表为空";
        emit errorOccurred("写入值列表为空");
        return false;
    }

    QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, startAddress, values.size());
    for (int i = 0; i < values.size(); ++i) {
        writeUnit.setValue(i, static_cast<quint16>(values[i]));
    }

    QModbusReply *reply = m_modbusClient->sendWriteRequest(writeUnit, m_slaveAddress);

    if (!reply) {
        qWarning() << "❌ [ModbusTCPMasterController] 发送写入请求失败";
        emit errorOccurred("发送写入请求失败");
        return false;
    }

    int count = values.size();
    if (reply->isFinished()) {
        if (reply->error() == QModbusDevice::NoError) {
            emit holdingRegistersWritten(startAddress, count);
            qDebug() << "✅ [ModbusTCPMasterController] 写入多个保持寄存器成功:" << startAddress << "数量:" << count;
        } else {
            emit errorOccurred(reply->errorString());
        }
        reply->deleteLater();
    } else {
        connect(reply, &QModbusReply::finished, this, [this, reply, startAddress, count]() {
            if (reply->error() == QModbusDevice::NoError) {
                emit holdingRegistersWritten(startAddress, count);
                qDebug() << "✅ [ModbusTCPMasterController] 写入多个保持寄存器成功:" << startAddress << "数量:" << count;
            } else {
                qWarning() << "❌ [ModbusTCPMasterController] 写入多个保持寄存器失败:" << reply->errorString();
                emit errorOccurred(reply->errorString());
            }
            reply->deleteLater();
        });
    }

    return true;
}

// ✅ 2026-02-08 [Phase 7.42]: 完善写入单个线圈功能
bool ModbusTCPMasterController::writeCoil(int address, bool value)
{
    if (!isConnected()) {
        qWarning() << "❌ [ModbusTCPMasterController] 未连接，无法写入线圈";
        emit errorOccurred("未连接到服务器");
        return false;
    }

    QModbusDataUnit writeUnit(QModbusDataUnit::Coils, address, 1);
    writeUnit.setValue(0, value ? 1 : 0);

    QModbusReply *reply = m_modbusClient->sendWriteRequest(writeUnit, m_slaveAddress);

    if (!reply) {
        qWarning() << "❌ [ModbusTCPMasterController] 发送写入请求失败";
        emit errorOccurred("发送写入请求失败");
        return false;
    }

    if (reply->isFinished()) {
        if (reply->error() == QModbusDevice::NoError) {
            emit coilWritten(address, value);
            qDebug() << "✅ [ModbusTCPMasterController] 写入线圈成功:" << address << "值:" << value;
        } else {
            emit errorOccurred(reply->errorString());
        }
        reply->deleteLater();
    } else {
        connect(reply, &QModbusReply::finished, this, [this, reply, address, value]() {
            if (reply->error() == QModbusDevice::NoError) {
                emit coilWritten(address, value);
                qDebug() << "✅ [ModbusTCPMasterController] 写入线圈成功:" << address << "值:" << value;
            } else {
                qWarning() << "❌ [ModbusTCPMasterController] 写入线圈失败:" << reply->errorString();
                emit errorOccurred(reply->errorString());
            }
            reply->deleteLater();
        });
    }

    return true;
}

// ✅ 2026-02-08 [Phase 7.42]: 完善写入多个线圈功能
bool ModbusTCPMasterController::writeCoils(int startAddress, const QList<bool> &values)
{
    if (!isConnected()) {
        qWarning() << "❌ [ModbusTCPMasterController] 未连接，无法写入线圈";
        emit errorOccurred("未连接到服务器");
        return false;
    }

    if (values.isEmpty()) {
        qWarning() << "❌ [ModbusTCPMasterController] 写入值列表为空";
        emit errorOccurred("写入值列表为空");
        return false;
    }

    QModbusDataUnit writeUnit(QModbusDataUnit::Coils, startAddress, values.size());
    for (int i = 0; i < values.size(); ++i) {
        writeUnit.setValue(i, values[i] ? 1 : 0);
    }

    QModbusReply *reply = m_modbusClient->sendWriteRequest(writeUnit, m_slaveAddress);

    if (!reply) {
        qWarning() << "❌ [ModbusTCPMasterController] 发送写入请求失败";
        emit errorOccurred("发送写入请求失败");
        return false;
    }

    int count = values.size();
    if (reply->isFinished()) {
        if (reply->error() == QModbusDevice::NoError) {
            emit coilsWritten(startAddress, count);
            qDebug() << "✅ [ModbusTCPMasterController] 写入多个线圈成功:" << startAddress << "数量:" << count;
        } else {
            emit errorOccurred(reply->errorString());
        }
        reply->deleteLater();
    } else {
        connect(reply, &QModbusReply::finished, this, [this, reply, startAddress, count]() {
            if (reply->error() == QModbusDevice::NoError) {
                emit coilsWritten(startAddress, count);
                qDebug() << "✅ [ModbusTCPMasterController] 写入多个线圈成功:" << startAddress << "数量:" << count;
            } else {
                qWarning() << "❌ [ModbusTCPMasterController] 写入多个线圈失败:" << reply->errorString();
                emit errorOccurred(reply->errorString());
            }
            reply->deleteLater();
        });
    }

    return true;
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

// ✅ 2026-02-08 [Phase 7.42]: 添加寄存器配置属性
void ModbusTCPMasterController::setStartRegister(int reg)
{
    if (m_startRegister != reg) {
        m_startRegister = reg;
        emit startRegisterChanged();
    }
}

void ModbusTCPMasterController::setRegisterCount(int count)
{
    if (m_registerCount != count) {
        m_registerCount = count;
        emit registerCountChanged();
    }
}

// ✅ 2026-02-08 [Phase 7.42]: 添加配置持久化功能
void ModbusTCPMasterController::initSettings()
{
    m_settings = new QSettings("BeltControlSystem", "ModbusTCPMaster", this);
}

void ModbusTCPMasterController::saveConfig(int portIndex)
{
    if (!m_settings) {
        initSettings();
    }

    QString prefix = QString("Port%1/").arg(portIndex);

    m_settings->setValue(prefix + "targetIP", m_targetIP);
    m_settings->setValue(prefix + "port", m_port);
    m_settings->setValue(prefix + "slaveAddress", m_slaveAddress);
    m_settings->setValue(prefix + "pollInterval", m_pollInterval);
    m_settings->setValue(prefix + "timeout", m_timeout);
    m_settings->setValue(prefix + "retryCount", m_retryCount);
    m_settings->setValue(prefix + "startRegister", m_startRegister);
    m_settings->setValue(prefix + "registerCount", m_registerCount);

    m_settings->sync();
    qDebug() << "✅ [ModbusTCPMasterController] 配置已保存 - 端口:" << portIndex;
}

void ModbusTCPMasterController::loadConfig(int portIndex)
{
    if (!m_settings) {
        initSettings();
    }

    QString prefix = QString("Port%1/").arg(portIndex);

    setTargetIP(m_settings->value(prefix + "targetIP", "192.168.1.1").toString());
    setPort(m_settings->value(prefix + "port", 502 + portIndex - 1).toInt());
    setSlaveAddress(m_settings->value(prefix + "slaveAddress", 1).toInt());
    setPollInterval(m_settings->value(prefix + "pollInterval", 1000).toInt());
    setTimeout(m_settings->value(prefix + "timeout", 3000).toInt());
    setRetryCount(m_settings->value(prefix + "retryCount", 3).toInt());
    setStartRegister(m_settings->value(prefix + "startRegister", 0).toInt());
    setRegisterCount(m_settings->value(prefix + "registerCount", 10).toInt());

    qDebug() << "✅ [ModbusTCPMasterController] 配置已加载 - 端口:" << portIndex;
}

void ModbusTCPMasterController::resetConfig()
{
    setTargetIP("192.168.1.1");
    setPort(502);
    setSlaveAddress(1);
    setPollInterval(1000);
    setTimeout(3000);
    setRetryCount(3);
    setStartRegister(0);
    setRegisterCount(10);

    qDebug() << "✅ [ModbusTCPMasterController] 配置已重置";
}
