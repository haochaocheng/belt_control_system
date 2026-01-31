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
        # ✅ 2026-01-31 [FIX 100.300.112.8.8] 删除重复的 Input1 文件列表（Line 16-24）
        # 保留 Line 27-35 的列表，因为它包含正确的 Screen01.qml
        # ✅ 2026-01-27 [FIX 100.300.52] 添加缺失的 Head 组件
        # ✅ 2026-01-27 [FIX 100.300.54] 添加键盘导航支持
        Input1/Input1Content/Back.ui.qml
        Input1/Input1Content/BHState.ui.qml
        Input1/Input1Content/DataShow.ui.qml
        Input1/Input1Content/Head.ui.qml
        Input1/Input1Content/Head_MiddleMenu.ui.qml
        Input1/Input1Content/MyIN_Data.ui.qml
        Input1/Input1Content/MyIN_State.ui.qml
        Input1/Input1Content/Screen01.qml
        Input1/Input1Content/Screen01Form.ui.qml
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
        components/common/IndustrialContainer.qml  # ✅ 2026-01-20 [FIX 100.253] 工业风格装饰容器
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
        components/virtual_keyboard/QtVirtualKeyboardIntegration.qml  # ✅ 2026-01-31 [FIX 100.300.112.8.11]: 添加 Qt 虚拟键盘集成组件
        components/sip_phone/SipDialerPopup.qml
        components/sip_phone/SipMainPage.qml
        components/sip_phone/SipPhoneWindow.qml
        components/sip_phone/components/RisipButton.qml
        components/sip_phone/components/RisipLineEdit.qml
        components/sip_phone/pages/SipDialPage.qml
        components/sip_phone/pages/SipContactsPage.qml
        components/sip_phone/pages/SipHistoryPage.qml
        components/sip_phone/pages/SipSettingsPage.qml
        # ✅ 2026-01-31 [FIX 100.300.112.8.6]: 添加 device_info 组件（设备信息对话框）
        components/device_info/DeviceSettingsDialog.qml
        components/device_info/DeviceInfoGrid.qml
        components/device_info/DeviceInfoItem.qml
        components/device_info/CustomTextField.qml
        components/device_info/CustomSpinBox.qml
        components/device_info/CustomComboBox.qml
        components/device_info/CustomReadOnlyField.qml
        components/device_info/IndustrialTheme.qml
        components/device_info/NavigationManager.qml
        components/device_info/VirtualKeyboardManager.qml
        # ✅ 2026-01-31 [FIX 100.300.112.8.6]: device_info 页面组件
        components/device_info/pages/BasicConfigPage.qml
        components/device_info/pages/BasicConfigTab.qml
        components/device_info/pages/SwitchInputPage.qml
        components/device_info/pages/AnalogInputPage.qml
        components/device_info/pages/MotorControlPage.qml
        components/device_info/pages/MotorListPanel.qml
        components/device_info/pages/MotorConfigPanel.qml
        components/device_info/pages/BrakeControlPage.qml
        components/device_info/pages/BrakeListPanel.qml
        components/device_info/pages/BrakeConfigPanel.qml
        components/device_info/pages/TensionControlPage.qml
        components/device_info/pages/TensionControlListPanel.qml
        components/device_info/pages/TensionControlConfigPanel.qml
        components/device_info/pages/CurrentProtectionTab.qml
        components/device_info/pages/MotorTempTab.qml
        components/device_info/pages/FrontBearingTempTab.qml
        components/device_info/pages/RearBearingTempTab.qml
        components/device_info/pages/XAxisVibrationTab.qml
        components/device_info/pages/YAxisVibrationTab.qml
        components/device_info/pages/PhaseAWindingTab.qml
        components/device_info/pages/PhaseBWindingTab.qml
        components/device_info/pages/PhaseCWindingTab.qml
    RESOURCES
        images/header.png
        sounds/ringtone.wav
        # 2026-01-12: Input1 模块资源文件（101 个图片，全英文文件名）
        Input1/Input1Content/images/082.png
        Input1/Input1Content/images/15823432333.svg
        Input1/Input1Content/images/back_Lift.svg
        Input1/Input1Content/images/back_Rrigt.png
        Input1/Input1Content/images/back1.svg
        Input1/Input1Content/images/back2.svg
        Input1/Input1Content/images/back3.png
        Input1/Input1Content/images/background_bottom_transparent.png
        Input1/Input1Content/images/background_full_transparent.png
        Input1/Input1Content/images/background_top_transparent.png
        Input1/Input1Content/images/current_value.svg
        Input1/Input1Content/images/dd.png
        Input1/Input1Content/images/fault.svg
        Input1/Input1Content/images/figma_export_1.svg
        Input1/Input1Content/images/group2_frame1_bottom_center.png
        Input1/Input1Content/images/group2_frame1_bottom_left.png
        Input1/Input1Content/images/group2_frame1_bottom_right.png
        Input1/Input1Content/images/group2_frame1_middle_left.png
        Input1/Input1Content/images/group2_frame1_middle_right.png
        Input1/Input1Content/images/group2_frame1_top_center.png
        Input1/Input1Content/images/group2_frame1_top_left.png
        Input1/Input1Content/images/group2_frame1_top_right.png
        Input1/Input1Content/images/group2_frame1.png
        Input1/Input1Content/images/group2_frame2_base.svg
        Input1/Input1Content/images/group2_frame2_bottom_center.png
        Input1/Input1Content/images/group2_frame2_bottom_left.png
        Input1/Input1Content/images/group2_frame2_bottom_right.png
        Input1/Input1Content/images/group2_frame2_middle_left.png
        Input1/Input1Content/images/group2_frame2_middle_right.png
        Input1/Input1Content/images/group2_frame2_top_center.png
        Input1/Input1Content/images/group2_frame2_top_left.png
        Input1/Input1Content/images/group2_frame2_top_right.png
        Input1/Input1Content/images/group2_frame2.svg
        Input1/Input1Content/images/group2_frame3_bottom_center.png
        Input1/Input1Content/images/group2_frame3_bottom_left.png
        Input1/Input1Content/images/group2_frame3_bottom_right.png
        Input1/Input1Content/images/group2_frame3_middle_left.png
        Input1/Input1Content/images/group2_frame3_middle_right.png
        Input1/Input1Content/images/group2_frame3_top_center.png
        Input1/Input1Content/images/group2_frame3_top_left.png
        Input1/Input1Content/images/group2_frame3_top_right.png
        Input1/Input1Content/images/group2_frame3.png
        Input1/Input1Content/images/GSC10.svg
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
        Input1/Input1Content/images/head_menuOK.png
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
        Input1/Input1Content/images/IN_Data_OK.png
        Input1/Input1Content/images/IN_Data.png
        Input1/Input1Content/images/IN_State.png
        Input1/Input1Content/images/input_type.svg
        Input1/Input1Content/images/middle_top_status_bg_sides.png
        Input1/Input1Content/images/middle_top_status_bg.png
        Input1/Input1Content/images/path_1.svg
        Input1/Input1Content/images/path_2.svg
        Input1/Input1Content/images/path_background.png
        Input1/Input1Content/images/path.svg
        Input1/Input1Content/images/protection_name.svg
        Input1/Input1Content/images/rectangle_34624263.svg
        Input1/Input1Content/images/rectangle_34624264.svg
        Input1/Input1Content/images/rectangle_34624265.svg
        Input1/Input1Content/images/rectangle_34624270.svg
        Input1/Input1Content/images/rectangle_34624271.svg
        Input1/Input1Content/images/running_active.svg
        Input1/Input1Content/images/speed.svg
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
        Input1/Input1Content/images/switch_value.svg
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

