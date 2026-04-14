// CentralizedControlManager.cpp
// 集控管理控制器 - 管理多协议混合集控系统
// 创建日期: 2026-04-11
// ✅ 2026-04-11 [Phase 7.48.88.110]: 新建集控管理控制器
// ✅ 2026-04-14 [Phase 7.48.88.111]: SubStationStatus结构 + 初始化框架
// ✅ 2026-04-14 [Phase 7.48.88.112]: S7轮询解析 + DB2控制命令
// ✅ 2026-04-14 [Phase 7.48.88.113]: Modbus轮询 + 控制
// ✅ 2026-04-14 [Phase 7.48.88.114]: MQTT协议 + 分站被动模式
// ✅ 2026-04-14 [Phase 7.48.88.115]: 心跳 + 连接健康监测 + 自动重连

#include "CentralizedControlManager.h"
#include "DeviceRoleManager.h"
#include "mqtt/MQTTController.h"
#include "S7ClientController.h"
#include "ModbusTCPMasterController.h"
#include "CommonControl.h"
#include "SystemConfig.h"
#include "MqttProtectionMonitor.h"
#include "ProtectionLogicController.h"
#include "DataPathConfig.h"
#include "TCPDataAdapter.h"
#include "DeviceRuntimeTracker.h"

#include <QDebug>
#include <QSettings>
#include <QDateTime>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <cstring>

// ========== MQTT集控模块索引（使用MQTTController的第7个模块，预留给集控）==========
// ✅ 2026-04-14 [Phase 7.48.88.117]: 从模块0改为模块7
// 原因：模块0-6已被DI/AI/DO/CS数据管理器占用，模块7为预留模块
static const int CENTRAL_MQTT_MODULE = 7;

// ========== SubStationStatus::toVariantMap ==========

QVariantMap SubStationStatus::toVariantMap() const
{
    QVariantMap m;
    m["runState"]         = runState;
    m["faultCode"]        = faultCode;
    m["motorRunningByte"] = (int)motorRunningByte;

    QVariantList motors;
    for (int i = 0; i < 8; i++) motors << motorStates[i];
    m["motorStates"] = motors;

    m["speed"]     = (double)speed;
    m["tension"]   = (double)tension;
    m["m1Current"] = (double)m1Current;
    m["m2Current"] = (double)m2Current;
    m["m1Voltage"] = (double)m1Voltage;
    m["m2Voltage"] = (double)m2Voltage;
    m["m1Temp"]    = (double)m1Temp;
    m["m2Temp"]    = (double)m2Temp;
    m["m1XVib"]    = (double)m1XVib;
    m["m1YVib"]    = (double)m1YVib;
    m["m2XVib"]    = (double)m2XVib;
    m["m2YVib"]    = (double)m2YVib;

    QVariantList envList;
    for (int i = 0; i < 16; i++) envList << (double)envValues[i];
    m["envValues"] = envList;

    m["doStates"]       = (int)doStates;
    m["diFeedback"]     = (int)diFeedback;
    m["diMod1"]         = (int)diMod1;
    m["diMod2"]         = (int)diMod2;
    m["estop"]          = estop;
    m["protectionByte"] = (int)protectionByte;

    m["dailyRuntimeSec"] = dailyRuntimeSec;
    m["isFault"]         = isFault;
    m["isOnline"]        = isOnline;
    m["missedHeartbeats"]= missedHeartbeats;
    m["lastUpdateTime"]  = lastUpdateTime.toString(Qt::ISODate);

    // 运行状态文字
    static const char* stateNames[] = {"停止","预警","运行","故障","松闸","停车中"};
    m["runStateText"] = (runState >= 0 && runState <= 5)
                        ? QString::fromUtf8(stateNames[runState]) : "未知";
    return m;
}

// ========== 构造 / 析构 ==========

CentralizedControlManager::CentralizedControlManager(QObject *parent)
    : QObject(parent)
    , m_localDeviceId(1)
    , m_stationRole("standalone")
    , m_stationId(1)
    , m_mqttBrokerPort(1883)
    , m_mqttQos(1)
    , m_mqttKeepAlive(60)
    , m_mqttTopicPrefix("belt/central/")
    , m_roleManager(nullptr)
    , m_mqttController(nullptr)
    , m_commonControl(nullptr)
    , m_systemConfig(nullptr)
    , m_protectionMonitor(nullptr)
    , m_protectionLogicController(nullptr)
    , m_tcpDataAdapter(nullptr)
    , m_runtimeTracker(nullptr)
    , m_heartbeatSeq(0)
    , m_mqttSubscribed(false)
{
    // ✅ 2026-04-14 [Phase 7.48.88.138]: 改用 DataPathConfig 统一数据目录（/app/appdata/）
    // 旧：QSettings("BeltControl", "CentralizedControl") → 保存到 ~/.config/，容器重新部署后配置丢失
    // 参考 DeviceRoleManager.cpp Phase 7.48.88.18 的同类修复
    QString configDir = DataPathConfig::getDataDirectory();
    QDir().mkpath(configDir);
    m_settings = new QSettings(configDir + "/centralized_control.ini",
                               QSettings::IniFormat, this);
    initSlots();
    initTimers();
    loadConfig();

    qDebug() << "[CentralizedControl] 初始化完成，角色=" << m_stationRole;
}

CentralizedControlManager::~CentralizedControlManager()
{
    exitMasterMode();
    exitSubStationMode();

    for (int i = 0; i < MAX_SLOTS; i++) {
        destroySlotControllers(i);
    }
}

// ========== 初始化 ==========

void CentralizedControlManager::initSlots()
{
    for (int i = 0; i < MAX_SLOTS; i++) {
        m_slots[i].enabled    = false;
        m_slots[i].protocol   = "mqtt";
        m_slots[i].port       = 1883;
        m_slots[i].isConnected = false;
        m_slots[i].statusText  = "未配置";
        m_slots[i].name        = QString("分站%1").arg(i + 1);

        m_slotStatus[i] = SubStationStatus();
        m_s7Clients[i]     = nullptr;
        m_modbusClients[i] = nullptr;
    }
}

void CentralizedControlManager::initTimers()
{
    // 500ms 轮询定时器（主站 S7/Modbus）
    m_pollTimer = new QTimer(this);
    m_pollTimer->setInterval(500);
    connect(m_pollTimer, &QTimer::timeout, this, [this]() {
        if (!isMasterMode()) return;
        for (int i = 0; i < MAX_SLOTS; i++) {
            if (!m_slots[i].enabled || !m_slots[i].isConnected) continue;
            const QString &proto = m_slots[i].protocol;
            if (proto == "s7")     pollS7SlotStatus(i);
            else if (proto == "modbus") pollModbusSlotStatus(i);
            // mqtt 分站通过订阅推送，不需要主动轮询
        }
    });

    // 3s 心跳定时器（主站/分站双向）
    m_heartbeatTimer = new QTimer(this);
    m_heartbeatTimer->setInterval(3000);
    connect(m_heartbeatTimer, &QTimer::timeout, this, [this]() {
        publishHeartbeat();
    });

    // 3s 健康检查定时器（主站）
    m_healthCheckTimer = new QTimer(this);
    m_healthCheckTimer->setInterval(3000);
    connect(m_healthCheckTimer, &QTimer::timeout, this, [this]() {
        checkConnectionHealth();
    });

    // 500ms 状态发布定时器（分站）
    m_statusPublishTimer = new QTimer(this);
    m_statusPublishTimer->setInterval(500);
    connect(m_statusPublishTimer, &QTimer::timeout, this, [this]() {
        if (isSubMode()) publishLocalStatus();
    });
}

// ========== 角色属性 setter ==========

void CentralizedControlManager::setLocalDeviceId(int id)
{
    if (m_localDeviceId == id) return;
    m_localDeviceId = id;
    emit localDeviceIdChanged();
}

void CentralizedControlManager::setStationRole(const QString &role)
{
    if (m_stationRole == role) return;

    // 退出旧模式
    if (m_stationRole == "master")     exitMasterMode();
    else if (m_stationRole == "sub")   exitSubStationMode();

    m_stationRole = role;
    emit stationRoleChanged();

    // 进入新模式
    if (role == "master")     enterMasterMode();
    else if (role == "sub")   enterSubStationMode();

    qDebug() << "[CentralizedControl] 角色切换 ->" << role;
}

void CentralizedControlManager::setStationId(int id)
{
    if (m_stationId == id) return;
    m_stationId = id;
    emit stationIdChanged();
}

// ========== MQTT集控配置 setter ==========

void CentralizedControlManager::setMqttBrokerIP(const QString &ip)
{
    if (m_mqttBrokerIP == ip) return;
    m_mqttBrokerIP = ip;
    emit mqttBrokerIPChanged();
}

void CentralizedControlManager::setMqttBrokerPort(int port)
{
    if (m_mqttBrokerPort == port) return;
    m_mqttBrokerPort = port;
    emit mqttBrokerPortChanged();
}

