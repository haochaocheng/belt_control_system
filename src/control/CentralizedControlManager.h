// CentralizedControlManager.h
// 集控管理控制器 - 管理多协议混合集控系统
// 创建日期: 2026-04-11
// ✅ 2026-04-11 [Phase 7.48.88.110]: 新建集控管理控制器
// ✅ 2026-04-14 [Phase 7.48.88.111-115]: 完善数据协议、轮询、控制、心跳、MQTT
// 支持8个分站槽位，每个槽位可配置不同协议（MQTT/S7/Modbus TCP）

#ifndef CENTRALIZEDCONTROLMANAGER_H
#define CENTRALIZEDCONTROLMANAGER_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QSettings>
#include <QTimer>
#include <QDateTime>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QtEndian>

// 前向声明
class DeviceRoleManager;
class MQTTController;
class S7ClientController;
class ModbusTCPMasterController;
class CommonControl;
class SystemConfig;
class MqttProtectionMonitor;
class ProtectionLogicController;
class TCPDataAdapter;
class DeviceRuntimeTracker;

// ========== 分站实时状态 ==========
struct SubStationStatus {
    // 运行状态
    int runState = 0;           // 0=停止,1=预警,2=运行,3=故障,4=松闸,5=停车中
    int faultCode = 0;

    // 电机状态
    quint8 motorRunningByte = 0;
    bool motorStates[8] = {};

    // 模拟量
    float speed = 0, tension = 0;
    float m1Current = 0, m2Current = 0;
    float m1Voltage = 0, m2Voltage = 0;
    float m1Temp = 0, m2Temp = 0;
    float m1XVib = 0, m1YVib = 0, m2XVib = 0, m2YVib = 0;
    float envValues[16] = {};   // 16个环境模拟量

    // 开关量
    quint8 doStates = 0, diFeedback = 0;
    quint8 diMod1 = 0, diMod2 = 0;
    bool estop = false;
    quint8 protectionByte = 0;

    // 运行统计
    int dailyRuntimeSec = 0;
    bool isFault = false;

    // 连接健康
    QDateTime lastUpdateTime;
    int missedHeartbeats = 0;
    bool isOnline = false;

    // 重连状态
    int reconnectAttempts = 0;
    QDateTime nextReconnectTime;

    QVariantMap toVariantMap() const;
};

class CentralizedControlManager : public QObject
{
    Q_OBJECT

    // ========== 角色属性 ==========
    Q_PROPERTY(int localDeviceId READ localDeviceId WRITE setLocalDeviceId NOTIFY localDeviceIdChanged)
    Q_PROPERTY(QString stationRole READ stationRole WRITE setStationRole NOTIFY stationRoleChanged)
    Q_PROPERTY(int stationId READ stationId WRITE setStationId NOTIFY stationIdChanged)
    Q_PROPERTY(bool isMasterMode READ isMasterMode NOTIFY stationRoleChanged)
    Q_PROPERTY(bool isSubMode READ isSubMode NOTIFY stationRoleChanged)

    // ========== 分站槽位管理 ==========
    Q_PROPERTY(QVariantList subStations READ subStations NOTIFY subStationsChanged)
    Q_PROPERTY(int activeSlotCount READ activeSlotCount NOTIFY activeSlotCountChanged)
    Q_PROPERTY(QVariantList slotStatuses READ slotStatuses NOTIFY slotStatusesChanged)

    // ========== MQTT集控配置 ==========
    Q_PROPERTY(QString mqttBrokerIP READ mqttBrokerIP WRITE setMqttBrokerIP NOTIFY mqttBrokerIPChanged)
    Q_PROPERTY(int mqttBrokerPort READ mqttBrokerPort WRITE setMqttBrokerPort NOTIFY mqttBrokerPortChanged)
    Q_PROPERTY(QString mqttClientId READ mqttClientId WRITE setMqttClientId NOTIFY mqttClientIdChanged)
    Q_PROPERTY(int mqttQos READ mqttQos WRITE setMqttQos NOTIFY mqttQosChanged)
    Q_PROPERTY(int mqttKeepAlive READ mqttKeepAlive WRITE setMqttKeepAlive NOTIFY mqttKeepAliveChanged)
    Q_PROPERTY(QString mqttTopicPrefix READ mqttTopicPrefix WRITE setMqttTopicPrefix NOTIFY mqttTopicPrefixChanged)
    Q_PROPERTY(QString mqttUsername READ mqttUsername WRITE setMqttUsername NOTIFY mqttUsernameChanged)
    Q_PROPERTY(QString mqttPassword READ mqttPassword WRITE setMqttPassword NOTIFY mqttPasswordChanged)

