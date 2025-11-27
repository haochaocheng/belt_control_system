# 皮带控制系统 - VSCode开发环境配置指南

## 📋 项目概述

这是一个基于Qt 6 QML开发的皮带输送控制系统，支持Windows和ARM64 Linux平台。

## 🛠 环境要求

### 必需软件

1. **Qt 6.5或更高版本**
   - 下载地址: https://www.qt.io/download-qt-installer
   - 需要安装的组件:
     - Qt 6.5.x for Desktop (MinGW或MSVC)
     - Qt Quick Controls
     - Qt SerialPort

2. **CMake 3.21或更高版本**
   - 下载地址: https://cmake.org/download/
   - 安装后添加到系统PATH

3. **编译器**
   - Windows: MinGW (随Qt安装) 或 Visual Studio 2019+
   - Linux: GCC 7+

4. **VSCode**
   - 下载地址: https://code.visualstudio.com/

## 📦 VSCode插件安装

打开项目后,VSCode会提示安装推荐的插件。主要插件包括:

- **bbenoist.qml** - QML语法高亮和格式化
- **seanwu.vscode-qt-for-python** - Qt支持
- **ms-vscode.cpptools** - C++ IntelliSense
- **ms-vscode.cmake-tools** - CMake工具
- **twxs.cmake** - CMake语法高亮

手动安装: 按 `Ctrl+Shift+X` 打开扩展面板,搜索并安装上述插件。

## ⚙️ 配置步骤

### 1. 修改Qt路径

需要在以下文件中配置你的Qt安装路径:

#### `.vscode/settings.json`
```json
{
  "qml.viewer.path": "C:/Qt/6.5.0/mingw_64/bin/qmlscene.exe",  // 修改此处
  "cmake.configureSettings": {
    "CMAKE_PREFIX_PATH": "C:/Qt/6.5.0/mingw_64"  // 修改此处
  }
}
```

#### `.vscode/c_cpp_properties.json`
```json
{
  "includePath": [
    "C:/Qt/6.5.*/mingw*/include/**"  // 修改此处
  ],
  "compilerPath": "C:/Qt/Tools/mingw1120_64/bin/g++.exe"  // 修改此处
}
```

#### `.vscode/launch.json`
```json
{
  "miDebuggerPath": "C:/Qt/Tools/mingw1120_64/bin/gdb.exe"  // 修改此处
}
```

#### `build.bat` 和 `run.bat`
```batch
set QT_PATH=C:\Qt\6.5.0\mingw_64  REM 修改此处
```

### 2. 配置CMake工具链

按 `Ctrl+Shift+P`, 输入 `CMake: Select a Kit`

选择:
- **MinGW**: 选择 Qt MinGW工具链
- **MSVC**: 选择 Visual Studio工具链

## 🚀 构建和运行

### 方法1: 使用批处理脚本 (推荐新手)

#### 构建项目
```batch
build.bat
```

#### 运行程序
```batch
run.bat
```

### 方法2: 使用VSCode任务

#### 构建
- 按 `Ctrl+Shift+B` (快捷键)
- 或 `Ctrl+Shift+P` → `Tasks: Run Build Task`

#### 运行/调试
- 按 `F5` 开始调试
- 按 `Ctrl+F5` 直接运行(无调试)

### 方法3: 使用CMake命令行

```bash
# 配置
cmake -B build -S . -DCMAKE_PREFIX_PATH=C:/Qt/6.5.0/mingw_64 -G "MinGW Makefiles"

# 编译
cmake --build build --config Debug

# 运行
build/bin_windows/belt_control_system.exe
```

## 📁 项目结构

