# PJSIP 重新编译指南 - H264 帧率修复

## 修改内容

**文件**: `F:\0\pjproject-2.15.1\pjproject-2.15.1\pjmedia\src\pjmedia-codec\ffmpeg_vid_codecs.c`

**修改位置**: 第 298 行

**修改内容**:
```c
// 修改前:
{720, 480},     {15, 1},        256000, 256000,

// 修改后:
{720, 480},     {25, 1},        256000, 256000,
```

**目的**: 将 H264 编码器默认发送帧率从 15fps 提升到 25fps，解决对方主叫本机视频时的卡顿问题。

---

## 重新编译步骤

### 步骤 1: 打开 MinGW64 终端

1. 打开 MSYS2 MinGW 64-bit 终端
   - 通常在开始菜单中搜索 "MSYS2 MinGW 64-bit"
   - 或运行 `C:\msys64\mingw64.exe`

2. 确认编译器可用:
   ```bash
   gcc --version
   ```
   应该显示 MinGW-w64 GCC 版本信息

### 步骤 2: 进入 PJSIP 源码目录

```bash
cd /f/0/pjproject-2.15.1/pjproject-2.15.1
```

### 步骤 3: 清理之前的编译（可选但推荐）

```bash
make clean
```

如果遇到错误，可以忽略（可能是首次编译或已经清理过）。

### 步骤 4: 重新配置（如果需要）

如果你之前没有运行过 configure，或者想确保配置正确：

```bash
./configure --prefix=/f/0/pjproject-2.15.1/pjproject-2.15.1 \
            --enable-shared \
            --disable-static \
            --with-ffmpeg=/c/ffmpeg
```

**注意**:
- 如果你的 FFmpeg 安装在其他位置，请修改 `--with-ffmpeg` 路径
- 如果不需要 FFmpeg H264 支持，可以移除 `--with-ffmpeg` 选项

### 步骤 5: 编译 PJSIP

```bash
make dep && make
```

**说明**:
- `make dep` - 重新生成依赖关系
- `make` - 编译所有库

**预计时间**: 5-15 分钟（取决于 CPU 性能）

**观察输出**:
```
Compiling pjmedia-codec/ffmpeg_vid_codecs.c ...
...
[大量编译输出]
...
```

### 步骤 6: 确认编译成功

编译完成后，检查输出目录：

```bash
ls -lh pjlib/lib/
ls -lh pjlib-util/lib/
ls -lh pjmedia/lib/
ls -lh pjsip/lib/
ls -lh pjsua/lib/
```

应该看到类似这些文件（可能是 `.a` 或 `.dll.a` 格式）：
- `libpj-x86_64-w64-mingw32.a`
- `libpjmedia-x86_64-w64-mingw32.a`
- `libpjmedia-codec-x86_64-w64-mingw32.a` ← **关键：包含 H264 编码器**
- `libpjsip-x86_64-w64-mingw32.a`
- `libpjsua-x86_64-w64-mingw32.a`
- 等等...

### 步骤 7: 复制新库到项目

```bash
# 返回项目根目录
cd /e/2025/3_gongkongji/belt_control_system

# 备份旧库（可选但推荐）
mkdir -p libs/pjsip_backup_old
cp libs/pjsip/*.a libs/pjsip_backup_old/

# 复制新编译的库
cp /f/0/pjproject-2.15.1/pjproject-2.15.1/pjlib/lib/*.a libs/pjsip/
cp /f/0/pjproject-2.15.1/pjproject-2.15.1/pjlib-util/lib/*.a libs/pjsip/
cp /f/0/pjproject-2.15.1/pjproject-2.15.1/pjmedia/lib/*.a libs/pjsip/
cp /f/0/pjproject-2.15.1/pjproject-2.15.1/pjnath/lib/*.a libs/pjsip/
cp /f/0/pjproject-2.15.1/pjproject-2.15.1/pjsip/lib/*.a libs/pjsip/

# 列出复制的文件，确认日期是今天
ls -lh libs/pjsip/*.a
```

---

## 重新编译项目

### 步骤 8: 清理并重新编译应用

回到 Windows CMD 或 PowerShell：

```cmd
cd E:\2025\3_gongkongji\belt_control_system

# 清理旧的编译输出
cmake.exe --build build --target clean

# 重新编译
cmake.exe --build build --target belt_control_system -j4
```

### 步骤 9: 测试

1. 运行应用:
   ```cmd
   build\bin_windows\belt_control_system.exe
   ```

2. 让对方发起视频通话

3. 接听视频通话

4. **关键检查点**:

   a) 查看启动日志，确认编码器配置:
   ```
   📹 Configuring H264 encoder parameters...
     Current H264 encoder FPS: 25 / 1  ← 应该显示 25，不是 15
   ```

   b) 通话结束后，查看统计信息:
   ```
   TX pt=100, size=720x480, fps=25.00  ← 应该是 25.00，不是 15.00
   RX pt=100, size=640x360, fps=32.xx
   ```

   c) 询问对方：看到的本机视频是否更流畅？

