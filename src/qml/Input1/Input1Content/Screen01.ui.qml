

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
    // 2026-01-12: 移除固定尺寸，使用 anchors.fill 自适应父容器
    // 避免与 SwipeView 的 ListView 产生 polish() 循环
    // width: Constants.width    // 原始固定尺寸 1920
    // height: Constants.height  // 原始固定尺寸 1080
    anchors.fill: parent         // 自适应父容器尺寸

    color: Constants.backgroundColor

    Image {
        id: back
        x: 0
        y: 0
        source: "images/path_background.png"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: image1
        x: 0
        y: -8
        source: "images/background_full_transparent.png"
        fillMode: Image.PreserveAspectFit

        Image {
            id: image2
            x: 0
            y: 780
            source: "images/background_bottom_transparent.png"
            fillMode: Image.PreserveAspectFit
        }
    }

    Image {
        id: image3
        x: 0
        y: -8
        source: "images/background_top_transparent.png"
        fillMode: Image.PreserveAspectFit

        Image {
            id: image4
            x: 112
            y: 249
            source: "images/path.svg"
            fillMode: Image.PreserveAspectFit

            Image {
                id: _1
                x: 0
                y: 0
                source: "images/path_1.svg"
                fillMode: Image.PreserveAspectFit

                Image {
                    id: _2
                    x: 6
                    y: 8
                    source: "images/path_2.svg"
                    fillMode: Image.PreserveAspectFit

                    Image {
                        id: rectangle34624270
                        x: 230
                        y: 5
                        source: "images/rectangle_34624270.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        id: text1
                        x: 18
                        y: 9
                        width: 45
                        height: 16
                        color: "#eaeaea"
                        text: qsTr("GSC10")
                        font.pixelSize: 12
                    }
                }

                Image {
                    id: rectangle34624271
                    x: 6
                    y: 47
                    source: "images/rectangle_34624271.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Image {
                    id: rectangle34624263
                    x: 277
                    y: 108
                    source: "images/rectangle_34624263.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Image {
                    id: rectangle34624264
                    x: 277
                    y: 121
                    source: "images/rectangle_34624264.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Image {
                    id: rectangle34624265
                    x: 277
                    y: 133
                    source: "images/rectangle_34624265.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: text2
                    x: 94
                    y: 17
                    width: 90
                    height: 16
                    color: "#07fa2d"
                    text: qsTr("投入中-正在运行")
                    font.pixelSize: 12
                }
            }

            Text {
                id: text3
                x: 80
                y: 54
                width: 52
                height: 16
                color: "#eaeaea"
                text: qsTr("保护名称")
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                id: text4
                x: 80
                y: 78
                width: 52
                height: 16
                color: "#eaeaea"
                text: qsTr("输入类型")
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                id: text5
                x: 80
                y: 106
                width: 52
                height: 16
                color: "#eaeaea"
                text: qsTr("当前值")
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Image {
            id: image16
            x: 50
            y: 191
            source: "images/middle_top_status_bg.png"
            fillMode: Image.PreserveAspectFit

            Text {
                id: text61
                x: 886
                y: 18
                width: 167
                height: 26
                color: "#eaeaea"
                text: qsTr("传感器使用情况")
                font.pixelSize: 20
            }
        }

        Image {
            id: image18
            x: 1897
            y: 191
            source: "images/middle_top_status_bg_sides.png"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: _25
            x: 81
            y: 66
            width: 318
            height: 97
            source: "images/group2_frame1.png"
            fillMode: Image.PreserveAspectFit

            Image {
                id: _26
                x: 0
                y: 95
                source: "images/group2_frame1_bottom_left.png"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: _28
                x: 285
                y: 95
                source: "images/group2_frame1_bottom_right.png"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: _29
                x: 285
                y: 0
                source: "images/group2_frame1_top_right.png"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: _31
                x: 294
                y: 39
                source: "images/group2_frame1_middle_right.png"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: _34
                x: 53
                y: 103
                source: "images/group2_frame1_bottom_center.png"
                fillMode: Image.PreserveAspectFit
            }
        }

        Image {
            id: _27
            x: 87
            y: 66
            source: "images/group2_frame1_top_left.png"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: _30
            x: 87
            y: 105
            source: "images/group2_frame1_middle_left.png"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: _32
            x: 437
            y: 66
            source: "images/group2_frame2.svg"
            fillMode: Image.PreserveAspectFit

            Image {
                id: _39
                x: 140
                y: 105
                source: "images/group2_frame2_bottom_center.png"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: _41
                x: 578
                y: 96
                source: "images/group2_frame2_bottom_right.png"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: _42
                x: 587
                y: 40
                source: "images/group2_frame2_middle_right.png"
                fillMode: Image.PreserveAspectFit
            }
        }

        Image {
            id: _33
            x: 140
            y: 66
            source: "images/group2_frame1_top_center.png"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: _35
            x: 437
            y: 66
            source: "images/group2_frame1_top_left.png"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: _36
            x: 437
            y: 162
            source: "images/group2_frame1_bottom_left.png"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: _37
            x: 437
            y: 106
            source: "images/group2_frame1_middle_left.png"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: _38
            x: 560
            y: 66
            source: "images/group2_frame2_top_center.png"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: _40
            x: 1015
            y: 66
            source: "images/group2_frame2_top_right.png"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: _43
            x: 1074
            y: 67
            source: "images/group2_frame3.png"
            fillMode: Image.PreserveAspectFit

            Image {
                id: _45
                x: 286
                y: 96
                source: "images/group2_frame3_bottom_right.png"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: _46
                x: 295
                y: 41
                source: "images/group2_frame3_middle_right.png"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: _48
                x: 68
                y: 105
                source: "images/group2_frame3_bottom_center.png"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: _49
                x: 0
                y: 0
                source: "images/group2_frame3_top_left.png"
                fillMode: Image.PreserveAspectFit
            }
        }

        Image {
            id: _44
            x: 1360
            y: 66
            source: "images/group2_frame3_top_right.png"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: _47
            x: 1147
            y: 66
            source: "images/group2_frame3_top_center.png"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: _50
            x: 1074
            y: 163
            source: "images/group2_frame3_bottom_left.png"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: _51
            x: 1074
            y: 108
            source: "images/group2_frame3_middle_left.png"
            fillMode: Image.PreserveAspectFit
        }
    }

    Image {
        id: image5
        x: 466
        y: 240
        source: "images/path.svg"
        fillMode: Image.PreserveAspectFit
        Image {
            id: _3
            x: 0
            y: 0
            source: "images/path_1.svg"
            fillMode: Image.PreserveAspectFit
            Image {
                id: _4
                x: 6
                y: 8
                source: "images/path_2.svg"
                fillMode: Image.PreserveAspectFit
                Image {
                    id: rectangle34624272
                    x: 230
                    y: 5
                    source: "images/rectangle_34624270.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: text6
                    x: 18
                    y: 9
                    width: 45
                    height: 16
                    color: "#eaeaea"
                    text: qsTr("GSC10")
                    font.pixelSize: 12
                }
            }

            Image {
                id: rectangle34624273
                x: 6
                y: 47
                source: "images/rectangle_34624271.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624266
                x: 277
                y: 108
                source: "images/rectangle_34624263.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624267
                x: 277
                y: 121
                source: "images/rectangle_34624264.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624268
                x: 277
                y: 133
                source: "images/rectangle_34624265.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: text7
                x: 94
                y: 17
                width: 90
                height: 16
                color: "#07fa2d"
                text: qsTr("投入中-正在运行")
                font.pixelSize: 12
            }
        }

        Text {
            id: text8
            x: 80
            y: 54
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("保护名称")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text9
            x: 80
            y: 78
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("输入类型")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text10
            x: 80
            y: 106
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("当前值")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Image {
        id: image6
        x: 858
        y: 240
        source: "images/path.svg"
        fillMode: Image.PreserveAspectFit
        Image {
            id: _5
            x: 0
            y: 0
            source: "images/path_1.svg"
            fillMode: Image.PreserveAspectFit
            Image {
                id: _6
                x: 6
                y: 8
                source: "images/path_2.svg"
                fillMode: Image.PreserveAspectFit
                Image {
                    id: rectangle34624274
                    x: 230
                    y: 5
                    source: "images/rectangle_34624270.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: text11
                    x: 18
                    y: 9
                    width: 45
                    height: 16
                    color: "#eaeaea"
                    text: qsTr("GSC10")
                    font.pixelSize: 12
                }
            }

            Image {
                id: rectangle34624275
                x: 6
                y: 47
                source: "images/rectangle_34624271.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624269
                x: 277
                y: 108
                source: "images/rectangle_34624263.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624276
                x: 277
                y: 121
                source: "images/rectangle_34624264.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624277
                x: 277
                y: 133
                source: "images/rectangle_34624265.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: text12
                x: 94
                y: 17
                width: 90
                height: 16
                color: "#07fa2d"
                text: qsTr("投入中-正在运行")
                font.pixelSize: 12
            }
        }

        Text {
            id: text13
            x: 80
            y: 54
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("保护名称")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text14
            x: 80
            y: 78
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("输入类型")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text15
            x: 80
            y: 106
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("当前值")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Image {
        id: image7
        x: 1308
        y: 245
        source: "images/path.svg"
        fillMode: Image.PreserveAspectFit
        Image {
            id: _7
            x: 0
            y: 0
            source: "images/path_1.svg"
            fillMode: Image.PreserveAspectFit
            Image {
                id: _8
                x: 6
                y: 8
                source: "images/path_2.svg"
                fillMode: Image.PreserveAspectFit
                Image {
                    id: rectangle34624278
                    x: 230
                    y: 5
                    source: "images/rectangle_34624270.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: text16
                    x: 18
                    y: 9
                    width: 45
                    height: 16
                    color: "#eaeaea"
                    text: qsTr("GSC10")
                    font.pixelSize: 12
                }
            }

            Image {
                id: rectangle34624279
                x: 6
                y: 47
                source: "images/rectangle_34624271.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624280
                x: 277
                y: 108
                source: "images/rectangle_34624263.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624281
                x: 277
                y: 121
                source: "images/rectangle_34624264.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624282
                x: 277
                y: 133
                source: "images/rectangle_34624265.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: text17
                x: 94
                y: 17
                width: 90
                height: 16
                color: "#07fa2d"
                text: qsTr("投入中-正在运行")
                font.pixelSize: 12
            }
        }

        Text {
            id: text18
            x: 80
            y: 54
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("保护名称")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text19
            x: 80
            y: 78
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("输入类型")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text20
            x: 80
            y: 106
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("当前值")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Image {
        id: image8
        x: 101
        y: 468
        source: "images/path.svg"
        fillMode: Image.PreserveAspectFit
        Image {
            id: _9
            x: 0
            y: 0
            source: "images/path_1.svg"
            fillMode: Image.PreserveAspectFit
            Image {
                id: _10
                x: 6
                y: 8
                source: "images/path_2.svg"
                fillMode: Image.PreserveAspectFit
                Image {
                    id: rectangle34624283
                    x: 230
                    y: 5
                    source: "images/rectangle_34624270.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: text21
                    x: 18
                    y: 9
                    width: 45
                    height: 16
                    color: "#eaeaea"
                    text: qsTr("GSC10")
                    font.pixelSize: 12
                }
            }

            Image {
                id: rectangle34624284
                x: 6
                y: 47
                source: "images/rectangle_34624271.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624285
                x: 277
                y: 108
                source: "images/rectangle_34624263.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624286
                x: 277
                y: 121
                source: "images/rectangle_34624264.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624287
                x: 277
                y: 133
                source: "images/rectangle_34624265.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: text22
                x: 94
                y: 17
                width: 90
                height: 16
                color: "#07fa2d"
                text: qsTr("投入中-正在运行")
                font.pixelSize: 12
            }
        }

        Text {
            id: text23
            x: 80
            y: 54
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("保护名称")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text24
            x: 80
            y: 78
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("输入类型")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text25
            x: 80
            y: 106
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("当前值")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Image {
        id: image9
        x: 479
        y: 460
        source: "images/path.svg"
        fillMode: Image.PreserveAspectFit
        Image {
            id: _11
            x: 0
            y: 0
            source: "images/path_1.svg"
            fillMode: Image.PreserveAspectFit
            Image {
                id: _12
                x: 6
                y: 8
                source: "images/path_2.svg"
                fillMode: Image.PreserveAspectFit
                Image {
                    id: rectangle34624288
                    x: 230
                    y: 5
                    source: "images/rectangle_34624270.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: text26
                    x: 18
                    y: 9
                    width: 45
                    height: 16
                    color: "#eaeaea"
                    text: qsTr("GSC10")
                    font.pixelSize: 12
                }
            }

            Image {
                id: rectangle34624289
                x: 6
                y: 47
                source: "images/rectangle_34624271.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624290
                x: 277
                y: 108
                source: "images/rectangle_34624263.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624291
                x: 277
                y: 121
                source: "images/rectangle_34624264.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624292
                x: 277
                y: 133
                source: "images/rectangle_34624265.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: text27
                x: 94
                y: 17
                width: 90
                height: 16
                color: "#07fa2d"
                text: qsTr("投入中-正在运行")
                font.pixelSize: 12
            }
        }

        Text {
            id: text28
            x: 80
            y: 54
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("保护名称")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text29
            x: 80
            y: 78
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("输入类型")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text30
            x: 80
            y: 106
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("当前值")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Image {
        id: image10
        x: 869
        y: 460
        source: "images/path.svg"
        fillMode: Image.PreserveAspectFit
        Image {
            id: _13
            x: 0
            y: 0
            source: "images/path_1.svg"
            fillMode: Image.PreserveAspectFit
            Image {
                id: _14
                x: 6
                y: 8
                source: "images/path_2.svg"
                fillMode: Image.PreserveAspectFit
                Image {
                    id: rectangle34624293
                    x: 230
                    y: 5
                    source: "images/rectangle_34624270.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: text31
                    x: 18
                    y: 9
                    width: 45
                    height: 16
                    color: "#eaeaea"
                    text: qsTr("GSC10")
                    font.pixelSize: 12
                }
            }

            Image {
                id: rectangle34624294
                x: 6
                y: 47
                source: "images/rectangle_34624271.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624295
                x: 277
                y: 108
                source: "images/rectangle_34624263.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624296
                x: 277
                y: 121
                source: "images/rectangle_34624264.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624297
                x: 277
                y: 133
                source: "images/rectangle_34624265.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: text32
                x: 94
                y: 17
                width: 90
                height: 16
                color: "#07fa2d"
                text: qsTr("投入中-正在运行")
                font.pixelSize: 12
            }
        }

        Text {
            id: text33
            x: 80
            y: 54
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("保护名称")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text34
            x: 80
            y: 78
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("输入类型")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text35
            x: 80
            y: 106
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("当前值")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Image {
        id: image11
        x: 1308
        y: 460
        source: "images/path.svg"
        fillMode: Image.PreserveAspectFit
        Image {
            id: _15
            x: 0
            y: 0
            source: "images/path_1.svg"
            fillMode: Image.PreserveAspectFit
            Image {
                id: _16
                x: 6
                y: 8
                source: "images/path_2.svg"
                fillMode: Image.PreserveAspectFit
                Image {
                    id: rectangle34624298
                    x: 230
                    y: 5
                    source: "images/rectangle_34624270.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: text36
                    x: 18
                    y: 9
                    width: 45
                    height: 16
                    color: "#eaeaea"
                    text: qsTr("GSC10")
                    font.pixelSize: 12
                }
            }

            Image {
                id: rectangle34624299
                x: 6
                y: 47
                source: "images/rectangle_34624271.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624300
                x: 277
                y: 108
                source: "images/rectangle_34624263.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624301
                x: 277
                y: 121
                source: "images/rectangle_34624264.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624302
                x: 277
                y: 133
                source: "images/rectangle_34624265.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: text37
                x: 94
                y: 17
                width: 90
                height: 16
                color: "#07fa2d"
                text: qsTr("投入中-正在运行")
                font.pixelSize: 12
            }
        }

        Text {
            id: text38
            x: 80
            y: 54
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("保护名称")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text39
            x: 80
            y: 78
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("输入类型")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text40
            x: 80
            y: 106
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("当前值")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Image {
        id: image12
        x: 89
        y: 718
        source: "images/path.svg"
        fillMode: Image.PreserveAspectFit
        Image {
            id: _17
            x: 0
            y: 0
            source: "images/path_1.svg"
            fillMode: Image.PreserveAspectFit
            Image {
                id: _18
                x: 6
                y: 8
                source: "images/path_2.svg"
                fillMode: Image.PreserveAspectFit
                Image {
                    id: rectangle34624303
                    x: 230
                    y: 5
                    source: "images/rectangle_34624270.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: text41
                    x: 18
                    y: 9
                    width: 45
                    height: 16
                    color: "#eaeaea"
                    text: qsTr("GSC10")
                    font.pixelSize: 12
                }
            }

            Image {
                id: rectangle34624304
                x: 6
                y: 47
                source: "images/rectangle_34624271.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624305
                x: 277
                y: 108
                source: "images/rectangle_34624263.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624306
                x: 277
                y: 121
                source: "images/rectangle_34624264.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624307
                x: 277
                y: 133
                source: "images/rectangle_34624265.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: text42
                x: 94
                y: 17
                width: 90
                height: 16
                color: "#07fa2d"
                text: qsTr("投入中-正在运行")
                font.pixelSize: 12
            }
        }

        Text {
            id: text43
            x: 80
            y: 54
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("保护名称")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text44
            x: 80
            y: 78
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("输入类型")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text45
            x: 80
            y: 106
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("当前值")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Image {
        id: image13
        x: 479
        y: 718
        source: "images/path.svg"
        fillMode: Image.PreserveAspectFit
        Image {
            id: _19
            x: 0
            y: 0
            source: "images/path_1.svg"
            fillMode: Image.PreserveAspectFit
            Image {
                id: _20
                x: 6
                y: 8
                source: "images/path_2.svg"
                fillMode: Image.PreserveAspectFit
                Image {
                    id: rectangle34624308
                    x: 230
                    y: 5
                    source: "images/rectangle_34624270.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: text46
                    x: 18
                    y: 9
                    width: 45
                    height: 16
                    color: "#eaeaea"
                    text: qsTr("GSC10")
                    font.pixelSize: 12
                }
            }

            Image {
                id: rectangle34624309
                x: 6
                y: 47
                source: "images/rectangle_34624271.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624310
                x: 277
                y: 108
                source: "images/rectangle_34624263.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624311
                x: 277
                y: 121
                source: "images/rectangle_34624264.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624312
                x: 277
                y: 133
                source: "images/rectangle_34624265.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: text47
                x: 94
                y: 17
                width: 90
                height: 16
                color: "#07fa2d"
                text: qsTr("投入中-正在运行")
                font.pixelSize: 12
            }
        }

        Text {
            id: text48
            x: 80
            y: 54
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("保护名称")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text49
            x: 80
            y: 78
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("输入类型")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text50
            x: 80
            y: 106
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("当前值")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Image {
        id: image14
        x: 858
        y: 711
        source: "images/path.svg"
        fillMode: Image.PreserveAspectFit
        Image {
            id: _21
            x: 0
            y: 0
            source: "images/path_1.svg"
            fillMode: Image.PreserveAspectFit
            Image {
                id: _22
                x: 6
                y: 8
                source: "images/path_2.svg"
                fillMode: Image.PreserveAspectFit
                Image {
                    id: rectangle34624313
                    x: 230
                    y: 5
                    source: "images/rectangle_34624270.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: text51
                    x: 18
                    y: 9
                    width: 45
                    height: 16
                    color: "#eaeaea"
                    text: qsTr("GSC10")
                    font.pixelSize: 12
                }
            }

            Image {
                id: rectangle34624314
                x: 6
                y: 47
                source: "images/rectangle_34624271.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624315
                x: 277
                y: 108
                source: "images/rectangle_34624263.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624316
                x: 277
                y: 121
                source: "images/rectangle_34624264.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624317
                x: 277
                y: 133
                source: "images/rectangle_34624265.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: text52
                x: 94
                y: 17
                width: 90
                height: 16
                color: "#07fa2d"
                text: qsTr("投入中-正在运行")
                font.pixelSize: 12
            }
        }

        Text {
            id: text53
            x: 80
            y: 54
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("保护名称")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text54
            x: 80
            y: 78
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("输入类型")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text55
            x: 80
            y: 106
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("当前值")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Image {
        id: image15
        x: 1308
        y: 733
        source: "images/path.svg"
        fillMode: Image.PreserveAspectFit
        Image {
            id: _23
            x: 0
            y: 0
            source: "images/path_1.svg"
            fillMode: Image.PreserveAspectFit
            Image {
                id: _24
                x: 6
                y: 8
                source: "images/path_2.svg"
                fillMode: Image.PreserveAspectFit
                Image {
                    id: rectangle34624318
                    x: 230
                    y: 5
                    source: "images/rectangle_34624270.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: text56
                    x: 18
                    y: 9
                    width: 45
                    height: 16
                    color: "#eaeaea"
                    text: qsTr("GSC10")
                    font.pixelSize: 12
                }
            }

            Image {
                id: rectangle34624319
                x: 6
                y: 47
                source: "images/rectangle_34624271.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624320
                x: 277
                y: 108
                source: "images/rectangle_34624263.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624321
                x: 277
                y: 121
                source: "images/rectangle_34624264.svg"
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: rectangle34624322
                x: 277
                y: 133
                source: "images/rectangle_34624265.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: text57
                x: 94
                y: 17
                width: 90
                height: 16
                color: "#07fa2d"
                text: qsTr("投入中-正在运行")
                font.pixelSize: 12
            }
        }

        Text {
            id: text58
            x: 80
            y: 54
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("保护名称")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text59
            x: 80
            y: 78
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("输入类型")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: text60
            x: 80
            y: 106
            width: 52
            height: 16
            color: "#eaeaea"
            text: qsTr("当前值")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Image {
        id: image17
        x: 51
        y: 183
        source: "images/middle_top_status_bg_sides.png"
        fillMode: Image.PreserveAspectFit
    }
}
