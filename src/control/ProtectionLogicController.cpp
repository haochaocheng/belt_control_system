#include "ProtectionLogicController.h"
#include "CommonControl.h"
#include "DeviceConfigManager.h"
#include "DeviceRoleManager.h"
#include <QDebug>

// ✅ 2026-03-23 [Phase 7.48.85]: 保护逻辑控制器实现
// 功能：将保护触发与皮带停车控制关联

ProtectionLogicController::ProtectionLogicController(QObject *parent)
    : QObject(parent)
    , m_commonControl(nullptr)
    , m_deviceConfigMgr(nullptr)
    , m_deviceRoleManager(nullptr)
{
    qDebug() << "✅ ProtectionLogicController: 保护逻辑控制器已创建";
}

ProtectionLogicController::~ProtectionLogicController()
{
    qDebug() << "✅ ProtectionLogicController: 保护逻辑控制器已销毁";
}

void ProtectionLogicController::setCommonControl(CommonControl *ctrl)
{
    m_commonControl = ctrl;
    qDebug() << "🔗 ProtectionLogicController: CommonControl已连接";
}

void ProtectionLogicController::setDeviceConfigManager(DeviceConfigManager *mgr)
{
    m_deviceConfigMgr = mgr;
    qDebug() << "🔗 ProtectionLogicController: DeviceConfigManager已连接";
}

void ProtectionLogicController::setDeviceRoleManager(DeviceRoleManager *mgr)
{
    m_deviceRoleManager = mgr;
    qDebug() << "🔗 ProtectionLogicController: DeviceRoleManager已连接";
}

QString ProtectionLogicController::stopSourceName(int source)
{
    switch (static_cast<StopSource>(source)) {
    case Source_ManualKey:          return "手动R/S键";
    case Source_DigitalProtection:  return "开关量保护";
    case Source_AnalogProtection:   return "模拟量保护";
    case Source_MotorProtection:    return "电机保护";
    case Source_CSProtection:       return "CS沿线点位";
    case Source_TensionProtection:  return "张紧控制";
    case Source_MasterCommLost:     return "主站通讯失败";
    case Source_MasterEmergency:    return "主站紧急停车";
    case Source_Reserved1:          return "预留1";
    case Source_Reserved2:          return "预留2";
    case Source_Reserved3:          return "预留3";
    case Source_Reserved4:          return "预留4";
    default:                        return "未知";
    }
}

void ProtectionLogicController::onProtectionTriggered(int beltNumber, const QString &protectionName,
                                                       int protectionLevel, int source)
{
    qDebug() << "🚨 ProtectionLogicController: 收到保护触发"
             << "皮带:" << beltNumber
             << "保护:" << protectionName
             << "级别:" << protectionLevel
             << "来源:" << stopSourceName(source);

    // 记录活跃保护
    QString key = QString("%1:%2").arg(beltNumber).arg(protectionName);
    ActiveProtection ap;
    ap.beltNumber = beltNumber;
    ap.protectionName = protectionName;
    ap.protectionLevel = protectionLevel;
    ap.source = static_cast<StopSource>(source);
    ap.triggeredAt = QDateTime::currentDateTime();
    m_activeProtections[key] = ap;

    // 执行保护控制动作
    executeProtectionAction(beltNumber, protectionName, protectionLevel, static_cast<StopSource>(source));
}

void ProtectionLogicController::onProtectionRestored(int beltNumber, const QString &protectionName,
                                                      int source)
{
    QString key = QString("%1:%2").arg(beltNumber).arg(protectionName);

    if (m_activeProtections.contains(key)) {
        m_activeProtections.remove(key);
        qDebug() << "✅ ProtectionLogicController: 保护恢复"
                 << "皮带:" << beltNumber
                 << "保护:" << protectionName
                 << "来源:" << stopSourceName(source);

        emit protectionCleared(beltNumber, protectionName);

        // 检查该皮带是否还有其他活跃保护
        bool hasActiveProtection = false;
        for (auto it = m_activeProtections.constBegin(); it != m_activeProtections.constEnd(); ++it) {
            if (it.value().beltNumber == beltNumber) {
                hasActiveProtection = true;
                break;
            }
        }
        if (!hasActiveProtection) {
            // 所有保护已恢复，清除停车标志
            m_beltStopped.remove(beltNumber);
            qDebug() << "✅ ProtectionLogicController: 皮带" << beltNumber << "所有保护已恢复，停车标志已清除";
        }
    }
}

