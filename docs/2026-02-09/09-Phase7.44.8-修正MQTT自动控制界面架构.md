# Phase 7.44.8 - 修正MQTT自动控制界面架构

**日期**: 2026-02-09
**阶段**: Phase 7.44.8
**类型**: 架构修正

---

## 一、问题描述

### 1.1 原设计错误

**错误理解**：
- ❌ 在"自动控制"Tab中同时显示所有8个模块的数据
- ❌ 开关量模块1和模块2一起显示
- ❌ 模拟量模块3和模块4一起显示

**正确理解**：
- ✅ 用户在模块列表中选择一个模块（模块1-8）
- ✅ 切换到"自动控制"Tab
- ✅ 根据选中的模块类型，显示对应的数据

### 1.2 8个模块对应关系

| 模块编号 | 模块名称 | 模块类型 | 数据内容 |
|---------|---------|---------|---------|
| 模块1 | 开关量输入1 | DI | 8位开关量 |
| 模块2 | 开关量输入2 | DI | 8位开关量 |
| 模块3 | 模拟量输入1 | AI | 8通道×16位AD |
| 模块4 | 模拟量输入2 | AI | 8通道×16位AD |
| 模块5 | CS1 | CS | 急停状态+通讯 |
| 模块6 | CS2 | CS | 急停状态+通讯 |
| 模块7 | 语音模块 | Voice | 语音播报控制 |
| 模块8 | 预留模块 | Reserved | 待定义 |

---

## 二、修正方案

### 2.1 界面流程

```
用户操作流程：
1. 在左侧模块列表选择"模块1"
   ↓
2. 切换到"自动控制"Tab
   ↓
3. 显示"开关量输入1"的数据（8位LED）
   ↓
4. 用户在模块列表选择"模块3"
   ↓
5. 界面自动切换显示"模拟量输入1"的数据（8通道）
```

### 2.2 界面架构

```
MQTTAutoControlTab
    ├─ 标题栏
    │   ├─ 模块信息（模块1: 开关量输入1）
    │   ├─ 连接状态（已连接/未连接）
    │   ├─ 健康状态（正常/数据超时）
    │   └─ 控制按钮（自动连接、数据采集、重连、启动/停止）
    │
    └─ 内容区域（StackLayout - 根据模块类型切换）
        ├─ [0] DIModulePanel（开关量，模块1-2）
        ├─ [1] AIModulePanel（模拟量，模块3-4）
        ├─ [2] CSModulePanel（CS模块，模块5-6）
        ├─ [3] VoiceModulePanel（语音，模块7）
        └─ [4] ReservedModulePanel（预留，模块8）
```

---

## 三、修改内容

### 3.1 MQTTAutoControlTab.qml（重新设计）

**文件**: `src/qml/components/device_info/pages/MQTTAutoControlTab.qml`

**关键修改**:

1. **添加属性**:
```qml
property var currentModule: null  // 当前选中的模块
property int currentModuleIndex: 0  // 当前模块索引 (0-7)
```

2. **模块类型判断函数**:
```qml
function getModuleType() {
    if (currentModuleIndex < 2) {
        return "di"  // 开关量
    } else if (currentModuleIndex < 4) {
        return "ai"  // 模拟量
    } else if (currentModuleIndex < 6) {
        return "cs"  // CS模块
    } else if (currentModuleIndex === 6) {
        return "voice"  // 语音模块
    } else {
        return "reserved"  // 预留
    }
}
```

3. **StackLayout 根据模块类型切换**:
```qml
StackLayout {
    currentIndex: {
        var type = getModuleType()
        if (type === "di") return 0
        if (type === "ai") return 1
        if (type === "cs") return 2
        if (type === "voice") return 3
        return 4  // reserved
    }

    // 开关量显示 (模块1-2)
    DIModulePanel {
        moduleIndex: currentModuleIndex
        moduleName: getModuleName()
        bitsData: {
            if (!diDataManager) return []
            if (currentModuleIndex === 0) {
                return diDataManager.module1Data
            } else if (currentModuleIndex === 1) {
                return diDataManager.module2Data
            }
            return []
        }
    }

    // 模拟量显示 (模块3-4)
    AIModulePanel {
        moduleIndex: currentModuleIndex
        moduleName: getModuleName()
        channelsData: {
            if (!aiDataManager) return []
            if (currentModuleIndex === 2) {
                return aiDataManager.module3Data
            } else if (currentModuleIndex === 3) {
                return aiDataManager.module4Data
            }
            return []
        }
    }

    // CS模块显示 (模块5-6)
    CSModulePanel {
        moduleIndex: currentModuleIndex
        moduleName: getModuleName()
    }

    // 语音模块显示 (模块7)
    VoiceModulePanel {
        moduleIndex: currentModuleIndex
        moduleName: getModuleName()
    }

    // 预留模块显示 (模块8)
    ReservedModulePanel {
        moduleIndex: currentModuleIndex
        moduleName: getModuleName()
    }
}
```

