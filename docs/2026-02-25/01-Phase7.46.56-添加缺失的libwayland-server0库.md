# Phase 7.46.56 - 添加缺失的 libwayland-server0 库

**创建时间**: 2026-02-25 00:35
**问题**: 应用启动失败，缺少 libwayland-server.so.0
**原因**: Dockerfile 中缺少 libwayland-server0 系统库
**解决**: 添加 libwayland-server0 到系统依赖

---

## 一、问题分析

### 1.1 错误信息

```
/bin/bash: error while loading shared libraries: libwayland-server.so.0: cannot open shared object file: No such file or directory
Application exited with code: 127
```

### 1.2 根本原因

**Dockerfile.ubuntu24-base 中缺少 libwayland-server0**：
- 已有：libwayland-client0, libwayland-egl1
- 缺少：libwayland-server0
- 导致应用启动时找不到库

---

## 二、修改内容

### 2.1 Dockerfile.ubuntu24-base (Line 50)

**修改前**：
```dockerfile
# OpenGL/EGL/Graphics
libegl1 \
libgles2 \
libgbm1 \
libdrm2 \
libwayland-client0 \
libwayland-egl1 \
\
```

**修改后**：
```dockerfile
# OpenGL/EGL/Graphics
libegl1 \
libgles2 \
libgbm1 \
libdrm2 \
libwayland-client0 \
libwayland-egl1 \
libwayland-server0 \
\
```

---

## 三、影响分析

### 3.1 构建时间影响

**几乎无影响**：
- libwayland-server0 大小：~100 KB
- 下载时间：<5 秒
- 安装时间：<5 秒
- **总影响：可忽略**

### 3.2 不涉及编译

**libwayland-server0 是预编译的动态库**：
- ✅ 不需要编译
- ✅ 直接从 Ubuntu 仓库下载
- ✅ apt-get install 即可

---

## 四、今日完成工作总结

### Phase 7.46.54 - 彻底禁用 MeloTTS

**原因**：MeloTTS 不适合煤矿工业场景
- 语音太柔和，缺乏权威感
- 部署复杂（需要 Rust 编译）
- 构建时间长（60-90 分钟 QEMU）

**修改内容**：
1. ✅ CommonControl.h: 注释 MeloTTSAdapter.h
2. ✅ CommonControl.cpp: 注释 MeloTTS 注册代码
3. ✅ CommonControl.cpp: 注释引擎列表
4. ✅ CommonControl.cpp: 注释模型路径
5. ✅ TTSEngineAdapter.h: 注释 MeloTTS 枚举
6. ✅ requirements.txt: MeloTTS 已禁用

**效果**：
- 构建时间：从 120-180 分钟降到 20-35 分钟
- 节省时间：100-145 分钟

---

### Phase 7.46.55 - 修复 CMakeLists.txt 缺少 TTS 源文件

**问题**：链接失败，找不到 TTS 相关符号

**修改内容**：
1. ✅ src/control/CMakeLists.txt: 添加 TTS 源文件
   - tts/TTSEngineManager.cpp
   - tts/TTSEngineAdapter.cpp
   - tts/PaddleSpeechAdapter.cpp
2. ✅ src/control/CMakeLists.txt: 添加 TTS 头文件
   - tts/TTSEngineManager.h
   - tts/TTSEngineAdapter.h
   - tts/PaddleSpeechAdapter.h

---

### Phase 7.46.56 - 添加缺失的 libwayland-server0 库

**问题**：应用启动失败，缺少 libwayland-server.so.0

**修改内容**：
1. ✅ Dockerfile.ubuntu24-base: 添加 libwayland-server0

---

## 五、下一步操作

### 5.1 重新构建

```powershell
# 删除缓存文件
Remove-Item .docker_base_cache.json -Force

# 重新构建
.\build-ubuntu24-apt.ps1 192.168.10.186
```

### 5.2 预计时间

- 有 Docker 缓存：**2-5 分钟**
- 无缓存（重建）：**20-35 分钟**

---

## 六、相关文档

- [22-Phase7.46.54-彻底禁用MeloTTS.md](22-Phase7.46.54-彻底禁用MeloTTS.md)
- [27-Phase7.46.55-修复CMakeLists缺少TTS源文件.md](27-Phase7.46.55-修复CMakeLists缺少TTS源文件.md)
- [21-煤矿工业场景TTS方案分析.md](21-煤矿工业场景TTS方案分析.md)

---

**文档版本**: v1.0
**最后更新**: 2026-02-25 00:35
**状态**: 已完成
**用时**: 约 3 小时（包括分析、修改、文档）
