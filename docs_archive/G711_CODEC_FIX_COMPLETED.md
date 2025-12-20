# G.711 编解码器修复完成报告

## 修复时间
2025-12-05 (下午完成)

## 问题根源

经过深入分析，发现**488 Not Acceptable Here**错误的根本原因：

### 1. SDP缺少G.711编解码器 (PCMU/PCMA)

**用户测试日志 (13:10:00)** 显示SDP只包含：
```sdp
m=audio 4000 RTP/AVP 96 3 120
a=rtpmap:96 iLBC/8000
a=rtpmap:3 GSM/8000
a=rtpmap:120 telephone-event/8000
```

**缺失**: PCMU (payload 0) 和 PCMA (payload 8) - FreeSWITCH要求的标准编解码器

### 2. 三层配置问题导致G.711被禁用

尽管`config_site.h`设置了`PJMEDIA_HAS_G711_CODEC 1`，但编解码器仍未编译进库，原因：

```
config_site.h (#define PJMEDIA_HAS_G711_CODEC 1)
    ↓ 被覆盖
config_auto.h (#define PJMEDIA_HAS_G711_CODEC 0)  ← 自动生成文件
    ↓ 被覆盖
os-auto.mak (AC_NO_G711_CODEC=1)  ← 根本原因！
    ↓ 导致
编译器命令行: gcc ... -DPJMEDIA_HAS_G711_CODEC=0 ...  ← 最高优先级！
```

**关键原理**: 编译器命令行参数 (`-D`) 优先级 > 头文件 `#define`

## 完整修复方案

### 修改文件清单

| 文件 | 行号 | 修改前 | 修改后 | 状态 |
|------|------|--------|--------|------|
| `pjsua_call.c` | 651 | `opt->flag = PJSUA_CALL_INCLUDE_DISABLED_MEDIA` | `opt->flag = 0` | ✅ 已修改 |
| `pjsua_call.c` | 655 | `opt->vid_cnt = 1` | `opt->vid_cnt = 0` | ✅ 已修改 |
| `config_site.h` | 44 | (未设置) | `#define PJMEDIA_HAS_G711_CODEC 1` | ✅ 已添加 |
| `config_auto.h` | 36 | `#define PJMEDIA_HAS_G711_CODEC 0` | `#define PJMEDIA_HAS_G711_CODEC 1` | ✅ 已修改 |
| `os-auto.mak` | 66 | `AC_NO_G711_CODEC=1` | `AC_NO_G711_CODEC=0` | ✅ 已修改 |

### 修改1: pjsua_call.c (视频问题修复)

**文件**: `F:/0/pjproject-2.15.1/pjproject-2.15.1/pjsip/src/pjsua-lib/pjsua_call.c`

**第651行** - 移除禁用媒体标志：
```c
// 修改前
opt->flag = PJSUA_CALL_INCLUDE_DISABLED_MEDIA;

// 修改后
opt->flag = 0;  // CRITICAL FIX: Removed to prevent m=video 0 in SDP
```

**第655行** - 默认关闭视频：
```c
// 修改前
#if defined(PJMEDIA_HAS_VIDEO) && (PJMEDIA_HAS_VIDEO != 0)
    opt->vid_cnt = 1;  // Hardcoded to always include video

// 修改后
#if defined(PJMEDIA_HAS_VIDEO) && (PJMEDIA_HAS_VIDEO != 0)
    opt->vid_cnt = 0;  // CRITICAL FIX: Changed from 1 to 0 for audio-only default
```

**效果**: 新创建的呼叫默认为纯语音，不在SDP中包含视频流

### 修改2: config_site.h (用户配置)

**文件**: `F:/0/pjproject-2.15.1/pjproject-2.15.1/pjlib/include/pj/config_site.h`

**第44行** - 启用G.711编解码器：
```c
/* CRITICAL: Enable G.711 codec (PCMU/PCMA) - standard codec required by most SIP servers
 * This overrides config_auto.h which disables G.711 by default
 */
#define PJMEDIA_HAS_G711_CODEC          1
```

### 修改3: config_auto.h (自动生成配置)

**文件**: `F:/0/pjproject-2.15.1/pjproject-2.15.1/pjmedia/include/pjmedia/config_auto.h`

