# 阶段 2-3 执行指南：编译视频依赖库

## 概述

本指南将引导您完成视频通话功能所需的所有依赖库的下载和编译。

**预计时间**: 4-6 小时（取决于机器性能）

**状态**: ⏳ 待执行

---

## 前置要求

### 1. 安装 MSYS2

1. 下载 MSYS2 安装程序: https://www.msys2.org/
2. 运行安装程序，安装到 `C:\msys64`
3. 安装完成后，运行 MSYS2 终端
4. 更新 MSYS2:
   ```bash
   pacman -Syu
   ```
   关闭终端，重新打开，再次运行:
   ```bash
   pacman -Syu
   ```

5. 安装开发工具:
   ```bash
   pacman -S base-devel mingw-w64-x86_64-toolchain
   pacman -S yasm nasm git curl
   ```

### 2. 验证工具

在 MSYS2 MinGW 64-bit 终端中运行:
```bash
gcc --version
make --version
yasm --version
git --version
```

所有工具都应该显示版本信息。

---

## 步骤 1: 下载依赖库

**执行文件**: `scripts\setup_video_dependencies_windows.bat`

### 执行

1. 以**管理员身份**打开命令提示符 (CMD)
2. 进入项目目录:
   ```cmd
   cd /d e:\2025\3_gongkongji\belt_control_system
   ```
3. 运行下载脚本:
   ```cmd
   scripts\setup_video_dependencies_windows.bat
   ```

### 脚本功能

该脚本将自动:
1. 创建 `C:\video_deps` 目录
2. 下载 x264 源码 (git clone)
3. 下载 FFmpeg 6.0 源码 (curl)
4. 下载 SDL2 2.28.5 预编译二进制 (curl)
5. 检查 MSYS2 安装

### 预期输出

```
========================================
Download Summary
========================================
Dependencies root: C:\video_deps

Downloaded components:
  [OK] x264 source
  [OK] FFmpeg 6.0 source
  [OK] SDL2 2.28.5 binaries

========================================
Next Steps
========================================
1. Ensure MSYS2 is installed and updated
2. Run: scripts\build_x264_windows.sh (in MSYS2 shell)
3. Run: scripts\build_ffmpeg_windows.sh (in MSYS2 shell)
4. Run: scripts\build_pjsip_windows.sh (in MSYS2 shell)
```

### 如果下载失败

如果某个组件下载失败，可以手动下载:

**x264**:
```bash
# 在 MSYS2 终端中
cd /c/video_deps
git clone --depth 1 https://code.videolan.org/videolan/x264.git x264_src
cd x264_src && git checkout stable
```

**FFmpeg 6.0**:
- 下载: https://ffmpeg.org/releases/ffmpeg-6.0.tar.xz
- 解压到: `C:\video_deps\ffmpeg-6.0`

**SDL2 2.28.5**:
- 下载: https://github.com/libsdl-org/SDL/releases/download/release-2.28.5/SDL2-devel-2.28.5-VC.zip
- 解压到: `C:\video_deps\SDL2-2.28.5`

---

## 步骤 2: 编译 x264

**执行文件**: `scripts\build_x264_windows.sh`

**预计时间**: 10-15 分钟

### 执行

1. 打开 **MSYS2 MinGW 64-bit** 终端
2. 进入项目目录:
   ```bash
   cd /e/2025/3_gongkongji/belt_control_system
   ```
3. 运行编译脚本:
   ```bash
   bash scripts/build_x264_windows.sh
   ```

### 编译过程

脚本将:
1. 进入 x264 源码目录
2. 配置编译选项 (shared + static, PIC enabled)
3. 编译 x264 (使用 8 个线程)
4. 安装到 `C:\x264`

### 预期输出

```
========================================
x264 Build SUCCESS
========================================
Installation directory: /c/x264
Library: /c/x264/lib/libx264.dll.a
Headers: /c/x264/include/x264.h

Next step: Run build_ffmpeg_windows.sh
```

### 验证

