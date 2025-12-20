#ifndef SYSTEMCONFIG_H
#define SYSTEMCONFIG_H

#include <QObject>
#include <QSettings>

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
    Q_PROPERTY(QString modbusServerIp READ modbusServerIp WRITE setModbusServerIp NOTIFY modbusServerIpChanged)
    Q_PROPERTY(QString modbusGateway READ modbusGateway WRITE setModbusGateway NOTIFY modbusGatewayChanged)
    Q_PROPERTY(QString modbusSubnetMask READ modbusSubnetMask WRITE setModbusSubnetMask NOTIFY modbusSubnetMaskChanged)
    Q_PROPERTY(int modbusPollInterval READ modbusPollInterval WRITE setModbusPollInterval NOTIFY modbusPollIntervalChanged)
    Q_PROPERTY(WorkMode workMode READ workMode WRITE setWorkMode NOTIFY workModeChanged)
    Q_PROPERTY(QString localDeviceName READ localDeviceName WRITE setLocalDeviceName NOTIFY localDeviceNameChanged)

    // 开关量保护状态
    Q_PROPERTY(bool emergencyStopActive READ emergencyStopActive NOTIFY emergencyStopActiveChanged)
    Q_PROPERTY(bool runOffActive READ runOffActive NOTIFY runOffActiveChanged)
    Q_PROPERTY(bool tearActive READ tearActive NOTIFY tearActiveChanged)
    Q_PROPERTY(bool smokeActive READ smokeActive NOTIFY smokeActiveChanged)
    Q_PROPERTY(bool temperatureActive READ temperatureActive NOTIFY temperatureActiveChanged)
    Q_PROPERTY(bool guardNetActive READ guardNetActive NOTIFY guardNetActiveChanged)
    Q_PROPERTY(bool coalPileActive READ coalPileActive NOTIFY coalPileActiveChanged)
    Q_PROPERTY(bool mainEmergencyStopActive READ mainEmergencyStopActive NOTIFY mainEmergencyStopActiveChanged)

    // 模拟量保护值
    Q_PROPERTY(double speedValue READ speedValue NOTIFY speedValueChanged)
    Q_PROPERTY(double tensionValue READ tensionValue NOTIFY tensionValueChanged)
    Q_PROPERTY(double motor1CurrentValue READ motor1CurrentValue NOTIFY motor1CurrentValueChanged)
    Q_PROPERTY(double motor2CurrentValue READ motor2CurrentValue NOTIFY motor2CurrentValueChanged)
    Q_PROPERTY(double motor1VoltageValue READ motor1VoltageValue NOTIFY motor1VoltageValueChanged)
    Q_PROPERTY(double motor2VoltageValue READ motor2VoltageValue NOTIFY motor2VoltageValueChanged)
    Q_PROPERTY(double motor1XVibrationValue READ motor1XVibrationValue NOTIFY motor1XVibrationValueChanged)
    Q_PROPERTY(double motor1YVibrationValue READ motor1YVibrationValue NOTIFY motor1YVibrationValueChanged)
    Q_PROPERTY(double motor2XVibrationValue READ motor2XVibrationValue NOTIFY motor2XVibrationValueChanged)
    Q_PROPERTY(double motor2YVibrationValue READ motor2YVibrationValue NOTIFY motor2YVibrationValueChanged)
    Q_PROPERTY(double motor1TemperatureValue READ motor1TemperatureValue NOTIFY motor1TemperatureValueChanged)
    Q_PROPERTY(double motor2TemperatureValue READ motor2TemperatureValue NOTIFY motor2TemperatureValueChanged)
    Q_PROPERTY(double motor1PhaseAWindingValue READ motor1PhaseAWindingValue NOTIFY motor1PhaseAWindingValueChanged)
    Q_PROPERTY(double motor1PhaseBWindingValue READ motor1PhaseBWindingValue NOTIFY motor1PhaseBWindingValueChanged)
    Q_PROPERTY(double motor1PhaseCWindingValue READ motor1PhaseCWindingValue NOTIFY motor1PhaseCWindingValueChanged)
    Q_PROPERTY(double motor2PhaseAWindingValue READ motor2PhaseAWindingValue NOTIFY motor2PhaseAWindingValueChanged)
    Q_PROPERTY(double motor2PhaseBWindingValue READ motor2PhaseBWindingValue NOTIFY motor2PhaseBWindingValueChanged)
    Q_PROPERTY(double motor2PhaseCWindingValue READ motor2PhaseCWindingValue NOTIFY motor2PhaseCWindingValueChanged)

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

    explicit SystemConfig(QObject *parent = nullptr);
    ~SystemConfig();

    // Getters
    int machineNumber() const { return m_machineNumber; }
    int warningTimeSeconds() const { return m_warningTimeSeconds; }
    int warningPlayCount() const { return m_warningPlayCount; }
    WarningMode warningMode() const { return m_warningMode; }
    QStringList startupSequence() const { return m_startupSequence; }
    QStringList stopSequence() const { return m_stopSequence; }
    QString modbusServerIp() const { return m_modbusServerIp; }
    QString modbusGateway() const { return m_modbusGateway; }
    QString modbusSubnetMask() const { return m_modbusSubnetMask; }
    int modbusPollInterval() const { return m_modbusPollInterval; }
    WorkMode workMode() const { return m_workMode; }
    QString localDeviceName() const { return m_localDeviceName; }

    // 开关量保护状态 Getters
    bool emergencyStopActive() const { return m_emergencyStopActive; }
    bool runOffActive() const { return m_runOffActive; }
    bool tearActive() const { return m_tearActive; }
    bool smokeActive() const { return m_smokeActive; }
    bool temperatureActive() const { return m_temperatureActive; }
    bool guardNetActive() const { return m_guardNetActive; }
    bool coalPileActive() const { return m_coalPileActive; }
    bool mainEmergencyStopActive() const { return m_mainEmergencyStopActive; }

    // 模拟量保护值 Getters
    double speedValue() const { return m_speedValue; }
    double tensionValue() const { return m_tensionValue; }
    double motor1CurrentValue() const { return m_motor1CurrentValue; }
    double motor2CurrentValue() const { return m_motor2CurrentValue; }
    double motor1VoltageValue() const { return m_motor1VoltageValue; }
    double motor2VoltageValue() const { return m_motor2VoltageValue; }
    double motor1XVibrationValue() const { return m_motor1XVibrationValue; }
    double motor1YVibrationValue() const { return m_motor1YVibrationValue; }
    double motor2XVibrationValue() const { return m_motor2XVibrationValue; }
    double motor2YVibrationValue() const { return m_motor2YVibrationValue; }
    double motor1TemperatureValue() const { return m_motor1TemperatureValue; }
    double motor2TemperatureValue() const { return m_motor2TemperatureValue; }
    double motor1PhaseAWindingValue() const { return m_motor1PhaseAWindingValue; }
    double motor1PhaseBWindingValue() const { return m_motor1PhaseBWindingValue; }
    double motor1PhaseCWindingValue() const { return m_motor1PhaseCWindingValue; }
    double motor2PhaseAWindingValue() const { return m_motor2PhaseAWindingValue; }
    double motor2PhaseBWindingValue() const { return m_motor2PhaseBWindingValue; }
    double motor2PhaseCWindingValue() const { return m_motor2PhaseCWindingValue; }

    // Setters
    void setMachineNumber(int number);
    void setWarningTimeSeconds(int seconds);
    void setWarningPlayCount(int count);
    void setWarningMode(WarningMode mode);
    void setStartupSequence(const QStringList &sequence);
    void setStopSequence(const QStringList &sequence);
    void setModbusServerIp(const QString &ip);
    void setModbusGateway(const QString &gateway);
    void setModbusSubnetMask(const QString &subnetMask);
    void setModbusPollInterval(int interval);
    void setWorkMode(WorkMode mode);
    void setLocalDeviceName(const QString &name);

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
    void modbusServerIpChanged();
    void modbusGatewayChanged();
    void modbusSubnetMaskChanged();
    void modbusPollIntervalChanged();
    void workModeChanged();
    void localDeviceNameChanged();
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

    // 模拟量保护值信号
    void speedValueChanged();
    void tensionValueChanged();
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

