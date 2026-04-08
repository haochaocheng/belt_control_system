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
        if (m_s7Servers[i] && m_s7Servers[i]->property("isConnected").toBool()) {
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

    // 2) 再启动服务器
    if (m_modbusSlaves[portIndex]) {
        if (!m_modbusSlaves[portIndex]->startServer()) {
            qWarning() << "[TCPDataAdapter] 端口" << portIndex << "Modbus从站启动失败";
            success = false;
        } else {
            qDebug() << "[TCPDataAdapter] 端口" << portIndex << "Modbus从站已启动";
        }
    }

    if (m_s7Servers[portIndex]) {
        if (!m_s7Servers[portIndex]->startServer()) {
            qWarning() << "[TCPDataAdapter] 端口" << portIndex << "S7服务器启动失败";
            success = false;
        } else {
            qDebug() << "[TCPDataAdapter] 端口" << portIndex << "S7服务器已启动";
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

    if (m_s7Servers[portIndex]) {
        m_s7Servers[portIndex]->stopServer();
        qDebug() << "[TCPDataAdapter] 端口" << portIndex << "S7服务器已停止";
    }
}

bool TCPDataAdapter::isPortRunning(int portIndex) const
{
    if (portIndex < 0 || portIndex >= 8) return false;

    // 检查Modbus从站是否连接
    if (m_modbusSlaves[portIndex]) {
        if (m_modbusSlaves[portIndex]->property("isConnected").toBool()) {
            return true;
        }
    }

    // 检查S7服务器是否连接
    if (m_s7Servers[portIndex]) {
        if (m_s7Servers[portIndex]->property("isConnected").toBool()) {
            return true;
        }
    }

    return false;
}

void TCPDataAdapter::autoStart()
{
    qDebug() << "[TCPDataAdapter] 自动启动 - 初始化端口0并启用同步";
    startPortServices(0);
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

    // 构建DB1数据缓冲区 (140 bytes实际使用, 256 bytes分配)
    QByteArray db1(S7_DB1_SIZE, 0);

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

    // Byte 44-115: 浮点参数 (REAL, Big-Endian)
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

    // 一次性写入整个DB1
    server->setDBData(S7_DB1_NUMBER, 0, db1);
}

// ===== 线圈写入事件处理 =====

void TCPDataAdapter::onCoilWritten(int portIndex, int address, bool value)
{
    // 上升沿检测：只在从0→1时触发命令
    if (address >= 0 && address < 32) {
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
            int machineNumber = m_systemConfig ? m_systemConfig->property("machineNumber").toInt() : 1;
            m_commonControl->startBelt(machineNumber);
            emit commandReceived(portIndex, "START_BELT", machineNumber);
            qDebug() << "[TCPDataAdapter] 远程启动皮带:" << machineNumber;
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
            int machineNumber = m_systemConfig ? m_systemConfig->property("machineNumber").toInt() : 1;
            m_commonControl->stopBelt(machineNumber);
            emit commandReceived(portIndex, "STOP_BELT", machineNumber);
            qDebug() << "[TCPDataAdapter] 远程停止皮带:" << machineNumber;
        }
        return;
    }

    // 紧急停车 (线圈10)
    if (address == COIL_EMERGENCY_STOP) {
        // 紧急停车不受工作模式限制
        if (m_commonControl) {
            int machineNumber = m_systemConfig ? m_systemConfig->property("machineNumber").toInt() : 1;
            m_commonControl->emergencyStopBelt(machineNumber);
            emit commandReceived(portIndex, "EMERGENCY_STOP", machineNumber);
            qWarning() << "[TCPDataAdapter] ⚠ 远程紧急停车:" << machineNumber;
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
    auto addEntry = [&](int addr, const QString &name, const QString &source, const QString &type) {
        QVariantMap entry;
        entry["address"] = QString("3%1").arg(addr + 1, 4, 10, QChar('0'));
        entry["internalAddr"] = addr;
        entry["name"] = name;
        entry["source"] = source;
        entry["type"] = type;
        // 读取当前寄存器值
        if (portIndex >= 0 && portIndex < 8 && m_modbusSlaves[portIndex]) {
            entry["value"] = m_modbusSlaves[portIndex]->getInputRegister(addr);
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

    return map;
}

QVariantList TCPDataAdapter::getS7DB1Map(int portIndex) const
{
    // 旧：Q_UNUSED(portIndex);  // 2026-04-08 [Phase 7.48.88.90] 需要portIndex读取当前值
    QVariantList map;

    // ✅ 2026-04-08 [Phase 7.48.88.90]: 读取DB1完整数据块用于获取当前值
    QByteArray dbData;
    bool hasData = false;
    if (portIndex >= 0 && portIndex < 8 && m_s7Servers[portIndex]) {
        dbData = m_s7Servers[portIndex]->getDBData(1, 0, 140);
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
                float val;
                quint8 bytes[4] = {
                    static_cast<quint8>(dbData.at(offset)),
                    static_cast<quint8>(dbData.at(offset + 1)),
                    static_cast<quint8>(dbData.at(offset + 2)),
                    static_cast<quint8>(dbData.at(offset + 3))
                };
                memcpy(&val, bytes, 4);
                entry["value"] = QString::number(val, 'f', 2);
            } else {
                entry["value"] = "--";
            }
        } else {
            entry["value"] = "--";
        }
        map.append(entry);
    };

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
        dbData = m_s7Servers[portIndex]->getDBData(2, 0, 6);
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

    return map;
}
