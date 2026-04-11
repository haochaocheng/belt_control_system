// CentralizedControlManager.h
// 集控管理控制器 - 管理多协议混合集控系统
// 创建日期: 2026-04-11
// ✅ 2026-04-11 [Phase 7.48.88.110]: 新建集控管理控制器
// 支持8个分站槽位，每个槽位可配置不同协议（MQTT/S7/Modbus TCP）

#ifndef CENTRALIZEDCONTROLMANAGER_H
#define CENTRALIZEDCONTROLMANAGER_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QSettings>
#include <QTimer>

// 前向声明
class DeviceRoleManager;
class MQTTController;
class S7ClientController;
class ModbusTCPMasterController;

class CentralizedControlManager : public QObject
{
    Q_OBJECT

    // ========== 角色属性（委托给DeviceRoleManager）==========
    Q_PROPERTY(int localDeviceId READ localDeviceId WRITE setLocalDeviceId NOTIFY localDeviceIdChanged)
    Q_PROPERTY(QString stationRole READ stationRole WRITE setStationRole NOTIFY stationRoleChanged)
    Q_PROPERTY(int stationId READ stationId WRITE setStationId NOTIFY stationIdChanged)

    // ========== 分站槽位管理 ==========
    Q_PROPERTY(QVariantList subStations READ subStations NOTIFY subStationsChanged)
    Q_PROPERTY(int activeSlotCount READ activeSlotCount NOTIFY activeSlotCountChanged)

    // ========== MQTT集控配置 ==========
    Q_PROPERTY(QString mqttBrokerIP READ mqttBrokerIP WRITE setMqttBrokerIP NOTIFY mqttBrokerIPChanged)
    Q_PROPERTY(int mqttBrokerPort READ mqttBrokerPort WRITE setMqttBrokerPort NOTIFY mqttBrokerPortChanged)
    Q_PROPERTY(QString mqttClientId READ mqttClientId WRITE setMqttClientId NOTIFY mqttClientIdChanged)
    Q_PROPERTY(int mqttQos READ mqttQos WRITE setMqttQos NOTIFY mqttQosChanged)
    Q_PROPERTY(int mqttKeepAlive READ mqttKeepAlive WRITE setMqttKeepAlive NOTIFY mqttKeepAliveChanged)
    Q_PROPERTY(QString mqttTopicPrefix READ mqttTopicPrefix WRITE setMqttTopicPrefix NOTIFY mqttTopicPrefixChanged)
    Q_PROPERTY(QString mqttUsername READ mqttUsername WRITE setMqttUsername NOTIFY mqttUsernameChanged)
    Q_PROPERTY(QString mqttPassword READ mqttPassword WRITE setMqttPassword NOTIFY mqttPasswordChanged)

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

    // ========== 分站槽位 ==========
    QVariantList subStations() const;
    int activeSlotCount() const;

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

    // ========== 槽位操作（Q_INVOKABLE供QML调用）==========
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

    // ========== 全局操作 ==========
    Q_INVOKABLE void connectAllSlots();
    Q_INVOKABLE void disconnectAllSlots();

    // ========== 数据持久化 ==========
    Q_INVOKABLE void saveConfig();
    Q_INVOKABLE void loadConfig();

    // ========== 外部控制器绑定 ==========
    void setDeviceRoleManager(DeviceRoleManager *manager);
    void setMQTTController(MQTTController *controller);

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

    // ========== 每槽位协议控制器（按需创建）==========
    S7ClientController *m_s7Clients[MAX_SLOTS] = {};
    ModbusTCPMasterController *m_modbusClients[MAX_SLOTS] = {};

    // ========== 数据持久化 ==========
    QSettings *m_settings;

    // ========== 辅助函数 ==========
    void initSettings();
    void initSlots();
    S7ClientController *getOrCreateS7Client(int slotIndex);
    ModbusTCPMasterController *getOrCreateModbusClient(int slotIndex);
    void destroySlotControllers(int slotIndex);
    int getDefaultPort(const QString &protocol) const;
};

#endif // CENTRALIZEDCONTROLMANAGER_H
