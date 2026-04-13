# Phase 7.48.88.133-136 集控管理运行时修复

**日期**：2026-04-14  
**分支**：feature/hardware-video-codec  
**类型**：fix

---

## 修复总览

| Phase | 提交 | 内容 |
|---|---|---|
| 7.48.88.133 | fdbec65 | isModuleConnecting 非 Q_INVOKABLE → TypeError 刷屏 |
| 7.48.88.134 | 3a51272 | MQTTCentralTab.qml 多余花括号编译失败 |
| 7.48.88.135 | dc364d3 | 状态栏 MQTT 连接状态不更新（Q_INVOKABLE 非响应式） |
| 7.48.88.136 | 9531b61 | RowLayout 内使用 anchors 产生大量警告 |

---

## Phase 7.48.88.133 修复 isModuleConnecting 非 Q_INVOKABLE

**问题**：打开 MQTT集控配置 Tab，voip.md 日志大量刷错误：
```
TypeError: Property 'isModuleConnecting' of object MQTTController is not a function
```

**根本原因**：`MQTTController.h` 中 `isModuleConnecting()` 缺少 `Q_INVOKABLE` 修饰，QML 只能调用 `Q_INVOKABLE` 或 `Q_PROPERTY`，普通 C++ 成员函数对 QML 不可见。

```cpp
// 修复前
bool isModuleConnecting(int moduleIndex) const;

// 修复后
Q_INVOKABLE bool isModuleConnecting(int moduleIndex) const;
```

**QML 侧同步修复**：因 C++ 重编译需要时间，MQTTCentralTab.qml 同时改用已有的 `getModuleConnectionState(7)` 判断连接中状态（该函数已是 Q_INVOKABLE）：

```qml
// 旧：直接调用不可用的函数
if (mqttController.isModuleConnecting(7)) return "#FFA726"

// 新：用 getModuleConnectionState 判断
var state = mqttController.getModuleConnectionState(7)
if (state === "Connecting" || state === "正在连接") return "#FFA726"
```

**文件**：`src/mqtt/MQTTController.h`、`src/qml/.../MQTTCentralTab.qml`

---

## Phase 7.48.88.134 修复 MQTTCentralTab.qml 多余花括号

**问题**：编译报错：
```
Error compiling qml file: MQTTCentralTab.qml:265:1: error: Unexpected token `}'
```

**原因**：Phase 7.48.88.133 编辑说明文字块时，`ColumnLayout` 的闭合 `}` 重复写了一次：

```qml
// 修复前（第 260-261 行）
                }
                }   ← 多余的 }

// 修复后
                }
```

**文件**：`src/qml/.../MQTTCentralTab.qml`

---

## Phase 7.48.88.135 修复状态栏 MQTT 连接状态不更新

**问题**：顶部状态栏显示 `MQTT: 192.168.10.142 未连接`，但 MQTT集控配置 Tab 显示 `MQTT模块7 已连接`。同一连接状态两个地方显示不一致。

**根本原因**：状态栏绑定使用 Q_INVOKABLE 函数调用：
```qml
mqttController.isModuleConnected(7)  // 函数调用，不响应式！
```
界面初始加载时是 `false`，模块 7 后来连接成功，但绑定**不会自动重新求值**。

**修复**：引入本地属性 + `Connections` 监听 `connectedChanged` 信号：

```qml
// CentralControlPage.qml
property bool mqttModule7Connected: false

Connections {
    target: typeof mqttController !== "undefined" ? mqttController : null
    function onConnectedChanged(moduleIndex, connected) {
        if (moduleIndex === 7) {
            root.mqttModule7Connected = connected
        }
    }
}

Component.onCompleted: {
    if (typeof mqttController !== "undefined") {
        root.mqttModule7Connected = mqttController.isModuleConnected(7)
    }
}
```

状态栏绑定改为：`root.mqttModule7Connected`（本地 QML 属性，完全响应式）。

**经验**：`mqttController.connectedChanged(int moduleIndex, bool connected)` 是信号，通过 `Connections` 监听后可实现响应式更新，无需 Q_PROPERTY。

**文件**：`src/qml/.../CentralControlPage.qml`

---

## Phase 7.48.88.136 修复 RowLayout 内使用 anchors 的警告

**问题**：voip.md 日志大量刷警告：
```
QML QQuickText: Detected anchors on an item that is managed by a layout.
This is undefined behavior; use Layout.alignment instead.
SubStationManageTab.qml:218:29
```

**根本原因**：`RowLayout` 内的子项不能使用 `anchors`——Qt 的布局系统会接管子项的尺寸和位置，与 `anchors` 冲突产生未定义行为。

**修复**：将两处 `anchors.verticalCenter` 改为 `Layout.alignment`：

| 位置 | 修复前 | 修复后 |
|---|---|---|
| line 163 状态 LED（Rectangle） | `anchors.verticalCenter: parent.verticalCenter` | `Layout.alignment: Qt.AlignVCenter` |
| line 228 协议标签（Text） | `anchors.verticalCenter: parent.verticalCenter` | `Layout.alignment: Qt.AlignVCenter` |

**规则**：在任何 Qt Quick Layout（`RowLayout`/`ColumnLayout`/`GridLayout`）内，子项只能用 `Layout.*` 属性，**不能**用 `anchors`（除了 `anchors.fill: parent` 对 Layout 容器本身有效）。

**文件**：`src/qml/.../SubStationManageTab.qml`

---

## 今日 MQTT 集控配置方法说明

根据用户问题整理，供文档参考：

### 三个 ID 的作用

| 参数 | 作用 |
|---|---|
| **本机设备ID** | 本台设备在集控网络的唯一编号（1-8），用于 MQTT Topic 路由 `belt/central/{ID}/status` |
| **集控ID** | 集控组编号，同一组主站和分站填相同值 |
| **主站设备ID** | 仅分站模式：填写主站的"本机设备ID"，分站据此订阅主站命令 |

### 主站配置

- 集控角色：**主站**，本机设备ID：**1**，集控ID：**1**
- 分站管理 → 分站1：启用=打开，协议=MQTT，目标设备ID=**2**（对方的本机ID）

### 分站配置（另一台设备）

- 集控角色：**分站**，本机设备ID：**2**，集控ID：**1**，主站设备ID：**1**
- 分站不需要配置"分站管理"

### MQTT 集控 Broker 说明

- 集控使用 **MQTT 模块7**（0-6已被 DI/AI/DO/CS 数据采集占用）
- 在 MQTT集控配置中填入 Broker IP（如 `192.168.10.142`），端口 `1883`
- 保存配置后，切换角色为主站/分站即自动触发模块7连接
- EMQX 客户端列表中显示为 `belt_control_module_7`
