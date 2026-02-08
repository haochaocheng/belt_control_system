// ModbusTCPMasterController.h
// Modbus TCP 主站控制器类
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现 - 基于 Qt SerialBus 模块

#ifndef MODBUSTCPMASTERCONTROLLER_H
#define MODBUSTCPMASTERCONTROLLER_H

#include <QObject>
#include <QModbusTcpClient>
#include <QModbusDataUnit>
#include <QModbusReply>
#include <QTimer>

class ModbusTCPMasterController : public QObject
{
    Q_OBJECT

    // ========== 连接状态 ==========
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY isConnectedChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)

    // ========== TCP配置 ==========
    Q_PROPERTY(QString targetIP READ targetIP WRITE setTargetIP NOTIFY targetIPChanged)
    Q_PROPERTY(int port READ port WRITE setPort NOTIFY portChanged)
    Q_PROPERTY(int slaveAddress READ slaveAddress WRITE setSlaveAddress NOTIFY slaveAddressChanged)

    // ========== 轮询配置 ==========
    Q_PROPERTY(int pollInterval READ pollInterval WRITE setPollInterval NOTIFY pollIntervalChanged)
    Q_PROPERTY(int timeout READ timeout WRITE setTimeout NOTIFY timeoutChanged)
    Q_PROPERTY(int retryCount READ retryCount WRITE setRetryCount NOTIFY retryCountChanged)

public:
    explicit ModbusTCPMasterController(QObject *parent = nullptr);
    ~ModbusTCPMasterController();

    // ========== 连接状态 ==========
    bool isConnected() const;
    QString statusText() const { return m_statusText; }

    // ========== TCP配置 ==========
    QString targetIP() const { return m_targetIP; }
    void setTargetIP(const QString &ip);

    int port() const { return m_port; }
    void setPort(int port);

    int slaveAddress() const { return m_slaveAddress; }
    void setSlaveAddress(int address);

    // ========== 轮询配置 ==========
    int pollInterval() const { return m_pollInterval; }
    void setPollInterval(int interval);

    int timeout() const { return m_timeout; }
    void setTimeout(int timeout);

    int retryCount() const { return m_retryCount; }
    void setRetryCount(int count);

    // ========== 主站操作 ==========
    Q_INVOKABLE bool connectToServer();
    Q_INVOKABLE void disconnectFromServer();
    Q_INVOKABLE void startPolling();
    Q_INVOKABLE void stopPolling();

    // ========== 读取操作 ==========
    Q_INVOKABLE bool readHoldingRegisters(int startAddress, int count);
    Q_INVOKABLE bool readInputRegisters(int startAddress, int count);
    Q_INVOKABLE bool readCoils(int startAddress, int count);
    Q_INVOKABLE bool readDiscreteInputs(int startAddress, int count);

    // ========== 写入操作 ==========
    Q_INVOKABLE bool writeHoldingRegister(int address, int value);
    Q_INVOKABLE bool writeHoldingRegisters(int startAddress, const QList<int> &values);
    Q_INVOKABLE bool writeCoil(int address, bool value);
    Q_INVOKABLE bool writeCoils(int startAddress, const QList<bool> &values);

signals:
    // ========== 属性变化信号 ==========
    void isConnectedChanged();
    void statusTextChanged();
    void targetIPChanged();
    void portChanged();
    void slaveAddressChanged();
    void pollIntervalChanged();
    void timeoutChanged();
    void retryCountChanged();

    // ========== 数据读取信号 ==========
    void holdingRegistersRead(int startAddress, const QList<int> &values);
    void inputRegistersRead(int startAddress, const QList<int> &values);
    void coilsRead(int startAddress, const QList<bool> &values);
    void discreteInputsRead(int startAddress, const QList<bool> &values);

    // ========== 数据写入信号 ==========
    void holdingRegisterWritten(int address, int value);
    void holdingRegistersWritten(int startAddress, int count);
    void coilWritten(int address, bool value);
    void coilsWritten(int startAddress, int count);

    // ========== 错误信号 ==========
    void errorOccurred(const QString &error);

private slots:
    void handleStateChanged(QModbusDevice::State state);
    void handleErrorOccurred(QModbusDevice::Error error);
    void handleReadReady();
    void handlePollTimeout();

private:
    // ========== MODBUS TCP 客户端 ==========
    QModbusTcpClient *m_modbusClient;

    // ========== TCP配置 ==========
    QString m_targetIP;
    int m_port;
    int m_slaveAddress;

    // ========== 轮询配置 ==========
    int m_pollInterval;  // 毫秒
    int m_timeout;       // 毫秒
    int m_retryCount;
    QTimer *m_pollTimer;

    // ========== 状态 ==========
    QString m_statusText;

    // ========== 辅助函数 ==========
    void updateStatusText();
};

#endif // MODBUSTCPMASTERCONTROLLER_H