    // ========== 顺序启动 ==========
    Q_PROPERTY(QVariantList sequenceOrder READ sequenceOrder NOTIFY sequenceOrderChanged)
    Q_PROPERTY(int sequenceInterval READ sequenceInterval WRITE setSequenceInterval NOTIFY sequenceIntervalChanged)
    Q_PROPERTY(bool sequenceRunning READ sequenceRunning NOTIFY sequenceRunningChanged)
    Q_PROPERTY(int sequenceCurrentStep READ sequenceCurrentStep NOTIFY sequenceCurrentStepChanged)
    Q_PROPERTY(QString sequenceStatusText READ sequenceStatusText NOTIFY sequenceStatusTextChanged)

public:
    explicit CentralizedControlManager(QObject *parent = nullptr);
    ~CentralizedControlManager();

    // ========== 角色属性 ==========
    int localDeviceId() const { return m_localDeviceId; }
    void setLocalDeviceId(int id);

    QString stationRole() const { return m_stationRole; }
    void setStationRole(const QString &role);

    int stationId() const { return m_stationId; }
    void setStationId(int id);

    bool isMasterMode() const { return m_stationRole == "master"; }
    bool isSubMode() const { return m_stationRole == "sub"; }

    // ========== 分站槽位 ==========
    QVariantList subStations() const;
    int activeSlotCount() const;
    QVariantList slotStatuses() const;

    // ========== MQTT集控配置 ==========
    QString mqttBrokerIP() const { return m_mqttBrokerIP; }
    void setMqttBrokerIP(const QString &ip);

    int mqttBrokerPort() const { return m_mqttBrokerPort; }
    void setMqttBrokerPort(int port);

    QString mqttClientId() const { return m_mqttClientId; }
    void setMqttClientId(const QString &id);

    int mqttQos() const { return m_mqttQos; }
    void setMqttQos(int qos);

    int mqttKeepAlive() const { return m_mqttKeepAlive; }
    void setMqttKeepAlive(int seconds);

    QString mqttTopicPrefix() const { return m_mqttTopicPrefix; }
    void setMqttTopicPrefix(const QString &prefix);

    QString mqttUsername() const { return m_mqttUsername; }
    void setMqttUsername(const QString &username);

    QString mqttPassword() const { return m_mqttPassword; }
    void setMqttPassword(const QString &password);

    // ========== 槽位配置操作（Q_INVOKABLE供QML调用）==========
    Q_INVOKABLE void setSlotEnabled(int slotIndex, bool enabled);
    Q_INVOKABLE bool isSlotEnabled(int slotIndex) const;
    Q_INVOKABLE void setSlotProtocol(int slotIndex, const QString &protocol);
    Q_INVOKABLE QString getSlotProtocol(int slotIndex) const;
    Q_INVOKABLE void setSlotTargetIP(int slotIndex, const QString &ip);
    Q_INVOKABLE QString getSlotTargetIP(int slotIndex) const;
    Q_INVOKABLE void setSlotPort(int slotIndex, int port);
    Q_INVOKABLE int getSlotPort(int slotIndex) const;
    Q_INVOKABLE void setSlotParam(int slotIndex, const QString &key, const QVariant &value);
    Q_INVOKABLE QVariant getSlotParam(int slotIndex, const QString &key) const;
    Q_INVOKABLE QVariantMap getSlotConfig(int slotIndex) const;
    Q_INVOKABLE bool connectSlot(int slotIndex);
    Q_INVOKABLE void disconnectSlot(int slotIndex);
    Q_INVOKABLE bool isSlotConnected(int slotIndex) const;
    Q_INVOKABLE QString getSlotStatusText(int slotIndex) const;
    Q_INVOKABLE QString getSlotName(int slotIndex) const;

    // ========== 分站状态查询 ==========
    Q_INVOKABLE QVariantMap getSlotStatus(int slotIndex) const;

    // ========== 控制命令（主站模式）==========
    Q_INVOKABLE void sendStartBelt(int slotIndex, int beltNumber);
    Q_INVOKABLE void sendStopBelt(int slotIndex, int beltNumber);
    Q_INVOKABLE void sendEmergencyStop(int slotIndex, int beltNumber);
    Q_INVOKABLE void sendMotorStart(int slotIndex, int beltNumber, int motorIndex);
    Q_INVOKABLE void sendMotorStop(int slotIndex, int beltNumber, int motorIndex);
    Q_INVOKABLE void sendResetProtection(int slotIndex);
    Q_INVOKABLE void sendResetFault(int slotIndex);

