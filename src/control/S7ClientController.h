// S7ClientController.h
// 西门子 S7 客户端（主站）控制器类
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现 - 基于 Snap7 库
// TODO: 集成 Snap7 库后完善实现

#ifndef S7CLIENTCONTROLLER_H
#define S7CLIENTCONTROLLER_H

#include <QObject>
#include <QTimer>

// TODO: 集成 Snap7 库后取消注释
// #include "snap7.h"

class S7ClientController : public QObject
{
    Q_OBJECT

    // ========== 连接状态 ==========
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY isConnectedChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)

    // ========== S7配置 ==========
    Q_PROPERTY(QString targetIP READ targetIP WRITE setTargetIP NOTIFY targetIPChanged)
    Q_PROPERTY(int port READ port WRITE setPort NOTIFY portChanged)
    Q_PROPERTY(int rack READ rack WRITE setRack NOTIFY rackChanged)
    Q_PROPERTY(int slot READ slot WRITE setSlot NOTIFY slotChanged)
    Q_PROPERTY(QString connectionType READ connectionType WRITE setConnectionType NOTIFY connectionTypeChanged)

    // ========== TSAP配置 ==========
    Q_PROPERTY(QString localTSAP READ localTSAP WRITE setLocalTSAP NOTIFY localTSAPChanged)
    Q_PROPERTY(QString remoteTSAP READ remoteTSAP WRITE setRemoteTSAP NOTIFY remoteTSAPChanged)

    // ========== 轮询配置 ==========
    Q_PROPERTY(int pollInterval READ pollInterval WRITE setPollInterval NOTIFY pollIntervalChanged)
    Q_PROPERTY(int timeout READ timeout WRITE setTimeout NOTIFY timeoutChanged)

public:
    explicit S7ClientController(QObject *parent = nullptr);
    ~S7ClientController();

    // ========== 连接状态 ==========
    bool isConnected() const { return m_isConnected; }
    QString statusText() const { return m_statusText; }

    // ========== S7配置 ==========
    QString targetIP() const { return m_targetIP; }
    void setTargetIP(const QString &ip);

    int port() const { return m_port; }
    void setPort(int port);

    int rack() const { return m_rack; }
    void setRack(int rack);

    int slot() const { return m_slot; }
    void setSlot(int slot);

    QString connectionType() const { return m_connectionType; }
    void setConnectionType(const QString &type);

    // ========== TSAP配置 ==========
    QString localTSAP() const { return m_localTSAP; }
    void setLocalTSAP(const QString &tsap);

    QString remoteTSAP() const { return m_remoteTSAP; }
    void setRemoteTSAP(const QString &tsap);

    // ========== 轮询配置 ==========
    int pollInterval() const { return m_pollInterval; }
    void setPollInterval(int interval);

    int timeout() const { return m_timeout; }
    void setTimeout(int timeout);

    // ========== 客户端操作 ==========
    Q_INVOKABLE bool connectToPLC();
    Q_INVOKABLE void disconnectFromPLC();
    Q_INVOKABLE void startPolling();
    Q_INVOKABLE void stopPolling();

    // ========== 读取操作 ==========
    Q_INVOKABLE bool readDB(int dbNumber, int start, int size, QByteArray &data);
    Q_INVOKABLE bool readMerker(int start, int size, QByteArray &data);
    Q_INVOKABLE bool readInput(int start, int size, QByteArray &data);
    Q_INVOKABLE bool readOutput(int start, int size, QByteArray &data);

    // ========== 写入操作 ==========
    Q_INVOKABLE bool writeDB(int dbNumber, int start, const QByteArray &data);
    Q_INVOKABLE bool writeMerker(int start, const QByteArray &data);
    Q_INVOKABLE bool writeOutput(int start, const QByteArray &data);

signals:
    // ========== 属性变化信号 ==========
    void isConnectedChanged();
    void statusTextChanged();
    void targetIPChanged();
    void portChanged();
    void rackChanged();
    void slotChanged();
    void connectionTypeChanged();
    void localTSAPChanged();
    void remoteTSAPChanged();
    void pollIntervalChanged();
    void timeoutChanged();

    // ========== 数据读取信号 ==========
    void dataRead(int dbNumber, int start, const QByteArray &data);

    // ========== 错误信号 ==========
    void errorOccurred(const QString &error);

private slots:
    void handlePollTimeout();

private:
    // TODO: 集成 Snap7 库后添加
    // TS7Client *m_s7Client;

    // ========== S7配置 ==========
    QString m_targetIP;
    int m_port;
    int m_rack;
    int m_slot;
    QString m_connectionType;  // PG, OP, Basic

    // ========== TSAP配置 ==========
    QString m_localTSAP;
    QString m_remoteTSAP;

    // ========== 轮询配置 ==========
    int m_pollInterval;
    int m_timeout;
    QTimer *m_pollTimer;

    // ========== 状态 ==========
    bool m_isConnected;
    QString m_statusText;

    // ========== 辅助函数 ==========
    void updateStatusText();
};

#endif // S7CLIENTCONTROLLER_H
