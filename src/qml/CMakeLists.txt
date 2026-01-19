qt_add_qml_module(qml_module
    URI BeltControlQml
    VERSION 1.0
    STATIC
    NO_PLUGIN
    NO_GENERATE_QMLTYPES
    QML_FILES
        main.qml
        App.qml
        pages/ControlPanel.qml
        pages/ParameterSettings.qml
        pages/AlarmPage.qml
        pages/DeviceOperationLog.qml
        pages/Input1Page.qml
        # 2026-01-12: Input1 模块 QML 文件已移到独立的 Input1 模块中（见文件末尾）
        # Input1/Input1Content/Screen01.ui.qml 是实际的 UI 文件
        # Input1/Input1Content/App.qml 仅用于 QDS 预览，不包含在应用中
        Input1/Input1Content/Screen01.ui.qml
        # 2026-01-19: Screen01 引用的子组件（必须添加，否则 Screen01 加载失败）
        Input1/Input1Content/Back.ui.qml
        Input1/Input1Content/Head.ui.qml
        Input1/Input1Content/Head_MiddleMenu.ui.qml
        Input1/Input1Content/BHState.ui.qml
        Input1/Input1Content/DataShow.ui.qml
        components/SpeedGauge.qml
        components/StatusIndicator.qml
        components/MotorControlBtn.qml
        components/SpeedControlPanel.qml
        components/MotorControlPanel.qml
        components/RuntimeInfoPanel.qml
        components/AlarmSummaryPanel.qml
        components/ProtectionSettingsDialog.qml
        components/common/Header.qml
        components/common/Footer.qml
        components/common/TabBar.qml
        components/control_panel/BeltScene3D.qml
        components/control_panel/DeviceStatusPanel.qml
        components/control_panel/ProtectionPanel.qml
        components/control_panel/ProtectionSettingsPopup.qml
        components/control_panel/OutputDevicePanel.qml
        components/control_panel/OutputDeviceSettingsPopup.qml
        components/control_panel/DeviceStatusBar.qml
        components/control_panel/OperationLogPanel.qml
        components/control_panel/ModuleConnectionPanel.qml
        components/control_panel/AnalogChart.qml
        components/parameter_settings/BasicParametersSection.qml
        components/parameter_settings/NetworkParametersSection.qml
        components/parameter_settings/NetworkSettingsSection.qml
        components/parameter_settings/MasterControlSection.qml
        components/parameter_settings/DeviceSequenceSection.qml
        components/parameter_settings/DeviceSelectionPopup.qml
        components/parameter_settings/VirtualKeyboardPopup.qml
        components/parameter_settings/DateTimePickerPopup.qml
        components/parameter_settings/NumericInputDialog.qml
        components/virtual_keyboard/EnhancedVirtualKeyboard.qml
        components/virtual_keyboard/KeyboardModeSelector.qml
        components/virtual_keyboard/NumericKeyboard.qml
        components/virtual_keyboard/EnglishKeyboard.qml
        components/virtual_keyboard/ChineseKeyboard.qml
        components/sip_phone/SipDialerPopup.qml
        components/sip_phone/SipMainPage.qml
        components/sip_phone/SipPhoneWindow.qml
        components/sip_phone/components/RisipButton.qml
        components/sip_phone/components/RisipLineEdit.qml
        components/sip_phone/pages/SipDialPage.qml
        components/sip_phone/pages/SipContactsPage.qml
        components/sip_phone/pages/SipHistoryPage.qml
        components/sip_phone/pages/SipSettingsPage.qml
    RESOURCES
        images/header.png
        sounds/ringtone.wav
        # 2026-01-12: Input1 模块资源文件（43 个图片，全英文文件名）
        Input1/Input1Content/images/back_Lift.svg
        Input1/Input1Content/images/back_Rrigt.png
        Input1/Input1Content/images/back1.svg
        Input1/Input1Content/images/back2.svg
        Input1/Input1Content/images/back3.png
        Input1/Input1Content/images/head_Bottom-left_straight_line1.png
        Input1/Input1Content/images/head_Bottom-left_straight_line10.png
        Input1/Input1Content/images/head_Bottom-left_straight_line11.png
        Input1/Input1Content/images/head_Bottom-left_straight_line12.png
        Input1/Input1Content/images/head_Bottom-left_straight_line13.png
        Input1/Input1Content/images/head_Bottom-left_straight_line14.png
        Input1/Input1Content/images/head_Bottom-left_straight_line15.png
        Input1/Input1Content/images/head_Bottom-left_straight_line16.png
        Input1/Input1Content/images/head_Bottom-left_straight_line2.png
        Input1/Input1Content/images/head_Bottom-left_straight_line3.png
        Input1/Input1Content/images/head_Bottom-left_straight_line4.png
        Input1/Input1Content/images/head_Bottom-left_straight_line5.png
        Input1/Input1Content/images/head_Bottom-left_straight_line6.png
        Input1/Input1Content/images/head_Bottom-left_straight_line7.png
        Input1/Input1Content/images/head_Bottom-left_straight_line8.png
        Input1/Input1Content/images/head_Bottom-left_straight_line9.png
        Input1/Input1Content/images/head_Left_gradient.svg
        Input1/Input1Content/images/head_MiddleMenu1.png
        Input1/Input1Content/images/head_MiddleMenu2.png
        Input1/Input1Content/images/head_Right_gradient.svg
        Input1/Input1Content/images/head_Right_triangle.svg
        Input1/Input1Content/images/head_Right_triangle2.svg
        Input1/Input1Content/images/head_Right_triangle3.svg
        Input1/Input1Content/images/head_Top-left_straight_line.png
        Input1/Input1Content/images/head_Top-left_straight_line2.png
        Input1/Input1Content/images/head_Top-right_straight_line.png
        Input1/Input1Content/images/head_Top-right_straight_line2.png
        Input1/Input1Content/images/state_bk_1.png
        Input1/Input1Content/images/state_bk_2.png
        Input1/Input1Content/images/state_bk_3.png
        Input1/Input1Content/images/state_bk_4.png
        Input1/Input1Content/images/state_bk_5.png
        Input1/Input1Content/images/state_bk_6.png
        Input1/Input1Content/images/state_bk_7.png
        Input1/Input1Content/images/state_bk1.png
        Input1/Input1Content/images/state_bk2.png
        Input1/Input1Content/images/state_bk3.png
        Input1/Input1Content/images/state_bk4.png
    RESOURCE_PREFIX /qt/qml
    NO_PLUGIN_OPTIONAL
)

