// ✅ 2026-02-06: FIX 100.300.113 Phase 7.38.1 - SerialPortController 基础框架
// 串口控制器类 - 管理6个串口的配置和通信

#ifndef SERIALPORTCONTROLLER_H
#define SERIALPORTCONTROLLER_H

#include <QObject>
#include <QSerialPort>
#include <QMap>
#include <QTimer>
#include <QSettings>

// ✅ 2026-02-06: 串口配置结构体
struct SerialPortConfig {
    QString portName;        // COM1, COM2, COM3, COM4, COM5, COM6
    QString devicePath;      // /dev/ttyS0, /dev/ttyS7, /dev/ttyCH9344USB0, ...
    QString portType;        // RS422, RS232, RS485
    int baudRate;            // 波特率（默认 9600）
    int dataBits;            // 数据位（默认 8）
    int stopBits;            // 停止位（默认 1）
    QString parity;          // 校验位（默认 "None"）
    bool isOpen;             // 是否打开
};

class SerialPortController : public QObject
{
    Q_OBJECT

    // ========== 串口列表 ==========
    Q_PROPERTY(QStringList serialPorts READ serialPorts CONSTANT)

    // ========== 当前串口配置 ==========
    Q_PROPERTY(int currentPortIndex READ currentPortIndex WRITE setCurrentPortIndex NOTIFY currentPortIndexChanged)
    Q_PROPERTY(QString currentPortName READ currentPortName NOTIFY currentPortNameChanged)
    Q_PROPERTY(QString devicePath READ devicePath NOTIFY devicePathChanged)
    Q_PROPERTY(QString portType READ portType NOTIFY portTypeChanged)
    Q_PROPERTY(int baudRate READ baudRate WRITE setBaudRate NOTIFY baudRateChanged)
    Q_PROPERTY(int dataBits READ dataBits WRITE setDataBits NOTIFY dataBitsChanged)
    Q_PROPERTY(int stopBits READ stopBits WRITE setStopBits NOTIFY stopBitsChanged)
    Q_PROPERTY(QString parity READ parity WRITE setParity NOTIFY parityChanged)
    Q_PROPERTY(bool isOpen READ isOpen NOTIFY isOpenChanged)

    // ========== 接收缓冲区 ==========
    Q_PROPERTY(QString receiveBuffer READ receiveBuffer NOTIFY receiveBufferChanged)
    Q_PROPERTY(bool receiveHexMode READ receiveHexMode WRITE setReceiveHexMode NOTIFY receiveHexModeChanged)

public:
    explicit SerialPortController(QObject *parent = nullptr);
    ~SerialPortController();

    // ========== 串口列表 ==========
    QStringList serialPorts() const;

    // ========== 当前串口配置 ==========
    int currentPortIndex() const { return m_currentPortIndex; }
    void setCurrentPortIndex(int index);

    QString currentPortName() const;
    QString devicePath() const;
    QString portType() const;

    int baudRate() const;
    void setBaudRate(int rate);

    int dataBits() const;
    void setDataBits(int bits);

    int stopBits() const;
    void setStopBits(int bits);

    QString parity() const;
    void setParity(const QString &parity);

    bool isOpen() const;

    // ========== 接收缓冲区 ==========
    QString receiveBuffer() const { return m_receiveBuffer; }
    bool receiveHexMode() const { return m_receiveHexMode; }
    void setReceiveHexMode(bool hexMode);

    // ========== 串口操作 ==========
    Q_INVOKABLE bool openSerialPort();
    Q_INVOKABLE void closeSerialPort();
    Q_INVOKABLE void sendData(const QString &data, bool isHex);
    Q_INVOKABLE void clearReceiveBuffer();

    // ========== MODBUS RTU 操作 ==========
    Q_INVOKABLE void readHoldingRegisters(int slaveAddress, int startAddress, int quantity);
    Q_INVOKABLE void writeSingleRegister(int slaveAddress, int address, int value);
    Q_INVOKABLE void writeMultipleRegisters(int slaveAddress, int startAddress, const QList<int> &values);

    // ========== 数据持久化 ==========
    Q_INVOKABLE void saveConfig();
    Q_INVOKABLE void loadConfig();
    Q_INVOKABLE void resetConfig();

signals:
    // ========== 属性变化信号 ==========
    void currentPortIndexChanged();
    void currentPortNameChanged();
    void devicePathChanged();
    void portTypeChanged();
    void baudRateChanged();
    void dataBitsChanged();
    void stopBitsChanged();
    void parityChanged();
    void isOpenChanged();
    void receiveBufferChanged();
    void receiveHexModeChanged();

    // ========== 数据接收信号 ==========
    void dataReceived(const QByteArray &data);
    void modbusResponseReceived(int slaveAddress, int functionCode, const QByteArray &data);

    // ========== 错误信号 ==========
    void errorOccurred(const QString &error);

private slots:
    void handleReadyRead();
    void handleError(QSerialPort::SerialPortError error);
    void handleModbusTimeout();
    void handleDataTimeout();  // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.13]: 数据超时处理

private:
    // ========== 串口配置 ==========
    QList<SerialPortConfig> m_serialPortConfigs;  // 6个串口配置
    int m_currentPortIndex;                        // 当前串口索引 (0-5)
    QMap<int, QSerialPort*> m_serialPorts;         // 串口对象映射（索引 -> 串口对象）
    QSerialPort *m_currentSerialPort;              // 当前串口对象

    // ========== 接收缓冲区 ==========
    QString m_receiveBuffer;
    bool m_receiveHexMode;
    QByteArray m_modbusBuffer;  // MODBUS 响应缓冲区

    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.13]: 数据拼接缓冲区
    QByteArray m_dataBuffer;    // 数据拼接缓冲区（用于处理分包）
    QTimer *m_dataTimer;        // 数据超时定时器（用于判断一帧数据结束）

    // ========== MODBUS 超时定时器 ==========
    QTimer *m_modbusTimer;
    int m_pendingSlaveAddress;
    int m_pendingFunctionCode;

    // ========== 数据持久化 ==========
    QSettings *m_settings;

    // ========== 辅助函数 ==========
    void initSerialPortConfigs();
    QSerialPort* getOrCreateSerialPort(int portIndex);

    // MODBUS 协议辅助函数
    QByteArray hexStringToByteArray(const QString &hex);
    QString byteArrayToHexString(const QByteArray &data);
    QByteArray buildModbusRequest(int slaveAddress, int functionCode,
                                   int startAddress, int quantity,
                                   const QList<int> &values = QList<int>());
    bool parseModbusResponse(const QByteArray &response,
                             int &slaveAddress, int &functionCode,
                             QByteArray &data);
    quint16 calculateCRC16(const QByteArray &data);
    bool isModbusResponseComplete(const QByteArray &buffer);
    void parseAndEmitModbusResponse();
};

#endif // SERIALPORTCONTROLLER_H
