import QtQuick

// ✅ 2026-01-27 [FIX 100.300.54]: 添加选中状态支持
// 使用 states 切换图片：IN_Data.png <-> IN_Data_OK.png
// ✅ 2026-02-02 [FIX 100.300.112.8.19.2]: 修复布局问题（第三版）
// - 使用 Column 布局，自动垂直排列三个装饰图片
// - 装饰图片宽度使用锚点跟随父容器
// - 文字使用锚点定位，垂直居中对齐装饰图片
// - 适应不同的容器高度（333px 或其他）
Image {
    id: iN_Data
    source: "images/IN_Data.png"
    fillMode: Image.PreserveAspectFit

    // ✅ 选中状态属性
    property bool selected: false

    // ✅ 使用 Column 布局，自动垂直排列
    Column {
        anchors.fill: parent
        anchors.topMargin: 20  // 顶部留白
        anchors.bottomMargin: 20  // 底部留白
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 10  // 装饰图片之间的间距

        // ========== 第一行：投入状态 ==========
        Item {
            width: parent.width
            height: (parent.height - parent.spacing * 2) / 3  // 平均分配高度

            Image {
                id: inputData_Zhuangshi
                anchors.fill: parent
                source: "../../images/inputData_Zhuangshi.png"
                fillMode: Image.Stretch
            }

            Text {
                id: text1
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 95
                }
                color: "#eaeaea"
                text: qsTr("投入状态:")
                font.pixelSize: 40
                verticalAlignment: Text.AlignVCenter
            }
        }

        // ========== 第二行：通讯 ==========
        Item {
            width: parent.width
            height: (parent.height - parent.spacing * 2) / 3

            Image {
                id: inputData_Zhuangshi1
                anchors.fill: parent
                source: "../../images/inputData_Zhuangshi.png"
                fillMode: Image.Stretch
            }

            Text {
                id: text2
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 95
                }
                color: "#eaeaea"
                text: qsTr("通讯:")
                font.pixelSize: 40
                verticalAlignment: Text.AlignVCenter
            }
        }

        // ========== 第三行：模式 ==========
        Item {
            width: parent.width
            height: (parent.height - parent.spacing * 2) / 3

            Image {
                id: inputData_Zhuangshi2
                anchors.fill: parent
                source: "../../images/inputData_Zhuangshi.png"
                fillMode: Image.Stretch
            }

            Text {
                id: text3
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 95
                }
                color: "#eaeaea"
                text: qsTr("模式:")
                font.pixelSize: 40
                verticalAlignment: Text.AlignVCenter
            }
        }
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
