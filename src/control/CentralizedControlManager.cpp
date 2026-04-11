// CentralizedControlManager.cpp
// 集控管理控制器实现
// 创建日期: 2026-04-11
// ✅ 2026-04-11 [Phase 7.48.88.110]: 新建集控管理控制器

#include "CentralizedControlManager.h"
#include "DeviceRoleManager.h"
#include "S7ClientController.h"
#include "ModbusTCPMasterController.h"
#include <QDebug>

CentralizedControlManager::CentralizedControlManager(QObject *parent)
    : QObject(parent)
    , m_localDeviceId(1)
    , m_stationRole("standalone")
    , m_stationId(1)
    , m_mqttBrokerIP("192.168.1.1")
    , m_mqttBrokerPort(1883)
    , m_mqttClientId("belt_central_1")
    , m_mqttQos(1)
    , m_mqttKeepAlive(60)
    , m_mqttTopicPrefix("belt/central/")
    , m_mqttUsername("")
    , m_mqttPassword("")
    , m_roleManager(nullptr)
    , m_mqttController(nullptr)
    , m_settings(nullptr)
{
    initSettings();
    initSlots();
    loadConfig();

    qDebug() << "✅ [CentralizedControlManager] 初始化完成";
}

CentralizedControlManager::~CentralizedControlManager()
{
    disconnectAllSlots();

    // 释放按需创建的控制器
    for (int i = 0; i < MAX_SLOTS; ++i) {
        destroySlotControllers(i);
    }
}

// ========== 角色属性 ==========
void CentralizedControlManager::setLocalDeviceId(int id)
{
    if (m_localDeviceId != id && id >= 1 && id <= 8) {
        m_localDeviceId = id;
        // 同步到DeviceRoleManager
        if (m_roleManager) {
            m_roleManager->setLocalDeviceId(id);
        }
        emit localDeviceIdChanged();
    }
}

void CentralizedControlManager::setStationRole(const QString &role)
{
    if (m_stationRole != role) {
        m_stationRole = role;
        // 同步到DeviceRoleManager
        if (m_roleManager) {
            m_roleManager->setStationRole(role);
        }
        emit stationRoleChanged();

        // 切换到非主站模式时断开所有分站连接
        if (role != "master") {
            disconnectAllSlots();
        }
    }
}

void CentralizedControlManager::setStationId(int id)
{
    if (m_stationId != id && id >= 1 && id <= 8) {
        m_stationId = id;
        emit stationIdChanged();
    }
}

// ========== 分站槽位查询 ==========
QVariantList CentralizedControlManager::subStations() const
{
    QVariantList list;
    for (int i = 0; i < MAX_SLOTS; ++i) {
        QVariantMap slot;
        slot["index"] = i;
        slot["enabled"] = m_slots[i].enabled;
        slot["protocol"] = m_slots[i].protocol;
        slot["targetIP"] = m_slots[i].targetIP;
        slot["port"] = m_slots[i].port;
        slot["isConnected"] = m_slots[i].isConnected;
        slot["statusText"] = m_slots[i].statusText;
        slot["name"] = m_slots[i].name;
        list.append(slot);
    }
    return list;
}

int CentralizedControlManager::activeSlotCount() const
{
    int count = 0;
    for (int i = 0; i < MAX_SLOTS; ++i) {
        if (m_slots[i].enabled) {
            count++;
        }
    }
    return count;
}

// ========== MQTT集控配置 ==========
void CentralizedControlManager::setMqttBrokerIP(const QString &ip)
{
    if (m_mqttBrokerIP != ip) {
        m_mqttBrokerIP = ip;
        emit mqttBrokerIPChanged();
    }
}

void CentralizedControlManager::setMqttBrokerPort(int port)
{
    if (m_mqttBrokerPort != port) {
        m_mqttBrokerPort = port;
        emit mqttBrokerPortChanged();
    }
}

