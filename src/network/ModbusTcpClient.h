#ifndef MODBUSTCPCLIENT_H
#define MODBUSTCPCLIENT_H

#include <QObject>
#include <QModbusTcpClient>
#include <QModbusDataUnit>
#include <QModbusReply>

/**
 * @brief Modbus TCP客户端类
 *
 * 负责连接Modbus TCP服务器（从站），读取/写入寄存器
 */
class ModbusTcpClient : public QObject
{
    Q_OBJECT

public:
    explicit ModbusTcpClient(QObject *parent = nullptr);
    ~ModbusTcpClient();

    // 连接到Modbus TCP服务器
    bool connectToServer(const QString &host, int port = 502);

    // 断开连接
    void disconnectFromServer();

    // 检查连接状态
    bool isConnected() const;

    // 读取保持寄存器（功能码0x03）
    void readHoldingRegisters(int startAddress, int count);

    // 写入单个保持寄存器（功能码0x06）
    void writeSingleRegister(int address, quint16 value);

    // 获取服务器地址
    QString serverAddress() const { return m_serverAddress; }
    int serverPort() const { return m_serverPort; }

signals:
    // 连接状态改变
    void connectionStateChanged(bool connected);

    // 读取成功
    void readSuccess(int startAddress, const QVector<quint16> &values);

    // 读取失败
    void readError(const QString &errorString);

    // 写入成功
    void writeSuccess(int address);

    // 写入失败
    void writeError(const QString &errorString);

private slots:
    void onStateChanged(QModbusDevice::State state);
    void onReadReady();
    void onErrorOccurred(QModbusDevice::Error error);

private:
    QModbusTcpClient *m_modbusClient;
    QString m_serverAddress;
    int m_serverPort;
    bool m_isConnected;
};

#endif // MODBUSTCPCLIENT_H
