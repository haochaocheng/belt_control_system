// ✅ 2026-04-07 [Phase 7.48.88.83]: 新建TCP数据适配层实现
// 数据流：
//   MQTT → 数据管理器 → TCPDataAdapter.onSyncTimer() → Modbus从站寄存器 / S7数据块
//   上位机PLC → Modbus从站写入 → TCPDataAdapter → CommonControl / NetworkTask

#include "TCPDataAdapter.h"
#include "../mqtt/DODataManager.h"
#include "../mqtt/DIDataManager.h"
#include "../mqtt/AIDataManager.h"
#include "../mqtt/CSDataManager.h"
#include "SystemConfig.h"
#include "CommonControl.h"
#include "../network/NetworkTask.h"
#include "ModbusTCPSlaveController.h"
#include "S7ServerController.h"
// ✅ 2026-04-08 [Phase 7.48.88.98]: 控制区新增依赖
#include "MqttProtectionMonitor.h"
#include "ProtectionLogicController.h"
#include "DeviceRuntimeTracker.h"
#include "DeviceConfigManager.h"

#include <QDebug>
#include <QtEndian>
#include <cstring>

TCPDataAdapter::TCPDataAdapter(QObject *parent)
    : QObject(parent)
{
    m_syncTimer = new QTimer(this);
    m_syncTimer->setInterval(m_syncInterval);
    connect(m_syncTimer, &QTimer::timeout, this, &TCPDataAdapter::onSyncTimer);

    // 初始化线圈上升沿检测数组
    memset(m_lastCoilStates, 0, sizeof(m_lastCoilStates));

    qDebug() << "[TCPDataAdapter] 数据适配层已创建, 同步间隔:" << m_syncInterval << "ms";
}

TCPDataAdapter::~TCPDataAdapter()
{
    if (m_syncTimer->isActive()) {
        m_syncTimer->stop();
    }
}

// ===== 数据管理器设置 =====

void TCPDataAdapter::setDODataManager(DODataManager *mgr)
{
    m_doDataManager = mgr;
}

void TCPDataAdapter::setDIDataManager(DIDataManager *mgr)
{
    m_diDataManager = mgr;
}

void TCPDataAdapter::setAIDataManager(AIDataManager *mgr)
{
    m_aiDataManager = mgr;
}

void TCPDataAdapter::setCSDataManager(CSDataManager *mgr)
{
    m_csDataManager = mgr;
}

void TCPDataAdapter::setSystemConfig(SystemConfig *config)
{
    m_systemConfig = config;
}

void TCPDataAdapter::setCommonControl(CommonControl *ctrl)
{
    m_commonControl = ctrl;
}

void TCPDataAdapter::setNetworkTask(NetworkTask *task)
{
    m_networkTask = task;
}

// ✅ 2026-04-08 [Phase 7.48.88.98]: 控制区新增依赖setter

void TCPDataAdapter::setMqttProtectionMonitor(MqttProtectionMonitor *monitor)
{
    m_mqttProtectionMonitor = monitor;
}

void TCPDataAdapter::setProtectionLogicController(ProtectionLogicController *ctrl)
{
    m_protectionLogicController = ctrl;
}

void TCPDataAdapter::setDeviceRuntimeTracker(DeviceRuntimeTracker *tracker)
{
    m_runtimeTracker = tracker;
}

void TCPDataAdapter::setDeviceConfigManager(DeviceConfigManager *mgr)
{
    m_deviceConfigMgr = mgr;
}

// ===== TCP控制器绑定 =====

void TCPDataAdapter::bindModbusSlave(int portIndex, ModbusTCPSlaveController *slave)
{
    if (portIndex < 0 || portIndex >= 8) {
        qWarning() << "[TCPDataAdapter] 无效的端口索引:" << portIndex;
        return;
    }
    m_modbusSlaves[portIndex] = slave;

    if (slave) {
        // 监听上位机写入事件（使用lambda捕获portIndex）
        connect(slave, &ModbusTCPSlaveController::coilWritten,
                this, [this, portIndex](int address, bool value) {
            onCoilWritten(portIndex, address, value);
        });
        connect(slave, &ModbusTCPSlaveController::holdingRegisterWritten,
                this, [this, portIndex](int address, int value) {
            onHoldingRegisterWritten(portIndex, address, value);
        });

        qDebug() << "[TCPDataAdapter] 绑定Modbus从站, 端口:" << portIndex;
    }

    emit activePortsChanged();
}

void TCPDataAdapter::bindS7Server(int portIndex, S7ServerController *server)
{
    if (portIndex < 0 || portIndex >= 8) {
        qWarning() << "[TCPDataAdapter] 无效的端口索引:" << portIndex;
        return;
    }
    m_s7Servers[portIndex] = server;

    if (server) {
        // ✅ 2026-04-08 [Phase 7.48.88.98]: 监听S7 DB2写入事件
        connect(server, &S7ServerController::dataWritten,
                this, [this, portIndex](int area, int dbNumber, int start, int size) {
            Q_UNUSED(area);
            if (dbNumber == S7_DB2_NUMBER) {
                QByteArray data = m_s7Servers[portIndex]->getDBData(S7_DB2_NUMBER, start, size);
                onS7DB2Written(portIndex, dbNumber, start, data);
            }
        });
        qDebug() << "[TCPDataAdapter] 绑定S7服务器, 端口:" << portIndex;
    }

    emit activePortsChanged();
}

// ===== 属性 =====

void TCPDataAdapter::setSyncInterval(int ms)
{
    if (ms < 10) ms = 10;  // 最小10ms
    if (ms > 10000) ms = 10000;  // 最大10秒
    if (m_syncInterval != ms) {
        m_syncInterval = ms;
        m_syncTimer->setInterval(ms);
        emit syncIntervalChanged();
        qDebug() << "[TCPDataAdapter] 同步间隔更新:" << ms << "ms";
    }
}

void TCPDataAdapter::setSyncEnabled(bool enabled)
{
    if (m_syncEnabled != enabled) {
        m_syncEnabled = enabled;
        if (enabled) {
            m_syncTimer->start();
            qDebug() << "[TCPDataAdapter] 数据同步已启动";
        } else {
            m_syncTimer->stop();
            qDebug() << "[TCPDataAdapter] 数据同步已停止";
        }
        emit syncEnabledChanged();
    }
}

int TCPDataAdapter::activePorts() const
{
    int count = 0;
    for (int i = 0; i < 8; i++) {
        if (m_modbusSlaves[i] || m_s7Servers[i]) count++;
    }
    return count;
}

// ===== 初始化端口 =====

void TCPDataAdapter::initializePort(int portIndex)
{
    if (portIndex < 0 || portIndex >= 8) return;

    // 初始化Modbus从站寄存器空间
    if (m_modbusSlaves[portIndex]) {
        m_modbusSlaves[portIndex]->initializeRegisters(
            HR_TOTAL_COUNT,    // 保持寄存器
            IR_TOTAL_COUNT,    // 输入寄存器
            COIL_TOTAL_COUNT,  // 线圈
            DI_TOTAL_COUNT     // 离散输入
        );
        qDebug() << "[TCPDataAdapter] 端口" << portIndex << "Modbus寄存器已初始化:"
                 << "离散输入=" << DI_TOTAL_COUNT
                 << "输入寄存器=" << IR_TOTAL_COUNT
                 << "线圈=" << COIL_TOTAL_COUNT
                 << "保持寄存器=" << HR_TOTAL_COUNT;
    }

    // 初始化S7数据块
    if (m_s7Servers[portIndex]) {
        m_s7Servers[portIndex]->registerDB(S7_DB1_NUMBER, S7_DB1_SIZE);
        m_s7Servers[portIndex]->registerDB(S7_DB2_NUMBER, S7_DB2_SIZE);
        qDebug() << "[TCPDataAdapter] 端口" << portIndex << "S7数据块已注册:"
                 << "DB1=" << S7_DB1_SIZE << "bytes"
                 << "DB2=" << S7_DB2_SIZE << "bytes";
    }
}

// ===== 同步定时器 =====

void TCPDataAdapter::onSyncTimer()
{
    // ✅ 2026-04-08 [Phase 7.48.88.89]: 只同步已启动且已连接的端口
    // 原因：遍历所有8端口会向未初始化的端口写寄存器，产生大量WARNING日志
    for (int i = 0; i < 8; i++) {
        if (m_modbusSlaves[i] && m_modbusSlaves[i]->isConnected()) {
            syncDiscreteInputs(i);
            syncInputRegisters(i);
            emit syncCompleted(i);
        }
        // 旧：if (m_s7Servers[i] && m_s7Servers[i]->property("isConnected").toBool()) {  // 2026-04-09 BUG: S7ServerController没有isConnected属性，应该是isRunning
        if (m_s7Servers[i] && m_s7Servers[i]->isRunning()) {
            syncS7DB1(i);
        }
    }
}

void TCPDataAdapter::syncNow()
{
    onSyncTimer();
}

// ✅ 2026-04-07 [Phase 7.48.88.86]: 启动/停止端口服务

bool TCPDataAdapter::startPortServices(int portIndex)
{
    if (portIndex < 0 || portIndex >= 8) return false;

    bool success = true;

    // ✅ 2026-04-08 [Phase 7.48.88.89]: 调整初始化顺序
    // 必须先初始化寄存器空间（setMap），再启动服务器（connectDevice）
    // 原因：Qt QModbusTcpServer要求setMap在connectDevice之前调用，
    //       否则寄存器空间不完整导致所有setData失败
    // 同时S7的registerDB也必须在startServer之前调用

    // 1) 先初始化寄存器/数据块空间
    initializePort(portIndex);

    // ✅ 2026-04-10 [Phase 7.48.88.105]: 启动前为每个端口分配独立的TCP端口号
    // Modbus: 用502+portIndex（Modbus Poll等工具可以设端口号）
    if (m_modbusSlaves[portIndex]) {
        int modbusPort = 502 + portIndex;
        if (m_modbusSlaves[portIndex]->port() == 502 && portIndex > 0) {
            m_modbusSlaves[portIndex]->setPort(modbusPort);
            qDebug() << "[TCPDataAdapter] 端口" << portIndex << "Modbus端口号自动设为:" << modbusPort;
        }
    }
    // 旧: S7互斥逻辑（共用102端口）已移到startS7Server()  // 2026-04-10 [Phase 7.48.88.105]

    // 2) 再启动服务器（仅Modbus）
    // 旧: 同时启动Modbus和S7  // 2026-04-10 [Phase 7.48.88.105]: S7已分离到独立的startS7Server()
    if (m_modbusSlaves[portIndex]) {
        if (!m_modbusSlaves[portIndex]->startServer()) {
            qWarning() << "[TCPDataAdapter] 端口" << portIndex << "Modbus从站启动失败";
            success = false;
        } else {
            qDebug() << "[TCPDataAdapter] 端口" << portIndex << "Modbus从站已启动";
        }
    }

    // 3) 确保同步已启用
    if (!m_syncEnabled) {
        setSyncEnabled(true);
    }

    return success;
}

void TCPDataAdapter::stopPortServices(int portIndex)
{
    if (portIndex < 0 || portIndex >= 8) return;

    if (m_modbusSlaves[portIndex]) {
        m_modbusSlaves[portIndex]->stopServer();
        qDebug() << "[TCPDataAdapter] 端口" << portIndex << "Modbus从站已停止";
    }
    // 旧: 同时停止S7  // 2026-04-10 [Phase 7.48.88.105]: S7已分离到独立的stopS7Server()
}

bool TCPDataAdapter::isPortRunning(int portIndex) const
{
    if (portIndex < 0 || portIndex >= 8) return false;

    // ✅ 2026-04-10 [Phase 7.48.88.105]: 只检查Modbus状态
    // 旧: 同时检查Modbus和S7  // S7已分离到独立的isS7Running()
    if (m_modbusSlaves[portIndex]) {
        if (m_modbusSlaves[portIndex]->property("isConnected").toBool()) {
            return true;
        }
    }

    return false;
}
    }

    return false;
}

void TCPDataAdapter::autoStart()
{
    // 旧: 仅启动端口0  startPortServices(0);
    // ✅ 2026-04-10 [Phase 7.48.88.106]: 问题3——8个端口全部默认启动
    qDebug() << "[TCPDataAdapter] 自动启动 - 初始化全部8个端口并启用同步";
    for (int i = 0; i < 8; i++) {
        startPortServices(i);
    }
    // ✅ 2026-04-10 [Phase 7.48.88.105]: 同时启动S7服务器
    startS7Server();
}

// ✅ 2026-04-09: 问题2修复——端口配置读写方法，供QML参数配置区实际应用到后端

int TCPDataAdapter::getModbusSlavePort(int portIndex) const
{
    if (portIndex < 0 || portIndex >= 8 || !m_modbusSlaves[portIndex]) return 502 + portIndex;
    return m_modbusSlaves[portIndex]->port();
}

void TCPDataAdapter::setModbusSlavePort(int portIndex, int port)
{
    if (portIndex < 0 || portIndex >= 8 || !m_modbusSlaves[portIndex]) return;
    m_modbusSlaves[portIndex]->setPort(port);
    qDebug() << "[TCPDataAdapter] 端口" << portIndex << "Modbus从站端口号设为:" << port;
}

