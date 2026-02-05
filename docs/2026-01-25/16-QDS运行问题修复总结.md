# QDS 运行问题修复总结

**日期**：2026-01-25
**问题**：QDS 运行时报错，找不到 `App.qml` 和 `BeltControl.SipPhone` 模块

---

## 🐛 问题分析

### 错误信息

```
Warning: QQmlApplicationEngine failed to load component
Warning: file:///E:/2025/3_gongkongji/belt_control_system/src/qml/main.qml:68:5: Type App unavailable
Warning: file:///E:/2025/3_gongkongji/belt_control_system/src/qml/App.qml:5:1: module "BeltControl.SipPhone" is not installed
```

### 根本原因

1. **原始 `main.qml` 依赖 C++ 后端**：
   - 使用了 `App.qml`，而 `App.qml` 导入了 `BeltControl.SipPhone` 模块
   - `BeltControl.SipPhone` 是 C++ 注册的 QML 模块，QDS 无法识别

2. **QDS 无法加载 C++ 模块**：
   - QDS 是纯 QML 运行环境
   - 无法加载 C++ 注册的类型和模块
   - 需要使用纯 QML 实现或模拟

---

## ✅ 解决方案

### 1. 创建 QDS 专用入口文件

**文件**：`src/qml/main_qds.qml`

**特点**：
- ✅ 不依赖任何 C++ 模块
- ✅ 使用 `MockBackend.qml` 模拟后端
- ✅ 提供简化的页面导航
- ✅ 支持键盘左右键切换页面
- ✅ 直接加载电机控制页面

**结构**：
```qml
ApplicationWindow {
    // 加载模拟后端
    MockBackend {
        id: mockBackend
    }

    // 暴露为全局属性
    property alias commonControl: mockBackend.commonControl
    property alias deviceInfoController: mockBackend.deviceInfoController

    // 简化的页面导航
    SwipeView {
        // 页面 1: 控制面板
        // 页面 2: 参数设置
        // 页面 3: 报警页面
        // 页面 4: 设备信息 - 电机控制 ✅
        // 页面 5: Input1
        // 页面 6: 语音管理
    }
}
```

### 2. 修改项目配置文件

**文件**：`src/qml/BeltControlSystem.qmlproject`

**修改**：
```qml
Project {
    mainFile: "main_qds.qml"  // ✅ 改为 QDS 专用入口
    mainUiFile: "components/device_info/pages/MotorControlPage.qml"
    // ...
}
```

### 3. 保持原始文件不变

**重要**：
- ✅ `main.qml` 保持不变（用于实际编译运行）
- ✅ `App.qml` 保持不变（用于实际编译运行）
- ✅ 只在 QDS 中使用 `main_qds.qml`

---

## 🎯 使用方法

### 在 QDS 中运行

1. **打开项目**：
   ```
   Qt Design Studio → 文件 → 打开项目
   选择：src/qml/BeltControlSystem.qmlproject
   ```

2. **运行应用程序**：
   - 点击 ▶️ 运行按钮
   - 或按 Ctrl+R

3. **查看效果**：
   - 应用程序会启动，显示简化的导航界面
   - 默认显示第 4 页：电机控制页面
   - 使用左右键切换页面

### 实际编译运行

```powershell
# 使用原始 main.qml（包含完整功能）
.\build-ubuntu24-apt.ps1 188
```

---

## 📊 文件对比

| 文件 | 用途 | 依赖 C++ | QDS 支持 |
|------|------|---------|---------|
| `main.qml` | 实际运行 | ✅ 是 | ❌ 否 |
| `main_qds.qml` | QDS 运行 | ❌ 否 | ✅ 是 |
| `App.qml` | 实际运行 | ✅ 是 | ❌ 否 |
| `MockBackend.qml` | QDS 模拟 | ❌ 否 | ✅ 是 |

---

## 🎨 QDS 运行效果

### 界面布局

```
┌─────────────────────────────────────────────────────┐
│  [控制面板] [参数设置] [报警页面] [设备信息] ...    │  ← 顶部导航
├─────────────────────────────────────────────────────┤
│                                                     │
│              电机控制页面（默认显示）                │
│                                                     │
│  ┌──────────┬────────────────────────────────┐     │
│  │ 电机列表 │  配置面板                      │     │
│  │          │                                │     │
│  │ 1号电机  │  基本配置  电流保护  ...       │     │
│  │ 2号电机  │                                │     │
│  │ ...      │  [配置内容]                    │     │
│  └──────────┴────────────────────────────────┘     │
│                                                     │
├─────────────────────────────────────────────────────┤
│  设备: 1号皮带  状态: 运行中  速度: 1.50 m/s       │  ← 底部状态栏
└─────────────────────────────────────────────────────┘
```

### 交互功能

- ✅ 点击顶部导航切换页面
- ✅ 左右键切换页面
- ✅ 点击电机列表选择电机
- ✅ 查看电机配置
- ✅ 查看模拟数据

---

## 🔄 工作流程

### 开发流程

```
1. 在 QDS 中设计 UI
   ↓
2. 在 QDS 中预览和运行（使用 main_qds.qml）
   ↓
3. 修改 UI 实时生效
   ↓
4. 完成后编译运行（使用 main.qml）
   ↓
5. 在实际设备上测试
```

### 两套入口的协作

```
QDS 开发环境:
  main_qds.qml → MockBackend.qml → 纯 QML 页面
  ↓
  快速迭代 UI 设计

实际运行环境:
  main.qml → App.qml → C++ 后端 → 完整功能
  ↓
  完整的业务逻辑和硬件控制
```

---

## 📝 注意事项

### 1. 不要混淆两个入口

- ❌ 不要在 `main_qds.qml` 中导入 C++ 模块
- ❌ 不要在 `main.qml` 中使用 `MockBackend`
- ✅ 保持两个入口独立

### 2. 模拟数据的局限性

- ⚠️ `MockBackend` 只是模拟，不是真实数据
- ⚠️ 网络通信、硬件控制等功能无法在 QDS 中测试
- ✅ 只用于 UI 设计和布局验证

### 3. 页面开发建议

- ✅ 新页面先在 QDS 中设计 UI
- ✅ UI 完成后再添加业务逻辑
- ✅ 最后在实际设备上测试完整功能

---

## 🎯 成功标准

### QDS 运行成功

- ✅ 应用程序正常启动
- ✅ 无错误信息
- ✅ 可以切换页面
- ✅ 电机控制页面正常显示
- ✅ 可以点击交互

### 实际运行成功

- ✅ 使用 `main.qml` 编译成功
- ✅ 在设备上正常运行
- ✅ C++ 后端正常工作
- ✅ 硬件控制正常

---

## 🔗 相关文档

- [QDS 完整运行配置指南](./15-QDS完整运行配置指南.md)
- [QDS 设计规范和迁移计划](./14-QDS设计规范和迁移计划.md)

---

**创建时间**：2026-01-25
**创建人员**：Claude Sonnet 4.5
**文档版本**：v1.0
