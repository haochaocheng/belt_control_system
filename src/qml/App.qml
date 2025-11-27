import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import Qt5Compat.GraphicalEffects
import BeltControl.SipPhone 1.0
import "pages"
import "components"

Item {
    id: app
    anchors.fill: parent

    // Shared properties
    property bool motorRunning: false
    property real currentSpeed: 2.5

    // Tech blue gradient background
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0a1628" }
            GradientStop { position: 0.5; color: "#0d2137" }
            GradientStop { position: 1.0; color: "#0a1628" }
        }
    }

    // Tech grid overlay effect
    Canvas {
        anchors.fill: parent
        opacity: 0.1
        onPaint: {
            var ctx = getContext("2d")
            ctx.strokeStyle = "#00d4ff"
            ctx.lineWidth = 0.5
            var gridSize = 40
            for (var x = 0; x < width; x += gridSize) {
                ctx.beginPath()
                ctx.moveTo(x, 0)
                ctx.lineTo(x, height)
                ctx.stroke()
            }
            for (var y = 0; y < height; y += gridSize) {
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()
            }
        }
    }

    // SwipeView for pages (full screen)
    SwipeView {
        id: swipeView
        anchors.fill: parent
        currentIndex: 0

        // Page 1: Control Panel - New Belt Control System Interface
        ControlPanel {
            motorRunning: app.motorRunning
            currentSpeed: app.currentSpeed

            onMotorRunningChanged: app.motorRunning = motorRunning
            onCurrentSpeedChanged: app.currentSpeed = currentSpeed
        }

        // Page 2: Parameter Settings (unchanged)
        ParameterSettings {
        }

        // Page 3: Alarm Page (unchanged)
        AlarmPage {
        }
    }

    // Page indicator - Floating at bottom
    PageIndicator {
        id: indicator
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        count: swipeView.count
        currentIndex: swipeView.currentIndex
        interactive: true

        delegate: Rectangle {
            implicitWidth: 12
            implicitHeight: 12
            radius: 6
            color: index === indicator.currentIndex ? "#3498db" : "#95a5a6"

            Behavior on color {
                ColorAnimation { duration: 200 }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: swipeView.currentIndex = index
            }
        }
    }
}
