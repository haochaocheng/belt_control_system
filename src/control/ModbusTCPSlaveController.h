// ModbusTCPSlaveController.h
// Modbus TCP 从站控制器类
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现 - 基于 Qt SerialBus 模块

#ifndef MODBUSTCPSLAVECONTROLLER_H
#define MODBUSTCPSLAVECONTROLLER_H

#include <QObject>
#include <QModbusTcpServer>
#include <QModbusDataUnit>

class ModbusTCPSlaveController : public QObject
{
    Q_OBJECT

    // ========== 连接状态 ==========
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY isConnectedChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)

    // ========== TCP配置 ==========
    Q_PROPERTY(int port READ port WRITE setPort NOTIFY portChanged)
    Q_PROPERTY(int slaveAddress READ slaveAddress WRITE setSlaveAddress NOTIFY slaveAddressChanged)
    Q_PROPERTY(int maxConnections READ maxConnections WRITE setMaxConnections NOTIFY maxConnectionsChanged)

public:
    explicit ModbusTCPSlaveController(QObject *parent = nullptr);
    ~ModbusTCPSlaveController();

    // ========== 连接状态 ==========
    bool isConnected() const;
    QString statusText() const { return m_statusText; }

    // ========== TCP配置 ==========
    int port() const { return m_port; }
    void setPort(int port);

    int slaveAddress() const { return m_slaveAddress; }
    void setSlaveAddress(int address);

    int maxConnections() const { return m_maxConnections; }
    void setMaxConnections(int max);

    // ========== 从站操作 ==========
    Q_INVOKABLE bool startServer();
    Q_INVOKABLE void stopServer();

    // ========== 寄存器操作 ==========
    Q_INVOKABLE bool setHoldingRegister(int address, int value);
    Q_INVOKABLE int getHoldingRegister(int address);
    Q_INVOKABLE bool setHoldingRegisters(int startAddress, const QList<int> &values);
    Q_INVOKABLE QList<int> getHoldingRegisters(int startAddress, int count);

    Q_INVOKABLE bool setInputRegister(int address, int value);
    Q_INVOKABLE int getInputRegister(int address);
    Q_INVOKABLE bool setInputRegisters(int startAddress, const QList<int> &values);
    Q_INVOKABLE QList<int> getInputRegisters(int startAddress, int count);

    Q_INVOKABLE bool setCoil(int address, bool value);
    Q_INVOKABLE bool getCoil(int address);
    Q_INVOKABLE bool setCoils(int startAddress, const QList<bool> &values);
    Q_INVOKABLE QList<bool> getCoils(int startAddress, int count);

    Q_INVOKABLE bool setDiscreteInput(int address, bool value);
    Q_INVOKABLE bool getDiscreteInput(int address);
    Q_INVOKABLE bool setDiscreteInputs(int startAddress, const QList<bool> &values);
    Q_INVOKABLE QList<bool> getDiscreteInputs(int startAddress, int count);

    // ========== 寄存器映射管理 ==========
    Q_INVOKABLE void initializeRegisters(int holdingCount = 100, int inputCount = 100,
                                         int coilCount = 100, int discreteCount = 100);
    Q_INVOKABLE void clearAllRegisters();

signals:
    // ========== 属性变化信号 ==========
    void isConnectedChanged();
    void statusTextChanged();
    void portChanged();
    void slaveAddressChanged();
    void maxConnectionsChanged();

    // ========== 数据访问信号 ==========
    void holdingRegisterRead(int address, int value);
    void holdingRegisterWritten(int address, int value);
    void inputRegisterRead(int address, int value);
    void coilRead(int address, bool value);
    void coilWritten(int address, bool value);
    void discreteInputRead(int address, bool value);

    // ========== 错误信号 ==========
    void errorOccurred(const QString &error);

private slots:
    void handleStateChanged(QModbusDevice::State state);
    void handleErrorOccurred(QModbusDevice::Error error);
    void handleDataWritten(QModbusDataUnit::RegisterType table, int address, int size);

private:
    // ========== MODBUS TCP 服务器 ==========
    QModbusTcpServer *m_modbusServer;

    // ========== TCP配置 ==========
    int m_port;
    int m_slaveAddress;
    int m_maxConnections;

    // ========== 状态 ==========
    QString m_statusText;

    // ========== 辅助函数 ==========
    void updateStatusText();
};

#endif // MODBUSTCPSLAVECONTROLLER_H