void CentralizedControlManager::setMqttClientId(const QString &id)
{
    if (m_mqttClientId != id) {
        m_mqttClientId = id;
        emit mqttClientIdChanged();
    }
}

void CentralizedControlManager::setMqttQos(int qos)
{
    if (m_mqttQos != qos && qos >= 0 && qos <= 2) {
        m_mqttQos = qos;
        emit mqttQosChanged();
    }
}

void CentralizedControlManager::setMqttKeepAlive(int seconds)
{
    if (m_mqttKeepAlive != seconds) {
        m_mqttKeepAlive = seconds;
        emit mqttKeepAliveChanged();
    }
}

void CentralizedControlManager::setMqttTopicPrefix(const QString &prefix)
{
    if (m_mqttTopicPrefix != prefix) {
        m_mqttTopicPrefix = prefix;
        emit mqttTopicPrefixChanged();
    }
}

void CentralizedControlManager::setMqttUsername(const QString &username)
{
    if (m_mqttUsername != username) {
        m_mqttUsername = username;
        emit mqttUsernameChanged();
    }
}

void CentralizedControlManager::setMqttPassword(const QString &password)
{
    if (m_mqttPassword != password) {
        m_mqttPassword = password;
        emit mqttPasswordChanged();
    }
}

// ========== 槽位操作 ==========
void CentralizedControlManager::setSlotEnabled(int slotIndex, bool enabled)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;

    if (m_slots[slotIndex].enabled != enabled) {
        m_slots[slotIndex].enabled = enabled;
        if (!enabled) {
            disconnectSlot(slotIndex);
            m_slots[slotIndex].statusText = "已禁用";
        } else {
            m_slots[slotIndex].statusText = "已配置";
        }
        emit subStationsChanged();
        emit activeSlotCountChanged();
    }
}

bool CentralizedControlManager::isSlotEnabled(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return false;
    return m_slots[slotIndex].enabled;
}

void CentralizedControlManager::setSlotProtocol(int slotIndex, const QString &protocol)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;

    if (m_slots[slotIndex].protocol != protocol) {
        // 切换协议时断开并释放旧控制器
        disconnectSlot(slotIndex);
        destroySlotControllers(slotIndex);

        m_slots[slotIndex].protocol = protocol;
        m_slots[slotIndex].port = getDefaultPort(protocol);
        m_slots[slotIndex].protocolParams.clear();
        emit subStationsChanged();
    }
}

QString CentralizedControlManager::getSlotProtocol(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return "";
    return m_slots[slotIndex].protocol;
}

void CentralizedControlManager::setSlotTargetIP(int slotIndex, const QString &ip)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;
    m_slots[slotIndex].targetIP = ip;
    emit subStationsChanged();
}

QString CentralizedControlManager::getSlotTargetIP(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return "";
    return m_slots[slotIndex].targetIP;
}

void CentralizedControlManager::setSlotPort(int slotIndex, int port)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;
    m_slots[slotIndex].port = port;
    emit subStationsChanged();
}

int CentralizedControlManager::getSlotPort(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return 0;
    return m_slots[slotIndex].port;
}

void CentralizedControlManager::setSlotParam(int slotIndex, const QString &key, const QVariant &value)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;
    m_slots[slotIndex].protocolParams[key] = value;
    emit subStationsChanged();
}

QVariant CentralizedControlManager::getSlotParam(int slotIndex, const QString &key) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return QVariant();
    return m_slots[slotIndex].protocolParams.value(key);
}

QVariantMap CentralizedControlManager::getSlotConfig(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return QVariantMap();

    QVariantMap config;
    config["enabled"] = m_slots[slotIndex].enabled;
    config["protocol"] = m_slots[slotIndex].protocol;
    config["targetIP"] = m_slots[slotIndex].targetIP;
    config["port"] = m_slots[slotIndex].port;
    config["isConnected"] = m_slots[slotIndex].isConnected;
    config["statusText"] = m_slots[slotIndex].statusText;
    config["name"] = m_slots[slotIndex].name;

    // 合并协议特定参数
    for (auto it = m_slots[slotIndex].protocolParams.begin();
         it != m_slots[slotIndex].protocolParams.end(); ++it) {
        config[it.key()] = it.value();
    }

    return config;
}

