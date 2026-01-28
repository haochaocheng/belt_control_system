import QtQuick

// ✅ 2026-01-27 [FIX 100.300.54]: 添加选中状态支持
// 使用 states 切换图片：IN_Data.png <-> IN_Data_OK.png
Image {
    id: iN_Data
    source: "images/IN_Data.png"
    fillMode: Image.PreserveAspectFit

    // ✅ 选中状态属性
    property bool selected: false

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
