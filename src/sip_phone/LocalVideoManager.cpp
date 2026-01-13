#include "LocalVideoManager.h"
#include <QDebug>
#include <QImage>
#include <QDateTime>
#include <pjsua-lib/pjsua.h>
#include <pjsua-lib/pjsua_internal.h>

#ifdef __linux__
#include <unordered_map>

// ✅ 2026-01-12 02:15 [修复 100.62] port → pool 静态映射
// 原因：port_on_destroy 需要释放 pool，但不能访问 this（可能已析构）
// 解决：使用静态映射保存 port → pool 关系，on_destroy 时从映射中获取 pool
// port_data.pdata 仍保存 this（供 port_put_frame 使用）
// 详细：docs/2026-01-12/72-完整根因分析-崩溃的真正原因.md
static std::unordered_map<pjmedia_port*, pj_pool_t*> s_portPoolMap;
#endif

/**
 * @brief 本地视频管理器实现 - 从 PJSIP 预览获取帧
 *
 * 使用 PJSIP 的视频预览功能，避免 Qt Multimedia QCamera 独立控制摄像头
 * 这样 PJSIP 可以同时用摄像头做预览和发送给对方
 */
LocalVideoManager::LocalVideoManager(QObject *parent)
    : QObject(parent)
    , m_videoSink(new QVideoSink(this))
    , m_hasLocalVideo(false)
    , m_previewWinId(PJSUA_INVALID_ID)
    , m_previewPort(nullptr)
    , m_captureTimer(new QTimer(this))
    , m_captureDevId(PJMEDIA_VID_DEFAULT_CAPTURE_DEV)
#ifdef __linux__
    , m_delayedCleanupTimer(new QTimer(this))
#endif
{
    qDebug() << "✅ LocalVideoManager created (PJSIP preview mode)";

#ifdef __linux__
    // ❌ 2026-01-12 02:15 [修复 100.62] 不再需要延迟清理定时器连接
    // m_delayedCleanupTimer->setSingleShot(true);
    // connect(m_delayedCleanupTimer, &QTimer::timeout, this, &LocalVideoManager::performDelayedCleanup);
#endif

    // 捕获定时器 - 60fps (17ms) for smooth preview
    m_captureTimer->setInterval(17);  // 60fps to match high frame rate video
    connect(m_captureTimer, &QTimer::timeout, this, &LocalVideoManager::capturePreviewFrame);
}

LocalVideoManager::~LocalVideoManager()
{
    qDebug() << "LocalVideoManager: Shutting down...";

    // ✅ 2026-01-12 01:45 [修复 100.61] 设置析构标志避免pthread_mutex错误
    // 问题：stopPreview()使用QMutexLocker会导致pthread_mutex_lock失败
    // 错误：pthread_mutex_lock.c:450 assertion failed: e != ESRCH || !robust
    // 解决：先设置标志，stopPreview()检测到后跳过mutex（析构时无并发风险）
#ifdef __linux__
    m_isDestroying = true;
#endif

    stopPreview();
}

QObject* LocalVideoManager::videoSink() const
{
    return m_videoSink;
}