```
belt_control_system/
├── .vscode/                    # VSCode配置
│   ├── extensions.json         # 推荐插件
│   ├── settings.json           # 工作区设置
│   ├── c_cpp_properties.json   # C++ IntelliSense配置
│   ├── launch.json             # 调试配置
│   ├── tasks.json              # 构建任务
│   └── qml.code-snippets       # QML代码片段
├── src/
│   ├── main/                   # 主程序入口
│   │   ├── main.cpp
│   │   └── CMakeLists.txt
│   ├── qml/                    # QML界面
│   │   ├── main.qml            # 主界面
│   │   ├── pages/              # 页面组件
│   │   ├── components/         # 可复用组件
│   │   └── CMakeLists.txt
│   ├── control/                # 控制逻辑
│   │   ├── belt_controller.h
│   │   ├── belt_controller.cpp
│   │   └── CMakeLists.txt
│   ├── hardware/               # 硬件抽象层
│   │   ├── hal/                # 硬件接口
│   │   ├── simulated/          # 模拟硬件
│   │   ├── real/               # 真实硬件
│   │   └── CMakeLists.txt
│   └── utils/                  # 工具类
│       ├── logger.h
│       ├── config_reader.h
│       └── CMakeLists.txt
├── resources/                  # 资源文件
│   ├── qml_resources.qrc       # QML资源配置
│   ├── images/
│   └── config/
├── tests/                      # 单元测试
├── CMakeLists.txt              # 主CMake配置
├── build.bat                   # Windows构建脚本
├── run.bat                     # Windows运行脚本
└── README_VSCODE_SETUP.md      # 本文档
```

## 🎨 界面预览

主界面包含:
- ⚡ 速度控制面板 (滑块控制皮带速度 0-5 m/s)
- 🔧 电机控制面板 (启动/停止/急停按钮)
- 📊 运行参数显示 (实时状态监控)
- ⚠️ 报警信息显示 (系统报警提示)

## 💡 QML代码片段使用

在`.qml`文件中输入以下前缀可快速生成代码:

- `qitem` - Item组件
- `qrect` - Rectangle
- `qbutton` - Button
- `qtext` - Text
- `qcolumn` - ColumnLayout
- `qrow` - RowLayout
- `qgrid` - GridLayout
- `qprop` - 属性定义
- `qsignal` - 信号定义
- `qtimer` - 定时器
- 等等...

## 🐛 常见问题

### 问题1: 找不到Qt库

**解决方案**:
1. 确认Qt已正确安装
2. 检查PATH环境变量是否包含Qt的bin目录
3. 修改配置文件中的Qt路径

### 问题2: CMake配置失败

**解决方案**:
1. 确认CMake已安装并添加到PATH
2. 确认`CMAKE_PREFIX_PATH`指向正确的Qt目录
3. 删除`build`目录后重新配置

### 问题3: 编译错误

**解决方案**:
1. 确认所有C++源文件已创建
2. 检查CMakeLists.txt配置是否正确
3. 查看编译错误信息,通常会提示缺少的头文件或库

### 问题4: 运行时找不到DLL

**解决方案**:
1. 使用`run.bat`脚本运行(会自动设置PATH)
2. 或手动将Qt的bin目录添加到系统PATH

### 问题5: QML文件无法加载

**解决方案**:
1. 检查`qml_resources.qrc`是否正确配置
2. 确认QML文件路径正确
3. 检查`main.cpp`中的QML加载路径

## 📚 学习资源

- Qt官方文档: https://doc.qt.io/qt-6/
- QML教程: https://doc.qt.io/qt-6/qmlapplications.html
- CMake文档: https://cmake.org/documentation/
- VSCode C++文档: https://code.visualstudio.com/docs/languages/cpp

## 🤝 开发建议

1. 使用Git进行版本控制
2. 编写单元测试确保代码质量
3. 遵循Qt代码规范
4. 及时提交代码并写清楚commit信息

## 📞 技术支持

如遇到问题:
1. 查看本文档的"常见问题"部分
2. 检查编译输出的错误信息
3. 查阅Qt官方文档

---

**版本**: v1.0.0
**更新日期**: 2025-11-12
**作者**: Belt Control System Team
