# QDS 设计规范和迁移计划

**日期**：2026-01-25
**目标**：将所有页面改为 QDS 设计，提升开发效率和设计质量

---

## 📋 设计规范

### 1. 文件命名规范

**QDS 设计文件**：
- 主页面：`PageName.qml`（如 `MotorControlPage.qml`）
- 子组件：`ComponentName.qml`（如 `MyMotorListPanel.qml`）
- 避免使用中文文件名

**目录结构**：
```
src/qml/
├── pages/                    # 主页面
│   ├── ControlPanel.qml
│   ├── ParameterSettings.qml
│   └── AlarmPage.qml
├── components/               # 可复用组件
│   ├── common/              # 通用组件
│   ├── control_panel/       # 控制面板组件
│   ├── device_info/         # 设备信息组件
│   └── sip_phone/           # SIP 电话组件
└── assets/                  # 资源文件
    └── images/              # 图片资源
```

### 2. 组件设计规范

#### 必须包含的属性

```qml
Rectangle {
    id: root
    width: 800   // 默认宽度（用于QDS预览）
    height: 600  // 默认高度（用于QDS预览）

    // ========== 公开属性 ==========
    property int someProperty: 0

    // ========== 信号 ==========
    signal someSignal(int value)

    // ========== 内容 ==========
    // ...
}
```

#### 颜色规范（工业科技感主题）

```qml
// 背景色
"#1a1f2e"  // 深蓝灰（主背景）
"#252b3d"  // 中蓝灰（卡片背景）
"#2d3548"  // 浅蓝灰（输入框背景）

// 强调色
"#2196F3"  // 科技蓝（主要强调色）
"#4CAF50"  // 绿色（成功/激活）
"#FF9800"  // 橙色（警告）
"#F44336"  // 红色（错误/危险）

// 文字色
"#E0E0E0"  // 主文字（浅灰）
"#9E9E9E"  // 次要文字（中灰）
"#616161"  // 禁用文字（深灰）

// 边框色
"#3d4556"  // 默认边框
"#2196F3"  // 激活边框
```

#### 字体规范

```qml
// 标题
font.pixelSize: 18
font.weight: Font.Bold

// 正文
font.pixelSize: 14
font.weight: Font.Normal

// 小字
font.pixelSize: 12
font.weight: Font.Normal
```

### 3. 组件加载规范

**使用 Loader 加载子组件**（QDS 兼容）：

```qml
Loader {
    id: componentLoader
    width: 200
    height: 400
    source: "SubComponent.qml"

    onLoaded: {
        // 绑定属性
        item.someProperty = Qt.binding(function() {
            return root.someValue
        })

        // 连接信号
        item.someSignal.connect(function(value) {
            root.handleSignal(value)
        })
    }
}
```

### 4. 布局规范

**优先使用**：
- `anchors` - 相对定位
- `Row` / `Column` - 简单线性布局
- `Grid` - 网格布局

**避免使用**（QDS 支持有限）：
- `RowLayout` / `ColumnLayout` - 复杂布局
- `GridLayout` - 复杂网格

**示例**：
```qml
Row {
    anchors.fill: parent
    spacing: 20

    Rectangle {
        width: 200
        height: parent.height
        // 左侧内容
    }

    Rectangle {
        width: parent.width - 220
        height: parent.height
        // 右侧内容
    }
}
```

---

## 🗓️ 迁移计划

### Phase 1：新页面直接用 QDS（立即执行）✅

**已完成**：
- ✅ 电机控制页面（MotorControlPage.qml）
- ✅ 电机列表组件（MyMotorListPanel.qml）
- ✅ 基本配置 Tab（BasicConfigTab.qml）
- ✅ 电流保护 Tab（CurrentProtectionTab.qml）
- ✅ 配置面板（MotorConfigPanel.qml）

**待开发**：
- ⏳ 其他 8 种保护类型 Tab
- ⏳ 设备信息详情页面
- ⏳ 网络配置页面

### Phase 2：简单页面迁移（优先级高）

**目标页面**：
1. **开关量输入页面**（SwitchInputPage.qml）
   - 当前状态：已有代码实现
   - 迁移难度：⭐⭐（中等）
   - 预计工作量：2-3 小时

2. **模拟量输入页面**（AnalogInputPage.qml）
   - 当前状态：已有代码实现
   - 迁移难度：⭐⭐（中等）
   - 预计工作量：2-3 小时

3. **设备操作日志**（DeviceOperationLog.qml）
   - 当前状态：已有代码实现
   - 迁移难度：⭐（简单）
   - 预计工作量：1-2 小时

### Phase 3：复杂页面迁移（优先级中）

