#include "MaintenanceControl.h"
#include "CommonControl.h"
#include "SystemConfig.h"
#include "DeviceRoleManager.h"  // ✅ 2026-03-23 [Phase 7.48.84.5]
#include <QDebug>

MaintenanceControl::MaintenanceControl(QObject *parent)
    : QObject(parent)
    , m_commonControl(nullptr)
    , m_systemConfig(nullptr)
    , m_deviceRoleManager(nullptr)  // ✅ 2026-03-23 [Phase 7.48.84.5]
{
    qDebug() << "✅ MaintenanceControl: 检修模式控制已创建";
}

MaintenanceControl::~MaintenanceControl()
{
    qDebug() << "✅ MaintenanceControl: 检修模式控制已销毁";
}

void MaintenanceControl::setCommonControl(CommonControl *commonControl)
{
    m_commonControl = commonControl;
    qDebug() << "🔗 MaintenanceControl: CommonControl已连接";
}

void MaintenanceControl::setSystemConfig(SystemConfig *systemConfig)
{
    m_systemConfig = systemConfig;
    qDebug() << "🔗 MaintenanceControl: SystemConfig已连接";
}

// ✅ 2026-03-23 [Phase 7.48.84.5]: 添加DeviceRoleManager连接
void MaintenanceControl::setDeviceRoleManager(DeviceRoleManager *deviceRoleManager)
{
    m_deviceRoleManager = deviceRoleManager;
    qDebug() << "🔗 MaintenanceControl: DeviceRoleManager已连接";
}

void MaintenanceControl::handleStart()
{
    qDebug() << "🔧 MaintenanceControl: 收到启动命令（检修模式 - 无连锁）";

    if (!m_commonControl) {
        qWarning() << "❌ MaintenanceControl: CommonControl未设置";
        emit statusMessage("错误：公共控制未初始化");
        return;
    }

    if (!m_systemConfig) {
        qWarning() << "❌ MaintenanceControl: SystemConfig未设置";
        emit statusMessage("错误：系统配置未初始化");
        return;
    }

    // 检修模式：不检查连锁条件，直接调用公共控制逻辑
    qDebug() << "  ⚙️  检修模式：跳过连锁检查";
    qDebug() << "  ➡️  调用公共控制启动逻辑";

    emit statusMessage("检修模式：启动皮带（无连锁）");

    // 调用CommonControl的启动方法（带预警播放）
    // ✅ 2026-03-23 [Phase 7.48.84.5]: 优先使用DeviceRoleManager的localDeviceId
    // 旧代码：int beltNumber = m_systemConfig->machineNumber();
    // 原因：用户在设备弹窗中设置的本机设备存储在DeviceRoleManager中，而非SystemConfig
    int beltNumber = m_deviceRoleManager ? m_deviceRoleManager->localDeviceId() : m_systemConfig->machineNumber();
    m_commonControl->startBelt(beltNumber);
}

void MaintenanceControl::handleStop()
{
    qDebug() << "🔧 MaintenanceControl: 收到停止命令（检修模式 - 无连锁）";

    if (!m_commonControl) {
        qWarning() << "❌ MaintenanceControl: CommonControl未设置";
        emit statusMessage("错误：公共控制未初始化");
        return;
    }

    if (!m_systemConfig) {
        qWarning() << "❌ MaintenanceControl: SystemConfig未设置";
        emit statusMessage("错误：系统配置未初始化");
        return;
    }

    // 检修模式：不检查连锁条件，直接调用公共控制逻辑
    qDebug() << "  ⚙️  检修模式：跳过连锁检查";
    qDebug() << "  ➡️  调用公共控制停止逻辑";

    emit statusMessage("检修模式：停止皮带（无连锁）");

    // 调用CommonControl的停止方法（带停车音频 + 停止序列）
    // ✅ 2026-03-23 [Phase 7.48.84.5]: 优先使用DeviceRoleManager的localDeviceId
    // 旧代码：int beltNumber = m_systemConfig->machineNumber();
    int beltNumber = m_deviceRoleManager ? m_deviceRoleManager->localDeviceId() : m_systemConfig->machineNumber();
    m_commonControl->stopBelt(beltNumber);
}
