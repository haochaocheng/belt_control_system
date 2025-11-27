add_library(control_module STATIC
    belt_controller.cpp
    belt_controller.h
)

target_link_libraries(control_module PRIVATE
    Qt6::Core
    hal_module
)

target_include_directories(control_module PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)
