// S7ClientController.cpp
// 西门子 S7 客户端（主站）控制器实现
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现 - 基于 Snap7 库
// ✅ 2026-02-08 [Phase 7.42.5]: 集成 Snap7 库实现
// ✅ 2026-04-11 [Phase 7.48.88.110]: 添加pduSize属性 + saveConfig/loadConfig持久化

#include "S7ClientController.h"
#include <QDebug>

S7ClientController::S7ClientController(QObject *parent)
    : QObject(parent)
    , m_targetIP("192.168.0.1")
    , m_port(102)
    , m_rack(0)
    , m_slot(2)
    , m_connectionType("PG")
    , m_localTSAP("0x0100")
    , m_remoteTSAP("0x0302")
    , m_pduSize(480)
    , m_pollInterval(1000)
    , m_timeout(5000)
    , m_pollTimer(new QTimer(this))
    , m_isConnected(false)
    , m_statusText("未连接")
    , m_settings(nullptr)
{
#ifdef ENABLE_SNAP7
    // ✅ 2026-02-08 [Phase 7.42.5]: 初始化 Snap7 客户端
    m_s7Client = new TS7Client();
    qDebug() << "✅ [S7ClientController] 初始化完成（Snap7支持已启用）";
#else
    qDebug() << "⚠️ [S7ClientController] 初始化完成（Snap7未启用，S7功能不可用）";
#endif

    // 配置轮询定时器
    connect(m_pollTimer, &QTimer::timeout,
            this, &S7ClientController::handlePollTimeout);

    // ✅ 2026-04-11 [Phase 7.48.88.110]: 初始化配置
    initSettings();
}

S7ClientController::~S7ClientController()
{
    disconnectFromPLC();
#ifdef ENABLE_SNAP7
    // ✅ 2026-02-08 [Phase 7.42.5]: 释放 Snap7 客户端资源
    delete m_s7Client;
#endif
}

// ========== S7配置 ==========
void S7ClientController::setTargetIP(const QString &ip)
{
    if (m_targetIP != ip) {
        m_targetIP = ip;
        emit targetIPChanged();
    }
}

void S7ClientController::setPort(int port)
{
    if (m_port != port) {
        m_port = port;
        emit portChanged();
    }
}

void S7ClientController::setRack(int rack)
{
    if (m_rack != rack) {
        m_rack = rack;
        emit rackChanged();
    }
}

void S7ClientController::setSlot(int slot)
{
    if (m_slot != slot) {
        m_slot = slot;
        emit slotChanged();
    }
}

void S7ClientController::setConnectionType(const QString &type)
{
    if (m_connectionType != type) {
        m_connectionType = type;
        emit connectionTypeChanged();
    }
}

// ========== TSAP配置 ==========
void S7ClientController::setLocalTSAP(const QString &tsap)
{
    if (m_localTSAP != tsap) {
        m_localTSAP = tsap;
        emit localTSAPChanged();
    }
}

void S7ClientController::setRemoteTSAP(const QString &tsap)
{
    if (m_remoteTSAP != tsap) {
        m_remoteTSAP = tsap;
        emit remoteTSAPChanged();
    }
}

// ========== PDU配置 ==========
void S7ClientController::setPduSize(int size)
{
    if (m_pduSize != size) {
        m_pduSize = size;
        emit pduSizeChanged();
    }
}

// ========== 轮询配置 ==========
void S7ClientController::setPollInterval(int interval)
{
    if (m_pollInterval != interval) {
        m_pollInterval = interval;
        emit pollIntervalChanged();
    }
}

void S7ClientController::setTimeout(int timeout)
{
    if (m_timeout != timeout) {
        m_timeout = timeout;
        emit timeoutChanged();
    }
}