bool CentralizedControlManager::connectSlot(int slotIndex)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return false;

    if (!m_slots[slotIndex].enabled) {
        qWarning() << "❌ [集控管理] 槽位" << slotIndex << "未启用";
        return false;
    }

    if (m_stationRole != "master") {
        qWarning() << "❌ [集控管理] 当前非主站模式，无法连接分站";
        emit errorOccurred("当前非主站模式，无法连接分站");
        return false;
    }

    const QString &protocol = m_slots[slotIndex].protocol;

    if (protocol == "s7") {
        S7ClientController *client = getOrCreateS7Client(slotIndex);
        if (!client) return false;

        client->setTargetIP(m_slots[slotIndex].targetIP);
        client->setPort(m_slots[slotIndex].port);
        client->setRack(m_slots[slotIndex].protocolParams.value("rack", 0).toInt());
        client->setSlot(m_slots[slotIndex].protocolParams.value("slot", 2).toInt());
        client->setConnectionType(m_slots[slotIndex].protocolParams.value("connectionType", "PG").toString());

        bool ok = client->connectToPLC();
        m_slots[slotIndex].isConnected = ok;
        m_slots[slotIndex].statusText = ok ? "已连接" : "连接失败";

        if (ok) {
            client->startPolling();
        }

        emit slotConnectionChanged(slotIndex, ok);
        emit subStationsChanged();
        return ok;

    } else if (protocol == "modbus") {
        ModbusTCPMasterController *client = getOrCreateModbusClient(slotIndex);
        if (!client) return false;

        client->setTargetIP(m_slots[slotIndex].targetIP);
        client->setPort(m_slots[slotIndex].port);
        client->setSlaveAddress(m_slots[slotIndex].protocolParams.value("slaveAddress", 1).toInt());
        client->setStartRegister(m_slots[slotIndex].protocolParams.value("startRegister", 0).toInt());
        client->setRegisterCount(m_slots[slotIndex].protocolParams.value("registerCount", 10).toInt());

        bool ok = client->connectToServer();
        m_slots[slotIndex].isConnected = ok;
        m_slots[slotIndex].statusText = ok ? "已连接" : "连接失败";

        if (ok) {
            client->startPolling();
        }

        emit slotConnectionChanged(slotIndex, ok);
        emit subStationsChanged();
        return ok;

    } else if (protocol == "mqtt") {
        // MQTT通过共享的MQTT Broker连接，这里只标记状态
        // 实际MQTT连接由MQTTController管理
        m_slots[slotIndex].isConnected = true;
        m_slots[slotIndex].statusText = "MQTT已配置";
        emit slotConnectionChanged(slotIndex, true);
        emit subStationsChanged();
        return true;

    } else {
        qWarning() << "❌ [集控管理] 槽位" << slotIndex << "未知协议:" << protocol;
        return false;
    }
}

void CentralizedControlManager::disconnectSlot(int slotIndex)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;

    const QString &protocol = m_slots[slotIndex].protocol;

    if (protocol == "s7" && m_s7Clients[slotIndex]) {
        m_s7Clients[slotIndex]->disconnectFromPLC();
    } else if (protocol == "modbus" && m_modbusClients[slotIndex]) {
        m_modbusClients[slotIndex]->disconnectFromServer();
    }

    m_slots[slotIndex].isConnected = false;
    m_slots[slotIndex].statusText = m_slots[slotIndex].enabled ? "已断开" : "已禁用";
    emit slotConnectionChanged(slotIndex, false);
    emit subStationsChanged();
}

