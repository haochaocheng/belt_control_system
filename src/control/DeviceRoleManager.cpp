// DeviceRoleManager.cpp
// 设备角色管理器实现
// 创建日期: 2026-02-10
// Phase 7.45.1
// ✅ 2026-02-10 [Phase 7.45.6]: 添加 MQTT 集成实现

#include "DeviceRoleManager.h"
#include "mqtt/MQTTController.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>

// DeviceInfo 转换为 QVariantMap
QVariantMap DeviceInfo::toVariantMap() const
{
    QVariantMap map;
    map["deviceId"] = deviceId;
    map["deviceName"] = deviceName;
    map["deviceType"] = static_cast<int>(deviceType);
    map["isLocal"] = isLocal;
    map["isOnline"] = isOnline;
    map["status"] = status;
    map["lastUpdate"] = lastUpdate.toString("yyyy-MM-dd HH:mm:ss");
    return map;
}

// StationInfo 转换为 QVariantMap
QVariantMap StationInfo::toVariantMap() const
{
    QVariantMap map;
    map["stationId"] = stationId;
    map["stationRole"] = stationRole;
    map["stationName"] = stationName;
    map["controlDevice"] = controlDevice;
    map["controlDeviceId"] = controlDeviceId;
    map["ip"] = ip;
    map["isOnline"] = isOnline;
    map["status"] = status;
    map["lastUpdate"] = lastUpdate.toString("yyyy-MM-dd HH:mm:ss");
    return map;
}

DeviceRoleManager::DeviceRoleManager(QObject *parent)
    : QObject(parent)
    , m_localDeviceId(1)  // 默认1号皮带
    , m_stationRole("master")  // 默认主站
    , m_stationId(1)  // 默认集控ID为1
    , m_mqttController(nullptr)  // ✅ 2026-02-10 [Phase 7.45.6]: 初始化 MQTT 控制器
    , m_publishTimer(nullptr)    // ✅ 2026-02-10 [Phase 7.45.6]: 初始化发布定时器
    , m_mqttEnabled(false)       // ✅ 2026-02-10 [Phase 7.45.6]: 默认禁用 MQTT
{
    // 设置配置文件路径
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    QDir().mkpath(configDir);
    m_configFilePath = configDir + "/device_role.json";

    qDebug() << "📋 [DeviceRoleManager] 初始化";
    qDebug() << "   配置文件路径:" << m_configFilePath;

    // 初始化设备列表
    initializeDevices();

    // 初始化集控设备列表
    initializeStations();

    // 从配置文件加载
    loadFromConfig();

    // ✅ 2026-02-10 [Phase 7.45.6]: 创建发布定时器
    m_publishTimer = new QTimer(this);
    m_publishTimer->setInterval(1000);  // 1秒发布一次
    connect(m_publishTimer, &QTimer::timeout, this, &DeviceRoleManager::onPublishTimerTimeout);
}

DeviceRoleManager::~DeviceRoleManager()
{
    // ✅ 2026-02-10 [Phase 7.45.6]: 停止 MQTT 发布
    stopMQTTPublishing();

    // 保存配置
    saveToConfig();
}

QString DeviceRoleManager::localDeviceName() const
{
    return getDeviceName(m_localDeviceId);
}

QString DeviceRoleManager::stationName() const
{
    if (m_stationRole == "master") {
        return "主站";
    } else {
        return QString("分站%1").arg(m_stationId);
    }
}

QVariantList DeviceRoleManager::allDevices() const
{
    QVariantList list;
    for (const DeviceInfo &device : m_devices) {
        list.append(device.toVariantMap());
    }
    return list;
}

QVariantList DeviceRoleManager::allStations() const
{
    QVariantList list;
    for (const StationInfo &station : m_stations) {
        list.append(station.toVariantMap());
    }
    return list;
}

