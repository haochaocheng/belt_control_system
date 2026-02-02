# QDS 参数持久化调试方案

**日期**: 2026-02-02
**任务编号**: FIX 100.300.112.8.22 - QDS 集成
**状态**: 📋 方案设计

---

## 🎯 目标

实现在 Qt Design Studio (QDS) 中调试参数持久化功能，避免每次修改都需要编译部署到设备上测试，提高开发效率。

---

## 📊 当前状态分析

### 现有 QDS 支持

**已实现**:
- ✅ QDS 项目配置文件：`BeltControlSystem.qmlproject`
- ✅ QDS 专用入口：`main_qds.qml`
- ✅ 模拟后端：`MockBackend.qml`
- ✅ 基本后端对象模拟：
  - `commonControl` - 设备控制
  - `deviceInfoController` - 设备信息
  - `sipPhoneManager` - SIP 电话
  - `audioManagementController` - 音频管理
  - `systemConfig` - 系统配置
  - `operationLogDB` - 操作日志
  - `runtimeTracker` - 运行时跟踪
  - `deviceConfigMgr` - 设备配置管理器（**基础版本**）

### 缺失的功能

**deviceConfigMgr 缺少的方法**:
- ❌ `saveMotorConfig(deviceId, motorIndex, tabIndex, config)` - 保存电机配置
- ❌ `loadMotorConfig(deviceId, motorIndex, tabIndex)` - 加载电机配置
- ❌ `loadAllMotorConfigs(deviceId, motorIndex)` - 加载电机所有配置
- ❌ `saveBrakeConfig(deviceId, brakeIndex, config)` - 保存制动器配置
- ❌ `loadBrakeConfig(deviceId, brakeIndex)` - 加载制动器配置
- ❌ `loadAllBrakeConfigs(deviceId)` - 加载所有制动器配置
- ❌ `saveTensionConfig(deviceId, tensionIndex, config)` - 保存张紧控制配置
- ❌ `loadTensionConfig(deviceId, tensionIndex)` - 加载张紧控制配置
- ❌ `loadAllTensionConfigs(deviceId)` - 加载所有张紧控制配置

---

## 🔧 实施方案

### 方案 A: 内存模拟（推荐）⭐

**原理**: 在 MockBackend.qml 中使用 JavaScript 对象模拟数据库存储，数据保存在内存中。

**优点**:
- ✅ 实现简单，无需外部依赖
- ✅ 完全在 QDS 中运行，无需编译
- ✅ 可以快速验证 UI 逻辑和数据流
- ✅ 支持实时修改和调试

**缺点**:
- ❌ 数据不持久化（刷新后丢失）
- ❌ 无法测试真实的数据库操作
- ❌ 无法测试跨会话的持久化

**适用场景**:
- UI 布局调试
- 参数收集和应用逻辑验证
- 快速迭代开发

**实施步骤**:
1. 在 MockBackend.qml 中添加内存存储对象
2. 实现所有参数持久化方法
3. 使用 JavaScript Map 或对象存储配置数据
4. 在 QDS 中测试保存和加载功能

---

### 方案 B: LocalStorage 持久化

**原理**: 使用 Qt Quick LocalStorage API 将数据保存到本地 SQLite 数据库。

**优点**:
- ✅ 数据持久化（刷新后保留）
- ✅ 使用真实的 SQLite 数据库
- ✅ 可以测试跨会话的持久化
- ✅ 完全在 QDS 中运行

**缺点**:
- ❌ 实现复杂度较高
- ❌ 需要编写 SQL 语句
- ❌ LocalStorage API 与 C++ QSqlDatabase 有差异
- ❌ 可能遇到 LocalStorage 限制

**适用场景**:
- 需要测试持久化逻辑
- 需要跨会话保留数据
- 需要验证数据库操作

**实施步骤**:
1. 在 MockBackend.qml 中导入 QtQuick.LocalStorage
2. 创建数据库表结构
3. 实现所有参数持久化方法
4. 在 QDS 中测试保存和加载功能

---

### 方案 C: 混合模式（最佳实践）⭐⭐⭐

**原理**: 结合方案 A 和方案 B，提供开关切换。

**优点**:
- ✅ 灵活性高，可根据需求切换
- ✅ 快速开发时使用内存模拟
- ✅ 需要持久化测试时使用 LocalStorage
- ✅ 最接近真实环境

**缺点**:
- ❌ 实现复杂度最高
- ❌ 需要维护两套实现