target_link_libraries(input1_qml_module PRIVATE
    Qt6::Qml
    Qt6::Quick
)

# ❌ 2026-01-27 18:55 [FIX 100.300.49] 注释掉孤立的文件列表
# 原因：这些文件列表没有包含在任何 CMake 命令中，导致解析错误
# 这些文件已经在上面的 qt_add_qml_module 中通过 RESOURCE_PREFIX 自动包含
# ✅ 2026-01-31 [FIX 100.300.112.8.7] 修复 CMake 解析错误 - 注释掉孤立的文件列表
#        # 2026-01-19: Input1 模块 QML 组件（9 个，自动检测）
#        Input1/Input1Content/Back.ui.qml
#        Input1/Input1Content/BHState.ui.qml
#        Input1/Input1Content/DataShow.ui.qml
#        Input1/Input1Content/Head_MiddleMenu.ui.qml
#        Input1/Input1Content/Head.ui.qml
#        Input1/Input1Content/MyIN_Data.ui.qml
#        Input1/Input1Content/MyIN_State.ui.qml
#        Input1/Input1Content/Screen01.ui.qml
#        Input1/Input1Content/Screen01Form.ui.qml
#        Input1/Input1Content/Back.ui.qml
#        Input1/Input1Content/BHState.ui.qml
#        Input1/Input1Content/DataShow.ui.qml
#        Input1/Input1Content/MyIN_Data.ui.qml
#        Input1/Input1Content/MyIN_State.ui.qml
#        Input1/Input1Content/Screen01.ui.qml
target_link_libraries(qml_module PRIVATE input1_qml_module)

message(STATUS "Input1 QML 模块已创建为独立模块")