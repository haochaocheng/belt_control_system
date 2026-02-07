# CAN 控制功能实施方案

**日期**: 2026-02-07（星期五）
**任务**: 在串口控制中新增 CAN 控制功能
**参考**: docs/2026-01-29/01-RK3588工控机外设测试报告.md

---

## 一、硬件基础

### 1.1 CAN 硬件支持

根据 RK3588 工控机外设测试报告：

- ✅ **CAN 接口**: 检测到 `can0` 和 `can1` 两个 CAN 接口
- ✅ **设备路径**:
  - `/sys/class/net/can0` → `/devices/platform/fea50000.can/net/can0`
  - `/sys/class/net/can1` → `/devices/platform/fea60000.can/net/can1`
- ✅ **内核驱动**: 已启用 Rockchip CAN 驱动
  - `CONFIG_CAN_ROCKCHIP=y`
  - `CONFIG_CANFD_ROCKCHIP=y`
- ✅ **SocketCAN 支持**: 已启用（标准 Linux CAN 协议栈）
- ✅ **工具支持**: `candump`、`cansend`、`ip` 命令

### 1.2 CAN 使用示例

```bash
# 配置 CAN0，波特率 500kbps
sudo ip link set can0 type can bitrate 500000
sudo ip link set can0 up

# 配置 CAN1，波特率 250kbps
sudo ip link set can1 type can bitrate 250000
sudo ip link set can1 up

# 监听 CAN0 数据
candump can0

# 发送 CAN 数据到 CAN1
cansend can1 123#DEADBEEF
```

---

## 二、功能设计

### 2.1 功能概述

在现有的串口控制界面中，新增 CAN 控制功能，支持：

1. **CAN 接口配置**
   - CAN 接口选择（can0、can1）
   - 波特率配置（常用：125k、250k、500k、1000k）
   - 接口状态显示（UP/DOWN）

2. **CAN 数据发送**
   - CAN ID 输入（标准帧 11 位、扩展帧 29 位）
   - 数据输入（HEX 格式，最多 8 字节）
   - 发送按钮

3. **CAN 数据接收**
   - 实时显示接收到的 CAN 数据
   - 显示 CAN ID、数据长度、数据内容
   - 时间戳显示
   - 清空接收区按钮

4. **CAN 过滤器**（可选，后续扩展）
   - 设置 CAN ID 过滤规则
   - 只接收特定 ID 的数据

### 2.2 界面布局

参考现有的串口控制界面布局：

```
┌─────────────────────────────────────────────────────────────┐
│  CAN 控制                                                    │
├──────────┬──────────────────────────────────────────────────┤
│ CAN 列表 │  CAN 配置和操作区域                              │
│          │  ┌────────────────────────────────────────────┐  │
│ ● CAN0   │  │ [参数配置] [发送区] [接收区]              │  │
│   CAN1   │  │                                            │  │
│          │  │  参数配置 Tab:                             │  │
│          │  │  - CAN 接口: can0                          │  │
│          │  │  - 波特率: 500000                          │  │
│          │  │  - 状态: DOWN                              │  │
│          │  │  - 帧类型: 标准帧                          │  │
│          │  │                                            │  │
│          │  └────────────────────────────────────────────┘  │
│          │                                                  │
│          │  [打开CAN] [关闭CAN] [保存] [删除] [重置]       │
└──────────┴──────────────────────────────────────────────────┘
```

### 2.3 导航方式

统一使用现有的导航方式（参考 SerialPortControlPage.qml）：

- **区域 0**: CAN 列表区域（左侧）
- **区域 1**: Tab 栏区域（参数配置、发送区、接收区）
- **区域 2**: 参数区域（当前 Tab 的参数）
- **区域 3**: 按钮区域（底部按钮）

**导航逻辑**：
- 上下键：在当前区域内导航
- 左右键：在区域之间切换
- 回车键：确认选择或执行操作

---

## 三、技术实现

### 3.1 后端实现（C++）

#### 3.1.1 CANController 类

创建 `src/control/CANController.h` 和 `src/control/CANController.cpp`

**主要功能**：
1. **CAN 接口管理**
   - 打开/关闭 CAN 接口
   - 配置波特率
   - 查询接口状态

2. **数据收发**
   - 发送 CAN 数据帧
   - 接收 CAN 数据帧
   - 数据格式转换（HEX ↔ Binary）

3. **配置持久化**
   - 保存 CAN 配置到 QSettings
   - 加载 CAN 配置