**第34-37行** - 启用G.711：
```c
/* G711 codec - ENABLED to fix 488 error (PCMU/PCMA required by FreeSWITCH) */
#ifndef PJMEDIA_HAS_G711_CODEC
#define PJMEDIA_HAS_G711_CODEC 1  // Changed from 0 to 1
#endif
```

### 修改4: os-auto.mak (根本原因修复)

**文件**: `F:/0/pjproject-2.15.1/pjproject-2.15.1/pjmedia/build/os-auto.mak`

**第66行** - 禁用G.711禁用标志：
```makefile
# 修改前
AC_NO_G711_CODEC=1

# 修改后
AC_NO_G711_CODEC=0    # CRITICAL FIX: Enable G.711 codec (PCMU/PCMA) - required by FreeSWITCH
```

**影响**: 由于第83-87行的逻辑，此修改阻止了 `-DPJMEDIA_HAS_G711_CODEC=0` 被添加到编译器命令行：
```makefile
ifeq ($(AC_NO_G711_CODEC),1)
export CFLAGS += -DPJMEDIA_HAS_G711_CODEC=0  # 现在不再执行
else
export CODEC_OBJS +=
endif
```

## 编译流程

### 1. 使用Qt MinGW GCC 11.2.0

```bash
export PATH='/c/Qt/Tools/mingw1120_64/bin:/c/Qt/6.5.3/mingw_64/bin:$PATH'
export CFLAGS='-I/c/openssl3/include -I/c/ffmpeg/include'
export LDFLAGS='-L/c/openssl3/lib64 -L/c/ffmpeg/lib'
```

**为什么**: MSYS2 GCC 15.2.0与PJSIP 2.15.1不兼容

### 2. 重新编译PJMEDIA库

```bash
cd /f/0/pjproject-2.15.1/pjproject-2.15.1/pjmedia/build
mingw32-make.exe clean
mingw32-make.exe -j8 lib
```

**验证G.711编译成功**:
```
gcc ... -c -o output/pjmedia-x86_64-w64-mingw32/g711.o ../src/pjmedia/g711.c
ar rv ../lib/libpjmedia-x86_64-w64-mingw32.a ... output/pjmedia-x86_64-w64-mingw32/g711.o ...
r - output/pjmedia-x86_64-w64-mingw32/g711.o  ← ✅ G.711已包含!
```

### 3. 编译PJSIP库

```bash
cd /f/0/pjproject-2.15.1/pjproject-2.15.1/pjsip/build
mingw32-make.exe lib
```

**结果**: 成功编译，包含vid_cnt=0修复

### 4. 复制库文件到应用程序

```bash
cp /f/0/pjproject-2.15.1/pjproject-2.15.1/*/lib/*.a \
   /e/2025/3_gongkongji/belt_control_system/libs/pjsip/
```

**已复制**: 31个库文件，包括：
- libpjmedia-codec-x86_64-w64-mingw32.a (包含G.711编解码器)
- libpjsua-x86_64-w64-mingw32.a (包含vid_cnt=0修复)
- libpjsip-x86_64-w64-mingw32.a
- libpjmedia-x86_64-w64-mingw32.a
- 第三方编解码器库 (GSM, iLBC, Speex等)

### 5. 重新编译应用程序

```bash
cd /e/2025/3_gongkongji/belt_control_system/build
cmake --build . --target belt_control_system -j4
```

**结果**: ✅ 成功
```
[100%] Linking CXX executable ..\..\bin_windows\belt_control_system.exe
[100%] Built target belt_control_system
```

## 预期效果

### 修复后的SDP格式

**之前 (13:10:00测试)**:
```sdp
m=audio 4000 RTP/AVP 96 3 120
a=rtpmap:96 iLBC/8000
a=rtpmap:3 GSM/8000
a=rtpmap:120 telephone-event/8000
```

**现在应该包含**:
```sdp
m=audio 4000 RTP/AVP 0 8 96 3 120
a=rtpmap:0 PCMU/8000      ← 新增: G.711 μ-law (最常用)
a=rtpmap:8 PCMA/8000      ← 新增: G.711 A-law
a=rtpmap:96 iLBC/8000
a=rtpmap:3 GSM/8000
a=rtpmap:120 telephone-event/8000
```

### FreeSWITCH响应

**之前**: `SIP/2.0 488 Not Acceptable Here`

**现在应该**: `SIP/2.0 200 OK`

## 测试验证步骤

