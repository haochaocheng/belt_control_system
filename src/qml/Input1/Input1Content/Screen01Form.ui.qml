

/*
This is a UI file (.ui.qml) that is intended to be edited in Qt Design Studio only.
It is supposed to be strictly declarative and only uses a subset of QML. If you edit
this file manually, you might introduce QML code that is not supported by Qt Design Studio.
Check out https://doc.qt.io/qtcreator/creator-quick-ui-forms.html for details on .ui.qml files.
*/
import QtQuick
import QtQuick.Controls
import Input1

Rectangle {
    width: 1920
    height: 1080

    // ✅ 2026-01-27 [FIX 100.300.53]: 重新设计布局 - 3行4列 MyIN_Data 网格
    // 移除 MyIN_State 组件，使用 12 个 MyIN_Data 组件
    // 部分运行环境 Constants 未注入，使用固定背景色避免 [undefined] QColor 告警
    color: "#0a1628"

    // ✅ 接收外部传入的当前页面索引
    property int currentPageIndex: 0

    // ✅ 2026-01-28 [FIX 100.300.63]: 暴露组件 ID 为属性，使外部可以访问
    // 原因：.ui.qml 文件的子组件 ID 默认是私有的，外部无法通过 screen01Form.data_row1_col1 访问
    // 解决方案：使用 property alias 显式暴露这些组件
    property alias data_row1_col1: data_row1_col1
    property alias data_row1_col2: data_row1_col2
    property alias data_row1_col3: data_row1_col3
    property alias data_row1_col4: data_row1_col4
    property alias data_row2_col1: data_row2_col1
    property alias data_row2_col2: data_row2_col2
    property alias data_row2_col3: data_row2_col3
    property alias data_row2_col4: data_row2_col4
    property alias data_row3_col1: data_row3_col1
    property alias data_row3_col2: data_row3_col2
    property alias data_row3_col3: data_row3_col3
    property alias data_row3_col4: data_row3_col4

    // ✅ 背景层
    Back {
        id: back
        anchors.fill: parent
        z: 0
    }

    // ✅ 头部组件
    Head {
        id: head
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 80
        currentPageIndex: currentPageIndex
    }

    // ✅ 2026-01-27 [FIX 100.300.53]: 3行4列网格布局
    // 布局参数：
    // - 可用区域：1920 x (1080-80) = 1920 x 1000
    // - 每个单元格：480 x 333.33
    // - 间距：0（紧密排列）

    // 第 1 行
    MyIN_Data {
        id: data_row1_col1
        x: 0
        y: 80
        width: 480
        height: 333
    }

    MyIN_Data {
        id: data_row1_col2
        x: 480
        y: 80
        width: 480
        height: 333
    }

    MyIN_Data {
        id: data_row1_col3
        x: 960
        y: 80
        width: 480
        height: 333
    }

    MyIN_Data {
        id: data_row1_col4
        x: 1440
        y: 80
        width: 480
        height: 333
    }

    // 第 2 行
    MyIN_Data {
        id: data_row2_col1
        x: 0
        y: 413
        width: 480
        height: 333
    }

    MyIN_Data {
        id: data_row2_col2
        x: 480
        y: 413
        width: 480
        height: 333
    }

    MyIN_Data {
        id: data_row2_col3
        x: 960
        y: 413
        width: 480
        height: 333
    }

    MyIN_Data {
        id: data_row2_col4
        x: 1440
        y: 413
        width: 480
        height: 333
    }

    // 第 3 行
    MyIN_Data {
        id: data_row3_col1
        x: 0
        y: 746
        width: 480
        height: 334
    }

    MyIN_Data {
        id: data_row3_col2
        x: 480
        y: 746
        width: 480
        height: 334
    }

    MyIN_Data {
        id: data_row3_col3
        x: 960
        y: 746
        width: 480
        height: 334
    }

    MyIN_Data {
        id: data_row3_col4
        x: 1440
        y: 746
        width: 480
        height: 334
    }
}