void LocalVideoManager::startPreview()
{
    // ❌ 2026-01-11 20:00 [FIX 100.55 已弃用] 禁用预览方案测试失败
    // 原因：禁用预览导致挂断时程序崩溃，用户要求必须保留预览功能
    // 证据：Fix 100.55 测试后挂断程序崩溃（SIGTRAP）
    // 解决：改用 Fix 69（复用 capture port）方案
    // 详细：docs/2026-01-06/27-Fix69-复用capture-port解决V4L2冲突.md

    // ✅ 2026-01-11 21:00 [FIX 69 重新启用] 复用 PJSIP capture port 避免 V4L2 冲突
    // ✅ 2026-01-01 23:20 [修复 26] 优先使用 PJSIP 自动创建的 preview，避免摄像头资源冲突
    // 背景：PJSIP 在视频通话时自动创建 preview window 并连接摄像头到编码器
    // 策略：
    // 1. 首先检查 PJSIP 是否已为通话创建了 preview window
    // 2. 如果有 → 直接复用（避免资源冲突）
    // 3. 如果没有 → 独立启动 preview（Windows 多路访问场景）
    //
    // 关键差异：
    // - 通话中：PJSIP preview 同时连接 camera → encoder (RTP发送) ✅
    // - 非通话：独立 preview 只连接 camera → SDL display (仅本地显示) ⚠️

    // ✅ Step 1: 检测首选的摄像头设备
    m_captureDevId = PJMEDIA_VID_DEFAULT_CAPTURE_DEV;  // Default: -1 (auto)

    unsigned vidDevCount = pjsua_vid_dev_count();
    for (unsigned i = 0; i < vidDevCount; ++i) {
        pjmedia_vid_dev_info devInfo;
        if (pjsua_vid_dev_get_info(i, &devInfo) == PJ_SUCCESS) {
            // Find first real capture device (skip colorbar/null/HDMI input)
            if (devInfo.dir & PJMEDIA_DIR_CAPTURE) {
                QString deviceName = QString::fromUtf8(devInfo.name);
                // Skip non-camera devices
                if (!deviceName.contains("colorbar", Qt::CaseInsensitive) &&
                    !deviceName.contains("null", Qt::CaseInsensitive) &&
                    !deviceName.contains("hdmirx", Qt::CaseInsensitive) &&
                    !deviceName.contains("rk_hdmirx", Qt::CaseInsensitive)) {
                    m_captureDevId = i;
                    qDebug() << "✅ LocalVideoManager: Auto-selected capture device" << i << ":" << devInfo.name;
                    break;
                }
            }
        }
    }

    if (m_captureDevId == PJMEDIA_VID_DEFAULT_CAPTURE_DEV) {
        qWarning() << "⚠️ LocalVideoManager: No suitable camera found, using default (-1)";
        // 继续尝试，可能系统会自动选择合适的设备
        m_captureDevId = 0;  // 尝试设备 0
    }

    // ✅ Step 2: 检查 PJSIP 是否已为该设备创建了 preview window
    pjsua_vid_win_id existingWinId = pjsua_vid_preview_get_win(m_captureDevId);

    if (existingWinId != PJSUA_INVALID_ID) {
        // ✅ PJSIP 已创建 preview（通话场景）→ 直接复用
        qDebug() << "✅ LocalVideoManager: Found existing PJSIP preview window" << existingWinId
                 << "for device" << m_captureDevId << "→ reusing it";
        m_previewWinId = existingWinId;

        // 直接附加到现有 preview 端口
        if (attachPreviewPort()) {
            m_hasLocalVideo = true;
            emit hasLocalVideoChanged();
            m_captureTimer->start();
            qDebug() << "✅ LocalVideoManager: Attached to PJSIP preview (通话模式，摄像头已连接到编码器)";
        } else {
            qWarning() << "❌ LocalVideoManager: Failed to attach to existing preview port";
        }
        return;
    }

    // ✅ Step 3: PJSIP 没有 preview → 检查是否有活跃通话
    qDebug() << "⚠️ LocalVideoManager: No PJSIP preview found for device" << m_captureDevId;

#ifdef __linux__
    // ✅ 2026-01-07 [修复 69.2] Linux V4L2 不支持多路访问
    // 问题：通话时摄像头已被占用，创建独立preview会导致 "Device or resource busy"
    // 方案：检查活跃通话，复用通话的capture port，避免重复打开摄像头
    // 详细：docs/2026-01-06/27-Fix69-复用capture-port解决V4L2冲突.md

    pjsua_conf_port_id cap_slot = findActiveCallCaptureSlot(m_captureDevId);

    // ✅ 2026-01-12 01:20 [修复 100.60] cap_slot 连接异步延迟，添加重试机制
    // 问题：第二次通话时 cap_slot → enc_slot 连接可能还在队列中（queued），未完成
    // 证据：transmitter_cnt=0（第一次为1），说明 PJSIP vid_conf async connect 延迟
    // 时序：12:00:14.798 connect queued → 12:00:15.073 startPreview() → 12:00:15.127 stream resumed
    // 解决：延迟 50ms 重试，最多 5 次（总计 250ms），等待异步连接完成
    // 详细：docs/2026-01-12/69-Fix100.59测试结果-第二次通话时序问题.md
    if (cap_slot == PJSUA_INVALID_ID) {
        // 创建重试定时器（如果还未创建）
        if (!m_capSlotRetryTimer) {
            m_capSlotRetryTimer = new QTimer(this);
            m_capSlotRetryTimer->setSingleShot(true);
            connect(m_capSlotRetryTimer, &QTimer::timeout, this, &LocalVideoManager::startPreview);
        }

        // 重试最多 5 次
        if (m_retryCount < 5) {
            m_retryCount++;
            qDebug() << "⏳ [FIX 100.60] cap_slot not ready yet, retry" << m_retryCount << "/ 5 in 50ms";
            qDebug() << "   [FIX 100.60] Reason: PJSIP vid_conf async connect may not be complete yet";
            m_capSlotRetryTimer->start(50);  // 50ms 后重试
            return;
        }

        // 重试 5 次后仍失败
        qWarning() << "❌ [FIX 100.60] cap_slot still not found after 5 retries (250ms)";
        qWarning() << "   [FIX 100.60] Fallback to independent preview (may fail on Linux V4L2)";
        m_retryCount = 0;  // 重置计数
        goto fallback;
    }

    // ✅ 成功找到 cap_slot，重置重试计数
    if (m_retryCount > 0) {
        qDebug() << "✅ [FIX 100.60] cap_slot found after" << m_retryCount << "retries";
    }
    m_retryCount = 0;

    if (cap_slot != PJSUA_INVALID_ID) {
        qDebug() << "✅ [FIX 69.12] Active call found, cap_slot:" << cap_slot;
        qDebug() << "   Strategy: Create custom port (Push mode) connected to capture port";

        // ❌ 2026-01-11 22:45 [FIX 69.11 已弃用] 渲染器方案概念错误
        // 原因：渲染器是数据消费者，其 passive port 用于接收数据，无法读取帧
        // 证据：RemoteVideoManager 成功使用自定义 pjmedia_port + put_frame 回调
        //
        // ✅ 2026-01-11 22:45 [修复 69.12] 自定义 pjmedia_port + put_frame 回调
        // 原理：模仿 RemoteVideoManager，创建自定义端口，PJSIP 主动推送帧到回调
        // 架构：Camera → Capture Port → Vid Tee → Encoder (RTP) + Custom Port (本地预览)
        // 详细：docs/2026-01-11/64-Fix69.12-自定义port回调接收帧.md

        pj_status_t status;

        // Step 1: 创建自定义 pjmedia_port（类似 RemoteVideoManager）
        // 使用与通话相同的分辨率和帧率（640x480 @ 30fps）
        if (!createCustomPort(640, 480, 30, 1)) {
            qWarning() << "❌ [FIX 69.12] Failed to create custom port";
            goto fallback;
        }

        qDebug() << "✅ [FIX 69.12] Custom port created for local preview";

        // Step 2: 添加自定义端口到视频会议桥
        status = pjsua_vid_conf_add_port(m_customPool, m_customPort, NULL, &m_customSlot);
        if (status != PJ_SUCCESS) {
            qWarning() << "❌ [FIX 69.12] Failed to add custom port to vid conf, status:" << status;
            destroyCustomPort();
            goto fallback;
        }

        qDebug() << "✅ [FIX 69.12] Custom port added to vid conf, slot:" << m_customSlot;

        // Step 3: 连接 cap_slot → custom_slot（关键！PJSIP 会推送帧到 put_frame）
        m_reusedCapSlot = cap_slot;
        status = pjsua_vid_conf_connect(m_reusedCapSlot, m_customSlot, NULL);
        if (status != PJ_SUCCESS) {
            qWarning() << "❌ [FIX 69.12] Failed to connect cap→custom, status:" << status;
            pjsua_vid_conf_remove_port(m_customSlot);
            m_customSlot = PJSUA_INVALID_ID;
            destroyCustomPort();
            goto fallback;
        }

        qDebug() << "✅ [FIX 69.12] Connected cap_slot:" << m_reusedCapSlot << "→ custom_slot:" << m_customSlot;

        // ✅ 成功！PJSIP 会自动调用 put_frame 推送帧
        m_hasLocalVideo = true;
        emit hasLocalVideoChanged();
        // ❌ 不再需要定时器，帧会被 PJSIP 主动推送到 put_frame 回调
        // m_captureTimer->start();

        qDebug() << "🎉 [FIX 69.12] Local video preview activated via custom port (Push mode)!";
        qDebug() << "   Architecture: Camera → Capture Port → Vid Tee → [Encoder (RTP) + Custom Port (本地预览)]";
        qDebug() << "   PJSIP will push frames to put_frame() callback automatically ✅";
        return;  // 成功，直接返回

fallback:
        qWarning() << "❌ [FIX 69.2] Failed to create renderer using reused cap_slot";
        qWarning() << "   Falling back to independent preview (may fail on Linux)";
    } else {
        qDebug() << "   No active call found, will create independent preview";
    }
#endif

    // ⚠️ 原有逻辑：创建独立预览（Windows 或无通话时）
    // 注意：Linux 通话时会失败（V4L2 资源冲突）
    qDebug() << "→ creating independent preview";
    qDebug() << "   Note: Windows多路访问正常，Linux V4L2可能导致通话时摄像头冲突";

    // 启动独立的 PJSIP 视频预览
    pjsua_vid_preview_param param;
    pjsua_vid_preview_param_default(&param);

    // ✅ 配置摄像头：640x360 @ 25fps，匹配通话分辨率
    // ❌ 2026-01-11 01:45 [修复 100.29] 修改为 640x368（16像素对齐）
    // ❌ 2026-01-11 04:00 [修复 100.33] 修改为 640x480 @ 30fps（摄像头硬件支持）
    // ❌ 2026-01-11 04:20 [修复 100.34] 修改为 640x360 @ 30fps（匹配对方）
    // ✅ 2026-01-11 11:20 [修复 100.37] 改回 VGA 640x480（对方已切换到 VGA）
    pjmedia_format_init_video(&param.format, PJMEDIA_FORMAT_YUY2, 640, 480, 30, 1);
    param.show = PJ_FALSE;  // 隐藏SDL窗口

    qDebug() << "📹 Creating independent preview: 640x480 (VGA) @ 30fps (YUY2), SDL window hidden";

    pj_status_t status = pjsua_vid_preview_start(m_captureDevId, &param);
    if (status != PJ_SUCCESS) {
        qWarning() << "❌ LocalVideoManager: Failed to start independent preview, status:" << status;
        qWarning() << "   This may be expected if already in a video call (camera busy)";
        emit errorOccurred("Failed to start video preview");
        return;
    }

    qDebug() << "✅ LocalVideoManager: Independent preview started successfully";

    // 获取独立 preview 的窗口ID
    m_previewWinId = pjsua_vid_preview_get_win(m_captureDevId);
    if (m_previewWinId == PJSUA_INVALID_ID) {
        qWarning() << "❌ LocalVideoManager: Failed to get independent preview window ID";
        return;
    }

    // 附加到独立 preview 端口
    if (attachPreviewPort()) {
        m_hasLocalVideo = true;
        emit hasLocalVideoChanged();
        m_captureTimer->start();
        qDebug() << "✅ LocalVideoManager: Frame capture started (独立预览模式，仅本地显示)";
    } else {
        qWarning() << "❌ LocalVideoManager: Failed to attach to independent preview port";
    }
}