**适用场景**:
- 完整的开发和测试流程
- 需要在不同阶段使用不同模式

**实施步骤**:
1. 实现方案 A（内存模拟）
2. 实现方案 B（LocalStorage）
3. 添加模式切换开关
4. 在 QDS 中测试两种模式

---

## 💡 推荐实施方案：方案 A（内存模拟）

### 实施详情

#### 1. 修改 MockBackend.qml

**位置**: `src/qml/MockBackend.qml` - Lines 227-248

**添加内容**:

```qml
// ✅ 2026-02-02 [参数持久化]: 扩展 deviceConfigMgr 对象，支持参数持久化
property QtObject deviceConfigMgr: QtObject {
    // ========== 内存存储 ==========
    // 使用 JavaScript 对象模拟数据库存储
    property var motorConfigStorage: ({})  // 格式: "deviceId_motorIndex_tabIndex" -> config
    property var brakeConfigStorage: ({})  // 格式: "deviceId_brakeIndex" -> config
    property var tensionConfigStorage: ({})  // 格式: "deviceId_tensionIndex" -> config

    // ========== 电机配置方法 ==========
    function saveMotorConfig(deviceId, motorIndex, tabIndex, config) {
        var key = deviceId + "_" + motorIndex + "_" + tabIndex
        console.log("✅ [MockBackend] 保存电机配置:", key, JSON.stringify(config))
        motorConfigStorage[key] = config
        return true
    }

    function loadMotorConfig(deviceId, motorIndex, tabIndex) {
        var key = deviceId + "_" + motorIndex + "_" + tabIndex
        var config = motorConfigStorage[key]
        console.log("✅ [MockBackend] 加载电机配置:", key, config ? "找到" : "未找到")
        return config || {}
    }

    function loadAllMotorConfigs(deviceId, motorIndex) {
        console.log("✅ [MockBackend] 加载电机所有配置:", deviceId, motorIndex)
        var configs = []
        for (var i = 0; i < 10; i++) {  // 10个Tab
            var key = deviceId + "_" + motorIndex + "_" + i
            if (motorConfigStorage[key]) {
                configs.push(motorConfigStorage[key])
            }
        }
        return configs
    }

    // ========== 制动器配置方法 ==========
    function saveBrakeConfig(deviceId, brakeIndex, config) {
        var key = deviceId + "_" + brakeIndex
        console.log("✅ [MockBackend] 保存制动器配置:", key, JSON.stringify(config))
        brakeConfigStorage[key] = config
        return true
    }

    function loadBrakeConfig(deviceId, brakeIndex) {
        var key = deviceId + "_" + brakeIndex
        var config = brakeConfigStorage[key]
        console.log("✅ [MockBackend] 加载制动器配置:", key, config ? "找到" : "未找到")
        return config || {}
    }

    function loadAllBrakeConfigs(deviceId) {
        console.log("✅ [MockBackend] 加载所有制动器配置:", deviceId)
        var configs = []
        for (var i = 0; i < 4; i++) {  // 4个制动器
            var key = deviceId + "_" + i
            if (brakeConfigStorage[key]) {
                configs.push(brakeConfigStorage[key])
            }
        }
        return configs
    }

    // ========== 张紧控制配置方法 ==========
    function saveTensionConfig(deviceId, tensionIndex, config) {
        var key = deviceId + "_" + tensionIndex
        console.log("✅ [MockBackend] 保存张紧控制配置:", key, JSON.stringify(config))
        tensionConfigStorage[key] = config
        return true
    }

    function loadTensionConfig(deviceId, tensionIndex) {
        var key = deviceId + "_" + tensionIndex
        var config = tensionConfigStorage[key]
        console.log("✅ [MockBackend] 加载张紧控制配置:", key, config ? "找到" : "未找到")
        return config || {}
    }

    function loadAllTensionConfigs(deviceId) {
        console.log("✅ [MockBackend] 加载所有张紧控制配置:", deviceId)
        var configs = []
        for (var i = 0; i < 2; i++) {  // 2个张紧装置
            var key = deviceId + "_" + i
            if (tensionConfigStorage[key]) {
                configs.push(tensionConfigStorage[key])
            }
        }
        return configs
    }

    // ========== 原有方法（保持不变）==========
    function loadDeviceConfig(deviceId) {
        console.log("模拟：加载设备配置", deviceId)
        return {}
    }

    function saveDeviceConfig(deviceId, config) {
        console.log("模拟：保存设备配置", deviceId, config)
    }

    function loadAllDigitalProtections(deviceId) {
        console.log("模拟：加载设备", deviceId, "的开关量保护配置")
        return []
    }

    function loadAllAnalogProtections(deviceId) {
        console.log("模拟：加载设备", deviceId, "的模拟量保护配置")
        return []
    }
}
```

