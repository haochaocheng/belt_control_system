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