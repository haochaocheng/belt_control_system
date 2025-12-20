# PJSIP 视频功能调研总结

## 调研时间
2025-12-03 16:35

## 当前状态分析

### 1. PJSIP 配置

**版本**: PJSIP 2.15.1
**源码位置**: `F:/0/pjproject-2.15.1/pjproject-2.15.1`
**库文件位置**: `libs/pjsip/`

**当前编译配置** (基于 CMakeLists.txt 分析):
```
✅ pjsua2 (C++ API)
✅ pjsua (高层 API)
✅ pjsip-ua (SIP 用户代理)
✅ pjmedia (媒体)
✅ pjmedia-codec (编解码器)
✅ pjmedia-audiodev (音频设备)
❌ pjmedia-videodev (视频设备) - 未链接！
```

**关键发现**:
- `src/risip/pjsip_stub/pjmedia_vid_dev_stub.c` - stub 文件存在，说明视频功能被禁用
- CMakeLists.txt 第198行只链接了 `pjmedia-audiodev`，没有 `pjmedia-videodev`
- **结论**: 当前 PJSIP 编译时禁用了视频支持

### 2. Risip SDK 视频支持

**文件分析**:

1. `src/risip/core/risipmedia.cpp`
   - 可能包含媒体管理代码
   - 需要检查是否有视频相关接口

2. `src/risip/pjsipwrapper/pjsipcall.cpp`
   - 包含通话管理代码
   - 注释中提到 "Audio/Video is ready to be transmitted"
   - 说明 Risip SDK 设计上支持视频，但可能未完整实现

**结论**: Risip SDK 有视频支持的框架，但需要启用 PJSIP 视频后才能使用

### 3. 依赖项状态

**已有的依赖**:
- ✅ Qt6 (Core, Gui, Network, Qml, Quick)
- ✅ PJSIP 2.15.1 (音频)

**缺失的依赖** (视频需要):
- ❌ FFmpeg (H.264 编解码)
- ❌ SDL2 (视频显示)
- ❌ x264 (H.264 编码器)

---

## 技术方案

### 方案 A: 完整实现 (推荐)

**优点**:
- 完全控制视频质量和性能
- 支持各种编解码器
- 长期可维护

**缺点**:
- 开发工作量大 (16-25天)
- 需要编译多个依赖库
- 调试复杂

**步骤**:
1. 编译 FFmpeg with x264
2. 编译或下载 SDL2
3. 重新编译 PJSIP 启用视频
4. 实现 C++ 视频管理类
5. 实现 QML 视频界面
6. 测试和优化

### 方案 B: 使用第三方视频库

**思路**: 将 PJSIP 音频通话与第三方视频流（如 WebRTC）分离

**优点**:
- 可以使用现成的视频库
- 开发工作量较小

**缺点**:
- 音视频不同步风险
- 集成复杂度高
- 不是标准 SIP 方案

**不推荐**: 违背 SIP 标准，不适合工控系统

### 方案 C: 最小化实现

**思路**: 只支持本地视频预览，不支持视频通话

**优点**:
- 开发工作量最小
- 风险低

**缺点**:
- 功能不完整
- 无法满足视频通话需求

**不推荐**: 不符合用户需求

---

## 推荐方案：方案 A (完整实现)

基于以下理由：
1. 用户明确要求"增加视频通话功能"
2. 项目已有 PJSIP 基础，扩展视频是自然延伸
3. 工控系统需要可靠性，使用标准 SIP 视频方案最佳
4. 长期来看，完整实现最容易维护

---

## 依赖库版本确定

### FFmpeg 6.0

**选择理由**:
- 稳定版本，广泛测试
- 支持所有需要的编解码器
- 与 PJSIP 2.15.1 兼容良好

**编译配置**:
```bash
./configure \
  --prefix=/c/ffmpeg \
  --toolchain=msvc \
  --enable-shared \
  --disable-static \
  --enable-gpl \
  --enable-libx264 \
  --enable-decoder=h264 \
  --enable-encoder=libx264 \
  --enable-parser=h264 \
  --disable-programs \
  --disable-doc \
  --disable-avdevice \
  --disable-postproc \
  --disable-avfilter
```

**产物**:
- `avcodec-60.dll` + `.lib`
- `avformat-60.dll` + `.lib`
- `avutil-58.dll` + `.lib`
- `swscale-7.dll` + `.lib`
- 头文件

### x264 (git master)

**选择理由**:
- H.264 编码器标准实现
- FFmpeg 依赖

