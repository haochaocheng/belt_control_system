# TTS 服务编译流程和 NPU 加速配置说明

## 文档信息
- **创建时间**: 2026-02-11
- **目的**: 说明 TTS 服务的独立编译流程和 NPU 加速配置

---

## 一、TTS 服务架构

### 1.1 独立进程设计

**TTS 服务是一个独立的可执行文件**，不是主程序的一部分：

```
belt_control_system (主程序)
    ↓ 启动子进程
sherpa_tts_service (TTS 服务)
    ↓ 通信方式
JSON via stdin/stdout
```

**设计原因**：
- 解决 MinGW/MSVC ABI 不兼容问题
- 隔离 TTS 引擎，避免主程序崩溃
- 支持跨平台编译（Windows MSVC / Linux ARM64）

---

## 二、编译流程

### 2.1 独立编译脚本

**文件**: `build-tts-service-arm64.ps1`

**编译命令**:
```powershell
.\build-tts-service-arm64.ps1
```

**编译流程**:
1. 清理旧构建目录 `build_tts_arm64`
2. 使用 Docker 容器进行交叉编译
3. CMake 配置：`src/tts_service/CMakeLists.txt`
4. 输出：`build_tts_arm64/sherpa_tts_service` (ARM64 可执行文件)

**关键 Docker 挂载**:
```powershell
docker run --rm `
  -v "e:/2025/3_gongkongji/belt_control_system:/workspace" `
  -v ".../qt-host:/opt/qt-host:ro" `
  -v ".../qt-raspi:/opt/qt-raspi:ro" `
  -v ".../sysroot:/opt/sysroot:ro" `
  -v ".../rk3588-libs:/opt/rk3588-libs:ro" `
  belt-control-rk3588:latest bash -c 'cmake ... && cmake --build .'
```

---

### 2.2 主构建脚本集成

**文件**: `build-ubuntu24-apt.ps1`

**TTS 服务复制流程** (第 1181-1188 行):
```powershell
# Copy TTS service executable
$TtsServiceFile = "$ProjectRoot\build_tts_arm64\sherpa_tts_service"
if (Test-Path $TtsServiceFile) {
    Write-Host "  Copying TTS service executable..." -ForegroundColor Yellow
    Copy-Item $TtsServiceFile "$DockerContextDir\sherpa_tts_service" -Force
    Write-Host "  [OK] TTS service copied" -ForegroundColor Green
} else {
    Write-Host "  [!] TTS service not found (TTS disabled)" -ForegroundColor Yellow
}
```

**说明**:
- 主构建脚本**不编译** TTS 服务
- 只是从 `build_tts_arm64` 目录**复制**预编译的二进制文件
- 如果文件不存在，TTS 功能将被禁用

---

### 2.3 Docker 镜像部署

**文件**: `Dockerfile.ubuntu24-apt`

**TTS 服务部署** (第 13 行):
```dockerfile
COPY sherpa_tts_service /app/sherpa_tts_service
```

**运行时权限** (第 59 行):
```dockerfile
RUN chmod +x /app/belt_control_system /app/sherpa_tts_service /app/detect-audio-device.sh /app/app-entrypoint.sh
```

---

## 三、NPU 加速配置

### 3.1 CMakeLists.txt 配置

**文件**: `src/tts_service/CMakeLists.txt`

**关键配置** (第 22-24 行):
```cmake
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    # ARM64 Linux (RK3588 with RKNN acceleration)
    set(SHERPA_ONNX_ROOT "${CMAKE_SOURCE_DIR}/../../libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared")
```

**说明**:
- ✅ 使用 **sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared** 版本
- ✅ 这是专门为 RK3588 NPU 编译的版本
- ✅ 包含 RKNN Execution Provider

---

### 3.2 链接的库

**Sherpa-ONNX 库** (第 36-37 行):
```cmake
set(SHERPA_ONNX_CXX_LIB "${SHERPA_ONNX_ROOT}/lib/libsherpa-onnx-cxx-api.so")
set(SHERPA_ONNX_C_LIB "${SHERPA_ONNX_ROOT}/lib/libsherpa-onnx-c-api.so")
```

**链接配置** (第 63-66 行):
```cmake
target_link_libraries(sherpa_tts_service
    ${SHERPA_ONNX_CXX_LIB}
    ${SHERPA_ONNX_C_LIB}
)
```

---

### 3.3 运行时库依赖

**RKNN 版本的 libonnxruntime.so**:
- 路径: `libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared/lib/libonnxruntime.so`
- 大小: 13MB
- 包含: RknnExecutionProvider

**RK3588 NPU 运行时库**:
- `librknnrt.so` - RK3588 NPU 运行时
- `librknn_api.so` - RKNN API

**部署位置**:
- Docker 镜像: `/app/lib/libonnxruntime.so`
- Docker 镜像: `/app/lib/librknnrt.so`

---

## 四、当前状态

### 4.1 已编译的 TTS 服务

**文件**: `build_tts_arm64/sherpa_tts_service`

