#ifndef TCPDATAADAPTER_H
#define TCPDATAADAPTER_H

// ✅ 2026-04-07 [Phase 7.48.88.83]: 新建TCP数据适配层
// 职责：
// 1. 持有所有数据管理器指针
// 2. 定时从数据管理器采集数据 → 刷新到Modbus从站寄存器 / S7数据块
// 3. 监听上位机写入事件 → 转发为控制命令
// 4. 提供Q_INVOKABLE供QML查看映射表和实时数据

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class DODataManager;
class DIDataManager;
class AIDataManager;
class CSDataManager;
class SystemConfig;
class CommonControl;
class NetworkTask;
class ModbusTCPSlaveController;
class S7ServerController;

class TCPDataAdapter : public QObject
{
    Q_OBJECT

    // ===== 配置属性 =====
    Q_PROPERTY(int syncInterval READ syncInterval WRITE setSyncInterval NOTIFY syncIntervalChanged)
    Q_PROPERTY(bool syncEnabled READ syncEnabled WRITE setSyncEnabled NOTIFY syncEnabledChanged)
    Q_PROPERTY(int activePorts READ activePorts NOTIFY activePortsChanged)

public:
    explicit TCPDataAdapter(QObject *parent = nullptr);
    ~TCPDataAdapter();

    // ===== 数据管理器设置 =====
    void setDODataManager(DODataManager *mgr);
    void setDIDataManager(DIDataManager *mgr);
    void setAIDataManager(AIDataManager *mgr);
    void setCSDataManager(CSDataManager *mgr);
    void setSystemConfig(SystemConfig *config);
    void setCommonControl(CommonControl *ctrl);
    void setNetworkTask(NetworkTask *task);

    // ===== TCP控制器绑定（8端口，每端口4个控制器） =====
    // portIndex: 0-7
    void bindModbusSlave(int portIndex, ModbusTCPSlaveController *slave);
    void bindS7Server(int portIndex, S7ServerController *server);

    // ===== 属性访问 =====
    int syncInterval() const { return m_syncInterval; }
    void setSyncInterval(int ms);
    bool syncEnabled() const { return m_syncEnabled; }
    void setSyncEnabled(bool enabled);
    int activePorts() const;

    // ===== QML可调用方法 =====

    // 获取Modbus寄存器映射表（供QML展示）
    // 返回: [{address, name, source, type, value}, ...]
    Q_INVOKABLE QVariantList getDiscreteInputMap(int portIndex) const;
    Q_INVOKABLE QVariantList getInputRegisterMap(int portIndex) const;
    Q_INVOKABLE QVariantList getCoilMap(int portIndex) const;
    Q_INVOKABLE QVariantList getHoldingRegisterMap(int portIndex) const;

    // 获取S7数据块映射表
    Q_INVOKABLE QVariantList getS7DB1Map(int portIndex) const;
    Q_INVOKABLE QVariantList getS7DB2Map(int portIndex) const;

    // 手动触发一次同步
    Q_INVOKABLE void syncNow();

    // 初始化指定端口的从站寄存器空间
    Q_INVOKABLE void initializePort(int portIndex);

    // ✅ 2026-04-07 [Phase 7.48.88.86]: 启动/停止端口服务
    Q_INVOKABLE bool startPortServices(int portIndex);
    Q_INVOKABLE void stopPortServices(int portIndex);
    Q_INVOKABLE bool isPortRunning(int portIndex) const;

    // ✅ 2026-04-07 [Phase 7.48.88.86]: 自动启动（初始化端口0 + 启动同步）
    Q_INVOKABLE void autoStart();

signals:
    void syncIntervalChanged();
    void syncEnabledChanged();
    void activePortsChanged();
    void syncCompleted(int portIndex);
    void commandReceived(int portIndex, const QString &command, const QVariant &value);
    void errorOccurred(const QString &message);

private slots:
    void onSyncTimer();

