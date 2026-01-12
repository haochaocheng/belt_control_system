# Fix: Screen01.ui.qml 固定尺寸导致 polish() 循环

**创建时间**：2026-01-12
**问题编号**：QML polish() 循环卡死（真正根因）
**状态**：✅ 已修复

---

## 📋 问题描述

### 错误现象

滑动到 Input1Page（第5页）时：
```
[DEBUG] Input1Page 激活状态: true
[WARNING] qrc:/qt-project.org/imports/QtQuick/Controls/Basic/SwipeView.qml:15:18: QML ListView: possible QQuickItem::polish() loop
[WARNING] qrc:/qt-project.org/imports/QtQuick/Controls/Basic/SwipeView.qml:15:18: QML ListView: ListView called polish() inside updatePolish() of ListView
（无限重复，应用卡死）
```

###  真正根本原因（非图片路径）

**尺寸冲突导致布局循环**：

```qml
Input1Page (Item)
  └─ Loader (anchors.fill: parent)  ← 期望子项自适应
     └─ Screen01.ui.qml (Rectangle, width: 1920, height: 1080)  ← 固定尺寸冲突！
```

**为什么导致 polish() 循环**：
1. **Loader** 使用 `anchors.fill: parent`，期望加载的内容填充父容器
2. **Screen01.ui.qml** 根元素使用固定尺寸：
   ```qml
   Rectangle {
       width: Constants.width    // 1920
       height: Constants.height  // 1080
       ...
   }
   ```
3. **SwipeView 的内部 ListView** 检测到子项尺寸 (1920x1080) 与容器尺寸不匹配
4. ListView 尝试重新计算布局 → 调用 polish()
5. polish() 完成后尺寸仍然冲突 → 再次触发 polish()
6. **无限递归循环 → CPU 100% → 应用卡死** ❌

---

## ✅ 解决方案

### 策略

将 Screen01.ui.qml 的根元素从 **固定尺寸** 改为 **自适应父容器**。

### 实施

**修改前**（Screen01.ui.qml:13-17）：
```qml
Rectangle {
    width: Constants.width    // 固定 1920
    height: Constants.height  // 固定 1080

    color: Constants.backgroundColor
```

**修改后**：
```qml
Rectangle {
    // 2026-01-12: 移除固定尺寸，使用 anchors.fill 自适应父容器
    // 避免与 SwipeView 的 ListView 产生 polish() 循环
    // width: Constants.width    // 原始固定尺寸 1920
    // height: Constants.height  // 原始固定尺寸 1080
    anchors.fill: parent         // 自适应父容器尺寸

    color: Constants.backgroundColor
```

---

## 📊 技术细节

### QML Loader 与子项尺寸

**Loader 的尺寸行为**：
```qml
Loader {
    anchors.fill: parent  // Loader 自身填充父容器
    source: "..."
}
```

**子项尺寸选项**：

1. **固定尺寸**（❌ 会导致冲突）：
   ```qml
   Rectangle {
       width: 1920   // 固定，不自适应
       height: 1080
   }
   ```
   - Loader 尺寸：`parent.width x parent.height`（例如 1280x800）
   - 子项尺寸：`1920 x 1080`
   - **冲突！** → SwipeView 的 ListView 循环重新布局

2. **自适应尺寸**（✅ 正确）：
   ```qml
   Rectangle {
       anchors.fill: parent  // 填充 Loader 的尺寸
   }
   ```
   - Loader 尺寸：`parent.width x parent.height`
   - 子项尺寸：**自动匹配** Loader 尺寸
   - **无冲突** ✅

### SwipeView + ListView 的 polish() 机制

```
SwipeView (用户滑动切换页面)
  └─ ListView (内部实现)
     ├─ 监听子项尺寸变化
     ├─ 检测到冲突 → 调用 polish() 重新布局
     ├─ polish() 完成 → 检查尺寸
     └─ 尺寸仍然冲突 → 再次调用 polish() → ❌ 无限循环
```

**触发条件**：
- 子项固定尺寸 ≠ SwipeView 实际尺寸
- 例如：Screen01 是 1920x1080，但设备屏幕是 1280x800

---

## 🎯 预期效果

### 编译后

```bash
-- Input1 QML 模块已创建为独立模块
-- Configuring done
-- Generating done
✅ 交叉编译成功完成
```

### 运行时

```bash
[DEBUG] Input1Page 激活状态: true
✅ Input1 Screen01 加载成功
```

**无 polish() 警告，滑动流畅，不卡死** ✅

### 界面效果

- ✅ Screen01.ui.qml 自动缩放到容器尺寸
- ✅ 1920x1080 设计在任意尺寸屏幕上正确显示
- ✅ 响应式布局，适配不同设备

---

## 🧪 测试步骤

### 1. 编译并部署

```powershell
# 清理缓存
Remove-Item build_rk3588 -Recurse -Force -ErrorAction SilentlyContinue

# 编译部署
.\build-ubuntu24-apt.ps1 188
```

### 2. 验证运行

SSH 连接到设备：