**关键属性**：
```cpp
class CANController : public QObject {
    Q_OBJECT
    Q_PROPERTY(int currentCanIndex READ currentCanIndex WRITE setCurrentCanIndex NOTIFY currentCanIndexChanged)
    Q_PROPERTY(QString canInterface READ canInterface WRITE setCanInterface NOTIFY canInterfaceChanged)
    Q_PROPERTY(int bitrate READ bitrate WRITE setBitrate NOTIFY bitrateChanged)
    Q_PROPERTY(bool isUp READ isUp NOTIFY isUpChanged)
    Q_PROPERTY(QString frameType READ frameType WRITE setFrameType NOTIFY frameTypeChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    // CAN 接口操作
    Q_INVOKABLE bool openCAN();
    Q_INVOKABLE void closeCAN();
    Q_INVOKABLE bool sendData(const QString &canId, const QString &data);

    // 配置管理
    Q_INVOKABLE void saveConfig();
    Q_INVOKABLE void loadConfig();
    Q_INVOKABLE void resetConfig();

signals:
    void dataReceived(const QString &canId, const QString &data, const QString &timestamp);
    void errorOccurred(const QString &error);
    void statusChanged();
};
```

#### 3.1.2 实现方式

使用 Qt 的 `QProcess` 调用 Linux 命令：

```cpp
// 打开 CAN 接口
bool CANController::openCAN() {
    // 1. 配置波特率
    QProcess process;
    process.start("sudo", QStringList() << "ip" << "link" << "set" << m_canInterface
                  << "type" << "can" << "bitrate" << QString::number(m_bitrate));
    process.waitForFinished();

    // 2. 启动接口
    process.start("sudo", QStringList() << "ip" << "link" << "set" << m_canInterface << "up");
    process.waitForFinished();

    // 3. 启动接收线程
    startReceiveThread();

    return true;
}

// 发送 CAN 数据
bool CANController::sendData(const QString &canId, const QString &data) {
    // 格式：cansend can0 123#DEADBEEF
    QString frame = canId + "#" + data;

    QProcess process;
    process.start("cansend", QStringList() << m_canInterface << frame);
    process.waitForFinished();

    return process.exitCode() == 0;
}

// 接收 CAN 数据（使用 QProcess 持续监听）
void CANController::startReceiveThread() {
    m_receiveProcess = new QProcess(this);
    connect(m_receiveProcess, &QProcess::readyReadStandardOutput, this, &CANController::handleReceiveData);

    m_receiveProcess->start("candump", QStringList() << m_canInterface);
}

void CANController::handleReceiveData() {
    QByteArray data = m_receiveProcess->readAllStandardOutput();
    QString line = QString::fromUtf8(data).trimmed();

    // 解析 candump 输出格式：can0  123   [8]  DE AD BE EF 01 02 03 04
    // 提取 CAN ID、数据长度、数据内容
    // 发送信号 dataReceived()
}
```

### 3.2 前端实现（QML）

#### 3.2.1 文件结构

参考串口控制的文件结构：

```
src/qml/components/device_info/pages/
├── CANControlPage.qml           # CAN 控制主页面
├── CANListPanel.qml             # CAN 列表面板
├── CANConfigPanel.qml           # CAN 配置面板（包含 Tab）
├── CANParamsTab.qml             # 参数配置 Tab
├── CANSendTab.qml               # 发送区 Tab
└── CANReceiveTab.qml            # 接收区 Tab
```

#### 3.2.2 CANControlPage.qml

主页面结构（参考 SerialPortControlPage.qml）：

```qml
Rectangle {
    id: root

    // 属性
    property int currentCanIndex: 0  // 当前选中的 CAN 索引 (0-1)
    property int focusItemIndex: -1
    property int focusSubArea: 0
    property int focusTabIndex: -1
    property int focusParamIndex: 0
    property int focusButtonIndex: 0

    // CAN 数据
    property var canInterfaces: [
        { name: "CAN0", path: "can0", bitrate: 500000 },
        { name: "CAN1", path: "can1", bitrate: 250000 }
    ]

    // NavigationManager 实例
    NavigationManager {
        id: navigationManager
        // 配置导航逻辑
    }

    // 布局
    ColumnLayout {
        // 上部：列表和配置区域
        RowLayout {
            // 左侧：CAN 列表
            Loader {
                id: canListPanel
                source: "CANListPanel.qml"
            }

            // 右侧：CAN 配置和操作区域
            Loader {
                id: canConfigPanel
                source: "CANConfigPanel.qml"
            }
        }

        // 底部：按钮区域
        Rectangle {
            // 打开CAN、关闭CAN、保存、删除、重置
        }
    }
}
```

#### 3.2.3 CANParamsTab.qml

参数配置 Tab（参考 SerialPortParamsTab.qml）：