void DeviceRoleManager::setLocalDeviceId(int deviceId)
{
    if (deviceId < 1 || deviceId > 8) {
        qWarning() << "⚠️ [DeviceRoleManager] 无效的设备ID:" << deviceId;
        return;
    }

    if (m_localDeviceId != deviceId) {
        int oldDeviceId = m_localDeviceId;
        m_localDeviceId = deviceId;

        qDebug() << "🔄 [DeviceRoleManager] 本机设备切换:" << oldDeviceId << "→" << deviceId;

        // 更新设备的本机状态
        updateDeviceLocalStatus();

        // 发送信号
        emit localDeviceIdChanged();
        emit localDeviceNameChanged();
        emit deviceRoleChanged(oldDeviceId, false);
        emit deviceRoleChanged(deviceId, true);
        emit allDevicesChanged();

        // 保存到配置文件
        saveToConfig();
    }
}

void DeviceRoleManager::setStationRole(const QString &role)
{
    if (role != "master" && role != "sub") {
        qWarning() << "⚠️ [DeviceRoleManager] 无效的角色:" << role;
        return;
    }

    if (m_stationRole != role) {
        QString oldRole = m_stationRole;
        m_stationRole = role;

        qDebug() << "🔄 [DeviceRoleManager] 本机角色切换:" << oldRole << "→" << role;

        // 发送信号
        emit stationRoleChanged();
        emit stationNameChanged();
        emit allStationsChanged();

        // 保存到配置文件
        saveToConfig();
    }
}

bool DeviceRoleManager::isLocalDevice(int deviceId) const
{
    return deviceId == m_localDeviceId;
}

bool DeviceRoleManager::hasPermission(int deviceId) const
{
    // 只有本机设备才有权限修改
    return isLocalDevice(deviceId);
}

void DeviceRoleManager::updateDeviceStatus(int deviceId, bool isOnline, const QString &status)
{
    if (m_devices.contains(deviceId)) {
        DeviceInfo &device = m_devices[deviceId];
        device.isOnline = isOnline;
        device.status = status;
        device.lastUpdate = QDateTime::currentDateTime();

        qDebug() << "📊 [DeviceRoleManager] 设备状态更新:" << device.deviceName
                 << "在线:" << isOnline << "状态:" << status;

        emit deviceStatusChanged(deviceId, isOnline, status);
        emit allDevicesChanged();
    }
}

void DeviceRoleManager::updateStationStatus(int stationId, bool isOnline, const QString &status)
{
    if (m_stations.contains(stationId)) {
        StationInfo &station = m_stations[stationId];
        station.isOnline = isOnline;
        station.status = status;
        station.lastUpdate = QDateTime::currentDateTime();

        qDebug() << "📊 [DeviceRoleManager] 集控状态更新:" << station.stationName
                 << "在线:" << isOnline << "状态:" << status;

        emit stationStatusChanged(stationId, isOnline, status);
        emit allStationsChanged();
    }
}

void DeviceRoleManager::saveToConfig()
{
    QJsonObject root;
    root["localDeviceId"] = m_localDeviceId;
    root["localDeviceName"] = localDeviceName();
    root["stationRole"] = m_stationRole;
    root["stationName"] = stationName();
    root["stationId"] = m_stationId;
    root["lastUpdate"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    QJsonDocument doc(root);
    QFile file(m_configFilePath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson(QJsonDocument::Indented));
        file.close();
        qDebug() << "💾 [DeviceRoleManager] 配置已保存:" << m_configFilePath;
    } else {
        qWarning() << "⚠️ [DeviceRoleManager] 无法保存配置文件:" << m_configFilePath;
    }
}

