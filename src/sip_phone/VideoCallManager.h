#ifndef VIDEOCALLMANAGER_H
#define VIDEOCALLMANAGER_H

#include <QObject>
#include <QQuickItem>
#include <pjsua.h>

/**
 * @brief 视频通话管理器
 *
 * 封装 PJSIP 视频 API，提供视频通话功能：
 * - 本地视频预览
 * - 视频通话发起和接听
 * - 视频流管理
 * - 摄像头控制
 */
class VideoCallManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool videoEnabled READ videoEnabled WRITE setVideoEnabled NOTIFY videoEnabledChanged)
    Q_PROPERTY(bool previewActive READ previewActive NOTIFY previewActiveChanged)
    Q_PROPERTY(bool inVideoCall READ inVideoCall NOTIFY inVideoCallChanged)
    Q_PROPERTY(QObject* localVideoWindow READ localVideoWindow NOTIFY localVideoWindowChanged)
    Q_PROPERTY(QObject* remoteVideoWindow READ remoteVideoWindow NOTIFY remoteVideoWindowChanged)

public:
    explicit VideoCallManager(QObject *parent = nullptr);
    virtual ~VideoCallManager();

    // 属性访问器
    bool videoEnabled() const { return m_videoEnabled; }
    void setVideoEnabled(bool enabled);

    bool previewActive() const { return m_previewActive; }
    bool inVideoCall() const { return m_inVideoCall; }

    QObject* localVideoWindow() const { return m_localVideoWindow; }
    QObject* remoteVideoWindow() const { return m_remoteVideoWindow; }

public slots:
    /**
     * @brief 启动本地视频预览
     * @return true 成功，false 失败
     */
    bool startPreview();

    /**
     * @brief 停止本地视频预览
     */
    void stopPreview();

    /**
     * @brief 发起视频通话
     * @param callId 当前音频通话的 ID
     * @return true 成功，false 失败
     */
    bool startVideoCall(int callId);

    /**
     * @brief 停止视频通话（视频流，但保持音频）
     * @param callId 通话 ID
     */
    void stopVideoCall(int callId);

    /**
     * @brief 切换摄像头开关
     */
    void toggleCamera();

    /**
     * @brief 设置本地视频窗口
     * @param window QQuickItem 指针
     */
    void setLocalVideoWindow(QObject* window);

    /**
     * @brief 设置远程视频窗口
     * @param window QQuickItem 指针
     */
    void setRemoteVideoWindow(QObject* window);

    /**
     * @brief 获取可用摄像头列表
     * @return 摄像头名称列表
     */
    QStringList getAvailableCameras();

    /**
     * @brief 切换摄像头
     * @param cameraIndex 摄像头索引
     */
    void switchCamera(int cameraIndex);

    /**
     * @brief 初始化视频子系统 (MUST be called AFTER PJSIP is initialized)
     * @return true 成功，false 失败
     */
    bool initVideoSubsystem();

    /**
     * @brief 获取当前捕获设备 ID
     * @return 捕获设备 ID (PJMEDIA device index)
     */
    pjmedia_vid_dev_index getCaptureDeviceId() const { return m_captureDevId; }
    pjmedia_vid_dev_index captureDevId() const { return m_captureDevId; }  // Alias for convenience

signals:
    void videoEnabledChanged();
    void previewActiveChanged();
    void inVideoCallChanged();
    void localVideoWindowChanged();
    void remoteVideoWindowChanged();
    void videoCallError(const QString& error);

private:
    bool m_videoEnabled;
    bool m_previewActive;
    bool m_inVideoCall;

    QObject* m_localVideoWindow;   // 本地视频窗口 (QQuickItem)
    QObject* m_remoteVideoWindow;  // 远程视频窗口 (QQuickItem)

    pjsua_call_id m_currentCallId;
    pjmedia_vid_dev_index m_captureDevId;  // 当前捕获设备 ID
    pjsua_vid_win_id m_previewWinId;      // 预览窗口 ID

    /**
     * @brief 创建视频窗口
     */
    pjsua_vid_win_id createVideoWindow(QObject* qmlWindow, bool isPreview);

    /**
     * @brief 销毁视频窗口
     */
    void destroyVideoWindow(pjsua_vid_win_id winId);
};

/**
 * @brief QML 视频渲染器
 *
 * 用于在 QML 中显示 PJSIP 视频流
 * 通过 native window handle 将 SDL/DirectShow 窗口嵌入到 QML 中
 */
class VideoRenderer : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(bool isPreview READ isPreview WRITE setIsPreview NOTIFY isPreviewChanged)

public:
    explicit VideoRenderer(QQuickItem *parent = nullptr);
    virtual ~VideoRenderer();

    bool isPreview() const { return m_isPreview; }
    void setIsPreview(bool preview);

    /**
     * @brief 获取原生窗口句柄
     */
    void* getNativeHandle();

signals:
    void isPreviewChanged();
    void nativeHandleReady();

protected:
    /**
     * @brief QQuickItem 生命周期
     */
    virtual void componentComplete() override;
    virtual void releaseResources() override;

private:
    bool m_isPreview;
    void* m_nativeHandle;

    void setupNativeWindow();
};

#endif // VIDEOCALLMANAGER_H
