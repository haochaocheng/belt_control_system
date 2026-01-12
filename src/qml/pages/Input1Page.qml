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
    anchors.fill: parent

    // 页面属性
    property string pageTitle: "输入监控"
    property bool isActive: false

    // QDS 设计的主界面
    // 2026-01-12: 使用新的路径（Input1 项目直接在 src/qml/Input1，无符号链接）
    Loader {
        id: screenLoader
        anchors.fill: parent
        source: "qrc:/qt/qml/BeltControlQml/Input1/Input1Content/Screen01.ui.qml"

        onLoaded: {
            console.log("✅ Input1 Screen01 加载成功")
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
