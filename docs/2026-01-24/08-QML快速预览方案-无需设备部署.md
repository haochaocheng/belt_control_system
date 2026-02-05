# QML 快速预览方案 - 无需设备部署

**文档版本**: v1.0
**创建日期**: 2026-01-24
**状态**: 实用指南

---

## 1. 问题描述

**痛点**：
- ❌ 每次修改 QML 都要重新编译（30-60分钟）
- ❌ 需要部署到设备才能看到效果
- ❌ 调试周期长，效率低

**需求**：
- ✅ 在电脑上直接预览 QML 布局
- ✅ 快速迭代，实时查看效果
- ✅ 无需设备部署

---

## 2. 解决方案对比

| 方案 | 速度 | 易用性 | 功能完整性 | 推荐度 |
|------|------|--------|-----------|--------|
| **Qt Design Studio** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **桌面测试项目** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **qml 命令行工具** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Qt Creator 预览** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## 3. 方案1：Qt Design Studio（最直观）

### 3.1 适用场景
- ✅ 可视化编辑布局
- ✅ 调整组件位置和大小
- ✅ 修改属性值
- ✅ 实时预览效果

### 3.2 使用步骤

**1. 打开 Qt Design Studio**：
```
开始菜单 → Qt Design Studio
```

**2. 打开 QML 文件**：
```
File → Open File or Project
选择：src/qml/components/device_info/DeviceSettingsDialog.qml
```

**3. 实时预览**：
- 左侧：组件树
- 中间：可视化编辑器
- 右侧：属性面板
- 底部：代码编辑器

**4. 修改并保存**：
- 拖拽组件调整位置
- 修改属性值
- Ctrl+S 保存
- 实时看到效果

### 3.3 优势
- ✅ 所见即所得
- ✅ 无需编写代码
- ✅ 支持拖拽
- ✅ 实时预览

### 3.4 限制
- ❌ 无法测试 C++ 后端交互
- ❌ 无法测试数据绑定
- ❌ 仅适合布局和样式调整

---

## 4. 方案2：桌面测试项目（最灵活）

### 4.1 适用场景
- ✅ 测试完整组件功能
- ✅ 测试数据绑定
- ✅ 测试交互逻辑
- ✅ 快速迭代开发

### 4.2 创建测试项目

**执行脚本**：
```powershell
.\scripts\2026-01-24\02-create-qml-preview-project.ps1
```

**生成的项目结构**：
```
QmlPreview/
├── CMakeLists.txt  - 项目配置
├── main.cpp        - 程序入口
├── main.qml        - 主界面
└── README.md       - 使用说明
```

### 4.3 使用步骤

**1. 打开项目**：
```
Qt Creator → 文件 → 打开文件或项目
选择：QmlPreview/CMakeLists.txt
```

**2. 配置 Kit**：
```
选择桌面 Kit（MinGW 或 MSVC）
点击 Configure Project
```

**3. 添加要测试的 QML 文件**：

在 `CMakeLists.txt` 中添加：
```cmake
qt_add_qml_module(QmlPreview
    URI QmlPreview
    VERSION 1.0
    QML_FILES
        main.qml
        # ✅ 添加要测试的文件
        ../src/qml/components/device_info/DeviceSettingsDialog.qml
        ../src/qml/components/device_info/pages/BasicConfigPage.qml
        ../src/qml/components/parameter_settings/BasicParametersSection.qml
        ../src/qml/components/parameter_settings/NetworkParametersSection.qml
)
```

**4. 在 main.qml 中导入组件**：
```qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Window {
    width: 1024
    height: 768
    visible: true
    title: "QML 预览测试"

    // ✅ 测试 DeviceSettingsDialog
    Loader {
        anchors.centerIn: parent
        width: 800
        height: 550
        source: "../src/qml/components/device_info/DeviceSettingsDialog.qml"

        onLoaded: {
            if (item) {
                item.deviceId = 1
                item.deviceName = "1号皮带（测试）"
            }
        }
    }
}
```

**5. 编译运行**：
```
快捷键：Ctrl+R
或点击左下角的绿色运行按钮
```

### 4.4 优势
- ✅ 快速编译（几秒钟）
- ✅ 完整的 Qt 环境
- ✅ 支持调试
- ✅ 可以测试交互逻辑

### 4.5 技巧

**热重载**：
- 修改 QML 文件后
- 无需重新编译
- 直接 Ctrl+R 重新运行即可

**模拟数据**：
```qml
// 在 main.qml 中模拟 C++ 后端数据
QtObject {
    id: mockSystemConfig
    property int machineNumber: 1
    property int workMode: 0
    property int warningTimeSeconds: 10
    property int warningPlayCount: 3
    property string localDeviceName: "测试设备"
}

Loader {
    source: "BasicConfigPage.qml"
    onLoaded: {
        // 传递模拟数据
        item.systemConfig = mockSystemConfig
    }
}
```

