// ✅ 2026-02-07: Phase 7.39.1 - CANController 基础框架
// CAN 控制器类 - 管理2个CAN接口的配置和通信

#ifndef CANCONTROLLER_H
#define CANCONTROLLER_H

#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QSettings>
#include <QStringList>

// ✅ 2026-02-07: CAN 配置结构体
struct CANConfig {
    QString canName;         // CAN0, CAN1
    QString canInterface;    // can0, can1
    int bitrate;             // 波特率（125000, 250000, 500000, 1000000）
    QString frameType;       // 帧类型（"标准帧", "扩展帧"）
    bool isUp;               // 是否启动
};

class CANController : public QObject
{
    Q_OBJECT

    // ========== CAN 列表 ==========
    Q_PROPERTY(QStringList canInterfaces READ canInterfaces CONSTANT)

    // ========== 当前 CAN 配置 ==========
    Q_PROPERTY(int currentCanIndex READ currentCanIndex WRITE setCurrentCanIndex NOTIFY currentCanIndexChanged)
    Q_PROPERTY(QString currentCanName READ currentCanName NOTIFY currentCanNameChanged)
    Q_PROPERTY(QString canInterface READ canInterface NOTIFY canInterfaceChanged)
    Q_PROPERTY(int bitrate READ bitrate WRITE setBitrate NOTIFY bitrateChanged)
    Q_PROPERTY(QString frameType READ frameType WRITE setFrameType NOTIFY frameTypeChanged)
    Q_PROPERTY(bool isUp READ isUp NOTIFY isUpChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

    // ========== 接收缓冲区 ==========
    Q_PROPERTY(QString receiveBuffer READ receiveBuffer NOTIFY receiveBufferChanged)

public:
    explicit CANController(QObject *parent = nullptr);
    ~CANController();

    // ========== CAN 列表 ==========
    QStringList canInterfaces() const;

    // ========== 当前 CAN 配置 ==========
    int currentCanIndex() const { return m_currentCanIndex; }
    void setCurrentCanIndex(int index);

    QString currentCanName() const;
    QString canInterface() const;

    int bitrate() const;
    void setBitrate(int rate);

    QString frameType() const;
    void setFrameType(const QString &type);

    bool isUp() const;
    QString status() const;

    // ========== 接收缓冲区 ==========
    QString receiveBuffer() const { return m_receiveBuffer; }

    // ========== CAN 操作 ==========
    Q_INVOKABLE bool openCAN();
    Q_INVOKABLE void closeCAN();
    Q_INVOKABLE bool sendData(const QString &canId, const QString &data);
    Q_INVOKABLE void clearReceiveBuffer();

    // ========== 数据持久化 ==========
    Q_INVOKABLE void saveConfig();
    Q_INVOKABLE void loadConfig();
    Q_INVOKABLE void resetConfig();

signals:
    // ========== 属性变化信号 ==========
    void currentCanIndexChanged();
    void currentCanNameChanged();
    void canInterfaceChanged();
    void bitrateChanged();
    void frameTypeChanged();
    void isUpChanged();
    void statusChanged();
    void receiveBufferChanged();

    // ========== 数据接收信号 ==========
    void dataReceived(const QString &canId, const QString &data, const QString &timestamp);

    // ========== 错误信号 ==========
    void errorOccurred(const QString &error);

private slots:
    void handleReceiveData();
    void handleReceiveError();
    void handleReceiveFinished(int exitCode, QProcess::ExitStatus exitStatus);

private:
    // ========== 辅助函数 ==========
    void initializeConfigs();
    void updateStatus();
    bool checkCANInterface(const QString &interface);
    QString parseCANFrame(const QString &line, QString &canId, QString &data);

    // ========== CAN 配置 ==========
    QList<CANConfig> m_canConfigs;      // 2个CAN配置
    int m_currentCanIndex;               // 当前CAN索引 (0-1)

    // ========== 接收进程 ==========
    QProcess *m_receiveProcess;          // candump 接收进程

    // ========== 接收缓冲区 ==========
    QString m_receiveBuffer;

    // ========== 数据持久化 ==========
    QSettings *m_settings;

    // ========== 辅助函数 ==========
    void initSettings();
    void loadConfigFromSettings();
    void saveConfigToSettings();
};

#endif // CANCONTROLLER_H
