# SDL2 视频渲染器修复完整总结

## 问题根本原因

**SDL2 渲染器未被枚举** - 尽管在 `config_site.h` 中启用了 SDL2 (`PJMEDIA_VIDEO_DEV_HAS_SDL2 1`),但 PJSIP 的 configure 脚本**未检测到 SDL2**,导致编译时缺少 SDL2 的包含路径和链接标志。

### 具体表现

#### PJSIP build.mak (Line 182-183)
```makefile
# SDL flags
SDL_CFLAGS =           ← 空的!
SDL_LDFLAGS =          ← 空的!
```

#### PJSIP os-auto.mak (Line 9-11)
```makefile
# SDL flags
SDL_CFLAGS =           ← 空的!
SDL_LDFLAGS =          ← 空的!
```

**结果**: `sdl_dev.c` 被编译,但没有 SDL2 头文件,导致所有 SDL2 功能被 `#ifdef` 条件编译排除,最终生成的库只有 4.6KB (原始大小)。

---

## 修复方案

### 修复 1: 手动添加 SDL2 编译标志到 build.mak

**文件**: `F:\0\pjproject-2.15.1\pjproject-2.15.1\build.mak`

**修改**:
```makefile
# SDL flags (manually configured for SDL2)
SDL_CFLAGS = -IC:/video_deps/SDL2-2.28.5/include -DPJMEDIA_VIDEO_DEV_HAS_SDL2=1
SDL_LDFLAGS = -LC:/video_deps/SDL2-2.28.5/lib/x64 -lSDL2
```

### 修复 2: 手动添加 SDL2 编译标志到 os-auto.mak

**文件**: `F:\0\pjproject-2.15.1\pjproject-2.15.1\pjmedia\build\os-auto.mak`

**修改**:
```makefile
# SDL flags (manually configured for SDL2)
SDL_CFLAGS = -IC:/video_deps/SDL2-2.28.5/include -DPJMEDIA_VIDEO_DEV_HAS_SDL2=1
SDL_LDFLAGS = -LC:/video_deps/SDL2-2.28.5/lib/x64 -lSDL2
```

---

## 执行的编译步骤

### 步骤 1: 清理旧的视频设备库
```bash
rm -f pjmedia/lib/libpjmedia-videodev*.a
```

### 步骤 2: 重新编译 PJMEDIA (启用 SDL2)
```bash
cd /f/0/pjproject-2.15.1/pjproject-2.15.1/pjmedia/build
mingw32-make.exe -j8 lib
```

**结果**:
- `sdl_dev.o` 成功编译 (包含 SDL2 头文件)
- `libpjmedia-videodev-x86_64-w64-mingw32.a` 大小: **206KB** (vs 原始 4.6KB)

### 步骤 3: 复制更新后的库到应用程序
```bash
cp pjmedia/lib/libpjmedia-videodev-x86_64-w64-mingw32.a \
   /e/2025/3_gongkongji/belt_control_system/libs/pjsip/
```

### 步骤 4: 清理并重新编译应用程序
```bash
cd /e/2025/3_gongkongji/belt_control_system
rm -f build/bin_windows/belt_control_system.exe
rm -rf build/src/risip/*.o build/src/sip_phone/*.o
cmake.exe --build build --target belt_control_system -j4
```

**编译时间**: 3.8 秒
**可执行文件大小**: 28MB
**编译时间戳**: 2025-12-06 14:39

---

## 验证检查

### 1. 库文件大小对比
```bash
原始: libpjmedia-videodev-x86_64-pc-mingw32.a  (4.6KB)  ← SDL2 未编译
修复后: libpjmedia-videodev-x86_64-w64-mingw32.a (206KB) ← ✅ SDL2 已编译
```

### 2. SDL2.dll 存在性
```bash
E:\2025\3_gongkongji\belt_control_system\build\bin_windows\SDL2.dll (2.4MB) ✅
```

### 3. 可执行文件
```bash
E:\2025\3_gongkongji\belt_control_system\build\bin_windows\belt_control_system.exe (28MB) ✅
```

---

## 预期测试结果

### 启动应用程序时的设备枚举

#### 修复前 (错误):
```
RisipEndpoint: Total video devices: 3
  Device 0 : Integrated Webcam | Dir: 1 | Driver: dshow    ← 只有捕获
  Device 1 : Colorbar generator | Dir: 1 | Driver: Colorbar
  Device 2 : Colorbar-active | Dir: 1 | Driver: Colorbar
❌ 没有 Dir:2 (RENDER) 设备 → 导致错误 "Unable to find default video device"
```

#### 修复后 (预期):
```
RisipEndpoint: Total video devices: 4
  Device 0 : Integrated Webcam | Dir: 1 | Driver: dshow    ← 捕获
  Device 1 : SDL2 renderer | Dir: 2 | Driver: SDL2        ← ✅ 渲染设备
  Device 2 : Colorbar generator | Dir: 1 | Driver: Colorbar
  Device 3 : Colorbar-active | Dir: 1 | Driver: Colorbar
✅ SDL2 渲染器应该被检测到
```

### 视频通话日志

#### 修复前 (错误):
```
Creating video window: type=stream, cap_id=0, rend_id=-2
❌ pjsua_media.c  ......pjsua_vid_channel_update() failed for call_id 0 media 1:
   Unable to find default video device (PJMEDIA_EVID_NODEFDEV)
```