```qml
Rectangle {
    id: root

    // 参数列表（2列布局）
    GridLayout {
        columns: 2

        // 行0：CAN 接口（只读）、波特率（可编辑）
        Text { text: "CAN 接口:" }
        Text { id: canInterfaceText; text: canController.canInterface }

        Text { text: "波特率:" }
        ComboBox {
            id: bitrateCombo
            model: ["125000", "250000", "500000", "1000000"]
            currentIndex: 2  // 默认 500000
        }

        // 行1：状态（只读）、帧类型（可编辑）
        Text { text: "状态:" }
        Text { id: statusText; text: canController.status }

        Text { text: "帧类型:" }
        ComboBox {
            id: frameTypeCombo
            model: ["标准帧", "扩展帧"]
            currentIndex: 0
        }
    }
}
```

#### 3.2.4 CANSendTab.qml

发送区 Tab：

```qml
Rectangle {
    id: root

    ColumnLayout {
        // CAN ID 输入
        RowLayout {
            Text { text: "CAN ID:" }
            TextField {
                id: canIdInput
                placeholderText: "例如: 123"
            }
        }

        // 数据输入
        RowLayout {
            Text { text: "数据 (HEX):" }
            TextField {
                id: dataInput
                placeholderText: "例如: DEADBEEF"
            }
        }

        // 发送按钮
        Button {
            text: "发送"
            onClicked: {
                canController.sendData(canIdInput.text, dataInput.text)
            }
        }
    }
}
```

#### 3.2.5 CANReceiveTab.qml

接收区 Tab：

```qml
Rectangle {
    id: root

    ColumnLayout {
        // 接收数据列表
        ListView {
            id: receiveListView
            model: receiveModel

            delegate: Rectangle {
                Text {
                    text: model.timestamp + " | " + model.canId + " | " + model.data
                }
            }
        }

        // 清空按钮
        Button {
            text: "清空"
            onClicked: {
                receiveModel.clear()
            }
        }
    }

    // 监听接收信号
    Connections {
        target: canController
        function onDataReceived(canId, data, timestamp) {
            receiveModel.append({
                canId: canId,
                data: data,
                timestamp: timestamp
            })
        }
    }
}
```

### 3.3 集成到 DeviceSettingsDialog

在 `DeviceSettingsDialog.qml` 中添加 CAN 控制选项：

```qml
// 左侧类别列表
ListView {
    model: ListModel {
        ListElement { name: "电机控制"; icon: "⚙️" }
        ListElement { name: "张紧控制"; icon: "🔧" }
        ListElement { name: "制动控制"; icon: "🛑" }
        ListElement { name: "串口控制"; icon: "📡" }
        ListElement { name: "CAN 控制"; icon: "🚌" }  // ✅ 新增
        ListElement { name: "基本配置"; icon: "⚙️" }
    }
}

// 右侧内容区域
Loader {
    id: contentLoader
    source: {
        switch(currentCategory) {
            case 0: return "pages/MotorControlPage.qml"
            case 1: return "pages/TensionControlPage.qml"
            case 2: return "pages/BrakeControlPage.qml"
            case 3: return "pages/SerialPortControlPage.qml"
            case 4: return "pages/CANControlPage.qml"  // ✅ 新增
            case 5: return "pages/BasicConfigPage.qml"
            default: return ""
        }
    }
}
```

---

## 四、实施步骤

### Phase 1: 后端 CANController 基础框架（30分钟）

**任务**：
1. 创建 `src/control/CANController.h` 和 `src/control/CANController.cpp`
2. 定义 CAN 接口管理属性（currentCanIndex、canInterface、bitrate、isUp、frameType、status）
3. 实现配置持久化（saveConfig、loadConfig、resetConfig）
4. 注册到 QML（main.cpp）

**验证**：
- 编译通过
- QML 中可以访问 `canController` 对象

### Phase 2: CAN 接口打开/关闭功能（30分钟）

**任务**：
1. 实现 `openCAN()` 方法（调用 `ip link set` 命令）
2. 实现 `closeCAN()` 方法（调用 `ip link set down` 命令）
3. 实现错误处理（errorOccurred 信号）
4. 实现状态查询（查询接口是否 UP）

**验证**：
- 调用 `openCAN()` 后，CAN 接口状态变为 UP
- 调用 `closeCAN()` 后，CAN 接口状态变为 DOWN

### Phase 3: CAN 数据收发功能（40分钟）

**任务**：
1. 实现 `sendData()` 方法（调用 `cansend` 命令）
2. 实现接收线程（使用 `QProcess` 持续运行 `candump`）
3. 实现数据解析（解析 candump 输出格式）
4. 发送 `dataReceived` 信号

**验证**：
- 调用 `sendData()` 可以发送 CAN 数据
- 接收到 CAN 数据时，触发 `dataReceived` 信号

### Phase 4: 前端界面实现（60分钟）

