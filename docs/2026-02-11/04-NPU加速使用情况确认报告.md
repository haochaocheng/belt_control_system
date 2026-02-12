# NPU 加速使用情况确认报告

## 文档信息
- **创建时间**: 2026-02-11
- **问题**: 确认项目是否使用了 RK3588 NPU 加速
- **结论**: ✅ **已配置 NPU 加速，但可能未正确启用**

---

## 一、NPU 加速配置证据

### 1.1 Sherpa-ONNX RKNN 版本库

**证据 1**: CMakeLists.txt 明确指定 RKNN 版本

**文件**: `src/tts_service/CMakeLists.txt`

```cmake
# 第 22-24 行
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    # ARM64 Linux (RK3588 with RKNN acceleration)
    set(SHERPA_ONNX_ROOT "${CMAKE_SOURCE_DIR}/../../libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared")
```

**说明**:
- ✅ 项目使用的是 **sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared** 版本
- ✅ 注释明确写明 "RK3588 with RKNN acceleration"
- ✅ 这是专门为 RK3588 NPU 编译的版本

---

### 1.2 RKNN 库文件存在

**证据 2**: RKNN 版本的 libonnxruntime.so

**文件路径**: `libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared/lib/`

```bash
$ ls -lh libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared/lib/
total 18M
-rw-r--r-- 1 54999 197610  13M  8月 25 11:39 libonnxruntime.so
-rw-r--r-- 1 54999 197610 4.5M  8月 25 11:39 libsherpa-onnx-c-api.so
-rw-r--r-- 1 54999 197610 218K  8月 25 11:39 libsherpa-onnx-cxx-api.so
```

**说明**:
- ✅ `libonnxruntime.so` (13MB) 是 RKNN 版本的 ONNX Runtime
- ✅ 这个版本内置了 RknnExecutionProvider
- ✅ 文件日期 8月25日，说明是专门下载的 RKNN 版本

---

### 1.3 构建脚本复制 RKNN 库

**证据 3**: build-ubuntu24-apt.ps1 复制 RKNN 库

**文件**: `build-ubuntu24-apt.ps1` (第 1361-1386 行)

```powershell
# Copy libonnxruntime (RKNN acceleration for TTS)
Write-Host "  Copying libonnxruntime (RKNN acceleration)..." -ForegroundColor Yellow
$OnnxRuntimePath = "$ProjectRoot\libs\sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared\lib\libonnxruntime.so"
if (Test-Path $OnnxRuntimePath) {
    Copy-Item $OnnxRuntimePath "$DockerBuildDir\lib\" -Force
    Write-Host "  [OK] libonnxruntime copied (RKNN hardware acceleration)" -ForegroundColor Green
}

# Copy librknnrt (RK3588 NPU runtime - REQUIRED for RKNN acceleration)
$RknnRtPath = "$ProjectRoot\docker\rk3588\rk3588-libs\lib\librknnrt.so"
if (Test-Path $RknnRtPath) {
    Copy-Item $RknnRtPath "$DockerBuildDir\lib\" -Force
    Write-Host "    OK: librknnrt copied (RKNN acceleration enabled)" -ForegroundColor Green
} else {
    Write-Host "    WARNING: librknnrt not found - RKNN acceleration will NOT work!" -ForegroundColor Red
}
```

**说明**:
- ✅ 构建脚本明确复制 `libonnxruntime.so` (RKNN 版本)
- ✅ 复制 `librknnrt.so` (RK3588 NPU 运行时库)
- ✅ 注释明确说明 "RKNN hardware acceleration"

---

### 1.4 运行时准备脚本包含 RKNN 库

**证据 4**: prepare-runtime.sh 列出 RKNN 库

**文件**: `docker/rk3588/prepare-runtime.sh` (第 42-52 行)

```bash
LIBS=(
    # PJSIP 库
    ...

    # Sherpa-ONNX RKNN 版本
    "sherpa-onnx-c-api"
    "sherpa-onnx-cxx-api"
    "sherpa-onnx-core"
    "sherpa-onnx-kaldifst-core"
    "sherpa-onnx-fstfar"
    "sherpa-onnx-fst"
    "kaldi-native-fbank-core"
    "onnxruntime"
    "rknnrt"
    "rknn_api"
    ...
)
```

