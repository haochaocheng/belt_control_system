#ifndef SYSTEMCONFIG_H
#define SYSTEMCONFIG_H

#include <QObject>
#include <QSettings>
#include <QVariantList>

/**
 * @brief 系统配置管理类 - 管理所有系统参数的保存和加载
 *
 * 功能：
 * - 本机编号配置
 * - 起车预警时间/次数配置
 * - 播放模式配置（按时间/按次数）
 * - 参数持久化保存到配置文件
 */
class SystemConfig : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int machineNumber READ machineNumber WRITE setMachineNumber NOTIFY machineNumberChanged)
    Q_PROPERTY(int warningTimeSeconds READ warningTimeSeconds WRITE setWarningTimeSeconds NOTIFY warningTimeSecondsChanged)
    Q_PROPERTY(int warningPlayCount READ warningPlayCount WRITE setWarningPlayCount NOTIFY warningPlayCountChanged)
    Q_PROPERTY(WarningMode warningMode READ warningMode WRITE setWarningMode NOTIFY warningModeChanged)
    Q_PROPERTY(QStringList startupSequence READ startupSequence WRITE setStartupSequence NOTIFY startupSequenceChanged)
    Q_PROPERTY(QStringList stopSequence READ stopSequence WRITE setStopSequence NOTIFY stopSequenceChanged)
    // ✅ 2026-03-20 [Phase 7.48.57]: 逻辑控制-每个设备的延时时间（秒），与序列一一对应
    Q_PROPERTY(QVariantList startupDelays READ startupDelays WRITE setStartupDelays NOTIFY startupDelaysChanged)
    Q_PROPERTY(QVariantList stopDelays READ stopDelays WRITE setStopDelays NOTIFY stopDelaysChanged)
    Q_PROPERTY(double defaultDelay READ defaultDelay WRITE setDefaultDelay NOTIFY defaultDelayChanged)
    Q_PROPERTY(QString modbusServerIp READ modbusServerIp WRITE setModbusServerIp NOTIFY modbusServerIpChanged)
    Q_PROPERTY(QString modbusGateway READ modbusGateway WRITE setModbusGateway NOTIFY modbusGatewayChanged)
    Q_PROPERTY(QString modbusSubnetMask READ modbusSubnetMask WRITE setModbusSubnetMask NOTIFY modbusSubnetMaskChanged)
    Q_PROPERTY(int modbusPollInterval READ modbusPollInterval WRITE setModbusPollInterval NOTIFY modbusPollIntervalChanged)
    Q_PROPERTY(WorkMode workMode READ workMode WRITE setWorkMode NOTIFY workModeChanged)
    Q_PROPERTY(QString localDeviceName READ localDeviceName WRITE setLocalDeviceName NOTIFY localDeviceNameChanged)
    // ✅ 2026-03-20 [Phase 7.48.60]: 皮带起/停车音频来源 0=默认(/app/AUDIO/) 1=TTS合成(audioBaseDir/engineFolder/)
    Q_PROPERTY(int beltAudioSource READ beltAudioSource WRITE setBeltAudioSource NOTIFY beltAudioSourceChanged)

    // 开关量保护状态
    Q_PROPERTY(bool emergencyStopActive READ emergencyStopActive NOTIFY emergencyStopActiveChanged)
    Q_PROPERTY(bool runOffActive READ runOffActive NOTIFY runOffActiveChanged)
    Q_PROPERTY(bool tearActive READ tearActive NOTIFY tearActiveChanged)
    Q_PROPERTY(bool smokeActive READ smokeActive NOTIFY smokeActiveChanged)
    Q_PROPERTY(bool temperatureActive READ temperatureActive NOTIFY temperatureActiveChanged)
    Q_PROPERTY(bool guardNetActive READ guardNetActive NOTIFY guardNetActiveChanged)
    Q_PROPERTY(bool coalPileActive READ coalPileActive NOTIFY coalPileActiveChanged)
    Q_PROPERTY(bool mainEmergencyStopActive READ mainEmergencyStopActive NOTIFY mainEmergencyStopActiveChanged)

    // ========== 模拟量保护值 ==========
    // ✅ 2026-04-08 [Phase 7.48.88.96]: 为所有模拟量保护值添加WRITE setter
    // ✅ 2026-04-08 [Phase 7.48.88.97]: 扩展为完整模拟量体系（环境+8电机）

    // --- 皮带/环境模拟量（来自 device_analog_protections，共17项）---
    Q_PROPERTY(double speedValue READ speedValue WRITE setSpeedValue NOTIFY speedValueChanged)
    Q_PROPERTY(double tensionValue READ tensionValue WRITE setTensionValue NOTIFY tensionValueChanged)
    Q_PROPERTY(double temperature1Value READ temperature1Value WRITE setTemperature1Value NOTIFY temperature1ValueChanged)
    Q_PROPERTY(double temperature2Value READ temperature2Value WRITE setTemperature2Value NOTIFY temperature2ValueChanged)
    Q_PROPERTY(double temperatureValue READ temperatureValue WRITE setTemperatureValue NOTIFY temperatureValueChanged)
    Q_PROPERTY(double humidityValue READ humidityValue WRITE setHumidityValue NOTIFY humidityValueChanged)
    Q_PROPERTY(double methaneValue READ methaneValue WRITE setMethaneValue NOTIFY methaneValueChanged)
    Q_PROPERTY(double dustValue READ dustValue WRITE setDustValue NOTIFY dustValueChanged)
    Q_PROPERTY(double coalFlowValue READ coalFlowValue WRITE setCoalFlowValue NOTIFY coalFlowValueChanged)
    Q_PROPERTY(double siloHeightValue READ siloHeightValue WRITE setSiloHeightValue NOTIFY siloHeightValueChanged)
    Q_PROPERTY(double voltageValue READ voltageValue WRITE setVoltageValue NOTIFY voltageValueChanged)
    Q_PROPERTY(double smokeValue READ smokeValue WRITE setSmokeValue NOTIFY smokeValueChanged)
    Q_PROPERTY(double pressureValue READ pressureValue WRITE setPressureValue NOTIFY pressureValueChanged)
    Q_PROPERTY(double oxygenValue READ oxygenValue WRITE setOxygenValue NOTIFY oxygenValueChanged)
    Q_PROPERTY(double coValue READ coValue WRITE setCoValue NOTIFY coValueChanged)
    Q_PROPERTY(double h2sValue READ h2sValue WRITE setH2sValue NOTIFY h2sValueChanged)
    Q_PROPERTY(double co2Value READ co2Value WRITE setCo2Value NOTIFY co2ValueChanged)
    Q_PROPERTY(double windSpeedValue READ windSpeedValue WRITE setWindSpeedValue NOTIFY windSpeedValueChanged)

    // --- 电机保护值（兼容旧属性：motor1/2，实际存储在 m_motorValues[8][14] 数组中）---
    // 旧：Q_PROPERTY(double motor1CurrentValue ...) 等18个独立属性  // 2026-04-08 [Phase 7.48.88.97] 改为数组后端
    Q_PROPERTY(double motor1CurrentValue READ motor1CurrentValue WRITE setMotor1CurrentValue NOTIFY motor1CurrentValueChanged)
    Q_PROPERTY(double motor2CurrentValue READ motor2CurrentValue WRITE setMotor2CurrentValue NOTIFY motor2CurrentValueChanged)
    Q_PROPERTY(double motor1VoltageValue READ motor1VoltageValue WRITE setMotor1VoltageValue NOTIFY motor1VoltageValueChanged)
    Q_PROPERTY(double motor2VoltageValue READ motor2VoltageValue WRITE setMotor2VoltageValue NOTIFY motor2VoltageValueChanged)
    Q_PROPERTY(double motor1XVibrationValue READ motor1XVibrationValue WRITE setMotor1XVibrationValue NOTIFY motor1XVibrationValueChanged)
    Q_PROPERTY(double motor1YVibrationValue READ motor1YVibrationValue WRITE setMotor1YVibrationValue NOTIFY motor1YVibrationValueChanged)
    Q_PROPERTY(double motor2XVibrationValue READ motor2XVibrationValue WRITE setMotor2XVibrationValue NOTIFY motor2XVibrationValueChanged)
    Q_PROPERTY(double motor2YVibrationValue READ motor2YVibrationValue WRITE setMotor2YVibrationValue NOTIFY motor2YVibrationValueChanged)
    Q_PROPERTY(double motor1TemperatureValue READ motor1TemperatureValue WRITE setMotor1TemperatureValue NOTIFY motor1TemperatureValueChanged)
    Q_PROPERTY(double motor2TemperatureValue READ motor2TemperatureValue WRITE setMotor2TemperatureValue NOTIFY motor2TemperatureValueChanged)
    Q_PROPERTY(double motor1PhaseAWindingValue READ motor1PhaseAWindingValue WRITE setMotor1PhaseAWindingValue NOTIFY motor1PhaseAWindingValueChanged)
    Q_PROPERTY(double motor1PhaseBWindingValue READ motor1PhaseBWindingValue WRITE setMotor1PhaseBWindingValue NOTIFY motor1PhaseBWindingValueChanged)
    Q_PROPERTY(double motor1PhaseCWindingValue READ motor1PhaseCWindingValue WRITE setMotor1PhaseCWindingValue NOTIFY motor1PhaseCWindingValueChanged)
    Q_PROPERTY(double motor2PhaseAWindingValue READ motor2PhaseAWindingValue WRITE setMotor2PhaseAWindingValue NOTIFY motor2PhaseAWindingValueChanged)
    Q_PROPERTY(double motor2PhaseBWindingValue READ motor2PhaseBWindingValue WRITE setMotor2PhaseBWindingValue NOTIFY motor2PhaseBWindingValueChanged)
    Q_PROPERTY(double motor2PhaseCWindingValue READ motor2PhaseCWindingValue WRITE setMotor2PhaseCWindingValue NOTIFY motor2PhaseCWindingValueChanged)

