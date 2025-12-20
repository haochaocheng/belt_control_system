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

signals:
    // 读取到寄存器值
    void registerValueReceived(int address, quint16 value);

    // 连接状态改变
    void connectionStatusChanged(bool connected);

private slots:
    void onPollTimerTimeout();
    void onConnectionStateChanged(bool connected);
    void onReadSuccess(int startAddress, const QVector<quint16> &values);
    void onReadError(const QString &errorString);

private:
    void connectToServer();
    void updatePollInterval();
    void sendNextRequest();  // 发送队列中的下一个请求

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
};

#endif // NETWORKTASK_H
