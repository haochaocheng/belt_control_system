# Phase 7.46.55 - 修复 CMakeLists.txt 缺少 TTS 源文件

**创建时间**: 2026-02-25 00:25
**问题**: 链接失败，找不到 TTS 相关符号
**原因**: CMakeLists.txt 中没有包含 TTS 模块源文件
**解决**: 添加 TTS 源文件到 CMakeLists.txt

---

## 一、问题分析

### 1.1 链接错误

```
undefined reference to `TTSEngineManager::synthesize(...)'
undefined reference to `PaddleSpeechAdapter::PaddleSpeechAdapter(...)'
undefined reference to `TTSEngineManager::registerEngine(...)'
...
```

### 1.2 根本原因

**CMakeLists.txt 中缺少 TTS 源文件**：
- CommonControl.cpp 使用了 TTS 类
- 但 CMakeLists.txt 没有编译 TTS 源文件
- 导致链接时找不到符号

---

## 二、修改内容

### 2.1 src/control/CMakeLists.txt

#### 添加源文件（Line 27-31）

```cmake
set(CONTROL_SOURCES
    ...
    TTSConfigManager.cpp
    # ✅ 2026-02-25 00:20 [Phase 7.46.54]: 添加 TTS 引擎模块源文件
    tts/TTSEngineManager.cpp
    tts/TTSEngineAdapter.cpp
    tts/PaddleSpeechAdapter.cpp
    # ❌ 2026-02-25 00:20 [禁用 MeloTTS]: tts/MeloTTSAdapter.cpp
)
```

#### 添加头文件（Line 59-63）

```cmake
set(CONTROL_HEADERS
    ...
    TTSConfigManager.h
    # ✅ 2026-02-25 00:20 [Phase 7.46.54]: 添加 TTS 引擎模块头文件
    tts/TTSEngineManager.h
    tts/TTSEngineAdapter.h
    tts/PaddleSpeechAdapter.h
    # ❌ 2026-02-25 00:20 [禁用 MeloTTS]: tts/MeloTTSAdapter.h
)
```

---

## 三、验证

### 3.1 重新编译

```powershell
# 重新运行构建
.\build-ubuntu24-apt.ps1 188
```

### 3.2 预期结果

- ✅ 编译成功
- ✅ 链接成功
- ✅ 无 undefined reference 错误

---

## 四、相关修改总结

### Phase 7.46.54 - 禁用 MeloTTS

1. ✅ CommonControl.h: 注释 MeloTTSAdapter.h
2. ✅ CommonControl.cpp: 注释 MeloTTS 注册代码
3. ✅ CommonControl.cpp: 注释引擎列表
4. ✅ CommonControl.cpp: 注释模型路径
5. ✅ TTSEngineAdapter.h: 注释 MeloTTS 枚举
6. ✅ requirements.txt: MeloTTS 已禁用

### Phase 7.46.55 - 修复 CMakeLists.txt

7. ✅ CMakeLists.txt: 添加 TTS 源文件
8. ✅ CMakeLists.txt: 添加 TTS 头文件

---

## 五、下一步

```powershell
# 等待 Docker 基础镜像构建完成（还剩 5-15 分钟）
# 然后重新运行构建
.\build-ubuntu24-apt.ps1 188
```

---

**文档版本**: v1.0
**最后更新**: 2026-02-25 00:25
**状态**: 已完成