# 链接依赖（QML模块需访问控制逻辑和工具类）
target_link_libraries(qml_module PRIVATE
    Qt6::Qml
    Qt6::Quick
    control_module        # 控制逻辑模块（C++）
    utils_module          # 工具类模块
)

# 条件性链接可选Qt组件
if(TARGET Qt6::Multimedia)
    target_link_libraries(qml_module PRIVATE Qt6::Multimedia)  # 用于来电铃声播放
endif()

# 暴露头文件路径（供main模块调用）
target_include_directories(qml_module PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

# 2026-01-12: Input1 QML 模块（QDS 项目）
# 创建独立的 Input1 模块，使 Screen01.ui.qml 能够 import Input1
qt_add_qml_module(input1_qml_module
    URI Input1
    VERSION 1.0
    STATIC
    NO_PLUGIN
    NO_GENERATE_QMLTYPES
    QML_FILES
        Input1/Input1/Constants.qml
        Input1/Input1/EventListModel.qml
        Input1/Input1/EventListSimulator.qml
    RESOURCE_PREFIX /qt/qml
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Input1
)

# Input1 模块依赖
target_link_libraries(input1_qml_module PRIVATE
    Qt6::Qml
    Qt6::Quick
)

# 将 Input1 模块链接到主 qml_module
target_link_libraries(qml_module PRIVATE input1_qml_module)

message(STATUS "Input1 QML 模块已创建为独立模块")