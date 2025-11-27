add_library(hal_module STATIC
    hardware_hal.cpp
    hardware_hal.h
)

target_link_libraries(hal_module PRIVATE
    Qt6::Core
    Qt6::SerialPort
)

target_include_directories(hal_module PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/../..
)