// ========== 客户端操作 ==========
bool S7ClientController::connectToPLC()
{
#ifdef ENABLE_SNAP7
    if (!m_s7Client) {
        qWarning() << "❌ [S7ClientController] S7客户端未初始化";
        return false;
    }

    qDebug() << "🔌 [S7ClientController] 连接到PLC...";
    qDebug() << "  目标IP:" << m_targetIP;
    qDebug() << "  Rack:" << m_rack << "Slot:" << m_slot;

    // 使用 ConnectTo 方法连接到 PLC
    // ✅ 2026-04-11 [Phase 7.48.88.110]: 连接前设置PDU大小
    if (m_pduSize > 0) {
        int pduRequest = m_pduSize;
        m_s7Client->SetParam(p_i32_PDURequest, &pduRequest);
        qDebug() << "  PDU请求大小:" << m_pduSize;
    }

    int result = m_s7Client->ConnectTo(m_targetIP.toStdString().c_str(), m_rack, m_slot);

    if (result == 0) {
        m_isConnected = true;
        updateStatusText();
        emit isConnectedChanged();
        qDebug() << "✅ [S7ClientController] 连接成功";
        return true;
    } else {
        QString errorMsg = QString("连接失败 (错误码: %1)").arg(result);
        qWarning() << "❌ [S7ClientController]" << errorMsg;
        emit errorOccurred(errorMsg);
        return false;
    }
#else
    qWarning() << "⚠️ [S7ClientController] Snap7未启用，无法连接";
    emit errorOccurred("Snap7库未启用");
    return false;
#endif
}

void S7ClientController::disconnectFromPLC()
{
    if (m_isConnected) {
        stopPolling();
#ifdef ENABLE_SNAP7
        if (m_s7Client) {
            m_s7Client->Disconnect();
        }
#endif
        m_isConnected = false;
        updateStatusText();
        emit isConnectedChanged();
        qDebug() << "✅ [S7ClientController] 已断开连接";
    }
}

void S7ClientController::startPolling()
{
    if (m_pollInterval > 0) {
        m_pollTimer->start(m_pollInterval);
        qDebug() << "✅ [S7ClientController] 开始轮询 - 间隔:" << m_pollInterval << "ms";
    }
}

void S7ClientController::stopPolling()
{
    m_pollTimer->stop();
    qDebug() << "✅ [S7ClientController] 停止轮询";
}

// ========== 读取操作 ==========
bool S7ClientController::readDB(int dbNumber, int start, int size, QByteArray &data)
{
#ifdef ENABLE_SNAP7
    if (!m_s7Client || !m_isConnected) {
        qWarning() << "❌ [S7ClientController] 未连接到PLC";
        return false;
    }

    // 分配缓冲区
    QByteArray buffer(size, 0);

    // 调用 Snap7 的 DBRead 方法
    int result = m_s7Client->DBRead(dbNumber, start, size, buffer.data());

    if (result == 0) {
        data = buffer;
        qDebug() << "✅ [S7ClientController] 读取DB成功 - DB" << dbNumber
                 << "起始:" << start << "大小:" << size;
        emit dataRead(dbNumber, start, data);
        return true;
    } else {
        QString errorMsg = QString("读取DB失败 (错误码: %1)").arg(result);
        qWarning() << "❌ [S7ClientController]" << errorMsg;
        emit errorOccurred(errorMsg);
        return false;
    }
#else
    Q_UNUSED(dbNumber);
    Q_UNUSED(start);
    Q_UNUSED(size);
    Q_UNUSED(data);
    qWarning() << "⚠️ [S7ClientController] Snap7未启用";
    return false;
#endif
}

bool S7ClientController::readMerker(int start, int size, QByteArray &data)
{
#ifdef ENABLE_SNAP7
    if (!m_s7Client || !m_isConnected) {
        qWarning() << "❌ [S7ClientController] 未连接到PLC";
        return false;
    }

    // 分配缓冲区
    QByteArray buffer(size, 0);

    // 调用 Snap7 的 MBRead 方法（Merker = Memory Bit）
    int result = m_s7Client->MBRead(start, size, buffer.data());

    if (result == 0) {
        data = buffer;
        qDebug() << "✅ [S7ClientController] 读取Merker成功 - 起始:" << start << "大小:" << size;
        return true;
    } else {
        QString errorMsg = QString("读取Merker失败 (错误码: %1)").arg(result);
        qWarning() << "❌ [S7ClientController]" << errorMsg;
        emit errorOccurred(errorMsg);
        return false;
    }
#else
    Q_UNUSED(start);
    Q_UNUSED(size);
    Q_UNUSED(data);
    qWarning() << "⚠️ [S7ClientController] Snap7未启用";
    return false;
#endif
}