int TCPDataAdapter::getModbusSlaveAddress(int portIndex) const
{
    if (portIndex < 0 || portIndex >= 8 || !m_modbusSlaves[portIndex]) return 1;
    return m_modbusSlaves[portIndex]->slaveAddress();
}

void TCPDataAdapter::setModbusSlaveAddress(int portIndex, int address)
{
    if (portIndex < 0 || portIndex >= 8 || !m_modbusSlaves[portIndex]) return;
    m_modbusSlaves[portIndex]->setSlaveAddress(address);
    qDebug() << "[TCPDataAdapter] 端口" << portIndex << "Modbus从站地址设为:" << address;
}

int TCPDataAdapter::getModbusMaxConnections(int portIndex) const
{
    if (portIndex < 0 || portIndex >= 8 || !m_modbusSlaves[portIndex]) return 5;
    return m_modbusSlaves[portIndex]->maxConnections();
}

void TCPDataAdapter::setModbusMaxConnections(int portIndex, int max)
{
    if (portIndex < 0 || portIndex >= 8 || !m_modbusSlaves[portIndex]) return;
    m_modbusSlaves[portIndex]->setMaxConnections(max);
    qDebug() << "[TCPDataAdapter] 端口" << portIndex << "Modbus从站最大连接数设为:" << max;
}

QString TCPDataAdapter::getPortStatusText(int portIndex) const
{
    if (portIndex < 0 || portIndex >= 8) return "无效端口";

    // ✅ 2026-04-10 [Phase 7.48.88.105]: 只显示Modbus状态
    // 旧: 同时显示Modbus和S7状态  // S7已分离到独立的getS7StatusText()
    bool modbusExists = m_modbusSlaves[portIndex] != nullptr;
    bool modbusRunning = modbusExists && m_modbusSlaves[portIndex]->isConnected();
    int modbusClients = modbusExists ? m_modbusSlaves[portIndex]->getConnectedClientCount() : 0;

    if (!modbusExists) return "未配置";

    if (!modbusRunning) {
        return "Modbus:已停止";
    } else if (modbusClients > 0) {
        return QString("Modbus:已连接(%1)").arg(modbusClients);
    } else {
        return "Modbus:监听中";
    }
}

// ===== 离散输入同步（10001+ / 只读） =====

// ✅ 2026-04-10 [Phase 7.48.88.105]: S7独立控制方法（从TCP端口服务中分离）
// S7只能使用端口102，同一时间只能运行一个实例，固定使用portIndex=0

bool TCPDataAdapter::startS7Server()
{
    // S7固定使用portIndex=0的S7服务器实例
    const int portIndex = 0;

    if (!m_s7Servers[portIndex]) {
        qWarning() << "[TCPDataAdapter] S7服务器未绑定";
        return false;
    }

    // 先初始化DB数据块空间
    initializePort(portIndex);

    // 启动S7服务器
    if (!m_s7Servers[portIndex]->startServer()) {
        qWarning() << "[TCPDataAdapter] S7服务器启动失败";
        return false;
    }

    qDebug() << "[TCPDataAdapter] S7服务器已启动（端口102）";

    // 确保同步已启用
    if (!m_syncEnabled) {
        setSyncEnabled(true);
    }

    return true;
}

void TCPDataAdapter::stopS7Server()
{
    const int portIndex = 0;
    if (m_s7Servers[portIndex]) {
        m_s7Servers[portIndex]->stopServer();
        qDebug() << "[TCPDataAdapter] S7服务器已停止";
    }
}

bool TCPDataAdapter::isS7Running() const
{
    const int portIndex = 0;
    if (m_s7Servers[portIndex]) {
        return m_s7Servers[portIndex]->isRunning();
    }
    return false;
}

QString TCPDataAdapter::getS7StatusText() const
{
    const int portIndex = 0;
    if (!m_s7Servers[portIndex]) return "未配置";

    if (!m_s7Servers[portIndex]->isRunning()) {
        return "S7:已停止";
    }

    int clients = m_s7Servers[portIndex]->getClientCount();
    if (clients > 0) {
        return QString("S7:已连接(%1)").arg(clients);
    }
    return "S7:监听中(端口102)";
}

// ===== 离散输入同步（10001+ / 只读） =====

void TCPDataAdapter::syncDiscreteInputs(int portIndex)
{
    ModbusTCPSlaveController *slave = m_modbusSlaves[portIndex];
    if (!slave) return;

    // ----- DO输出状态 (10001-10008 → 内部地址0-7) -----
    if (m_doDataManager) {
        QVariantList doStates = m_doDataManager->property("doStates").toList();
        for (int i = 0; i < 8 && i < doStates.size(); i++) {
            slave->setDiscreteInput(DI_DO_STATES_START + i, doStates[i].toBool());
        }

        // DI反馈状态 (10009-10016 → 内部地址8-15)
        QVariantList diFeedback = m_doDataManager->property("diFeedback").toList();
        for (int i = 0; i < 8 && i < diFeedback.size(); i++) {
            slave->setDiscreteInput(DI_DI_FEEDBACK_START + i, diFeedback[i].toBool());
        }

        // 急停状态 (10017 → 内部地址16)
        slave->setDiscreteInput(DI_ESTOP, m_doDataManager->property("estop").toBool());
    }

    // ----- DI模块输入 (10018-10033 → 内部地址17-32) -----
    if (m_diDataManager) {
        QVariantList mod1 = m_diDataManager->property("module1Data").toList();
        for (int i = 0; i < 8 && i < mod1.size(); i++) {
            slave->setDiscreteInput(DI_DI_MODULE1_START + i, mod1[i].toBool());
        }
        QVariantList mod2 = m_diDataManager->property("module2Data").toList();
        for (int i = 0; i < 8 && i < mod2.size(); i++) {
            slave->setDiscreteInput(DI_DI_MODULE2_START + i, mod2[i].toBool());
        }
    }

    // ----- 设备运行状态 (10034-10059 → 内部地址33-58) -----
    if (m_commonControl) {
        // 电机状态 (10034-10041)
        for (int i = 0; i < 8; i++) {
            // CommonControl.isBeltRunning 对应皮带编号1-8
            bool running = m_commonControl->isBeltRunning(i + 1);
            slave->setDiscreteInput(DI_MOTOR_STATUS_START + i, running);
        }

        // 制动器/张紧/洒水状态需要从deviceStatusChanged信号维护的状态获取
        // 这里暂时设为false，后续从QML属性或内部状态表读取
        // TODO: 需要CommonControl提供制动器/张紧/洒水独立查询接口
    }

    // ----- 保护状态 (10060-10067 → 内部地址59-66) -----
    if (m_systemConfig) {
        slave->setDiscreteInput(DI_PROTECTION_START + 0, m_systemConfig->property("emergencyStopActive").toBool());
        slave->setDiscreteInput(DI_PROTECTION_START + 1, m_systemConfig->property("runOffActive").toBool());
        slave->setDiscreteInput(DI_PROTECTION_START + 2, m_systemConfig->property("tearActive").toBool());
        slave->setDiscreteInput(DI_PROTECTION_START + 3, m_systemConfig->property("smokeActive").toBool());
        slave->setDiscreteInput(DI_PROTECTION_START + 4, m_systemConfig->property("temperatureActive").toBool());
        slave->setDiscreteInput(DI_PROTECTION_START + 5, m_systemConfig->property("guardNetActive").toBool());
        slave->setDiscreteInput(DI_PROTECTION_START + 6, m_systemConfig->property("coalPileActive").toBool());
        slave->setDiscreteInput(DI_PROTECTION_START + 7, m_systemConfig->property("mainEmergencyStopActive").toBool());
    }

    // ----- 沿线保护 (10101-10364 → 内部地址100-363) -----
    if (m_csDataManager) {
        // 沿线急停 64点 (内部地址100-163)
        QVariantList estopData = m_csDataManager->getProtectionData(0);  // Estop=0
        for (int i = 0; i < 64 && i < estopData.size(); i++) {
            slave->setDiscreteInput(DI_CS_ESTOP_START + i, estopData[i].toBool());
        }
        // 沿线跑偏 64点 (内部地址200-263)
        QVariantList devData = m_csDataManager->getProtectionData(1);  // Deviation=1
        for (int i = 0; i < 64 && i < devData.size(); i++) {
            slave->setDiscreteInput(DI_CS_DEVIATION_START + i, devData[i].toBool());
        }
        // 沿线撕裂 64点 (内部地址300-363)
        QVariantList tearData = m_csDataManager->getProtectionData(2);  // Tear=2
        for (int i = 0; i < 64 && i < tearData.size(); i++) {
            slave->setDiscreteInput(DI_CS_TEAR_START + i, tearData[i].toBool());
        }
    }
}

// ===== 输入寄存器同步（30001+ / 只读 / 16位） =====

