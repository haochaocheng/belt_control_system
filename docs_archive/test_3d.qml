import QtQuick 6.5
import QtQuick3D 6.5

Window {
    width: 800
    height: 600
    visible: true
    title: "Qt Quick 3D Test"

    View3D {
        anchors.fill: parent

        environment: SceneEnvironment {
            clearColor: "#222222"
            backgroundMode: SceneEnvironment.Color
        }

        PerspectiveCamera {
            position: Qt.vector3d(0, 0, 300)
        }

        DirectionalLight {
            eulerRotation.x: -30
        }

        Model {
            source: "#Cube"
            materials: DefaultMaterial {
                diffuseColor: "red"
            }

            PropertyAnimation on eulerRotation.y {
                from: 0
                to: 360
                duration: 3000
                loops: Animation.Infinite
            }
        }
    }

    Text {
        text: "If you see a rotating red cube, Qt Quick 3D works!"
        color: "white"
        font.pixelSize: 16
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 20
    }
}