**目标页面**：
1. **控制面板**（ControlPanel.qml）
   - 当前状态：已有代码实现
   - 迁移难度：⭐⭐⭐（复杂）
   - 预计工作量：4-6 小时
   - 包含子组件：
     - BeltScene3D.qml（3D 场景，暂不迁移）
     - DeviceStatusPanel.qml
     - ProtectionPanel.qml
     - OutputDevicePanel.qml

2. **参数设置**（ParameterSettings.qml）
   - 当前状态：已有代码实现
   - 迁移难度：⭐⭐⭐（复杂）
   - 预计工作量：4-6 小时
   - 包含子组件：
     - BasicParametersSection.qml
     - NetworkParametersSection.qml
     - MasterControlSection.qml

3. **报警页面**（AlarmPage.qml）
   - 当前状态：已有代码实现
   - 迁移难度：⭐⭐（中等）
   - 预计工作量：2-3 小时

### Phase 4：特殊页面评估（优先级低）

**暂不迁移**：
1. **Input1 页面**（Input1Page.qml）
   - 原因：已有完整的 Figma 导出设计
   - 建议：保持现状，除非需要大改

2. **SIP 电话组件**
   - 原因：功能复杂，交互逻辑多
   - 建议：保持现状，仅迁移 UI 部分

3. **3D 场景**（BeltScene3D.qml）
   - 原因：QDS 不支持 3D
   - 建议：保持代码实现

---

## 🛠️ 迁移步骤模板

### 步骤 1：分析现有页面

```bash
# 查看现有页面结构
cat src/qml/pages/PageName.qml

# 识别：
# - 静态 UI 元素（可用 QDS 设计）
# - 动态逻辑（需保留代码）
# - 数据绑定（需保留代码）
```

### 步骤 2：在 QDS 中创建新页面

1. 打开 QDS
2. 创建新的 QML 文件
3. 设置默认宽度和高度
4. 设计布局结构
5. 添加静态元素
6. 应用颜色和字体规范

### 步骤 3：提取可复用组件

```qml
// 如果某个部分会重复使用，提取为独立组件
// 例如：按钮、输入框、卡片等
```

### 步骤 4：添加动态逻辑

```qml
// 在 QDS 设计的基础上添加：
// - 属性绑定
// - 信号处理
// - 数据模型
```

### 步骤 5：测试验证

1. 在 QDS 中预览
2. 编译运行测试
3. 验证功能完整性
4. 验证视觉效果

---

## 📊 迁移优先级矩阵

| 页面 | 复杂度 | 使用频率 | 优先级 | 状态 |
|------|--------|----------|--------|------|
| 电机控制 | ⭐⭐⭐ | 高 | P0 | ✅ 已完成 |
| 开关量输入 | ⭐⭐ | 高 | P1 | ⏳ 待迁移 |
| 模拟量输入 | ⭐⭐ | 高 | P1 | ⏳ 待迁移 |
| 设备操作日志 | ⭐ | 中 | P2 | ⏳ 待迁移 |
| 报警页面 | ⭐⭐ | 高 | P1 | ⏳ 待迁移 |
| 控制面板 | ⭐⭐⭐ | 高 | P2 | ⏳ 待迁移 |
| 参数设置 | ⭐⭐⭐ | 中 | P2 | ⏳ 待迁移 |
| Input1 页面 | ⭐⭐⭐ | 高 | P3 | 保持现状 |
| SIP 电话 | ⭐⭐⭐⭐ | 中 | P3 | 保持现状 |

---

## 🎯 成功标准

### 设计质量
- ✅ 所有页面在 QDS 中可预览
- ✅ 视觉风格统一（工业科技感）
- ✅ 布局响应式（适配不同屏幕）

### 开发效率
- ✅ UI 修改不需要重新编译
- ✅ 设计师可独立完成 UI 调整
- ✅ 代码量减少 30% 以上

### 维护性
- ✅ 组件可复用
- ✅ 代码结构清晰
- ✅ 文档完善

---

## 📝 注意事项

### QDS 限制

1. **不支持的功能**：
   - 3D 场景
   - 复杂动画
   - 自定义 C++ 组件

2. **性能考虑**：
   - Loader 会有轻微性能开销
   - 大量动态元素建议用代码实现

3. **版本兼容**：
   - 确保 QDS 版本与 Qt 版本匹配
   - 定期更新 QDS

### 最佳实践

1. **先设计后编码**
   - 在 QDS 中完成 UI 设计
   - 再添加业务逻辑

2. **组件化思维**
   - 识别可复用的 UI 元素
   - 提取为独立组件

3. **保持简单**
   - 避免过度设计
   - 优先使用简单布局

---

## 🔄 持续改进

### 定期评审
- 每周评审迁移进度
- 收集使用反馈
- 优化设计规范

### 知识分享
- 记录迁移经验
- 分享最佳实践
- 培训团队成员

---

**创建时间**：2026-01-25
**创建人员**：Claude Sonnet 4.5
**文档版本**：v1.0