**编译**:
```bash
./configure \
  --prefix=/c/x264 \
  --enable-shared \
  --enable-pic

make -j8
make install
```

### SDL2 2.28.5

**选择理由**:
- 最新稳定版
- 良好的 Windows 支持
- Qt 集成简单

**方案**: 使用预编译二进制
- 下载: https://github.com/libsdl-org/SDL/releases/tag/release-2.28.5
- 解压到 `C:/SDL2`

---

## PJSIP 重新编译方案

### 1. 修改 config_site.h

**文件**: `F:/0/pjproject-2.15.1/pjproject-2.15.1/pjlib/include/pj/config_site.h`

```c
/*
 * PJSIP 视频通话配置
 */

/* 启用视频支持 */
#define PJMEDIA_HAS_VIDEO               1

/* FFmpeg 视频编解码 */
#define PJMEDIA_HAS_FFMPEG_VID_CODEC    1
#define PJMEDIA_HAS_FFMPEG_CODEC_H264   1

/* SDL 视频设备 */
#define PJMEDIA_VIDEO_DEV_HAS_SDL       1
#define PJMEDIA_VIDEO_DEV_HAS_SDL2      1

/* 禁用不需要的音频编解码器以节省空间 */
#define PJMEDIA_HAS_SPEEX_CODEC         0
#define PJMEDIA_HAS_GSM_CODEC           0
#define PJMEDIA_HAS_ILBC_CODEC          0

/* 视频分辨率配置 */
#define PJMEDIA_VID_DEFAULT_WIDTH       640
#define PJMEDIA_VID_DEFAULT_HEIGHT      480
#define PJMEDIA_VID_DEFAULT_FPS         25

/* 性能优化 */
#define PJ_HAS_HIGH_RES_TIMER           1
#define PJMEDIA_USE_OLD_FFMPEG          0
```

### 2. 配置环境变量

```batch
set FFMPEG_ROOT=C:\ffmpeg
set SDL2_ROOT=C:\SDL2
set PATH=%FFMPEG_ROOT%\bin;%SDL2_ROOT%\bin;%PATH%
```

### 3. 运行配置脚本

**Windows (MinGW)**:
```bash
cd F:/0/pjproject-2.15.1/pjproject-2.15.1

./configure-mingw \
  --enable-video \
  --with-ffmpeg=$FFMPEG_ROOT \
  --with-sdl=$SDL2_ROOT \
  --disable-opencore-amr \
  --disable-silk \
  --disable-opus \
  --disable-speex-aec \
  --disable-g711-codec \
  --disable-g722-codec \
  --disable-g7221-codec
```

### 4. 编译

```bash
make dep
make -j8

# 检查生成的库
ls lib/ | grep videodev
# 应该看到: libpjmedia-videodev-x86_64-pc-mingw32.a
```

### 5. 复制库文件到项目

```bash
cp lib/*.a e:/2025/3_gongkongji/belt_control_system/libs/pjsip/
```

---

## 修改项目 CMakeLists.txt

### src/risip/CMakeLists.txt

**添加视频设备库链接** (在第198行后):

```cmake
# 媒体库
pjmedia-codec-x86_64-pc-mingw32   # Media Codecs
pjmedia-x86_64-pc-mingw32         # Media
pjmedia-audiodev-x86_64-pc-mingw32 # Audio Device
pjmedia-videodev-x86_64-pc-mingw32 # ✅ Video Device (新增)
pjsdp-x86_64-pc-mingw32           # SDP
```

**添加 FFmpeg 和 SDL2** (在 Windows 平台部分):

```cmake
# FFmpeg 库
if(EXISTS "C:/ffmpeg")
    target_include_directories(risip_sdk PUBLIC
        C:/ffmpeg/include
    )
    target_link_directories(risip_sdk PUBLIC
        C:/ffmpeg/lib
    )
    target_link_libraries(risip_sdk PUBLIC
        avcodec
        avformat
        avutil
        swscale
    )
endif()

# SDL2 库
if(EXISTS "C:/SDL2")
    target_include_directories(risip_sdk PUBLIC
        C:/SDL2/include
    )
    target_link_directories(risip_sdk PUBLIC
        C:/SDL2/lib/x64
    )
    target_link_libraries(risip_sdk PUBLIC
        SDL2
        SDL2main
    )
endif()
```

**移除 stub 文件** (第82行):

