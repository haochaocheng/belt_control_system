import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Chinese keyboard with Pinyin input
ColumnLayout {
    id: root
    spacing: 5

    property var targetInput: null
    property string pinyinBuffer: ""

    // Computed property for current candidates
    property var currentCandidates: {
        if (pinyinBuffer.length === 0) return []
        var candidates = pinyinMap[pinyinBuffer]
        return candidates ? candidates : []
    }

    // Common Chinese character mapping (simplified)
    // Extended vocabulary for belt control system
    property var pinyinMap: ({
        // Numbers
        "yi": ["一", "以", "已", "意"],
        "er": ["二", "而", "儿"],
        "san": ["三"],
        "si": ["四", "思", "斯"],
        "wu": ["五", "无", "物"],
        "liu": ["六", "流"],
        "qi": ["七", "起", "其", "气", "启"],
        "ba": ["八", "吧"],
        "jiu": ["九", "就"],
        "shi": ["十", "时", "是", "石", "室", "识"],

        // Common words
        "ni": ["你", "呢", "泥", "尼"],
        "hao": ["好", "号", "豪"],
        "de": ["的", "得", "德"],
        "ma": ["吗", "妈", "马", "麻"],
        "wo": ["我", "握"],
        "men": ["们", "门"],
        "ta": ["他", "她", "它", "塔"],
        "zhe": ["这", "着", "者"],
        "ge": ["个", "各"],
        "you": ["有", "又", "右"],
        "le": ["了", "乐"],
        "ren": ["人"],
        "shang": ["上"],
        "xia": ["下"],
        "zai": ["在", "再"],
        "dao": ["到", "道"],
        "chu": ["出"],
        "lai": ["来"],
        "qu": ["去"],

        // Belt control vocabulary
        "pi": ["皮"],
        "dai": ["带"],
        "ji": ["机", "级", "集"],
        "dian": ["电", "点"],
        "dong": ["动"],
        "ting": ["停", "听"],
        "kai": ["开"],
        "guan": ["关"],
        "kong": ["控"],
        "zhi": ["制", "置", "之", "址"],
        "xi": ["系"],
        "tong": ["统", "通"],
        "she": ["设", "社"],
        "bei": ["备"],
        "can": ["参"],
        "shu": ["数", "书"],
        "she": ["设"],
        "zhi": ["置"],
        "wang": ["网"],
        "luo": ["络"],
        "di": ["地", "第"],
        "zhi": ["址"],
        "duan": ["端"],
        "kou": ["口"],
        "yan": ["延"],
        "chi": ["迟"],
        "xun": ["讯"],
        "bao": ["保", "报"],
        "hu": ["护"],
        "gu": ["故"],
        "zhang": ["障"],
        "biao": ["标"],
        "su": ["速"],
        "du": ["度"],
        "wen": ["温"],
        "liu": ["流"],
        "liang": ["量"],
        "zhuang": ["状", "装"],
        "tai": ["态", "台"],
        "yun": ["运"],
        "xing": ["行"],
        "ben": ["本"],
        "ming": ["名", "明"],
        "cheng": ["称"],
        "yue": ["月"],
        "ri": ["日"],
        "nian": ["年"],
        "gong": ["工", "公"],
        "zuo": ["作", "做"],

        // Extended belt control terms
        "zhu": ["主"],
        "cong": ["从"],
        "ce": ["测"],
        "liang": ["量"],
        "jian": ["监"],
        "kong": ["控"],
        "bao": ["保"],
        "jing": ["警"],
        "qi": ["启"],
        "ting": ["停"],
        "su": ["速"],
        "lv": ["率"],
        "wen": ["温"],
        "ya": ["压"],
        "liu": ["流"],
        "dian": ["电"],
        "liu": ["流"],
        "chu": ["出"],
        "ru": ["入"],
        "shu": ["输"],
        "chu": ["出"],
        "gu": ["故"],
        "zhang": ["障"],
        "bao": ["报"],
        "jing": ["警"],
        "zhuang": ["状"],
        "tai": ["态"],
        "yun": ["运"],
        "xing": ["行"],
        "ting": ["停"],
        "zhi": ["止"],
        "mo": ["模"],
        "shi": ["式"],
        "shou": ["手"],
        "dong": ["动"],
        "zi": ["自"],
        "dong": ["动"],
        "wei": ["位"],
        "zhi": ["置"],
        "chuan": ["传"],
        "gan": ["感"],
        "qi": ["器"]
    })

    // Pinyin display and candidates
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5

        // Pinyin buffer display
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            color: "#0a1628"
            border.color: "#00d4ff"
            border.width: 1
            radius: 3
            visible: root.pinyinBuffer.length > 0

            Text {
                anchors.fill: parent
                anchors.margins: 5
                text: "拼音: " + root.pinyinBuffer
                color: "#00d4ff"
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Candidate characters
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            visible: root.pinyinBuffer.length > 0
            clip: true

            RowLayout {
                spacing: 5
                Repeater {
                    model: root.currentCandidates

                    Button {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 35
                        text: modelData
                        background: Rectangle {
                            color: parent.pressed ? "#2a3f54" : "#34495e"
                            radius: 3
                            border.color: "#00d4ff"
                            border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#ecf0f1"
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            if (root.targetInput) {
                                root.targetInput.text += modelData
                                root.pinyinBuffer = ""
                            }
                        }
                    }
                }
            }
        }
    }

    // Pinyin keyboard (same layout as English but lowercase only)
    // Row 1: QWERTYUIOP
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                text: modelData
                background: Rectangle {
                    color: parent.pressed ? "#2a3f54" : "#34495e"
                    radius: 3
                    border.color: "#00d4ff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ecf0f1"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    root.pinyinBuffer += modelData
                }
            }
        }
    }

    // Row 2: ASDFGHJKL
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Item { Layout.preferredWidth: 20 }
        Repeater {
            model: ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                text: modelData
                background: Rectangle {
                    color: parent.pressed ? "#2a3f54" : "#34495e"
                    radius: 3
                    border.color: "#00d4ff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ecf0f1"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    root.pinyinBuffer += modelData
                }
            }
        }
        Item { Layout.preferredWidth: 20 }
    }

    // Row 3: ZXCVBNM + Backspace
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Item { Layout.preferredWidth: 30 }

        Repeater {
            model: ["z", "x", "c", "v", "b", "n", "m"]
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                text: modelData
                background: Rectangle {
                    color: parent.pressed ? "#2a3f54" : "#34495e"
                    radius: 3
                    border.color: "#00d4ff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ecf0f1"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    root.pinyinBuffer += modelData
                }
            }
        }

        Button {
            Layout.preferredWidth: 60
            Layout.preferredHeight: 40
            text: "←"
            background: Rectangle {
                color: parent.pressed ? "#d68910" : "#f39c12"
                radius: 3
                border.color: "#00d4ff"
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                if (root.pinyinBuffer.length > 0) {
                    root.pinyinBuffer = root.pinyinBuffer.slice(0, -1)
                } else if (root.targetInput && root.targetInput.text.length > 0) {
                    root.targetInput.text = root.targetInput.text.slice(0, -1)
                }
            }
        }

        Item { Layout.preferredWidth: 30 }
    }

    // Bottom row: Numbers and controls
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 35
                text: modelData
                background: Rectangle {
                    color: parent.pressed ? "#2a3f54" : "#34495e"
                    radius: 3
                    border.color: "#00d4ff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ecf0f1"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (root.targetInput) {
                        root.targetInput.text += modelData
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            text: "空格"
            background: Rectangle {
                color: parent.pressed ? "#2a3f54" : "#34495e"
                radius: 3
                border.color: "#00d4ff"
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: "#ecf0f1"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                if (root.targetInput) {
                    root.targetInput.text += " "
                }
            }
        }

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            text: "清除拼音"
            background: Rectangle {
                color: parent.pressed ? "#d68910" : "#f39c12"
                radius: 3
                border.color: "#00d4ff"
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                root.pinyinBuffer = ""
            }
        }

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            text: "清除全部"
            background: Rectangle {
                color: parent.pressed ? "#c0392b" : "#e74c3c"
                radius: 3
                border.color: "#00d4ff"
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                if (root.targetInput) {
                    root.targetInput.text = ""
                }
                root.pinyinBuffer = ""
            }
        }
    }
}
