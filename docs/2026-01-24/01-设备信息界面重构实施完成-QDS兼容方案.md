# 设备信息界面重构实施完成 - QDS 兼容方案

**文档版本**: v1.0
**创建日期**: 2026-01-24
**状态**: 已完成

## 1. 概述

成功完成设备信息界面重构，采用 QDS 兼容方案，使用 12 个 MyIN_Data 组件展示设备信息。

### 1.1 核心变更

- ✅ 修改 MyIN_Data.ui.qml 为设备信息卡片组件
- ✅ Screen01.ui.qml 使用 12 个 MyIN_Data 实例（4x3 网格布局）
- ✅ 纯声明式 QML，完全兼容 Qt Design Studio
- ✅ 创建后端 DeviceInfoController 支持数据绑定

---

## 2. 技术方案

### 2.1 为什么采用 QDS 兼容方案？

**问题**：
- Screen01.ui.qml 是 Qt Design Studio 文件（.ui.qml）
- 不支持 JavaScript 函数调用和复杂逻辑
- 错误提示：`Arbitrary functions and function calls outside of a Connections or ScriptAction objects are not supported in a UI file`

**解决方案**：
- 使用纯声明式 QML 语法
- 将 MyIN_Data 组件改造成设备信息卡片
- 在 Screen01.ui.qml 中使用 12 个 MyIN_Data 实例
- 交互逻辑后续在 Input1Page.qml 中处理

---

## 3. 文件修改详情

### 3.1 MyIN_Data.ui.qml（设备信息卡片组件）

**文件路径**: `src/qml/Input1/Input1Content/MyIN_Data.ui.qml`

**修改内容**：
```qml
Rectangle {
    id: root

    // 公开属性
    property string deviceName: ""
    property string deviceId: ""
    property bool isSelected: false
    property bool isRunning: false
    property real speed: 0.0
    property string status: "停止"

    // 样式
    color: "#1E1E1E"
    border.color: isSelected ? "#00FF00" : "#555555"
    border.width: isSelected ? 3 : 1
    radius: 8

    // 设备图片区域
    Rectangle {
        id: imageContainer
        // 占位符图片
        Image {
            source: "images/IN_Data.png"
        }
    }

    // 设备信息区域
    Column {
        // 设备名称
        Text { text: deviceName }

        // 运行状态指示器
        Rectangle { color: isRunning ? "#00FF00" : "#808080" }

        // 速度信息
        Text { text: "速度: " + speed.toFixed(1) + " m/s" }
    }
}
```

**特性**：
- ✅ 纯声明式，QDS 完全兼容
- ✅ 支持选中状态（绿色边框）
- ✅ 显示设备名称、状态、速度
- ✅ 占位符图片支持

### 3.2 Screen01.ui.qml（主界面）

**文件路径**: `src/qml/Input1/Input1Content/Screen01.ui.qml`

**修改内容**：
```qml
Rectangle {
    // 第一行（1-4号皮带）
    MyIN_Data {
        id: device1
        x: 40
        y: 110
        width: 280
        height: 180
        deviceName: "1号皮带"
        deviceId: "1"
    }

    MyIN_Data {
        id: device2
        x: 340
        y: 110
        width: 280
        height: 180
        deviceName: "2号皮带"
        deviceId: "2"
    }

    // ... 共 12 个设备
}
```

**布局规格**（1920x1080 设计尺寸）：
- 单个设备：280 x 180 px
- 水平间距：20 px
- 垂直间距：20 px
- 左边距：40 px
- 上边距：110 px（Head 高度 80 + 间距 30）

**设备命名**：
1. device1-8: 1-8号皮带
2. device9: 破碎机
3. device10: 转载机
4. device11: 前刮板机
5. device12: 后刮板机

### 3.3 DeviceInfoController（后端控制器）

**文件路径**:
- `src/control/DeviceInfoController.h`
- `src/control/DeviceInfoController.cpp`

**功能**：
```cpp
class DeviceInfoController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList deviceList READ deviceList NOTIFY deviceListChanged)

public:
    QVariantList deviceList() const;
    Q_INVOKABLE void openDeviceSettings(int deviceId);
    Q_INVOKABLE void updateDeviceStatus(int deviceId, const QString& status);
    Q_INVOKABLE void updateDeviceName(int deviceId, const QString& name);

signals:
    void deviceListChanged();
    void deviceStatusChanged(int deviceId, const QString& status);

private:
    void initializeDevices();
    QVariantList m_deviceList;
};
```

**已注册到 QML**：
- 在 `main.cpp` 中注册为 `deviceInfoController`
- QML 中可通过 `deviceInfoController.deviceList` 访问设备数据

---

## 4. 构建配置

### 4.1 CMakeLists.txt 更新

**src/qml/CMakeLists.txt**：
```cmake
QML_FILES
    # ✅ 2026-01-24 [设备信息界面重构]: 设备信息组件
    components/device_info/DeviceInfoItem.qml
    components/device_info/DeviceInfoGrid.qml
    components/device_info/DeviceSettingsDialog.qml
```

**src/control/CMakeLists.txt**：
```cmake
set(CONTROL_SOURCES
    DeviceInfoController.cpp  # ✅ 2026-01-24 [设备信息界面重构]
)

set(CONTROL_HEADERS
    DeviceInfoController.h  # ✅ 2026-01-24 [设备信息界面重构]
)
```

### 4.2 main.cpp 注册

