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
        pages/DeviceMonitorPage.qml  # ✅ 2026-02-11 [Phase 7.45.21]: 设备监控页面
        pages/ParameterSettings.qml
        pages/AlarmPage.qml
        pages/DeviceOperationLog.qml
        pages/Input1Page.qml
        pages/VoiceManagement.qml  # ✅ 2026-02-11 [Phase 7.45.22]: 语音管理页面
        pages/BatchSynthesisDialog.qml  # ✅ 2026-02-25 [Phase 7.47.2]: 批量语音合成对话框
        pages/BatchSynthesisContent.qml  # ✅ 2026-03-09 [Phase 7.48.27]: 批量合成内容组件（VoiceManagement引用）
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
        components/control_panel/ImageInputField.qml  # 2026-02-11: 图片背景输入框组件
        components/control_panel/StateInputField.qml  # 2026-02-11: 状态显示输入框组件
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
        components/device_info/pages/MyMotorListPanel.qml  # ✅ 2026-02-02 [FIX 100.300.112.8.21]: 修正文件名（原为MotorListPanel.qml）
        components/device_info/pages/MotorConfigPanel.qml
        components/device_info/pages/BrakeControlPage.qml
        components/device_info/pages/BrakeListPanel.qml
        components/device_info/pages/BrakeConfigPanel.qml
        components/device_info/pages/TensionControlPage.qml
        components/device_info/pages/TensionControlListPanel.qml
        components/device_info/pages/TensionControlConfigPanel.qml
        # ✅ 2026-02-07 [Phase 7.39.21]: CAN 控制页面组件
        components/device_info/pages/CANControlPage.qml
        components/device_info/pages/CANListPanel.qml
        components/device_info/pages/CANConfigPanel.qml
        components/device_info/pages/CANParamsTab.qml
        components/device_info/pages/CANSendTab.qml
        components/device_info/pages/CANReceiveTab.qml
        # ✅ 2026-02-04 [FIX 100.300.113]: 串口控制页面组件
        components/device_info/pages/SerialPortControlPage.qml
        components/device_info/pages/SerialPortListPanel.qml
        components/device_info/pages/SerialPortConfigPanel.qml
        components/device_info/pages/SerialPortParamsTab.qml  # ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8.14]: 修正文件名（原为SerialPortParamsSection.qml）
        components/device_info/pages/SerialPortSendTab.qml  # ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.7]: 修正文件名（原为SerialPortSendSection.qml）
        components/device_info/pages/SerialPortReceiveTab.qml  # ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.7]: 修正文件名（原为SerialPortReceiveSection.qml）
        components/device_info/pages/ModbusRegisterTab.qml  # ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.9]: 修正文件名（原为ModbusRegisterSection.qml）
        # ✅ 2026-02-08 [Phase 7.42]: TCP控制页面组件
        components/device_info/pages/TCPControlPage.qml
        components/device_info/pages/TCPListPanel.qml
        components/device_info/pages/TCPConfigPanel.qml
        components/device_info/pages/ModbusTCPMasterTab.qml
        components/device_info/pages/ModbusTCPSlaveTab.qml
        components/device_info/pages/S7MasterTab.qml
        components/device_info/pages/S7SlaveTab.qml
        # ✅ 2026-02-08 [Phase 7.43]: MQTT控制页面组件
        components/device_info/pages/MQTTControlPage.qml
        components/device_info/pages/MQTTListPanel.qml
        components/device_info/pages/MQTTConfigPanel.qml
        components/device_info/pages/MQTTConnectionTab.qml
        components/device_info/pages/MQTTSubscribeTab.qml
        components/device_info/pages/MQTTPublishTab.qml
        components/device_info/pages/MQTTMonitorTab.qml
        # ✅ 2026-02-09 [Phase 7.44]: MQTT自动控制页面组件
        components/device_info/pages/MQTTAutoControlTab.qml
        components/device_info/pages/DIModulePanel.qml
        components/device_info/pages/AIModulePanel.qml
        components/device_info/pages/CSModulePanel.qml
        components/device_info/pages/VoiceModulePanel.qml
        components/device_info/pages/ReservedModulePanel.qml
        components/device_info/pages/CurrentProtectionTab.qml
        components/device_info/pages/MotorTempTab.qml
        components/device_info/pages/FrontBearingTempTab.qml
        components/device_info/pages/RearBearingTempTab.qml
        components/device_info/pages/XAxisVibrationTab.qml
        components/device_info/pages/YAxisVibrationTab.qml
        components/device_info/pages/PhaseAWindingTab.qml
        components/device_info/pages/PhaseBWindingTab.qml
        components/device_info/pages/PhaseCWindingTab.qml
        # ✅ 2026-02-11 [Phase 7.45.21]: device_monitor 组件（设备监控页面）
        components/device_monitor/BeltConnectionDiagram.qml
        components/device_monitor/CornerDecoration.qml
        components/device_monitor/DeviceStatusCard.qml
        components/device_monitor/GlowLed.qml
        components/device_monitor/InterlockDiagram.qml
        components/device_monitor/MiniTrendChart.qml
        components/device_monitor/ModernButton.qml
        components/device_monitor/SmoothLineChart.qml
        components/device_monitor/StationCard.qml
        components/device_monitor/StatusBadge.qml
        # ✅ 2026-02-11 [Phase 7.45.22]: voice_management 组件（语音管理页面）
        components/voice_management/TTSConfigSection.qml
        # ✅ 2026-02-11 [Phase 7.45.23]: theme 组件（主题系统）
        theme/qmldir  # ✅ 2026-02-12 [Phase 7.45.27]: 添加 qmldir 以支持 Theme singleton
        theme/Theme.qml
        theme/AnimatedCounter.qml
        theme/CircularProgress.qml
    RESOURCES
        images/header.png
        sounds/ringtone.wav
        # ✅ 2026-02-12 [Phase 7.45.32]: 添加 DeviceSettingsDialog 使用的图片资源
        # 原因：这些图片在 BeltControlSystem.qrc 中但未在 CMakeLists.txt 中，导致部署后不显示
        images/036.png
        images/dvList.png
        images/dvList2.png
        images/bhNameBK.png
        images/bhNameBK1.png
        images/infostate.png
        images/input1.png
        images/input2.png
        images/info_lift.png
        components/device_info/images/deviceInfo40.png
        components/device_info/images/351.png
        components/device_info/images/042.png
        components/device_info/images/034.png
        components/device_info/images/059.png
        components/device_info/images/33.png
        components/device_info/images/DJHeadbutton1.png
        components/device_info/images/DJHeadbutton2.png
        # 2026-01-12: Input1 模块资源文件（102 个图片，全英文文件名）
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
        Input1/Input1Content/images/inputData_Zhuangshi.png
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
        # 2026-01-19: Input1 模块 QML 组件（9 个，自动检测）
        Input1/Input1Content/Back.ui.qml
        Input1/Input1Content/BHState.ui.qml
        Input1/Input1Content/DataShow.ui.qml
        Input1/Input1Content/Head_MiddleMenu.ui.qml
        Input1/Input1Content/Head.ui.qml
        Input1/Input1Content/MyIN_Data.ui.qml
        Input1/Input1Content/MyIN_State.ui.qml
        Input1/Input1Content/Screen01.ui.qml
        Input1/Input1Content/Screen01Form.ui.qml
        # 2026-01-19: Input1 模块 QML 组件（9 个，自动检测）
        Input1/Input1Content/Back.ui.qml
        Input1/Input1Content/BHState.ui.qml
        Input1/Input1Content/DataShow.ui.qml
        Input1/Input1Content/Head_MiddleMenu.ui.qml
        Input1/Input1Content/Head.ui.qml
        Input1/Input1Content/MyIN_Data.ui.qml
        Input1/Input1Content/MyIN_State.ui.qml
        Input1/Input1Content/Screen01.ui.qml
        Input1/Input1Content/Screen01Form.ui.qml
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
# ✅ 2026-02-02 [FIX 100.300.112.8.19.4] 修复 CMake 解析错误 - 注释掉第 270-278 行的孤立文件列表
# ✅ 2026-02-11 [Phase 7.45.21] 修复 CMake 解析错误 - 注释掉第 320-329 行的孤立文件列表
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
#        Input1/Input1Content/Head_MiddleMenu.ui.qml
#        Input1/Input1Content/Head.ui.qml
#        Input1/Input1Content/MyIN_Data.ui.qml
#        Input1/Input1Content/MyIN_State.ui.qml
#        Input1/Input1Content/Screen01.ui.qml
#        Input1/Input1Content/Screen01Form.ui.qml
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