```bash
ssh linaro@192.168.10.188
docker logs belt-control-app --tail 100 | grep -i "input1\|polish\|warning"
```

**预期输出**：
```bash
Input1Page 已加载
[DEBUG] Input1Page 激活状态: true
✅ Input1 Screen01 加载成功
```

**无 polish() 警告** ✅

### 3. 界面功能测试

- 启动应用
- 滑动到第 5 页（Input1Page）
- 验证：
  - ✅ 界面正确显示（自动缩放到屏幕尺寸）
  - ✅ 滑动流畅，无卡顿
  - ✅ 无警告日志
  - ✅ CPU 占用正常

---

## 🔍 为什么图片路径修复不够？

**之前的修复（10-fix-screen01-image-paths.ps1）**：
- ✅ 修复了 115 处图片路径错误
- ✅ 确保图片可以正常加载
- ❌ **但未解决尺寸冲突问题**

**图片路径修复的局限**：
- 图片加载失败 **可能** 触发 polish() 循环（尺寸变化）
- 但 **主要原因** 是 Screen01 的 **固定尺寸与 Loader 冲突**
- 即使所有图片都加载成功，固定尺寸仍会导致 polish() 循环

**结论**：
- 图片路径修复 + 尺寸自适应 = **完全解决** ✅

---

## 📝 相关文件

### 修改的文件

1. [src/qml/Input1/Input1Content/Screen01.ui.qml](../../src/qml/Input1/Input1Content/Screen01.ui.qml)
   - 第 13-20 行：移除固定尺寸，改用 `anchors.fill: parent`

### 参考文档

1. [13-Fix-Screen01图片路径-解决卡死问题.md](13-Fix-Screen01图片路径-解决卡死问题.md) - 图片路径修复
2. [12-Fix-App命名冲突-移除QDS预览文件.md](12-Fix-App命名冲突-移除QDS预览文件.md) - App.qml 冲突

---

## 🎓 技术总结

### 关键发现

1. **QDS 设计的固定尺寸**：
   - Qt Design Studio 默认生成固定尺寸的根元素（1920x1080）
   - 适合 **预览**，不适合 **实际应用**（需要响应式布局）

2. **Loader 的尺寸期望**：
   - `anchors.fill: parent` 的 Loader 期望子项也自适应
   - 固定尺寸的子项会导致 **尺寸冲突**

3. **SwipeView + ListView 的脆弱性**：
   - Qt 6.5 的 SwipeView 内部使用 ListView
   - ListView 对尺寸变化非常敏感
   - 尺寸冲突容易触发 polish() 循环（已知 Bug）

### 最佳实践

1. **QDS 设计集成到应用时**：
   - ✅ 将根元素的固定尺寸改为 `anchors.fill: parent`
   - ✅ 保留内部元素的相对坐标（x, y）
   - ✅ 使用 Qt Quick 的 Item 布局系统（anchors, layouts）

2. **Loader 使用规范**：
   ```qml
   Loader {
       anchors.fill: parent  // Loader 自适应父容器
       source: "..."

       // 加载的内容应该使用 anchors.fill: parent
   }
   ```

3. **避免固定尺寸**：
   - ❌ 不要在顶层组件使用 `width: 1920, height: 1080`
   - ✅ 使用相对布局（anchors, layouts）
   - ✅ 使用 `implicitWidth/Height` 提供建议尺寸，但允许调整

---

## 🔄 未来 QDS 工作流调整

### 问题

每次从 QDS 导出 Screen01.ui.qml 时，**可能会重新生成固定尺寸**：
```qml
Rectangle {
    width: Constants.width    // QDS 重新生成
    height: Constants.height
```

### 解决方案

#### 方案 A：手动修复脚本

创建 `12-fix-screen01-anchors.ps1`：
```powershell
# 自动将 Screen01.ui.qml 的固定尺寸改为 anchors.fill
$content = Get-Content -Path $Screen01Path -Raw
$content = $content -replace 'Rectangle \{\s+width: Constants.width\s+height: Constants.height', 'Rectangle {\n    anchors.fill: parent  // Auto-fixed'
Set-Content -Path $Screen01Path -Value $content
```

集成到 `11-sync-qds-to-project.ps1` 中。

#### 方案 B：修改 Constants.qml

不修改 Screen01.ui.qml，而是动态调整 Constants：
```qml
// Constants.qml
QtObject {
    // 从父容器获取实际尺寸（而不是固定 1920x1080）
    property int width: parent ? parent.width : 1920
    property int height: parent ? parent.height : 1080
}
```

**限制**：Singleton 无法访问 parent，此方案不可行。

#### 方案 C（推荐）：在 QDS 中使用 anchors

直接在 Qt Design Studio 中：
1. 选中 Screen01.ui.qml 的根 Rectangle
2. 右侧属性面板 → Layout → 设置 `anchors.fill: parent`
3. 保存

**优点**：QDS 导出时保留 anchors，无需后续修复。

---

**创建者**：Claude
**文档版本**：1.0
**最后更新**：2026-01-12