    // Modbus从站写入事件处理
    void onCoilWritten(int portIndex, int address, bool value);
    void onHoldingRegisterWritten(int portIndex, int address, int value);

private:
    // ===== 同步方法（从数据管理器 → 从站寄存器） =====
    void syncDiscreteInputs(int portIndex);     // 离散输入区
    void syncInputRegisters(int portIndex);      // 输入寄存器区
    void syncS7DB1(int portIndex);               // S7 DB1状态区

    // ===== 命令处理方法（上位机写入 → 本机控制） =====
    void handleCoilCommand(int portIndex, int address, bool value);
    void handleHoldingRegisterCommand(int portIndex, int address, int value);

    // ===== IEEE754浮点转换 =====
    // float → 2个16位寄存器 (HiWord在前, Big-Endian)
    static void floatToRegisters(float value, int &hiWord, int &loWord);
    // 2个16位寄存器 → float
    static float registersToFloat(int hiWord, int loWord);

    // float → 4字节QByteArray (Big-Endian)
    static QByteArray floatToBytes(float value);

    // ===== 安全检查 =====
    bool isRemoteControlAllowed() const;

    // ===== 成员变量 =====
    // 数据管理器指针
    DODataManager *m_doDataManager = nullptr;
    DIDataManager *m_diDataManager = nullptr;
    AIDataManager *m_aiDataManager = nullptr;
    CSDataManager *m_csDataManager = nullptr;
    SystemConfig *m_systemConfig = nullptr;
    CommonControl *m_commonControl = nullptr;
    NetworkTask *m_networkTask = nullptr;

    // TCP控制器数组（8端口）
    ModbusTCPSlaveController *m_modbusSlaves[8] = {};
    S7ServerController *m_s7Servers[8] = {};

    // 同步定时器
    QTimer *m_syncTimer = nullptr;
    int m_syncInterval = 100;   // 默认100ms
    bool m_syncEnabled = false;

    // 线圈上升沿检测（防止重复触发）
    bool m_lastCoilStates[8][32] = {};  // [portIndex][coilAddress]

    // ===== Modbus地址常量 =====
    // 离散输入区 (10001+)
    static constexpr int DI_DO_STATES_START = 0;        // DO输出状态 0-7
    static constexpr int DI_DI_FEEDBACK_START = 8;       // DI反馈 8-15
    static constexpr int DI_ESTOP = 16;                  // 急停 16
    static constexpr int DI_DI_MODULE1_START = 17;       // DI模块1 17-24
    static constexpr int DI_DI_MODULE2_START = 25;       // DI模块2 25-32
    static constexpr int DI_MOTOR_STATUS_START = 33;     // 电机状态 33-40
    static constexpr int DI_BRAKE_STATUS_START = 41;     // 制动器状态 41-48
    static constexpr int DI_TENSION_STATUS_START = 49;   // 张紧状态 49-50
    static constexpr int DI_SPRINKLER_STATUS_START = 51; // 洒水状态 51-58
    static constexpr int DI_PROTECTION_START = 59;       // 保护状态 59-66
    static constexpr int DI_CS_ESTOP_START = 100;        // 沿线急停 100-163
    static constexpr int DI_CS_DEVIATION_START = 200;    // 沿线跑偏 200-263
    static constexpr int DI_CS_TEAR_START = 300;         // 沿线撕裂 300-363
    static constexpr int DI_TOTAL_COUNT = 400;           // 离散输入总数

