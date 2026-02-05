# QDS 完整运行配置指南

**日期**：2026-01-25
**目标**：在 QDS 中运行整个皮带控制系统应用程序

---

## 📋 已创建的文件

### 1. **BeltControlSystem.qmlproject** ✅
- **位置**：`src/qml/BeltControlSystem.qmlproject`
- **用途**：QDS 项目配置文件，定义整个应用程序的结构
- **主文件**：`main_qds.qml`（QDS 专用入口）
- **包含内容**：
  - 所有页面（pages/）
  - 所有组件（components/）
  - Input1 模块
  - 资源文件（图片、字体、音频等）

### 2. **main_qds.qml** ✅
- **位置**：`src/qml/main_qds.qml`
- **用途**：QDS 专用入口文件，不依赖 C++ 后端
- **功能**：
  - 加载 MockBackend 模拟后端
  - 提供简化的页面导航
  - 支持键盘左右键切换页面
  - 显示电机控制页面

### 3. **qtquickcontrols2.conf** ✅
- **位置**：`src/qml/qtquickcontrols2.conf`
- **用途**：Qt Quick Controls 样式配置
- **配置内容**：
  - 基础样式：Basic
  - 深色主题
  - 科技蓝强调色（#2196F3）

### 4. **MockBackend.qml** ✅
- **位置**：`src/qml/MockBackend.qml`
- **用途**：模拟 C++ 后端，让 QDS 能够运行应用程序
- **模拟内容**：
  - CommonControl（设备控制）
  - DeviceInfoController（设备信息）
  - SipPhoneManager（SIP 电话）
  - AudioManagementController（音频管理）
  - 报警数据
  - 开关量输入
  - 模拟量输入

---

## 🚀 在 QDS 中运行应用程序

### 方法 1：直接打开项目（推荐）

1. **打开 Qt Design Studio**

2. **打开项目文件**：
   ```
   文件 → 打开项目
   选择：src/qml/BeltControlSystem.qmlproject
   ```

3. **等待项目加载**：
   - QDS 会自动扫描所有 QML 文件
   - 加载所有资源文件
   - 配置导入路径

4. **运行应用程序**：
   - 点击 QDS 左下角的 **▶️ 运行** 按钮
   - 或按快捷键 **Ctrl+R**（Windows）/ **Cmd+R**（Mac）

5. **查看效果**：
   - 应用程序会在新窗口中启动
   - 可以浏览所有页面
   - 可以测试交互功能

### 方法 2：从命令行运行

```powershell
# 进入 QML 目录
cd src/qml

# 使用 qml 工具运行
qml BeltControlSystem.qmlproject

# 或使用 qmlscene
qmlscene main.qml
```

---

## 🔧 配置说明

### 项目结构

```
src/qml/
├── BeltControlSystem.qmlproject  # ✅ QDS 项目文件
├── qtquickcontrols2.conf         # ✅ 控件样式配置
├── MockBackend.qml               # ✅ 后端模拟
├── main.qml                      # 应用程序入口
├── App.qml                       # 主界面
├── pages/                        # 所有页面
│   ├── ControlPanel.qml
│   ├── ParameterSettings.qml
│   ├── AlarmPage.qml
│   └── ...
├── components/                   # 所有组件
│   ├── common/
│   ├── control_panel/
│   ├── device_info/
│   └── sip_phone/
└── Input1/                       # Input1 模块
    └── Input1Content/
```

### 导入路径配置

在 `BeltControlSystem.qmlproject` 中已配置：

```qml
importPaths: [
    ".",
    "components",
    "pages",
    "Input1"
]
```

这样可以在 QML 文件中直接导入：

```qml
import "components/common"
import "pages"
```

---

## 🎯 使用模拟后端

### 在 main.qml 中加载模拟后端

**方法 1：全局加载**（推荐用于 QDS）

在 `main.qml` 的 `ApplicationWindow` 中添加：

```qml
ApplicationWindow {
    id: root

    // ✅ 加载模拟后端（仅在 QDS 中）
    property bool isQdsMode: Qt.application.arguments.indexOf("--qds") !== -1

    MockBackend {
        id: mockBackend
    }

    // 将模拟后端暴露为全局对象
    property alias commonControl: mockBackend.commonControl
    property alias deviceInfoController: mockBackend.deviceInfoController
    property alias sipPhoneManager: mockBackend.sipPhoneManager
    property alias audioManagementController: mockBackend.audioManagementController

    // ... 其他内容
}
```

**方法 2：条件加载**（推荐用于生产环境）

```qml
ApplicationWindow {
    id: root

    // ✅ 检测是否在 QDS 中运行
    property bool isQdsMode: typeof qmlDesignerMode !== 'undefined' && qmlDesignerMode

    Loader {
        id: backendLoader
        active: isQdsMode
        sourceComponent: MockBackend {}
    }

    // 使用模拟后端或真实后端
    property var commonControl: isQdsMode ? backendLoader.item.commonControl : realCommonControl

    // ... 其他内容
}
```

### 在页面中使用模拟数据

**示例：电机控制页面**