void CentralizedControlManager::setMqttClientId(const QString &id)
{
    if (m_mqttClientId == id) return;
    m_mqttClientId = id;
    emit mqttClientIdChanged();
}

void CentralizedControlManager::setMqttQos(int qos)
{
    if (m_mqttQos == qos) return;
    m_mqttQos = qos;
    emit mqttQosChanged();
}

void CentralizedControlManager::setMqttKeepAlive(int seconds)
{
    if (m_mqttKeepAlive == seconds) return;
    m_mqttKeepAlive = seconds;
    emit mqttKeepAliveChanged();
}

void CentralizedControlManager::setMqttTopicPrefix(const QString &prefix)
{
    if (m_mqttTopicPrefix == prefix) return;
    m_mqttTopicPrefix = prefix;
    emit mqttTopicPrefixChanged();
}

void CentralizedControlManager::setMqttUsername(const QString &username)
{
    if (m_mqttUsername == username) return;
    m_mqttUsername = username;
    emit mqttUsernameChanged();
}

void CentralizedControlManager::setMqttPassword(const QString &password)
{
    if (m_mqttPassword == password) return;
    m_mqttPassword = password;
    emit mqttPasswordChanged();
}

// ========== 分站槽位属性 ==========

QVariantList CentralizedControlManager::subStations() const
{
    QVariantList list;
    for (int i = 0; i < MAX_SLOTS; i++) {
        QVariantMap m;
        m["index"]       = i;
        m["name"]        = m_slots[i].name;
        m["enabled"]     = m_slots[i].enabled;
        m["protocol"]    = m_slots[i].protocol;
        m["targetIP"]    = m_slots[i].targetIP;
        m["port"]        = m_slots[i].port;
        m["isConnected"] = m_slots[i].isConnected;
        m["statusText"]  = m_slots[i].statusText;
        // ✅ 2026-04-14 [Phase 7.48.88.117]: Qt6移除了QMap::unite()，改用迭代器插入
        for (auto it = m_slots[i].protocolParams.cbegin(); it != m_slots[i].protocolParams.cend(); ++it)
            m.insert(it.key(), it.value());
        list << m;
    }
    return list;
}

int CentralizedControlManager::activeSlotCount() const
{
    int count = 0;
    for (int i = 0; i < MAX_SLOTS; i++)
        if (m_slots[i].enabled) count++;
    return count;
}

QVariantList CentralizedControlManager::slotStatuses() const
{
    QVariantList list;
    for (int i = 0; i < MAX_SLOTS; i++)
        list << m_slotStatus[i].toVariantMap();
    return list;
}

// ========== 槽位配置操作 ==========

void CentralizedControlManager::setSlotEnabled(int slotIndex, bool enabled)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;
    m_slots[slotIndex].enabled = enabled;
    if (!enabled) {
        disconnectSlot(slotIndex);
        m_slots[slotIndex].statusText = "未配置";
    }
    emit subStationsChanged();
    emit activeSlotCountChanged();
}

bool CentralizedControlManager::isSlotEnabled(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return false;
    return m_slots[slotIndex].enabled;
}

void CentralizedControlManager::setSlotProtocol(int slotIndex, const QString &protocol)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;
    if (m_slots[slotIndex].protocol == protocol) return;
    destroySlotControllers(slotIndex);
    m_slots[slotIndex].protocol = protocol;
    m_slots[slotIndex].port     = getDefaultPort(protocol);
    emit subStationsChanged();
}

QString CentralizedControlManager::getSlotProtocol(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return "mqtt";
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
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return {};
    QVariantMap m;
    m["index"]       = slotIndex;
    m["name"]        = m_slots[slotIndex].name;
    m["enabled"]     = m_slots[slotIndex].enabled;
    m["protocol"]    = m_slots[slotIndex].protocol;
    m["targetIP"]    = m_slots[slotIndex].targetIP;
    m["port"]        = m_slots[slotIndex].port;
    m["isConnected"] = m_slots[slotIndex].isConnected;
    m["statusText"]  = m_slots[slotIndex].statusText;
    // ✅ 2026-04-14 [Phase 7.48.88.117]: Qt6移除了QMap::unite()，改用迭代器插入
    for (auto it = m_slots[slotIndex].protocolParams.cbegin(); it != m_slots[slotIndex].protocolParams.cend(); ++it)
        m.insert(it.key(), it.value());
    return m;
}

QString CentralizedControlManager::getSlotStatusText(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return "无效";
    return m_slots[slotIndex].statusText;
}

QString CentralizedControlManager::getSlotName(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return "";
    return m_slots[slotIndex].name;
}

QVariantMap CentralizedControlManager::getSlotStatus(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return {};
    return m_slotStatus[slotIndex].toVariantMap();
}

// ========== 依赖注入 ==========

void CentralizedControlManager::setDeviceRoleManager(DeviceRoleManager *manager)
{
    m_roleManager = manager;
}

void CentralizedControlManager::setMQTTController(MQTTController *controller)
{
    if (m_mqttController == controller) return;

    // 断开旧连接
    if (m_mqttController) {
        disconnect(m_mqttController, nullptr, this, nullptr);
    }

    m_mqttController = controller;

    if (m_mqttController) {
        connect(m_mqttController, &MQTTController::messageReceived,
                this, [this](int /*moduleIndex*/, const QString &topic, const QByteArray &payload) {
            handleMqttMessage(topic, payload);
        });
    }
}

void CentralizedControlManager::setCommonControl(CommonControl *ctrl)
{
    m_commonControl = ctrl;
}

void CentralizedControlManager::setSystemConfig(SystemConfig *config)
{
    m_systemConfig = config;
}

void CentralizedControlManager::setMqttProtectionMonitor(MqttProtectionMonitor *monitor)
{
    m_protectionMonitor = monitor;
}

void CentralizedControlManager::setProtectionLogicController(ProtectionLogicController *ctrl)
{
    m_protectionLogicController = ctrl;
}

void CentralizedControlManager::setTCPDataAdapter(TCPDataAdapter *adapter)
{
    m_tcpDataAdapter = adapter;
}

void CentralizedControlManager::setDeviceRuntimeTracker(DeviceRuntimeTracker *tracker)
{
    m_runtimeTracker = tracker;
}

// ========== 数据持久化 ==========

void CentralizedControlManager::saveConfig()
{
    m_settings->beginGroup("Role");
    m_settings->setValue("localDeviceId", m_localDeviceId);
    m_settings->setValue("stationRole",   m_stationRole);
    m_settings->setValue("stationId",     m_stationId);
    m_settings->endGroup();

    m_settings->beginGroup("MQTT");
    m_settings->setValue("brokerIP",     m_mqttBrokerIP);
    m_settings->setValue("brokerPort",   m_mqttBrokerPort);
    m_settings->setValue("clientId",     m_mqttClientId);
    m_settings->setValue("qos",          m_mqttQos);
    m_settings->setValue("keepAlive",    m_mqttKeepAlive);
    m_settings->setValue("topicPrefix",  m_mqttTopicPrefix);
    m_settings->setValue("username",     m_mqttUsername);
    m_settings->setValue("password",     m_mqttPassword);
    m_settings->endGroup();

    for (int i = 0; i < MAX_SLOTS; i++) {
        m_settings->beginGroup(QString("Slot%1").arg(i));
        m_settings->setValue("enabled",   m_slots[i].enabled);
        m_settings->setValue("name",      m_slots[i].name);
        m_settings->setValue("protocol",  m_slots[i].protocol);
        m_settings->setValue("targetIP",  m_slots[i].targetIP);
        m_settings->setValue("port",      m_slots[i].port);
        // 协议特定参数
        for (auto it = m_slots[i].protocolParams.cbegin();
             it != m_slots[i].protocolParams.cend(); ++it) {
            m_settings->setValue("param_" + it.key(), it.value());
        }
        m_settings->endGroup();
    }
    qDebug() << "[CentralizedControl] 配置已保存";
}

void CentralizedControlManager::loadConfig()
{
    m_settings->beginGroup("Role");
    m_localDeviceId = m_settings->value("localDeviceId", 1).toInt();
    m_stationId     = m_settings->value("stationId",     1).toInt();
    // 角色不在 loadConfig 里直接切换，避免触发模式逻辑（由外部调用 setStationRole）
    m_stationRole   = m_settings->value("stationRole", "standalone").toString();
    m_settings->endGroup();

    m_settings->beginGroup("MQTT");
    m_mqttBrokerIP     = m_settings->value("brokerIP",    "").toString();
    m_mqttBrokerPort   = m_settings->value("brokerPort",  1883).toInt();
    m_mqttClientId     = m_settings->value("clientId",    "").toString();
    m_mqttQos          = m_settings->value("qos",         1).toInt();
    m_mqttKeepAlive    = m_settings->value("keepAlive",   60).toInt();
    m_mqttTopicPrefix  = m_settings->value("topicPrefix", "belt/central/").toString();
    m_mqttUsername     = m_settings->value("username",    "").toString();
    m_mqttPassword     = m_settings->value("password",    "").toString();
    m_settings->endGroup();

    for (int i = 0; i < MAX_SLOTS; i++) {
        m_settings->beginGroup(QString("Slot%1").arg(i));
        m_slots[i].enabled  = m_settings->value("enabled",  false).toBool();
        m_slots[i].name     = m_settings->value("name", QString("分站%1").arg(i+1)).toString();
        m_slots[i].protocol = m_settings->value("protocol", "mqtt").toString();
        m_slots[i].targetIP = m_settings->value("targetIP", "").toString();
        m_slots[i].port     = m_settings->value("port", getDefaultPort(m_slots[i].protocol)).toInt();

        // 读取协议特定参数（以 "param_" 为前缀）
        const QStringList keys = m_settings->childKeys();
        for (const QString &k : keys) {
            if (k.startsWith("param_"))
                m_slots[i].protocolParams[k.mid(6)] = m_settings->value(k);
        }
        m_settings->endGroup();
    }
}