```cmake
# PJSIP Wrapper 源文件
set(RISIP_PJSIP_SOURCES
    pjsipwrapper/pjsipaccount.cpp
    pjsipwrapper/pjsipbuddy.cpp
    pjsipwrapper/pjsipcall.cpp
    pjsipwrapper/pjsipendpoint.cpp
    # ❌ 移除: pjsip_stub/pjmedia_vid_dev_stub.c
)
```

---

## 验证步骤

### 1. 验证 PJSIP 视频编译

```bash
cd F:/0/pjproject-2.15.1/pjproject-2.15.1

# 运行测试程序
./pjsua-x86_64-pc-mingw32 --video

# 应该看到类似输出:
# Video devices:
# 0: SDL2 video window (SDL2)
# 1: Integrated Camera (dshow)
```

### 2. 验证项目编译

```bash
cd e:/2025/3_gongkongji/belt_control_system
mkdir build && cd build
cmake ..
cmake --build . --config Release

# 检查链接的库
ldd bin_windows/belt_control_system.exe | grep -i video
# 应该看到 pjmedia-videodev
```

### 3. 验证 FFmpeg 集成

**创建测试程序**:
```cpp
#include <libavcodec/avcodec.h>
#include <iostream>

int main() {
    const AVCodec* codec = avcodec_find_encoder(AV_CODEC_ID_H264);
    if (codec) {
        std::cout << "H.264 encoder found: " << codec->name << std::endl;
        return 0;
    } else {
        std::cerr << "H.264 encoder NOT found!" << std::endl;
        return 1;
    }
}
```

---

## 风险和注意事项

### 1. 编译依赖复杂度 ⚠️

**风险**: FFmpeg 和 PJSIP 编译可能失败

**缓解**:
- 使用明确的版本号
- 提供详细的编译脚本
- 准备预编译的 fallback 方案

### 2. 库版本兼容性 ⚠️

**风险**: PJSIP 2.15.1 可能与最新 FFmpeg 不兼容

**缓解**:
- 使用 FFmpeg 6.0 (经过测试的稳定版)
- 如果不兼容,降级到 FFmpeg 5.1

### 3. 性能问题 ⚠️

**风险**: 视频编解码占用大量 CPU

**缓解**:
- 默认使用 640x480 分辨率
- 使用 "fast" 编码预设
- 考虑硬件加速 (未来优化)

### 4. Windows vs AArch64 差异 ⚠️

**风险**: 两个平台行为不一致

**缓解**:
- 先在 Windows 完整实现和测试
- 抽象平台差异代码
- 为 AArch64 预留硬件加速接口

---

## 下一步行动

### 立即执行

1. ✅ 完成调研报告 (本文档)
2. [ ] 下载 FFmpeg 6.0 源码
3. [ ] 下载 SDL2 2.28.5 预编译库
4. [ ] 安装 MSYS2 (用于编译 FFmpeg)
5. [ ] 准备 x264 源码

### 准备阶段 2

创建编译脚本:
- `scripts/build_ffmpeg_windows.sh`
- `scripts/build_pjsip_windows.sh`
- `scripts/setup_video_dependencies.bat`

---

## 估算时间表

| 任务 | 预计时间 | 风险等级 |
|-----|---------|---------|
| 编译 x264 | 2小时 | 低 |
| 编译 FFmpeg | 4小时 | 中 |
| 配置 SDL2 | 1小时 | 低 |
| 重新编译 PJSIP | 4小时 | 中 |
| 修改 CMakeLists.txt | 2小时 | 低 |
| 验证编译 | 2小时 | 中 |
| **小计 (阶段2+3)** | **15小时** | |

---

## 参考资源

### PJSIP 官方文档

- 视频支持: https://docs.pjsip.org/en/latest/specific-guides/video_users_guide.html
- 编译选项: https://docs.pjsip.org/en/latest/get-started/general.html

### FFmpeg 文档

- 编译指南: https://trac.ffmpeg.org/wiki/CompilationGuide
- libx264: https://trac.ffmpeg.org/wiki/Encode/H.264

### SDL2 文档

- 官网: https://www.libsdl.org/
- GitHub: https://github.com/libsdl-org/SDL

### 示例代码

- pjsip-apps/vidgui: PJSIP 官方视频示例
- 位置: `F:/0/pjproject-2.15.1/pjproject-2.15.1/pjsip-apps/src/vidgui/`

---

**状态**: ✅ 调研完成
**下一阶段**: 阶段 2 - 编译依赖库
**负责人**: Claude (AI Assistant)
**审核**: 待用户确认