bool CentralizedControlManager::isSlotConnected(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return false;
    return m_slots[slotIndex].isConnected;
}

QString CentralizedControlManager::getSlotStatusText(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return "";
    return m_slots[slotIndex].statusText;
}

QString CentralizedControlManager::getSlotName(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return "";
    if (!m_slots[slotIndex].name.isEmpty()) {
        return m_slots[slotIndex].name;
    }
    return QString("分站 %1").arg(slotIndex + 1);
}

// ========== 全局操作 ==========
void CentralizedControlManager::connectAllSlots()
{
    for (int i = 0; i < MAX_SLOTS; ++i) {
        if (m_slots[i].enabled) {
            connectSlot(i);
        }
    }
}

void CentralizedControlManager::disconnectAllSlots()
{
    for (int i = 0; i < MAX_SLOTS; ++i) {
        if (m_slots[i].isConnected) {
            disconnectSlot(i);
        }
    }
}

// ========== 数据持久化 ==========
void CentralizedControlManager::initSettings()
{
    m_settings = new QSettings("BeltControlSystem", "CentralizedControl", this);
}

void CentralizedControlManager::saveConfig()
{
    if (!m_settings) {
        initSettings();
    }

    // 保存角色配置
    m_settings->setValue("Role/localDeviceId", m_localDeviceId);
    m_settings->setValue("Role/stationRole", m_stationRole);
    m_settings->setValue("Role/stationId", m_stationId);

    // 保存MQTT集控配置
    m_settings->setValue("MQTT/brokerIP", m_mqttBrokerIP);
    m_settings->setValue("MQTT/brokerPort", m_mqttBrokerPort);
    m_settings->setValue("MQTT/clientId", m_mqttClientId);
    m_settings->setValue("MQTT/qos", m_mqttQos);
    m_settings->setValue("MQTT/keepAlive", m_mqttKeepAlive);
    m_settings->setValue("MQTT/topicPrefix", m_mqttTopicPrefix);
    m_settings->setValue("MQTT/username", m_mqttUsername);
    m_settings->setValue("MQTT/password", m_mqttPassword);

    // 保存每个槽位配置
    for (int i = 0; i < MAX_SLOTS; ++i) {
        QString prefix = QString("Slot%1/").arg(i);
        m_settings->setValue(prefix + "enabled", m_slots[i].enabled);
        m_settings->setValue(prefix + "protocol", m_slots[i].protocol);
        m_settings->setValue(prefix + "targetIP", m_slots[i].targetIP);
        m_settings->setValue(prefix + "port", m_slots[i].port);
        m_settings->setValue(prefix + "name", m_slots[i].name);

        // 保存协议特定参数
        QVariantMap params = m_slots[i].protocolParams;
        for (auto it = params.begin(); it != params.end(); ++it) {
            m_settings->setValue(prefix + "param_" + it.key(), it.value());
        }
    }

    m_settings->sync();
    qDebug() << "✅ [集控管理] 配置已保存";
}