### 3.2 MQTTConfigPanel.qml

**文件**: `src/qml/components/device_info/pages/MQTTConfigPanel.qml`

**修改内容**:
```qml
onLoaded: {
    console.log("✅ [MQTTConfigPanel] MQTTAutoControlTab 加载成功")
    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
    item.currentModule = Qt.binding(function() { return root.currentModule })
    // 从currentModule获取模块索引
    if (root.currentModule && root.currentModule.index !== undefined) {
        item.currentModuleIndex = Qt.binding(function() { return root.currentModule.index })
    }
}
```

### 3.3 新增组件

**文件**:
- `src/qml/components/device_info/pages/CSModulePanel.qml`
- `src/qml/components/device_info/pages/VoiceModulePanel.qml`
- `src/qml/components/device_info/pages/ReservedModulePanel.qml`

**功能**:
- CS模块：显示急停状态、通讯数据（占位，待实施）
- 语音模块：显示播报状态、控制（占位，待实施）
- 预留模块：占位提示

### 3.4 修改组件

**文件**:
- `src/qml/components/device_info/pages/DIModulePanel.qml`
- `src/qml/components/device_info/pages/AIModulePanel.qml`

**修改内容**:
- 移除连接状态显示（已在标题栏显示）
- 简化布局

---

## 四、界面效果

### 4.1 选择模块1（开关量输入1）

```
┌─────────────────────────────────────────────────────────────┐
│  模块1: 开关量输入1  [●已连接]  状态: 正常  重连: 0次       │
│  [自动连接: ON] [数据采集: ON] [重新连接] [启动全部] [停止] │
├─────────────────────────────────────────────────────────────┤
│  开关量输入1                                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  位0   位1   位2   位3   位4   位5   位6   位7      │   │
│  │  [●]   [○]   [●]   [●]   [○]   [○]   [●]   [○]     │   │
│  │  ON    OFF   ON    ON    OFF   OFF   ON    OFF      │   │
│  │                                                      │   │
│  │  字节值: B2h (178)  二进制: 1011 0010                │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 选择模块3（模拟量输入1）

```
┌─────────────────────────────────────────────────────────────┐
│  模块3: 模拟量输入1  [●已连接]  状态: 正常  重连: 0次       │
│  [自动连接: ON] [数据采集: ON] [重新连接] [启动全部] [停止] │
├─────────────────────────────────────────────────────────────┤
│  模拟量输入1                                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  [通道0: 32768 / 10.00V] [通道1: 40000 / 12.21V]    │   │
│  │  [通道2: 50000 / 15.26V] [通道3: 55000 / 16.79V]    │   │
│  │  [通道4: 45000 / 13.73V] [通道5: 35000 / 10.68V]    │   │
│  │  [通道6: 25000 / 7.63V]  [通道7: 20000 / 6.10V]     │   │
│  │                                                      │   │
│  │  最小值: 6.10V  最大值: 16.79V  平均值: 11.29V      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 4.3 选择模块5（CS1）

```
┌─────────────────────────────────────────────────────────────┐
│  模块5: CS1  [●已连接]  状态: 正常  重连: 0次               │
│  [自动连接: ON] [数据采集: ON] [重新连接] [启动全部] [停止] │
├─────────────────────────────────────────────────────────────┤
│  CS1 - 沿线急停状态监控                                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  ⚠️ CS模块功能待实施                                 │   │
│  │  此模块用于监控沿线急停状态和主机通讯数据             │   │
│  │                                                      │   │
│  │  急停状态：                                          │   │
│  │  • 急停位置1: 正常                                   │   │
│  │  • 急停位置2: 正常                                   │   │
│  │  • 急停位置3: 正常                                   │   │
│  │  • 通讯状态: 在线                                    │   │
│  │  • 信号强度: 85%                                     │   │
│  │                                                      │   │
│  │  （模拟数据，实际功能待实施）                         │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 五、数据绑定逻辑

### 5.1 开关量数据绑定（模块1-2）

```qml
DIModulePanel {
    moduleIndex: currentModuleIndex  // 0 或 1
    moduleName: getModuleName()      // "开关量输入1" 或 "开关量输入2"
    bitsData: {
        if (!diDataManager) return []
        if (currentModuleIndex === 0) {
            return diDataManager.module1Data  // 模块1的数据
        } else if (currentModuleIndex === 1) {
            return diDataManager.module2Data  // 模块2的数据
        }
        return []
    }
}
```

### 5.2 模拟量数据绑定（模块3-4）

```qml
AIModulePanel {
    moduleIndex: currentModuleIndex  // 2 或 3
    moduleName: getModuleName()      // "模拟量输入1" 或 "模拟量输入2"
    channelsData: {
        if (!aiDataManager) return []
        if (currentModuleIndex === 2) {
            return aiDataManager.module3Data  // 模块3的数据
        } else if (currentModuleIndex === 3) {
            return aiDataManager.module4Data  // 模块4的数据
        }
        return []
    }
}
```

### 5.3 其他模块（模块5-8）

```qml
// CS模块（模块5-6）
CSModulePanel {
    moduleIndex: currentModuleIndex  // 4 或 5
    moduleName: getModuleName()      // "CS1" 或 "CS2"
}