void DeviceRoleManager::loadFromConfig()
{
    QFile file(m_configFilePath);
    if (!file.exists()) {
        qDebug() << "ℹ️ [DeviceRoleManager] 配置文件不存在，使用默认配置";
        return;
    }

    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        file.close();

        if (doc.isObject()) {
            QJsonObject root = doc.object();

            // 加载本机设备ID
            if (root.contains("localDeviceId")) {
                int deviceId = root["localDeviceId"].toInt();
                if (deviceId >= 1 && deviceId <= 8) {
                    m_localDeviceId = deviceId;
                }
            }

            // 加载本机角色
            if (root.contains("stationRole")) {
                QString role = root["stationRole"].toString();
                if (role == "master" || role == "sub") {
                    m_stationRole = role;
                }
            }

            // 加载集控ID
            if (root.contains("stationId")) {
                m_stationId = root["stationId"].toInt();
            }

            qDebug() << "📂 [DeviceRoleManager] 配置已加载:";
            qDebug() << "   本机设备:" << localDeviceName() << "(" << m_localDeviceId << ")";
            qDebug() << "   本机角色:" << stationName() << "(" << m_stationRole << ")";

            // 更新设备的本机状态
            updateDeviceLocalStatus();

            // 发送信号
            emit localDeviceIdChanged();
            emit localDeviceNameChanged();
            emit stationRoleChanged();
            emit stationNameChanged();
            emit allDevicesChanged();
            emit allStationsChanged();
        }
    } else {
        qWarning() << "⚠️ [DeviceRoleManager] 无法读取配置文件:" << m_configFilePath;
    }
}

void DeviceRoleManager::initializeDevices()
{
    qDebug() << "🔧 [DeviceRoleManager] 初始化设备列表";

    // 初始化12个设备
    for (int i = 1; i <= 12; i++) {
        DeviceInfo device;
        device.deviceId = i;
        device.deviceName = getDeviceName(i);
        device.deviceType = getDeviceType(i);
        device.isLocal = (i == m_localDeviceId);
        device.isOnline = false;  // 默认离线
        device.status = "未知";
        device.lastUpdate = QDateTime::currentDateTime();

        m_devices[i] = device;
    }

    qDebug() << "   已初始化" << m_devices.size() << "个设备";
}

void DeviceRoleManager::initializeStations()
{
    qDebug() << "🔧 [DeviceRoleManager] 初始化集控设备列表";

    // 初始化本机集控
    StationInfo localStation;
    localStation.stationId = m_stationId;
    localStation.stationRole = m_stationRole;
    localStation.stationName = stationName();
    localStation.controlDevice = localDeviceName();
    localStation.controlDeviceId = m_localDeviceId;
    localStation.ip = "192.168.10.188";  // 默认IP
    localStation.isOnline = true;  // 本机始终在线
    localStation.status = "运行中";
    localStation.lastUpdate = QDateTime::currentDateTime();

    m_stations[m_stationId] = localStation;

    qDebug() << "   已初始化" << m_stations.size() << "个集控设备";
}

void DeviceRoleManager::updateDeviceLocalStatus()
{
    // 更新所有设备的本机状态
    for (auto it = m_devices.begin(); it != m_devices.end(); ++it) {
        bool wasLocal = it->isLocal;
        it->isLocal = (it->deviceId == m_localDeviceId);

        if (wasLocal != it->isLocal) {
            qDebug() << "   设备" << it->deviceName << "本机状态:" << wasLocal << "→" << it->isLocal;
        }
    }
}

QString DeviceRoleManager::getDeviceName(int deviceId) const
{
    switch (deviceId) {
    case 1: return "1号皮带";
    case 2: return "2号皮带";
    case 3: return "3号皮带";
    case 4: return "4号皮带";
    case 5: return "5号皮带";
    case 6: return "6号皮带";
    case 7: return "7号皮带";
    case 8: return "8号皮带";
    case 9: return "转载机";
    case 10: return "破碎机";
    case 11: return "前刮板";
    case 12: return "后刮板";
    default: return "未知设备";
    }
}

DeviceType DeviceRoleManager::getDeviceType(int deviceId) const
{
    if (deviceId >= 1 && deviceId <= 8) {
        return DeviceType::Belt;
    } else if (deviceId == 9) {
        return DeviceType::Loader;
    } else if (deviceId == 10) {
        return DeviceType::Crusher;
    } else if (deviceId == 11) {
        return DeviceType::FrontScraper;
    } else if (deviceId == 12) {
        return DeviceType::RearScraper;
    }
    return DeviceType::Belt;
}

// ========== ✅ 2026-02-10 [Phase 7.45.6]: MQTT 集成实现 ==========

