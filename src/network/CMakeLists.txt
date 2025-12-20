# Network module - Modbus TCP communication
cmake_minimum_required(VERSION 3.16)

project(network_module LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Network SerialBus)

add_library(network_module STATIC
    ModbusTcpClient.h
    ModbusTcpClient.cpp
    NetworkTask.h
    NetworkTask.cpp
)

target_link_libraries(network_module
    Qt6::Core
    Qt6::Network
    Qt6::SerialBus
)

target_include_directories(network_module PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)