void LocalVideoManager::stopPreview()
{
    // qDebug() << "📹 LocalVideoManager: Stopping PJSIP video preview";

    // ✅ 2026-01-12 00:10 [修复 100.58] 互斥锁 + 延迟清理组合方案
    // 问题：Fix 100.56/100.57 仍崩溃，原因是并发清理 + PJSIP异步操作竞态
    // 根因分析：
    //   1. 双重调用：两个线程几乎同时调用 stopPreview()
    //   2. 异步冲突：pjsua_vid_conf_remove_port() 异步执行，立即释放pool崩溃
    //   3. on_destroy崩溃：vid_conf清理时访问已释放的内存
    // 解决方案：
    //   1. 互斥锁：防止并发进入清理代码
    //   2. 延迟清理：1000ms后清理pool，确保PJSIP异步操作完成
    //   3. 不在on_destroy释放：避免在回调中访问可能失效的this指针
    // 详细：docs/2026-01-11/67-Fix100.58-互斥锁+延迟清理.md
#ifdef __linux__
    // ✅ 2026-01-12 01:45 [修复 100.61] 析构时跳过mutex避免pthread_mutex错误
    // 问题：析构中调用stopPreview()时，QMutexLocker导致pthread_mutex_lock失败
    // 错误：pthread_mutex_lock.c:450 assertion failed: e != ESRCH || !robust (exit code 133)
    // 根因：对象析构时，QMutex底层pthread_mutex可能已失效
    // 解决：检查m_isDestroying标志，析构时跳过mutex（析构时无并发风险）
    // 详细：docs/2026-01-12/71-Fix100.61-析构时避免pthread_mutex.md

    if (m_isDestroying) {
        // ✅ 析构期间：不使用mutex（无并发风险）
        qDebug() << "🔧 [FIX 100.61] stopPreview() called during destruction (no mutex)";

        // ✅ 2026-01-12 01:20 [修复 100.60] 停止重试定时器
        if (m_capSlotRetryTimer && m_capSlotRetryTimer->isActive()) {
            m_capSlotRetryTimer->stop();
            qDebug() << "   [FIX 100.61] Stopped cap_slot retry timer";
        }
        m_retryCount = 0;

        // ✅ 双重清理保护
        if (m_customSlot == PJSUA_INVALID_ID) {
            qDebug() << "   [FIX 100.61] Already cleaned up, ignoring";
            return;
        }

        // ✅ 立即标记为已清理
        pjsua_conf_port_id temp_customSlot = m_customSlot;
        m_customSlot = PJSUA_INVALID_ID;
        m_reusedCapSlot = PJSUA_INVALID_ID;

        qDebug() << "   [FIX 100.61] Cleanup (custom_slot:" << temp_customSlot << ")";

        // ❌ 2026-01-12 02:15 [修复 100.62] 析构时也不手动 disconnect/remove
        // 原因：与正常路径相同，PJSIP 已自动处理
        // 解决：让 PJSIP 自动清理，on_destroy 回调会释放 pool
        // if (temp_capSlot != PJSUA_INVALID_ID && temp_customSlot != PJSUA_INVALID_ID) {
        //     pjsua_vid_conf_disconnect(temp_capSlot, temp_customSlot);
        //     qDebug() << "   [FIX 100.61] Disconnected cap_slot → custom_slot";
        // }
        //
        // if (temp_customSlot != PJSUA_INVALID_ID) {
        //     pjsua_vid_conf_remove_port(temp_customSlot);
        //     qDebug() << "   [FIX 100.61] Removed custom_slot from vid_conf (queued)";
        // }

        // ✅ 标记 port 为 nullptr
        m_customPort = nullptr;
        qDebug() << "   [FIX 100.62] Port marked as null (pool will be released by on_destroy)";

        // ❌ 2026-01-12 02:15 [修复 100.62] 析构时也不立即释放 pool
        // 原因：可能导致 on_destroy 回调访问已释放的 pool
        // 解决：由 on_destroy 回调负责释放（时机正确）
        // if (m_customPool) {
        //     qDebug() << "   [FIX 100.61] Releasing pool immediately (during destruction)";
        //     pj_pool_release(m_customPool);
        //     m_customPool = nullptr;
        //     qDebug() << "   [FIX 100.61] Pool released";
        // }

        // ✅ 停止延迟清理定时器（如果已启动）
        if (m_delayedCleanupTimer && m_delayedCleanupTimer->isActive()) {
            m_delayedCleanupTimer->stop();
            qDebug() << "   [FIX 100.62] Stopped delayed cleanup timer";
        }

        // ✅ 更新状态
        if (m_hasLocalVideo) {
            m_hasLocalVideo = false;
            emit hasLocalVideoChanged();
        }

        qDebug() << "✅ [FIX 100.62] Custom port cleanup completed (destruction path, PJSIP will auto-cleanup)";
        return;
    }

    // ❌ 2026-01-12 02:30 [修复 100.63] 移除正常路径的mutex使用
    // ❌ 2026-01-12 14:50 [修复 100.64] 完全删除 m_cleanupMutex 成员变量
    // 原因：Fix 100.63 已不使用 mutex，但成员变量的存在本身就是问题源
    // 证据：RemoteVideoManager 无 mutex 成员变量，清理成功；LocalVideoManager 有 mutex，崩溃
    // 根本原因：Qt 在对象生命周期的某个时刻访问 QMutex，线程状态异常时 pthread_mutex_lock 失败
    // 解决：完全删除 m_cleanupMutex，彻底消除问题源
    // 详细：docs/2026-01-12/76-Fix100.64-完全删除m_cleanupMutex.md
    // QMutexLocker locker(&m_cleanupMutex);  // ✅ 自动加锁/解锁

    // ✅ 2026-01-12 01:20 [修复 100.60] 停止重试定时器
    if (m_capSlotRetryTimer && m_capSlotRetryTimer->isActive()) {
        m_capSlotRetryTimer->stop();
        qDebug() << "⏹️ [FIX 100.60] Stopped cap_slot retry timer";
    }
    m_retryCount = 0;  // 重置重试计数

    // ✅ Step 1: 双重清理保护（原子操作，不需要 mutex）
    if (m_customSlot == PJSUA_INVALID_ID) {
        qDebug() << "⚠️ [FIX 100.64] stopPreview() called but already cleaned up, ignoring";
        return;
    }

    // ✅ Step 2: 立即标记为已清理（防止并发）
    pjsua_conf_port_id temp_customSlot = m_customSlot;
    m_customSlot = PJSUA_INVALID_ID;
    m_reusedCapSlot = PJSUA_INVALID_ID;

    qDebug() << "🔧 [FIX 100.64] Initiating cleanup (custom_slot:" << temp_customSlot << ", no QMutex member)";

    // ✅ 2026-01-14 21:50 [修复 VERSION 156 LOCAL_PUSH 循环 - 真正移除 port]
    // 问题：Fix 100.62 依赖 PJSIP 自动清理，但在通话挂断场景下 PJSIP 不会自动移除 custom port
    //       导致 port 仍在 vid_conf 中，port_put_frame 回调持续执行
    //       表现：[LOCAL PUSH] Video frames: 0 | Total callbacks: 持续增长
    // 证据：docs/log/voip.md Line 3754+ 显示 [LOCAL PUSH] 仍在输出，Total callbacks 达到 2361
    // 原因：
    //   - Fix 100.62（Line 429-435）注释掉了 pjsua_vid_conf_remove_port()
    //   - 期望 PJSIP 自动清理，但实际上没有
    //   - port 仍在 vid_conf 中，PJSIP 持续调用 port_put_frame
    // 解决：手动调用 pjsua_vid_conf_remove_port()，真正移除 port
    // 风险：可能与 PJSIP 清理竞争，但这是必要的（否则 port 永远不会被移除）
    // 详细：docs/2026-01-14/14-修复VERSION156-真正移除port-手动调用remove.md
    if (temp_customSlot != PJSUA_INVALID_ID) {
        qDebug() << "   [FIX VERSION 156] Manually removing custom_slot from vid_conf to stop callbacks";
        pj_status_t status = pjsua_vid_conf_remove_port(temp_customSlot);
        if (status == PJ_SUCCESS) {
            qDebug() << "   ✅ [FIX VERSION 156] Port removed successfully (custom_slot:" << temp_customSlot << ")";
        } else {
            qDebug() << "   ⚠️ [FIX VERSION 156] Port removal returned status:" << status << "(may already be removed)";
        }
    }

    // ❌ 2026-01-12 02:15 [修复 100.62 设计已推翻] 不手动 remove 导致 port 永远不会被移除
    // 原因：在通话挂断场景下，PJSIP 不会自动清理 custom port
    // 后果：port_put_frame 回调持续执行，[LOCAL PUSH] 日志持续输出
    // 解决：必须手动调用 pjsua_vid_conf_remove_port()（上面已实施）
    // if (temp_customSlot != PJSUA_INVALID_ID) {
    //     pjsua_vid_conf_remove_port(temp_customSlot);
    //     qDebug() << "   [FIX 100.59] Step 2: Removed custom_slot from vid_conf (queued)";
    // }

    // ✅ Step 3: 标记 port 为 nullptr（防止重复访问）
    m_customPort = nullptr;
    qDebug() << "   [FIX VERSION 156] Port marked as null (pool will be released by on_destroy callback)";

    // ❌ 2026-01-12 02:15 [修复 100.62] 不延迟释放 pool
    // 原因：无法准确判断释放时机（200ms、500ms、1000ms 都是猜测）
    // 解决：在 port_on_destroy 回调中释放（时机完全正确，等待 PJSIP 完成所有清理）
    // m_customPool = nullptr;  // 不再由我们管理，由 on_destroy 释放

    // ✅ Step 4: 停止延迟清理定时器（不再需要）
    if (m_delayedCleanupTimer && m_delayedCleanupTimer->isActive()) {
        m_delayedCleanupTimer->stop();
        qDebug() << "   [FIX 100.64] Delayed cleanup timer stopped (not needed anymore)";
    }

    // ✅ Step 5: 更新状态
    if (m_hasLocalVideo) {
        m_hasLocalVideo = false;
        emit hasLocalVideoChanged();
    }

    qDebug() << "✅ [FIX 100.64] Custom port cleanup initiated (PJSIP will auto-cleanup, no QMutex member)";
    return;
#endif

    // 停止帧捕获
    m_captureTimer->stop();

    // 分离预览端口
    detachPreviewPort();

    // 停止 PJSIP 预览 (使用检测到的摄像头设备ID)
    if (m_previewWinId != PJSUA_INVALID_ID) {
        pjsua_vid_preview_stop(m_captureDevId);
        m_previewWinId = PJSUA_INVALID_ID;
    }

    if (m_hasLocalVideo) {
        m_hasLocalVideo = false;
        emit hasLocalVideoChanged();
    }

    qDebug() << "✅ LocalVideoManager: Preview stopped";
}