void DeviceRoleManager::setMQTTController(MQTTController *controller)
{
    if (m_mqttController == controller) {
        return;
    }

    // 断开旧的连接
    if (m_mqttController) {
        disconnect(m_mqttController, nullptr, this, nullptr);
    }

    m_mqttController = controller;

    // 连接新的信号
    if (m_mqttController) {
        connect(m_mqttController, &MQTTController::messageReceived,
                this, &DeviceRoleManager::onMQTTMessageReceived);

        qDebug() << "✅ [DeviceRoleManager] MQTT 控制器已设置";

        // 订阅主题
        subscribeMQTTTopics();
    }
}

void DeviceRoleManager::startMQTTPublishing()
{
    if (!m_mqttController) {
        qWarning() << "⚠️ [DeviceRoleManager] MQTT 控制器未设置，无法启动发布";
        return;
    }

    if (m_mqttEnabled) {
        qDebug() << "⚠️ [DeviceRoleManager] MQTT 发布已启动";
        return;
    }

    m_mqttEnabled = true;
    m_publishTimer->start();

    qDebug() << "✅ [DeviceRoleManager] MQTT 发布已启动";
    qDebug() << "   发布间隔: 1秒";
    qDebug() << "   集控主题: station/status/" << m_stationId;
    qDebug() << "   设备主题: device/status/" << m_localDeviceId;
}

void DeviceRoleManager::stopMQTTPublishing()
{
    if (!m_mqttEnabled) {
        return;
    }

    m_mqttEnabled = false;
    m_publishTimer->stop();

    // 取消订阅
    unsubscribeMQTTTopics();

    qDebug() << "🛑 [DeviceRoleManager] MQTT 发布已停止";
}

void DeviceRoleManager::subscribeMQTTTopics()
{
    if (!m_mqttController) {
        return;
    }

    // 订阅所有集控设备状态（station/status/+）
    m_mqttController->subscribe("station/status/+", 1);
    qDebug() << "📡 [DeviceRoleManager] 订阅主题: station/status/+";

    // 订阅所有设备状态（device/status/+）
    m_mqttController->subscribe("device/status/+", 1);
    qDebug() << "📡 [DeviceRoleManager] 订阅主题: device/status/+";
}

void DeviceRoleManager::unsubscribeMQTTTopics()
{
    if (!m_mqttController) {
        return;
    }

    m_mqttController->unsubscribe("station/status/+");
    m_mqttController->unsubscribe("device/status/+");

    qDebug() << "📡 [DeviceRoleManager] 取消订阅所有主题";
}

void DeviceRoleManager::onPublishTimerTimeout()
{
    if (!m_mqttEnabled || !m_mqttController) {
        return;
    }

    // 发布集控设备状态
    publishStationStatus();

    // 发布本机设备状态
    publishDeviceStatus();
}