public:
    enum WarningMode {
        ByTime = 0,  // 按时间播放
        ByCount = 1  // 按次数播放
    };
    Q_ENUM(WarningMode)

    enum WorkMode {
        Maintenance = 0,  // 检修模式 - 无连锁
        Local = 1,        // 就地模式 - 有连锁
        Jog = 2,          // 点动模式（待实现）
        Centralized = 3   // 集控模式（待实现）
    };
    Q_ENUM(WorkMode)

    // ✅ 2026-04-08 [Phase 7.48.88.97]: 电机保护Tab索引常量
    // 与 DeviceConfigManager.cpp initDefaultMotorConfigs() 的 tabDefaults 一一对应
    static constexpr int MOTOR_TAB_COUNT = 14;       // 每电机14个Tab（0-13）
    static constexpr int MOTOR_COUNT = 8;            // 8个电机（0-7）
    // Tab索引定义
    static constexpr int TAB_BASIC       = 0;   // 基本配置（无保护值）
    static constexpr int TAB_CURRENT     = 1;   // 电流保护
    static constexpr int TAB_FRONT_BEARING = 2; // 前轴承温度
    static constexpr int TAB_REAR_BEARING = 3;  // 后轴承温度
    static constexpr int TAB_WINDING_A   = 4;   // 甲相绕组
    static constexpr int TAB_WINDING_B   = 5;   // 乙相绕组
    static constexpr int TAB_WINDING_C   = 6;   // 丙相绕组
    static constexpr int TAB_MOTOR_TEMP  = 7;   // 电机温度
    static constexpr int TAB_X_VIBRATION = 8;   // 水平振动
    static constexpr int TAB_Y_VIBRATION = 9;   // 垂直振动
    static constexpr int TAB_STALL       = 10;  // 堵转保护
    static constexpr int TAB_START_TIMEOUT = 11; // 起动超时
    static constexpr int TAB_POWER       = 12;  // 功率保护
    static constexpr int TAB_IMBALANCE   = 13;  // 三相不平衡

    explicit SystemConfig(QObject *parent = nullptr);
    ~SystemConfig();

    // Getters
    int machineNumber() const { return m_machineNumber; }
    int warningTimeSeconds() const { return m_warningTimeSeconds; }
    int warningPlayCount() const { return m_warningPlayCount; }
    WarningMode warningMode() const { return m_warningMode; }
    QStringList startupSequence() const { return m_startupSequence; }
    QStringList stopSequence() const { return m_stopSequence; }
    // ✅ 2026-03-20 [Phase 7.48.57]: 逻辑控制延时 Getters
    QVariantList startupDelays() const { return m_startupDelays; }
    QVariantList stopDelays() const { return m_stopDelays; }
    double defaultDelay() const { return m_defaultDelay; }
    QString modbusServerIp() const { return m_modbusServerIp; }
    QString modbusGateway() const { return m_modbusGateway; }
    QString modbusSubnetMask() const { return m_modbusSubnetMask; }
    int modbusPollInterval() const { return m_modbusPollInterval; }
    WorkMode workMode() const { return m_workMode; }
    QString localDeviceName() const { return m_localDeviceName; }
    // ✅ 2026-03-20 [Phase 7.48.60]: 皮带音频来源 Getter
    int beltAudioSource() const { return m_beltAudioSource; }

    // 开关量保护状态 Getters
    bool emergencyStopActive() const { return m_emergencyStopActive; }
    bool runOffActive() const { return m_runOffActive; }
    bool tearActive() const { return m_tearActive; }
    bool smokeActive() const { return m_smokeActive; }
    bool temperatureActive() const { return m_temperatureActive; }
    bool guardNetActive() const { return m_guardNetActive; }
    bool coalPileActive() const { return m_coalPileActive; }
    bool mainEmergencyStopActive() const { return m_mainEmergencyStopActive; }

    // ========== 环境模拟量 Getters ==========
    double speedValue() const { return m_speedValue; }
    double tensionValue() const { return m_tensionValue; }
    double temperature1Value() const { return m_temperature1Value; }
    double temperature2Value() const { return m_temperature2Value; }
    double temperatureValue() const { return m_temperatureValue_env; }
    double humidityValue() const { return m_humidityValue; }
    double methaneValue() const { return m_methaneValue; }
    double dustValue() const { return m_dustValue; }
    double coalFlowValue() const { return m_coalFlowValue; }
    double siloHeightValue() const { return m_siloHeightValue; }
    double voltageValue() const { return m_voltageValue; }
    double smokeValue() const { return m_smokeValue_env; }
    double pressureValue() const { return m_pressureValue; }
    double oxygenValue() const { return m_oxygenValue; }
    double coValue() const { return m_coValue; }
    double h2sValue() const { return m_h2sValue; }
    double co2Value() const { return m_co2Value; }
    double windSpeedValue() const { return m_windSpeedValue; }

    // ========== 电机保护值 Getters（兼容旧属性，实际从数组读取）==========
    // 旧：double motor1CurrentValue() const { return m_motor1CurrentValue; }  // 2026-04-08 [Phase 7.48.88.97] 改为数组
    double motor1CurrentValue() const { return m_motorValues[0][TAB_CURRENT]; }
    double motor2CurrentValue() const { return m_motorValues[1][TAB_CURRENT]; }
    double motor1VoltageValue() const { return m_motor1VoltageValue; }
    double motor2VoltageValue() const { return m_motor2VoltageValue; }
    double motor1XVibrationValue() const { return m_motorValues[0][TAB_X_VIBRATION]; }
    double motor1YVibrationValue() const { return m_motorValues[0][TAB_Y_VIBRATION]; }
    double motor2XVibrationValue() const { return m_motorValues[1][TAB_X_VIBRATION]; }
    double motor2YVibrationValue() const { return m_motorValues[1][TAB_Y_VIBRATION]; }
    double motor1TemperatureValue() const { return m_motorValues[0][TAB_MOTOR_TEMP]; }
    double motor2TemperatureValue() const { return m_motorValues[1][TAB_MOTOR_TEMP]; }
    double motor1PhaseAWindingValue() const { return m_motorValues[0][TAB_WINDING_A]; }
    double motor1PhaseBWindingValue() const { return m_motorValues[0][TAB_WINDING_B]; }
    double motor1PhaseCWindingValue() const { return m_motorValues[0][TAB_WINDING_C]; }
    double motor2PhaseAWindingValue() const { return m_motorValues[1][TAB_WINDING_A]; }
    double motor2PhaseBWindingValue() const { return m_motorValues[1][TAB_WINDING_B]; }
    double motor2PhaseCWindingValue() const { return m_motorValues[1][TAB_WINDING_C]; }

    // ✅ 2026-04-08 [Phase 7.48.88.97]: 通用电机保护值访问（8电机×14Tab）
    // QML调用示例: systemConfig.motorProtectionValue(2, 1) 获取3号电机电流
    Q_INVOKABLE double motorProtectionValue(int motorIndex, int tabIndex) const;
    Q_INVOKABLE void setMotorProtectionValue(int motorIndex, int tabIndex, double value);

    // Setters
    void setMachineNumber(int number);
    void setWarningTimeSeconds(int seconds);
    void setWarningPlayCount(int count);
    void setWarningMode(WarningMode mode);
    void setStartupSequence(const QStringList &sequence);
    void setStopSequence(const QStringList &sequence);
    // ✅ 2026-03-20 [Phase 7.48.57]: 逻辑控制延时 Setters
    void setStartupDelays(const QVariantList &delays);
    void setStopDelays(const QVariantList &delays);
    void setDefaultDelay(double delay);
    void setModbusServerIp(const QString &ip);
    void setModbusGateway(const QString &gateway);
    void setModbusSubnetMask(const QString &subnetMask);
    void setModbusPollInterval(int interval);
    void setWorkMode(WorkMode mode);
    void setLocalDeviceName(const QString &name);
    // ✅ 2026-03-20 [Phase 7.48.60]: 皮带音频来源 Setter
    void setBeltAudioSource(int source);

    // ========== 环境模拟量 Setters ==========
    void setSpeedValue(double value);
    void setTensionValue(double value);
    void setTemperature1Value(double value);
    void setTemperature2Value(double value);
    void setTemperatureValue(double value);
    void setHumidityValue(double value);
    void setMethaneValue(double value);
    void setDustValue(double value);
    void setCoalFlowValue(double value);
    void setSiloHeightValue(double value);
    void setVoltageValue(double value);
    void setSmokeValue(double value);
    void setPressureValue(double value);
    void setOxygenValue(double value);
    void setCoValue(double value);
    void setH2sValue(double value);
    void setCo2Value(double value);
    void setWindSpeedValue(double value);

    // ========== 电机保护值 Setters（兼容旧属性，实际写入数组）==========
    void setMotor1CurrentValue(double value);
    void setMotor2CurrentValue(double value);
    void setMotor1VoltageValue(double value);
    void setMotor2VoltageValue(double value);
    void setMotor1XVibrationValue(double value);
    void setMotor1YVibrationValue(double value);
    void setMotor2XVibrationValue(double value);
    void setMotor2YVibrationValue(double value);
    void setMotor1TemperatureValue(double value);
    void setMotor2TemperatureValue(double value);
    void setMotor1PhaseAWindingValue(double value);
    void setMotor1PhaseBWindingValue(double value);
    void setMotor1PhaseCWindingValue(double value);
    void setMotor2PhaseAWindingValue(double value);
    void setMotor2PhaseBWindingValue(double value);
    void setMotor2PhaseCWindingValue(double value);

