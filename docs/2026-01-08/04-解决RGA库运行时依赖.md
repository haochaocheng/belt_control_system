# 修复 81 依赖 - 解决 RGA 库运行时依赖

**日期**: 2026-01-08 15:00
**状态**: 🔧 待执行

---

## 🎯 问题

### 编译警告

```
[!] Some libraries need runtime mounting from host:
    ✓ librga.so.2 => not found (will be mounted from host at runtime)
```

### 问题分析

**librga.so.2** 是什么？
- **全称**: Rockchip RGA (2D Graphics Accelerator) Library
- **用途**: 硬件加速的图像格式转换
- **在本项目中**: Fix 59/Fix 62 使用 RGA3 进行 I420 → NV12 转换

**为什么找不到？**
- 编译时：交叉编译环境缺少 RGA 库
- 运行时：Docker 镜像中未打包 RGA 库

**当前行为**：
- 警告提示"will be mounted from host at runtime"
- 运行时需要从宿主机挂载（不稳定）

---

## ✅ 解决方案

### 方案：将 RGA 库打包到 Docker 镜像

**原理**：
1. 从设备 188 下载 `librga.so*` 文件
2. 复制到 `docker/rk3588/lib/` 目录
3. Dockerfile 自动将其打包到镜像的 `/app/lib/`
4. 运行时通过 `LD_LIBRARY_PATH=/app/lib` 自动找到

---

## 🔧 实施步骤

### Step 1: 下载 RGA 库

```powershell
# 运行下载脚本
.\scripts\2026-01-08\01-download-rga-libs.ps1
```

**脚本功能**：
1. ✅ 检查设备 192.168.10.188 连接
2. ✅ 在设备上查找所有 `librga.so*` 文件
3. ✅ 下载到 `docker/rk3588/lib/` 目录
4. ✅ 验证下载结果

### Step 2: 验证文件

检查 `docker/rk3588/lib/` 目录：

```powershell
Get-ChildItem docker/rk3588/lib/librga.so*
```

预期输出：
```
librga.so        (符号链接)
librga.so.2      (符号链接)
librga.so.2.x.x  (实际库文件)
```

### Step 3: 重新编译

```powershell
.\build-ubuntu24-apt.ps1 188
```

**预期结果**：
- ✅ 编译时警告消失
- ✅ Docker 镜像包含 RGA 库
- ✅ 运行时自动加载，无需手动挂载

---

## 📊 验证方法

### 编译时验证

编译日志中应该 **不再出现** RGA 警告：
```
[!] Some libraries need runtime mounting from host:
    ✓ librga.so.2 => not found (will be mounted from host at runtime)
```

### 运行时验证

设备上检查库加载：
```bash
# 进入容器
docker exec -it belt-control-latest bash

# 检查 RGA 库
ls -l /app/lib/librga.so*

# 检查程序依赖
ldd /app/belt_control_system | grep librga
```

预期输出：
```
librga.so.2 => /app/lib/librga.so.2 (0x00007f...)  ← 正确加载
```

---

## 🔍 技术细节

### Dockerfile 自动处理

`Dockerfile.ubuntu24-apt` 中的相关配置：

```dockerfile
# Step 1: 复制运行时库
COPY docker/rk3588/lib/*.so* /app/lib/
#     ^^^^^^^^^^^^^^^^^^^^^^
#     包括 librga.so.2 等所有动态库

# Step 2: 设置库搜索路径
ENV LD_LIBRARY_PATH=/app/lib:${LD_LIBRARY_PATH}
#   ^^^^^^^^^^^^^^^
#   运行时自动搜索 /app/lib
```

### RGA 库的作用

**在本项目中的使用**（Fix 59/Fix 62）：

```c
// RKMPP 解码器输出 I420
decoder_output: AV_PIX_FMT_YUV420P (I420)

// RGA3 硬件转换 I420 → NV12
rga_convert(I420, NV12);  // ← 需要 librga.so.2

// RGA3 硬件转换 NV12 → RGBA
rga_convert(NV12, RGBA);  // ← 需要 librga.so.2
```

**性能优势**：
- 软件转换：~40% CPU
- RGA3 硬件转换：~0% CPU（专用硬件）

---

## ⚠️ 注意事项

### 1. 符号链接问题

RGA 库通常有多个符号链接：
```
librga.so -> librga.so.2
librga.so.2 -> librga.so.2.1.0
librga.so.2.1.0 (实际文件)
```

**解决**：下载脚本会下载所有相关文件。

### 2. 版本兼容性

- RK3588 设备上的 RGA 版本：2.x
- 确保下载的库版本与设备匹配

### 3. Windows 符号链接

PowerShell 复制时可能丢失符号链接，需要：
- 使用 SCP 保持链接结构
- 或在 Dockerfile 中手动创建符号链接

---

## 📁 相关文件

### 新建文件
- `scripts/2026-01-08/01-download-rga-libs.ps1` - RGA 库下载脚本

### 修改位置
- `docker/rk3588/lib/` - RGA 库存放目录（新增文件）

### 相关文档
- [Fix 59 - I420 输出优化](../2025-12-31/修复11-使用h264_v4l2m2m硬件解码器.md)
- [Fix 62 - RGA 硬件加速](../2025-12-31/RGA硬件加速器正确使用方法研究.md)

---

## ✅ 成功指标

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| **编译警告** | ⚠️ librga.so.2 not found | ✅ 无警告 |
| **运行时挂载** | ⚠️ 需要手动挂载 | ✅ 自动加载 |
| **库路径** | ❌ host:/usr/lib | ✅ /app/lib |
| **RGA 硬件加速** | ⚠️ 可能失败 | ✅ 正常工作 |

---

**文档版本**: v1.0
**创建时间**: 2026-01-08 15:00
**状态**: 🔧 待执行下载脚本
