qt_add_executable(belt_control_system
    main.cpp
    pjmedia_vid_dev_stub.c
)

target_link_libraries(belt_control_system PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Quick3D
    qml_module
    qml_moduleplugin
    control_module
    hal_module
    simulated_hal_module
    real_hal_module
    utils_module
    sip_phone_module
    -Wl,--whole-archive ${CMAKE_BINARY_DIR}/libpjmedia_vid_dev_stub.a -Wl,--no-whole-archive
    ${CMAKE_BINARY_DIR}/libpjmedia_vid_dev_stub.a
)

target_include_directories(belt_control_system PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

set_target_properties(belt_control_system PROPERTIES
    WIN32_EXECUTABLE FALSE
    MACOSX_BUNDLE TRUE
)
