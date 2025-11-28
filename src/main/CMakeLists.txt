qt_add_executable(belt_control_system
    main.cpp
)

target_link_libraries(belt_control_system PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Quick3D
    qml_module
    control_module
    hal_module
    simulated_hal_module
    real_hal_module
    utils_module
    sip_phone_module
)

# Link risip_sdk with whole-archive to force inclusion of stub symbols
target_link_libraries(belt_control_system PRIVATE
    -Wl,--whole-archive
    risip_sdk
    -Wl,--no-whole-archive
)

target_include_directories(belt_control_system PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
    F:/0/pjproject-2.15.1/pjproject-2.15.1/pjlib/include
)

set_target_properties(belt_control_system PROPERTIES
    WIN32_EXECUTABLE FALSE
    MACOSX_BUNDLE TRUE
)