---

## 故障排除

### 问题 1: 编译失败 - "ffmpeg not found"

**症状**:
```
checking for ffmpeg... no
```

**解决方案**:
1. 确认 FFmpeg 安装路径
2. 重新运行 configure 时指定正确的 FFmpeg 路径:
   ```bash
   ./configure --with-ffmpeg=/c/ffmpeg
   ```

### 问题 2: 编译失败 - "undefined reference to..."

**症状**:
```
undefined reference to `av_frame_alloc'
```

**解决方案**:
1. 确保链接了 FFmpeg 库
2. 检查 `libs/pjsip/` 目录中是否有 FFmpeg 相关库
3. 可能需要手动添加 FFmpeg 库到链接器

### 问题 3: 应用运行后仍然显示 15fps

**可能原因**:
1. 新库没有正确复制到项目
2. 旧的 DLL 缓存

**解决方案**:
```cmd
# 检查库文件日期
dir libs\pjsip\*.a

# 如果日期不是今天，重新复制
# 完全清理并重新编译
cmake.exe --build build --target clean
del /Q build\bin_windows\belt_control_system.exe
cmake.exe --build build --target belt_control_system -j4
```

### 问题 4: 编译后应用崩溃

**可能原因**: PJSIP 库版本不匹配

**解决方案**:
1. 确保所有 PJSIP 库都是新编译的
2. 检查是否混用了旧库和新库
3. 重新复制所有库文件（步骤 7）

---

## 预期效果

### 修复前:
- TX fps: 15.00
- 对方看本机视频：一帧一帧，卡顿
- 本机看自己预览：不流畅

### 修复后:
- TX fps: 25.00
- 对方看本机视频：流畅
- 本机看自己预览：流畅
- 与接收帧率（32fps）更匹配

---

## 技术说明

### 为什么需要修改源码？

PJSIP 的视频编码器默认参数是在编译时通过 `codec_desc` 结构体数组定义的。这些参数在库初始化时被读取并用作默认值。

**Runtime API 的局限**:
- `pjsua_vid_codec_set_param()` 可以修改已经创建的编码器实例
- 但不能修改用于创建新实例的默认模板
- 每次建立新的视频通话时，都会从默认模板创建新的编码器实例

**Source-level 修改的优势**:
- 修改默认模板本身
- 所有新创建的编码器实例都使用新的默认值
- 不需要在每次通话时手动配置

### 相关代码结构

```c
// ffmpeg_vid_codecs.c
static ffmpeg_codec_desc codec_desc[] = {
    #if PJMEDIA_HAS_FFMPEG_CODEC_H264
    {
        {PJMEDIA_FORMAT_H264, ...},
        0,
        {720, 480},     // 分辨率 (width, height)
        {25, 1},        // 帧率 (num, denum) = 25/1 = 25fps ← 这里
        256000,         // 平均比特率
        256000,         // 最大比特率
        ...
    },
    #endif
};
```

这个数组在 `pjmedia_codec_ffmpeg_vid_init()` 中被读取，用于初始化 H264 编码器工厂。

---

## 相关文件

- **PJSIP 源码** (已修改):
  - `F:\0\pjproject-2.15.1\pjproject-2.15.1\pjmedia\src\pjmedia-codec\ffmpeg_vid_codecs.c:298`

- **项目源码** (辅助配置，已修改但非关键):
  - [VideoCallManager.cpp:72-109](src/sip_phone/VideoCallManager.cpp#L72-L109) - Runtime 配置（补充）
  - [risipendpoint.cpp:627-664](src/risip/core/risipendpoint.cpp#L627-L664) - Endpoint 初始化配置
  - [RemoteVideoManager.cpp:145-149](src/sip_phone/RemoteVideoManager.cpp#L145-L149) - 视频端口优化

- **文档**:
  - [视频卡顿问题_帧率优化方案.md](视频卡顿问题_帧率优化方案.md) - 详细分析
  - [视频卡顿问题修复_RemoteVideoManager优化.md](视频卡顿问题修复_RemoteVideoManager优化.md) - RemoteVideoManager 优化

---

## 下一步优化（可选）

如果 25fps 仍然不够流畅，可以考虑：

1. **提升到 30fps**:
   - 修改同一位置为 `{30, 1}`
   - 重新编译
   - 代价：带宽增加约 20%

2. **同时优化 VP8/VP9**:
   - VP8: line 312
   - VP9: line 324
   - 如果使用这些编码器，也可以提升到 25fps

3. **调整分辨率**:
   - 降低分辨率可以在相同带宽下提高帧率
   - 例如: `{640, 480}` 或 `{640, 360}`

---

祝编译顺利！完成后应该能看到明显的视频流畅度改善。🎉