public slots:
    // 保存所有配置
    void saveConfig();

    // 加载所有配置
    void loadConfig();

    // 重置为默认值
    void resetToDefaults();

signals:
    void machineNumberChanged();
    void warningTimeSecondsChanged();
    void warningPlayCountChanged();
    void warningModeChanged();
    void startupSequenceChanged();
    void stopSequenceChanged();
    // ✅ 2026-03-20 [Phase 7.48.57]: 逻辑控制延时信号
    void startupDelaysChanged();
    void stopDelaysChanged();
    void defaultDelayChanged();
    void modbusServerIpChanged();
    void modbusGatewayChanged();
    void modbusSubnetMaskChanged();
    void modbusPollIntervalChanged();
    void workModeChanged();
    void localDeviceNameChanged();
    // ✅ 2026-03-20 [Phase 7.48.60]: 皮带音频来源信号
    void beltAudioSourceChanged();
    void configSaved();
    void configLoaded();

    // 开关量保护状态信号
    void emergencyStopActiveChanged();
    void runOffActiveChanged();
    void tearActiveChanged();
    void smokeActiveChanged();
    void temperatureActiveChanged();
    void guardNetActiveChanged();
    void coalPileActiveChanged();
    void mainEmergencyStopActiveChanged();

    // ========== 环境模拟量信号 ==========
    void speedValueChanged();
    void tensionValueChanged();
    void temperature1ValueChanged();
    void temperature2ValueChanged();
    void temperatureValueChanged();
    void humidityValueChanged();
    void methaneValueChanged();
    void dustValueChanged();
    void coalFlowValueChanged();
    void siloHeightValueChanged();
    void voltageValueChanged();
    void smokeValueChanged();
    void pressureValueChanged();
    void oxygenValueChanged();
    void coValueChanged();
    void h2sValueChanged();
    void co2ValueChanged();
    void windSpeedValueChanged();

    // ========== 电机保护值信号 ==========
    // 兼容旧信号（motor1/2 专用）
    void motor1CurrentValueChanged();
    void motor2CurrentValueChanged();
    void motor1VoltageValueChanged();
    void motor2VoltageValueChanged();
    void motor1XVibrationValueChanged();
    void motor1YVibrationValueChanged();
    void motor2XVibrationValueChanged();
    void motor2YVibrationValueChanged();
    void motor1TemperatureValueChanged();
    void motor2TemperatureValueChanged();
    void motor1PhaseAWindingValueChanged();
    void motor1PhaseBWindingValueChanged();
    void motor1PhaseCWindingValueChanged();
    void motor2PhaseAWindingValueChanged();
    void motor2PhaseBWindingValueChanged();
    void motor2PhaseCWindingValueChanged();

    // ✅ 2026-04-08 [Phase 7.48.88.97]: 通用电机保护值变化信号（8电机×14Tab）
    // QML中: onMotorProtectionValueChanged: { if(motorIndex===2 && tabIndex===1) ... }
    void motorProtectionValueChanged(int motorIndex, int tabIndex, double value);

