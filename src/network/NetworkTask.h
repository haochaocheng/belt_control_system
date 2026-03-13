#ifndef NETWORKTASK_H
#define NETWORKTASK_H

#include <QObject>
#include <QTimer>
#include <QMap>
#include "ModbusTcpClient.h"

class SystemConfig;

/**
 * @brief 网络任务管理类
 *
 * 负责定时轮询Modbus TCP设备，读取寄存器值
 * ✅ 2026-03-13: 新增电机保护Modbus TCP轮询（8电机×9保护，PT100/4-20mA）
 */
class NetworkTask : public QObject
{
    Q_OBJECT

public:
    explicit NetworkTask(QObject *parent = nullptr);
    ~NetworkTask();

    // 设置系统配置
    void setSystemConfig(SystemConfig *config);

    // 启动网络任务
    void start();

    // 停止网络任务
    void stop();

    // 检查任务是否运行中
    bool isRunning() const { return m_isRunning; }

    // 获取Modbus客户端
    ModbusTcpClient* modbusClient() { return m_modbusClient; }

    // 设备控制 - 根据寄存器地址和通道号控制设备
    Q_INVOKABLE void writeDeviceControl(int registerAddress, int channel, bool turnOn);

    // 读取特定寄存器（用于按需读取）
    Q_INVOKABLE void readRegister(int registerAddress, int count = 1);

    // ✅ 2026-03-13: 电机保护Modbus TCP测试模式
    // 连接到模拟从站(192.168.10.142)，轮询8电机×9保护寄存器
    Q_INVOKABLE void setMotorTestMode(bool enabled, const QString &ip = "192.168.10.142", int port = 502);
    bool motorTestMode() const { return m_motorTestMode; }

    // 电机保护寄存器映射常量
    static const int MOTOR_COUNT = 8;           // 8个电机
    static const int REGS_PER_MOTOR = 12;       // 每电机12个寄存器（9用+3备用）
    static const int MOTOR_PROTECTIONS = 9;     // 每电机9个保护通道
    static const int TOTAL_MOTOR_REGS = 96;     // 总寄存器数 8×12=96

    // 寄存器偏移 → Tab索引映射（偏移0=Tab1电流, 偏移1=Tab2前轴承温度, ...）
    static int offsetToTabIndex(int offset) { return offset + 1; }

signals:
    // 读取到寄存器值（旧信号，保持兼容）
    void registerValueReceived(int address, quint16 value);

    // 连接状态改变
    void connectionStatusChanged(bool connected);

    // ✅ 2026-03-13: 电机保护寄存器值接收信号
    // motorIndex: 电机索引（0-7）
    // tabIndex: 保护Tab索引（1=电流, 2=前轴承温度, ..., 9=Y轴振动）
    // rawValue: Modbus原始寄存器值（0-4095）
    void motorRegisterReceived(int motorIndex, int tabIndex, quint16 rawValue);

private slots:
    void onPollTimerTimeout();
    void onConnectionStateChanged(bool connected);
    void onReadSuccess(int startAddress, const QVector<quint16> &values);
    void onReadError(const QString &errorString);

private:
    void connectToServer();
    void updatePollInterval();
    void sendNextRequest();  // 发送队列中的下一个请求
    void processMotorRegisters(int startAddress, const QVector<quint16> &values);  // ✅ 2026-03-13

private:
    SystemConfig *m_systemConfig;
    ModbusTcpClient *m_modbusClient;
    QTimer *m_pollTimer;
    bool m_isRunning;
    bool m_isConnected;

    // 用于存储上次读取的寄存器值，只在值变化时打印日志
    QMap<int, quint16> m_lastRegisterValues;

    // 请求队列相关
    struct ReadRequest {
        int startAddress;
        int count;
    };
    QList<ReadRequest> m_requestQueue;  // 请求队列
    bool m_isRequestInProgress;         // 是否有请求正在处理中

    // ✅ 2026-03-13: 电机保护测试模式
    bool m_motorTestMode;
    QString m_motorTestIp;
    int m_motorTestPort;
};

#endif // NETWORKTASK_H