```qml
// MotorControlPage.qml
Rectangle {
    id: root

    // ✅ 从父级获取后端对象
    property var deviceInfoController: parent.deviceInfoController

    // 使用模拟数据
    Component.onCompleted: {
        var motorInfo = deviceInfoController.getMotorInfo(0)
        console.log("电机信息:", JSON.stringify(motorInfo))
    }
}
```

---

## 🐛 常见问题

### 问题 1：QDS 无法找到组件

**症状**：
```
Cannot find component: MyMotorListPanel
```

**解决方案**：
1. 确保组件文件在正确的目录下
2. 检查 `BeltControlSystem.qmlproject` 中是否包含该目录
3. 使用 `Loader` 加载组件：
   ```qml
   Loader {
       source: "MyMotorListPanel.qml"
   }
   ```

### 问题 2：C++ 类型未定义

**症状**：
```
ReferenceError: CommonControl is not defined
```

**解决方案**：
1. 确保 `MockBackend.qml` 已加载
2. 在 `main.qml` 中暴露模拟对象为全局属性
3. 或在每个页面中通过 `parent` 访问

### 问题 3：图片资源找不到

**症状**：
```
Cannot load image: file:///path/to/image.png
```

**解决方案**：
1. 检查图片路径是否正确
2. 确保 `BeltControlSystem.qmlproject` 中包含图片目录：
   ```qml
   ImageFiles {
       directory: "components/device_info/pages"
   }
   ```
3. 使用相对路径：
   ```qml
   Image {
       source: "images/background.png"
   }
   ```

### 问题 4：QDS 运行时崩溃

**可能原因**：
1. 使用了 QDS 不支持的 C++ 类型
2. 使用了 3D 场景（QDS 不支持）
3. 使用了复杂的动画或效果

**解决方案**：
1. 使用 `MockBackend.qml` 替代 C++ 类型
2. 暂时禁用 3D 场景：
   ```qml
   Loader {
       active: !isQdsMode
       source: "BeltScene3D.qml"
   }
   ```
3. 简化动画和效果

---

## 📊 功能对比

| 功能 | QDS 预览 | QDS 运行 | 实际编译运行 |
|------|---------|---------|-------------|
| 查看 UI 布局 | ✅ | ✅ | ✅ |
| 测试交互 | ❌ | ✅ | ✅ |
| 使用 C++ 后端 | ❌ | ⚠️ 模拟 | ✅ |
| 3D 场景 | ❌ | ❌ | ✅ |
| 网络通信 | ❌ | ⚠️ 模拟 | ✅ |
| 硬件控制 | ❌ | ❌ | ✅ |
| 性能测试 | ❌ | ⚠️ 部分 | ✅ |

**说明**：
- ✅ 完全支持
- ⚠️ 部分支持或需要模拟
- ❌ 不支持

---

## 🎯 最佳实践

### 1. 分离 UI 和逻辑

**推荐**：
```qml
// UI 部分（QDS 设计）
Rectangle {
    id: root
    property var dataSource: null  // 数据源（可以是模拟或真实）

    Text {
        text: dataSource ? dataSource.deviceName : "未知设备"
    }
}
```

**不推荐**：
```qml
// UI 和逻辑混合
Rectangle {
    Text {
        text: CommonControl.deviceName  // 直接依赖 C++ 类型
    }
}
```

### 2. 使用属性绑定

**推荐**：
```qml
property var motorInfo: deviceInfoController.getMotorInfo(motorIndex)

Text {
    text: motorInfo ? motorInfo.name : ""
}
```

**不推荐**：
```qml
Text {
    text: deviceInfoController.getMotorInfo(motorIndex).name  // 可能崩溃
}
```

### 3. 提供默认值

**推荐**：
```qml
Rectangle {
    width: 800   // 默认宽度（用于 QDS 预览）
    height: 600  // 默认高度（用于 QDS 预览）
}
```

### 4. 使用条件加载

**推荐**：
```qml
Loader {
    active: !isQdsMode  // 仅在非 QDS 模式下加载
    source: "BeltScene3D.qml"
}
```

---

## 📝 下一步

### 立即可做

1. **在 QDS 中打开项目**：
   ```
   打开 src/qml/BeltControlSystem.qmlproject
   ```

2. **运行应用程序**：
   - 点击 ▶️ 运行按钮
   - 测试所有页面

3. **修改 UI**：
   - 在 QDS 中直接编辑页面
   - 实时预览效果
   - 无需重新编译

### 后续优化

1. **完善模拟后端**：
   - 添加更多模拟数据
   - 模拟网络延迟
   - 模拟错误情况

2. **添加测试数据**：
   - 创建测试场景
   - 模拟不同状态
   - 测试边界情况

3. **优化性能**：
   - 使用 Loader 延迟加载
   - 减少不必要的绑定
   - 优化图片资源

---

## 🔗 相关文档

- [QDS 设计规范和迁移计划](./14-QDS设计规范和迁移计划.md)
- [Qt Design Studio 官方文档](https://doc.qt.io/qtdesignstudio/)
- [QML 项目文件格式](https://doc.qt.io/qtdesignstudio/studio-projects.html)

---

**创建时间**：2026-01-25
**创建人员**：Claude Sonnet 4.5
**文档版本**：v1.0