void CentralizedControlManager::initSettings()
{
    // 已在构造函数通过 QSettings 构造完成，此处预留扩展
}

// ========== 辅助：默认端口 ==========

int CentralizedControlManager::getDefaultPort(const QString &protocol) const
{
    if (protocol == "s7")     return 102;
    if (protocol == "modbus") return 502;
    return 1883; // mqtt
}

int CentralizedControlManager::findSlotByDeviceId(int deviceId) const
{
    for (int i = 0; i < MAX_SLOTS; i++) {
        if (!m_slots[i].enabled) continue;
        // ✅ 2026-04-14 [Phase 7.48.88.142]: 修复key不匹配
        // QML保存用"targetDeviceId"，但这里读"deviceId"，导致永远找不到槽位
        // 同时兼容两种写法：先找"targetDeviceId"，再找"deviceId"（向后兼容）
        int slotDevId = m_slots[i].protocolParams.value("targetDeviceId", -1).toInt();
        if (slotDevId < 0)
            slotDevId = m_slots[i].protocolParams.value("deviceId", -1).toInt();
        if (slotDevId == deviceId) return i;
    }
    return -1;
}

// ========== 辅助：大端浮点转换（与 TCPDataAdapter::floatToBytes 对称）==========

float CentralizedControlManager::bytesToFloat(const QByteArray &data, int offset)
{
    if (offset + 4 > data.size()) return 0.0f;
    // S7/DB1 使用大端序 IEEE 754
    quint32 raw = (static_cast<quint8>(data[offset])     << 24)
                | (static_cast<quint8>(data[offset + 1]) << 16)
                | (static_cast<quint8>(data[offset + 2]) <<  8)
                |  static_cast<quint8>(data[offset + 3]);
    float val;
    memcpy(&val, &raw, 4);
    return val;
}

void CentralizedControlManager::floatToBytes(float value, QByteArray &data, int offset)
{
    if (offset + 4 > data.size()) return;
    quint32 raw;
    memcpy(&raw, &value, 4);
    data[offset]     = static_cast<char>((raw >> 24) & 0xFF);
    data[offset + 1] = static_cast<char>((raw >> 16) & 0xFF);
    data[offset + 2] = static_cast<char>((raw >>  8) & 0xFF);
    data[offset + 3] = static_cast<char>( raw        & 0xFF);
}

quint16 CentralizedControlManager::bytesToUint16(const QByteArray &data, int offset)
{
    if (offset + 2 > data.size()) return 0;
    return (static_cast<quint8>(data[offset]) << 8)
          | static_cast<quint8>(data[offset + 1]);
}

// ========== 槽位连接管理 ==========

bool CentralizedControlManager::connectSlot(int slotIndex)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return false;
    SubStationSlot &slot = m_slots[slotIndex];
    if (!slot.enabled || slot.targetIP.isEmpty()) {
        slot.statusText = "未配置";
        return false;
    }

    const QString &proto = slot.protocol;

    if (proto == "s7") {
        S7ClientController *client = getOrCreateS7Client(slotIndex);
        client->setTargetIP(slot.targetIP);
        client->setPort(slot.port > 0 ? slot.port : 102);
        int rack  = slot.protocolParams.value("rack",  0).toInt();
        int s7slot = slot.protocolParams.value("slot", 1).toInt();
        client->setRack(rack);
        client->setSlot(s7slot);
        bool ok = client->connectToPLC();
        slot.isConnected = ok;
        slot.statusText  = ok ? "已连接" : "连接失败";
        emit slotConnectionChanged(slotIndex, ok);
        emit subStationsChanged();
        return ok;

    } else if (proto == "modbus") {
        ModbusTCPMasterController *client = getOrCreateModbusClient(slotIndex);
        client->setTargetIP(slot.targetIP);
        client->setPort(slot.port > 0 ? slot.port : 502);
        int slaveAddr = slot.protocolParams.value("slaveAddress", 1).toInt();
        client->setSlaveAddress(slaveAddr);
        bool ok = client->connectToServer();
        slot.isConnected = ok;
        slot.statusText  = ok ? "已连接" : "连接失败";
        emit slotConnectionChanged(slotIndex, ok);
        emit subStationsChanged();
        return ok;

    } else if (proto == "mqtt") {
        // MQTT 分站：通过订阅 topic 感知在线，连接在 setupMqttSubscriptions 里完成
        slot.isConnected = m_mqttController
                           && m_mqttController->isModuleConnected(CENTRAL_MQTT_MODULE);
        slot.statusText  = slot.isConnected ? "已订阅" : "等待MQTT";
        emit slotConnectionChanged(slotIndex, slot.isConnected);
        emit subStationsChanged();
        return slot.isConnected;
    }

    return false;
}

void CentralizedControlManager::disconnectSlot(int slotIndex)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;
    SubStationSlot &slot = m_slots[slotIndex];

    if (slot.protocol == "s7" && m_s7Clients[slotIndex])
        m_s7Clients[slotIndex]->disconnectFromPLC();
    else if (slot.protocol == "modbus" && m_modbusClients[slotIndex])
        m_modbusClients[slotIndex]->disconnectFromServer();

    slot.isConnected = false;
    slot.statusText  = "已断开";
    m_slotStatus[slotIndex].isOnline = false;
    emit slotConnectionChanged(slotIndex, false);
    emit slotOnlineChanged(slotIndex, false);
    emit subStationsChanged();
}

bool CentralizedControlManager::isSlotConnected(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return false;
    return m_slots[slotIndex].isConnected;
}

void CentralizedControlManager::connectAllSlots()
{
    for (int i = 0; i < MAX_SLOTS; i++) {
        if (m_slots[i].enabled) connectSlot(i);
    }
}

void CentralizedControlManager::disconnectAllSlots()
{
    for (int i = 0; i < MAX_SLOTS; i++) {
        disconnectSlot(i);
    }
}

// ========== 按需创建 / 销毁协议控制器 ==========

S7ClientController *CentralizedControlManager::getOrCreateS7Client(int slotIndex)
{
    if (!m_s7Clients[slotIndex]) {
        m_s7Clients[slotIndex] = new S7ClientController(this);
        // 连接状态变化信号
        connect(m_s7Clients[slotIndex], &S7ClientController::isConnectedChanged,
                this, [this, slotIndex]() {
            bool connected = m_s7Clients[slotIndex]->isConnected();
            m_slots[slotIndex].isConnected = connected;
            m_slots[slotIndex].statusText  = connected ? "已连接" : "已断开";
            if (!connected) {
                m_slotStatus[slotIndex].isOnline = false;
                emit slotOnlineChanged(slotIndex, false);
            }
            emit slotConnectionChanged(slotIndex, connected);
            emit subStationsChanged();
        });
    }
    return m_s7Clients[slotIndex];
}

ModbusTCPMasterController *CentralizedControlManager::getOrCreateModbusClient(int slotIndex)
{
    if (!m_modbusClients[slotIndex]) {
        m_modbusClients[slotIndex] = new ModbusTCPMasterController(this);
        connect(m_modbusClients[slotIndex], &ModbusTCPMasterController::isConnectedChanged,
                this, [this, slotIndex]() {
            bool connected = m_modbusClients[slotIndex]->isConnected();
            m_slots[slotIndex].isConnected = connected;
            m_slots[slotIndex].statusText  = connected ? "已连接" : "已断开";
            if (!connected) {
                m_slotStatus[slotIndex].isOnline = false;
                emit slotOnlineChanged(slotIndex, false);
            }
            emit slotConnectionChanged(slotIndex, connected);
            emit subStationsChanged();
        });
        // Modbus 读取结果信号
        connect(m_modbusClients[slotIndex], &ModbusTCPMasterController::discreteInputsRead,
                this, [this, slotIndex](int /*start*/, const QList<bool> &values) {
            parseModbusDiscreteInputs(slotIndex, values);
        });
        connect(m_modbusClients[slotIndex], &ModbusTCPMasterController::inputRegistersRead,
                this, [this, slotIndex](int /*start*/, const QList<int> &values) {
            parseModbusInputRegisters(slotIndex, values);
        });
    }
    return m_modbusClients[slotIndex];
}

