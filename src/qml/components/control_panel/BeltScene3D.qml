import QtQuick 6.5
import QtQuick3D 6.5

// Belt Scene 3D - Digital Twin for belt control system
Item {
    id: root

    // Public properties for controlling the scene
    property bool isRunning: false
    property real beltSpeed: 0.0
    property real cameraDistance: 1500
    property real cameraRotation: 0

    View3D {
        id: view3D
        anchors.fill: parent

        environment: SceneEnvironment {
            clearColor: "#0a1628"
            backgroundMode: SceneEnvironment.Color
        }

        // Camera with orbit control
        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(
                Math.sin(root.cameraRotation * Math.PI / 180) * root.cameraDistance,
                root.cameraDistance * 0.4,
                Math.cos(root.cameraRotation * Math.PI / 180) * root.cameraDistance
            )
            eulerRotation.x: -20
            eulerRotation.y: root.cameraRotation
            clipFar: 10000
            clipNear: 1
        }

        // Main directional light
        DirectionalLight {
            eulerRotation.x: -45
            eulerRotation.y: 45
            brightness: 1.5
        }

        // Ambient light for fill
        DirectionalLight {
            eulerRotation.x: 45
            eulerRotation.y: -45
            brightness: 0.5
        }

        // Point light for highlights
        PointLight {
            position: Qt.vector3d(0, 800, 0)
            brightness: 0.8
        }

        // Belt conveyor system
        Node {
            id: beltModel

            // Left motor
            Model {
                source: "#Cylinder"
                position: Qt.vector3d(-400, 80, 0)
                scale: Qt.vector3d(1.5, 2, 1.5)
                eulerRotation.z: 90
                materials: DefaultMaterial {
                    diffuseColor: root.isRunning ? "#00ff88" : "#2c3e50"
                }
            }

            // Right motor
            Model {
                source: "#Cylinder"
                position: Qt.vector3d(400, 80, 0)
                scale: Qt.vector3d(1.5, 2, 1.5)
                eulerRotation.z: 90
                materials: DefaultMaterial {
                    diffuseColor: root.isRunning ? "#00ff88" : "#2c3e50"
                }
            }

            // Center roller
            Model {
                source: "#Cylinder"
                position: Qt.vector3d(0, 80, 0)
                scale: Qt.vector3d(1.2, 0.6, 1.2)
                eulerRotation.z: 90
                materials: DefaultMaterial {
                    diffuseColor: "#00d4ff"
                }
            }

            // Belt surface
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, 90, 0)
                scale: Qt.vector3d(8, 0.08, 1.5)
                materials: DefaultMaterial {
                    diffuseColor: "#2c3e50"
                }
            }

            // Ground plane
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, -20, 0)
                scale: Qt.vector3d(30, 0.1, 30)
                materials: DefaultMaterial {
                    diffuseColor: "#0d1e35"
                }
            }
        }
    }

    // Mouse drag to rotate camera
    MouseArea {
        anchors.fill: parent
        property real lastX: 0

        onPressed: function(mouse) {
            lastX = mouse.x
        }

        onPositionChanged: function(mouse) {
            if (pressed) {
                var deltaX = mouse.x - lastX
                root.cameraRotation += deltaX * 0.3
                lastX = mouse.x
            }
        }

        onWheel: function(wheel) {
            root.cameraDistance = Math.max(500, Math.min(3000,
                root.cameraDistance - wheel.angleDelta.y * 1.5))
        }
    }

    // Auto-rotate timer (避免NumberAnimation on的问题)
    Timer {
        interval: 50
        running: !root.isRunning
        repeat: true
        onTriggered: {
            root.cameraRotation += 0.3
        }
    }
}