void ProtectionLogicController::onMasterCommStatusChanged(bool connected)
{
    if (!connected) {
        qWarning() << "🚨 ProtectionLogicController: 主站通讯失败，触发紧急停车";
        // 获取本机皮带编号
        int beltNumber = m_deviceRoleManager ? m_deviceRoleManager->localDeviceId() : 1;
        onProtectionTriggered(beltNumber, "主站通讯失败", 0, Source_MasterCommLost);
    } else {
        qDebug() << "✅ ProtectionLogicController: 主站通讯恢复";
        int beltNumber = m_deviceRoleManager ? m_deviceRoleManager->localDeviceId() : 1;
        onProtectionRestored(beltNumber, "主站通讯失败", Source_MasterCommLost);
    }
}

void ProtectionLogicController::onMasterEmergencyStop(int beltNumber)
{
    qWarning() << "🚨 ProtectionLogicController: 收到主站紧急停车命令，皮带:" << beltNumber;
    // beltNumber=0 表示停止所有皮带，这里简化为停止本机皮带
    if (beltNumber == 0) {
        beltNumber = m_deviceRoleManager ? m_deviceRoleManager->localDeviceId() : 1;
    }
    onProtectionTriggered(beltNumber, "主站紧急停车", 0, Source_MasterEmergency);
}

void ProtectionLogicController::executeProtectionAction(int beltNumber, const QString &protectionName,
                                                         int protectionLevel, StopSource source)
{
    switch (protectionLevel) {
    case 0: {
        // 紧急停车：跳过停车音频，直接执行停止序列
        if (m_beltStopped.value(beltNumber, false)) {
            qDebug() << "⚠️ ProtectionLogicController: 皮带" << beltNumber
                     << "已因保护触发停车，忽略重复停车请求";
            return;
        }
        m_beltStopped[beltNumber] = true;

        QString msg = QString("🚨 紧急停车：%1 [来源: %2]").arg(protectionName).arg(stopSourceName(source));
        emit statusMessage(msg);
        emit protectionStopTriggered(beltNumber, protectionName, protectionLevel, source);

        qWarning() << "🚨 ProtectionLogicController: 执行紧急停车 - 皮带" << beltNumber
                   << "保护:" << protectionName << "来源:" << stopSourceName(source);

        if (m_commonControl) {
            m_commonControl->emergencyStopBelt(beltNumber);
        } else {
            qWarning() << "❌ ProtectionLogicController: CommonControl未设置，无法执行紧急停车";
        }
        break;
    }
    case 1: {
        // 正常停车：播放停车音频 + 停止序列
        if (m_beltStopped.value(beltNumber, false)) {
            qDebug() << "⚠️ ProtectionLogicController: 皮带" << beltNumber
                     << "已因保护触发停车，忽略重复停车请求";
            return;
        }
        m_beltStopped[beltNumber] = true;

        QString msg = QString("⚠️ 正常停车：%1 [来源: %2]").arg(protectionName).arg(stopSourceName(source));
        emit statusMessage(msg);
        emit protectionStopTriggered(beltNumber, protectionName, protectionLevel, source);

        qWarning() << "⚠️ ProtectionLogicController: 执行正常停车 - 皮带" << beltNumber
                   << "保护:" << protectionName << "来源:" << stopSourceName(source);

        if (m_commonControl) {
            m_commonControl->stopBelt(beltNumber);
        } else {
            qWarning() << "❌ ProtectionLogicController: CommonControl未设置，无法执行正常停车";
        }
        break;
    }
    case 2:
        // 仅预警：不停车（报警音频已由 AlarmPlaybackService 处理）
        qDebug() << "🔔 ProtectionLogicController: 仅预警 - 皮带" << beltNumber
                 << "保护:" << protectionName << "（不停车）";
        break;
    case 3:
        // 不处理
        qDebug() << "📝 ProtectionLogicController: 不处理 - 皮带" << beltNumber
                 << "保护:" << protectionName << "（protection_level=3）";
        break;
    default:
        qWarning() << "⚠️ ProtectionLogicController: 未知保护级别:" << protectionLevel;
        break;
    }
}

QVariantList ProtectionLogicController::activeProtections() const
{
    QVariantList result;
    for (auto it = m_activeProtections.constBegin(); it != m_activeProtections.constEnd(); ++it) {
        QVariantMap item;
        item["beltNumber"] = it.value().beltNumber;
        item["protectionName"] = it.value().protectionName;
        item["protectionLevel"] = it.value().protectionLevel;
        item["source"] = static_cast<int>(it.value().source);
        item["sourceName"] = stopSourceName(it.value().source);
        item["triggeredAt"] = it.value().triggeredAt.toString("yyyy-MM-dd HH:mm:ss");
        result.append(item);
    }
    return result;
}

void ProtectionLogicController::resetAllProtections()
{
    qDebug() << "🔄 ProtectionLogicController: 手动复位所有保护";
    int count = m_activeProtections.size();
    m_activeProtections.clear();
    m_beltStopped.clear();
    qDebug() << "✅ ProtectionLogicController: 已清除" << count << "个活跃保护记录";
    emit statusMessage(QString("已复位 %1 个保护").arg(count));
}
