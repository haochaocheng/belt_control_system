import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import "../components/voice_management"
import com.belt.control 1.0  // ✅ 2026-01-23 11:00 [FIX 100.299] 导入 TTSConfig 单例

/**
 * @brief 语音管理页面
 *
 * 功能：
 * 1. TTS模型配置
 * 2. 音频文件管理
 * 3. 批量识别和生成
 *
 * ✅ 2026-01-23 10:30 [FIX 100.299] 语音管理界面
 * ✅ 2026-01-23 11:00 [FIX 100.299] 后端集成
 */
Rectangle {
    id: root
    color: "#1a1a1a"

    // 页面标题
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        color: "#2c3e50"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 15

            Text {
                text: "🎵 语音管理"
                font.pixelSize: 24
                font.bold: true
                color: "#ecf0f1"
            }

            Item { Layout.fillWidth: true }

            // 帮助按钮
            Button {
                text: "❓ 帮助"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 40

                background: Rectangle {
                    color: parent.pressed ? "#34495e" : "#2c3e50"
                    border.color: "#00d4ff"
                    border.width: 1
                    radius: 5
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 14
                    color: "#ecf0f1"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    helpDialog.open()
                }
            }
        }
    }

    // 主内容区域
    RowLayout {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 15
        spacing: 15

        // 左侧：TTS配置区域
        Rectangle {
            Layout.preferredWidth: 400
            Layout.fillHeight: true
            color: "#2c3e50"
            radius: 10

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                // 区域标题
                Text {
                    text: "🎤 TTS模型配置"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#00d4ff"
                }

                // TTS配置组件
                TTSConfigSection {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }

        // 右侧：音频文件管理区域
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#2c3e50"
            radius: 10

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                // 区域标题
                Text {
                    text: "📁 音频文件管理"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#00d4ff"
                }

                // 目录选择
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "扫描目录："
                        font.pixelSize: 14
                        color: "#ecf0f1"
                    }

                    TextField {
                        id: dirPathInput
                        Layout.fillWidth: true
                        placeholderText: "E:/2025/3_gongkongji/belt_control_system/AUDIO/1#PD"
                        text: "E:/2025/3_gongkongji/belt_control_system/AUDIO/1#PD"

                        background: Rectangle {
                            color: "transparent"
                            border.color: dirPathInput.activeFocus ? "#00d4ff" : "#34495e"
                            border.width: 1
                            radius: 5
                        }

                        color: "#ecf0f1"
                        font.pixelSize: 14
                    }

                    Button {
                        text: "📂 浏览"
                        Layout.preferredWidth: 80

                        background: Rectangle {
                            color: parent.pressed ? "#34495e" : "#2c3e50"
                            border.color: "#00d4ff"
                            border.width: 1
                            radius: 5
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            color: "#ecf0f1"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            // TODO: 打开文件夹选择对话框
                            console.log("打开文件夹选择对话框")
                        }
                    }

                    Button {
                        text: "🔍 扫描"
                        Layout.preferredWidth: 80

                        background: Rectangle {
                            color: parent.pressed ? "#00a8cc" : "#00d4ff"
                            border.color: "#00d4ff"
                            border.width: 1
                            radius: 5
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            color: "#1a1a1a"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            // ✅ 2026-01-23 11:00 [FIX 100.299] 调用后端扫描目录
                            audioManagementController.scanDirectory(dirPathInput.text)
                        }
                    }
                }

                // 文件列表
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#1a1a1a"
                    radius: 5

                    Text {
                        anchors.centerIn: parent
                        text: "文件列表\n（待实现）"
                        font.pixelSize: 16
                        color: "#95a5a6"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // 批量操作按钮
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        text: "🎯 批量识别"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40

                        background: Rectangle {
                            color: parent.pressed ? "#27ae60" : "#2ecc71"
                            border.color: "#2ecc71"
                            border.width: 1
                            radius: 5
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            color: "#1a1a1a"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            // ✅ 2026-01-23 11:00 [FIX 100.299] 调用后端批量识别
                            audioManagementController.recognizeAll()
                        }
                    }

                    Button {
                        text: "🎙️ 批量生成"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40

                        background: Rectangle {
                            color: parent.pressed ? "#2980b9" : "#3498db"
                            border.color: "#3498db"
                            border.width: 1
                            radius: 5
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            color: "#ecf0f1"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            // ✅ 2026-01-23 11:00 [FIX 100.299] 调用后端批量生成
                            audioManagementController.generateAllTts()
                        }
                    }

                    Button {
                        text: "⏹️ 停止"
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 40

                        background: Rectangle {
                            color: parent.pressed ? "#c0392b" : "#e74c3c"
                            border.color: "#e74c3c"
                            border.width: 1
                            radius: 5
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            color: "#ecf0f1"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            // ✅ 2026-01-23 11:00 [FIX 100.299] 调用后端停止处理
                            audioManagementController.stopProcessing()
                        }
                    }
                }

                // 进度显示
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "进度："
                        font.pixelSize: 14
                        color: "#ecf0f1"
                    }

                    ProgressBar {
                        id: progressBar
                        Layout.fillWidth: true
                        // ✅ 2026-01-23 11:00 [FIX 100.299] 绑定后端进度
                        value: audioManagementController.progress / 100

                        background: Rectangle {
                            implicitWidth: 200
                            implicitHeight: 6
                            color: "#34495e"
                            radius: 3
                        }

                        contentItem: Item {
                            implicitWidth: 200
                            implicitHeight: 6

                            Rectangle {
                                width: progressBar.visualPosition * parent.width
                                height: parent.height
                                radius: 3
                                color: "#00d4ff"
                            }
                        }
                    }

                    Text {
                        id: progressText
                        // ✅ 2026-01-23 11:00 [FIX 100.299] 绑定后端进度文本
                        text: audioManagementController.processedFiles + " / " +
                              audioManagementController.totalFiles + " (" +
                              audioManagementController.progress + "%)"
                        font.pixelSize: 14
                        color: "#00d4ff"
                        Layout.preferredWidth: 120
                    }
                }
            }
        }
    }

    // 帮助对话框
    Dialog {
        id: helpDialog
        title: "语音管理帮助"
        modal: true
        anchors.centerIn: parent
        width: 600
        height: 400

        background: Rectangle {
            color: "#2c3e50"
            border.color: "#00d4ff"
            border.width: 2
            radius: 10
        }

        contentItem: ScrollView {
            clip: true

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: "#ecf0f1"
                font.pixelSize: 14
                lineHeight: 1.5

                text: "
<b>语音管理功能说明</b>

<b>1. TTS模型配置</b>
- 选择TTS模型（7个可选模型）
- 设置说话人ID
- 调整语速和音量
- 测试语音效果

<b>2. 音频文件管理</b>
- 扫描指定目录的音频文件
- 支持格式：.wav, .mp3, .ogg, .flac
- 显示文件列表和状态

<b>3. 批量识别</b>
- 使用STT识别音频文件内容
- 自动识别所有文件
- 显示识别结果

<b>4. 批量生成</b>
- 根据识别的文本生成TTS语音
- 使用当前配置的TTS模型
- 保存到 generated_tts/ 目录

<b>使用流程</b>
1. 配置TTS模型和参数
2. 扫描音频文件目录
3. 批量识别音频内容
4. 批量生成TTS语音
5. 查看生成结果
                "
            }
        }

        standardButtons: Dialog.Ok
    }
}