bool LocalVideoManager::attachPreviewPort()
{
    if (m_previewWinId == PJSUA_INVALID_ID) {
        return false;
    }

    // 获取预览窗口信息
    pjsua_vid_win_info wi;
    pj_status_t status = pjsua_vid_win_get_info(m_previewWinId, &wi);
    if (status != PJ_SUCCESS) {
        qWarning() << "❌ LocalVideoManager: Failed to get preview window info, status:" << status;
        return false;
    }

    // qDebug() << "📺 LocalVideoManager: Preview window info:"
    //          << "show=" << wi.show
    //          << "is_native=" << wi.is_native
    //          << "hwnd.type=" << wi.hwnd.type;

    // 尝试方法1: 通过 pjmedia_vid_port 获取端口
    // 预览窗口的 pjmedia_vid_port 包含了从摄像头捕获的帧
    if (m_previewWinId >= 0 && m_previewWinId < PJSUA_MAX_VID_WINS) {
        pjsua_vid_win *win = &pjsua_var.win[m_previewWinId];

        // 检查是否是预览窗口（有捕获设备）
        if (win->preview_cap_id != PJSUA_INVALID_ID && win->vp_cap) {
            // 从捕获设备的 vid_port 获取被动端口
            m_previewPort = pjmedia_vid_port_get_passive_port(win->vp_cap);
            if (m_previewPort) {
                // qDebug() << "📺 LocalVideoManager: Attached to preview port via vp_cap" << m_previewPort;
                return true;
            }
        }

        // 方法2: 尝试从渲染端口获取
        if (win->vp_rend) {
            m_previewPort = pjmedia_vid_port_get_passive_port(win->vp_rend);
            if (m_previewPort) {
                // qDebug() << "📺 LocalVideoManager: Attached to preview port via vp_rend" << m_previewPort;
                return true;
            }
        }
    }

    qWarning() << "❌ LocalVideoManager: Could not attach to preview port";
    return false;
}