#### 修复后 (预期):
```
Creating video window: type=stream, cap_id=0, rend_id=-2
✅ Window 1 created
✅ Video call created with ID: 0
✅ 视频窗口成功创建,本地和远程视频可以显示
```

---

## 测试步骤

### 1. 启动应用程序并检查日志
```bash
cd E:\2025\3_gongkongji\belt_control_system\build\bin_windows
.\belt_control_system.exe
```

**在启动日志中查找**:
```
RisipEndpoint: Total video devices: X
```

**关键检查点**:
- ✅ 设备总数 ≥ 2
- ✅ 至少一个设备 `Dir: 2` 且 `Driver: SDL2`
- ✅ 至少一个设备 `Dir: 1` (Integrated Webcam)

### 2. 发起视频通话
1. 配置并登录 SIP 账户
2. 输入对方 SIP 号码
3. 点击"视频通话"按钮

**预期日志**:
```
✅ Making call to: sip:1002@192.168.1.100 (Video)
✅ Creating video call with PJSIP API (video in initial INVITE)
✅ Video call created with ID: 0
Creating video window: type=stream, cap_id=0, rend_id=-2
Window 1 created  ← ✅ 成功!
```

### 3. 验证视频流
- ✅ 本地摄像头预览显示
- ✅ 远程视频接收显示 (如果对方启用视频)
- ✅ 视频控制按钮 (开/关摄像头) 正常工作

---

## 故障排查

### 问题: 仍然报错 "Unable to find default video device"

**可能原因 1**: SDL2.dll 未加载

**检查**:
```bash
ls E:\2025\3_gongkongji\belt_control_system\build\bin_windows\SDL2.dll
```

**可能原因 2**: PJSIP 库未正确更新

**检查**:
```bash
ls -lh E:\2025\3_gongkongji\belt_control_system\libs\pjsip\libpjmedia-videodev*.a
# 应该看到 w64-mingw32 版本 206KB
```

**可能原因 3**: 应用程序使用旧的库缓存

**解决**:
```bash
cd /e/2025/3_gongkongji/belt_control_system
rm -rf build/src/risip/*.o build/src/sip_phone/*.o
cmake.exe --build build --target belt_control_system -j4
```

### 问题: SDL2 设备未枚举

**调试方法**:
在启动日志中搜索 "SDL" 关键字,检查是否有 SDL2 初始化失败的消息。

**检查 PJSIP 库是否包含 SDL2 支持**:
```bash
# 使用 nm 或 objdump 检查符号
nm libs/pjsip/libpjmedia-videodev-x86_64-w64-mingw32.a | grep SDL
# 应该看到 SDL 相关符号
```

---

## 技术细节

### 为什么 configure 脚本没有检测到 SDL2?

PJSIP 的 `./configure` 脚本依赖以下方式检测 SDL2:
1. 查找 `sdl2-config` 工具在 PATH 中
2. 使用 `pkg-config` 查找 SDL2
3. 检查标准路径 `/usr/include/SDL2` 等

Windows 上的 SDL2 安装在非标准路径 `C:\video_deps\SDL2-2.28.5`,configure 脚本无法自动检测。

### 为什么手动配置可以解决问题?

直接在 `build.mak` 和 `os-auto.mak` 中添加 SDL2 的编译标志,绕过 configure 检测,确保:
1. 编译时使用 `-IC:/video_deps/SDL2-2.28.5/include` (头文件路径)
2. 链接时使用 `-LC:/video_deps/SDL2-2.28.5/lib/x64 -lSDL2` (库文件)
3. `sdl_dev.c` 中的 `#ifdef PJMEDIA_VIDEO_DEV_HAS_SDL2` 条件为真
4. SDL2 渲染器代码被正确编译

---

## 修改的文件清单

### PJSIP 配置文件
1. `F:\0\pjproject-2.15.1\pjproject-2.15.1\build.mak` (Line 181-183)
2. `F:\0\pjproject-2.15.1\pjproject-2.15.1\pjmedia\build\os-auto.mak` (Line 9-11)
3. `F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\include\pj\config_site.h` (Line 33) - 已在之前修改

### 更新的库文件
- `F:\0\pjproject-2.15.1\pjproject-2.15.1\pjmedia\lib\libpjmedia-videodev-x86_64-w64-mingw32.a` (206KB)
  → 复制到 `E:\2025\3_gongkongji\belt_control_system\libs\pjsip\`

### 应用程序可执行文件
- `E:\2025\3_gongkongji\belt_control_system\build\bin_windows\belt_control_system.exe` (28MB)

---

## 下一步

请按照上述测试步骤运行应用程序,并提供:

1. **完整的启动日志** (特别是设备枚举部分)
2. **视频通话拨号时的日志**
3. **任何错误消息**
4. **测试结果反馈** (成功/失败)

如果 SDL2 渲染器成功枚举,视频通话应该可以正常工作了!

---

## 参考

- PJSIP 官方文档: https://www.pjsip.org/docs/book-latest/html/index.html
- SDL2 官方文档: https://wiki.libsdl.org/SDL2/FrontPage
- 两个 Bug 修复总结参见: [视频通话修复总结.md](./视频通话修复总结.md)