void CentralizedControlManager::loadConfig()
{
    if (!m_settings) {
        initSettings();
    }

    // 加载角色配置
    m_localDeviceId = m_settings->value("Role/localDeviceId", 1).toInt();
    m_stationRole = m_settings->value("Role/stationRole", "standalone").toString();
    m_stationId = m_settings->value("Role/stationId", 1).toInt();

    // 加载MQTT集控配置
    m_mqttBrokerIP = m_settings->value("MQTT/brokerIP", "192.168.1.1").toString();
    m_mqttBrokerPort = m_settings->value("MQTT/brokerPort", 1883).toInt();
    m_mqttClientId = m_settings->value("MQTT/clientId", "belt_central_1").toString();
    m_mqttQos = m_settings->value("MQTT/qos", 1).toInt();
    m_mqttKeepAlive = m_settings->value("MQTT/keepAlive", 60).toInt();
    m_mqttTopicPrefix = m_settings->value("MQTT/topicPrefix", "belt/central/").toString();
    m_mqttUsername = m_settings->value("MQTT/username", "").toString();
    m_mqttPassword = m_settings->value("MQTT/password", "").toString();

    // 加载每个槽位配置
    for (int i = 0; i < MAX_SLOTS; ++i) {
        QString prefix = QString("Slot%1/").arg(i);
        m_slots[i].enabled = m_settings->value(prefix + "enabled", false).toBool();
        m_slots[i].protocol = m_settings->value(prefix + "protocol", "").toString();
        m_slots[i].targetIP = m_settings->value(prefix + "targetIP", "").toString();
        m_slots[i].port = m_settings->value(prefix + "port", 0).toInt();
        m_slots[i].name = m_settings->value(prefix + "name", "").toString();

        if (m_slots[i].port == 0 && !m_slots[i].protocol.isEmpty()) {
            m_slots[i].port = getDefaultPort(m_slots[i].protocol);
        }

        m_slots[i].statusText = m_slots[i].enabled ? "已配置" : "未配置";

        // 加载协议特定参数
        QStringList keys = m_settings->allKeys();
        for (const QString &key : keys) {
            if (key.startsWith(prefix + "param_")) {
                QString paramKey = key.mid(prefix.length() + 6); // 去掉 "param_" 前缀
                m_slots[i].protocolParams[paramKey] = m_settings->value(key);
            }
        }
    }

    qDebug() << "✅ [集控管理] 配置已加载 - 角色:" << m_stationRole
             << "设备ID:" << m_localDeviceId;
}

// ========== 外部控制器绑定 ==========
void CentralizedControlManager::setDeviceRoleManager(DeviceRoleManager *manager)
{
    m_roleManager = manager;

    // 从DeviceRoleManager同步当前状态
    if (m_roleManager) {
        m_localDeviceId = m_roleManager->localDeviceId();
        m_stationRole = m_roleManager->stationRole();
    }
}

void CentralizedControlManager::setMQTTController(MQTTController *controller)
{
    m_mqttController = controller;
}

// ========== 辅助函数 ==========
void CentralizedControlManager::initSlots()
{
    for (int i = 0; i < MAX_SLOTS; ++i) {
        m_slots[i].name = QString("分站 %1").arg(i + 1);
    }
}

S7ClientController *CentralizedControlManager::getOrCreateS7Client(int slotIndex)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return nullptr;

    if (!m_s7Clients[slotIndex]) {
        m_s7Clients[slotIndex] = new S7ClientController(this);
        qDebug() << "✅ [集控管理] 创建S7客户端 - 槽位:" << slotIndex;
    }
    return m_s7Clients[slotIndex];
}

ModbusTCPMasterController *CentralizedControlManager::getOrCreateModbusClient(int slotIndex)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return nullptr;

    if (!m_modbusClients[slotIndex]) {
        m_modbusClients[slotIndex] = new ModbusTCPMasterController(this);
        qDebug() << "✅ [集控管理] 创建Modbus客户端 - 槽位:" << slotIndex;
    }
    return m_modbusClients[slotIndex];
}

void CentralizedControlManager::destroySlotControllers(int slotIndex)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;

    if (m_s7Clients[slotIndex]) {
        m_s7Clients[slotIndex]->disconnectFromPLC();
        delete m_s7Clients[slotIndex];
        m_s7Clients[slotIndex] = nullptr;
    }

    if (m_modbusClients[slotIndex]) {
        m_modbusClients[slotIndex]->disconnectFromServer();
        delete m_modbusClients[slotIndex];
        m_modbusClients[slotIndex] = nullptr;
    }
}

int CentralizedControlManager::getDefaultPort(const QString &protocol) const
{
    if (protocol == "s7") return 102;
    if (protocol == "modbus") return 502;
    if (protocol == "mqtt") return 1883;
    return 0;
}
