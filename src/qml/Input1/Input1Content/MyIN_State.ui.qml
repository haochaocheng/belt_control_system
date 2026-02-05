import QtQuick

Image {
    id: iN_State
    source: "images/IN_State.png"
    fillMode: Image.PreserveAspectFit

    Text {
        id: text1
        x: 32
        y: 0
        width: 142
        height: 39
        color: "#eaeaea"
        text: qsTr("模块状态")
        font.pixelSize: 30
    }
}
