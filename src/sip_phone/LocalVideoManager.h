#ifndef LOCALVIDEOMANAGER_H
#define LOCALVIDEOMANAGER_H

#include <QObject>
#include <QTimer>
#include <QVideoSink>
#include <QVideoFrame>
#include <QImage>
#include <QMutex>
#include <pjsua.h>
#include <pjmedia.h>

/**
 * @brief 本地视频管理器 - 从 PJSIP 预览获取视频帧
 *
 * 不使用 Qt Multimedia 的 QCamera 独立控制摄像头，
 * 而是从 PJSIP 的视频预览端口获取帧，避免摄像头资源冲突
 */
class LocalVideoManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject* videoSink READ videoSink CONSTANT)
    Q_PROPERTY(bool hasLocalVideo READ hasLocalVideo NOTIFY hasLocalVideoChanged)

public:
    explicit LocalVideoManager(QObject *parent = nullptr);
    ~LocalVideoManager();

    QObject* videoSink() const;
    bool hasLocalVideo() const { return m_hasLocalVideo; }

    // 视频预览控制
    Q_INVOKABLE void startPreview();
    Q_INVOKABLE void stopPreview();

signals:
    void hasLocalVideoChanged();
    void errorOccurred(const QString &error);

private slots:
    void capturePreviewFrame();

private:
    QVideoSink *m_videoSink;
    bool m_hasLocalVideo;
    pjsua_vid_win_id m_previewWinId;
    pjmedia_port *m_previewPort;
    QTimer *m_captureTimer;
    pjmedia_vid_dev_index m_captureDevId;  // ✅ Store the capture device ID used for preview

    // ❌ 2026-01-11 22:45 [FIX 69.11 已弃用] 渲染器方案概念错误
    // 原因：渲染器是数据消费者，无法从中读取帧
    // 证据：RemoteVideoManager 使用自定义 pjmedia_port + put_frame 回调
    // 解决：改用 Fix 69.12（自定义端口 + 回调）
    // ✅ 2026-01-07 [修复 69.4] Linux V4L2 复用capture port的状态
    // 详细：docs/2026-01-06/27-Fix69-复用capture-port解决V4L2冲突.md
#ifdef __linux__
    // ❌ 2026-01-11 22:45 [FIX 69.11 已弃用] 不再使用渲染器
    // pjsua_conf_port_id m_reusedCapSlot = PJSUA_INVALID_ID;
    // pjsua_conf_port_id m_reusedRendSlot = PJSUA_INVALID_ID;
    // pjmedia_vid_port *m_reusedRendPort = nullptr;
    // pj_pool_t *m_reusedPool = nullptr;

    // ✅ 2026-01-11 22:45 [修复 69.12] 自定义 pjmedia_port + put_frame 回调
    // 原理：模仿 RemoteVideoManager，创建自定义端口接收 PJSIP 推送的帧
    // 详细：docs/2026-01-11/64-Fix69.12-自定义port回调接收帧.md
    // ✅ 2026-01-12 00:10 [修复 100.58] 添加互斥锁防止并发清理
    pjsua_conf_port_id m_reusedCapSlot = PJSUA_INVALID_ID;
    pjsua_conf_port_id m_customSlot = PJSUA_INVALID_ID;  // 自定义端口的 slot ID
    pjmedia_port *m_customPort = nullptr;  // 自定义端口（接收帧）
    pj_pool_t *m_customPool = nullptr;  // 自定义端口的内存池
    // ❌ 2026-01-12 14:50 [修复 100.64] 完全删除 m_cleanupMutex 成员变量
    // 原因：Fix 100.63 已不使用 mutex，但成员变量的存在本身就是问题源
    // 证据：RemoteVideoManager 无 mutex 成员变量，清理成功；LocalVideoManager 有 mutex，崩溃
    // 根本原因：Qt 在对象生命周期的某个时刻访问 QMutex，线程状态异常时 pthread_mutex_lock 失败
    // 解决：完全删除 m_cleanupMutex，彻底消除问题源
    // 详细：docs/2026-01-12/76-Fix100.64-完全删除m_cleanupMutex.md
    // QMutex m_cleanupMutex;  // 保护清理操作的互斥锁
    QTimer *m_delayedCleanupTimer;  // 延迟清理定时器（避免PJSIP异步竞态）

    // ✅ 2026-01-12 01:20 [修复 100.60] cap_slot 连接重试机制
    // 问题：第二次通话时 cap_slot → enc_slot 连接异步延迟，startPreview() 太早执行
    // 证据：transmitter_cnt=0（第一次为1），说明 vid_conf async connect 未完成
    // 解决：延迟 50ms 重试，最多 5 次（总计 250ms）
    // 详细：docs/2026-01-12/69-Fix100.59测试结果-第二次通话时序问题.md
    QTimer *m_capSlotRetryTimer = nullptr;  // cap_slot 查找重试定时器
    int m_retryCount = 0;  // 当前重试次数

    // ✅ 2026-01-12 01:45 [修复 100.61] 析构标志防止pthread_mutex错误
    // 问题：析构函数调用stopPreview()时，QMutexLocker尝试加锁导致pthread错误
    // 错误：pthread_mutex_lock.c:450 assertion failed: e != ESRCH || !robust
    // 根因：对象析构中，QMutex底层pthread_mutex可能已失效
    // 解决：析构时设置标志，stopPreview()检查后跳过mutex（析构时无并发风险）
    // 详细：docs/2026-01-12/71-Fix100.61-析构时避免pthread_mutex.md
    bool m_isDestroying = false;  // 标记对象正在析构
#endif

    bool attachPreviewPort();
    void detachPreviewPort();
    QVideoFrame convertPjFrameToQt(pjmedia_frame *frame, const pjmedia_format *fmt);

    // ✅ 2026-01-07 [修复 69.1] 查找活跃通话的摄像头端口
    // 详细：docs/2026-01-06/27-Fix69-复用capture-port解决V4L2冲突.md
    pjsua_conf_port_id findActiveCallCaptureSlot(int capDevId);

#ifdef __linux__
    // ✅ 2026-01-11 22:45 [修复 69.12] 自定义端口管理
    bool createCustomPort(int width = 640, int height = 480, int fps_num = 30, int fps_denum = 1);
    void destroyCustomPort();

    // ❌ 2026-01-12 02:15 [修复 100.62] 不再需要延迟清理
    // void performDelayedCleanup();

    // ✅ 2026-01-11 22:45 [修复 69.12] PJSIP 静态回调函数（Push 模式）
    static pj_status_t port_put_frame(pjmedia_port *port, pjmedia_frame *frame);
    static pj_status_t port_get_frame(pjmedia_port *port, pjmedia_frame *frame);
    static pj_status_t port_on_destroy(pjmedia_port *port);

    // ✅ 2026-01-11 22:45 [修复 69.12] 帧接收回调（成员函数）
    void onLocalFrameReceived(pjmedia_frame *frame, const pjmedia_format *fmt);
#endif
};

#endif // LOCALVIDEOMANAGER_H
