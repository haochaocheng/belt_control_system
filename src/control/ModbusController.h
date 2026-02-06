// ✅ 2026-02-06: FIX 100.300.113 Phase 7.38.4 - ModbusController 使用 Qt SerialBus
// MODBUS RTU 控制器类 - 基于 Qt SerialBus 模块

#ifndef MODBUSCONTROLLER_H
#define MODBUSCONTROLLER_H

#include <QObject>
#include <QVariant>  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.7.1]: 添加 QVariant 头文件
#include <QModbusRtuSerialMaster>
#include <QModbusDataUnit>
#include <QModbusReply>
#include <QSerialPort>

class ModbusController : public QObject
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

public:
    explicit ModbusController(QObject *parent = nullptr);
    ~ModbusController();

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

    // ========== MODBUS 操作 ==========
    Q_INVOKABLE bool connectDevice();
    Q_INVOKABLE void disconnectDevice();

    Q_INVOKABLE void readHoldingRegisters(int serverAddress, int startAddress, int count);
    Q_INVOKABLE void writeSingleRegister(int serverAddress, int address, int value);
    Q_INVOKABLE void writeMultipleRegisters(int serverAddress, int startAddress, const QList<int> &values);

signals:
    // ========== 属性变化信号 ==========
    void isConnectedChanged();
    void statusTextChanged();
    void portNameChanged();
    void baudRateChanged();
    void dataBitsChanged();
    void stopBitsChanged();
    void parityChanged();

    // ========== MODBUS 响应信号 ==========
    void readRegistersFinished(int serverAddress, int startAddress, const QList<int> &values);
    void writeRegisterFinished(int serverAddress, int address, bool success);
    void writeRegistersFinished(int serverAddress, int startAddress, bool success);

    // ========== 错误信号 ==========
    void errorOccurred(const QString &error);

private slots:
    void handleStateChanged(QModbusDevice::State state);
    void handleErrorOccurred(QModbusDevice::Error error);
    void handleReadReady();
    void handleWriteReady();

private:
    // ========== MODBUS 设备 ==========
    QModbusRtuSerialMaster *m_modbusDevice;

    // ========== 串口配置 ==========
    QString m_portName;
    int m_baudRate;
    int m_dataBits;
    int m_stopBits;
    QString m_parity;

    // ========== 状态 ==========
    QString m_statusText;

    // ========== 辅助函数 ==========
    void updateStatusText();
    QSerialPort::Parity convertParity(const QString &parity);
};

#endif // MODBUSCONTROLLER_H