**任务**：
1. 创建 `CANControlPage.qml`（主页面）
2. 创建 `CANListPanel.qml`（CAN 列表）
3. 创建 `CANConfigPanel.qml`（配置面板，包含 Tab）
4. 创建 `CANParamsTab.qml`（参数配置 Tab）
5. 创建 `CANSendTab.qml`（发送区 Tab）
6. 创建 `CANReceiveTab.qml`（接收区 Tab）

**验证**：
- 界面显示正常
- 可以切换 CAN 接口
- 可以切换 Tab

### Phase 5: 导航功能集成（30分钟）

**任务**：
1. 在 `CANControlPage.qml` 中集成 `NavigationManager`
2. 实现键盘导航（上下左右键）
3. 实现焦点指示器
4. 实现回车键处理

**验证**：
- 可以使用键盘导航
- 焦点指示器正常显示
- 回车键可以执行操作

### Phase 6: 集成到 DeviceSettingsDialog（20分钟）

**任务**：
1. 在 `DeviceSettingsDialog.qml` 中添加 "CAN 控制" 类别
2. 配置 Loader 加载 `CANControlPage.qml`
3. 测试类别切换

**验证**：
- 可以切换到 "CAN 控制" 类别
- 界面显示正常

### Phase 7: 功能测试（30分钟）

**任务**：
1. 测试 CAN 接口打开/关闭
2. 测试 CAN 数据发送
3. 测试 CAN 数据接收
4. 测试配置保存/加载
5. 测试键盘导航

**验证**：
- 所有功能正常工作
- 无崩溃或错误

### Phase 8: 文档编写和 Git 提交（30分钟）

**任务**：
1. 创建实施文档（7个 Phase 文档）
2. 创建工作日报
3. Git 提交代码和文档
4. 推送到 GitLab 和 GitHub

---

## 五、技术要点

### 5.1 权限问题

CAN 接口操作需要 root 权限，有两种解决方案：

**方案 1: 使用 sudo（推荐）**
```cpp
QProcess process;
process.start("sudo", QStringList() << "ip" << "link" << "set" << "can0" << "up");
```

**方案 2: 配置 sudoers 免密码**
```bash
# 编辑 /etc/sudoers.d/can-control
linaro ALL=(ALL) NOPASSWD: /sbin/ip link set can*
linaro ALL=(ALL) NOPASSWD: /usr/bin/cansend
```

### 5.2 数据格式

**CAN 数据帧格式**：
- 标准帧：11 位 ID（0x000 - 0x7FF）
- 扩展帧：29 位 ID（0x00000000 - 0x1FFFFFFF）
- 数据长度：0-8 字节

**candump 输出格式**：
```
can0  123   [8]  DE AD BE EF 01 02 03 04
│     │     │    │
│     │     │    └─ 数据内容（HEX）
│     │     └─ 数据长度
│     └─ CAN ID（HEX）
└─ CAN 接口
```

### 5.3 错误处理

常见错误：
1. **接口不存在**: 检查 CAN 接口是否存在
2. **权限不足**: 使用 sudo 或配置 sudoers
3. **接口已启动**: 先关闭再打开
4. **波特率不支持**: 检查硬件支持的波特率范围

---

## 六、预期成果

### 6.1 代码统计

- **后端代码**: 约 800 行（CANController.h + CANController.cpp）
- **前端代码**: 约 600 行（6 个 QML 文件）
- **文档**: 8 个 Markdown 文件
- **总计**: 约 1400 行代码 + 8 个文档

### 6.2 功能清单

- ✅ CAN 接口管理（打开/关闭）
- ✅ 波特率配置（125k、250k、500k、1000k）
- ✅ CAN 数据发送（标准帧、扩展帧）
- ✅ CAN 数据接收（实时显示）
- ✅ 配置持久化（保存/加载/重置）
- ✅ 键盘导航（上下左右键、回车键）
- ✅ 焦点指示器
- ✅ 错误提示

### 6.3 用户体验

- 界面布局与串口控制保持一致
- 导航方式统一，易于使用
- 实时显示 CAN 数据，便于调试
- 配置持久化，重启后自动恢复

---

## 七、后续扩展

### 7.1 CAN 过滤器

支持设置 CAN ID 过滤规则，只接收特定 ID 的数据。

### 7.2 CAN-FD 支持

支持 CAN-FD（CAN with Flexible Data-Rate），数据长度最多 64 字节。

### 7.3 CAN 数据分析

支持 CAN 数据统计、波形显示、协议解析等高级功能。

### 7.4 CAN 数据录制

支持录制 CAN 数据到文件，便于后续分析。

---

**编写人员**: Claude Sonnet 4.5
**审核状态**: ✅ 待审核
**最后更新**: 2026-02-07
