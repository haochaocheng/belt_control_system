// ✅ 2026-02-06: FIX 100.300.113 Phase 7.40 - ModbusSlaveController RTU 从站
// MODBUS RTU 从站控制器类 - 基于 Qt SerialBus 模块

#ifndef MODBUSSLAVECONTROLLER_H
#define MODBUSSLAVECONTROLLER_H

#include <QObject>
#include <QModbusRtuSerialServer>
#include <QModbusDataUnit>
#include <QSerialPort>
#include <QMap>

class ModbusSlaveController : public QObject
{
    Q_OBJECT

    // ========== 连接状态 ==========
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY isConnectedChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)

    // ========== 串口配置 ==========
    Q_PROPERTY(QString portName READ portName WRITE setPortName NOTIFY portNameChanged)
    Q_PROPERTY(int baudRate READ baudRate WRITE setBaudRate NOTIFY baudRateChanged)
    Q_PROPERTY(int dataBits READ dataBits WRITE setDataBits NOTIFY dataBitsChanged)
    Q_PROPERTY(int stopBits READ stopBits WRITE setStopBits NOTIFY stopBitsChanged)
    Q_PROPERTY(QString parity READ parity WRITE setParity NOTIFY parityChanged)

    // ========== 从站地址 ==========
    Q_PROPERTY(int slaveAddress READ slaveAddress WRITE setSlaveAddress NOTIFY slaveAddressChanged)

public:
    explicit ModbusSlaveController(QObject *parent = nullptr);
    ~ModbusSlaveController();

    // ========== 连接状态 ==========
    bool isConnected() const;
    QString statusText() const { return m_statusText; }

    // ========== 串口配置 ==========
    QString portName() const { return m_portName; }
    void setPortName(const QString &portName);

    int baudRate() const { return m_baudRate; }
    void setBaudRate(int baudRate);

    int dataBits() const { return m_dataBits; }
    void setDataBits(int dataBits);

    int stopBits() const { return m_stopBits; }
    void setStopBits(int stopBits);

    QString parity() const { return m_parity; }
    void setParity(const QString &parity);

    // ========== 从站地址 ==========
    int slaveAddress() const { return m_slaveAddress; }
    void setSlaveAddress(int address);

    // ========== 从站操作 ==========
    Q_INVOKABLE bool startSlave();
    Q_INVOKABLE void stopSlave();

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
    void portNameChanged();
    void baudRateChanged();
    void dataBitsChanged();
    void stopBitsChanged();
    void parityChanged();
    void slaveAddressChanged();

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
    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.41.3]: 添加串口数据接收调试槽函数
    void handleSerialPortReadyRead();
    void handleSerialPortError(QSerialPort::SerialPortError error);

private:
    // ========== MODBUS 从站设备 ==========
    QModbusRtuSerialServer *m_modbusServer;

    // ========== 串口配置 ==========
    QString m_portName;
    int m_baudRate;
    int m_dataBits;
    int m_stopBits;
    QString m_parity;

    // ========== 从站地址 ==========
    int m_slaveAddress;

    // ========== 状态 ==========
    QString m_statusText;

    // ========== 辅助函数 ==========
    void updateStatusText();
    QSerialPort::Parity convertParity(const QString &parity);
    QSerialPort::DataBits convertDataBits(int dataBits);
    QSerialPort::StopBits convertStopBits(int stopBits);
};

#endif // MODBUSSLAVECONTROLLER_H
