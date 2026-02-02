import QtQuick

// ✅ 2026-01-27 [FIX 100.300.54]: 添加选中状态支持
// 使用 states 切换图片：IN_Data.png <-> IN_Data_OK.png
// ✅ 2026-02-02 [FIX 100.300.112.8.19]: 修复布局问题，改为响应式布局
// - 移除固定尺寸，使用相对定位和锚点
// - 装饰图片宽度跟随父容器，高度按比例缩放
// - 文字使用锚点定位，跟随装饰图片布局
Image {
    id: iN_Data
    source: "images/IN_Data.png"
    fillMode: Image.PreserveAspectFit

    // ✅ 选中状态属性
    property bool selected: false

    // ========== 第一行：投入状态 ==========
    Image {
        id: inputData_Zhuangshi
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 8
            rightMargin: 8
            topMargin: 122
        }
        height: 172  // 保持高度，但宽度跟随父容器
        source: "../../images/inputData_Zhuangshi.png"
        fillMode: Image.Stretch  // 拉伸填充，适应不同宽度
    }

    Text {
        id: text1
        anchors {
            left: inputData_Zhuangshi.left
            verticalCenter: inputData_Zhuangshi.verticalCenter
            leftMargin: 95  // 相对于装饰图片的左边距
        }
        color: "#eaeaea"
        text: qsTr("投入状态:")
        font.pixelSize: 40
        verticalAlignment: Text.AlignVCenter
    }

    // ========== 第二行：通讯 ==========
    Image {
        id: inputData_Zhuangshi1
        anchors {
            left: parent.left
            right: parent.right
            top: inputData_Zhuangshi.bottom
            leftMargin: 8
            rightMargin: 8
            topMargin: 9  // 与上一个装饰图片的间距 (303 - 122 - 172 = 9)
        }
        height: 172
        source: "../../images/inputData_Zhuangshi.png"
        fillMode: Image.Stretch
    }

    Text {
        id: text2
        anchors {
            left: inputData_Zhuangshi1.left
            verticalCenter: inputData_Zhuangshi1.verticalCenter
            leftMargin: 95
        }
        color: "#eaeaea"
        text: qsTr("通讯:")
        font.pixelSize: 40
        verticalAlignment: Text.AlignVCenter
    }

    // ========== 第三行：模式 ==========
    Image {
        id: inputData_Zhuangshi2
        anchors {
            left: parent.left
            right: parent.right
            top: inputData_Zhuangshi1.bottom
            leftMargin: 8
            rightMargin: 8
            topMargin: 6  // 与上一个装饰图片的间距 (481 - 303 - 172 = 6)
        }
        height: 172
        source: "../../images/inputData_Zhuangshi.png"
        fillMode: Image.Stretch
    }

    Text {
        id: text3
        anchors {
            left: inputData_Zhuangshi2.left
            verticalCenter: inputData_Zhuangshi2.verticalCenter
            leftMargin: 95
        }
        color: "#eaeaea"
        text: qsTr("模式:")
        font.pixelSize: 40
        verticalAlignment: Text.AlignVCenter
    }

    // ✅ 使用 states 切换图片
    states: [
        State {
            name: "normal"
            when: !iN_Data.selected
            PropertyChanges {
                target: iN_Data
                source: "images/IN_Data.png"
            }
        },
        State {
            name: "selected"
            when: iN_Data.selected
            PropertyChanges {
                target: iN_Data
                source: "images/IN_Data_OK.png"
            }
        }
    ]
}