void LocalVideoManager::detachPreviewPort()
{
    if (m_previewPort) {
        // qDebug() << "🔌 LocalVideoManager: Detaching preview port";
        m_previewPort = nullptr;
    }
}

void LocalVideoManager::capturePreviewFrame()
{
    // ✅ 性能统计（类似 RemoteVideoManager）
    static int frameCount = 0;
    static qint64 lastLogTime = 0;
    static qint64 lastFrameTime = 0;
    static int framesInSecond = 0;
    static qint64 totalFrameInterval = 0;
    static int intervalSamples = 0;
    static int errorCount = 0;

    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();

    if (!m_previewPort) {
        if (errorCount < 5) {
            qDebug() << "⚠️ capturePreviewFrame: No preview port";
            errorCount++;
        }
        return;
    }

    // 准备帧缓冲区
    pjmedia_frame frame;
    pj_bzero(&frame, sizeof(frame));

    // 分配足够大的缓冲区 (假设最大 1920x1080 RGBA)
    static unsigned char buffer[1920 * 1080 * 4];
    frame.buf = buffer;
    frame.size = sizeof(buffer);
    frame.type = PJMEDIA_FRAME_TYPE_NONE;

    // 从端口获取帧
    pj_status_t status = pjmedia_port_get_frame(m_previewPort, &frame);

    if (status != PJ_SUCCESS) {
        if (errorCount < 5) {
            qDebug() << "❌ pjmedia_port_get_frame failed, status:" << status;
            errorCount++;
        }
        return;
    }

    if (frame.type != PJMEDIA_FRAME_TYPE_VIDEO) {
        if (errorCount < 5) {
            qDebug() << "⚠️ Frame type is not video, type:" << frame.type;
            errorCount++;
        }
        return;
    }

    // 获取视频格式
    const pjmedia_format *fmt = &m_previewPort->info.fmt;

    // 转换为 QVideoFrame
    QVideoFrame videoFrame = convertPjFrameToQt(&frame, fmt);

    if (videoFrame.isValid()) {
        frameCount++;
        framesInSecond++;

        // 发送到 QVideoSink
        m_videoSink->setVideoFrame(videoFrame);

        // ✅ 统计帧间隔
        if (lastFrameTime > 0) {
            qint64 interval = currentTime - lastFrameTime;
            totalFrameInterval += interval;
            intervalSamples++;
        }
        lastFrameTime = currentTime;

        // ✅ 首帧日志
        if (frameCount == 1) {
            pjmedia_video_format_detail *vfd = pjmedia_format_get_video_format_detail(fmt, PJ_TRUE);
            if (vfd) {
                qDebug() << "🎬 [FIRST LOCAL FRAME] Sending format:" << vfd->size.w << "x" << vfd->size.h
                         << "@" << vfd->fps.num << "/" << vfd->fps.denum << "fps"
                         << "| Format:" << videoFrame.pixelFormat();
            }
        }

        // ✅ 每秒统计一次性能
        if (lastLogTime == 0) {
            lastLogTime = currentTime;
        } else if (currentTime - lastLogTime >= 1000) {
            qint64 elapsedMs = currentTime - lastLogTime;
            double actualFps = (framesInSecond * 1000.0) / elapsedMs;
            double avgInterval = intervalSamples > 0 ? (double)totalFrameInterval / intervalSamples : 0;

            qDebug() << "📤 [LOCAL VIDEO SEND]"
                     << "Sending FPS:" << QString::number(actualFps, 'f', 1)
                     << "| Avg interval:" << QString::number(avgInterval, 'f', 1) << "ms"
                     << "| Total frames:" << frameCount
                     << "| Size:" << videoFrame.size()
                     << "| Format:" << videoFrame.pixelFormat();

            // 重置计数器
            lastLogTime = currentTime;
            framesInSecond = 0;
            totalFrameInterval = 0;
            intervalSamples = 0;
        }

        // 重置错误计数
        errorCount = 0;
    } else {
        if (errorCount < 5) {
            qDebug() << "❌ convertPjFrameToQt returned invalid frame";
            errorCount++;
        }
    }
}