#### 2. 在 QDS 中测试

**步骤**:
1. 打开 Qt Design Studio
2. 打开项目：`src/qml/BeltControlSystem.qmlproject`
3. 运行 `main_qds.qml`
4. 导航到设备设置对话框
5. 测试参数保存和加载功能

**验证点**:
- ✅ 点击"保存"按钮，控制台输出保存日志
- ✅ 切换电机或Tab，控制台输出加载日志
- ✅ 修改参数后保存，切换后再切换回来，参数应该被正确加载
- ✅ 刷新 QDS 预览，数据会丢失（符合内存模拟预期）

---

## 🎯 使用流程

### 开发流程

1. **在 QDS 中快速迭代**
   - 修改 QML 代码
   - 在 QDS 中实时预览
   - 测试 UI 布局和交互逻辑
   - 验证参数收集和应用逻辑

2. **在设备上完整测试**
   - 编译部署到设备：`.\build-ubuntu24-apt.ps1 188`
   - 测试真实的数据库持久化
   - 验证跨会话的数据保留
   - 测试性能和稳定性

### 调试流程

**QDS 调试**（快速）:
- 修改 QML → 保存 → QDS 自动刷新 → 立即看到效果
- 适用于：UI 调整、参数字段修改、逻辑验证

**设备调试**（完整）:
- 修改代码 → 编译 → 部署 → 测试 → 查看日志
- 适用于：数据库操作、持久化验证、性能测试

---

## 📊 效率对比

| 操作 | QDS 调试 | 设备调试 |
|------|----------|----------|
| 修改 QML | 保存即生效 | 需要重新编译 |
| 查看效果 | 立即显示 | 2-3 分钟 |
| 测试参数收集 | ✅ 支持 | ✅ 支持 |
| 测试参数应用 | ✅ 支持 | ✅ 支持 |
| 测试数据库持久化 | ❌ 不支持 | ✅ 支持 |
| 测试跨会话保留 | ❌ 不支持 | ✅ 支持 |
| 适用阶段 | 开发阶段 | 测试阶段 |

---

## 💡 最佳实践

### 开发阶段（使用 QDS）

1. **UI 布局调整**
   - 在 QDS 中调整控件位置、大小、样式
   - 实时预览效果
   - 快速迭代

2. **参数字段修改**
   - 添加/删除参数字段
   - 修改 collectConfig() 和 applyConfig() 方法
   - 在 QDS 中验证逻辑

3. **交互逻辑验证**
   - 测试保存按钮点击
   - 测试切换电机/Tab时的自动加载
   - 验证参数收集和应用流程

### 测试阶段（使用设备）

1. **数据库持久化测试**
   - 保存参数后重启应用
   - 验证参数是否正确加载
   - 测试数据库操作性能

2. **完整功能测试**
   - 测试所有 Tab 的保存和加载
   - 测试多个电机的配置
   - 测试制动器和张紧控制

3. **稳定性测试**
   - 长时间运行测试
   - 大量数据保存测试
   - 异常情况处理测试

---

## 🔗 相关文档

- [BeltControlSystem.qmlproject](../../src/qml/BeltControlSystem.qmlproject)
- [main_qds.qml](../../src/qml/main_qds.qml)
- [MockBackend.qml](../../src/qml/MockBackend.qml)
- [10-FIX100.300.112.8.22-Phase1完成-MotorControlPage和BasicConfigTab集成.md](./10-FIX100.300.112.8.22-Phase1完成-MotorControlPage和BasicConfigTab集成.md)

---

## 📦 下一步行动

### 立即实施

1. ✅ 修改 MockBackend.qml，添加参数持久化方法
2. ✅ 在 QDS 中测试 MotorControlPage 的保存和加载功能
3. ✅ 验证 BasicConfigTab 的 collectConfig() 和 applyConfig() 方法
4. ⏳ 继续实施其他 Tab 组件的集成

### 后续优化（可选）

1. ⏳ 实现 LocalStorage 持久化（方案 B）
2. ⏳ 添加模式切换开关（方案 C）
3. ⏳ 创建 QDS 调试指南文档

---

**创建日期**: 2026-02-02
**状态**: 📋 方案设计完成，待实施
**编写人员**: Claude Sonnet 4.5
