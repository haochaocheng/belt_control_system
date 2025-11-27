add_library(utils_module STATIC
    logger.cpp
    logger.h
    config_reader.cpp
    config_reader.h
)

target_link_libraries(utils_module PRIVATE
    Qt6::Core
)

target_include_directories(utils_module PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)