QVideoFrame LocalVideoManager::convertPjFrameToQt(pjmedia_frame *frame, const pjmedia_format *fmt)
{
    if (!frame || !fmt || frame->type != PJMEDIA_FRAME_TYPE_VIDEO) {
        return QVideoFrame();
    }

    // 获取视频尺寸
    pjmedia_video_format_detail *vfd = pjmedia_format_get_video_format_detail(fmt, PJ_TRUE);
    if (!vfd) {
        return QVideoFrame();
    }

    int width = vfd->size.w;
    int height = vfd->size.h;

    // 检查格式
    pj_uint32_t pjfmt = fmt->id;

    // Define J420 format ID (JPEG YUV420 with full range)
    const pj_uint32_t PJMEDIA_FORMAT_J420 = 0x3032344a;

    // ✅ 使用Qt的YUV格式支持，让Qt来处理颜色转换（与 RemoteVideoManager 相同的方法）

    // YUY2/YUYV format (packed YUV 4:2:2) - 常用于摄像头输出
    if (pjfmt == PJMEDIA_FORMAT_YUY2) {
        // YUY2 -> 使用Qt的YUYV格式
        QVideoFrameFormat format(QSize(width, height), QVideoFrameFormat::Format_YUYV);
        QVideoFrame videoFrame(format);

        if (!videoFrame.map(QVideoFrame::WriteOnly)) {
            qWarning() << "❌ LocalVideoManager: Failed to map YUY2 video frame";
            return QVideoFrame();
        }

        // YUY2 是打包格式，直接复制整个缓冲区
        size_t bufferSize = width * height * 2;  // YUY2 每像素2字节
        memcpy(videoFrame.bits(0), frame->buf, bufferSize);

        videoFrame.unmap();

        static int logCount = 0;
        if (logCount == 0) {
            qDebug() << "✅ LocalVideoManager: Using Qt native YUYV format for YUY2 video:" << width << "x" << height;
            logCount++;
        }

        return videoFrame;
    }
    else if (pjfmt == PJMEDIA_FORMAT_I420 || pjfmt == PJMEDIA_FORMAT_IYUV || pjfmt == PJMEDIA_FORMAT_J420) {
        // I420/IYUV/J420 -> 使用Qt的YUV420P格式
        QVideoFrameFormat format(QSize(width, height), QVideoFrameFormat::Format_YUV420P);
        QVideoFrame videoFrame(format);

        if (!videoFrame.map(QVideoFrame::WriteOnly)) {
            qWarning() << "❌ LocalVideoManager: Failed to map YUV video frame";
            return QVideoFrame();
        }

        // YUV420P内存布局：Y平面 + U平面 + V平面
        const unsigned char *src_y = (const unsigned char *)frame->buf;
        const unsigned char *src_u = src_y + width * height;
        const unsigned char *src_v = src_u + (width * height / 4);

        // 复制Y平面
        unsigned char *dst_y = videoFrame.bits(0);
        memcpy(dst_y, src_y, width * height);

        // 复制U平面
        unsigned char *dst_u = videoFrame.bits(1);
        memcpy(dst_u, src_u, width * height / 4);

        // 复制V平面
        unsigned char *dst_v = videoFrame.bits(2);
        memcpy(dst_v, src_v, width * height / 4);

        videoFrame.unmap();

        static int logCount = 0;
        if (logCount == 0) {
            qDebug() << "✅ LocalVideoManager: Using Qt native YUV420P format for"
                     << (pjfmt == PJMEDIA_FORMAT_J420 ? "J420" : "I420")
                     << "video:" << width << "x" << height;
            logCount++;
        }

        return videoFrame;
    }
    else if (pjfmt == PJMEDIA_FORMAT_RGB24) {
        // RGB24 -> 直接使用QImage然后转换
        QImage image((const uchar *)frame->buf, width, height, width * 3, QImage::Format_RGB888);

        QVideoFrameFormat format(image.size(), QVideoFrameFormat::Format_ARGB8888);
        QVideoFrame videoFrame(format);

        if (!videoFrame.map(QVideoFrame::WriteOnly)) {
            qWarning() << "❌ LocalVideoManager: Failed to map video frame";
            return QVideoFrame();
        }

        QImage rgbImage = image.convertToFormat(QImage::Format_ARGB32);
        memcpy(videoFrame.bits(0), rgbImage.bits(), rgbImage.sizeInBytes());
        videoFrame.unmap();

        return videoFrame;
    }
    else if (pjfmt == PJMEDIA_FORMAT_RGBA) {
        // RGBA -> 直接使用QImage然后转换
        QImage image((const uchar *)frame->buf, width, height, width * 4, QImage::Format_RGBA8888);

        QVideoFrameFormat format(image.size(), QVideoFrameFormat::Format_ARGB8888);
        QVideoFrame videoFrame(format);

        if (!videoFrame.map(QVideoFrame::WriteOnly)) {
            qWarning() << "❌ LocalVideoManager: Failed to map video frame";
            return QVideoFrame();
        }

        QImage rgbImage = image.convertToFormat(QImage::Format_ARGB32);
        memcpy(videoFrame.bits(0), rgbImage.bits(), rgbImage.sizeInBytes());
        videoFrame.unmap();

        return videoFrame;
    }
    else {
        qWarning() << "❌ LocalVideoManager: Unsupported format:" << Qt::hex << pjfmt;
        return QVideoFrame();
    }
}

// ❌ 2026-01-11 22:00 [FIX 69.6 已弃用] 遍历窗口数组方法失败
// 原因：Fix 32 启用时，摄像头没有创建窗口（PJSUA_VID_PREVIEW_DISABLE）
// 证据：日志显示 "No active camera window found"，因为根本没有创建窗口
// 解决：改用 Fix 69.9（通过 vid_conf API 查询端口连接关系）