// 语音模块（模块7）
VoiceModulePanel {
    moduleIndex: currentModuleIndex  // 6
    moduleName: getModuleName()      // "语音模块"
}

// 预留模块（模块8）
ReservedModulePanel {
    moduleIndex: currentModuleIndex  // 7
    moduleName: getModuleName()      // "预留模块"
}
```

---

## 六、修改文件清单

### 6.1 重新设计的文件

1. **MQTTAutoControlTab.qml**
   - 添加 currentModule 和 currentModuleIndex 属性
   - 添加模块类型判断函数
   - 使用 StackLayout 根据模块类型切换显示
   - 标题栏显示当前模块信息

### 6.2 新增组件

2. **CSModulePanel.qml**
   - CS模块显示组件
   - 急停状态监控（占位）

3. **VoiceModulePanel.qml**
   - 语音模块显示组件
   - 语音播报控制（占位）

4. **ReservedModulePanel.qml**
   - 预留模块显示组件
   - 占位提示

### 6.3 修改的文件

5. **MQTTConfigPanel.qml**
   - 传递 currentModule 和 currentModuleIndex 到 MQTTAutoControlTab

6. **DIModulePanel.qml**
   - 移除连接状态显示（已在标题栏）

7. **AIModulePanel.qml**
   - 移除连接状态显示（已在标题栏）

---

## 七、使用流程

### 7.1 查看开关量模块

1. 在模块列表选择"模块1"或"模块2"
2. 切换到"自动控制"Tab
3. 看到8个LED指示灯显示开关量状态
4. 看到字节值和二进制显示

### 7.2 查看模拟量模块

1. 在模块列表选择"模块3"或"模块4"
2. 切换到"自动控制"Tab
3. 看到8个通道的AD值和电压值
4. 看到颜色编码和进度条
5. 看到统计信息（最小值、最大值、平均值）

### 7.3 查看CS模块

1. 在模块列表选择"模块5"或"模块6"
2. 切换到"自动控制"Tab
3. 看到CS模块占位界面（待实施）

### 7.4 查看语音模块

1. 在模块列表选择"模块7"
2. 切换到"自动控制"Tab
3. 看到语音模块占位界面（待实施）

### 7.5 查看预留模块

1. 在模块列表选择"模块8"
2. 切换到"自动控制"Tab
3. 看到预留模块占位界面

---

## 八、测试验证

### 8.1 测试步骤

1. **启动EMQX和模拟器**:
```powershell
docker start emqx
# 启动MQTTX模拟器，创建8个连接
```

2. **启动主机应用**:
   - 打开设备信息对话框
   - 选择"MQTT"类别

3. **测试模块1（开关量）**:
   - 在模块列表选择"模块1"
   - 切换到"自动控制"Tab
   - 验证LED灯显示正确
   - 在MQTTX中修改数据，验证LED实时更新

4. **测试模块3（模拟量）**:
   - 在模块列表选择"模块3"
   - 切换到"自动控制"Tab
   - 验证8通道数值显示正确
   - 在MQTTX中修改数据，验证数值实时更新

5. **测试模块5-8**:
   - 依次选择模块5、6、7、8
   - 验证显示对应的占位界面

### 8.2 预期结果

- ✅ 选择不同模块，界面自动切换显示对应内容
- ✅ 开关量模块显示LED灯
- ✅ 模拟量模块显示数值和进度条
- ✅ CS/语音/预留模块显示占位界面
- ✅ 数据实时更新
- ✅ 连接状态正确显示

---

## 九、总结

### 9.1 修正内容

- ✅ 重新设计 MQTTAutoControlTab 架构
- ✅ 根据模块类型动态切换显示内容
- ✅ 新增 CS/Voice/Reserved 组件
- ✅ 修正数据绑定逻辑
- ✅ 优化界面布局

### 9.2 核心改进

**修正前**：
- ❌ 同时显示所有模块数据
- ❌ 界面混乱，信息过载

**修正后**：
- ✅ 根据选中模块显示对应数据
- ✅ 界面清晰，信息聚焦
- ✅ 符合用户操作习惯

### 9.3 文件统计

| 类型 | 数量 | 说明 |
|-----|------|------|
| 重新设计 | 1个 | MQTTAutoControlTab.qml |
| 新增组件 | 3个 | CS/Voice/Reserved |
| 修改文件 | 3个 | MQTTConfigPanel + DI/AI Panel |
| **总计** | **7个** | - |

---

**文档版本**: v1.0
**最后更新**: 2026-02-09
**用时**: 约30分钟