bool S7ClientController::readInput(int start, int size, QByteArray &data)
{
#ifdef ENABLE_SNAP7
    if (!m_s7Client || !m_isConnected) {
        qWarning() << "❌ [S7ClientController] 未连接到PLC";
        return false;
    }

    // 分配缓冲区
    QByteArray buffer(size, 0);

    // 调用 Snap7 的 EBRead 方法（EB = Eingangsbyte = Input Byte）
    int result = m_s7Client->EBRead(start, size, buffer.data());

    if (result == 0) {
        data = buffer;
        qDebug() << "✅ [S7ClientController] 读取Input成功 - 起始:" << start << "大小:" << size;
        return true;
    } else {
        QString errorMsg = QString("读取Input失败 (错误码: %1)").arg(result);
        qWarning() << "❌ [S7ClientController]" << errorMsg;
        emit errorOccurred(errorMsg);
        return false;
    }
#else
    Q_UNUSED(start);
    Q_UNUSED(size);
    Q_UNUSED(data);
    qWarning() << "⚠️ [S7ClientController] Snap7未启用";
    return false;
#endif
}

bool S7ClientController::readOutput(int start, int size, QByteArray &data)
{
#ifdef ENABLE_SNAP7
    if (!m_s7Client || !m_isConnected) {
        qWarning() << "❌ [S7ClientController] 未连接到PLC";
        return false;
    }

    // 分配缓冲区
    QByteArray buffer(size, 0);

    // 调用 Snap7 的 ABRead 方法（AB = Ausgangsbyte = Output Byte）
    int result = m_s7Client->ABRead(start, size, buffer.data());

    if (result == 0) {
        data = buffer;
        qDebug() << "✅ [S7ClientController] 读取Output成功 - 起始:" << start << "大小:" << size;
        return true;
    } else {
        QString errorMsg = QString("读取Output失败 (错误码: %1)").arg(result);
        qWarning() << "❌ [S7ClientController]" << errorMsg;
        emit errorOccurred(errorMsg);
        return false;
    }
#else
    Q_UNUSED(start);
    Q_UNUSED(size);
    Q_UNUSED(data);
    qWarning() << "⚠️ [S7ClientController] Snap7未启用";
    return false;
#endif
}

// ========== 写入操作 ==========
bool S7ClientController::writeDB(int dbNumber, int start, const QByteArray &data)
{
#ifdef ENABLE_SNAP7
    if (!m_s7Client || !m_isConnected) {
        qWarning() << "❌ [S7ClientController] 未连接到PLC";
        return false;
    }

    // 调用 Snap7 的 DBWrite 方法
    int result = m_s7Client->DBWrite(dbNumber, start, data.size(),
                                      const_cast<char*>(data.data()));

    if (result == 0) {
        qDebug() << "✅ [S7ClientController] 写入DB成功 - DB" << dbNumber
                 << "起始:" << start << "大小:" << data.size();
        return true;
    } else {
        QString errorMsg = QString("写入DB失败 (错误码: %1)").arg(result);
        qWarning() << "❌ [S7ClientController]" << errorMsg;
        emit errorOccurred(errorMsg);
        return false;
    }
#else
    Q_UNUSED(dbNumber);
    Q_UNUSED(start);
    Q_UNUSED(data);
    qWarning() << "⚠️ [S7ClientController] Snap7未启用";
    return false;
#endif
}

bool S7ClientController::writeMerker(int start, const QByteArray &data)
{
#ifdef ENABLE_SNAP7
    if (!m_s7Client || !m_isConnected) {
        qWarning() << "❌ [S7ClientController] 未连接到PLC";
        return false;
    }

    // 调用 Snap7 的 MBWrite 方法
    int result = m_s7Client->MBWrite(start, data.size(),
                                      const_cast<char*>(data.data()));

    if (result == 0) {
        qDebug() << "✅ [S7ClientController] 写入Merker成功 - 起始:" << start
                 << "大小:" << data.size();
        return true;
    } else {
        QString errorMsg = QString("写入Merker失败 (错误码: %1)").arg(result);
        qWarning() << "❌ [S7ClientController]" << errorMsg;
        emit errorOccurred(errorMsg);
        return false;
    }
#else
    Q_UNUSED(start);
    Q_UNUSED(data);
    qWarning() << "⚠️ [S7ClientController] Snap7未启用";
    return false;
#endif
}