void CentralizedControlManager::destroySlotControllers(int slotIndex)
{
    if (m_s7Clients[slotIndex]) {
        m_s7Clients[slotIndex]->disconnectFromPLC();
        m_s7Clients[slotIndex]->deleteLater();
        m_s7Clients[slotIndex] = nullptr;
    }
    if (m_modbusClients[slotIndex]) {
        m_modbusClients[slotIndex]->disconnectFromServer();
        m_modbusClients[slotIndex]->deleteLater();
        m_modbusClients[slotIndex] = nullptr;
    }
}

// ========== S7 数据处理（Phase 7.48.88.112）==========

void CentralizedControlManager::pollS7SlotStatus(int slotIndex)
{
    S7ClientController *client = m_s7Clients[slotIndex];
    if (!client || !client->isConnected()) return;

    // 读取 DB1（状态区，640 bytes）
    QByteArray db1;
    if (client->readDB(1, 0, 640, db1)) {
        parseS7DB1(slotIndex, db1);
    } else {
        qWarning() << "[CentralizedControl] 槽位" << slotIndex << "DB1读取失败";
    }
}

void CentralizedControlManager::parseS7DB1(int slotIndex, const QByteArray &db1Data)
{
    if (db1Data.size() < 92) {
        qWarning() << "[CentralizedControl] 槽位" << slotIndex << "DB1数据不足";
        return;
    }

    SubStationStatus &st = m_slotStatus[slotIndex];

    // --- 开关量区 (Byte 0-9) ---
    st.doStates   = static_cast<quint8>(db1Data[0]);
    st.diFeedback = static_cast<quint8>(db1Data[1]);
    st.diMod1     = static_cast<quint8>(db1Data[2]);
    st.diMod2     = static_cast<quint8>(db1Data[3]);
    st.estop      = static_cast<quint8>(db1Data[4]) != 0;

    // Byte 5: 电机运行位图
    st.motorRunningByte = static_cast<quint8>(db1Data[5]);
    for (int i = 0; i < 8; i++)
        st.motorStates[i] = (st.motorRunningByte >> i) & 0x01;

    // Byte 9: 保护汇总字节
    st.protectionByte = static_cast<quint8>(db1Data[9]);

    // 从保护字节推断运行状态
    bool anyProt = (st.protectionByte != 0);
    if (anyProt) {
        st.runState = 3;   // 故障
        st.isFault  = true;
    } else if (st.motorRunningByte != 0) {
        st.runState = 2;   // 运行
        st.isFault  = false;
    } else {
        st.runState = 0;   // 停止
        st.isFault  = false;
    }

    // --- 基本浮点区 (Byte 44-91) ---
    if (db1Data.size() >= 92) {
        st.speed     = bytesToFloat(db1Data, 44);
        st.tension   = bytesToFloat(db1Data, 48);
        st.m1Current = bytesToFloat(db1Data, 52);
        st.m2Current = bytesToFloat(db1Data, 56);
        st.m1Voltage = bytesToFloat(db1Data, 60);
        st.m2Voltage = bytesToFloat(db1Data, 64);
        st.m1XVib    = bytesToFloat(db1Data, 68);
        st.m1YVib    = bytesToFloat(db1Data, 72);
        st.m2XVib    = bytesToFloat(db1Data, 76);
        st.m2YVib    = bytesToFloat(db1Data, 80);
        st.m1Temp    = bytesToFloat(db1Data, 84);
        st.m2Temp    = bytesToFloat(db1Data, 88);
    }

    // --- 环境模拟量区 (Byte 140-203, 16×FLOAT32) ---
    static const int S7_DB1_ENV_START = 140;
    if (db1Data.size() >= S7_DB1_ENV_START + 64) {
        for (int i = 0; i < 16; i++)
            st.envValues[i] = bytesToFloat(db1Data, S7_DB1_ENV_START + i * 4);
    }

    // 更新时间戳 & 在线状态
    st.lastUpdateTime    = QDateTime::currentDateTime();
    st.missedHeartbeats  = 0;
    if (!st.isOnline) handleSlotOnline(slotIndex);

    emit slotStatusUpdated(slotIndex);
    emit slotStatusesChanged();
}

// ========== S7 控制命令（写 DB2）==========

QByteArray CentralizedControlManager::buildS7DB2Command(int beltNumber, quint8 beltCtrl,
                                                          quint8 motorStart, quint8 motorStop,
                                                          quint8 resetCmd)
{
    // DB2 布局（64 bytes）：
    //   Byte 0  : DO输出控制
    //   Byte 1  : 皮带控制 (bit0=启动, bit1=停止, bit2=急停)
    //   Byte 6  : 电机启动位图
    //   Byte 7  : 电机停止位图
    //   Byte 10 : 复位命令 (bit0=保护, bit2=故障)
    //   Byte 11 : 目标皮带编号
    QByteArray db2(64, 0);
    db2[1]  = static_cast<char>(beltCtrl);
    db2[6]  = static_cast<char>(motorStart);
    db2[7]  = static_cast<char>(motorStop);
    db2[10] = static_cast<char>(resetCmd);
    db2[11] = static_cast<char>(beltNumber & 0xFF);
    return db2;
}

void CentralizedControlManager::sendS7Command(int slotIndex, const QByteArray &db2Data)
{
    S7ClientController *client = m_s7Clients[slotIndex];
    if (!client || !client->isConnected()) {
        qWarning() << "[CentralizedControl] 槽位" << slotIndex << "S7未连接，命令丢弃";
        return;
    }
    bool ok = client->writeDB(2, 0, db2Data);
    if (!ok)
        qWarning() << "[CentralizedControl] 槽位" << slotIndex << "DB2写入失败";
}

// ========== Modbus 数据处理（Phase 7.48.88.113）==========
// 寄存器映射（复用 TCPDataAdapter 常量）：
//   Discrete Inputs 0-66  : DI状态、电机状态、保护位
//   Input Registers 0-119 : AI原始值 + 速度/张力/电流/温度 (FLOAT32, 两寄存器一个值)
//   Coils 8-10            : 皮带启动(8)/停止(9)/急停(10)
//   Holding Registers 20  : 目标皮带编号

void CentralizedControlManager::pollModbusSlotStatus(int slotIndex)
{
    ModbusTCPMasterController *client = m_modbusClients[slotIndex];
    if (!client || !client->isConnected()) return;

    // 读取离散输入 0-66（DI + 电机 + 保护）
    client->readDiscreteInputs(0, 67);

    // 读取输入寄存器 0-119（AI原始值 + 浮点参数）
    client->readInputRegisters(0, 120);
}

void CentralizedControlManager::parseModbusDiscreteInputs(int slotIndex, const QList<bool> &values)
{
    // Modbus Discrete Inputs 布局（与 TCPDataAdapter Modbus从站一致）：
    //   DI 0-7   : DO输出反馈 (bit0-7)
    //   DI 8-15  : DI反馈 (bit0-7)
    //   DI 16-23 : DI模块1 (急停/拉绳/跑偏/撕裂/烟雾/温度/护网/堆煤)
    //   DI 24-31 : DI模块2
    //   DI 32    : 主急停
    //   DI 40-47 : 电机运行位图 (motor1-8)
    //   DI 56-63 : 保护汇总位 (bit0=急停..bit7=主急停)

    if (values.size() < 64) return;

    SubStationStatus &st = m_slotStatus[slotIndex];

    // DO输出反馈 (DI 0-7)
    quint8 doByte = 0;
    for (int i = 0; i < 8 && i < values.size(); i++)
        if (values[i]) doByte |= (1 << i);
    st.doStates = doByte;

    // DI反馈 (DI 8-15)
    quint8 fbByte = 0;
    for (int i = 0; i < 8 && (8 + i) < values.size(); i++)
        if (values[8 + i]) fbByte |= (1 << i);
    st.diFeedback = fbByte;

    // DI模块1 (DI 16-23)
    quint8 mod1 = 0;
    for (int i = 0; i < 8 && (16 + i) < values.size(); i++)
        if (values[16 + i]) mod1 |= (1 << i);
    st.diMod1 = mod1;

    // DI模块2 (DI 24-31)
    quint8 mod2 = 0;
    for (int i = 0; i < 8 && (24 + i) < values.size(); i++)
        if (values[24 + i]) mod2 |= (1 << i);
    st.diMod2 = mod2;

    // 主急停 (DI 32)
    st.estop = (values.size() > 32) && values[32];

    // 电机运行位图 (DI 40-47)
    quint8 motorByte = 0;
    for (int i = 0; i < 8 && (40 + i) < values.size(); i++)
        if (values[40 + i]) motorByte |= (1 << i);
    st.motorRunningByte = motorByte;
    for (int i = 0; i < 8; i++)
        st.motorStates[i] = (motorByte >> i) & 0x01;

    // 保护汇总 (DI 56-63)
    quint8 protByte = 0;
    for (int i = 0; i < 8 && (56 + i) < values.size(); i++)
        if (values[56 + i]) protByte |= (1 << i);
    st.protectionByte = protByte;

    // 推断运行状态
    if (protByte != 0) {
        st.runState = 3;  // 故障
        st.isFault  = true;
    } else if (motorByte != 0) {
        st.runState = 2;  // 运行
        st.isFault  = false;
    } else {
        st.runState = 0;  // 停止
        st.isFault  = false;
    }

    st.lastUpdateTime   = QDateTime::currentDateTime();
    st.missedHeartbeats = 0;
    if (!st.isOnline) handleSlotOnline(slotIndex);

    emit slotStatusUpdated(slotIndex);
    emit slotStatusesChanged();
}