void TCPDataAdapter::syncInputRegisters(int portIndex)
{
    ModbusTCPSlaveController *slave = m_modbusSlaves[portIndex];
    if (!slave) return;

    // ----- AI模块数据 (30001-30016 → 内部地址0-15) -----
    if (m_aiDataManager) {
        QVariantList mod3 = m_aiDataManager->property("module3Data").toList();
        for (int i = 0; i < 8 && i < mod3.size(); i++) {
            QVariantMap chData = mod3[i].toMap();
            slave->setInputRegister(IR_AI_MODULE3_START + i, chData["adValue"].toInt());
        }
        QVariantList mod4 = m_aiDataManager->property("module4Data").toList();
        for (int i = 0; i < 8 && i < mod4.size(); i++) {
            QVariantMap chData = mod4[i].toMap();
            slave->setInputRegister(IR_AI_MODULE4_START + i, chData["adValue"].toInt());
        }
    }

    // ----- 系统配置参数 -----
    if (m_systemConfig) {
        // 本机编号 (30017)
        slave->setInputRegister(IR_MACHINE_NUMBER, m_systemConfig->property("machineNumber").toInt());

        // 工作模式 (30018)
        slave->setInputRegister(IR_WORK_MODE, m_systemConfig->property("workMode").toInt());

        // 浮点数参数（每个占2个寄存器，HiWord在前）
        auto syncFloat = [&](int startAddr, const char *propName) {
            float val = m_systemConfig->property(propName).toFloat();
            int hi, lo;
            floatToRegisters(val, hi, lo);
            slave->setInputRegister(startAddr, hi);
            slave->setInputRegister(startAddr + 1, lo);
        };

        syncFloat(IR_SPEED_START, "speedValue");
        syncFloat(IR_TENSION_START, "tensionValue");
        syncFloat(IR_MOTOR1_CURRENT_START, "motor1CurrentValue");
        syncFloat(IR_MOTOR2_CURRENT_START, "motor2CurrentValue");
        syncFloat(IR_MOTOR1_VOLTAGE_START, "motor1VoltageValue");
        syncFloat(IR_MOTOR2_VOLTAGE_START, "motor2VoltageValue");
        syncFloat(IR_MOTOR1_XVIB_START, "motor1XVibrationValue");
        syncFloat(IR_MOTOR1_YVIB_START, "motor1YVibrationValue");
        syncFloat(IR_MOTOR2_XVIB_START, "motor2XVibrationValue");
        syncFloat(IR_MOTOR2_YVIB_START, "motor2YVibrationValue");
        syncFloat(IR_MOTOR1_TEMP_START, "motor1TemperatureValue");
        syncFloat(IR_MOTOR2_TEMP_START, "motor2TemperatureValue");

        // 电机1绕组ABC (30043-30048)
        syncFloat(IR_MOTOR1_WINDING_START, "motor1PhaseAWindingValue");
        syncFloat(IR_MOTOR1_WINDING_START + 2, "motor1PhaseBWindingValue");
        syncFloat(IR_MOTOR1_WINDING_START + 4, "motor1PhaseCWindingValue");

        // 电机2绕组ABC (30049-30054)
        syncFloat(IR_MOTOR2_WINDING_START, "motor2PhaseAWindingValue");
        syncFloat(IR_MOTOR2_WINDING_START + 2, "motor2PhaseBWindingValue");
        syncFloat(IR_MOTOR2_WINDING_START + 4, "motor2PhaseCWindingValue");

        // ✅ 2026-04-08 [Phase 7.48.88.97]: 环境模拟量扩展（16个）
        syncFloat(IR_TEMPERATURE1_START, "temperature1Value");
        syncFloat(IR_TEMPERATURE2_START, "temperature2Value");
        syncFloat(IR_TEMPERATURE_ENV_START, "temperatureValue");
        syncFloat(IR_HUMIDITY_START, "humidityValue");
        syncFloat(IR_METHANE_START, "methaneValue");
        syncFloat(IR_DUST_START, "dustValue");
        syncFloat(IR_COALFLOW_START, "coalFlowValue");
        syncFloat(IR_SILOHEIGHT_START, "siloHeightValue");
        syncFloat(IR_VOLTAGE_ENV_START, "voltageValue");
        syncFloat(IR_SMOKE_START, "smokeValue");
        syncFloat(IR_PRESSURE_START, "pressureValue");
        syncFloat(IR_OXYGEN_START, "oxygenValue");
        syncFloat(IR_CO_START, "coValue");
        syncFloat(IR_H2S_START, "h2sValue");
        syncFloat(IR_CO2_START, "co2Value");
        syncFloat(IR_WINDSPEED_START, "windSpeedValue");

        // ✅ 2026-04-08 [Phase 7.48.88.97]: 电机1-2 扩展Tab（前/后轴承、堵转、起动超时、功率、不平衡）
        // 使用Q_INVOKABLE motorProtectionValue(motorIndex, tabIndex)读取
        auto syncMotorTab = [&](int startAddr, int motorIdx, int tabIdx) {
            float val = static_cast<float>(
                static_cast<SystemConfig*>(m_systemConfig)->motorProtectionValue(motorIdx, tabIdx));
            int hi, lo;
            floatToRegisters(val, hi, lo);
            slave->setInputRegister(startAddr, hi);
            slave->setInputRegister(startAddr + 1, lo);
        };
        syncMotorTab(IR_MOTOR1_FRONT_BEARING_START, 0, SystemConfig::TAB_FRONT_BEARING);
        syncMotorTab(IR_MOTOR1_REAR_BEARING_START,  0, SystemConfig::TAB_REAR_BEARING);
        syncMotorTab(IR_MOTOR1_STALL_START,         0, SystemConfig::TAB_STALL);
        syncMotorTab(IR_MOTOR1_START_TIMEOUT_START,  0, SystemConfig::TAB_START_TIMEOUT);
        syncMotorTab(IR_MOTOR1_POWER_START,          0, SystemConfig::TAB_POWER);
        syncMotorTab(IR_MOTOR1_IMBALANCE_START,      0, SystemConfig::TAB_IMBALANCE);
        syncMotorTab(IR_MOTOR2_FRONT_BEARING_START, 1, SystemConfig::TAB_FRONT_BEARING);
        syncMotorTab(IR_MOTOR2_REAR_BEARING_START,  1, SystemConfig::TAB_REAR_BEARING);
        syncMotorTab(IR_MOTOR2_STALL_START,         1, SystemConfig::TAB_STALL);
        syncMotorTab(IR_MOTOR2_START_TIMEOUT_START,  1, SystemConfig::TAB_START_TIMEOUT);
        syncMotorTab(IR_MOTOR2_POWER_START,          1, SystemConfig::TAB_POWER);
        syncMotorTab(IR_MOTOR2_IMBALANCE_START,      1, SystemConfig::TAB_IMBALANCE);

        // ✅ 2026-04-08 [Phase 7.48.88.97]: 电机3-8 完整数据块（每电机28寄存器）
        for (int m = 2; m < SystemConfig::MOTOR_COUNT; m++) {
            int base = IR_MOTOR_BLOCK_START + (m - 2) * IR_MOTOR_BLOCK_SIZE;
            // Tab 1-13（每Tab占2寄存器，tab0无值）
            for (int t = 1; t < SystemConfig::MOTOR_TAB_COUNT; t++) {
                int addr = base + (t - 1) * 2;
                syncMotorTab(addr, m, t);
            }
            // 电压（独立，偏移26-27）— 电机3-8暂无独立电压属性，保留0
            slave->setInputRegister(base + 26, 0);
            slave->setInputRegister(base + 27, 0);
        }
    }

    // ----- 打包状态寄存器 (30055-30062) -----
    // DO状态打包 (30055)
    if (m_doDataManager) {
        QVariantList doStates = m_doDataManager->property("doStates").toList();
        int packed = 0;
        for (int i = 0; i < 8 && i < doStates.size(); i++) {
            if (doStates[i].toBool()) packed |= (1 << i);
        }
        slave->setInputRegister(IR_DO_PACKED, packed);

        // DI反馈打包 (30056)
        QVariantList diFb = m_doDataManager->property("diFeedback").toList();
        int fbPacked = 0;
        for (int i = 0; i < 8 && i < diFb.size(); i++) {
            if (diFb[i].toBool()) fbPacked |= (1 << i);
        }
        slave->setInputRegister(IR_DIFB_PACKED, fbPacked);
    }

    // DI模块打包 (30057-30058)
    if (m_diDataManager) {
        int mod1Packed = m_diDataManager->getByte(0);
        int mod2Packed = m_diDataManager->getByte(1);
        slave->setInputRegister(IR_DI_MOD1_PACKED, mod1Packed);
        slave->setInputRegister(IR_DI_MOD2_PACKED, mod2Packed);
    }

    // 电机状态打包 (30059)
    if (m_commonControl) {
        int motorPacked = 0;
        for (int i = 0; i < 8; i++) {
            if (m_commonControl->isBeltRunning(i + 1)) motorPacked |= (1 << i);
        }
        slave->setInputRegister(IR_MOTOR_PACKED, motorPacked);
    }

    // 制动器/洒水/张紧打包 (30060-30061): TODO 需要CommonControl提供查询接口
    // 保护状态打包 (30062)
    if (m_systemConfig) {
        int protPacked = 0;
        if (m_systemConfig->property("emergencyStopActive").toBool()) protPacked |= (1 << 0);
        if (m_systemConfig->property("runOffActive").toBool()) protPacked |= (1 << 1);
        if (m_systemConfig->property("tearActive").toBool()) protPacked |= (1 << 2);
        if (m_systemConfig->property("smokeActive").toBool()) protPacked |= (1 << 3);
        if (m_systemConfig->property("temperatureActive").toBool()) protPacked |= (1 << 4);
        if (m_systemConfig->property("guardNetActive").toBool()) protPacked |= (1 << 5);
        if (m_systemConfig->property("coalPileActive").toBool()) protPacked |= (1 << 6);
        if (m_systemConfig->property("mainEmergencyStopActive").toBool()) protPacked |= (1 << 7);
        slave->setInputRegister(IR_PROTECTION_PACKED, protPacked);
    }
}

// ===== S7 DB1同步 =====

void TCPDataAdapter::syncS7DB1(int portIndex)
{
    S7ServerController *server = m_s7Servers[portIndex];
    if (!server) return;

    // 构建DB1数据缓冲区
    // 旧值: QByteArray db1(S7_DB1_SIZE, 0);  // 2026-04-09: S7_DB1_SIZE从256扩展到640
    QByteArray db1(S7_DB1_SIZE, 0);

    // ========== 基本数据区 (Byte 0-139) ==========

    // Byte 0: DO输出状态 (bit0-7)
    if (m_doDataManager) {
        QVariantList doStates = m_doDataManager->property("doStates").toList();
        quint8 doByte = 0;
        for (int i = 0; i < 8 && i < doStates.size(); i++) {
            if (doStates[i].toBool()) doByte |= (1 << i);
        }
        db1[0] = doByte;

        // Byte 1: DI反馈状态 (bit0-7)
        QVariantList diFb = m_doDataManager->property("diFeedback").toList();
        quint8 fbByte = 0;
        for (int i = 0; i < 8 && i < diFb.size(); i++) {
            if (diFb[i].toBool()) fbByte |= (1 << i);
        }
        db1[1] = fbByte;

        // Byte 4: 急停状态
        db1[4] = m_doDataManager->property("estop").toBool() ? 1 : 0;
    }

    // Byte 2-3: DI模块1/2
    if (m_diDataManager) {
        db1[2] = static_cast<char>(m_diDataManager->getByte(0));
        db1[3] = static_cast<char>(m_diDataManager->getByte(1));
    }

    // Byte 5: 电机运行状态
    if (m_commonControl) {
        quint8 motorByte = 0;
        for (int i = 0; i < 8; i++) {
            if (m_commonControl->isBeltRunning(i + 1)) motorByte |= (1 << i);
        }
        db1[5] = motorByte;
    }

    // Byte 6-8: 制动器/洒水/张紧 (TODO)
    // Byte 9: 保护状态汇总
    if (m_systemConfig) {
        quint8 protByte = 0;
        if (m_systemConfig->property("emergencyStopActive").toBool()) protByte |= (1 << 0);
        if (m_systemConfig->property("runOffActive").toBool()) protByte |= (1 << 1);
        if (m_systemConfig->property("tearActive").toBool()) protByte |= (1 << 2);
        if (m_systemConfig->property("smokeActive").toBool()) protByte |= (1 << 3);
        if (m_systemConfig->property("temperatureActive").toBool()) protByte |= (1 << 4);
        if (m_systemConfig->property("guardNetActive").toBool()) protByte |= (1 << 5);
        if (m_systemConfig->property("coalPileActive").toBool()) protByte |= (1 << 6);
        if (m_systemConfig->property("mainEmergencyStopActive").toBool()) protByte |= (1 << 7);
        db1[9] = protByte;

        // Byte 10-11: 工作模式(高字节) + 本机编号(低字节)
        quint16 modeMachine = (m_systemConfig->property("workMode").toInt() << 8)
                            | (m_systemConfig->property("machineNumber").toInt() & 0xFF);
        qToBigEndian(modeMachine, reinterpret_cast<uchar*>(db1.data() + 10));
    }

    // Byte 12-43: AI 16通道 (16 × WORD, Big-Endian)
    if (m_aiDataManager) {
        QVariantList mod3 = m_aiDataManager->property("module3Data").toList();
        for (int i = 0; i < 8 && i < mod3.size(); i++) {
            QVariantMap chData = mod3[i].toMap();
            quint16 adVal = chData["adValue"].toUInt();
            qToBigEndian(adVal, reinterpret_cast<uchar*>(db1.data() + 12 + i * 2));
        }
        QVariantList mod4 = m_aiDataManager->property("module4Data").toList();
        for (int i = 0; i < 8 && i < mod4.size(); i++) {
            QVariantMap chData = mod4[i].toMap();
            quint16 adVal = chData["adValue"].toUInt();
            qToBigEndian(adVal, reinterpret_cast<uchar*>(db1.data() + 12 + (8 + i) * 2));
        }
    }

    // Byte 44-115: 基本浮点参数 (REAL, Big-Endian)
    if (m_systemConfig) {
        auto writeFloat = [&](int offset, const char *propName) {
            float val = m_systemConfig->property(propName).toFloat();
            QByteArray bytes = floatToBytes(val);
            memcpy(db1.data() + offset, bytes.constData(), 4);
        };

        writeFloat(44, "speedValue");
        writeFloat(48, "tensionValue");
        writeFloat(52, "motor1CurrentValue");
        writeFloat(56, "motor2CurrentValue");
        writeFloat(60, "motor1VoltageValue");
        writeFloat(64, "motor2VoltageValue");
        writeFloat(68, "motor1XVibrationValue");
        writeFloat(72, "motor1YVibrationValue");
        writeFloat(76, "motor2XVibrationValue");
        writeFloat(80, "motor2YVibrationValue");
        writeFloat(84, "motor1TemperatureValue");
        writeFloat(88, "motor2TemperatureValue");
        writeFloat(92, "motor1PhaseAWindingValue");
        writeFloat(96, "motor1PhaseBWindingValue");
        writeFloat(100, "motor1PhaseCWindingValue");
        writeFloat(104, "motor2PhaseAWindingValue");
        writeFloat(108, "motor2PhaseBWindingValue");
        writeFloat(112, "motor2PhaseCWindingValue");
    }

    // Byte 116-139: 沿线保护 (3×64 bit = 24 bytes)
    if (m_csDataManager) {
        for (int prot = 0; prot < 3; prot++) {
            QVariantList data = m_csDataManager->getProtectionData(prot);
            int baseOffset = 116 + prot * 8;
            quint8 bytes[8] = {};
            for (int i = 0; i < 64 && i < data.size(); i++) {
                if (data[i].toBool()) {
                    bytes[i / 8] |= (1 << (i % 8));
                }
            }
            memcpy(db1.data() + baseOffset, bytes, 8);
        }
    }

    // ========== ✅ 2026-04-09: 扩展数据区 (Byte 140-587) ==========
    // 与Modbus输入寄存器完全对应，确保S7从站数据与Modbus从站一致

    if (m_systemConfig) {
        auto writeFloat = [&](int offset, const char *propName) {
            float val = m_systemConfig->property(propName).toFloat();
            QByteArray bytes = floatToBytes(val);
            memcpy(db1.data() + offset, bytes.constData(), 4);
        };

        // ----- Byte 140-203: 16个环境模拟量FLOAT32 (对应Modbus IR 62-93) -----
        writeFloat(S7_DB1_ENV_START + 0,  "temperature1Value");    // 温度一
        writeFloat(S7_DB1_ENV_START + 4,  "temperature2Value");    // 温度二
        writeFloat(S7_DB1_ENV_START + 8,  "temperatureValue");     // 温度（环境）
        writeFloat(S7_DB1_ENV_START + 12, "humidityValue");        // 湿度
        writeFloat(S7_DB1_ENV_START + 16, "methaneValue");         // 甲烷
        writeFloat(S7_DB1_ENV_START + 20, "dustValue");            // 粉尘浓度
        writeFloat(S7_DB1_ENV_START + 24, "coalFlowValue");        // 煤流
        writeFloat(S7_DB1_ENV_START + 28, "siloHeightValue");      // 煤仓高度
        writeFloat(S7_DB1_ENV_START + 32, "voltageValue");         // 电压（环境）
        writeFloat(S7_DB1_ENV_START + 36, "smokeValue");           // 烟雾
        writeFloat(S7_DB1_ENV_START + 40, "pressureValue");        // 气压
        writeFloat(S7_DB1_ENV_START + 44, "oxygenValue");          // 氧气
        writeFloat(S7_DB1_ENV_START + 48, "coValue");              // 一氧化碳
        writeFloat(S7_DB1_ENV_START + 52, "h2sValue");             // 硫化氢
        writeFloat(S7_DB1_ENV_START + 56, "co2Value");             // 二氧化碳
        writeFloat(S7_DB1_ENV_START + 60, "windSpeedValue");       // 风速

        // ----- Byte 204-251: 电机1-2扩展Tab (对应Modbus IR 94-117) -----
        auto writeMotorTab = [&](int offset, int motorIdx, int tabIdx) {
            float val = static_cast<float>(
                static_cast<SystemConfig*>(m_systemConfig)->motorProtectionValue(motorIdx, tabIdx));
            QByteArray bytes = floatToBytes(val);
            memcpy(db1.data() + offset, bytes.constData(), 4);
        };

        // 电机1扩展 (Byte 204-227)
        writeMotorTab(S7_DB1_MOTOR12_EXT_START + 0,  0, SystemConfig::TAB_FRONT_BEARING);  // 前轴承
        writeMotorTab(S7_DB1_MOTOR12_EXT_START + 4,  0, SystemConfig::TAB_REAR_BEARING);   // 后轴承
        writeMotorTab(S7_DB1_MOTOR12_EXT_START + 8,  0, SystemConfig::TAB_STALL);          // 堵转
        writeMotorTab(S7_DB1_MOTOR12_EXT_START + 12, 0, SystemConfig::TAB_START_TIMEOUT);  // 起动超时
        writeMotorTab(S7_DB1_MOTOR12_EXT_START + 16, 0, SystemConfig::TAB_POWER);          // 功率
        writeMotorTab(S7_DB1_MOTOR12_EXT_START + 20, 0, SystemConfig::TAB_IMBALANCE);      // 不平衡

        // 电机2扩展 (Byte 228-251)
        writeMotorTab(S7_DB1_MOTOR12_EXT_START + 24, 1, SystemConfig::TAB_FRONT_BEARING);
        writeMotorTab(S7_DB1_MOTOR12_EXT_START + 28, 1, SystemConfig::TAB_REAR_BEARING);
        writeMotorTab(S7_DB1_MOTOR12_EXT_START + 32, 1, SystemConfig::TAB_STALL);
        writeMotorTab(S7_DB1_MOTOR12_EXT_START + 36, 1, SystemConfig::TAB_START_TIMEOUT);
        writeMotorTab(S7_DB1_MOTOR12_EXT_START + 40, 1, SystemConfig::TAB_POWER);
        writeMotorTab(S7_DB1_MOTOR12_EXT_START + 44, 1, SystemConfig::TAB_IMBALANCE);

        // ----- Byte 252-587: 电机3-8完整数据块 (对应Modbus IR 120-287) -----
        // 每电机14个Tab值 × 4字节 = 56字节
        for (int m = 2; m < SystemConfig::MOTOR_COUNT; m++) {
            int base = S7_DB1_MOTOR_BLOCK_START + (m - 2) * S7_DB1_MOTOR_BLOCK_SIZE;
            // Tab 1-13 (tab0无值)
            for (int t = 1; t < SystemConfig::MOTOR_TAB_COUNT; t++) {
                int offset = base + (t - 1) * 4;  // 每Tab占4字节(FLOAT32)
                writeMotorTab(offset, m, t);
            }
            // 电压（独立，偏移52-55）— 电机3-8暂无独立电压属性，保留0
            // db1[base+52..base+55] 已被初始化为0
        }
    }

    // 一次性写入整个DB1
    server->setDBData(S7_DB1_NUMBER, 0, db1);
}

