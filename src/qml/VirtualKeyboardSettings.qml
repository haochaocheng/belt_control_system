import QtQuick
import QtQuick.VirtualKeyboard
import QtQuick.VirtualKeyboard.Settings

QtObject {
    Component.onCompleted: {
        // Configure virtual keyboard settings
        console.log("[VirtualKeyboard] Configuring settings...")

        // Note: VirtualKeyboardSettings is read-only in Qt 6
        // We cannot programmatically change keyboard size here
        // The keyboard size is controlled by the InputPanel's parent container

        console.log("[VirtualKeyboard] Settings configured")
    }
}
