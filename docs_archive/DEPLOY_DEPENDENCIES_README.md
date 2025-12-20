# 运行时依赖自动部署说明

## 问题背景
使用 `rebuild.bat` 清理重建项目时会删除 `build` 目录，导致所有运行时依赖DLL丢失，程序无法运行。

## 解决方案
创建了自动部署脚本 `deploy_dependencies.bat`，在构建完成后自动复制所有必需的依赖文件。

## 使用方法

### 方式1：使用 build.bat（推荐）
```cmd
build.bat
```
- 会自动构建项目
- **构建成功后自动调用 deploy_dependencies.bat 部署依赖**
- 完成后自动运行程序

### 方式2：使用 rebuild.bat（清理重建）
```cmd
rebuild.bat
```
- 删除 build 目录
- 调用 build.bat 重新构建
- **自动部署所有依赖**
- 完成后运行程序

### 方式3：手动部署（仅在需要时）
```cmd
deploy_dependencies.bat
```
- 单独运行此脚本手动部署依赖
- 用于构建完成但忘记部署依赖的情况

## 部署的依赖文件

### 1. FFmpeg 视频库 (6个DLL)
- `avcodec-58.dll` (13MB) - 视频编解码器
- `avformat-58.dll` (2.4MB) - 视频格式处理
- `avutil-56.dll` (615KB) - 视频工具库
- `swresample-3.dll` (92KB) - 音频重采样
- `swscale-5.dll` (447KB) - 视频缩放
- `libx264-165.dll` (1.9MB) - H.264编码器

### 2. SDL2 视频设备库
- `SDL2.dll` (2.4MB) - 视频输入/输出设备

### 3. MinGW 运行时库 (MSYS2 MinGW64)
- `libwinpthread-1.dll` (64KB) - 线程库
- `libgcc_s_seh-1.dll` (147KB) - GCC运行时
- `libstdc++-6.dll` (2.4MB) - C++标准库
- `libiconv-2.dll` - 字符编码转换

### 4. Qt 依赖 (~64个DLL)
- Qt6Core, Qt6Gui, Qt6Quick, Qt6Network等
- 通过 `windeployqt` 自动识别和部署

### 5. QML 模块
- QtQuick, Qt5Compat, QtMultimedia, QtQuick3D等
- 部署到 `build\bin_windows\qml\` 目录

## 验证部署结果

脚本会自动验证以下内容：
- ✓ 关键DLL是否存在
- ✓ QML模块是否完整
- ✓ 统计DLL和QML模块数量

## 自定义依赖路径

如果你的依赖库安装在不同位置，编辑 `deploy_dependencies.bat` 修改以下变量：
```batch
set "QT_BIN=C:\Qt\6.5.3\mingw_64\bin"
set "MSYS2_BIN=C:\msys64\mingw64\bin"
set "FFMPEG_BIN=C:\ffmpeg\bin"
set "SDL2_LIB=C:\video_deps\SDL2-2.28.5\lib\x64"
```

## 常见问题

### Q: 运行程序时提示"找不到 XXX.dll"？
**A:** 运行 `deploy_dependencies.bat` 重新部署依赖。

### Q: rebuild.bat 后程序无法运行？
**A:** 检查 build.bat 是否包含自动部署调用（第78-84行）。

### Q: 如何检查缺失哪些DLL？
**A:** 运行以下命令：
```bash
cd build\bin_windows
ldd belt_control_system.exe | grep "not found"
```

### Q: windeployqt 执行失败？
**A:**
1. 检查 Qt 路径是否正确 (`C:\Qt\6.5.3\mingw_64`)
2. 检查 QML 源码路径是否正确 (`src\qml`)
3. 手动运行 windeployqt 查看详细错误信息

## 技术细节

### 为什么需要 MSYS2 MinGW64 运行时？
FFmpeg DLL 是用 MSYS2 MinGW64 编译的，依赖 `clock_gettime64` 函数，因此需要使用 MSYS2 MinGW64 的运行时库，而不是 Qt 自带的 MinGW 运行时。

### 为什么需要 libiconv-2.dll？
某些 FFmpeg 或 SDL2 功能需要字符编码转换，依赖 libiconv 库。

### deploy_dependencies.bat vs windeployqt
- `windeployqt` 只部署 Qt 相关依赖
- `deploy_dependencies.bat` 部署所有依赖（Qt + FFmpeg + SDL2 + MinGW运行时）

## 更新日志

### 2025-12-05
- 创建 `deploy_dependencies.bat` 自动部署脚本
- 集成到 `build.bat` 实现自动化部署
- 添加 `libiconv-2.dll` 到部署列表
- 添加验证步骤检查关键DLL

---

**重要提示**: 每次使用 `rebuild.bat` 后，必须确保运行时依赖已正确部署，否则程序无法启动！
