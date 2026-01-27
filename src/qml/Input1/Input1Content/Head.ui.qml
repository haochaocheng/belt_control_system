import QtQuick

// ✅ 2026-01-20 [FIX 100.255] 头部组件 - 5个菜单对应5个画面
Rectangle {
    id: rectangle
    width: 1920
    height: 100
    color: "#00333333"
    clip: true  // ✅ 2026-01-20 [FIX 100.257]: 裁剪超出边界的装饰线

    // 当前页面索引（0-4）- 从外部传入
    property int currentPageIndex: 0

    // ✅ 2026-01-20 [FIX 100.270]: 移除 JavaScript 代码块以兼容 QDS
    // 调试日志已移动到 Input1Page.qml（非 .ui.qml 文件）

    Image {
        id: head_Left_gradient
        x: 1
        y: 12
        source: "images/head_Left_gradient.svg"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_Right_gradient
        x: 1307
        y: 25
        source: "images/head_Right_gradient.svg"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_Right_triangle
        x: 1906
        y: 52
        source: "images/head_Right_triangle.svg"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_Right_triangle2
        x: 429
        y: 18
        source: "images/head_Right_triangle2.svg"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_Right_triangle3
        x: 453
        y: 18
        source: "images/head_Right_triangle3.svg"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_TopLeft_straight_line
        x: 0
        y: 6
        source: "images/head_Top-left_straight_line.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_TopLeft_straight_line2
        x: 380
        y: 6
        source: "images/head_Top-left_straight_line2.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_TopRight_straight_line
        x: 1548
        y: 6
        source: "images/head_Top-right_straight_line.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_TopRight_straight_line2
        x: 1524
        y: 6
        source: "images/head_Top-right_straight_line2.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line1
        x: 59
        y: 74
        source: "images/head_Bottom-left_straight_line1.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line10
        x: 1889
        y: 72
        width: 1
        height: 4
        source: "images/head_Bottom-left_straight_line10.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line11
        x: 33
        y: 72
        source: "images/head_Bottom-left_straight_line11.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line12
        x: 44
        y: 73
        source: "images/head_Bottom-left_straight_line12.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line13
        x: 1075
        y: 70
        source: "images/head_Bottom-left_straight_line13.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line14
        x: 852
        y: 71
        source: "images/head_Bottom-left_straight_line14.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line15
        x: 1685
        y: 66
        source: "images/head_Bottom-left_straight_line15.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line16
        x: 1725
        y: 66
        source: "images/head_Bottom-left_straight_line16.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line2
        x: 24
        y: 72
        source: "images/head_Bottom-left_straight_line2.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line3
        x: 30
        y: 72
        source: "images/head_Bottom-left_straight_line3.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line4
        x: 1863
        y: 72
        source: "images/head_Bottom-left_straight_line4.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line5
        x: 1864
        y: 73
        source: "images/head_Bottom-left_straight_line5.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line6
        x: 839
        y: 70
        source: "images/head_Bottom-left_straight_line6.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line7
        x: 1068
        y: 71
        source: "images/head_Bottom-left_straight_line7.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line8
        x: 1022
        y: 74
        source: "images/head_Bottom-left_straight_line8.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: head_BottomLeft_straight_line9
        x: 1892
        y: 72
        source: "images/head_Bottom-left_straight_line9.png"
        fillMode: Image.PreserveAspectFit
    }

    Head_MiddleMenu {
        id: menu1_home
        x: 520
        y: 25
        menuText: "首页"                        // 画面 1: ControlPanel
        isActive: rectangle.currentPageIndex === 0
    }

    Head_MiddleMenu {
        id: menu2_params
        x: 677
        y: 25
        menuText: "参数设置"                    // 画面 2: ParameterSettings
        isActive: rectangle.currentPageIndex === 1
    }

    Head_MiddleMenu {
        id: menu3_alarm
        x: 810
        y: 25
        menuText: "报警保护"                    // 画面 3: AlarmPage
        isActive: rectangle.currentPageIndex === 2
    }

    Head_MiddleMenu {
        id: menu4_log
        x: 950
        y: 25
        menuText: "运行日志"                    // 画面 4: DeviceOperationLog
        isActive: rectangle.currentPageIndex === 3
    }

    Head_MiddleMenu {
        id: menu5_status
        x: 1109
        y: 29
        menuText: "模块状态"                    // 画面 5: Input1Page
        isActive: rectangle.currentPageIndex === 4
    }
}