void CentralizedControlManager::parseModbusInputRegisters(int slotIndex, const QList<int> &values)
{
    // Input Registers 布局（每个 FLOAT32 占两个寄存器，大端高字在前）：
    //   IR 0-1   : 速度 (m/s)
    //   IR 2-3   : 张力
    //   IR 4-5   : 电机1电流
    //   IR 6-7   : 电机2电流
    //   IR 8-9   : 电机1电压
    //   IR 10-11 : 电机2电压
    //   IR 12-13 : 电机1X振动
    //   IR 14-15 : 电机1Y振动
    //   IR 16-17 : 电机2X振动
    //   IR 18-19 : 电机2Y振动
    //   IR 20-21 : 电机1温度
    //   IR 22-23 : 电机2温度
    //   IR 62-93 : 16个环境模拟量 (每个2寄存器)

    if (values.size() < 24) return;

    SubStationStatus &st = m_slotStatus[slotIndex];

    // 两个 uint16 → float（大端）
    auto toFloat = [&](int regIdx) -> float {
        if (regIdx + 1 >= values.size()) return 0.0f;
        quint32 raw = ((quint32)(quint16)values[regIdx] << 16)
                    |  (quint32)(quint16)values[regIdx + 1];
        float val;
        memcpy(&val, &raw, 4);
        return val;
    };

    st.speed     = toFloat(0);
    st.tension   = toFloat(2);
    st.m1Current = toFloat(4);
    st.m2Current = toFloat(6);
    st.m1Voltage = toFloat(8);
    st.m2Voltage = toFloat(10);
    st.m1XVib    = toFloat(12);
    st.m1YVib    = toFloat(14);
    st.m2XVib    = toFloat(16);
    st.m2YVib    = toFloat(18);
    st.m1Temp    = toFloat(20);
    st.m2Temp    = toFloat(22);

    // 16个环境模拟量 (IR 62-93)
    if (values.size() >= 94) {
        for (int i = 0; i < 16; i++)
            st.envValues[i] = toFloat(62 + i * 2);
    }

    emit slotStatusUpdated(slotIndex);
    emit slotStatusesChanged();
}

void CentralizedControlManager::sendModbusCommand(int slotIndex, int coilAddress, bool value)
{
    ModbusTCPMasterController *client = m_modbusClients[slotIndex];
    if (!client || !client->isConnected()) {
        qWarning() << "[CentralizedControl] 槽位" << slotIndex << "Modbus未连接，命令丢弃";
        return;
    }
    client->writeCoil(coilAddress, value);
}

void CentralizedControlManager::sendModbusRegister(int slotIndex, int address, int value)
{
    ModbusTCPMasterController *client = m_modbusClients[slotIndex];
    if (!client || !client->isConnected()) return;
    client->writeHoldingRegister(address, value);
}

// ========== MQTT 数据处理（Phase 7.48.88.114）==========

void CentralizedControlManager::setupMqttSubscriptions()
{
    if (!m_mqttController || m_mqttSubscribed) return;
    if (!m_mqttController->isModuleConnected(CENTRAL_MQTT_MODULE)) return;

    const QString &prefix = m_mqttTopicPrefix;

    if (isMasterMode()) {
        // 主站订阅所有分站的状态/心跳/报警
        m_mqttController->subscribe(prefix + "+/status",    m_mqttQos, CENTRAL_MQTT_MODULE);
        m_mqttController->subscribe(prefix + "+/heartbeat", 0,         CENTRAL_MQTT_MODULE);
        m_mqttController->subscribe(prefix + "+/alarm",     m_mqttQos, CENTRAL_MQTT_MODULE);
    } else if (isSubMode()) {
        // 分站订阅主站下发的命令（含广播）
        QString localId = QString::number(m_localDeviceId);
        m_mqttController->subscribe(prefix + localId + "/command", m_mqttQos, CENTRAL_MQTT_MODULE);
        m_mqttController->subscribe(prefix + "broadcast/command",  m_mqttQos, CENTRAL_MQTT_MODULE);
    }

    m_mqttSubscribed = true;
    qDebug() << "[CentralizedControl] MQTT订阅完成，前缀=" << prefix;
}

void CentralizedControlManager::teardownMqttSubscriptions()
{
    if (!m_mqttController || !m_mqttSubscribed) return;

    const QString &prefix = m_mqttTopicPrefix;
    m_mqttController->unsubscribe(prefix + "+/status",    CENTRAL_MQTT_MODULE);
    m_mqttController->unsubscribe(prefix + "+/heartbeat", CENTRAL_MQTT_MODULE);
    m_mqttController->unsubscribe(prefix + "+/alarm",     CENTRAL_MQTT_MODULE);

    QString localId = QString::number(m_localDeviceId);
    m_mqttController->unsubscribe(prefix + localId + "/command", CENTRAL_MQTT_MODULE);
    m_mqttController->unsubscribe(prefix + "broadcast/command",  CENTRAL_MQTT_MODULE);

    m_mqttSubscribed = false;
}

void CentralizedControlManager::handleMqttMessage(const QString &topic, const QByteArray &payload)
{
    const QString &prefix = m_mqttTopicPrefix;
    if (!topic.startsWith(prefix)) return;

    // 去掉前缀，剩余格式：{deviceId}/{type}  或  broadcast/{type}
    QString remainder = topic.mid(prefix.length());
    int slashPos = remainder.indexOf('/');
    if (slashPos < 0) return;

    QString idStr   = remainder.left(slashPos);
    QString msgType = remainder.mid(slashPos + 1);

    if (isSubMode()) {
        // 分站只处理 command
        if (msgType == "command") {
            handleRemoteCommand(payload);
        }
        return;
    }

    // 主站：根据 deviceId 找对应槽位
    if (idStr == "broadcast") return; // 主站忽略广播

    bool ok;
    int deviceId = idStr.toInt(&ok);
    if (!ok) return;

    int slotIndex = findSlotByDeviceId(deviceId);
    if (slotIndex < 0) return;  // 未配置的分站，忽略

    if (msgType == "status") {
        handleMqttStatusMessage(slotIndex, payload);
    } else if (msgType == "heartbeat") {
        handleMqttHeartbeat(slotIndex, payload);
    } else if (msgType == "alarm") {
        handleMqttAlarm(slotIndex, payload);
    }
}

