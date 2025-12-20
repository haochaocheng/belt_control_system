#include "NetworkTask.h"
#include "../control/SystemConfig.h"
#include <QDebug>

NetworkTask::NetworkTask(QObject *parent)
    : QObject(parent)
    , m_systemConfig(nullptr)
    , m_modbusClient(new ModbusTcpClient(this))
    , m_pollTimer(new QTimer(this))
    , m_isRunning(false)
    , m_isConnected(false)
    , m_isRequestInProgress(false)
{
    qDebug() << "✅ NetworkTask: 网络任务已创建";

    // 连接Modbus客户端信号
    connect(m_modbusClient, &ModbusTcpClient::connectionStateChanged,
            this, &NetworkTask::onConnectionStateChanged);
    connect(m_modbusClient, &ModbusTcpClient::readSuccess,
            this, &NetworkTask::onReadSuccess);
    connect(m_modbusClient, &ModbusTcpClient::readError,
            this, &NetworkTask::onReadError);

    // 连接轮询定时器
    connect(m_pollTimer, &QTimer::timeout,
            this, &NetworkTask::onPollTimerTimeout);
}

NetworkTask::~NetworkTask()
{
    stop();
    qDebug() << "✅ NetworkTask: 网络任务已销毁";
}

void NetworkTask::setSystemConfig(SystemConfig *config)
{
    m_systemConfig = config;
    qDebug() << "🔗 NetworkTask: SystemConfig已连接";
}

void NetworkTask::start()
{
    if (m_isRunning) {
        qDebug() << "⚠️  NetworkTask: 网络任务已经在运行中";
        return;
    }

    if (!m_systemConfig) {
        qWarning() << "❌ NetworkTask: SystemConfig未设置，无法启动";
        return;
    }

    qDebug() << "🚀 NetworkTask: 启动网络任务";
    m_isRunning = true;

    // 连接到Modbus服务器
    connectToServer();

    // 启动轮询定时器
    updatePollInterval();
    m_pollTimer->start();
}

void NetworkTask::stop()
{
    if (!m_isRunning) {
        return;
    }

    qDebug() << "🛑 NetworkTask: 停止网络任务";
    m_isRunning = false;

    // 停止定时器
    m_pollTimer->stop();

    // 断开Modbus连接
    m_modbusClient->disconnectFromServer();
}

void NetworkTask::connectToServer()
{
    if (!m_systemConfig) {
        qWarning() << "❌ NetworkTask: SystemConfig未设置";
        return;
    }

    QString serverIp = m_systemConfig->modbusServerIp();
    int serverPort = 502;  // Modbus TCP默认端口

    qDebug() << "🔌 NetworkTask: 连接到Modbus服务器" << serverIp << ":" << serverPort;
    m_modbusClient->connectToServer(serverIp, serverPort);
}

void NetworkTask::updatePollInterval()
{
    if (!m_systemConfig) {
        return;
    }

    int interval = m_systemConfig->modbusPollInterval();
    m_pollTimer->setInterval(interval);

    qDebug() << "⏱️  NetworkTask: 轮询间隔设置为" << interval << "ms";
}

void NetworkTask::onPollTimerTimeout()
{
    if (!m_isConnected) {
        // 不打印警告，避免日志过多
        return;
    }

    // ========== 防止重复触发 ==========
    // 如果上一轮请求还在进行中，或者队列还有未处理的请求，跳过本次轮询
    // 这是正常行为，不需要打印日志
    if (m_isRequestInProgress || !m_requestQueue.isEmpty()) {
        return;
    }

    // ========== 构建请求队列（串行化处理） ==========
    // 1. 数字保护 - 输入模块1（寄存器2）
    //    包含：急停、跑偏、撕裂、烟雾、温度、护网、堆煤、主机急停
    m_requestQueue.append({2, 1});

    // 2. 模拟量保护 - 模拟量模块1（寄存器5-12，共8个）
    //    包含：速度、张力、红外温度一/二、电流一/二、电压、1号电机温度
    m_requestQueue.append({5, 8});

    // 3. 模拟量保护 - 模拟量模块2（寄存器13-20，共8个）
    //    包含：2号电机温度、1号电机X/Y振动、2号电机X/Y振动、1号电机绕组温度
    m_requestQueue.append({13, 8});

    // 4. 模拟量保护 - 模拟量模块3（寄存器21-23，共3个）
    //    包含：2号电机第一/二/三项绕组温度
    m_requestQueue.append({21, 3});

    // 开始发送第一个请求
    sendNextRequest();
}

