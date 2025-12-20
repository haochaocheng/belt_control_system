# Install script for directory: E:/2025/3_gongkongji/belt_control_system/src/tts_service

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "C:/Program Files/sherpa_tts_service")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE EXECUTABLE FILES "E:/2025/3_gongkongji/belt_control_system/src/tts_service/build-msvc/Debug/sherpa_tts_service.exe")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE EXECUTABLE FILES "E:/2025/3_gongkongji/belt_control_system/src/tts_service/build-msvc/Release/sherpa_tts_service.exe")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE EXECUTABLE FILES "E:/2025/3_gongkongji/belt_control_system/src/tts_service/build-msvc/MinSizeRel/sherpa_tts_service.exe")
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE EXECUTABLE FILES "E:/2025/3_gongkongji/belt_control_system/src/tts_service/build-msvc/RelWithDebInfo/sherpa_tts_service.exe")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE FILE FILES
    "E:/2025/3_gongkongji/belt_control_system/src/tts_service/../../libs/sherpa-onnx-v1.12.9-win-x64-shared/bin/onnxruntime.dll"
    "E:/2025/3_gongkongji/belt_control_system/src/tts_service/../../libs/sherpa-onnx-v1.12.9-win-x64-shared/bin/onnxruntime_providers_shared.dll"
    "E:/2025/3_gongkongji/belt_control_system/src/tts_service/../../libs/sherpa-onnx-v1.12.9-win-x64-shared/lib/cargs.dll"
    "E:/2025/3_gongkongji/belt_control_system/src/tts_service/../../libs/sherpa-onnx-v1.12.9-win-x64-shared/lib/onnxruntime.dll"
    "E:/2025/3_gongkongji/belt_control_system/src/tts_service/../../libs/sherpa-onnx-v1.12.9-win-x64-shared/lib/onnxruntime_providers_shared.dll"
    "E:/2025/3_gongkongji/belt_control_system/src/tts_service/../../libs/sherpa-onnx-v1.12.9-win-x64-shared/lib/sherpa-onnx-c-api.dll"
    "E:/2025/3_gongkongji/belt_control_system/src/tts_service/../../libs/sherpa-onnx-v1.12.9-win-x64-shared/lib/sherpa-onnx-cxx-api.dll"
    )
endif()

if(CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_COMPONENT MATCHES "^[a-zA-Z0-9_.+-]+$")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
  else()
    string(MD5 CMAKE_INST_COMP_HASH "${CMAKE_INSTALL_COMPONENT}")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INST_COMP_HASH}.txt")
    unset(CMAKE_INST_COMP_HASH)
  endif()
else()
  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
  file(WRITE "E:/2025/3_gongkongji/belt_control_system/src/tts_service/build-msvc/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
