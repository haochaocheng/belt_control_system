add_library(simulated_hal_module STATIC
    simulated_hal.cpp
    simulated_hal.h
)

target_link_libraries(simulated_hal_module PRIVATE
    Qt6::Core
    hal_module
)

target_include_directories(simulated_hal_module PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/../..
)