---

## 5. 方案3：qml 命令行工具（最快速）

### 5.1 适用场景
- ✅ 快速预览单个 QML 文件
- ✅ 不依赖项目配置
- ✅ 命令行操作

### 5.2 使用步骤

**1. 找到 qml.exe**：
```
通常位置：C:\Qt\6.5.3\mingw_64\bin\qml.exe
```

**2. 运行 QML 文件**：
```powershell
C:\Qt\6.5.3\mingw_64\bin\qml.exe src\qml\components\device_info\DeviceSettingsDialog.qml
```

**3. 使用预览脚本**：
```powershell
.\scripts\2026-01-24\01-preview-qml.ps1 "src/qml/components/device_info/DeviceSettingsDialog.qml"
```

### 5.3 限制
- ❌ 无法加载项目资源（qrc）
- ❌ 无法加载自定义组件
- ❌ 仅适合简单的独立 QML 文件

---

## 6. 方案4：Qt Creator QML 预览

### 6.1 使用步骤

**1. 打开 QML 文件**：
```
Qt Creator → 打开 DeviceSettingsDialog.qml
```

**2. 启用 QML 预览**：
```
菜单栏 → 工具 → QML/JS → Show Qt Quick Designer
或快捷键：Alt+Shift+D
```

**3. 实时预览**：
- 左侧：代码编辑器
- 右侧：可视化预览
- 修改代码后自动更新预览

### 6.2 优势
- ✅ 集成在 Qt Creator 中
- ✅ 代码和预览同步
- ✅ 无需额外工具

### 6.3 限制
- ❌ 预览功能有时不稳定
- ❌ 复杂组件可能无法预览

---

## 7. 推荐工作流程

### 7.1 布局调整阶段
**使用 Qt Design Studio**：
1. 打开 QML 文件
2. 可视化调整布局
3. 修改属性值
4. 实时查看效果
5. 保存文件

### 7.2 功能开发阶段
**使用桌面测试项目**：
1. 创建测试项目
2. 添加要测试的 QML 文件
3. 在 main.qml 中导入组件
4. 快速编译运行（Ctrl+R）
5. 测试交互逻辑
6. 修改代码后重新运行

### 7.3 最终验证阶段
**部署到设备**：
1. 确认功能完整
2. 执行完整编译
3. 部署到设备
4. 真机测试

---

## 8. 常见问题

### 8.1 资源文件找不到

**问题**：
```
qrc:/qt/qml/BeltControlQml/components/device_info/images/deviceInfo40.png
```

**解决方案**：
在桌面测试项目中，需要复制资源文件：
```cmake
# CMakeLists.txt
RESOURCES
    ../src/qml/components/device_info/images/deviceInfo40.png
    ../src/qml/components/device_info/images/351.png
    ../src/qml/components/device_info/images/042.png
```

### 8.2 自定义组件找不到

**问题**：
```
Cannot find component: BasicParametersSection
```

**解决方案**：
在 CMakeLists.txt 中添加所有依赖的 QML 文件：
```cmake
QML_FILES
    main.qml
    ../src/qml/components/parameter_settings/BasicParametersSection.qml
    ../src/qml/components/parameter_settings/NetworkParametersSection.qml
```

### 8.3 C++ 后端对象找不到

**问题**：
```
ReferenceError: systemConfig is not defined
```

**解决方案**：
在 main.qml 中创建模拟对象：
```qml
QtObject {
    id: mockSystemConfig
    property int machineNumber: 1
    // ... 其他属性
}
```

---

## 9. 总结

### 9.1 最佳实践

**快速布局调整**：
```
Qt Design Studio → 可视化编辑 → 保存
```

**功能开发测试**：
```
桌面测试项目 → 快速编译 → 实时预览 → 迭代开发
```

**最终验证**：
```
完整编译 → 设备部署 → 真机测试
```

### 9.2 效率提升

**传统方式**：
- 修改 QML → 完整编译（30-60分钟）→ 部署 → 测试
- 每次迭代：30-60分钟

**新方式**：
- 修改 QML → 桌面测试项目编译（几秒钟）→ 预览
- 每次迭代：几秒钟
- **效率提升：100-1000倍**

### 9.3 下一步

**立即尝试**：
```powershell
# 创建桌面测试项目
.\scripts\2026-01-24\02-create-qml-preview-project.ps1

# 使用 Qt Creator 打开
# QmlPreview/CMakeLists.txt
```

---

**文档结束**
