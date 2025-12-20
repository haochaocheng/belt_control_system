# Qt Multimedia 视频预览集成问题说明

## 问题现象

尝试使用 Qt Multimedia 的 VideoOutput 组件集成视频预览时，导致整个拨号界面无法显示（所有控件消失）。

## 根本原因

### 1. VideoOutput 组件在 Qt 6.5 中的状态

检查 Qt 6.5.3 的 QtMultimedia 模块发现：

```bash
/c/Qt/6.5.3/mingw_64/qml/QtMultimedia/
├── plugins.qmltypes    # 包含 VideoOutput 类型定义
├── qmldir               # 但 qmldir 中未导出 VideoOutput
├── Video.qml            # 只导出了 Video 组件
└── quickmultimediaplugin.dll
```

**关键发现：**
- `VideoOutput` 在 `plugins.qmltypes` 中有定义（C++ 类型）
- 但 `qmldir` 文件中**没有导出** VideoOutput
- 只导出了 `Video` 组件（用于播放视频文件，不适合实时流）

### 2. QML 导入失败

当 QML 文件中使用：
```qml
import QtMultimedia 6.5

VideoOutput {
    videoSink: SipPhoneManager.qtVideoPreview.videoSink
}
```

由于 VideoOutput 未正式导出，QML 引擎无法找到该类型，导致整个 QML 文件加载失败，所有控件都不显示。

### 3. 嵌套属性访问问题

即使 VideoOutput 可用，以下代码在 QML 初始化时也会失败：
```qml
videoSink: SipPhoneManager.qtVideoPreview.videoSink
```

原因：
- QML 属性绑定在对象创建时立即求值
- 如果 `qtVideoPreview` 为 null 或 `videoSink` 未初始化，整个绑定失败
- 失败的属性绑定会导致组件创建失败

## 临时解决方案

### 当前状态

已恢复界面正常显示，采用占位符方式：

```qml
// 移除 QtMultimedia 导入
// import QtMultimedia 6.5  // ❌ 移除

Rectangle {
    visible: videoPreviewButton.previewActive

    // 占位符矩形
    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a"

        Text {
            text: "视频预览功能\n(Qt Multimedia 集成调试中)"
            color: "#7f8c8d"
        }
    }
}
```

### 保留的代码

C++ 端的 QtVideoPreview 类已经实现完成，包括：
- ✅ `QtVideoPreview.h/cpp` - 摄像头访问和 QVideoSink
- ✅ `SipPhoneManager` 集成 - qtVideoPreview 属性
- ✅ CMake 配置 - Qt6::Multimedia 链接

## 正确的集成方法

### 方法 1：使用 QML C++ 插件（推荐）

创建自定义 QML 类型直接包装 QVideoSink：

```cpp
// CustomVideoOutput.h
class CustomVideoOutput : public QQuickItem {
    Q_OBJECT
    Q_PROPERTY(QObject* videoSink READ videoSink WRITE setVideoSink)

public:
    QObject* videoSink() const { return m_videoSink; }
    void setVideoSink(QObject* sink);

protected:
    QSGNode* updatePaintNode(QSGNode*, UpdatePaintNodeData*) override;

private:
    QVideoSink* m_videoSink;
};

// main.cpp
qmlRegisterType<CustomVideoOutput>("BeltControl.Video", 1, 0, "VideoOutput");
```

QML 使用：
```qml
import BeltControl.Video 1.0

VideoOutput {
    videoSink: SipPhoneManager.qtVideoPreview.videoSink
}
```

### 方法 2：使用 Qt Quick Widgets（Qt 6.2+）

Qt 6.2+ 引入了 `QQuickWidget` for QML，可以嵌入 Qt Widgets：

```cpp
// 在 QML 中创建 QQuickWidget
QQuickWidget *videoWidget = new QQuickWidget();
videoWidget->setSource(QUrl("qrc:/VideoPreview.qml"));

// 将 widget 嵌入到 QML (需要 Qt Quick Controls 原生窗口)
```

但这会带回之前的窗口嵌入问题。

### 方法 3：回退到 PJSIP SDL 预览（当前使用）

继续使用 PJSIP 的原生视频预览（SDL 独立窗口）：

```cpp
// SipPhoneManager::startVideoPreview()
pjsua_vid_preview_start(captureDevice, &preview_param);
```

优点：
- ✅ 已经实现完成
- ✅ PJSIP 官方支持
- ✅ 与视频通话统一使用 PJSIP

缺点：
- ❌ SDL 窗口无法真正嵌入（SetParent 失败）
- ❌ 独立浮动窗口，用户体验差

## 推荐方案

### 短期方案（当前）

保持使用 PJSIP SDL 预览（已实现），但改进窗口管理：

1. ✅ 使用无边框窗口（WS_POPUP）
2. ✅ 设置 HWND_TOPMOST（始终置顶）
3. ✅ 通过 SetWindowPos 定位到 SIP 窗口上方
4. ⚠️ 用户需手动关闭（"停止预览"按钮）

优点：
- 无需额外开发
- 稳定可靠
- 与视频通话统一

缺点：
- 仍然是独立窗口（用户需求不满足）

### 长期方案（推荐）

**实现自定义 QML VideoOutput 类型**（方法 1）：

**开发工作量估计：**
- C++ QQuickItem 实现：2-3 小时
- QSGNode 纹理渲染：3-4 小时
- QML 集成测试：1-2 小时
- **总计：6-9 小时**

**收益：**
- ✅ 完美集成到 QML 界面中
- ✅ 无独立窗口
- ✅ 完全满足用户需求："直接做嵌入在sip界面"

## 当前状态总结

| 组件 | 状态 | 说明 |
|------|------|------|
| QtVideoPreview C++ 类 | ✅ 已实现 | 可访问摄像头，提供 QVideoSink |
| SipPhoneManager 集成 | ✅ 已完成 | qtVideoPreview 属性可用 |
| QML VideoOutput | ❌ 未实现 | VideoOutput 组件不可用 |
| PJSIP SDL 预览 | ✅ 可用 | 独立窗口，无法嵌入 |
| 拨号界面显示 | ✅ 已恢复 | 移除 QtMultimedia 导入 |

## 后续步骤

### 选项 A：继续使用 PJSIP SDL（快速）

1. 恢复 `startVideoPreview()` 调用 PJSIP
2. 更新 QML 按钮调用 `SipPhoneManager.startVideoPreview()`
3. 接受独立窗口的限制

### 选项 B：开发自定义 VideoOutput（彻底解决）

1. 创建 `CustomVideoOutput` QQuickItem 类
2. 实现 QSGNode 纹理渲染
3. 注册到 QML
4. 更新 QML 使用自定义组件

---

**建议：先采用选项 A 恢复功能，再计划选项 B 作为后续优化。**
