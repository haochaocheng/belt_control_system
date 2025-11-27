add_library(real_hal_module STATIC
    real_hal.cpp
    real_hal.h
)

target_link_libraries(real_hal_module PRIVATE
    Qt6::Core
    Qt6::SerialPort
    hal_module
)

target_include_directories(real_hal_module PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/../..
)