    // ========== 全局操作 ==========
    Q_INVOKABLE void connectAllSlots();
    Q_INVOKABLE void disconnectAllSlots();
    Q_INVOKABLE void startAllBelts();
    Q_INVOKABLE void stopAllBelts();
    Q_INVOKABLE void emergencyStopAll();

    // ========== 顺序启动 ==========
    QVariantList sequenceOrder() const;
    int sequenceInterval() const { return m_sequenceInterval; }
    void setSequenceInterval(int secs);
    bool sequenceRunning() const { return m_sequenceRunning; }
    int sequenceCurrentStep() const { return m_sequenceStep; }
    QString sequenceStatusText() const { return m_sequenceStatusText; }

    Q_INVOKABLE void startSequence();          // 顺序启动（按序）
    Q_INVOKABLE void stopSequence();           // 顺序停止（倒序）
    Q_INVOKABLE void abortSequence();          // 中止当前序列
    Q_INVOKABLE void moveSequenceItem(int fromIndex, int toIndex);  // 调整顺序
    Q_INVOKABLE void resetSequenceOrder();     // 重置为默认顺序
    // ✅ 2026-04-14 [Phase 7.48.88.151]: 每步独立延迟
    Q_INVOKABLE void setSequenceStepDelay(int stepIndex, int delaySecs);

    // ========== 数据持久化 ==========
    Q_INVOKABLE void saveConfig();
    Q_INVOKABLE void loadConfig();

    // ========== 外部控制器绑定 ==========
    void setDeviceRoleManager(DeviceRoleManager *manager);
    void setMQTTController(MQTTController *controller);
    void setCommonControl(CommonControl *ctrl);
    void setSystemConfig(SystemConfig *config);
    void setMqttProtectionMonitor(MqttProtectionMonitor *monitor);
    void setProtectionLogicController(ProtectionLogicController *ctrl);
    void setTCPDataAdapter(TCPDataAdapter *adapter);
    void setDeviceRuntimeTracker(DeviceRuntimeTracker *tracker);

    // ✅ 2026-04-14 [Phase 7.48.88.142]: 依赖注入完成后调用，激活已保存的角色
    void activateLoadedRole();

signals:
    // ========== 角色信号 ==========
    void localDeviceIdChanged();
    void stationRoleChanged();
    void stationIdChanged();

    // ========== 槽位信号 ==========
    void subStationsChanged();
    void activeSlotCountChanged();
    void slotConnectionChanged(int slotIndex, bool connected);
    void slotStatusChanged(int slotIndex, const QString &status);
    void slotStatusesChanged();
    void slotStatusUpdated(int slotIndex);
    void slotOnlineChanged(int slotIndex, bool online);

    // ========== 报警信号 ==========
    void remoteAlarmReceived(int slotIndex, const QString &alarmType, const QString &name);
    void commandSent(int slotIndex, const QString &cmd, bool success);

    // ========== 顺序启动信号 ==========
    void sequenceOrderChanged();
    void sequenceIntervalChanged();
    void sequenceRunningChanged();
    void sequenceCurrentStepChanged();
    void sequenceStatusTextChanged();
    void sequenceStepExecuted(int step, int slotIndex, bool isStart, const QString &msg);

    // ========== MQTT配置信号 ==========
    void mqttBrokerIPChanged();
    void mqttBrokerPortChanged();
    void mqttClientIdChanged();
    void mqttQosChanged();
    void mqttKeepAliveChanged();
    void mqttTopicPrefixChanged();
    void mqttUsernameChanged();
    void mqttPasswordChanged();

    // ========== 错误信号 ==========
    void errorOccurred(const QString &error);

private:
    // ========== 分站槽位数据结构 ==========
    static const int MAX_SLOTS = 8;

    struct SubStationSlot {
        bool enabled = false;
        QString protocol;       // "mqtt", "s7", "modbus"
        QString targetIP;
        int port = 0;
        QVariantMap protocolParams;  // 协议特定参数
        bool isConnected = false;
        QString statusText = "未配置";
        QString name;           // 槽位名称
    };

    SubStationSlot m_slots[MAX_SLOTS];
    SubStationStatus m_slotStatus[MAX_SLOTS];

    // ========== 角色 ==========
    int m_localDeviceId;
    QString m_stationRole;      // "master", "sub", "standalone"
    int m_stationId;

    // ========== MQTT集控配置 ==========
    QString m_mqttBrokerIP;
    int m_mqttBrokerPort;
    QString m_mqttClientId;
    int m_mqttQos;
    int m_mqttKeepAlive;
    QString m_mqttTopicPrefix;
    QString m_mqttUsername;
    QString m_mqttPassword;