void DeviceRoleManager::publishStationStatus()
{
    if (!m_mqttController) {
        return;
    }

    // 构建集控状态消息
    QJsonObject json;
    json["stationId"] = m_stationId;
    json["stationRole"] = m_stationRole;
    json["stationName"] = stationName();
    json["controlDevice"] = localDeviceName();
    json["controlDeviceId"] = m_localDeviceId;
    json["ip"] = "192.168.10.188";  // TODO: 从配置获取
    json["isOnline"] = true;
    json["status"] = "运行中";  // TODO: 从实际状态获取
    json["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    QJsonDocument doc(json);
    QString topic = QString("station/status/%1").arg(m_stationId);
    QString message = doc.toJson(QJsonDocument::Compact);

    // 发布消息
    m_mqttController->publish(topic, message, 1, false);

    // qDebug() << "📤 [DeviceRoleManager] 发布集控状态:" << topic;
}

void DeviceRoleManager::publishDeviceStatus()
{
    if (!m_mqttController) {
        return;
    }

    // 获取本机设备信息
    if (!m_devices.contains(m_localDeviceId)) {
        return;
    }

    const DeviceInfo &device = m_devices[m_localDeviceId];

    // 构建设备状态消息
    QJsonObject json;
    json["deviceId"] = device.deviceId;
    json["deviceName"] = device.deviceName;
    json["deviceType"] = static_cast<int>(device.deviceType);
    json["isOnline"] = device.isOnline;
    json["status"] = device.status;
    json["controlStation"] = stationName();
    json["controlStationId"] = m_stationId;
    json["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    QJsonDocument doc(json);
    QString topic = QString("device/status/%1").arg(m_localDeviceId);
    QString message = doc.toJson(QJsonDocument::Compact);

    // 发布消息
    m_mqttController->publish(topic, message, 1, false);

    // qDebug() << "📤 [DeviceRoleManager] 发布设备状态:" << topic;
}

void DeviceRoleManager::onMQTTMessageReceived(int moduleIndex, const QString &topic, const QByteArray &payload)
{
    Q_UNUSED(moduleIndex);

    // 解析集控设备状态消息
    if (topic.startsWith("station/status/")) {
        parseStationStatusMessage(topic, payload);
    }
    // 解析设备状态消息
    else if (topic.startsWith("device/status/")) {
        parseDeviceStatusMessage(topic, payload);
    }
}

void DeviceRoleManager::parseStationStatusMessage(const QString &topic, const QByteArray &payload)
{
    // 提取集控ID
    QString stationIdStr = topic.mid(QString("station/status/").length());
    bool ok;
    int stationId = stationIdStr.toInt(&ok);
    if (!ok) {
        qWarning() << "⚠️ [DeviceRoleManager] 无效的集控ID:" << stationIdStr;
        return;
    }

    // 跳过本机消息
    if (stationId == m_stationId) {
        return;
    }

    // 解析 JSON
    QJsonDocument doc = QJsonDocument::fromJson(payload);
    if (!doc.isObject()) {
        qWarning() << "⚠️ [DeviceRoleManager] 无效的 JSON 消息:" << payload;
        return;
    }

    QJsonObject json = doc.object();

    // 更新或创建集控设备信息
    StationInfo station;
    station.stationId = json["stationId"].toInt();
    station.stationRole = json["stationRole"].toString();
    station.stationName = json["stationName"].toString();
    station.controlDevice = json["controlDevice"].toString();
    station.controlDeviceId = json["controlDeviceId"].toInt();
    station.ip = json["ip"].toString();
    station.isOnline = json["isOnline"].toBool();
    station.status = json["status"].toString();
    station.lastUpdate = QDateTime::currentDateTime();

    m_stations[stationId] = station;

    qDebug() << "📥 [DeviceRoleManager] 收到集控状态:" << station.stationName
             << "在线:" << station.isOnline << "状态:" << station.status;

    // 发送信号
    emit stationStatusChanged(stationId, station.isOnline, station.status);
    emit allStationsChanged();
}

void DeviceRoleManager::parseDeviceStatusMessage(const QString &topic, const QByteArray &payload)
{
    // 提取设备ID
    QString deviceIdStr = topic.mid(QString("device/status/").length());
    bool ok;
    int deviceId = deviceIdStr.toInt(&ok);
    if (!ok) {
        qWarning() << "⚠️ [DeviceRoleManager] 无效的设备ID:" << deviceIdStr;
        return;
    }

    // 跳过本机设备消息
    if (deviceId == m_localDeviceId) {
        return;
    }

    // 解析 JSON
    QJsonDocument doc = QJsonDocument::fromJson(payload);
    if (!doc.isObject()) {
        qWarning() << "⚠️ [DeviceRoleManager] 无效的 JSON 消息:" << payload;
        return;
    }

    QJsonObject json = doc.object();

    // 更新设备信息
    if (m_devices.contains(deviceId)) {
        DeviceInfo &device = m_devices[deviceId];
        device.isOnline = json["isOnline"].toBool();
        device.status = json["status"].toString();
        device.lastUpdate = QDateTime::currentDateTime();

        qDebug() << "📥 [DeviceRoleManager] 收到设备状态:" << device.deviceName
                 << "在线:" << device.isOnline << "状态:" << device.status;

        // 发送信号
        emit deviceStatusChanged(deviceId, device.isOnline, device.status);
        emit allDevicesChanged();
    }
}