// ✅ 2026-01-11 22:00 [修复 69.9] 通过 vid_conf API 获取 cap_slot
// 原理：查询 enc_slot 的 transmitters（数据源），找到连接的 cap_slot
// 原因：Fix 32 启用时，摄像头没有创建窗口，无法通过窗口数组查找
// 解决：使用 pjsua_vid_conf_get_port_info() API 查询端口连接关系
// 详细：docs/2026-01-11/62-Fix69.9-通过vidconf-API获取capslot.md
// 架构：cap_slot (摄像头) → enc_slot (编码器) → RTP
//       我们有 enc_slot，查询其 transmitters[0] 即可得到 cap_slot
pjsua_conf_port_id LocalVideoManager::findActiveCallCaptureSlot(int capDevId)
{
    pjsua_call_id call_ids[PJSUA_MAX_CALLS];
    unsigned call_count = PJSUA_MAX_CALLS;

    // 获取所有活跃通话
    pj_status_t status = pjsua_enum_calls(call_ids, &call_count);
    if (status != PJ_SUCCESS || call_count == 0) {
        qDebug() << "   [FIX 69.9] No calls found, status:" << status << ", count:" << call_count;
        return PJSUA_INVALID_ID;  // 无活跃通话
    }

    qDebug() << "   [FIX 69.9] Found" << call_count << "calls, searching for video...";

    // 遍历所有通话，查找视频通话
    for (unsigned i = 0; i < call_count; ++i) {
        pjsua_call_info ci;
        status = pjsua_call_get_info(call_ids[i], &ci);
        if (status != PJ_SUCCESS) {
            continue;
        }

        qDebug() << "   [FIX 69.9] Call" << i << "has" << ci.media_cnt << "media streams";

        // 遍历媒体流，查找视频流
        for (unsigned mi = 0; mi < ci.media_cnt; ++mi) {
            if (ci.media[mi].type != PJMEDIA_TYPE_VIDEO) {
                continue;
            }

            if (ci.media[mi].status != PJSUA_CALL_MEDIA_ACTIVE) {
                continue;
            }

            // ✅ 找到活跃的视频流
            qDebug() << "   [FIX 69.9] Found active video media at index" << mi;

            // ✅ 2026-01-11 [修复 69.9] 通过内部结构体访问 enc_slot
            // 注意：pjsua_call_info 不包含 enc_slot，需要访问 pjsua_var.calls[]
            pjsua_call *call = &pjsua_var.calls[call_ids[i]];
            pjsua_call_media *call_med = &call->media[mi];

            if (call_med->strm.v.strm_enc_slot == PJSUA_INVALID_ID) {
                qDebug() << "   [FIX 69.9] enc_slot is invalid, skipping";
                continue;
            }

            pjsua_conf_port_id enc_slot = call_med->strm.v.strm_enc_slot;
            qDebug() << "   [FIX 69.9] Found enc_slot:" << enc_slot;

            // ✅ 2026-01-11 [修复 69.9] 查询 enc_slot 的端口信息
            pjsua_vid_conf_port_info port_info;
            status = pjsua_vid_conf_get_port_info(enc_slot, &port_info);
            if (status != PJ_SUCCESS) {
                qDebug() << "   [FIX 69.9] Failed to get port info, status:" << status;
                continue;
            }

            qDebug() << "   [FIX 69.9] enc_slot port info:";
            qDebug() << "      name:" << QString::fromUtf8(port_info.name.ptr, port_info.name.slen);
            qDebug() << "      transmitter_cnt:" << port_info.transmitter_cnt;
            qDebug() << "      listener_cnt:" << port_info.listener_cnt;

            // ✅ 2026-01-11 [修复 69.9] 获取 enc_slot 的数据源（cap_slot）
            // transmitters[0] 应该是摄像头端口
            if (port_info.transmitter_cnt > 0) {
                pjsua_conf_port_id cap_slot = port_info.transmitters[0];
                qDebug() << "✅ [FIX 69.9] Found cap_slot via vid_conf API:" << cap_slot;
                qDebug() << "   Connection: cap_slot(" << cap_slot << ") → enc_slot(" << enc_slot << ")";
                return cap_slot;
            } else {
                qDebug() << "   [FIX 69.9] enc_slot has no transmitters (unexpected)";
            }
        }
    }

    qDebug() << "   [FIX 69.9] No active video call found";
    return PJSUA_INVALID_ID;  // 未找到
}

// ========== Fix 69.12: 自定义端口管理（模仿 RemoteVideoManager）==========

#ifdef __linux__

bool LocalVideoManager::createCustomPort(int width, int height, int fps_num, int fps_denum)
{
    if (m_customPort) {
        return true;  // 已经创建
    }

    // 创建内存池
    m_customPool = pjsua_pool_create("local_video_custom_port", 4000, 4000);
    if (!m_customPool) {
        qCritical() << "❌ [FIX 69.12] Failed to create pool for custom port";
        return false;
    }

    // 分配 pjmedia_port 结构
    m_customPort = (pjmedia_port*)pj_pool_zalloc(m_customPool, sizeof(pjmedia_port));
    if (!m_customPort) {
        pj_pool_release(m_customPool);
        m_customPool = nullptr;
        return false;
    }

    // 初始化 port 信息
    pj_str_t name = pj_str((char*)"qt_local_video_sink");
    pjmedia_port_info_init(&m_customPort->info, &name,
                           PJMEDIA_SIG_CLASS_PORT_VID('L', 'C'),  // LC = Local Camera
                           90000,  // clock_rate (90kHz for video)
                           1,      // channel_count
                           16,     // bits_per_sample
                           1);     // samples_per_frame

    // ✅ 设置视频格式 - 使用实际的分辨率和帧率
    pjmedia_format_init_video(&m_customPort->info.fmt,
                              PJMEDIA_FORMAT_I420,
                              width, height,        // 使用实际视频尺寸
                              fps_num, fps_denum);  // 使用实际帧率

    // ✅ 关键: 设置回调函数
    m_customPort->put_frame = &LocalVideoManager::port_put_frame;  // PJSIP 推送帧
    m_customPort->get_frame = &LocalVideoManager::port_get_frame;  // 不需要
    m_customPort->on_destroy = &LocalVideoManager::port_on_destroy;

    // 将 this 指针存储在 port_data 中,以便在静态回调中访问
    m_customPort->port_data.pdata = this;

    // ✅ 2026-01-12 02:15 [修复 100.62] 保存 port → pool 映射
    // 原因：port_on_destroy 需要释放 pool，但不能访问 this（可能已析构）
    // 解决：将映射保存到静态 map，on_destroy 时从 map 中获取 pool
    // 详细：docs/2026-01-12/72-完整根因分析-崩溃的真正原因.md
    s_portPoolMap[m_customPort] = m_customPool;

    qDebug() << "✅ [FIX 69.12] Custom pjmedia_port created for local preview:"
             << width << "x" << height << "@" << fps_num << "/" << fps_denum << "fps";

    return true;
}

void LocalVideoManager::destroyCustomPort()
{
    if (m_customPort) {
        m_customPort = nullptr;  // port 由 pool 管理
    }

    if (m_customPool) {
        pj_pool_release(m_customPool);
        m_customPool = nullptr;
        qDebug() << "✅ [FIX 69.12] Custom port pool released";
    }
}

// ========== PJSIP 静态回调函数 (C 风格，模仿 RemoteVideoManager) ==========