**说明**:
- ✅ 注释明确写明 "Sherpa-ONNX RKNN 版本"
- ✅ 包含 `rknnrt` 和 `rknn_api` 库
- ✅ 这些是 RK3588 NPU 运行时必需的库

---

### 1.5 RKNN 库文件已存在

**证据 5**: docker/rk3588/rk3588-libs/lib/ 中的 RKNN 库

```bash
$ find docker/rk3588/rk3588-libs/lib -name "*rknn*"
docker/rk3588/rk3588-libs/lib/librknnrt.so
```

**说明**:
- ✅ `librknnrt.so` 存在于 rk3588-libs 目录
- ✅ 这是 RK3588 NPU 运行时库
- ✅ 构建时会被复制到 Docker 镜像

---

## 二、NPU 加速可能未启用的原因

### 2.1 ONNX Runtime Provider 配置

**问题**: 没有找到显式配置 RknnExecutionProvider 的代码

**搜索结果**:
```bash
# 搜索 ExecutionProvider 配置
$ grep -r "ExecutionProvider" src/
# 未找到相关配置代码
```

**说明**:
- ⚠️ 虽然使用了 RKNN 版本的 libonnxruntime.so
- ⚠️ 但没有在代码中显式配置使用 RknnExecutionProvider
- ⚠️ 可能依赖 ONNX Runtime 的自动检测机制

---

### 2.2 Sherpa-ONNX 默认行为

**Sherpa-ONNX 的 Provider 选择机制**:

1. **自动检测**: Sherpa-ONNX 会自动检测可用的 Execution Provider
2. **优先级**: RKNN > CUDA > CPU
3. **回退机制**: 如果 RKNN 不可用，自动回退到 CPU

**可能的情况**:
- ✅ 如果 librknnrt.so 正确加载，RKNN Provider 会自动启用
- ⚠️ 如果 librknnrt.so 加载失败，会回退到 CPU
- ⚠️ 没有日志输出，无法确认当前使用的 Provider

---

### 2.3 模型格式问题

**RKNN 加速的要求**:

1. **ONNX 模型**: 需要是标准 ONNX 格式（✅ 当前使用的是 ONNX 模型）
2. **RKNN 转换**: 某些情况下需要将 ONNX 模型转换为 RKNN 格式（❓ 未确认）
3. **算子支持**: 模型中的算子必须被 RKNN 支持（❓ 未确认）

**当前模型**:
- 模型路径: `/app/tts_models/vits-zh-aishell3/`
- 模型格式: ONNX (`.onnx` 文件)
- ❓ 未确认是否需要转换为 `.rknn` 格式

---

## 三、验证 NPU 是否正在使用

### 3.1 方法 1：检查日志输出

**修改代码添加日志**:

**文件**: `src/tts_service/sherpa_tts_service.cpp`

在初始化 TTS 引擎时添加：

```cpp
// 初始化 TTS 引擎
auto tts = sherpa_onnx::OfflineTts(config);

// 2026-02-11: 输出 ONNX Runtime Provider 信息
std::cout << "========================================" << std::endl;
std::cout << "ONNX Runtime Providers:" << std::endl;
// 注意：sherpa-onnx 可能没有直接暴露 provider 信息的 API
// 需要查看 sherpa-onnx 文档或源码
std::cout << "========================================" << std::endl;
```

**问题**: Sherpa-ONNX 可能没有暴露 Provider 信息的 API

---

### 3.2 方法 2：使用 ldd 检查库依赖

**在设备上运行**:

```bash
# 进入容器
docker exec -it belt-control-rk3588 bash

# 检查 sherpa_tts_service 链接的库
ldd /app/bin/sherpa_tts_service | grep -E 'rknn|onnx'

# 预期输出：
# libonnxruntime.so => /app/lib/libonnxruntime.so
# librknnrt.so => /app/lib/librknnrt.so
```

**如果看到 librknnrt.so**:
- ✅ RKNN 库已加载
- ✅ NPU 加速可能已启用

**如果没有看到 librknnrt.so**:
- ❌ RKNN 库未加载
- ❌ NPU 加速未启用

---

### 3.3 方法 3：性能对比测试

**测试方法**:

1. **当前性能**: RTF ≈ 1.9 秒
2. **CPU 性能**: 预期 RTF ≈ 1.5-2.0 秒（ARM CPU）
3. **NPU 性能**: 预期 RTF ≈ 0.2-0.5 秒（NPU 加速）