private:
    QSettings *m_settings;

    // 配置参数
    int m_machineNumber;         // 本机编号 (1-8)
    int m_warningTimeSeconds;    // 起车预警时间(秒)
    int m_warningPlayCount;      // 起车预警播放次数
    WarningMode m_warningMode;   // 播放模式
    QStringList m_startupSequence;  // 启动顺序列表
    QStringList m_stopSequence;     // 停止顺序列表
    // ✅ 2026-03-20 [Phase 7.48.57]: 逻辑控制-每个设备的延时（秒）
    QVariantList m_startupDelays;   // 启动延时列表（与startupSequence一一对应）
    QVariantList m_stopDelays;      // 停止延时列表（与stopSequence一一对应）
    double m_defaultDelay;          // 新设备默认延时（秒）
    QString m_modbusServerIp;       // Modbus服务器IP地址
    QString m_modbusGateway;        // 网关地址
    QString m_modbusSubnetMask;     // 子网掩码
    int m_modbusPollInterval;       // Modbus轮询间隔(毫秒)
    WorkMode m_workMode;            // 工作模式
    QString m_localDeviceName;      // 本机名称
    // ✅ 2026-03-20 [Phase 7.48.60]: 皮带音频来源 0=默认 1=TTS合成
    int m_beltAudioSource = 0;      // 皮带起/停车音频来源

    // 开关量保护状态
    bool m_emergencyStopActive = false;      // 急停
    bool m_runOffActive = false;             // 跑偏
    bool m_tearActive = false;               // 撕裂
    bool m_smokeActive = false;              // 烟雾
    bool m_temperatureActive = false;        // 温度
    bool m_guardNetActive = false;           // 护网
    bool m_coalPileActive = false;           // 堆煤
    bool m_mainEmergencyStopActive = false;  // 主机急停

    // ========== 环境模拟量保护值 ==========
    double m_speedValue = 0.0;               // 速度
    double m_tensionValue = 0.0;             // 张力
    double m_temperature1Value = 0.0;        // 温度一
    double m_temperature2Value = 0.0;        // 温度二
    double m_temperatureValue_env = 0.0;     // 温度（环境温度）
    double m_humidityValue = 0.0;            // 湿度
    double m_methaneValue = 0.0;             // 甲烷
    double m_dustValue = 0.0;                // 粉尘浓度
    double m_coalFlowValue = 0.0;            // 煤流
    double m_siloHeightValue = 0.0;          // 煤仓高度
    double m_voltageValue = 0.0;             // 电压
    double m_smokeValue_env = 0.0;           // 烟雾（环境）
    double m_pressureValue = 0.0;            // 气压
    double m_oxygenValue = 0.0;              // 氧气
    double m_coValue = 0.0;                  // 一氧化碳
    double m_h2sValue = 0.0;                 // 硫化氢
    double m_co2Value = 0.0;                 // 二氧化碳
    double m_windSpeedValue = 0.0;           // 风速

    // ========== 电机保护值 ==========
    // ✅ 2026-04-08 [Phase 7.48.88.97]: 8电机×14Tab 二维数组
    // 行=motorIndex(0-7), 列=tabIndex(0-13)
    // Tab 0(基本配置)不存储保护值，但预留位置
    double m_motorValues[MOTOR_COUNT][MOTOR_TAB_COUNT] = {};  // 全部初始化为0.0

    // 旧：double m_motor1CurrentValue = 0.0; 等18个独立变量
    // 2026-04-08 [Phase 7.48.88.97] 改为数组存储，旧变量由数组替代
    // 电压保留独立变量（电压来自模拟量保护表，不属于电机Tab）
    double m_motor1VoltageValue = 0.0;             // 1号电机电压
    double m_motor2VoltageValue = 0.0;             // 2号电机电压

    // 默认值
    static const int DEFAULT_MACHINE_NUMBER = 1;
    static const int DEFAULT_WARNING_TIME = 10;     // 10秒
    static const int DEFAULT_WARNING_COUNT = 3;     // 3次
    static const WarningMode DEFAULT_WARNING_MODE = ByTime;
    static const WorkMode DEFAULT_WORK_MODE = Maintenance;  // 默认检修模式

    // 默认设备顺序
    static QStringList getDefaultStartupSequence();
    static QStringList getDefaultStopSequence();
    // ✅ 2026-03-20 [Phase 7.48.57]: 默认延时列表
    static QVariantList getDefaultStartupDelays();
    static QVariantList getDefaultStopDelays();
    static constexpr double DEFAULT_DELAY = 1.0;  // 默认延时1秒

    // ✅ 2026-04-08 [Phase 7.48.88.97]: 电机保护值变化时，同时emit兼容信号（motor1/2专用）
    void emitMotorCompatSignal(int motorIndex, int tabIndex);
};

#endif // SYSTEMCONFIG_H