void CentralizedControlManager::handleMqttStatusMessage(int slotIndex, const QByteArray &payload)
{
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(payload, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return;

    QJsonObject obj = doc.object();
    SubStationStatus &st = m_slotStatus[slotIndex];

    // --- run ---
    if (obj.contains("run")) {
        QJsonObject run = obj["run"].toObject();
        st.runState  = run["state"].toInt(0);
        st.faultCode = run["faultCode"].toInt(0);
        st.isFault   = (st.runState == 3);
    }

    // --- motor ---
    if (obj.contains("motor")) {
        QJsonObject motor = obj["motor"].toObject();
        st.motorRunningByte = static_cast<quint8>(motor["byte"].toInt(0));
        QJsonArray states   = motor["states"].toArray();
        for (int i = 0; i < 8 && i < states.size(); i++)
            st.motorStates[i] = states[i].toBool();
    }

    // --- analog ---
    if (obj.contains("analog")) {
        QJsonObject an = obj["analog"].toObject();
        st.speed     = static_cast<float>(an["speed"].toDouble());
        st.tension   = static_cast<float>(an["tension"].toDouble());
        st.m1Current = static_cast<float>(an["m1Current"].toDouble());
        st.m2Current = static_cast<float>(an["m2Current"].toDouble());
        st.m1Voltage = static_cast<float>(an["m1Voltage"].toDouble());
        st.m2Voltage = static_cast<float>(an["m2Voltage"].toDouble());
        st.m1Temp    = static_cast<float>(an["m1Temp"].toDouble());
        st.m2Temp    = static_cast<float>(an["m2Temp"].toDouble());
    }

    // --- di ---
    if (obj.contains("di")) {
        QJsonObject di = obj["di"].toObject();
        st.doStates       = static_cast<quint8>(di["doStates"].toInt());
        st.diFeedback     = static_cast<quint8>(di["diFeedback"].toInt());
        st.diMod1         = static_cast<quint8>(di["diMod1"].toInt());
        st.diMod2         = static_cast<quint8>(di["diMod2"].toInt());
        st.protectionByte = static_cast<quint8>(di["protByte"].toInt());
        st.estop          = (st.protectionByte & 0x01) != 0;
    }

    // --- runtime ---
    if (obj.contains("runtime")) {
        QJsonObject rt   = obj["runtime"].toObject();
        st.dailyRuntimeSec = rt["dailySec"].toInt(0);
        st.isFault         = rt["isFault"].toBool(false);
    }

    // 更新时间戳 & 在线状态
    st.lastUpdateTime   = QDateTime::currentDateTime();
    st.missedHeartbeats = 0;
    if (!st.isOnline) handleSlotOnline(slotIndex);

    emit slotStatusUpdated(slotIndex);
    emit slotStatusesChanged();
}

void CentralizedControlManager::handleMqttHeartbeat(int slotIndex, const QByteArray &payload)
{
    QJsonDocument doc = QJsonDocument::fromJson(payload);
    if (!doc.isObject()) return;

    SubStationStatus &st    = m_slotStatus[slotIndex];
    st.lastUpdateTime       = QDateTime::currentDateTime();
    st.missedHeartbeats     = 0;
    if (!st.isOnline) handleSlotOnline(slotIndex);
}

void CentralizedControlManager::handleMqttAlarm(int slotIndex, const QByteArray &payload)
{
    QJsonDocument doc = QJsonDocument::fromJson(payload);
    if (!doc.isObject()) return;

    QJsonObject obj   = doc.object();
    QString alarmType = obj["type"].toString();
    QString name      = obj["name"].toString();
    emit remoteAlarmReceived(slotIndex, alarmType, name);
    qWarning() << "[CentralizedControl] 分站" << slotIndex
               << "报警:" << alarmType << name;
}

void CentralizedControlManager::publishMqttCommand(int slotIndex,
                                                    const QString &cmd,
                                                    const QJsonObject &params)
{
    if (!m_mqttController) return;
    if (!m_mqttController->isModuleConnected(CENTRAL_MQTT_MODULE)) return;

    int deviceId = m_slots[slotIndex].protocolParams.value("targetDeviceId", -1).toInt();
    if (deviceId < 0)
        deviceId = m_slots[slotIndex].protocolParams.value("deviceId", -1).toInt();
    if (deviceId < 0) {
        qWarning() << "[CentralizedControl] 槽位" << slotIndex << "未配置targetDeviceId/deviceId";
        return;
    }

    QJsonObject msg;
    msg["ver"] = 1;
    msg["ts"]  = QDateTime::currentMSecsSinceEpoch();
    msg["cmd"] = cmd;
    msg["params"] = params;
    msg["seq"] = ++m_heartbeatSeq;

    QString topic = m_mqttTopicPrefix + QString::number(deviceId) + "/command";
    QByteArray payload = QJsonDocument(msg).toJson(QJsonDocument::Compact);
    bool ok = m_mqttController->publishBytes(topic, payload, m_mqttQos, false, CENTRAL_MQTT_MODULE);
    emit commandSent(slotIndex, cmd, ok);
}

// ========== 心跳发布 ==========

void CentralizedControlManager::publishHeartbeat()
{
    if (!m_mqttController) return;
    if (!m_mqttController->isModuleConnected(CENTRAL_MQTT_MODULE)) return;

    QJsonObject hb;
    hb["deviceId"] = m_localDeviceId;
    hb["role"]     = m_stationRole;
    hb["ts"]       = QDateTime::currentMSecsSinceEpoch();
    hb["seq"]      = ++m_heartbeatSeq;

    QByteArray payload = QJsonDocument(hb).toJson(QJsonDocument::Compact);
    QString topic;

    if (isMasterMode()) {
        // 主站心跳发到所有已配置分站
        for (int i = 0; i < MAX_SLOTS; i++) {
            if (!m_slots[i].enabled || m_slots[i].protocol != "mqtt") continue;
            int devId = m_slots[i].protocolParams.value("targetDeviceId", -1).toInt();
            if (devId < 0)
                devId = m_slots[i].protocolParams.value("deviceId", -1).toInt();
            if (devId < 0) continue;
            topic = m_mqttTopicPrefix + QString::number(devId) + "/heartbeat";
            m_mqttController->publishBytes(topic, payload, 0, false, CENTRAL_MQTT_MODULE);
        }
    } else if (isSubMode()) {
        // ✅ 2026-04-14 [Phase 7.48.88.143]: 分站模式心跳 + 模块7断线自动重连
        // 场景：分站先启动，主站 Mosquitto 未就绪 → 模块7连接失败 → 无自动重连
        // 每次心跳检查模块7是否在线，断线则重新设置Broker并连接
        if (m_mqttController && !m_mqttController->isModuleConnected(CENTRAL_MQTT_MODULE)) {
            if (!m_mqttBrokerIP.isEmpty()) {
                // 确保模块7 Broker 指向主站
                int oldIdx = m_mqttController->currentModuleIndex();
                m_mqttController->setCurrentModuleIndex(CENTRAL_MQTT_MODULE);
                m_mqttController->setBrokerHost(m_mqttBrokerIP);
                if (m_mqttBrokerPort > 0)
                    m_mqttController->setBrokerPort(m_mqttBrokerPort);
                m_mqttController->setCurrentModuleIndex(oldIdx);
                m_mqttController->connectToModule(CENTRAL_MQTT_MODULE);
                qDebug() << "[CentralizedControl] 分站心跳：模块7断线，重连到" << m_mqttBrokerIP;
            }
        } else {
            // 模块7已连接，正常发送心跳
            topic = m_mqttTopicPrefix + QString::number(m_localDeviceId) + "/heartbeat";
            m_mqttController->publishBytes(topic, payload, 0, false, CENTRAL_MQTT_MODULE);
        }
    }

// ========== 分站被动模式：发布本地状态（Phase 7.48.88.114）==========

void CentralizedControlManager::publishLocalStatus()
{
    if (!m_mqttController || !isSubMode()) return;
    if (!m_mqttController->isModuleConnected(CENTRAL_MQTT_MODULE)) return;
    if (!m_systemConfig) return;

    // 收集本地数据（从 SystemConfig 属性读取，与 TCPDataAdapter::syncS7DB1 一致）
    QJsonObject run;
    int runState = 0;
    bool isFault = m_systemConfig->property("isFault").toBool();
    bool isRunning = false;
    if (m_commonControl) {
        // 检查任意皮带在运行
        for (int b = 1; b <= 8; b++) {
            if (m_commonControl->isBeltRunning(b)) { isRunning = true; break; }
        }
    }
    if (isFault)      runState = 3;
    else if (isRunning) runState = 2;

    run["state"]     = runState;
    run["faultCode"] = m_systemConfig->property("faultCode").toInt();

    // 电机运行位图
    quint8 motorByte = 0;
    if (m_commonControl) {
        for (int i = 0; i < 8; i++)
            if (m_commonControl->isBeltRunning(i + 1)) motorByte |= (1 << i);
    }
    QJsonArray motorStatesArr;
    for (int i = 0; i < 8; i++) motorStatesArr.append((motorByte >> i) & 0x01 ? true : false);

    QJsonObject motor;
    motor["byte"]   = motorByte;
    motor["states"] = motorStatesArr;

    // 模拟量
    QJsonObject analog;
    analog["speed"]     = m_systemConfig->property("speedValue").toDouble();
    analog["tension"]   = m_systemConfig->property("tensionValue").toDouble();
    analog["m1Current"] = m_systemConfig->property("motor1CurrentValue").toDouble();
    analog["m2Current"] = m_systemConfig->property("motor2CurrentValue").toDouble();
    analog["m1Voltage"] = m_systemConfig->property("motor1VoltageValue").toDouble();
    analog["m2Voltage"] = m_systemConfig->property("motor2VoltageValue").toDouble();
    analog["m1Temp"]    = m_systemConfig->property("motor1TemperatureValue").toDouble();
    analog["m2Temp"]    = m_systemConfig->property("motor2TemperatureValue").toDouble();

    // 开关量 + 保护
    quint8 protByte = 0;
    if (m_systemConfig) {
        if (m_systemConfig->property("emergencyStopActive").toBool())    protByte |= (1 << 0);
        // ✅ 2026-04-14 [Phase 7.48.88.143]: 修复属性名 deviationActive→runOffActive, temperatureProtActive→temperatureActive
        if (m_systemConfig->property("runOffActive").toBool())           protByte |= (1 << 1);
        if (m_systemConfig->property("tearActive").toBool())             protByte |= (1 << 2);
        if (m_systemConfig->property("smokeActive").toBool())            protByte |= (1 << 3);
        if (m_systemConfig->property("temperatureActive").toBool())      protByte |= (1 << 4);
        if (m_systemConfig->property("guardNetActive").toBool())         protByte |= (1 << 5);
        if (m_systemConfig->property("coalPileActive").toBool())         protByte |= (1 << 6);
        if (m_systemConfig->property("mainEmergencyStopActive").toBool())protByte |= (1 << 7);
    }
    QJsonObject di;
    di["doStates"]  = 0;
    di["diFeedback"]= 0;
    di["diMod1"]    = 0;
    di["diMod2"]    = 0;
    di["protByte"]  = protByte;

    QJsonObject runtime;
    runtime["dailySec"] = 0;  // 运行时间由 DeviceRuntimeTracker 提供（后续集成）
    runtime["isFault"]  = isFault;

    // 组装完整消息
    QJsonObject msg;
    msg["ver"]       = 1;
    msg["ts"]        = QDateTime::currentMSecsSinceEpoch();
    msg["deviceId"]  = m_localDeviceId;
    msg["stationId"] = m_stationId;
    msg["run"]       = run;
    msg["motor"]     = motor;
    msg["analog"]    = analog;
    msg["di"]        = di;
    msg["runtime"]   = runtime;

    QString topic   = m_mqttTopicPrefix + QString::number(m_localDeviceId) + "/status";
    QByteArray data = QJsonDocument(msg).toJson(QJsonDocument::Compact);
    m_mqttController->publishBytes(topic, data, m_mqttQos, false, CENTRAL_MQTT_MODULE);
}

// ========== 分站被动模式：处理主站命令 ==========

void CentralizedControlManager::handleRemoteCommand(const QByteArray &payload)
{
    if (!m_commonControl) return;

    QJsonDocument doc = QJsonDocument::fromJson(payload);
    if (!doc.isObject()) return;

    QJsonObject obj    = doc.object();
    QString cmd        = obj["cmd"].toString();
    QJsonObject params = obj["params"].toObject();
    int beltNumber     = params["beltNumber"].toInt(1);
    int motorIndex     = params["motorIndex"].toInt(0);

    qDebug() << "[CentralizedControl] 收到远程命令:" << cmd
             << "皮带=" << beltNumber;

    if (cmd == "start_belt") {
        m_commonControl->startBelt(beltNumber);
    } else if (cmd == "stop_belt") {
        m_commonControl->stopBelt(beltNumber);
    } else if (cmd == "emergency_stop") {
        m_commonControl->emergencyStopBelt(beltNumber);
    } else if (cmd == "motor_start") {
        // CommonControl 目前通过皮带编号控制，motorIndex 预留
        m_commonControl->startBelt(beltNumber);
    } else if (cmd == "motor_stop") {
        m_commonControl->stopBelt(beltNumber);
    } else if (cmd == "reset_protection") {
        if (m_systemConfig)
            m_systemConfig->setProperty("resetProtection", true);
    } else if (cmd == "reset_fault") {
        if (m_systemConfig)
            m_systemConfig->setProperty("resetFault", true);
    } else {
        qWarning() << "[CentralizedControl] 未知命令:" << cmd;
    }

    Q_UNUSED(motorIndex)
}

// ========== 连接健康监测（Phase 7.48.88.115）==========

void CentralizedControlManager::checkConnectionHealth()
{
    if (!isMasterMode()) return;
    QDateTime now = QDateTime::currentDateTime();

    for (int i = 0; i < MAX_SLOTS; i++) {
        if (!m_slots[i].enabled) continue;

        SubStationStatus &st = m_slotStatus[i];
        if (!st.isOnline) {
            // 离线状态：检查是否到重连时间
            attemptReconnect(i);
            continue;
        }

        // 检查最后更新时间
        // S7/Modbus：500ms轮询，超过3s无更新视为离线
        // MQTT：心跳3s一次，连续3次未收（9s）视为离线
        int timeoutMs = (m_slots[i].protocol == "mqtt") ? 9000 : 3000;
        if (st.lastUpdateTime.isValid() &&
            st.lastUpdateTime.msecsTo(now) > timeoutMs)
        {
            st.missedHeartbeats++;
            qWarning() << "[CentralizedControl] 槽位" << i
                       << "超时，missedHeartbeats=" << st.missedHeartbeats;
            if (st.missedHeartbeats >= 3) {
                handleSlotOffline(i);
            }
        }
    }
}

void CentralizedControlManager::handleSlotOnline(int slotIndex)
{
    SubStationStatus &st  = m_slotStatus[slotIndex];
    st.isOnline           = true;
    st.missedHeartbeats   = 0;
    st.reconnectAttempts  = 0;
    st.nextReconnectTime  = QDateTime();

    m_slots[slotIndex].statusText = "在线";
    emit slotOnlineChanged(slotIndex, true);
    emit slotStatusChanged(slotIndex, "在线");
    emit subStationsChanged();
    qDebug() << "[CentralizedControl] 槽位" << slotIndex << "上线";
}

void CentralizedControlManager::handleSlotOffline(int slotIndex)
{
    SubStationStatus &st = m_slotStatus[slotIndex];
    st.isOnline          = false;
    st.missedHeartbeats  = 0;

    m_slots[slotIndex].statusText = "离线";
    emit slotOnlineChanged(slotIndex, false);
    emit slotStatusChanged(slotIndex, "离线");
    emit subStationsChanged();
    qWarning() << "[CentralizedControl] 槽位" << slotIndex << "离线";

    // 触发重连计划
    st.reconnectAttempts = 0;
    st.nextReconnectTime = QDateTime::currentDateTime().addSecs(5);
}

void CentralizedControlManager::attemptReconnect(int slotIndex)
{
    SubStationStatus &st = m_slotStatus[slotIndex];
    if (!st.nextReconnectTime.isValid()) return;
    if (QDateTime::currentDateTime() < st.nextReconnectTime) return;

    const QString &proto = m_slots[slotIndex].protocol;

    // MQTT分站通过心跳感知，不需要主动重连
    if (proto == "mqtt") {
        st.nextReconnectTime = QDateTime();
        return;
    }

    st.reconnectAttempts++;
    qDebug() << "[CentralizedControl] 槽位" << slotIndex
             << "第" << st.reconnectAttempts << "次重连...";

    bool ok = connectSlot(slotIndex);
    if (ok) {
        handleSlotOnline(slotIndex);
        return;
    }

    // 指数退避：5s → 10s → 20s → 60s（最大）
    int delaySec = 5;
    if      (st.reconnectAttempts == 1) delaySec = 5;
    else if (st.reconnectAttempts == 2) delaySec = 10;
    else if (st.reconnectAttempts == 3) delaySec = 20;
    else                                delaySec = 60;

    st.nextReconnectTime = QDateTime::currentDateTime().addSecs(delaySec);
    m_slots[slotIndex].statusText = QString("重连中(%1)").arg(st.reconnectAttempts);
    emit subStationsChanged();
}

// ========== 模式切换（Phase 7.48.88.115）==========

void CentralizedControlManager::enterMasterMode()
{
    qDebug() << "[CentralizedControl] 进入主站模式";

    // ✅ 2026-04-14 [Phase 7.48.88.142]: 将模块7的Broker地址配置为集控MQTT地址
    // 主站模块7连自己的本机Broker（127.0.0.1），也可以由用户指定其他地址
    if (m_mqttController && !m_mqttBrokerIP.isEmpty()
            && m_mqttBrokerIP != "127.0.0.1") {
        int oldIdx = m_mqttController->currentModuleIndex();
        m_mqttController->setCurrentModuleIndex(CENTRAL_MQTT_MODULE);
        m_mqttController->setBrokerHost(m_mqttBrokerIP);
        if (m_mqttBrokerPort > 0)
            m_mqttController->setBrokerPort(m_mqttBrokerPort);
        m_mqttController->setCurrentModuleIndex(oldIdx);
        qDebug() << "[CentralizedControl] 主站模式：模块7 Broker 设为" << m_mqttBrokerIP;
    }

    // 确保模块7已连接（模块7是预留的集控专用模块，不被MQTTAutoManager自动连接）
    if (m_mqttController && !m_mqttController->isModuleConnected(CENTRAL_MQTT_MODULE)) {
        m_mqttController->connectToModule(CENTRAL_MQTT_MODULE);
        qDebug() << "[CentralizedControl] 请求连接MQTT模块" << CENTRAL_MQTT_MODULE;
    }

    // 启动 S7/Modbus 轮询
    m_pollTimer->start();

    // 启动心跳 & 健康检查
    m_heartbeatTimer->start();
    m_healthCheckTimer->start();

    // 建立 MQTT 订阅（若 MQTTController 已连接）
    setupMqttSubscriptions();
}

void CentralizedControlManager::exitMasterMode()
{
    qDebug() << "[CentralizedControl] 退出主站模式";

    m_pollTimer->stop();
    m_heartbeatTimer->stop();
    m_healthCheckTimer->stop();

    teardownMqttSubscriptions();

    // 断开所有 S7/Modbus 连接
    for (int i = 0; i < MAX_SLOTS; i++) {
        if (m_slots[i].protocol != "mqtt")
            disconnectSlot(i);
    }
}

void CentralizedControlManager::enterSubStationMode()
{
    qDebug() << "[CentralizedControl] 进入分站模式，deviceId=" << m_localDeviceId;

    // ✅ 2026-04-14 [Phase 7.48.88.142]: 将模块7的Broker地址配置为集控MQTT地址
    // 模块0-6连本机127.0.0.1，模块7（集控）连主站的MQTT地址
    if (m_mqttController && !m_mqttBrokerIP.isEmpty()) {
        int oldIdx = m_mqttController->currentModuleIndex();
        m_mqttController->setCurrentModuleIndex(CENTRAL_MQTT_MODULE);
        m_mqttController->setBrokerHost(m_mqttBrokerIP);
        if (m_mqttBrokerPort > 0)
            m_mqttController->setBrokerPort(m_mqttBrokerPort);
        m_mqttController->setCurrentModuleIndex(oldIdx);
        qDebug() << "[CentralizedControl] 分站模式：模块7 Broker 设为" << m_mqttBrokerIP;
    }

    // 确保模块7已连接
    if (m_mqttController && !m_mqttController->isModuleConnected(CENTRAL_MQTT_MODULE)) {
        m_mqttController->connectToModule(CENTRAL_MQTT_MODULE);
        qDebug() << "[CentralizedControl] 请求连接MQTT模块" << CENTRAL_MQTT_MODULE;
    }

    // 分站订阅命令主题
    setupMqttSubscriptions();

    // 500ms 发布本地状态
    m_statusPublishTimer->start();

    // 3s 心跳
    m_heartbeatTimer->start();
}

// ✅ 2026-04-14 [Phase 7.48.88.142]: 启动时激活已加载的角色
// loadConfig() 只加载配置，不触发模式切换；此方法供 main.cpp 在依赖注入完成后调用
void CentralizedControlManager::activateLoadedRole()
{
    if (m_stationRole == "master") {
        qDebug() << "[CentralizedControl] 启动激活：主站模式";
        enterMasterMode();
    } else if (m_stationRole == "sub") {
        qDebug() << "[CentralizedControl] 启动激活：分站模式 deviceId=" << m_localDeviceId;
        enterSubStationMode();
    }
}

void CentralizedControlManager::exitSubStationMode()
{
    qDebug() << "[CentralizedControl] 退出分站模式";

    m_statusPublishTimer->stop();
    m_heartbeatTimer->stop();

    teardownMqttSubscriptions();
}

// ========== 控制命令（主站模式，Phase 7.48.88.112/113/114）==========

void CentralizedControlManager::sendStartBelt(int slotIndex, int beltNumber)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;
    if (!isMasterMode()) return;

    const QString &proto = m_slots[slotIndex].protocol;

    if (proto == "s7") {
        // DB2 Byte1: bit0=启动
        QByteArray db2 = buildS7DB2Command(beltNumber, 0x01);
        sendS7Command(slotIndex, db2);

    } else if (proto == "modbus") {
        // Coil 20 = 目标皮带编号，Coil 8 = 启动
        sendModbusRegister(slotIndex, 20, beltNumber);
        sendModbusCommand(slotIndex, 8, true);

    } else if (proto == "mqtt") {
        QJsonObject params;
        params["beltNumber"] = beltNumber;
        publishMqttCommand(slotIndex, "start_belt", params);
    }

    qDebug() << "[CentralizedControl] sendStartBelt 槽位=" << slotIndex
             << "皮带=" << beltNumber << "协议=" << proto;
}

void CentralizedControlManager::sendStopBelt(int slotIndex, int beltNumber)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;
    if (!isMasterMode()) return;

    const QString &proto = m_slots[slotIndex].protocol;

    if (proto == "s7") {
        // DB2 Byte1: bit1=停止
        QByteArray db2 = buildS7DB2Command(beltNumber, 0x02);
        sendS7Command(slotIndex, db2);

    } else if (proto == "modbus") {
        sendModbusRegister(slotIndex, 20, beltNumber);
        sendModbusCommand(slotIndex, 9, true);

    } else if (proto == "mqtt") {
        QJsonObject params;
        params["beltNumber"] = beltNumber;
        publishMqttCommand(slotIndex, "stop_belt", params);
    }

    qDebug() << "[CentralizedControl] sendStopBelt 槽位=" << slotIndex
             << "皮带=" << beltNumber << "协议=" << proto;
}

