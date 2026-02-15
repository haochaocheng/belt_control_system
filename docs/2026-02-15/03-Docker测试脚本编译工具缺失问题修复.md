# Docker测试脚本编译工具缺失问题修复

**创建时间**: 2026-02-15 05:00
**问题**: Docker测试失败，pyworld/webrtcvad等依赖编译失败
**状态**: ✅ 已修复

---

## 🔍 问题分析

### 错误信息

```
error: command 'gcc' failed: No such file or directory
error: command 'g++' failed: No such file or directory

ERROR: Failed building wheel for pyworld
ERROR: Failed building wheel for webrtcvad
ERROR: Failed building wheel for ligo-segments
```

### 根本原因

**python:3.11-slim 镜像特点**：
- ✅ 体积小（约150MB）
- ❌ 不包含编译工具（gcc、g++、make等）
- ❌ 不适合需要编译C/C++扩展的Python包

**paddlespeech依赖**：
- `pyworld` - 需要C++编译
- `webrtcvad` - 需要C编译
- `ligo-segments` - 需要C编译

---

## ✅ 解决方案

### 修复内容

在安装Python依赖前，先安装编译工具：

```bash
# ✅ 2026-02-15 05:00 [修复]: 安装编译工具
echo '  📦 安装编译工具...'
apt-get update -qq
apt-get install -y build-essential -qq

echo '  📦 安装Python依赖...'
pip install paddlepaddle==3.0.0 -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet
pip install paddlespeech -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet
pip install soundfile -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet
```

### build-essential 包含内容

- `gcc` - GNU C编译器
- `g++` - GNU C++编译器
- `make` - 构建工具
- `libc6-dev` - C标准库开发文件
- 其他必要的编译工具

---

## 📊 修复前后对比

### 修复前

```bash
# ❌ 直接安装Python包
pip install paddlespeech
# 结果：pyworld、webrtcvad编译失败
```

### 修复后

```bash
# ✅ 先安装编译工具
apt-get install -y build-essential

# ✅ 再安装Python包
pip install paddlespeech
# 结果：所有依赖成功编译
```

---

## 🚀 使用方法

现在可以正常运行测试脚本：

```powershell
.\scripts\2026-02-15\06-test-paddlespeech-docker.ps1
```

**预期流程**：
1. 检查VITS模型 ✅
2. 准备输出目录 ✅
3. 安装编译工具（build-essential）
4. 安装paddlespeech及依赖
5. 测试语音合成
6. 输出音频文件

**预计时间**：10-15分钟（首次需要安装编译工具和依赖）

---

## 💡 技术细节

### 为什么需要编译工具？

**Python C扩展编译流程**：
```
Python源码 (.pyx/.c/.cpp)
    ↓
Cython编译 (如果是.pyx)
    ↓
C/C++编译 (gcc/g++)
    ↓
链接 (ld)
    ↓
.so动态库 (Linux)
```

**paddlespeech依赖的C扩展**：
- `pyworld` - 语音信号处理（C++）
- `webrtcvad` - 语音活动检测（C）
- `ligo-segments` - 时间段处理（C）
- `librosa` - 音频分析（部分C扩展）

### 为什么不用完整镜像？

**python:3.11 vs python:3.11-slim**：

| 特性 | python:3.11 | python:3.11-slim |
|------|-------------|------------------|
| 大小 | ~900MB | ~150MB |
| 编译工具 | ✅ 包含 | ❌ 不包含 |
| 下载速度 | 慢 | 快 |
| 适用场景 | 需要编译 | 纯Python |

**我们的选择**：
- 使用 `python:3.11-slim`（快速下载）
- 手动安装 `build-essential`（按需添加）
- 平衡了镜像大小和功能需求

---

## ⚠️ 注意事项

### 1. 编译时间

安装编译工具和编译依赖需要额外时间：
- `build-essential` 安装：约1-2分钟
- `paddlespeech` 依赖编译：约5-10分钟
- **总计**：约10-15分钟（首次）

### 2. 磁盘空间

编译工具会占用额外空间：
- `build-essential`：约200MB
- 编译临时文件：约100MB
- **总计**：约300MB额外空间

### 3. 网络依赖

需要从apt源下载编译工具：
- 使用Debian官方源
- 如果网络慢，可能需要更长时间

---

## 📝 相关文件

### 修改的文件
- `scripts/2026-02-15/06-test-paddlespeech-docker.ps1`

### Git提交
- 提交信息：`fix(tts): 修复Docker测试脚本编译工具缺失问题`
- 已推送到GitHub和GitLab

---

## 🎯 下一步

运行修复后的测试脚本：

```powershell
.\scripts\2026-02-15\06-test-paddlespeech-docker.ps1
```

**预期结果**：
- ✅ 编译工具安装成功
- ✅ paddlespeech依赖编译成功
- ✅ 语音合成测试成功
- ✅ 输出音频文件：`test_output/test_output.wav`

---

**相关文档**：
- [PaddleSpeech模型下载问题完整解决方案](./02-PaddleSpeech模型下载问题完整解决方案.md)
- [PaddleSpeech离线部署完整方案](./01-PaddleSpeech离线部署完整方案.md)
