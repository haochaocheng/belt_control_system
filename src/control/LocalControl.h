#ifndef LOCALCONTROL_H
#define LOCALCONTROL_H

#include <QObject>

// 前向声明
class CommonControl;
class SystemConfig;

/**
 * @brief 就地模式控制类 - 有连锁控制
 *
 * 功能：
 * - 接收启动/停止命令（R键/S键或其他触发方式）
 * - 检查连锁条件（例如：安全门、急停、设备状态等）
 * - 满足条件后调用CommonControl执行公共控制逻辑
 */
class LocalControl : public QObject
{
    Q_OBJECT

public:
    explicit LocalControl(QObject *parent = nullptr);
    ~LocalControl();

    // 设置CommonControl引用
    void setCommonControl(CommonControl *commonControl);

    // 设置SystemConfig引用
    void setSystemConfig(SystemConfig *systemConfig);

public slots:
    /**
     * @brief 处理启动命令（就地模式：检查连锁条件后启动）
     */
    void handleStart();

    /**
     * @brief 处理停止命令（就地模式：可能需要检查停止条件）
     */
    void handleStop();

signals:
    void statusMessage(const QString &message);  // 状态消息

private:
    CommonControl *m_commonControl;
    SystemConfig *m_systemConfig;

    /**
     * @brief 检查启动连锁条件
     * @return true=满足条件可以启动, false=不满足条件禁止启动
     */
    bool checkStartInterlock();

    /**
     * @brief 检查停止连锁条件（可选）
     * @return true=满足条件可以停止, false=不满足条件
     */
    bool checkStopInterlock();
};

#endif // LOCALCONTROL_H