### 第1步: 启动应用程序

```
E:\2025\3_gongkongji\belt_control_system\build\bin_windows\belt_control_system.exe
```

### 第2步: 登录SIP账户

1. 打开SIP设置页面
2. 输入FreeSWITCH服务器信息
3. 点击"登录"按钮
4. 等待注册成功

### 第3步: 发起测试呼叫

1. 拨打测试号码
2. 查看日志窗口中的SIP消息
3. 查找INVITE消息中的SDP部分

### 第4步: 验证SDP内容

在INVITE消息的SDP中，确认包含以下行：

```sdp
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
```

### 第5步: 验证呼叫成功

1. 检查FreeSWITCH返回 `200 OK` (不再是488)
2. 确认语音通话已建立
3. 测试双向语音通信

## 技术详解

### 为什么三层修改都必要？

1. **config_site.h** - 用户配置层，最佳实践
2. **config_auto.h** - 防止configure脚本覆盖
3. **os-auto.mak** - 根本原因，控制编译器命令行参数

如果只修改config_site.h，编译器命令行的`-DPJMEDIA_HAS_G711_CODEC=0`会覆盖头文件设置。

### G.711编解码器重要性

- **PCMU (μ-law)**: payload type 0, 北美标准
- **PCMA (A-law)**: payload type 8, 欧洲标准
- **采样率**: 8000 Hz
- **带宽**: 64 kbps
- **延迟**: 极低
- **兼容性**: 几乎所有SIP服务器都支持

G.711是SIP协议的**事实标准编解码器**，大多数服务器要求至少支持PCMU或PCMA之一。

### 视频功能保留

虽然默认呼叫为纯语音，但视频功能**仍然可用**：

1. **编译支持**: PJMEDIA_HAS_VIDEO = 1
2. **H.264编解码器**: 已编译FFmpeg支持
3. **启用方式**: 通过UI双按钮或re-INVITE

用户可以实现：
- **语音通话按钮**: 发起纯语音呼叫 (vid_cnt=0)
- **视频通话按钮**: 发起视频呼叫 (vid_cnt=1)

## 成功标志

✅ **已完成**:
1. 所有配置文件已修改 (4个文件)
2. PJMEDIA库已重新编译 (包含g711.o)
3. PJSIP库已重新编译 (包含vid_cnt=0修复)
4. 应用程序已重新编译 (belt_control_system.exe)
5. 所有库文件已复制到应用程序目录

⏳ **等待用户验证**:
1. SDP是否包含PCMU/PCMA
2. FreeSWITCH是否返回200 OK
3. 语音通话是否成功建立
4. (可选) 视频通话是否可用

## 如果仍有问题

### 如果SDP仍不包含PCMU/PCMA

1. 检查应用程序日志中的编解码器初始化消息
2. 确认使用的是新编译的belt_control_system.exe
3. 检查PJSIP日志级别是否足够详细

### 如果FreeSWITCH仍返回488

1. 检查FreeSWITCH配置是否支持PCMU/PCMA
2. 检查网络连接和防火墙设置
3. 捕获完整的SIP消息交换日志

### 如果语音通话无声音

1. 检查RTP端口是否可达
2. 检查音频设备是否正常工作
3. 查看PJSIP媒体传输日志

## 后续建议

1. **实现双按钮UI**: 语音通话 + 视频通话
2. **添加编解码器选择**: 让用户可以优先选择PCMU或PCMA
3. **记录详细日志**: 保存SIP消息到文件便于诊断
4. **错误处理**: 在UI中显示488等错误的友好提示

## 文件路径参考

### PJSIP源码目录
- **PJSIP**: `F:/0/pjproject-2.15.1/pjproject-2.15.1/`
- **配置文件**: `pjlib/include/pj/config_site.h`
- **呼叫处理**: `pjsip/src/pjsua-lib/pjsua_call.c`

### 应用程序目录
- **项目根目录**: `E:/2025/3_gongkongji/belt_control_system/`
- **PJSIP库**: `libs/pjsip/`
- **可执行文件**: `build/bin_windows/belt_control_system.exe`

---

**创建日期**: 2025-12-05
**作者**: Claude Code (Anthropic)
**状态**: ✅ 所有修复已完成，等待用户测试验证
**关键成就**: 成功解决G.711编解码器三层配置问题，应用程序已重新编译完成
