#ifndef MAINTENANCECONTROL_H
#define MAINTENANCECONTROL_H

#include <QObject>

// 前向声明
class CommonControl;
class SystemConfig;

/**
 * @brief 检修模式控制类 - 没有连锁控制
 *
 * 功能：
 * - 接收启动/停止命令（R键/S键或其他触发方式）
 * - 不检查连锁条件，直接执行
 * - 调用CommonControl执行公共控制逻辑（预警、设备序列、反馈检测等）
 */
class MaintenanceControl : public QObject
{
    Q_OBJECT

public:
    explicit MaintenanceControl(QObject *parent = nullptr);
    ~MaintenanceControl();

    // 设置CommonControl引用
    void setCommonControl(CommonControl *commonControl);

    // 设置SystemConfig引用
    void setSystemConfig(SystemConfig *systemConfig);

public slots:
    /**
     * @brief 处理启动命令（检修模式：无连锁，直接启动）
     */
    void handleStart();

    /**
     * @brief 处理停止命令（检修模式：无连锁，直接停止）
     */
    void handleStop();

signals:
    void statusMessage(const QString &message);  // 状态消息

private:
    CommonControl *m_commonControl;
    SystemConfig *m_systemConfig;
};

#endif // MAINTENANCECONTROL_H