    // ========== 外部控制器引用 ==========
    DeviceRoleManager *m_roleManager;
    MQTTController *m_mqttController;
    CommonControl *m_commonControl;
    SystemConfig *m_systemConfig;
    MqttProtectionMonitor *m_protectionMonitor;
    ProtectionLogicController *m_protectionLogicController;
    TCPDataAdapter *m_tcpDataAdapter;
    DeviceRuntimeTracker *m_runtimeTracker;

    // ========== 每槽位协议控制器（按需创建）==========
    S7ClientController *m_s7Clients[MAX_SLOTS] = {};
    ModbusTCPMasterController *m_modbusClients[MAX_SLOTS] = {};

    // ========== 定时器 ==========
    QTimer *m_pollTimer = nullptr;            // 500ms S7/Modbus轮询（主站模式）
    QTimer *m_heartbeatTimer = nullptr;       // 3s 心跳发送（双向）
    QTimer *m_healthCheckTimer = nullptr;     // 3s 连接健康检查（主站模式）
    QTimer *m_statusPublishTimer = nullptr;   // 500ms 本地状态发布（分站模式）
    int m_heartbeatSeq = 0;

    // ========== MQTT订阅追踪 ==========
    bool m_mqttSubscribed = false;

    // ========== 顺序启动 ==========
    QList<int> m_sequenceOrder;      // 槽位索引顺序列表
    QList<int> m_sequenceDelays;     // ✅ 2026-04-14 [Phase 7.48.88.151]: 每步独立延迟（秒）
    int  m_sequenceInterval = 5;     // 全局默认间隔（新步加入时使用）
    bool m_sequenceRunning  = false;
    int  m_sequenceStep     = -1;
    bool m_sequenceIsStart  = true;
    QString m_sequenceStatusText;
    QTimer *m_sequenceTimer = nullptr;

    // ========== 数据持久化 ==========
    QSettings *m_settings;

    // ========== 初始化 ==========
    void initSettings();
    void initSlots();
    void initTimers();

    // ========== S7数据处理 ==========
    void pollS7SlotStatus(int slotIndex);
    void parseS7DB1(int slotIndex, const QByteArray &db1Data);
    void sendS7Command(int slotIndex, const QByteArray &db2Data);
    QByteArray buildS7DB2Command(int beltNumber, quint8 beltCtrl, quint8 motorStart = 0,
                                  quint8 motorStop = 0, quint8 resetCmd = 0);

    // ========== Modbus数据处理 ==========
    void pollModbusSlotStatus(int slotIndex);
    void parseModbusDiscreteInputs(int slotIndex, const QList<bool> &values);
    void parseModbusInputRegisters(int slotIndex, const QList<int> &values);
    void sendModbusCommand(int slotIndex, int coilAddress, bool value);
    void sendModbusRegister(int slotIndex, int address, int value);

    // ========== MQTT数据处理 ==========
    void setupMqttSubscriptions();
    void teardownMqttSubscriptions();
    void handleMqttMessage(const QString &topic, const QByteArray &payload);
    void handleMqttStatusMessage(int slotIndex, const QByteArray &payload);
    void handleMqttHeartbeat(int slotIndex, const QByteArray &payload);
    void handleMqttAlarm(int slotIndex, const QByteArray &payload);
    void publishMqttCommand(int slotIndex, const QString &cmd, const QJsonObject &params);
    void publishHeartbeat();
    void publishLocalStatus();
    void handleRemoteCommand(const QByteArray &payload);

    // ========== 连接健康 ==========
    void checkConnectionHealth();
    void handleSlotOffline(int slotIndex);
    void handleSlotOnline(int slotIndex);
    void attemptReconnect(int slotIndex);

    // ========== 模式切换 ==========
    void enterMasterMode();
    void exitMasterMode();
    void enterSubStationMode();
    void exitSubStationMode();

    // ========== 辅助 ==========
    S7ClientController *getOrCreateS7Client(int slotIndex);
    ModbusTCPMasterController *getOrCreateModbusClient(int slotIndex);
    void destroySlotControllers(int slotIndex);
    // ✅ 2026-04-14 [Phase 7.48.88.151]: 顺序执行内部方法
    void executeSequenceStep();
    int getDefaultPort(const QString &protocol) const;
    int findSlotByDeviceId(int deviceId) const;

    static float bytesToFloat(const QByteArray &data, int offset);
    static void floatToBytes(float value, QByteArray &data, int offset);
    static quint16 bytesToUint16(const QByteArray &data, int offset);
};

#endif // CENTRALIZEDCONTROLMANAGER_H