检查 x264 是否正确安装:
```bash
ls -lh /c/x264/lib/
ls -lh /c/x264/include/
```

应该看到:
- `libx264.dll.a` (静态链接库)
- `libx264-*.dll` (动态库)
- `x264.h` (头文件)

---

## 步骤 3: 编译 FFmpeg

**执行文件**: `scripts\build_ffmpeg_windows.sh`

**预计时间**: 20-30 分钟

### 执行

在同一个 MSYS2 终端中:
```bash
bash scripts/build_ffmpeg_windows.sh
```

### 编译过程

脚本将:
1. 检查 x264 是否已安装
2. 进入 FFmpeg 6.0 源码目录
3. 配置编译选项:
   - 启用 shared libraries
   - 启用 GPL 和 libx264
   - 启用 H.264 decoder/encoder
   - 禁用不需要的组件 (programs, docs, filters)
4. 编译 FFmpeg (使用 8 个线程)
5. 安装到 `C:\ffmpeg`

### 预期输出

```
========================================
FFmpeg Build SUCCESS
========================================
Installation directory: /c/ffmpeg

Libraries:
avcodec-60.dll
avformat-60.dll
avutil-58.dll
swscale-7.dll

Headers:
/c/ffmpeg/include/libavcodec
/c/ffmpeg/include/libavformat
/c/ffmpeg/include/libavutil
/c/ffmpeg/include/libswscale

[OK] H.264 codec found

Next step: Run build_pjsip_windows.sh
```

### 验证

检查 FFmpeg 是否正确安装:
```bash
ls -lh /c/ffmpeg/bin/*.dll
ls -d /c/ffmpeg/include/libav*
```

测试 H.264 编解码器:
```bash
/c/ffmpeg/bin/ffmpeg.exe -codecs | grep h264
```

应该看到 H.264 编解码器列表。

---

## 步骤 4: 重新编译 PJSIP

**执行文件**: `scripts\build_pjsip_windows.sh`

**预计时间**: 20-30 分钟

### 执行

在同一个 MSYS2 终端中:
```bash
bash scripts/build_pjsip_windows.sh
```

### 编译过程

脚本将:
1. 检查 FFmpeg 和 SDL2 是否已准备好
2. 备份现有的 `config_site.h`
3. 创建新的 `config_site.h` 启用视频支持:
   - `PJMEDIA_HAS_VIDEO = 1`
   - `PJMEDIA_HAS_FFMPEG_VID_CODEC = 1`
   - `PJMEDIA_VIDEO_DEV_HAS_SDL = 1`
4. 配置 PJSIP:
   - `--enable-video`
   - `--with-ffmpeg=/c/ffmpeg`
   - `--with-sdl=/c/video_deps/SDL2-2.28.5`
5. 编译 PJSIP (使用 8 个线程)
6. 将所有库文件复制到项目 `libs/pjsip/` 目录

### 预期输出

```
========================================
PJSIP Build Complete
========================================
PJSIP source: /f/0/pjproject-2.15.1/pjproject-2.15.1
Video device library: lib/libpjmedia-videodev-x86_64-pc-mingw32.a
Libraries copied to: /e/2025/3_gongkongji/belt_control_system/libs/pjsip

Next steps:
1. Update project CMakeLists.txt to link pjmedia-videodev
2. Add FFmpeg and SDL2 libraries to CMakeLists.txt
3. Remove stub file: src/risip/pjsip_stub/pjmedia_vid_dev_stub.c
4. Implement VideoCallManager C++ class
```

### 验证

检查 PJSIP 视频库是否已编译:
```bash
ls -lh /f/0/pjproject-2.15.1/pjproject-2.15.1/lib/ | grep videodev
```

应该看到:
- `libpjmedia-videodev-x86_64-pc-mingw32.a`

检查库文件是否已复制到项目:
```bash
ls -lh /e/2025/3_gongkongji/belt_control_system/libs/pjsip/ | grep videodev
```

---

## 故障排除

### 问题 1: MSYS2 找不到 gcc

**错误**: `bash: gcc: command not found`