void NetworkTask::onConnectionStateChanged(bool connected)
{
    m_isConnected = connected;

    if (connected) {
        qDebug() << "🟢 NetworkTask: Modbus连接已建立";
    } else {
        qDebug() << "🔴 NetworkTask: Modbus连接已断开";

        // 如果任务还在运行，尝试重新连接
        if (m_isRunning) {
            qDebug() << "🔄 NetworkTask: 3秒后尝试重新连接...";
            QTimer::singleShot(3000, this, &NetworkTask::connectToServer);
        }
    }

    emit connectionStatusChanged(connected);
}

void NetworkTask::sendNextRequest()
{
    // 如果已经有请求在处理，或者队列为空，则不发送
    if (m_isRequestInProgress || m_requestQueue.isEmpty()) {
        return;
    }

    // 取出队列中的第一个请求
    ReadRequest request = m_requestQueue.takeFirst();

    // 标记正在处理请求
    m_isRequestInProgress = true;

    // 发送读取请求
    m_modbusClient->readHoldingRegisters(request.startAddress, request.count);
}

void NetworkTask::onReadSuccess(int startAddress, const QVector<quint16> &values)
{
    if (values.isEmpty()) {
        // 标记请求完成，继续下一个
        m_isRequestInProgress = false;
        sendNextRequest();
        return;
    }

    // 处理批量读取的寄存器值
    for (int i = 0; i < values.size(); ++i) {
        int currentAddress = startAddress + i;
        quint16 value = values[i];

        // 只在值变化时打印日志
        if (!m_lastRegisterValues.contains(currentAddress) || m_lastRegisterValues[currentAddress] != value) {
            qDebug() << "📊 NetworkTask: 寄存器[" << currentAddress << "] 值变化: "
                     << m_lastRegisterValues.value(currentAddress, 0) << " -> " << value;
            m_lastRegisterValues[currentAddress] = value;
        }

        // 发射每个寄存器的值（即使没有变化，保护监控服务需要定期检查）
        emit registerValueReceived(currentAddress, value);
    }

    // 标记请求完成，发送下一个请求
    m_isRequestInProgress = false;
    sendNextRequest();
}

void NetworkTask::onReadError(const QString &errorString)
{
    qWarning() << "❌ NetworkTask: 读取失败:" << errorString;

    // 即使出错，也要标记请求完成，继续下一个请求
    m_isRequestInProgress = false;
    sendNextRequest();
}

void NetworkTask::writeDeviceControl(int registerAddress, int channel, bool turnOn)
{
    if (!m_isConnected) {
        qWarning() << "❌ NetworkTask: 未连接到服务器，无法控制设备";
        return;
    }

    if (channel < 0 || channel > 15) {
        qWarning() << "❌ NetworkTask: 通道号超出范围 (0-15):" << channel;
        return;
    }

    // 使用上次读取的寄存器值作为基础（如果有的话）
    quint16 currentValue = m_lastRegisterValues.value(registerAddress, 0);

    // 计算新值：设置或清除对应通道的位
    quint16 newValue;
    if (turnOn) {
        // 设置对应位为1 (OR操作)
        newValue = currentValue | (1 << channel);
    } else {
        // 清除对应位为0 (AND NOT操作)
        newValue = currentValue & ~(1 << channel);
    }

    qDebug() << "🎛️  NetworkTask: 控制设备 - 寄存器:" << registerAddress
             << "通道:" << channel
             << (turnOn ? "开启" : "关闭")
             << "- 当前值:" << QString("0x%1").arg(currentValue, 4, 16, QChar('0'))
             << "-> 新值:" << QString("0x%1").arg(newValue, 4, 16, QChar('0'));

    // 写入新值
    m_modbusClient->writeSingleRegister(registerAddress, newValue);

    // 更新缓存值
    m_lastRegisterValues[registerAddress] = newValue;
}

void NetworkTask::readRegister(int registerAddress, int count)
{
    if (!m_isConnected) {
        qWarning() << "❌ NetworkTask: 未连接到服务器，无法读取寄存器";
        return;
    }

    if (count < 1 || count > 125) {
        qWarning() << "❌ NetworkTask: 读取数量超出范围 (1-125):" << count;
        return;
    }

    qDebug() << "📖 NetworkTask: 读取寄存器 - 地址:" << registerAddress << "数量:" << count;
    m_modbusClient->readHoldingRegisters(registerAddress, count);
}