void CentralizedControlManager::sendEmergencyStop(int slotIndex, int beltNumber)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;
    if (!isMasterMode()) return;

    const QString &proto = m_slots[slotIndex].protocol;

    if (proto == "s7") {
        // DB2 Byte1: bit2=急停
        QByteArray db2 = buildS7DB2Command(beltNumber, 0x04);
        sendS7Command(slotIndex, db2);

    } else if (proto == "modbus") {
        sendModbusRegister(slotIndex, 20, beltNumber);
        sendModbusCommand(slotIndex, 10, true);

    } else if (proto == "mqtt") {
        QJsonObject params;
        params["beltNumber"] = beltNumber;
        publishMqttCommand(slotIndex, "emergency_stop", params);
    }

    qWarning() << "[CentralizedControl] sendEmergencyStop 槽位=" << slotIndex
               << "皮带=" << beltNumber << "协议=" << proto;
}

void CentralizedControlManager::sendMotorStart(int slotIndex, int beltNumber, int motorIndex)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;
    if (!isMasterMode()) return;
    if (motorIndex < 0 || motorIndex >= 8) return;

    const QString &proto = m_slots[slotIndex].protocol;
    quint8 motorBit = static_cast<quint8>(1 << motorIndex);

    if (proto == "s7") {
        // DB2 Byte6: 电机启动位图
        QByteArray db2 = buildS7DB2Command(beltNumber, 0x00, motorBit, 0x00);
        sendS7Command(slotIndex, db2);

    } else if (proto == "modbus") {
        // Modbus 无单独电机线圈，用 start_belt 代替
        sendModbusRegister(slotIndex, 20, beltNumber);
        sendModbusCommand(slotIndex, 8, true);

    } else if (proto == "mqtt") {
        QJsonObject params;
        params["beltNumber"] = beltNumber;
        params["motorIndex"] = motorIndex;
        publishMqttCommand(slotIndex, "motor_start", params);
    }
}