// ===== 线圈写入事件处理 =====

void TCPDataAdapter::onCoilWritten(int portIndex, int address, bool value)
{
    // 上升沿检测：只在从0→1时触发命令
    // 旧值: if (address >= 0 && address < 32)
    if (address >= 0 && address < COIL_TOTAL_COUNT) {  // ✅ Phase 7.48.88.98: 扩展到64
        bool lastState = m_lastCoilStates[portIndex][address];
        m_lastCoilStates[portIndex][address] = value;

        if (value && !lastState) {
            // 上升沿，执行命令
            handleCoilCommand(portIndex, address, true);

            // 自动清零（下一个周期会被检测为下降沿）
            if (m_modbusSlaves[portIndex]) {
                QTimer::singleShot(50, this, [this, portIndex, address]() {
                    if (m_modbusSlaves[portIndex]) {
                        m_modbusSlaves[portIndex]->setCoil(address, false);
                        m_lastCoilStates[portIndex][address] = false;
                    }
                });
            }
        }
    }
}

void TCPDataAdapter::onHoldingRegisterWritten(int portIndex, int address, int value)
{
    handleHoldingRegisterCommand(portIndex, address, value);
}

// ===== 命令处理 =====

void TCPDataAdapter::handleCoilCommand(int portIndex, int address, bool value)
{
    Q_UNUSED(value);

    qDebug() << "[TCPDataAdapter] 线圈命令: 端口=" << portIndex
             << "地址=" << address;

    // DO输出控制 (线圈0-7)
    if (address >= COIL_DO_START && address < COIL_DO_START + 8) {
        int channel = address - COIL_DO_START;
        if (m_networkTask) {
            // writeDeviceControl(registerAddress, channel, turnOn)
            // 继电器控制通过NetworkTask发送到IO模块
            m_networkTask->writeDeviceControl(0, channel, true);
            emit commandReceived(portIndex, "DO_ON", channel);
            qDebug() << "[TCPDataAdapter] DO控制: 通道" << channel << "ON";
        }
        return;
    }

    // 启动皮带 (线圈8)
    if (address == COIL_START_BELT) {
        if (!isRemoteControlAllowed()) {
            qWarning() << "[TCPDataAdapter] 远程启动被拒绝: 当前非集控模式";
            emit errorOccurred("远程启动被拒绝：当前非集控模式");
            return;
        }
        if (m_commonControl) {
            int beltNumber = getTargetBeltNumber();
            m_commonControl->startBelt(beltNumber);
            emit commandReceived(portIndex, "START_BELT", beltNumber);
            qDebug() << "[TCPDataAdapter] 远程启动皮带:" << beltNumber;
        }
        return;
    }

    // 停止皮带 (线圈9)
    if (address == COIL_STOP_BELT) {
        if (!isRemoteControlAllowed()) {
            qWarning() << "[TCPDataAdapter] 远程停止被拒绝: 当前非集控模式";
            emit errorOccurred("远程停止被拒绝：当前非集控模式");
            return;
        }
        if (m_commonControl) {
            int beltNumber = getTargetBeltNumber();
            m_commonControl->stopBelt(beltNumber);
            emit commandReceived(portIndex, "STOP_BELT", beltNumber);
            qDebug() << "[TCPDataAdapter] 远程停止皮带:" << beltNumber;
        }
        return;
    }

    // 紧急停车 (线圈10)
    if (address == COIL_EMERGENCY_STOP) {
        // 紧急停车不受工作模式限制
        if (m_commonControl) {
            int beltNumber = getTargetBeltNumber();
            m_commonControl->emergencyStopBelt(beltNumber);
            emit commandReceived(portIndex, "EMERGENCY_STOP", beltNumber);
            qWarning() << "[TCPDataAdapter] ⚠ 远程紧急停车:" << beltNumber;
        }
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: B组 — 电机独立启动 (线圈11-18)
    if (address >= COIL_MOTOR_START_START && address < COIL_MOTOR_START_START + 8) {
        if (!isRemoteControlAllowed()) {
            qWarning() << "[TCPDataAdapter] 远程电机启动被拒绝: 当前非集控模式";
            emit errorOccurred("远程电机启动被拒绝：当前非集控模式");
            return;
        }
        int motorIdx = address - COIL_MOTOR_START_START;  // 0-7
        int beltNumber = getTargetBeltNumber();
        if (m_mqttProtectionMonitor) {
            m_mqttProtectionMonitor->publishMotorCommand(beltNumber, motorIdx, true);
            emit commandReceived(portIndex, "MOTOR_START", motorIdx + 1);
            qDebug() << "[TCPDataAdapter] 远程电机启动: 皮带" << beltNumber << "电机" << (motorIdx + 1);
        }
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: B组 — 电机独立停止 (线圈19-26)
    if (address >= COIL_MOTOR_STOP_START && address < COIL_MOTOR_STOP_START + 8) {
        if (!isRemoteControlAllowed()) {
            qWarning() << "[TCPDataAdapter] 远程电机停止被拒绝: 当前非集控模式";
            emit errorOccurred("远程电机停止被拒绝：当前非集控模式");
            return;
        }
        int motorIdx = address - COIL_MOTOR_STOP_START;  // 0-7
        int beltNumber = getTargetBeltNumber();
        if (m_mqttProtectionMonitor) {
            m_mqttProtectionMonitor->publishMotorCommand(beltNumber, motorIdx, false);
            emit commandReceived(portIndex, "MOTOR_STOP", motorIdx + 1);
            qDebug() << "[TCPDataAdapter] 远程电机停止: 皮带" << beltNumber << "电机" << (motorIdx + 1);
        }
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: C组 — 洒水启动 (线圈27-34)
    if (address >= COIL_SPRINKLER_START_START && address < COIL_SPRINKLER_START_START + 8) {
        if (!isRemoteControlAllowed()) {
            qWarning() << "[TCPDataAdapter] 远程洒水启动被拒绝: 当前非集控模式";
            emit errorOccurred("远程洒水启动被拒绝：当前非集控模式");
            return;
        }
        int sprinklerIdx = address - COIL_SPRINKLER_START_START + 1;  // 1-8
        if (m_mqttProtectionMonitor) {
            m_mqttProtectionMonitor->publishSprinklerCommand(sprinklerIdx, true);
            emit commandReceived(portIndex, "SPRINKLER_START", sprinklerIdx);
            qDebug() << "[TCPDataAdapter] 远程洒水启动:" << sprinklerIdx;
        }
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: C组 — 洒水停止 (线圈35-42)
    if (address >= COIL_SPRINKLER_STOP_START && address < COIL_SPRINKLER_STOP_START + 8) {
        if (!isRemoteControlAllowed()) {
            qWarning() << "[TCPDataAdapter] 远程洒水停止被拒绝: 当前非集控模式";
            emit errorOccurred("远程洒水停止被拒绝：当前非集控模式");
            return;
        }
        int sprinklerIdx = address - COIL_SPRINKLER_STOP_START + 1;  // 1-8
        if (m_mqttProtectionMonitor) {
            m_mqttProtectionMonitor->publishSprinklerCommand(sprinklerIdx, false);
            emit commandReceived(portIndex, "SPRINKLER_STOP", sprinklerIdx);
            qDebug() << "[TCPDataAdapter] 远程洒水停止:" << sprinklerIdx;
        }
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: D组 — 复位全部保护 (线圈43)
    if (address == COIL_RESET_ALL_PROTECTION) {
        if (!isRemoteControlAllowed()) {
            qWarning() << "[TCPDataAdapter] 远程保护复位被拒绝: 当前非集控模式";
            emit errorOccurred("远程保护复位被拒绝：当前非集控模式");
            return;
        }
        if (m_protectionLogicController) {
            m_protectionLogicController->resetAllProtections();
            emit commandReceived(portIndex, "RESET_ALL_PROTECTION", 0);
            qDebug() << "[TCPDataAdapter] 远程复位全部保护";
        }
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: D组 — 复位速度保护报警 (线圈44)
    if (address == COIL_RESET_SPEED_ALARM) {
        if (!isRemoteControlAllowed()) {
            qWarning() << "[TCPDataAdapter] 远程速度报警复位被拒绝: 当前非集控模式";
            emit errorOccurred("远程速度报警复位被拒绝：当前非集控模式");
            return;
        }
        int beltNumber = getTargetBeltNumber();
        if (m_mqttProtectionMonitor) {
            m_mqttProtectionMonitor->resetSpeedProtectionAlarm(beltNumber);
            emit commandReceived(portIndex, "RESET_SPEED_ALARM", beltNumber);
            qDebug() << "[TCPDataAdapter] 远程复位速度保护报警: 皮带" << beltNumber;
        }
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: D组 — 复位故障状态 (线圈45)
    if (address == COIL_RESET_FAULT) {
        if (!isRemoteControlAllowed()) {
            qWarning() << "[TCPDataAdapter] 远程故障复位被拒绝: 当前非集控模式";
            emit errorOccurred("远程故障复位被拒绝：当前非集控模式");
            return;
        }
        if (m_runtimeTracker) {
            m_runtimeTracker->resetFault();
            emit commandReceived(portIndex, "RESET_FAULT", 0);
            qDebug() << "[TCPDataAdapter] 远程复位故障状态";
        }
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: D组 — 启动设备序列 (线圈46)
    if (address == COIL_START_SEQUENCE) {
        if (!isRemoteControlAllowed()) {
            qWarning() << "[TCPDataAdapter] 远程启动序列被拒绝: 当前非集控模式";
            emit errorOccurred("远程启动序列被拒绝：当前非集控模式");
            return;
        }
        int beltNumber = getTargetBeltNumber();
        if (m_commonControl) {
            m_commonControl->startDeviceSequence(beltNumber);
            emit commandReceived(portIndex, "START_SEQUENCE", beltNumber);
            qDebug() << "[TCPDataAdapter] 远程启动设备序列: 皮带" << beltNumber;
        }
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: D组 — 停止设备序列 (线圈47)
    if (address == COIL_STOP_SEQUENCE) {
        if (!isRemoteControlAllowed()) {
            qWarning() << "[TCPDataAdapter] 远程停止序列被拒绝: 当前非集控模式";
            emit errorOccurred("远程停止序列被拒绝：当前非集控模式");
            return;
        }
        int beltNumber = getTargetBeltNumber();
        if (m_commonControl) {
            m_commonControl->stopDeviceSequence(beltNumber);
            emit commandReceived(portIndex, "STOP_SEQUENCE", beltNumber);
            qDebug() << "[TCPDataAdapter] 远程停止设备序列: 皮带" << beltNumber;
        }
        return;
    }
}

void TCPDataAdapter::handleHoldingRegisterCommand(int portIndex, int address, int value)
{
    qDebug() << "[TCPDataAdapter] 保持寄存器写入: 端口=" << portIndex
             << "地址=" << address << "值=" << value;

    // 工作模式设置 (保持寄存器0)
    if (address == HR_WORK_MODE) {
        if (value >= 0 && value <= 3) {
            if (m_systemConfig) {
                m_systemConfig->setProperty("workMode", value);
                emit commandReceived(portIndex, "SET_WORK_MODE", value);
                qDebug() << "[TCPDataAdapter] 工作模式设置:" << value;
            }
        } else {
            qWarning() << "[TCPDataAdapter] 无效工作模式值:" << value;
        }
        return;
    }

    // 本机编号设置 (保持寄存器1)
    if (address == HR_MACHINE_NUMBER) {
        if (value >= 1 && value <= 8) {
            if (m_systemConfig) {
                m_systemConfig->setProperty("machineNumber", value);
                emit commandReceived(portIndex, "SET_MACHINE_NUMBER", value);
                qDebug() << "[TCPDataAdapter] 本机编号设置:" << value;
            }
        } else {
            qWarning() << "[TCPDataAdapter] 无效本机编号:" << value;
        }
        return;
    }

    // DO控制字 (保持寄存器2-9)
    if (address >= HR_DO_CONTROL_START && address < HR_DO_CONTROL_START + 8) {
        int channel = address - HR_DO_CONTROL_START;
        bool turnOn = (value != 0);
        if (m_networkTask) {
            m_networkTask->writeDeviceControl(0, channel, turnOn);
            emit commandReceived(portIndex, turnOn ? "DO_ON" : "DO_OFF", channel);
        }
        return;
    }

    // 心跳计数器 (保持寄存器10)
    if (address == HR_HEARTBEAT) {
        // 上位机写入心跳值，本机+1回写
        if (m_modbusSlaves[portIndex]) {
            m_modbusSlaves[portIndex]->setHoldingRegister(HR_HEARTBEAT, value + 1);
        }
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: B组 — 系统配置参数 (11-19)

    // 预警时间(秒) (保持寄存器11)
    if (address == HR_WARNING_TIME) {
        int clampedVal = qBound(5, value, 300);
        if (m_systemConfig) {
            m_systemConfig->setProperty("warningTimeSeconds", clampedVal);
            emit commandReceived(portIndex, "SET_WARNING_TIME", clampedVal);
            qDebug() << "[TCPDataAdapter] 预警时间设置:" << clampedVal << "秒";
        }
        return;
    }

    // 预警播放次数 (保持寄存器12)
    if (address == HR_WARNING_PLAY_COUNT) {
        int clampedVal = qBound(1, value, 50);
        if (m_systemConfig) {
            m_systemConfig->setProperty("warningPlayCount", clampedVal);
            emit commandReceived(portIndex, "SET_WARNING_PLAY_COUNT", clampedVal);
            qDebug() << "[TCPDataAdapter] 预警播放次数设置:" << clampedVal;
        }
        return;
    }

    // 预警模式 (保持寄存器13)
    if (address == HR_WARNING_MODE) {
        if (value == 0 || value == 1) {
            if (m_systemConfig) {
                m_systemConfig->setProperty("warningMode", value);
                emit commandReceived(portIndex, "SET_WARNING_MODE", value);
                qDebug() << "[TCPDataAdapter] 预警模式设置:" << value;
            }
        }
        return;
    }

    // Modbus轮询间隔(ms) (保持寄存器14)
    if (address == HR_MODBUS_POLL_INTERVAL) {
        int clampedVal = qBound(100, value, 10000);
        if (m_systemConfig) {
            m_systemConfig->setProperty("modbusPollInterval", clampedVal);
            emit commandReceived(portIndex, "SET_MODBUS_POLL_INTERVAL", clampedVal);
            qDebug() << "[TCPDataAdapter] Modbus轮询间隔设置:" << clampedVal << "ms";
        }
        return;
    }

    // 皮带音频来源 (保持寄存器15)
    if (address == HR_BELT_AUDIO_SOURCE) {
        if (value == 0 || value == 1) {
            if (m_systemConfig) {
                m_systemConfig->setProperty("beltAudioSource", value);
                emit commandReceived(portIndex, "SET_BELT_AUDIO_SOURCE", value);
                qDebug() << "[TCPDataAdapter] 皮带音频来源设置:" << value;
            }
        }
        return;
    }

    // 默认延时(×10ms→s) (保持寄存器16)
    if (address == HR_DEFAULT_DELAY) {
        int clampedVal = qBound(5, value, 300);
        if (m_systemConfig) {
            double delaySec = clampedVal / 10.0;
            m_systemConfig->setProperty("defaultDelay", delaySec);
            emit commandReceived(portIndex, "SET_DEFAULT_DELAY", clampedVal);
            qDebug() << "[TCPDataAdapter] 默认延时设置:" << delaySec << "秒 (raw=" << clampedVal << ")";
        }
        return;
    }

    // 音频输出模式 (保持寄存器17)
    if (address == HR_AUDIO_OUTPUT_MODE) {
        if (value >= 0 && value <= 3) {
            if (m_commonControl) {
                m_commonControl->setAudioOutputMode(static_cast<CommonControl::AudioOutputMode>(value));
                emit commandReceived(portIndex, "SET_AUDIO_OUTPUT_MODE", value);
                qDebug() << "[TCPDataAdapter] 音频输出模式设置:" << value;
            }
        }
        return;
    }

    // TTS引擎选择 (保持寄存器18)
    if (address == HR_TTS_ENGINE) {
        if (value == 0 || value == 1) {
            if (m_commonControl) {
                m_commonControl->switchTTSEngine(value);
                emit commandReceived(portIndex, "SET_TTS_ENGINE", value);
                qDebug() << "[TCPDataAdapter] TTS引擎选择:" << value;
            }
        }
        return;
    }

    // TTS模型选择 (保持寄存器19)
    if (address == HR_TTS_MODEL) {
        if (value >= 0) {
            if (m_commonControl) {
                m_commonControl->switchTTSModel(value);
                emit commandReceived(portIndex, "SET_TTS_MODEL", value);
                qDebug() << "[TCPDataAdapter] TTS模型选择:" << value;
            }
        }
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: C组 — 目标皮带选择 (保持寄存器20)
    if (address == HR_TARGET_BELT) {
        if (value >= 0 && value <= 8) {
            m_paramTargetBeltNumber[portIndex] = value;
            emit commandReceived(portIndex, "SET_TARGET_BELT", value);
            qDebug() << "[TCPDataAdapter] 目标皮带编号设置:" << value << "(0=使用本机编号)";
        }
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: D组 — 参数写入确认 (保持寄存器21)
    if (address == HR_PARAM_CONFIRM) {
        handleParamConfirm(portIndex, value);
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: D组 — 参数数据区 (保持寄存器23-33)
    // 这些地址的写入不需要立即处理，数据存储在从站寄存器中
    // 等待 HR_PARAM_EXECUTE 触发时统一读取
    if (address >= HR_PARAM_DEVICE_ID && address <= HR_PARAM_LEVEL) {
        // 数据暂存在保持寄存器中，不需要额外处理
        return;
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: D组 — 执行写入 (保持寄存器34)
    if (address == HR_PARAM_EXECUTE) {
        handleParamExecute(portIndex, value);
        return;
    }
}

// ✅ 2026-04-08 [Phase 7.48.88.98]: 目标皮带编号获取（HR20覆盖本机编号）
int TCPDataAdapter::getTargetBeltNumber() const
{
    // 遍历所有端口，找到第一个非零的目标皮带编号
    // 实际上使用当前操作端口的值，但简化为使用第一个端口
    for (int i = 0; i < 8; i++) {
        if (m_paramTargetBeltNumber[i] > 0) {
            return m_paramTargetBeltNumber[i];
        }
    }
    // 默认使用本机编号
    return m_systemConfig ? m_systemConfig->property("machineNumber").toInt() : 1;
}

// ✅ 2026-04-08 [Phase 7.48.88.98]: 参数确认码处理
void TCPDataAdapter::handleParamConfirm(int portIndex, int value)
{
    if (value == 0x5A5A) {
        if (!isRemoteControlAllowed()) {
            qWarning() << "[TCPDataAdapter] 参数修改被拒绝: 当前非集控模式";
            // 设置状态为错误
            if (m_modbusSlaves[portIndex]) {
                m_modbusSlaves[portIndex]->setHoldingRegister(HR_PARAM_STATUS, 3);  // 3=错误
            }
            return;
        }
        m_paramConfirmActive[portIndex] = true;
        // 设置状态为就绪
        if (m_modbusSlaves[portIndex]) {
            m_modbusSlaves[portIndex]->setHoldingRegister(HR_PARAM_STATUS, 1);  // 1=就绪
        }
        emit commandReceived(portIndex, "PARAM_CONFIRM", 1);
        qDebug() << "[TCPDataAdapter] 参数写入确认码已接受, 端口:" << portIndex;
    } else {
        m_paramConfirmActive[portIndex] = false;
        if (m_modbusSlaves[portIndex]) {
            m_modbusSlaves[portIndex]->setHoldingRegister(HR_PARAM_STATUS, 0);  // 0=空闲
        }
    }
}

// ✅ 2026-04-08 [Phase 7.48.88.98]: 参数执行处理
void TCPDataAdapter::handleParamExecute(int portIndex, int value)
{
    if (value != 0x1234) {
        qWarning() << "[TCPDataAdapter] 无效的执行码:" << Qt::hex << value;
        return;
    }

    if (!m_paramConfirmActive[portIndex]) {
        qWarning() << "[TCPDataAdapter] 参数执行被拒绝: 未发送确认码";
        if (m_modbusSlaves[portIndex]) {
            m_modbusSlaves[portIndex]->setHoldingRegister(HR_PARAM_STATUS, 3);  // 3=错误
        }
        return;
    }

    executeParameterWrite(portIndex);

    // 清除确认状态和执行码，防止重复执行
    m_paramConfirmActive[portIndex] = false;
    if (m_modbusSlaves[portIndex]) {
        m_modbusSlaves[portIndex]->setHoldingRegister(HR_PARAM_CONFIRM, 0);
        m_modbusSlaves[portIndex]->setHoldingRegister(HR_PARAM_EXECUTE, 0);
    }
}

// ✅ 2026-04-08 [Phase 7.48.88.98]: 执行参数写入
void TCPDataAdapter::executeParameterWrite(int portIndex)
{
    if (!m_modbusSlaves[portIndex] || !m_deviceConfigMgr) {
        if (m_modbusSlaves[portIndex]) {
            m_modbusSlaves[portIndex]->setHoldingRegister(HR_PARAM_STATUS, 3);  // 3=错误
        }
        return;
    }

    auto *slave = m_modbusSlaves[portIndex];

    int deviceId = slave->getHoldingRegister(HR_PARAM_DEVICE_ID);
    int paramType = slave->getHoldingRegister(HR_PARAM_TYPE);
    int index1 = slave->getHoldingRegister(HR_PARAM_INDEX1);
    int index2 = slave->getHoldingRegister(HR_PARAM_INDEX2);
    float upperLimit = registersToFloat(slave->getHoldingRegister(HR_PARAM_UPPER_HI),
                                         slave->getHoldingRegister(HR_PARAM_UPPER_LO));
    float lowerLimit = registersToFloat(slave->getHoldingRegister(HR_PARAM_LOWER_HI),
                                         slave->getHoldingRegister(HR_PARAM_LOWER_LO));
    float range = registersToFloat(slave->getHoldingRegister(HR_PARAM_RANGE_HI),
                                    slave->getHoldingRegister(HR_PARAM_RANGE_LO));
    int level = slave->getHoldingRegister(HR_PARAM_LEVEL);

    qDebug() << "[TCPDataAdapter] 执行参数写入: deviceId=" << deviceId
             << "type=" << paramType << "index1=" << index1 << "index2=" << index2
             << "upper=" << upperLimit << "lower=" << lowerLimit
             << "range=" << range << "level=" << level;

    // 校验设备ID
    if (deviceId < 1 || deviceId > 12) {
        qWarning() << "[TCPDataAdapter] 无效设备ID:" << deviceId;
        slave->setHoldingRegister(HR_PARAM_STATUS, 3);
        return;
    }

    bool success = false;

    if (paramType == 1) {
        // 类型1: 模拟量保护参数修改
        // index1 = 保护序号（用于定位保护名称）
        QVariantMap protection;
        protection["upper_limit"] = static_cast<double>(upperLimit);
        protection["lower_limit"] = static_cast<double>(lowerLimit);
        protection["range"] = static_cast<double>(range);
        protection["level"] = level;
        // 加载已有配置，更新部分字段
        QVariantList allProtections = m_deviceConfigMgr->loadAllAnalogProtections(deviceId);
        if (index1 >= 0 && index1 < allProtections.size()) {
            QVariantMap existing = allProtections[index1].toMap();
            existing["upper_limit"] = protection["upper_limit"];
            existing["lower_limit"] = protection["lower_limit"];
            existing["range"] = protection["range"];
            existing["level"] = protection["level"];
            success = m_deviceConfigMgr->saveAnalogProtection(deviceId, existing);
        } else {
            qWarning() << "[TCPDataAdapter] 模拟量保护索引越界:" << index1;
        }
    } else if (paramType == 2) {
        // 类型2: 电机配置参数修改
        // index1 = motorIndex, index2 = tabIndex
        QVariantMap existing = m_deviceConfigMgr->loadMotorConfig(deviceId, index1, index2);
        existing["upper_limit"] = static_cast<double>(upperLimit);
        existing["lower_limit"] = static_cast<double>(lowerLimit);
        existing["range"] = static_cast<double>(range);
        existing["level"] = level;
        success = m_deviceConfigMgr->saveMotorConfig(deviceId, index1, index2, existing);
    } else {
        qWarning() << "[TCPDataAdapter] 未知参数类型:" << paramType;
    }

    // 设置执行结果状态
    slave->setHoldingRegister(HR_PARAM_STATUS, success ? 2 : 3);  // 2=成功, 3=错误
    emit commandReceived(portIndex, "PARAM_WRITE", success ? 1 : 0);
    qDebug() << "[TCPDataAdapter] 参数写入" << (success ? "成功" : "失败");
}

// ===== IEEE754浮点转换 =====

void TCPDataAdapter::floatToRegisters(float value, int &hiWord, int &loWord)
{
    quint32 raw;
    memcpy(&raw, &value, 4);
    hiWord = static_cast<int>((raw >> 16) & 0xFFFF);
    loWord = static_cast<int>(raw & 0xFFFF);
}

float TCPDataAdapter::registersToFloat(int hiWord, int loWord)
{
    quint32 raw = (static_cast<quint32>(hiWord) << 16) | (static_cast<quint32>(loWord) & 0xFFFF);
    float value;
    memcpy(&value, &raw, 4);
    return value;
}

QByteArray TCPDataAdapter::floatToBytes(float value)
{
    QByteArray bytes(4, 0);
    quint32 raw;
    memcpy(&raw, &value, 4);
    // Big-Endian: 高字节在前
    qToBigEndian(raw, reinterpret_cast<uchar*>(bytes.data()));
    return bytes;
}

// ===== 安全检查 =====

bool TCPDataAdapter::isRemoteControlAllowed() const
{
    if (!m_systemConfig) return false;
    // 只有集控模式(workMode=3)允许远程启停
    int mode = m_systemConfig->property("workMode").toInt();
    return (mode == 3);  // Centralized
}

// ✅ 2026-04-08 [Phase 7.48.88.98]: S7 DB2写入事件处理
void TCPDataAdapter::onS7DB2Written(int portIndex, int dbNumber, int offset, const QByteArray &data)
{
    Q_UNUSED(dbNumber);
    if (data.isEmpty()) return;

    qDebug() << "[TCPDataAdapter] S7 DB2写入: 端口=" << portIndex
             << "偏移=" << offset << "大小=" << data.size();

    // 根据偏移量映射到对应的Modbus命令处理
    for (int i = 0; i < data.size(); i++) {
        int byteOffset = offset + i;
        quint8 byteVal = static_cast<quint8>(data.at(i));

        switch (byteOffset) {
        case 0:  // DO输出控制(bit0-7)
            for (int bit = 0; bit < 8; bit++) {
                if (byteVal & (1 << bit)) {
                    handleCoilCommand(portIndex, COIL_DO_START + bit, true);
                }
            }
            break;

        case 1:  // 皮带控制(bit0=启动, bit1=停止, bit2=急停)
            if (byteVal & 0x01) handleCoilCommand(portIndex, COIL_START_BELT, true);
            if (byteVal & 0x02) handleCoilCommand(portIndex, COIL_STOP_BELT, true);
            if (byteVal & 0x04) handleCoilCommand(portIndex, COIL_EMERGENCY_STOP, true);
            break;

        case 2:  // 工作模式切换
            handleHoldingRegisterCommand(portIndex, HR_WORK_MODE, byteVal);
            break;

        case 3:  // 命令序列号（忽略）
            break;

        case 4:  // 心跳高字节
        case 5:  // 心跳低字节（需要两个字节一起处理）
            if (byteOffset == 4 && data.size() > i + 1) {
                int heartbeat = (byteVal << 8) | static_cast<quint8>(data.at(i + 1));
                handleHoldingRegisterCommand(portIndex, HR_HEARTBEAT, heartbeat);
            }
            break;

        case 6:  // 电机启动(bit0-7=电机1-8)
            for (int bit = 0; bit < 8; bit++) {
                if (byteVal & (1 << bit)) {
                    handleCoilCommand(portIndex, COIL_MOTOR_START_START + bit, true);
                }
            }
            break;

        case 7:  // 电机停止(bit0-7=电机1-8)
            for (int bit = 0; bit < 8; bit++) {
                if (byteVal & (1 << bit)) {
                    handleCoilCommand(portIndex, COIL_MOTOR_STOP_START + bit, true);
                }
            }
            break;

        case 8:  // 洒水启动(bit0-7=洒水1-8)
            for (int bit = 0; bit < 8; bit++) {
                if (byteVal & (1 << bit)) {
                    handleCoilCommand(portIndex, COIL_SPRINKLER_START_START + bit, true);
                }
            }
            break;

        case 9:  // 洒水停止(bit0-7=洒水1-8)
            for (int bit = 0; bit < 8; bit++) {
                if (byteVal & (1 << bit)) {
                    handleCoilCommand(portIndex, COIL_SPRINKLER_STOP_START + bit, true);
                }
            }
            break;

        case 10:  // 复位命令(bit0=全部保护, bit1=速度报警, bit2=故障, bit3=启动序列, bit4=停止序列)
            if (byteVal & 0x01) handleCoilCommand(portIndex, COIL_RESET_ALL_PROTECTION, true);
            if (byteVal & 0x02) handleCoilCommand(portIndex, COIL_RESET_SPEED_ALARM, true);
            if (byteVal & 0x04) handleCoilCommand(portIndex, COIL_RESET_FAULT, true);
            if (byteVal & 0x08) handleCoilCommand(portIndex, COIL_START_SEQUENCE, true);
            if (byteVal & 0x10) handleCoilCommand(portIndex, COIL_STOP_SEQUENCE, true);
            break;

        case 11:  // 目标皮带编号
            handleHoldingRegisterCommand(portIndex, HR_TARGET_BELT, byteVal);
            break;

        case 12:  // 预警时间高字节
            if (data.size() > i + 1) {
                int val = (byteVal << 8) | static_cast<quint8>(data.at(i + 1));
                handleHoldingRegisterCommand(portIndex, HR_WARNING_TIME, val);
            }
            break;

        case 14:  // 预警次数
            handleHoldingRegisterCommand(portIndex, HR_WARNING_PLAY_COUNT, byteVal);
            break;

        case 15:  // 预警模式
            handleHoldingRegisterCommand(portIndex, HR_WARNING_MODE, byteVal);
            break;

        case 16:  // 轮询间隔高字节
            if (data.size() > i + 1) {
                int val = (byteVal << 8) | static_cast<quint8>(data.at(i + 1));
                handleHoldingRegisterCommand(portIndex, HR_MODBUS_POLL_INTERVAL, val);
            }
            break;

        case 18:  // 音频来源
            handleHoldingRegisterCommand(portIndex, HR_BELT_AUDIO_SOURCE, byteVal);
            break;

        case 19:  // TTS引擎
            handleHoldingRegisterCommand(portIndex, HR_TTS_ENGINE, byteVal);
            break;

        case 20:  // TTS模型
            handleHoldingRegisterCommand(portIndex, HR_TTS_MODEL, byteVal);
            break;

        default:
            break;
        }
    }
}

// ===== QML映射表查询 =====

QVariantList TCPDataAdapter::getDiscreteInputMap(int portIndex) const
{
    QVariantList map;

    // ✅ 2026-04-08 [Phase 7.48.88.90]: 添加当前值读取
    auto addEntry = [&](int addr, const QString &name, const QString &source) {
        QVariantMap entry;
        entry["address"] = QString("1%1").arg(addr + 1, 4, 10, QChar('0'));
        entry["internalAddr"] = addr;
        entry["name"] = name;
        entry["source"] = source;
        entry["type"] = "BOOL";
        // 读取当前寄存器值
        if (portIndex >= 0 && portIndex < 8 && m_modbusSlaves[portIndex]) {
            entry["value"] = m_modbusSlaves[portIndex]->getDiscreteInput(addr);
        } else {
            entry["value"] = "--";
        }
        map.append(entry);
    };

    // DO输出状态
    for (int i = 0; i < 8; i++) {
        addEntry(DI_DO_STATES_START + i,
                 QString("继电器%1状态").arg(i + 1),
                 QString("DODataManager.doStates[%1]").arg(i));
    }
    // DI反馈
    for (int i = 0; i < 8; i++) {
        addEntry(DI_DI_FEEDBACK_START + i,
                 QString("反馈%1状态").arg(i + 1),
                 QString("DODataManager.diFeedback[%1]").arg(i));
    }
    // 急停
    addEntry(DI_ESTOP, "急停状态", "DODataManager.estop");
    // DI模块
    for (int i = 0; i < 8; i++) {
        addEntry(DI_DI_MODULE1_START + i,
                 QString("DI模块1-%1").arg(i + 1),
                 QString("DIDataManager.module1[%1]").arg(i));
    }
    for (int i = 0; i < 8; i++) {
        addEntry(DI_DI_MODULE2_START + i,
                 QString("DI模块2-%1").arg(i + 1),
                 QString("DIDataManager.module2[%1]").arg(i));
    }
    // 电机状态
    for (int i = 0; i < 8; i++) {
        addEntry(DI_MOTOR_STATUS_START + i,
                 QString("电机%1运行").arg(i + 1),
                 "CommonControl");
    }
    // 制动器
    for (int i = 0; i < 8; i++) {
        addEntry(DI_BRAKE_STATUS_START + i,
                 QString("制动器%1").arg(i + 1),
                 "CommonControl");
    }
    // 张紧
    for (int i = 0; i < 2; i++) {
        addEntry(DI_TENSION_STATUS_START + i,
                 QString("张紧%1").arg(i + 1),
                 "CommonControl");
    }
    // 洒水
    for (int i = 0; i < 8; i++) {
        addEntry(DI_SPRINKLER_STATUS_START + i,
                 QString("洒水%1").arg(i + 1),
                 "CommonControl");
    }
    // 保护状态
    QStringList protNames = {"急停", "跑偏", "撕裂", "烟雾", "温度", "护网", "堆煤", "主急停"};
    for (int i = 0; i < 8; i++) {
        addEntry(DI_PROTECTION_START + i,
                 protNames[i] + "保护",
                 "SystemConfig");
    }
    // 沿线保护
    for (int i = 0; i < 64; i++) {
        addEntry(DI_CS_ESTOP_START + i,
                 QString("沿线急停%1").arg(i + 1),
                 QString("CSDataManager[0].point%1").arg(i));
    }
    for (int i = 0; i < 64; i++) {
        addEntry(DI_CS_DEVIATION_START + i,
                 QString("沿线跑偏%1").arg(i + 1),
                 QString("CSDataManager[1].point%1").arg(i));
    }
    for (int i = 0; i < 64; i++) {
        addEntry(DI_CS_TEAR_START + i,
                 QString("沿线撕裂%1").arg(i + 1),
                 QString("CSDataManager[2].point%1").arg(i));
    }

    return map;
}

QVariantList TCPDataAdapter::getInputRegisterMap(int portIndex) const
{
    QVariantList map;

    // ✅ 2026-04-08 [Phase 7.48.88.90]: 添加当前值读取
    // ✅ 2026-04-09 [Phase 7.48.88.102]: 修复FLOAT32显示——合并两个寄存器还原浮点数
    auto addEntry = [&](int addr, const QString &name, const QString &source, const QString &type) {
        QVariantMap entry;
        entry["address"] = QString("3%1").arg(addr + 1, 4, 10, QChar('0'));
        entry["internalAddr"] = addr;
        entry["name"] = name;
        entry["source"] = source;
        entry["type"] = type;
        // 读取当前寄存器值
        if (portIndex >= 0 && portIndex < 8 && m_modbusSlaves[portIndex]) {
            if (type == "FLOAT32") {
                // 旧: entry["value"] = m_modbusSlaves[portIndex]->getInputRegister(addr);
                // 2026-04-09: FLOAT32占两个连续寄存器，需合并为IEEE754浮点数
                int hi = m_modbusSlaves[portIndex]->getInputRegister(addr);
                int lo = m_modbusSlaves[portIndex]->getInputRegister(addr + 1);
                float val = registersToFloat(hi, lo);
                entry["value"] = QString::number(val, 'f', 2);
            } else {
                entry["value"] = m_modbusSlaves[portIndex]->getInputRegister(addr);
            }
        } else {
            entry["value"] = "--";
        }
        map.append(entry);
    };

    // AI模块
    for (int i = 0; i < 8; i++) {
        addEntry(IR_AI_MODULE3_START + i,
                 QString("AI模块1通道%1").arg(i + 1),
                 QString("AIDataManager.module3[%1]").arg(i), "UINT16");
    }
    for (int i = 0; i < 8; i++) {
        addEntry(IR_AI_MODULE4_START + i,
                 QString("AI模块2通道%1").arg(i + 1),
                 QString("AIDataManager.module4[%1]").arg(i), "UINT16");
    }

    addEntry(IR_MACHINE_NUMBER, "本机编号", "SystemConfig.machineNumber", "UINT16");
    addEntry(IR_WORK_MODE, "工作模式", "SystemConfig.workMode", "UINT16");

    // 浮点参数
    struct FloatParam { int addr; QString name; QString source; };
    QList<FloatParam> floats = {
        {IR_SPEED_START, "皮带速度", "speedValue"},
        {IR_TENSION_START, "张力值", "tensionValue"},
        {IR_MOTOR1_CURRENT_START, "电机1电流", "motor1CurrentValue"},
        {IR_MOTOR2_CURRENT_START, "电机2电流", "motor2CurrentValue"},
        {IR_MOTOR1_VOLTAGE_START, "电机1电压", "motor1VoltageValue"},
        {IR_MOTOR2_VOLTAGE_START, "电机2电压", "motor2VoltageValue"},
        {IR_MOTOR1_XVIB_START, "电机1 X振动", "motor1XVibrationValue"},
        {IR_MOTOR1_YVIB_START, "电机1 Y振动", "motor1YVibrationValue"},
        {IR_MOTOR2_XVIB_START, "电机2 X振动", "motor2XVibrationValue"},
        {IR_MOTOR2_YVIB_START, "电机2 Y振动", "motor2YVibrationValue"},
        {IR_MOTOR1_TEMP_START, "电机1温度", "motor1TemperatureValue"},
        {IR_MOTOR2_TEMP_START, "电机2温度", "motor2TemperatureValue"},
    };
    for (const auto &fp : floats) {
        addEntry(fp.addr, fp.name, "SystemConfig." + fp.source, "FLOAT32");
    }

    // 绕组
    QStringList windingNames = {"电机1绕组A", "电机1绕组B", "电机1绕组C",
                                "电机2绕组A", "电机2绕组B", "电机2绕组C"};
    QStringList windingSources = {"motor1PhaseAWindingValue", "motor1PhaseBWindingValue", "motor1PhaseCWindingValue",
                                  "motor2PhaseAWindingValue", "motor2PhaseBWindingValue", "motor2PhaseCWindingValue"};
    for (int i = 0; i < 6; i++) {
        int baseAddr = (i < 3) ? IR_MOTOR1_WINDING_START + i * 2 : IR_MOTOR2_WINDING_START + (i - 3) * 2;
        addEntry(baseAddr, windingNames[i], "SystemConfig." + windingSources[i], "FLOAT32");
    }

    // 打包寄存器
    addEntry(IR_DO_PACKED, "DO状态打包", "DODataManager(packed)", "UINT16");
    addEntry(IR_DIFB_PACKED, "DI反馈打包", "DODataManager(packed)", "UINT16");
    addEntry(IR_DI_MOD1_PACKED, "DI模块1打包", "DIDataManager(packed)", "UINT16");
    addEntry(IR_DI_MOD2_PACKED, "DI模块2打包", "DIDataManager(packed)", "UINT16");
    addEntry(IR_MOTOR_PACKED, "电机状态打包", "CommonControl(packed)", "UINT16");
    addEntry(IR_BRAKE_PACKED, "制动器打包", "CommonControl(packed)", "UINT16");
    addEntry(IR_SPRINKLER_TENSION_PACKED, "洒水+张紧打包", "CommonControl(packed)", "UINT16");
    addEntry(IR_PROTECTION_PACKED, "保护状态打包", "SystemConfig(packed)", "UINT16");

    // ✅ 2026-04-08 [Phase 7.48.88.97]: 环境模拟量
    QList<FloatParam> envFloats = {
        {IR_TEMPERATURE1_START, "温度一", "temperature1Value"},
        {IR_TEMPERATURE2_START, "温度二", "temperature2Value"},
        {IR_TEMPERATURE_ENV_START, "温度（环境）", "temperatureValue"},
        {IR_HUMIDITY_START, "湿度", "humidityValue"},
        {IR_METHANE_START, "甲烷", "methaneValue"},
        {IR_DUST_START, "粉尘浓度", "dustValue"},
        {IR_COALFLOW_START, "煤流", "coalFlowValue"},
        {IR_SILOHEIGHT_START, "煤仓高度", "siloHeightValue"},
        {IR_VOLTAGE_ENV_START, "电压（环境）", "voltageValue"},
        {IR_SMOKE_START, "烟雾", "smokeValue"},
        {IR_PRESSURE_START, "气压", "pressureValue"},
        {IR_OXYGEN_START, "氧气", "oxygenValue"},
        {IR_CO_START, "一氧化碳", "coValue"},
        {IR_H2S_START, "硫化氢", "h2sValue"},
        {IR_CO2_START, "二氧化碳", "co2Value"},
        {IR_WINDSPEED_START, "风速", "windSpeedValue"},
    };
    for (const auto &fp : envFloats) {
        addEntry(fp.addr, fp.name, "SystemConfig." + fp.source, "FLOAT32");
    }

    // ✅ 2026-04-08 [Phase 7.48.88.97]: 电机1-2 扩展Tab
    QList<FloatParam> motor12Ext = {
        {IR_MOTOR1_FRONT_BEARING_START, "电机1前轴承温度", "motorProtectionValue(0,2)"},
        {IR_MOTOR1_REAR_BEARING_START,  "电机1后轴承温度", "motorProtectionValue(0,3)"},
        {IR_MOTOR1_STALL_START,         "电机1堵转", "motorProtectionValue(0,10)"},
        {IR_MOTOR1_START_TIMEOUT_START,  "电机1起动超时", "motorProtectionValue(0,11)"},
        {IR_MOTOR1_POWER_START,          "电机1功率", "motorProtectionValue(0,12)"},
        {IR_MOTOR1_IMBALANCE_START,      "电机1三相不平衡", "motorProtectionValue(0,13)"},
        {IR_MOTOR2_FRONT_BEARING_START, "电机2前轴承温度", "motorProtectionValue(1,2)"},
        {IR_MOTOR2_REAR_BEARING_START,  "电机2后轴承温度", "motorProtectionValue(1,3)"},
        {IR_MOTOR2_STALL_START,         "电机2堵转", "motorProtectionValue(1,10)"},
        {IR_MOTOR2_START_TIMEOUT_START,  "电机2起动超时", "motorProtectionValue(1,11)"},
        {IR_MOTOR2_POWER_START,          "电机2功率", "motorProtectionValue(1,12)"},
        {IR_MOTOR2_IMBALANCE_START,      "电机2三相不平衡", "motorProtectionValue(1,13)"},
    };
    for (const auto &fp : motor12Ext) {
        addEntry(fp.addr, fp.name, "SystemConfig." + fp.source, "FLOAT32");
    }

    // ✅ 2026-04-08 [Phase 7.48.88.97]: 电机3-8 完整数据块
    QStringList tabNames = {"", "电流", "前轴承温度", "后轴承温度",
                            "甲相绕组", "乙相绕组", "丙相绕组",
                            "电机温度", "水平振动", "垂直振动",
                            "堵转", "起动超时", "功率", "三相不平衡"};
    for (int m = 2; m < 8; m++) {
        int base = IR_MOTOR_BLOCK_START + (m - 2) * IR_MOTOR_BLOCK_SIZE;
        for (int t = 1; t < 14; t++) {
            int addr = base + (t - 1) * 2;
            addEntry(addr,
                     QString("电机%1%2").arg(m + 1).arg(tabNames[t]),
                     QString("SystemConfig.motorProtectionValue(%1,%2)").arg(m).arg(t),
                     "FLOAT32");
        }
    }

    return map;
}

QVariantList TCPDataAdapter::getCoilMap(int portIndex) const
{
    // 旧：Q_UNUSED(portIndex);  // 2026-04-08 [Phase 7.48.88.90] 需要portIndex读取当前值
    QVariantList map;

    auto addEntry = [&](int addr, const QString &name, const QString &target) {
        QVariantMap entry;
        entry["address"] = QString("0%1").arg(addr + 1, 4, 10, QChar('0'));
        entry["internalAddr"] = addr;
        entry["name"] = name;
        entry["target"] = target;
        entry["type"] = "BOOL";
        // ✅ 2026-04-08 [Phase 7.48.88.90]: 添加当前寄存器值
        if (portIndex >= 0 && portIndex < 8 && m_modbusSlaves[portIndex]) {
            entry["value"] = m_modbusSlaves[portIndex]->getCoil(addr);
        } else {
            entry["value"] = "--";
        }
        map.append(entry);
    };

    for (int i = 0; i < 8; i++) {
        addEntry(COIL_DO_START + i,
                 QString("DO输出控制%1").arg(i + 1),
                 "NetworkTask");
    }
    addEntry(COIL_START_BELT, "启动皮带", "CommonControl.startBelt");
    addEntry(COIL_STOP_BELT, "停止皮带", "CommonControl.stopBelt");
    addEntry(COIL_EMERGENCY_STOP, "紧急停车", "CommonControl.emergencyStop");

    // ✅ 2026-04-08 [Phase 7.48.88.98]: B组 — 电机独立控制
    for (int i = 0; i < 8; i++) {
        addEntry(COIL_MOTOR_START_START + i,
                 QString("电机%1启动").arg(i + 1),
                 "MqttProtectionMonitor.publishMotorCommand");
    }
    for (int i = 0; i < 8; i++) {
        addEntry(COIL_MOTOR_STOP_START + i,
                 QString("电机%1停止").arg(i + 1),
                 "MqttProtectionMonitor.publishMotorCommand");
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: C组 — 洒水控制
    for (int i = 0; i < 8; i++) {
        addEntry(COIL_SPRINKLER_START_START + i,
                 QString("洒水%1启动").arg(i + 1),
                 "MqttProtectionMonitor.publishSprinklerCommand");
    }
    for (int i = 0; i < 8; i++) {
        addEntry(COIL_SPRINKLER_STOP_START + i,
                 QString("洒水%1停止").arg(i + 1),
                 "MqttProtectionMonitor.publishSprinklerCommand");
    }

    // ✅ 2026-04-08 [Phase 7.48.88.98]: D组 — 保护/系统复位+序列
    addEntry(COIL_RESET_ALL_PROTECTION, "复位全部保护", "ProtectionLogicController.resetAllProtections");
    addEntry(COIL_RESET_SPEED_ALARM, "复位速度保护报警", "MqttProtectionMonitor.resetSpeedProtectionAlarm");
    addEntry(COIL_RESET_FAULT, "复位故障状态", "DeviceRuntimeTracker.resetFault");
    addEntry(COIL_START_SEQUENCE, "启动设备序列", "CommonControl.startDeviceSequence");
    addEntry(COIL_STOP_SEQUENCE, "停止设备序列", "CommonControl.stopDeviceSequence");

    return map;
}

QVariantList TCPDataAdapter::getHoldingRegisterMap(int portIndex) const
{
    // 旧：Q_UNUSED(portIndex);  // 2026-04-08 [Phase 7.48.88.90] 需要portIndex读取当前值
    QVariantList map;

    auto addEntry = [&](int addr, const QString &name, const QString &desc, const QString &type) {
        QVariantMap entry;
        entry["address"] = QString("4%1").arg(addr + 1, 4, 10, QChar('0'));
        entry["internalAddr"] = addr;
        entry["name"] = name;
        entry["description"] = desc;
        entry["type"] = type;
        // ✅ 2026-04-08 [Phase 7.48.88.90]: 添加当前寄存器值
        if (portIndex >= 0 && portIndex < 8 && m_modbusSlaves[portIndex]) {
            entry["value"] = m_modbusSlaves[portIndex]->getHoldingRegister(addr);
        } else {
            entry["value"] = "--";
        }
        map.append(entry);
    };

    addEntry(HR_WORK_MODE, "工作模式设置", "0检修/1就地/2点动/3集控", "UINT16");
    addEntry(HR_MACHINE_NUMBER, "本机编号设置", "1-8", "UINT16");
    for (int i = 0; i < 8; i++) {
        addEntry(HR_DO_CONTROL_START + i,
                 QString("DO控制字%1").arg(i + 1),
                 "与线圈联动", "UINT16");
    }
    addEntry(HR_HEARTBEAT, "心跳计数器", "上位机写入，本机+1回写", "UINT16");

    // ✅ 2026-04-08 [Phase 7.48.88.98]: B组 — 系统配置参数
    addEntry(HR_WARNING_TIME, "预警时间(秒)", "5-300", "UINT16");
    addEntry(HR_WARNING_PLAY_COUNT, "预警播放次数", "1-50", "UINT16");
    addEntry(HR_WARNING_MODE, "预警模式", "0按次/1按时长", "UINT16");
    addEntry(HR_MODBUS_POLL_INTERVAL, "Modbus轮询间隔(ms)", "100-10000", "UINT16");
    addEntry(HR_BELT_AUDIO_SOURCE, "皮带音频来源", "0本地/1远程", "UINT16");
    addEntry(HR_DEFAULT_DELAY, "默认延时(×0.1s)", "5-300", "UINT16");
    addEntry(HR_AUDIO_OUTPUT_MODE, "音频输出模式", "0-3", "UINT16");
    addEntry(HR_TTS_ENGINE, "TTS引擎选择", "0/1", "UINT16");
    addEntry(HR_TTS_MODEL, "TTS模型选择", "0-N", "UINT16");

    // ✅ 2026-04-08 [Phase 7.48.88.98]: C组 — 目标皮带选择
    addEntry(HR_TARGET_BELT, "目标皮带编号", "0=本机,1-8=指定", "UINT16");

    // ✅ 2026-04-08 [Phase 7.48.88.98]: D组 — 保护参数修改块
    addEntry(HR_PARAM_CONFIRM, "参数写入确认", "写0x5A5A解锁", "UINT16");
    addEntry(HR_PARAM_STATUS, "参数写入状态", "只读:0空闲/1就绪/2成功/3错误", "UINT16");
    addEntry(HR_PARAM_DEVICE_ID, "目标设备ID", "1-12", "UINT16");
    addEntry(HR_PARAM_TYPE, "参数类型", "1=模拟量/2=电机", "UINT16");
    addEntry(HR_PARAM_INDEX1, "参数索引1", "类型1:保护序号/类型2:motorIndex", "UINT16");
    addEntry(HR_PARAM_INDEX2, "参数索引2", "类型2:tabIndex", "UINT16");
    addEntry(HR_PARAM_UPPER_HI, "上限值(高16位)", "FLOAT32 HiWord", "UINT16");
    addEntry(HR_PARAM_UPPER_LO, "上限值(低16位)", "FLOAT32 LoWord", "UINT16");
    addEntry(HR_PARAM_LOWER_HI, "下限值(高16位)", "FLOAT32 HiWord", "UINT16");
    addEntry(HR_PARAM_LOWER_LO, "下限值(低16位)", "FLOAT32 LoWord", "UINT16");
    addEntry(HR_PARAM_RANGE_HI, "量程(高16位)", "FLOAT32 HiWord", "UINT16");
    addEntry(HR_PARAM_RANGE_LO, "量程(低16位)", "FLOAT32 LoWord", "UINT16");
    addEntry(HR_PARAM_LEVEL, "保护等级", "0-3", "UINT16");
    addEntry(HR_PARAM_EXECUTE, "执行写入", "写0x1234执行", "UINT16");

    return map;
}

QVariantList TCPDataAdapter::getS7DB1Map(int portIndex) const
{
    // 旧：Q_UNUSED(portIndex);  // 2026-04-08 [Phase 7.48.88.90] 需要portIndex读取当前值
    QVariantList map;

    // ✅ 2026-04-09: 读取DB1完整数据块（扩展到640字节）
    QByteArray dbData;
    bool hasData = false;
    if (portIndex >= 0 && portIndex < 8 && m_s7Servers[portIndex]) {
        // 旧值: dbData = m_s7Servers[portIndex]->getDBData(1, 0, 140);  // 2026-04-09 扩展到S7_DB1_SIZE
        dbData = m_s7Servers[portIndex]->getDBData(1, 0, S7_DB1_SIZE);
        hasData = !dbData.isEmpty();
    }

    auto addEntry = [&](int offset, int length, const QString &name, const QString &type) {
        QVariantMap entry;
        entry["offset"] = offset;
        entry["length"] = length;
        entry["name"] = name;
        entry["type"] = type;
        // ✅ 2026-04-08 [Phase 7.48.88.90]: 添加当前值
        if (hasData && offset < dbData.size()) {
            if (type == "BYTE" && length == 1) {
                entry["value"] = static_cast<quint8>(dbData.at(offset));
            } else if (type == "WORD" && length == 2 && offset + 1 < dbData.size()) {
                quint16 val = (static_cast<quint8>(dbData.at(offset)) << 8) | static_cast<quint8>(dbData.at(offset + 1));
                entry["value"] = val;
            } else if (type == "REAL" && length == 4 && offset + 3 < dbData.size()) {
                // ✅ 2026-04-10 [Phase 7.48.88.102]: 修复Big-Endian字节序转换
                // 旧: 直接memcpy 4字节（在x86 Little-Endian上值错误）
                // 新: S7 DB1数据以Big-Endian存储，需用qFromBigEndian还原
                quint32 raw = (static_cast<quint8>(dbData.at(offset))     << 24) |
                              (static_cast<quint8>(dbData.at(offset + 1)) << 16) |
                              (static_cast<quint8>(dbData.at(offset + 2)) << 8)  |
                              (static_cast<quint8>(dbData.at(offset + 3)));
                float val;
                memcpy(&val, &raw, 4);
                entry["value"] = QString::number(val, 'f', 2);
            } else {
                entry["value"] = "--";
            }
        } else {
            entry["value"] = "--";
        }
        map.append(entry);
    };

    // ===== 基本数据区 (Byte 0-139) =====
    addEntry(0, 1, "DO输出状态", "BYTE");
    addEntry(1, 1, "DI反馈状态", "BYTE");
    addEntry(2, 1, "DI模块1", "BYTE");
    addEntry(3, 1, "DI模块2", "BYTE");
    addEntry(4, 1, "急停状态", "BYTE");
    addEntry(5, 1, "电机运行状态", "BYTE");
    addEntry(6, 1, "制动器状态", "BYTE");
    addEntry(7, 1, "洒水状态", "BYTE");
    addEntry(8, 1, "张紧状态", "BYTE");
    addEntry(9, 1, "保护状态汇总", "BYTE");
    addEntry(10, 2, "工作模式+本机编号", "WORD");
    addEntry(12, 32, "AI 16通道AD值", "16×WORD");
    addEntry(44, 4, "皮带速度", "REAL");
    addEntry(48, 4, "张力值", "REAL");
    addEntry(52, 4, "电机1电流", "REAL");
    addEntry(56, 4, "电机2电流", "REAL");
    addEntry(60, 4, "电机1电压", "REAL");
    addEntry(64, 4, "电机2电压", "REAL");
    addEntry(68, 4, "电机1 X振动", "REAL");
    addEntry(72, 4, "电机1 Y振动", "REAL");
    addEntry(76, 4, "电机2 X振动", "REAL");
    addEntry(80, 4, "电机2 Y振动", "REAL");
    addEntry(84, 4, "电机1温度", "REAL");
    addEntry(88, 4, "电机2温度", "REAL");
    addEntry(92, 24, "电机1/2绕组ABC", "6×REAL");
    addEntry(116, 8, "沿线急停64点", "64×BOOL");
    addEntry(124, 8, "沿线跑偏64点", "64×BOOL");
    addEntry(132, 8, "沿线撕裂64点", "64×BOOL");

    // ===== ✅ 2026-04-09: 扩展数据区 =====

    // 环境模拟量 (Byte 140-203)
    addEntry(140, 4, "温度一", "REAL");
    addEntry(144, 4, "温度二", "REAL");
    addEntry(148, 4, "温度（环境）", "REAL");
    addEntry(152, 4, "湿度", "REAL");
    addEntry(156, 4, "甲烷", "REAL");
    addEntry(160, 4, "粉尘浓度", "REAL");
    addEntry(164, 4, "煤流", "REAL");
    addEntry(168, 4, "煤仓高度", "REAL");
    addEntry(172, 4, "电压（环境）", "REAL");
    addEntry(176, 4, "烟雾", "REAL");
    addEntry(180, 4, "气压", "REAL");
    addEntry(184, 4, "氧气", "REAL");
    addEntry(188, 4, "一氧化碳", "REAL");
    addEntry(192, 4, "硫化氢", "REAL");
    addEntry(196, 4, "二氧化碳", "REAL");
    addEntry(200, 4, "风速", "REAL");

    // 电机1扩展 (Byte 204-227)
    addEntry(204, 4, "电机1前轴承温度", "REAL");
    addEntry(208, 4, "电机1后轴承温度", "REAL");
    addEntry(212, 4, "电机1堵转", "REAL");
    addEntry(216, 4, "电机1起动超时", "REAL");
    addEntry(220, 4, "电机1功率", "REAL");
    addEntry(224, 4, "电机1三相不平衡", "REAL");

    // 电机2扩展 (Byte 228-251)
    addEntry(228, 4, "电机2前轴承温度", "REAL");
    addEntry(232, 4, "电机2后轴承温度", "REAL");
    addEntry(236, 4, "电机2堵转", "REAL");
    addEntry(240, 4, "电机2起动超时", "REAL");
    addEntry(244, 4, "电机2功率", "REAL");
    addEntry(248, 4, "电机2三相不平衡", "REAL");

    // 电机3-8完整数据块 (Byte 252-587)
    QStringList tabNames = {"电流", "前轴承", "后轴承", "甲相", "乙相", "丙相",
                            "温度", "水平振动", "垂直振动", "堵转", "起动超时", "功率", "不平衡"};
    for (int m = 3; m <= 8; m++) {
        int base = S7_DB1_MOTOR_BLOCK_START + (m - 3) * S7_DB1_MOTOR_BLOCK_SIZE;
        for (int t = 0; t < 13; t++) {
            addEntry(base + t * 4, 4, QString("电机%1%2").arg(m).arg(tabNames[t]), "REAL");
        }
        addEntry(base + 52, 4, QString("电机%1电压").arg(m), "REAL");
    }

    return map;
}

QVariantList TCPDataAdapter::getS7DB2Map(int portIndex) const
{
    // 旧：Q_UNUSED(portIndex);  // 2026-04-08 [Phase 7.48.88.90] 需要portIndex读取当前值
    QVariantList map;

    // ✅ 2026-04-08 [Phase 7.48.88.90]: 读取DB2完整数据块用于获取当前值
    QByteArray dbData;
    bool hasData = false;
    if (portIndex >= 0 && portIndex < 8 && m_s7Servers[portIndex]) {
        dbData = m_s7Servers[portIndex]->getDBData(2, 0, S7_DB2_SIZE);
        hasData = !dbData.isEmpty();
    }

    auto addEntry = [&](int offset, int length, const QString &name, const QString &type) {
        QVariantMap entry;
        entry["offset"] = offset;
        entry["length"] = length;
        entry["name"] = name;
        entry["type"] = type;
        // ✅ 2026-04-08 [Phase 7.48.88.90]: 添加当前值
        if (hasData && offset < dbData.size()) {
            if (length == 1) {
                entry["value"] = static_cast<quint8>(dbData.at(offset));
            } else if (length == 2 && offset + 1 < dbData.size()) {
                quint16 val = (static_cast<quint8>(dbData.at(offset)) << 8) | static_cast<quint8>(dbData.at(offset + 1));
                entry["value"] = val;
            } else {
                entry["value"] = "--";
            }
        } else {
            entry["value"] = "--";
        }
        map.append(entry);
    };

    addEntry(0, 1, "DO输出控制字", "BYTE");
    addEntry(1, 1, "启动/停止/急停", "BOOL×3");
    addEntry(2, 1, "工作模式切换", "BYTE");
    addEntry(3, 1, "命令序列号", "BYTE");
    addEntry(4, 2, "心跳计数器", "WORD");
    // ✅ 2026-04-08 [Phase 7.48.88.98]: S7 DB2控制区扩展
    addEntry(6, 1, "电机启动(bit0-7)", "BYTE");
    addEntry(7, 1, "电机停止(bit0-7)", "BYTE");
    addEntry(8, 1, "洒水启动(bit0-7)", "BYTE");
    addEntry(9, 1, "洒水停止(bit0-7)", "BYTE");
    addEntry(10, 1, "复位命令(bit0-4)", "BYTE");
    addEntry(11, 1, "目标皮带编号", "BYTE");
    addEntry(12, 2, "预警时间", "WORD");
    addEntry(14, 1, "预警次数", "BYTE");
    addEntry(15, 1, "预警模式", "BYTE");
    addEntry(16, 2, "轮询间隔", "WORD");
    addEntry(18, 1, "音频来源", "BYTE");
    addEntry(19, 1, "TTS引擎", "BYTE");
    addEntry(20, 1, "TTS模型", "BYTE");
    addEntry(21, 43, "预留/参数块", "BYTES");

    return map;
}
