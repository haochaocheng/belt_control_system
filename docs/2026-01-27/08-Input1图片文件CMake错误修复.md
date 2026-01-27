# Input1 图片文件 CMake 错误修复

**日期**: 2026-01-27
**问题**: CMake 报错找不到 Input1/Input1Content/images/ 下的图片文件

## 问题描述

编译时出现大量 CMake 错误：

```
CMake Error at /opt/qt-raspi/lib/cmake/Qt6Qml/Qt6QmlMacros.cmake:2037 (file):
  file COPY_FILE failed to copy

      /workspace/src/qml/Input1/Input1Content/images/GSC10.svg

  to

      /workspace/build_rk3588/src/qml/Input1/Input1Content/images/GSC10.svg

  because: No such file or directory (output)
```

类似错误还包括：
- `head_Top-left_straight_line.png`
- `head_Top-left_straight_line2.png`
- `head_Top-right_straight_line.png`
- `head_Top-right_straight_line2.png`
- `IN_Data_OK.png`
- `middle_top_status_bg.png`
- `path_1.svg`
- `path_2.svg`
- `path.svg`

## 根本原因

用户执行了以下操作：
1. 将 `.tar`, `.zip`, `.7z` 压缩包文件剪切到 `F:\1\3.7.8`
2. 执行了 `.\push-commits-one-by-one.ps1` 脚本
3. 之后编译失败

**实际情况**：
- 文件实际上都存在于 `src/qml/Input1/Input1Content/images/` 目录
- `git status` 显示工作树干净
- CMakeLists.txt 中正确引用了这些文件

**问题根源**：
- **CMake 构建缓存损坏**
- 可能是 git 操作或文件移动导致 CMake 缓存状态不一致

## 解决方案

### 方案 1: 清除 CMake 缓存（推荐）

```powershell
# 删除构建缓存
Remove-Item -Recurse -Force "build_rk3588" -ErrorAction SilentlyContinue

# 重新编译
.\build-ubuntu24-apt.ps1 188
```

### 方案 2: 清除 Docker 容器缓存

```powershell
# 删除 Docker 容器和镜像
docker rm -f $(docker ps -aq) 2>$null
docker rmi belt-control-fixed:latest 2>$null

# 重新编译
.\build-ubuntu24-apt.ps1 188
```

### 方案 3: 检查文件是否真的存在

```powershell
# 检查文件
Get-ChildItem "src\qml\Input1\Input1Content\images\GSC10.svg"
Get-ChildItem "src\qml\Input1\Input1Content\images\*.png"
Get-ChildItem "src\qml\Input1\Input1Content\images\*.svg"
```

## 验证

文件确实存在：
```
✅ src/qml/Input1/Input1Content/images/GSC10.svg
✅ src/qml/Input1/Input1Content/images/15823432333.svg
✅ src/qml/Input1/Input1Content/images/current_value.svg
✅ src/qml/Input1/Input1Content/images/fault.svg
... (共 28 个 SVG 文件)
```

CMakeLists.txt 正确引用：
```cmake
# Line 152
Input1/Input1Content/images/GSC10.svg
```

## 技术要点

1. **CMake 缓存机制**：
   - CMake 会缓存文件路径和状态
   - 文件移动或 git 操作可能导致缓存失效
   - 需要清除 `build_rk3588` 目录重新生成

2. **Qt QML 资源系统**：
   - QML 文件通过 `qt_add_qml_module` 注册
   - 图片文件作为 RESOURCES 添加
   - CMake 会复制这些文件到构建目录

3. **Docker 构建环境**：
   - 容器内的构建目录是 `/workspace/build_rk3588`
   - 文件复制失败可能是容器缓存问题

## 相关问题

- FIX 100.300.45: 修复了 SherpaOnnxTTS 编译错误
- FIX 100.300.43: 修复了 CMakeLists.txt 孤立文件列表问题

## 状态

⏳ **待用户执行** - 需要清除 CMake 缓存后重新编译