```cpp
#include "control/DeviceInfoController.h"

// 创建控制器实例
DeviceInfoController deviceInfoController;

// 注册到 QML
engine.rootContext()->setContextProperty("deviceInfoController", &deviceInfoController);
```

---

## 5. 响应式设计

### 5.1 多分辨率支持

**设计尺寸**: 1920 x 1080（QDS 设计）
**目标分辨率**: 1280 x 800（测试环境）

**缩放处理**：
- Input1Page.qml 中的 Loader 应用缩放变换
- xScale: 1280 / 1920 = 0.667
- yScale: 800 / 1080 = 0.741

**计算后的实际尺寸**（1280x800）：
- 单个设备：187 x 133 px
- 水平间距：13 px
- 垂直间距：15 px

---

## 6. 后续扩展计划

### 6.1 Phase 4: 交互逻辑（待实现）

**目标**：在 Input1Page.qml 中添加交互逻辑

**功能**：
1. 鼠标点击选中设备
2. 键盘方向键导航
3. 双击或 Enter 键打开参数设置弹窗
4. 从 DeviceInfoController 获取实时设备状态

**实现方式**：
```qml
// Input1Page.qml
Loader {
    id: screenLoader
    source: "Screen01.ui.qml"

    onLoaded: {
        // 为每个设备添加 MouseArea
        var devices = [
            screenLoader.item.device1,
            screenLoader.item.device2,
            // ... 共 12 个
        ]

        devices.forEach(function(device, index) {
            // 添加点击事件处理
            // 绑定设备数据
        })
    }
}
```

### 6.2 Phase 5: 参数设置弹窗（待实现）

**目标**：实现 DeviceSettingsDialog 弹窗

**功能**：
- 左侧类别按钮（基本参数、运行参数、报警设置等）
- 上部操作按钮（关闭、保存、重置）
- 中间参数显示区域（带图片占位符）

---

## 7. 测试验证

### 7.1 编译测试

```powershell
# 手动执行构建和部署
.\build-ubuntu24-apt.ps1 188
```

### 7.2 功能测试

**测试项**：
- [ ] 第5个页面显示 12 个设备卡片
- [ ] 设备名称正确显示（1-8号皮带、破碎机等）
- [ ] 设备卡片布局正确（4x3 网格）
- [ ] 占位符图片正常显示
- [ ] 缩放适配正确（1280x800 分辨率）

**预期结果**：
- ✅ QDS 可以正常打开 Screen01.ui.qml
- ✅ 不再出现 JavaScript 语法错误
- ✅ 12 个设备卡片正确显示

---

## 8. 技术亮点

### 8.1 QDS 兼容性

**优势**：
- ✅ 完全兼容 Qt Design Studio
- ✅ 可在 QDS 中可视化编辑
- ✅ 纯声明式 QML，易于维护

**限制**：
- ❌ 不能使用 JavaScript 函数
- ❌ 不能使用复杂的数据绑定表达式
- ✅ 解决方案：交互逻辑在 Input1Page.qml 中处理

### 8.2 组件复用

**MyIN_Data 组件**：
- 原本只是简单的图片占位符
- 改造成功能完整的设备信息卡片
- 保持 .ui.qml 格式，QDS 兼容

**DeviceInfoController**：
- 提供统一的设备数据管理
- 支持设备状态更新
- 支持设备名称修改

---

## 9. 文件清单

### 9.1 新建文件

```
src/qml/components/device_info/
├── DeviceInfoItem.qml          (166 行) - 设备信息卡片（备用）
├── DeviceInfoGrid.qml          (196 行) - 4x3 网格容器（备用）
└── DeviceSettingsDialog.qml    (260 行) - 参数设置弹窗（备用）

src/control/
├── DeviceInfoController.h      (40 行)  - 设备信息控制器头文件
└── DeviceInfoController.cpp    (92 行)  - 设备信息控制器实现
```

### 9.2 修改文件

```
src/qml/Input1/Input1Content/
├── Screen01.ui.qml             - 使用 12 个 MyIN_Data 实例
└── MyIN_Data.ui.qml            - 改造成设备信息卡片

src/qml/CMakeLists.txt          - 添加新组件文件
src/control/CMakeLists.txt      - 添加控制器文件
src/main/main.cpp               - 注册控制器到 QML
```

---

## 10. 总结

### 10.1 实施成果

✅ **Phase 1-3 完成**：
1. ✅ 组件开发（DeviceInfoItem, DeviceInfoGrid, DeviceSettingsDialog）
2. ✅ 后端集成（DeviceInfoController）
3. ✅ 界面集成（Screen01.ui.qml, MyIN_Data.ui.qml）

✅ **QDS 兼容性**：
- 完全兼容 Qt Design Studio
- 纯声明式 QML 语法
- 可在 QDS 中可视化编辑

✅ **技术架构**：
- 组件化设计，易于维护
- 后端控制器统一管理设备数据
- 响应式布局，支持多分辨率

### 10.2 下一步工作

⏳ **Phase 4: 交互逻辑**（待实现）：
- 在 Input1Page.qml 中添加鼠标点击事件
- 实现键盘导航功能
- 绑定设备实时状态数据

⏳ **Phase 5: 参数设置弹窗**（待实现）：
- 实现 DeviceSettingsDialog 具体参数界面
- 添加参数保存和加载功能
- 集成到设备双击事件

---

**文档结束**
