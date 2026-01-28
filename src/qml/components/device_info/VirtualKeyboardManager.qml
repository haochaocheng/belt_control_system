import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-01-28 [虚拟键盘管理器]: 统一管理所有输入框的虚拟键盘交互
// 支持触摸屏和键盘导航两种场景
QtObject {
    id: root

    // ========== 公开属性 ==========
    property var keyboardInstance: null          // 共享的虚拟键盘实例
    property var currentInputField: null         // 当前正在编辑的输入框
    property bool isTouchMode: false             // 触摸模式标志
    property var registeredFields: []            // 已注册的输入框列表

    // ========== 键盘类型映射 ==========
    // 根据输入框类型自动选择键盘模式
    readonly property var keyboardModeMap: ({
        "TextField": "english",      // 文本框 → 英文键盘
        "SpinBox": "numeric",        // 数字框 → 数字键盘
        "ComboBox": "english"        // 下拉框 → 英文键盘（可编辑时）
    })

    // ========== 初始化键盘实例 ==========
    function initialize(keyboard) {
        keyboardInstance = keyboard
        console.log("✅ [VirtualKeyboardManager] 键盘实例已初始化")
    }

    // ========== 注册输入框 ==========
    // 为输入框添加触摸和键盘导航支持
    function registerInputField(inputField) {
        if (!inputField) {
            console.warn("⚠️ [VirtualKeyboardManager] 尝试注册空输入框")
            return
        }

        // 避免重复注册
        if (registeredFields.indexOf(inputField) !== -1) {
            return
        }

        registeredFields.push(inputField)

        console.log("✅ [VirtualKeyboardManager] 注册输入框:", inputField.objectName || "unnamed")
    }

    // ========== 打开键盘（供输入框调用）==========
    function openKeyboardForField(inputField, touchMode) {
        if (!keyboardInstance) {
            console.error("❌ [VirtualKeyboardManager] 键盘实例未初始化")
            return
        }

        if (!inputField) {
            console.error("❌ [VirtualKeyboardManager] 输入框为空")
            return
        }

        // 记录当前输入框和模式
        currentInputField = inputField
        isTouchMode = touchMode !== undefined ? touchMode : false

        // 确定键盘模式
        var mode = determineKeyboardMode(inputField)

        // 获取当前值
        var currentValue = ""
        if (inputField.hasOwnProperty("value")) {
            // SpinBox
            currentValue = inputField.value.toString()
        } else if (inputField.hasOwnProperty("text")) {
            // TextField / ComboBox
            currentValue = inputField.text
        }

        // 打开键盘
        keyboardInstance.openForField(
            inputField,
            function(newValue) {
                // 回调：更新输入框的值
                updateInputFieldValue(inputField, newValue)
            },
            mode
        )

        console.log("✅ [VirtualKeyboardManager] 打开键盘 - 模式:", mode, "触摸模式:", isTouchMode, "当前值:", currentValue)
    }

    // ========== 更新输入框的值 ==========
    function updateInputFieldValue(inputField, newValue) {
        if (!inputField) return

        if (inputField.hasOwnProperty("value")) {
            // SpinBox - 转换为数字
            var numValue = parseFloat(newValue)
            if (!isNaN(numValue)) {
                inputField.value = numValue
                console.log("✅ [VirtualKeyboardManager] 更新 SpinBox 值:", numValue)
            } else {
                console.warn("⚠️ [VirtualKeyboardManager] 无效的数字值:", newValue)
            }
        } else if (inputField.hasOwnProperty("text")) {
            // TextField / ComboBox
            inputField.text = newValue
            console.log("✅ [VirtualKeyboardManager] 更新 TextField 值:", newValue)
        }
    }

    // ========== 确定键盘模式 ==========
    function determineKeyboardMode(inputField) {
        if (!inputField) return "numeric"

        // 获取组件类型名称
        var typeName = inputField.toString()

        // 1. SpinBox → 数字键盘
        if (typeName.indexOf("SpinBox") !== -1) {
            return "numeric"
        }

        // 2. TextField
        if (typeName.indexOf("TextField") !== -1) {
            // 检查是否有数字验证器
            if (inputField.validator) {
                var validatorType = inputField.validator.toString()
                if (validatorType.indexOf("IntValidator") !== -1 ||
                    validatorType.indexOf("DoubleValidator") !== -1) {
                    return "numeric"
                }
            }
            return "english"
        }

        // 3. ComboBox（可编辑时）
        if (typeName.indexOf("ComboBox") !== -1) {
            if (inputField.editable) {
                return "english"
            }
            return null  // 不可编辑的 ComboBox 不需要键盘
        }

        // 4. 默认 → 数字键盘
        return "numeric"
    }

    // ========== 关闭键盘 ==========
    function closeKeyboard() {
        if (keyboardInstance) {
            keyboardInstance.close()
            console.log("✅ [VirtualKeyboardManager] 关闭键盘")
        }
        currentInputField = null
    }

    // ========== 获取已注册输入框数量 ==========
    function getRegisteredFieldsCount() {
        return registeredFields.length
    }

    // ========== 清除所有注册 ==========
    function clearRegistrations() {
        registeredFields = []
        console.log("✅ [VirtualKeyboardManager] 清除所有注册")
    }
}
