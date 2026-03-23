#include "LocalControl.h"
#include "CommonControl.h"
#include "SystemConfig.h"
#include "DeviceRoleManager.h"  // ✅ 2026-03-23 [Phase 7.48.84.5]
#include <QDebug>

LocalControl::LocalControl(QObject *parent)
    : QObject(parent)
    , m_commonControl(nullptr)
    , m_systemConfig(nullptr)
    , m_deviceRoleManager(nullptr)  // ✅ 2026-03-23 [Phase 7.48.84.5]
{
    qDebug() << "✅ LocalControl: 就地模式控制已创建";
}

LocalControl::~LocalControl()
{
    qDebug() << "✅ LocalControl: 就地模式控制已销毁";
}

void LocalControl::setCommonControl(CommonControl *commonControl)
{
    m_commonControl = commonControl;
    qDebug() << "🔗 LocalControl: CommonControl已连接";
}

void LocalControl::setSystemConfig(SystemConfig *systemConfig)
{
    m_systemConfig = systemConfig;
    qDebug() << "🔗 LocalControl: SystemConfig已连接";
}

// ✅ 2026-03-23 [Phase 7.48.84.5]: 添加DeviceRoleManager连接
void LocalControl::setDeviceRoleManager(DeviceRoleManager *deviceRoleManager)
{
    m_deviceRoleManager = deviceRoleManager;
    qDebug() << "🔗 LocalControl: DeviceRoleManager已连接";
}

bool LocalControl::checkStartInterlock()
{
    // TODO: 实现连锁条件检查
    // 例如：
    // - 检查急停按钮状态
    // - 检查安全门状态
    // - 检查前级设备运行状态
    // - 检查设备故障状态
    // - 检查温度、压力等传感器

    qDebug() << "  🔍 就地模式：检查启动连锁条件";

    // 临时实现：始终返回true（允许启动）
    // 后续需要根据实际连锁需求添加检查逻辑
    qDebug() << "  ✅ 连锁检查通过（当前为临时实现，无实际检查）";

    return true;
}

bool LocalControl::checkStopInterlock()
{
    // TODO: 实现停止连锁条件检查（可选）
    // 一般停止操作不需要连锁检查，但某些场景可能需要
    // 例如：
    // - 检查后级设备是否已停止
    // - 检查是否处于紧急状态

    qDebug() << "  🔍 就地模式：检查停止连锁条件";

    // 临时实现：始终返回true（允许停止）
    qDebug() << "  ✅ 停止检查通过";

    return true;
}

void LocalControl::handleStart()
{
    qDebug() << "🏭 LocalControl: 收到启动命令（就地模式 - 有连锁）";

    if (!m_commonControl) {
        qWarning() << "❌ LocalControl: CommonControl未设置";
        emit statusMessage("错误：公共控制未初始化");
        return;
    }

    if (!m_systemConfig) {
        qWarning() << "❌ LocalControl: SystemConfig未设置";
        emit statusMessage("错误：系统配置未初始化");
        return;
    }

    // 就地模式：检查连锁条件
    if (!checkStartInterlock()) {
        qWarning() << "❌ LocalControl: 启动连锁条件不满足，禁止启动";
        emit statusMessage("就地模式：连锁条件不满足，无法启动");
        // TODO: 播放"连锁条件不满足"音频提示
        return;
    }

    qDebug() << "  ➡️  连锁检查通过，调用公共控制启动逻辑";
    emit statusMessage("就地模式：启动皮带（连锁检查通过）");

    // 调用CommonControl的启动方法（带预警播放）
    // ✅ 2026-03-23 [Phase 7.48.84.5]: 优先使用DeviceRoleManager的localDeviceId
    // 旧代码：int beltNumber = m_systemConfig->machineNumber();
    int beltNumber = m_deviceRoleManager ? m_deviceRoleManager->localDeviceId() : m_systemConfig->machineNumber();
    m_commonControl->startBelt(beltNumber);
}

void LocalControl::handleStop()
{
    qDebug() << "🏭 LocalControl: 收到停止命令（就地模式 - 有连锁）";

    if (!m_commonControl) {
        qWarning() << "❌ LocalControl: CommonControl未设置";
        emit statusMessage("错误：公共控制未初始化");
        return;
    }

    if (!m_systemConfig) {
        qWarning() << "❌ LocalControl: SystemConfig未设置";
        emit statusMessage("错误：系统配置未初始化");
        return;
    }

    // 就地模式：可选的停止连锁检查
    if (!checkStopInterlock()) {
        qWarning() << "❌ LocalControl: 停止连锁条件不满足";
        emit statusMessage("就地模式：停止条件不满足");
        return;
    }

    qDebug() << "  ➡️  调用公共控制停止逻辑";
    emit statusMessage("就地模式：停止皮带");

    // 调用CommonControl的停止方法（带停车音频 + 停止序列）
    // ✅ 2026-03-23 [Phase 7.48.84.5]: 优先使用DeviceRoleManager的localDeviceId
    // 旧代码：int beltNumber = m_systemConfig->machineNumber();
    int beltNumber = m_deviceRoleManager ? m_deviceRoleManager->localDeviceId() : m_systemConfig->machineNumber();
    m_commonControl->stopBelt(beltNumber);
}
