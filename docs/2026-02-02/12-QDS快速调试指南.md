# QDS 快速调试指南 - 参数持久化功能

**日期**: 2026-02-02
**适用场景**: 快速调试 QML 界面和参数持久化逻辑

---

## 🎯 为什么使用 QDS？

### 传统开发流程（慢）
```
修改 QML → 编译 C++ → 构建 Docker 镜像 → 部署到设备 → 测试
⏱️ 耗时：2-3 分钟/次
```

### QDS 开发流程（快）⭐
```
修改 QML → 保存 → QDS 自动刷新 → 立即测试
⏱️ 耗时：1-2 秒/次
```

**效率提升**: 100-200 倍！

---

## 🚀 快速开始

### 1. 打开 Qt Design Studio

**方式 1**: 从开始菜单启动
- 打开 Windows 开始菜单
- 搜索 "Qt Design Studio"
- 点击启动

**方式 2**: 从项目文件启动
- 双击 `src/qml/BeltControlSystem.qmlproject`
- 系统会自动用 QDS 打开

### 2. 运行项目

**步骤**:
1. QDS 打开后，会自动加载项目
2. 点击左下角的 "▶️ Run" 按钮（或按 `Ctrl+R`）
3. 等待 QML 引擎启动（约 2-3 秒）
4. 预览窗口会显示应用界面

### 3. 测试参数持久化

**测试步骤**:
1. 在预览窗口中，导航到设备设置对话框
2. 切换到"电机控制"类别
3. 选择 1号电机，切换到"基本配置"Tab
4. 修改参数（例如：模块地址改为 5）
5. 点击"保存"按钮
6. **查看控制台输出**：
   ```
   ✅ [MotorControlPage] 保存电机配置 - 设备: 1 电机: 0 Tab: 0
   ✅ [BasicConfigTab] 收集配置: {"running_state":"投入","module_type":"继电器模块","module_address":5,"output_channel":0,"feedback_channel":0}
   ✅ [MockBackend] 保存电机配置: 1_0_0 {"running_state":"投入","module_type":"继电器模块","module_address":5,"output_channel":0,"feedback_channel":0}
   ✅ [MotorControlPage] 保存成功
   ```
7. 切换到 2号电机，再切换回 1号电机
8. **查看控制台输出**：
   ```
   ✅ [MotorControlPage] 加载电机配置 - 设备: 1 电机: 0 Tab: 0
   ✅ [MockBackend] 加载电机配置: 1_0_0 找到
   ✅ [BasicConfigTab] 应用配置: {"running_state":"投入","module_type":"继电器模块","module_address":5,"output_channel":0,"feedback_channel":0}
   ✅ [MotorControlPage] 配置已应用
   ```
9. **验证**：模块地址应该显示为 5 ✅

---

## 📝 控制台日志说明

### 保存日志
```
✅ [MotorControlPage] 保存电机配置 - 设备: 1 电机: 0 Tab: 0
   ↓ MotorControlPage 调用 saveMotorConfig()
✅ [BasicConfigTab] 收集配置: {...}
   ↓ BasicConfigTab 的 collectConfig() 收集参数
✅ [MockBackend] 保存电机配置: 1_0_0 {...}
   ↓ MockBackend 保存到内存存储
✅ [MotorControlPage] 保存成功
   ↓ 保存完成
```

### 加载日志
```
✅ [MotorControlPage] 加载电机配置 - 设备: 1 电机: 0 Tab: 0
   ↓ MotorControlPage 调用 loadMotorConfig()
✅ [MockBackend] 加载电机配置: 1_0_0 找到
   ↓ MockBackend 从内存存储加载
✅ [BasicConfigTab] 应用配置: {...}
   ↓ BasicConfigTab 的 applyConfig() 应用参数
✅ [MotorControlPage] 配置已应用
   ↓ 加载完成
```

---

## 🔧 常见问题

### Q1: 修改 QML 后没有立即生效？

**解决方法**:
1. 确保已保存文件（`Ctrl+S`）
2. 点击 QDS 的 "🔄 Reload" 按钮（或按 `Ctrl+Shift+R`）
3. 如果还是不行，重新运行项目（`Ctrl+R`）

### Q2: 控制台没有输出日志？

**解决方法**:
1. 确保 QDS 的"应用程序输出"面板是打开的
2. 点击 QDS 底部的 "Application Output" 标签
3. 如果看不到，点击菜单 "View" → "Output Panes" → "Application Output"

### Q3: 刷新后数据丢失？

**这是正常的！**
- QDS 使用内存模拟，数据不持久化
- 刷新后数据会丢失
- 这是设计行为，用于快速测试
- 如需测试真实持久化，请部署到设备