bool S7ClientController::writeOutput(int start, const QByteArray &data)
{
#ifdef ENABLE_SNAP7
    if (!m_s7Client || !m_isConnected) {
        qWarning() << "❌ [S7ClientController] 未连接到PLC";
        return false;
    }

    // 调用 Snap7 的 ABWrite 方法
    int result = m_s7Client->ABWrite(start, data.size(),
                                      const_cast<char*>(data.data()));

    if (result == 0) {
        qDebug() << "✅ [S7ClientController] 写入Output成功 - 起始:" << start
                 << "大小:" << data.size();
        return true;
    } else {
        QString errorMsg = QString("写入Output失败 (错误码: %1)").arg(result);
        qWarning() << "❌ [S7ClientController]" << errorMsg;
        emit errorOccurred(errorMsg);
        return false;
    }
#else
    Q_UNUSED(start);
    Q_UNUSED(data);
    qWarning() << "⚠️ [S7ClientController] Snap7未启用";
    return false;
#endif
}

// ========== 私有槽函数 ==========
void S7ClientController::handlePollTimeout()
{
    // ✅ 2026-04-07 [Phase 7.48.88.83]: 实现轮询逻辑
    // 旧代码：// TODO: 实现轮询逻辑
    // 原因：之前为空实现，主站无法自动轮询PLC数据
    if (!m_isConnected) {
        return;
    }

    // 默认轮询DB1状态区（与S7ServerController的DB1映射对应）
    QByteArray data;
    if (readDB(1, 0, 140, data)) {
        emit dataRead(1, 0, data);
    }
}

// ========== 辅助函数 ==========
void S7ClientController::updateStatusText()
{
    QString newStatus;
    if (m_isConnected) {
        newStatus = QString("已连接 (%1:%2)").arg(m_targetIP).arg(m_port);
    } else {
        newStatus = "未连接";
    }

    if (m_statusText != newStatus) {
        m_statusText = newStatus;
        emit statusTextChanged();
    }
}

// ✅ 2026-04-11 [Phase 7.48.88.110]: 添加配置持久化功能
void S7ClientController::initSettings()
{
    m_settings = new QSettings("BeltControlSystem", "S7Client", this);
}

void S7ClientController::saveConfig(int portIndex)
{
    if (!m_settings) {
        initSettings();
    }

    QString prefix = QString("Port%1/").arg(portIndex);

    m_settings->setValue(prefix + "targetIP", m_targetIP);
    m_settings->setValue(prefix + "port", m_port);
    m_settings->setValue(prefix + "rack", m_rack);
    m_settings->setValue(prefix + "slot", m_slot);
    m_settings->setValue(prefix + "connectionType", m_connectionType);
    m_settings->setValue(prefix + "localTSAP", m_localTSAP);
    m_settings->setValue(prefix + "remoteTSAP", m_remoteTSAP);
    m_settings->setValue(prefix + "pduSize", m_pduSize);
    m_settings->setValue(prefix + "pollInterval", m_pollInterval);
    m_settings->setValue(prefix + "timeout", m_timeout);

    m_settings->sync();
    qDebug() << "✅ [S7ClientController] 配置已保存 - 端口:" << portIndex;
}

void S7ClientController::loadConfig(int portIndex)
{
    if (!m_settings) {
        initSettings();
    }

    QString prefix = QString("Port%1/").arg(portIndex);

    setTargetIP(m_settings->value(prefix + "targetIP", "192.168.0.1").toString());
    setPort(m_settings->value(prefix + "port", 102).toInt());
    setRack(m_settings->value(prefix + "rack", 0).toInt());
    setSlot(m_settings->value(prefix + "slot", 2).toInt());
    setConnectionType(m_settings->value(prefix + "connectionType", "PG").toString());
    setLocalTSAP(m_settings->value(prefix + "localTSAP", "0x0100").toString());
    setRemoteTSAP(m_settings->value(prefix + "remoteTSAP", "0x0302").toString());
    setPduSize(m_settings->value(prefix + "pduSize", 480).toInt());
    setPollInterval(m_settings->value(prefix + "pollInterval", 1000).toInt());
    setTimeout(m_settings->value(prefix + "timeout", 5000).toInt());

    qDebug() << "✅ [S7ClientController] 配置已加载 - 端口:" << portIndex;
}

void S7ClientController::resetConfig()
{
    setTargetIP("192.168.0.1");
    setPort(102);
    setRack(0);
    setSlot(2);
    setConnectionType("PG");
    setLocalTSAP("0x0100");
    setRemoteTSAP("0x0302");
    setPduSize(480);
    setPollInterval(1000);
    setTimeout(5000);

    qDebug() << "✅ [S7ClientController] 配置已重置";
}