private:
    QSettings *m_settings;

    // 配置参数
    int m_machineNumber;         // 本机编号 (1-8)
    int m_warningTimeSeconds;    // 起车预警时间(秒)
    int m_warningPlayCount;      // 起车预警播放次数
    WarningMode m_warningMode;   // 播放模式
    QStringList m_startupSequence;  // 启动顺序列表
    QStringList m_stopSequence;     // 停止顺序列表
    QString m_modbusServerIp;       // Modbus服务器IP地址
    QString m_modbusGateway;        // 网关地址
    QString m_modbusSubnetMask;     // 子网掩码
    int m_modbusPollInterval;       // Modbus轮询间隔(毫秒)
    WorkMode m_workMode;            // 工作模式
    QString m_localDeviceName;      // 本机名称

    // 开关量保护状态
    bool m_emergencyStopActive = false;      // 急停
    bool m_runOffActive = false;             // 跑偏
    bool m_tearActive = false;               // 撕裂
    bool m_smokeActive = false;              // 烟雾
    bool m_temperatureActive = false;        // 温度
    bool m_guardNetActive = false;           // 护网
    bool m_coalPileActive = false;           // 堆煤
    bool m_mainEmergencyStopActive = false;  // 主机急停

    // 模拟量保护值
    double m_speedValue = 0.0;                     // 速度
    double m_tensionValue = 0.0;                   // 张力
    double m_motor1CurrentValue = 0.0;             // 1号电机电流
    double m_motor2CurrentValue = 0.0;             // 2号电机电流
    double m_motor1VoltageValue = 0.0;             // 1号电机电压
    double m_motor2VoltageValue = 0.0;             // 2号电机电压
    double m_motor1XVibrationValue = 0.0;          // 1号电机X振动
    double m_motor1YVibrationValue = 0.0;          // 1号电机Y振动
    double m_motor2XVibrationValue = 0.0;          // 2号电机X振动
    double m_motor2YVibrationValue = 0.0;          // 2号电机Y振动
    double m_motor1TemperatureValue = 0.0;         // 1号电机温度
    double m_motor2TemperatureValue = 0.0;         // 2号电机温度
    double m_motor1PhaseAWindingValue = 0.0;       // 1号电机第一项绕组
    double m_motor1PhaseBWindingValue = 0.0;       // 1号电机第二项绕组
    double m_motor1PhaseCWindingValue = 0.0;       // 1号电机第三项绕组
    double m_motor2PhaseAWindingValue = 0.0;       // 2号电机第一项绕组
    double m_motor2PhaseBWindingValue = 0.0;       // 2号电机第二项绕组
    double m_motor2PhaseCWindingValue = 0.0;       // 2号电机第三项绕组

    // 默认值
    static const int DEFAULT_MACHINE_NUMBER = 1;
    static const int DEFAULT_WARNING_TIME = 10;     // 10秒
    static const int DEFAULT_WARNING_COUNT = 3;     // 3次
    static const WarningMode DEFAULT_WARNING_MODE = ByTime;
    static const WorkMode DEFAULT_WORK_MODE = Maintenance;  // 默认检修模式

    // 默认设备顺序
    static QStringList getDefaultStartupSequence();
    static QStringList getDefaultStopSequence();
};

#endif // SYSTEMCONFIG_H