### Q4: 如何打开设备设置对话框？

**方法 1**: 通过 Input1 页面
1. 切换到 Input1 页面
2. 双击任意设备项
3. 设备设置对话框会弹出

**方法 2**: 直接预览对话框
1. 在 QDS 项目面板中找到 `DeviceSettingsDialog.qml`
2. 右键 → "Run" 或 "Preview"
3. 直接预览对话框

### Q5: 如何查看特定 Tab 的效果？

**方法**:
1. 在 QDS 项目面板中找到对应的 Tab 文件
   - 例如：`BasicConfigTab.qml`
2. 右键 → "Run" 或 "Preview"
3. 直接预览该 Tab

---

## 💡 开发技巧

### 技巧 1: 使用实时预览

**步骤**:
1. 在 QDS 中打开 QML 文件
2. 点击右上角的 "👁️ Live Preview" 按钮
3. 修改代码后，预览会实时更新
4. 无需手动刷新

### 技巧 2: 使用设计模式

**步骤**:
1. 点击 QDS 左侧的 "Design" 按钮
2. 进入可视化设计模式
3. 拖拽控件、调整布局
4. QDS 会自动生成 QML 代码

### 技巧 3: 使用代码模式

**步骤**:
1. 点击 QDS 左侧的 "Edit" 按钮
2. 进入代码编辑模式
3. 直接编辑 QML 代码
4. 保存后自动刷新预览

### 技巧 4: 使用分屏预览

**步骤**:
1. 点击 QDS 右上角的 "Split" 按钮
2. 左侧显示代码，右侧显示预览
3. 修改代码时可以立即看到效果

---

## 📊 QDS vs 设备调试对比

| 功能 | QDS 调试 | 设备调试 |
|------|----------|----------|
| **UI 布局调整** | ✅ 推荐 | ❌ 太慢 |
| **参数字段修改** | ✅ 推荐 | ❌ 太慢 |
| **collectConfig() 逻辑** | ✅ 推荐 | ❌ 太慢 |
| **applyConfig() 逻辑** | ✅ 推荐 | ❌ 太慢 |
| **保存/加载流程** | ✅ 推荐 | ⚠️ 可选 |
| **数据库持久化** | ❌ 不支持 | ✅ 必须 |
| **跨会话保留** | ❌ 不支持 | ✅ 必须 |
| **性能测试** | ❌ 不支持 | ✅ 必须 |
| **真实环境测试** | ❌ 不支持 | ✅ 必须 |

---

## 🎯 推荐工作流程

### 阶段 1: UI 开发（使用 QDS）

1. 在 QDS 中调整 UI 布局
2. 添加/修改参数字段
3. 实时预览效果
4. 快速迭代

**耗时**: 10-20 分钟

### 阶段 2: 逻辑开发（使用 QDS）

1. 实现 collectConfig() 方法
2. 实现 applyConfig() 方法
3. 测试保存和加载流程
4. 验证参数收集和应用逻辑

**耗时**: 20-30 分钟

### 阶段 3: 完整测试（使用设备）

1. 编译部署到设备：`.\build-ubuntu24-apt.ps1 188`
2. 测试数据库持久化
3. 测试跨会话保留
4. 测试性能和稳定性

**耗时**: 10-15 分钟

**总耗时**: 40-65 分钟（相比传统方式节省 50-70% 时间）

---

## 🔗 相关文档

- [11-QDS参数持久化调试方案.md](./11-QDS参数持久化调试方案.md) - 详细技术方案
- [10-FIX100.300.112.8.22-Phase1完成-MotorControlPage和BasicConfigTab集成.md](./10-FIX100.300.112.8.22-Phase1完成-MotorControlPage和BasicConfigTab集成.md) - Phase 1 实施总结
- [BeltControlSystem.qmlproject](../../src/qml/BeltControlSystem.qmlproject) - QDS 项目配置
- [main_qds.qml](../../src/qml/main_qds.qml) - QDS 入口文件
- [MockBackend.qml](../../src/qml/MockBackend.qml) - 模拟后端

---

## 📦 下一步

### 继续开发

1. ✅ 在 QDS 中测试 BasicConfigTab
2. ⏳ 在 QDS 中实现其他 9 个 Tab 的 collectConfig/applyConfig
3. ⏳ 在 QDS 中测试 BrakeControlPage
4. ⏳ 在 QDS 中测试 TensionControlPage

### 完整测试

1. ⏳ 编译部署到设备
2. ⏳ 测试数据库持久化
3. ⏳ 测试跨会话保留
4. ⏳ 验证所有功能正常

---

**创建日期**: 2026-02-02
**状态**: ✅ 指南完成
**编写人员**: Claude Sonnet 4.5