    // 输入寄存器区 (30001+)
    static constexpr int IR_AI_MODULE3_START = 0;        // AI模块1 0-7
    static constexpr int IR_AI_MODULE4_START = 8;        // AI模块2 8-15
    static constexpr int IR_MACHINE_NUMBER = 16;         // 本机编号 16
    static constexpr int IR_WORK_MODE = 17;              // 工作模式 17
    static constexpr int IR_SPEED_START = 18;            // 皮带速度 18-19 (FLOAT32)
    static constexpr int IR_TENSION_START = 20;          // 张力值 20-21
    static constexpr int IR_MOTOR1_CURRENT_START = 22;   // 电机1电流 22-23
    static constexpr int IR_MOTOR2_CURRENT_START = 24;   // 电机2电流 24-25
    static constexpr int IR_MOTOR1_VOLTAGE_START = 26;   // 电机1电压 26-27
    static constexpr int IR_MOTOR2_VOLTAGE_START = 28;   // 电机2电压 28-29
    static constexpr int IR_MOTOR1_XVIB_START = 30;      // 电机1 X振动 30-31
    static constexpr int IR_MOTOR1_YVIB_START = 32;      // 电机1 Y振动 32-33
    static constexpr int IR_MOTOR2_XVIB_START = 34;      // 电机2 X振动 34-35
    static constexpr int IR_MOTOR2_YVIB_START = 36;      // 电机2 Y振动 36-37
    static constexpr int IR_MOTOR1_TEMP_START = 38;      // 电机1温度 38-39
    static constexpr int IR_MOTOR2_TEMP_START = 40;      // 电机2温度 40-41
    static constexpr int IR_MOTOR1_WINDING_START = 42;   // 电机1绕组ABC 42-47
    static constexpr int IR_MOTOR2_WINDING_START = 48;   // 电机2绕组ABC 48-53
    static constexpr int IR_DO_PACKED = 54;              // DO状态打包 54
    static constexpr int IR_DIFB_PACKED = 55;            // DI反馈打包 55
    static constexpr int IR_DI_MOD1_PACKED = 56;         // DI模块1打包 56
    static constexpr int IR_DI_MOD2_PACKED = 57;         // DI模块2打包 57
    static constexpr int IR_MOTOR_PACKED = 58;           // 电机状态打包 58
    static constexpr int IR_BRAKE_PACKED = 59;           // 制动器打包 59
    static constexpr int IR_SPRINKLER_TENSION_PACKED = 60; // 洒水+张紧打包 60
    static constexpr int IR_PROTECTION_PACKED = 61;      // 保护状态打包 61

    // ✅ 2026-04-08 [Phase 7.48.88.97]: 环境模拟量扩展 62-93（16个FLOAT32 × 2寄存器）
    static constexpr int IR_TEMPERATURE1_START = 62;     // 温度一 62-63
    static constexpr int IR_TEMPERATURE2_START = 64;     // 温度二 64-65
    static constexpr int IR_TEMPERATURE_ENV_START = 66;  // 温度（环境）66-67
    static constexpr int IR_HUMIDITY_START = 68;         // 湿度 68-69
    static constexpr int IR_METHANE_START = 70;          // 甲烷 70-71
    static constexpr int IR_DUST_START = 72;             // 粉尘浓度 72-73
    static constexpr int IR_COALFLOW_START = 74;         // 煤流 74-75
    static constexpr int IR_SILOHEIGHT_START = 76;       // 煤仓高度 76-77
    static constexpr int IR_VOLTAGE_ENV_START = 78;      // 电压（环境）78-79
    static constexpr int IR_SMOKE_START = 80;            // 烟雾 80-81
    static constexpr int IR_PRESSURE_START = 82;         // 气压 82-83
    static constexpr int IR_OXYGEN_START = 84;           // 氧气 84-85
    static constexpr int IR_CO_START = 86;               // 一氧化碳 86-87
    static constexpr int IR_H2S_START = 88;              // 硫化氢 88-89
    static constexpr int IR_CO2_START = 90;              // 二氧化碳 90-91
    static constexpr int IR_WINDSPEED_START = 92;        // 风速 92-93