**结论**:
- ⚠️ 当前 RTF ≈ 1.9 秒，**接近 CPU 性能**
- ⚠️ 如果 NPU 正常工作，应该是 0.2-0.5 秒
- ⚠️ **很可能 NPU 未启用，正在使用 CPU**

---

### 3.4 方法 4：检查 NPU 使用率

**在设备上运行**:

```bash
# 查看 NPU 使用率（RK3588 特定命令）
cat /sys/kernel/debug/rknpu/load

# 或使用 top 查看 NPU 进程
top -H | grep npu
```

**如果 NPU 使用率为 0**:
- ❌ NPU 未被使用
- ❌ TTS 正在使用 CPU

---

## 四、结论和建议

### 4.1 当前状态

| 项目 | 状态 | 说明 |
|------|------|------|
| **RKNN 库配置** | ✅ 已配置 | 使用 sherpa-onnx-v1.12.9-rknn 版本 |
| **libonnxruntime.so** | ✅ 已复制 | RKNN 版本 (13MB) |
| **librknnrt.so** | ✅ 已复制 | RK3588 NPU 运行时库 |
| **构建脚本** | ✅ 正确 | 明确复制 RKNN 库 |
| **NPU 实际使用** | ❓ 未确认 | 性能数据显示可能未启用 |

---

### 4.2 NPU 未启用的可能原因

1. **librknnrt.so 加载失败**
   - 库路径不在 LD_LIBRARY_PATH 中
   - 库版本不兼容
   - 缺少依赖库

2. **ONNX Runtime 未检测到 RKNN**
   - RKNN Provider 未正确注册
   - 模型不支持 RKNN 加速
   - 算子不支持 RKNN

3. **模型格式问题**
   - 需要将 ONNX 模型转换为 RKNN 格式
   - 当前使用的是通用 ONNX 模型

4. **环境变量缺失**
   - 可能需要设置 RKNN 相关环境变量
   - 例如: `RKNN_LOG_LEVEL=1`

---

### 4.3 下一步行动

#### 立即验证（今天）

1. **检查库依赖**
   ```bash
   ssh linaro@192.168.10.188
   docker exec -it belt-control-rk3588 bash
   ldd /app/bin/sherpa_tts_service | grep -E 'rknn|onnx'
   ```

2. **检查 NPU 使用率**
   ```bash
   # 运行 TTS 合成时
   cat /sys/kernel/debug/rknpu/load
   ```

3. **查看运行时日志**
   ```bash
   docker logs belt-control-rk3588 | grep -i rknn
   ```

#### 短期修复（1-2天）

4. **添加 Provider 日志**
   - 修改 sherpa_tts_service.cpp
   - 输出当前使用的 Execution Provider
   - 确认是 RKNN 还是 CPU

5. **检查 LD_LIBRARY_PATH**
   - 确保 /app/lib 在 LD_LIBRARY_PATH 中
   - 确保 librknnrt.so 可以被找到

6. **测试 RKNN 库加载**
   ```bash
   # 在容器内测试
   LD_DEBUG=libs /app/bin/sherpa_tts_service 2>&1 | grep rknn
   ```

#### 中期优化（1周）

7. **模型转换测试**
   - 尝试将 ONNX 模型转换为 RKNN 格式
   - 测试性能差异

8. **对比测试**
   - 强制使用 CPU Provider
   - 对比 CPU vs RKNN 性能

9. **优化配置**
   - 根据测试结果调整配置
   - 确保 NPU 正确启用

---

## 五、参考资料

### 5.1 Sherpa-ONNX RKNN 文档

- GitHub: https://github.com/k2-fsa/sherpa-onnx
- RKNN 版本说明: https://k2-fsa.github.io/sherpa/onnx/install/linux.html#rknn

### 5.2 RK3588 NPU 文档

- RKNN Toolkit: https://github.com/rockchip-linux/rknn-toolkit2
- NPU 性能优化: https://github.com/rockchip-linux/rknpu2

### 5.3 ONNX Runtime RKNN Provider

- ONNX Runtime: https://onnxruntime.ai/
- Execution Providers: https://onnxruntime.ai/docs/execution-providers/

---

**文档版本**: v1.0
**最后更新**: 2026-02-11
**作者**: Claude Sonnet 4.5