**解决**:
1. 确保打开的是 **MSYS2 MinGW 64-bit** 终端（不是 MSYS2 MSYS 终端）
2. 重新安装工具链:
   ```bash
   pacman -S mingw-w64-x86_64-toolchain
   ```

### 问题 2: x264 configure 失败

**错误**: `./configure: No such file or directory`

**解决**:
1. 检查 x264 源码是否完整下载:
   ```bash
   ls -lh /c/video_deps/x264_src/
   ```
2. 如果目录为空，重新 clone:
   ```bash
   cd /c/video_deps
   rm -rf x264_src
   git clone https://code.videolan.org/videolan/x264.git x264_src
   cd x264_src && git checkout stable
   ```

### 问题 3: FFmpeg 编译错误 - nasm not found

**错误**: `ERROR: nasm/yasm not found`

**解决**:
```bash
pacman -S nasm yasm
```

### 问题 4: PJSIP 编译错误 - FFmpeg not found

**错误**: `configure: error: FFmpeg not found`

**解决**:
1. 检查 FFmpeg 是否正确安装:
   ```bash
   ls -d /c/ffmpeg
   ```
2. 手动设置环境变量:
   ```bash
   export CFLAGS="-I/c/ffmpeg/include"
   export LDFLAGS="-L/c/ffmpeg/lib"
   ```
3. 重新运行 `build_pjsip_windows.sh`

### 问题 5: PJSIP 编译成功但没有 videodev 库

**症状**: 编译完成但找不到 `libpjmedia-videodev*.a`

**解决**:
1. 检查 `config_site.h`:
   ```bash
   cat /f/0/pjproject-2.15.1/pjproject-2.15.1/pjlib/include/pj/config_site.h
   ```
   应该包含:
   ```c
   #define PJMEDIA_HAS_VIDEO 1
   ```
2. 检查 configure 输出:
   ```bash
   cd /f/0/pjproject-2.15.1/pjproject-2.15.1
   ./configure --enable-video --with-ffmpeg=/c/ffmpeg --with-sdl=/c/video_deps/SDL2-2.28.5
   ```
   查找输出中是否有:
   ```
   Video support: enabled
   FFmpeg: yes
   SDL: yes
   ```
3. 如果仍然失败，手动检查依赖:
   ```bash
   ls -lh /c/ffmpeg/lib/
   ls -lh /c/video_deps/SDL2-2.28.5/lib/x64/
   ```

---

## 进度检查清单

完成每个步骤后，在这里打勾：

- [ ] ✅ 安装并配置 MSYS2
- [ ] ✅ 运行 `setup_video_dependencies_windows.bat` - 下载所有依赖
- [ ] ✅ 运行 `build_x264_windows.sh` - 编译 x264
- [ ] ✅ 运行 `build_ffmpeg_windows.sh` - 编译 FFmpeg
- [ ] ✅ 运行 `build_pjsip_windows.sh` - 重新编译 PJSIP
- [ ] ✅ 验证所有库文件已复制到 `libs/pjsip/`

---

## 下一步

完成阶段 2-3 后，继续：

**阶段 4**: 修改项目 CMakeLists.txt
- 添加 `pjmedia-videodev` 链接
- 添加 FFmpeg 库链接
- 添加 SDL2 库链接
- 移除 stub 文件

详见 `VIDEO_RESEARCH_SUMMARY.md` 的 "修改项目 CMakeLists.txt" 章节。

---

## 时间估算

| 任务 | 预计时间 | 实际时间 |
|-----|---------|---------|
| 安装 MSYS2 | 30 分钟 | |
| 下载依赖 | 30 分钟 | |
| 编译 x264 | 15 分钟 | |
| 编译 FFmpeg | 30 分钟 | |
| 编译 PJSIP | 30 分钟 | |
| **总计** | **~2.5 小时** | |

实际时间取决于网络速度和机器性能。

---

**状态**: ⏳ 待执行
**最后更新**: 2025-12-03
**负责人**: Claude (AI Assistant)
**执行者**: 用户（跟随脚本执行）