**编译时间**: 2026-01-23 21:55

**文件信息**:
```bash
$ ls -lh build_tts_arm64/sherpa_tts_service
-rw-r--r-- 1 54999 197610 77K  1月 23 21:55 build_tts_arm64/sherpa_tts_service

$ file build_tts_arm64/sherpa_tts_service
ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked
```

**说明**:
- ✅ 已编译为 ARM64 可执行文件
- ✅ 动态链接（需要运行时库）
- ⚠️ 编译时间较早（1月23日），可能需要重新编译

---

### 4.2 NPU 加速状态

**配置状态**:
- ✅ CMakeLists.txt 配置正确（使用 RKNN 版本）
- ✅ RKNN 库文件存在
- ✅ 构建脚本复制 RKNN 库到 Docker 镜像
- ❓ 运行时是否实际使用 NPU（需要验证）

**可能的问题**:
1. **编译时间过早**: 1月23日编译的，可能使用的是旧配置
2. **库依赖**: 需要确认运行时能找到 librknnrt.so
3. **Provider 配置**: Sherpa-ONNX 可能需要显式配置使用 RKNN Provider

---

## 五、重新编译 TTS 服务

### 5.1 为什么需要重新编译？

1. **确保使用最新配置**: 当前二进制文件是 1月23日编译的
2. **验证 NPU 配置**: 确认 RKNN 库正确链接
3. **更新依赖**: 可能有库版本更新

---

### 5.2 重新编译步骤

**步骤 1: 清理旧文件**
```powershell
Remove-Item build_tts_arm64 -Recurse -Force
```

**步骤 2: 重新编译**
```powershell
.\build-tts-service-arm64.ps1
```

**步骤 3: 验证输出**
```powershell
ls -lh build_tts_arm64/sherpa_tts_service
file build_tts_arm64/sherpa_tts_service
```

**步骤 4: 检查库依赖**
```bash
# 在 Docker 容器中
docker run --rm -v "e:/2025/3_gongkongji/belt_control_system:/workspace" \
  belt-control-rk3588:latest \
  aarch64-linux-gnu-readelf -d /workspace/build_tts_arm64/sherpa_tts_service | grep NEEDED
```

**步骤 5: 重新部署**
```powershell
.\build-ubuntu24-apt.ps1 188
```

---

## 六、验证 NPU 加速

### 6.1 部署后验证

**在设备上运行**:
```bash
# 1. 进入容器
docker exec -it belt-control-rk3588 bash

# 2. 检查 TTS 服务
ls -lh /app/sherpa_tts_service

# 3. 检查库依赖
ldd /app/sherpa_tts_service | grep -E 'sherpa|onnx|rknn'

# 4. 检查 RKNN 库
ls -lh /app/lib/librknnrt.so
ls -lh /app/lib/libonnxruntime.so
```

**预期输出**:
```
libsherpa-onnx-c-api.so => /app/lib/libsherpa-onnx-c-api.so
libsherpa-onnx-cxx-api.so => /app/lib/libsherpa-onnx-cxx-api.so
libonnxruntime.so => /app/lib/libonnxruntime.so
librknnrt.so => /app/lib/librknnrt.so
```

---

### 6.2 运行时验证

**方法 1: 检查 NPU 使用率**
```bash
# 运行 TTS 合成时
cat /sys/kernel/debug/rknpu/load
```

**方法 2: 性能测试**
- 当前性能: RTF ≈ 1.9 秒
- NPU 加速后: RTF ≈ 0.2-0.5 秒

**方法 3: 日志分析**
```bash
docker logs belt-control-rk3588 | grep -i rknn
```

---

## 七、总结

### 7.1 TTS 服务编译流程

```
1. 独立编译脚本: build-tts-service-arm64.ps1
   ↓
2. Docker 交叉编译: belt-control-rk3588:latest
   ↓
3. 输出: build_tts_arm64/sherpa_tts_service
   ↓
4. 主构建脚本复制: build-ubuntu24-apt.ps1
   ↓
5. Docker 镜像打包: Dockerfile.ubuntu24-apt
   ↓
6. 部署到设备: /app/sherpa_tts_service
```

### 7.2 NPU 加速配置

| 配置项 | 状态 | 说明 |
|--------|------|------|
| **CMakeLists.txt** | ✅ 正确 | 使用 RKNN 版本 sherpa-onnx |
| **库文件** | ✅ 存在 | libonnxruntime.so (13MB, RKNN) |
| **运行时库** | ✅ 部署 | librknnrt.so 复制到镜像 |
| **实际使用** | ❓ 未确认 | 需要运行时验证 |

### 7.3 下一步行动

1. **重新编译 TTS 服务** (确保使用最新配置)
2. **部署到设备** (运行主构建脚本)
3. **验证 NPU 使用** (检查库依赖和性能)
4. **性能测试** (对比 CPU vs NPU)

---

**文档版本**: v1.0
**最后更新**: 2026-02-11
**作者**: Claude Sonnet 4.5