void CentralizedControlManager::sendMotorStop(int slotIndex, int beltNumber, int motorIndex)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;
    if (!isMasterMode()) return;
    if (motorIndex < 0 || motorIndex >= 8) return;

    const QString &proto = m_slots[slotIndex].protocol;
    quint8 motorBit = static_cast<quint8>(1 << motorIndex);

    if (proto == "s7") {
        // DB2 Byte7: 电机停止位图
        QByteArray db2 = buildS7DB2Command(beltNumber, 0x00, 0x00, motorBit);
        sendS7Command(slotIndex, db2);

    } else if (proto == "modbus") {
        sendModbusRegister(slotIndex, 20, beltNumber);
        sendModbusCommand(slotIndex, 9, true);

    } else if (proto == "mqtt") {
        QJsonObject params;
        params["beltNumber"] = beltNumber;
        params["motorIndex"] = motorIndex;
        publishMqttCommand(slotIndex, "motor_stop", params);
    }
}

void CentralizedControlManager::sendResetProtection(int slotIndex)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;
    if (!isMasterMode()) return;

    const QString &proto = m_slots[slotIndex].protocol;

    if (proto == "s7") {
        // DB2 Byte10: bit0=复位保护
        QByteArray db2 = buildS7DB2Command(0, 0x00, 0x00, 0x00, 0x01);
        sendS7Command(slotIndex, db2);

    } else if (proto == "modbus") {
        // Holding Register 21: 复位标志
        sendModbusRegister(slotIndex, 21, 1);

    } else if (proto == "mqtt") {
        publishMqttCommand(slotIndex, "reset_protection", QJsonObject());
    }
}

void CentralizedControlManager::sendResetFault(int slotIndex)
{
    if (slotIndex < 0 || slotIndex >= MAX_SLOTS) return;
    if (!isMasterMode()) return;

    const QString &proto = m_slots[slotIndex].protocol;

    if (proto == "s7") {
        // DB2 Byte10: bit2=复位故障
        QByteArray db2 = buildS7DB2Command(0, 0x00, 0x00, 0x00, 0x04);
        sendS7Command(slotIndex, db2);

    } else if (proto == "modbus") {
        sendModbusRegister(slotIndex, 22, 1);

    } else if (proto == "mqtt") {
        publishMqttCommand(slotIndex, "reset_fault", QJsonObject());
    }
}

// ========== 全局操作 ==========

void CentralizedControlManager::startAllBelts()
{
    if (!isMasterMode()) return;
    for (int i = 0; i < MAX_SLOTS; i++) {
        if (m_slots[i].enabled && m_slots[i].isConnected)
            sendStartBelt(i, 1);
    }
    qDebug() << "[CentralizedControl] 全部启动";
}

void CentralizedControlManager::stopAllBelts()
{
    if (!isMasterMode()) return;
    for (int i = 0; i < MAX_SLOTS; i++) {
        if (m_slots[i].enabled && m_slots[i].isConnected)
            sendStopBelt(i, 1);
    }
    qDebug() << "[CentralizedControl] 全部停止";
}

void CentralizedControlManager::emergencyStopAll()
{
    if (!isMasterMode()) return;
    for (int i = 0; i < MAX_SLOTS; i++) {
        if (m_slots[i].enabled && m_slots[i].isConnected)
            sendEmergencyStop(i, 1);
    }
    qWarning() << "[CentralizedControl] 全部紧急停车";
}