    // ✅ 2026-04-08 [Phase 7.48.88.97]: 电机1-2 扩展Tab值 94-117
    static constexpr int IR_MOTOR1_FRONT_BEARING_START = 94;  // 电机1前轴承温度 94-95
    static constexpr int IR_MOTOR1_REAR_BEARING_START = 96;   // 电机1后轴承温度 96-97
    static constexpr int IR_MOTOR1_STALL_START = 98;          // 电机1堵转 98-99
    static constexpr int IR_MOTOR1_START_TIMEOUT_START = 100; // 电机1起动超时 100-101
    static constexpr int IR_MOTOR1_POWER_START = 102;         // 电机1功率 102-103
    static constexpr int IR_MOTOR1_IMBALANCE_START = 104;     // 电机1三相不平衡 104-105
    static constexpr int IR_MOTOR2_FRONT_BEARING_START = 106; // 电机2前轴承温度 106-107
    static constexpr int IR_MOTOR2_REAR_BEARING_START = 108;  // 电机2后轴承温度 108-109
    static constexpr int IR_MOTOR2_STALL_START = 110;         // 电机2堵转 110-111
    static constexpr int IR_MOTOR2_START_TIMEOUT_START = 112; // 电机2起动超时 112-113
    static constexpr int IR_MOTOR2_POWER_START = 114;         // 电机2功率 114-115
    static constexpr int IR_MOTOR2_IMBALANCE_START = 116;     // 电机2三相不平衡 116-117

    // ✅ 2026-04-08 [Phase 7.48.88.97]: 电机3-8 完整数据块 120-287
    // 每个电机28个寄存器（13个Tab值 + 1个电压 = 14个FLOAT32 × 2寄存器）
    // 电机N(motorIndex 2-7)基地址: IR_MOTOR_BLOCK_START + (motorIndex - 2) * IR_MOTOR_BLOCK_SIZE
    // 块内偏移: (tabIndex - 1) * 2（tab 1起，tab 0无值）
    //   0-1=电流(tab1), 2-3=前轴承(tab2), 4-5=后轴承(tab3),
    //   6-7=甲相(tab4), 8-9=乙相(tab5), 10-11=丙相(tab6),
    //   12-13=电机温度(tab7), 14-15=水平振动(tab8), 16-17=垂直振动(tab9),
    //   18-19=堵转(tab10), 20-21=起动超时(tab11), 22-23=功率(tab12), 24-25=不平衡(tab13)
    //   26-27=电压（独立）
    static constexpr int IR_MOTOR_BLOCK_START = 120;
    static constexpr int IR_MOTOR_BLOCK_SIZE = 28;       // 每电机28寄存器
    // 旧值: static constexpr int IR_TOTAL_COUNT = 100;
    static constexpr int IR_TOTAL_COUNT = 300;           // 输入寄存器总数（扩展后）

    // 线圈区 (00001+)
    static constexpr int COIL_DO_START = 0;              // DO控制 0-7
    static constexpr int COIL_START_BELT = 8;            // 启动皮带 8
    static constexpr int COIL_STOP_BELT = 9;             // 停止皮带 9
    static constexpr int COIL_EMERGENCY_STOP = 10;       // 紧急停车 10
    static constexpr int COIL_TOTAL_COUNT = 32;          // 线圈总数

    // 保持寄存器区 (40001+)
    static constexpr int HR_WORK_MODE = 0;               // 工作模式 0
    static constexpr int HR_MACHINE_NUMBER = 1;          // 本机编号 1
    static constexpr int HR_DO_CONTROL_START = 2;        // DO控制字 2-9
    static constexpr int HR_HEARTBEAT = 10;              // 心跳计数器 10
    static constexpr int HR_TOTAL_COUNT = 32;            // 保持寄存器总数

    // S7数据块常量
    static constexpr int S7_DB1_NUMBER = 1;              // DB1 状态区
    static constexpr int S7_DB2_NUMBER = 2;              // DB2 控制区
    static constexpr int S7_DB1_SIZE = 256;              // DB1 分配256字节
    static constexpr int S7_DB2_SIZE = 64;               // DB2 分配64字节
};

#endif // TCPDATAADAPTER_H
