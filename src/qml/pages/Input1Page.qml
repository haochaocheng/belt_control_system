// 文件: src/qml/pages/Input1Page.qml
// 描述: 输入监控页面（第五个页面，Qt Design Studio 设计）
// 创建时间: 2026-01-12
// 更新时间: 2026-01-12（消除符号链接，QDS 项目直接集成）
//
// 此页面集成了 Qt Design Studio 设计的输入监控界面
// QDS 项目路径: E:\2025\3_gongkongji\belt_control_system\src\qml\Input1
//
// 工作流程:
// 1. 在 Qt Design Studio 中打开 Input1 项目（直接打开 src/qml/Input1）
// 2. 编辑 Screen01.ui.qml 设计界面
// 3. 保存后运行同步脚本更新资源列表：.\scripts\2026-01-12\09-sync-input1-resources.ps1
// 4. 重新编译即可看到效果

import QtQuick
import QtQuick.Controls
// 2026-01-12: Input1 模块文件已打包到 BeltControlQml 模块中
// 直接引用 Input1/Input1Content/Screen01 即可，无需单独 import

Item {
    id: input1Page
    // 2026-01-12: 移除 anchors.fill - SwipeView 子项不能使用 anchors
    // SwipeView 会自动管理子项的尺寸和位置
    // anchors.fill: parent  // ❌ 与 SwipeView 冲突，导致 polish() 循环
    // ⚠️ 不要再绑定 parent.width/height，SwipeView 下会形成尺寸正反馈
    // 仅使用 SwipeView 分配给当前页的 width/height

    // ✅ 2026-02-12 [Phase 7.45.30]
    // 历史问题：在 SwipeView 中额外绑定 parent.width/height + 尺寸监听，触发尺寸正反馈
    // 现方案：不绑定 parent 尺寸，且只在尺寸就绪后激活 Loader

    // 页面属性
    property string pageTitle: "输入监控"
    property bool isActive: false
    property int currentPageIndex: 0  // ✅ 2026-01-20 [FIX 100.255]

    // ✅ 2026-01-20 [FIX 100.259/100.270]: 调试 currentPageIndex 传递
    // Input1Page.qml 不是 .ui.qml，可以使用 JavaScript 输出调试日志
    onCurrentPageIndexChanged: {
        console.log("🔵 [Input1Page] currentPageIndex changed:", currentPageIndex)
        console.log("   Expected: 4 (模块状态是第5页)")

        // ✅ 2026-01-20 [FIX 100.269/100.270]: 验证传递到 Screen01 和 Head
        if (screenLoader.item) {
            console.log("   → Passing to Screen01.currentPageIndex")
            console.log("   → Screen01.currentPageIndex =", screenLoader.item.currentPageIndex)

            // ✅ 2026-01-20 [FIX 100.270]: 通过访问 Screen01 内部获取 Head 状态
            // 替代 Head.ui.qml 中的调试日志（Head.ui.qml 不能使用 JavaScript）
            var head = screenLoader.item.children[1]  // Head 是 Screen01 的第2个子元素
            if (head && head.currentPageIndex !== undefined) {
                console.log("📋 [Screen01] currentPageIndex changed:", screenLoader.item.currentPageIndex)
                console.log("   → Will pass to Head.currentPageIndex")
                console.log("🎯 [Head] currentPageIndex changed:", head.currentPageIndex)
                console.log("   menu1_home isActive:", head.currentPageIndex === 0)
                console.log("   menu2_params isActive:", head.currentPageIndex === 1)
                console.log("   menu3_alarm isActive:", head.currentPageIndex === 2)
                console.log("   menu4_log isActive:", head.currentPageIndex === 3)
                console.log("   menu5_status isActive:", head.currentPageIndex === 4)
            }
        } else {
            console.log("   ⚠️ Screen01 not loaded yet")
        }
    }

    // QDS 设计的主界面
    // 2026-01-20 [FIX 100.259]: 恢复缩放逻辑
    // Screen01 保持固定尺寸 1920x1080，由 Loader 应用缩放
    Loader {
        id: screenLoader

        // ✅ 固定原始尺寸（QDS 设计尺寸）
        width: 1920
        height: 1080
        // ✅ 2026-02-12 [Phase 7.45.31]: 提高阈值，确保尺寸接近最终值时才加载
        // 原因：height=16 时就激活，导致 yScale=0.015，Canvas 绘制失败
        // 解决：要求尺寸至少达到设计尺寸的 50%（960x540）
        active: input1Page.width >= 960 && input1Page.height >= 540

        source: "../Input1/Input1Content/Screen01.qml"  // ✅ 2026-01-27 [FIX 100.300.57]: 使用相对路径以支持 QDS

        // ✅ 2026-01-20 [FIX 100.262]: 改为非等比缩放（填满整个屏幕）
        transform: Scale {
            id: scaleTransform
            xScale: Math.max(1, Math.min(input1Page.width, 3840)) / 1920
            yScale: Math.max(1, Math.min(input1Page.height, 2160)) / 1080
            origin.x: 0  // ✅ 左上角缩放
            origin.y: 0  // ✅ 左上角缩放
        }

        onLoaded: {
            console.log("✅ Input1 Screen01 加载成功")

            // ✅ 2026-03-22 [Phase 7.48.82.3]: 只在SwipeView内才禁止Screen01自动抢焦点
            // QDS独立预览时没有SwipeView父级，SwipeView.view为null，不设置此属性
            // 设备运行时Input1Page在SwipeView中，SwipeView.view有值，禁止自动焦点
            // 旧代码：screenLoader.item.autoFocusOnLoad = false  // 无条件禁止，QDS也被禁止了
            if (input1Page.SwipeView.view) {
                screenLoader.item.autoFocusOnLoad = false
                console.log("✅ [Input1Page] SwipeView模式 - 禁止Screen01自动焦点")
            } else {
                console.log("✅ [Input1Page] QDS独立模式 - 允许Screen01自动焦点")
            }
            console.log("   [布局] 屏幕尺寸:", input1Page.width.toFixed(0), "x", input1Page.height.toFixed(0))
            console.log("🔍 [Input1Page] 缩放调试:")
            console.log("   xScale (宽度缩放):", (Math.max(1, Math.min(input1Page.width, 3840)) / 1920).toFixed(3))
            console.log("   yScale (高度缩放):", (Math.max(1, Math.min(input1Page.height, 2160)) / 1080).toFixed(3))
            console.log("   预期显示尺寸:", Math.max(1, Math.min(input1Page.width, 3840)).toFixed(0), "x", Math.max(1, Math.min(input1Page.height, 2160)).toFixed(0))

            // ✅ 2026-01-20 [FIX 100.257]: 传递 currentPageIndex 到 Screen01
            // ✅ 2026-01-20 [FIX 100.269]: 添加调试日志验证绑定
            if (screenLoader.item) {
                console.log("🔗 [Input1Page] 设置 Screen01.currentPageIndex 绑定")
                console.log("   input1Page.currentPageIndex =", input1Page.currentPageIndex)
                screenLoader.item.currentPageIndex = Qt.binding(function() {
                    console.log("📡 [Binding] Screen01.currentPageIndex 更新 =", input1Page.currentPageIndex)
                    return input1Page.currentPageIndex
                })
                console.log("   Screen01.currentPageIndex =", screenLoader.item.currentPageIndex)
            } else {
                console.log("⚠️ [Input1Page] screenLoader.item is null")
            }
        }

        onStatusChanged: {
            if (screenLoader.status === Loader.Error) {
                console.error("❌ Input1 Screen01 加载失败")
                errorOverlay.visible = true
            }
        }
    }

    // 错误提示覆盖层
    Rectangle {
        id: errorOverlay
        anchors.fill: parent
        color: "#000000"
        visible: false

        Text {
            anchors.centerIn: parent
            text: "❌ Input1 Screen01 加载失败\n\n请检查:\n1. CMakeLists.txt 是否包含所有 Input1 文件\n2. 图片资源文件名是否全为英文\n3. 运行同步脚本：.\\scripts\\2026-01-12\\09-sync-input1-resources.ps1\n4. 重新编译项目"
            color: "#FF0000"
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // 页面激活/停用事件
    Component.onCompleted: {
        console.log("Input1Page 已加载")

        // ✅ 2026-01-20 [FIX 100.262]: 在页面完成时输出缩放调试信息
        console.log("🔍 [Input1Page] 缩放调试（Component.onCompleted）:")
        console.log("   input1Page.width:", width)
        console.log("   input1Page.height:", height)
        console.log("   xScale (宽度缩放):", (width / 1920).toFixed(3))
        console.log("   yScale (高度缩放):", (height / 1080).toFixed(3))
        console.log("   预期显示尺寸:", width, "x", height)
    }

    Component.onDestruction: {
        console.log("Input1Page 已卸载")
    }

    // 页面状态变化监听
    onIsActiveChanged: {
        console.log("Input1Page 激活状态:", isActive)

        if (isActive) {
            // 页面激活时的逻辑
            // 例如：开始定时刷新数据
        } else {
            // 页面停用时的逻辑
            // 例如：停止定时刷新
        }
    }
}