pj_status_t LocalVideoManager::port_put_frame(pjmedia_port *port, pjmedia_frame *frame)
{
    // ✅ PJSIP 在摄像头有新帧时主动调用这个函数 (Push 模式!)
    static int callback_count = 0;
    static int video_frames = 0;
    static int non_video_frames = 0;
    static qint64 last_log_time = 0;

    qint64 current_time = QDateTime::currentMSecsSinceEpoch();

    callback_count++;

    // 每秒统计一次回调频率
    if (last_log_time == 0) {
        last_log_time = current_time;
    } else if (current_time - last_log_time >= 1000) {
        qDebug() << "🎯 [LOCAL PUSH]" << "Video frames:" << video_frames
                 << "| Non-video:" << non_video_frames
                 << "| Total callbacks:" << callback_count;
        last_log_time = current_time;
        video_frames = 0;
        non_video_frames = 0;
    }

    // 从 port_data 恢复 this 指针
    LocalVideoManager *self = static_cast<LocalVideoManager*>(port->port_data.pdata);

    if (!self) {
        return PJ_SUCCESS;
    }

    // ✅ 统计帧类型
    if (frame->type != PJMEDIA_FRAME_TYPE_VIDEO) {
        non_video_frames++;
        return PJ_SUCCESS;
    }

    // ✅ 安全检查：验证帧数据有效性
    if (!frame->buf || frame->size == 0) {
        return PJ_SUCCESS;  // 静默忽略无效帧
    }

    video_frames++;

    // 调用成员函数处理帧
    self->onLocalFrameReceived(frame, &port->info.fmt);

    return PJ_SUCCESS;
}

pj_status_t LocalVideoManager::port_get_frame(pjmedia_port *port, pjmedia_frame *frame)
{
    // Sink port 不需要提供帧
    PJ_UNUSED_ARG(port);
    frame->type = PJMEDIA_FRAME_TYPE_NONE;
    return PJ_SUCCESS;
}

pj_status_t LocalVideoManager::port_on_destroy(pjmedia_port *port)
{
    // ✅ 2026-01-12 02:15 [修复 100.62] 从静态映射中获取 pool 并释放
    // 原因：不能访问 this 指针（可能已析构），但需要释放 pool
    // 解决：从静态映射中查找 port → pool，释放后从映射中移除
    // 时机：vid_conf 真正销毁 port 时调用，此时 PJSIP 所有清理已完成
    // 详细：docs/2026-01-12/72-完整根因分析-崩溃的真正原因.md

    auto it = s_portPoolMap.find(port);
    if (it != s_portPoolMap.end()) {
        pj_pool_t *pool = it->second;
        qDebug() << "📹 [FIX 100.62] port_on_destroy: Found pool in map, releasing...";
        pj_pool_release(pool);
        s_portPoolMap.erase(it);
        qDebug() << "✅ [FIX 100.62] Pool released in on_destroy callback";
    } else {
        qDebug() << "⚠️ [FIX 100.62] port_on_destroy: Port not found in map (already cleaned?)";
    }

    PJ_UNUSED_ARG(port);
    return PJ_SUCCESS;
}

// ========== 延迟清理实现 ==========

#ifdef __linux__
// ❌ 2026-01-12 02:15 [修复 100.62] 不再需要延迟清理函数
// 原因：pool 由 port_on_destroy 回调释放，时机完全正确
// 详细：docs/2026-01-12/72-完整根因分析-崩溃的真正原因.md
//
// void LocalVideoManager::performDelayedCleanup()
// {
//     QMutexLocker locker(&m_cleanupMutex);
//
//     qDebug() << "⏰ [FIX 100.59] Delayed cleanup timer triggered (200ms elapsed)";
//
//     if (m_customPool) {
//         qDebug() << "   [FIX 100.59] Releasing pool now (PJSIP async operations should be complete)";
//         pj_pool_release(m_customPool);
//         m_customPool = nullptr;
//         qDebug() << "✅ [FIX 100.59] Custom port pool released safely (delayed cleanup complete)";
//     } else {
//         qDebug() << "   [FIX 100.59] Pool already released, nothing to do";
//     }
// }
#endif

// ========== 帧处理 (Push 模式核心) ==========

void LocalVideoManager::onLocalFrameReceived(pjmedia_frame *frame, const pjmedia_format *fmt)
{
    // ✅ 在 PJSIP 线程中调用，需要快速处理
    // 注意：不同于 RemoteVideoManager，这里直接转换发送，因为本地预览帧率较低

    static int frameCount = 0;
    static qint64 lastLogTime = 0;
    static qint64 lastFrameTime = 0;
    static int framesInSecond = 0;
    static qint64 totalFrameInterval = 0;
    static int intervalSamples = 0;

    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();

    // 首帧日志
    if (frameCount == 0 && fmt) {
        pjmedia_video_format_detail *vfd = pjmedia_format_get_video_format_detail(fmt, PJ_TRUE);
        if (vfd) {
            qDebug() << "🎬 [FIRST LOCAL FRAME] Format:" << vfd->size.w << "x" << vfd->size.h
                     << "@" << vfd->fps.num << "/" << vfd->fps.denum << "fps"
                     << "| Buffer size:" << frame->size << "bytes";
        }
    }

    // 统计帧间隔
    if (lastFrameTime > 0) {
        qint64 interval = currentTime - lastFrameTime;
        totalFrameInterval += interval;
        intervalSamples++;
    }
    lastFrameTime = currentTime;

    // 转换帧并发送到 QVideoSink
    QVideoFrame videoFrame = convertPjFrameToQt(frame, fmt);
    if (videoFrame.isValid()) {
        m_videoSink->setVideoFrame(videoFrame);
        frameCount++;
        framesInSecond++;
    }

    // 每秒统计一次性能
    if (lastLogTime == 0) {
        lastLogTime = currentTime;
    } else if (currentTime - lastLogTime >= 1000) {
        qint64 elapsedMs = currentTime - lastLogTime;
        double actualFps = (framesInSecond * 1000.0) / elapsedMs;
        double avgInterval = intervalSamples > 0 ? (double)totalFrameInterval / intervalSamples : 0;

        qDebug() << "📤 [LOCAL VIDEO SEND]"
                 << "FPS:" << QString::number(actualFps, 'f', 1)
                 << "| Avg interval:" << QString::number(avgInterval, 'f', 1) << "ms"
                 << "| Total frames:" << frameCount;

        // 重置计数器
        lastLogTime = currentTime;
        framesInSecond = 0;
        totalFrameInterval = 0;
        intervalSamples = 0;
    }
}

#endif  // __linux__

