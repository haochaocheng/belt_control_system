# Screen01.ui.qml 三个版本对比

**目录**: docs/2026-01-27/Screen01_versions/
**创建日期**: 2026-01-27 21:55

## 文件列表

| 文件名 | 版本 | 提交哈希 | 日期 | 大小 | 说明 |
|--------|------|----------|------|------|------|
| Screen01.ui.qml.v1-a000b5cd-初始版本.qml | 版本 1 | a000b5cd | 2026-01-12 17:22 | 46KB | Qt Design Studio 导出的初始版本 |
| Screen01.ui.qml.v2-39c8451a-图片路径修复.qml | 版本 2 | 39c8451a | 2026-01-12 17:44 | 46KB | 修复图片路径错误 |
| Screen01.ui.qml.v3-41986199-尺寸修复-当前版本.qml | 版本 3 | 41986199 | 2026-01-12 18:05 | 46KB | 修复固定尺寸问题（当前版本） |

## 版本差异说明

### 版本 1 → 版本 2 的主要变化

**修复内容**: 图片路径错误

**变更示例**:
```qml
// 版本 1（错误）
source: "images/back1.svg"
source: "images/back2.svg"
source: "images/back3.png"

// 版本 2（修复）
source: "Input1Content/images/back1.svg"
source: "Input1Content/images/back2.svg"
source: "Input1Content/images/back3.png"
```

**影响**: 修复了约 115 个图片路径引用

### 版本 2 → 版本 3 的主要变化

**修复内容**: 固定尺寸导致 polish() 循环

**变更示例**:
```qml
// 版本 2（问题）
Rectangle {
    width: Constants.width
    height: Constants.height
    color: Constants.backgroundColor
    // ...
}

// 版本 3（修复）
Rectangle {
    anchors.fill: parent  // ✅ 自适应父容器
    color: Constants.backgroundColor
    // ...
}
```

**影响**: 解决了界面卡死问题

## 如何查看差异

### 使用 Git 命令

```bash
# 比较版本 1 和版本 2
git diff a000b5cd..39c8451a -- "src/qml/Input1/Input1Content/Screen01.ui.qml"

# 比较版本 2 和版本 3
git diff 39c8451a..41986199 -- "src/qml/Input1/Input1Content/Screen01.ui.qml"

# 比较版本 1 和版本 3（所有变化）
git diff a000b5cd..41986199 -- "src/qml/Input1/Input1Content/Screen01.ui.qml"
```

### 使用文本编辑器

1. 打开三个文件
2. 使用对比工具（如 VS Code 的 Compare 功能）
3. 搜索关键差异：
   - 版本 1→2: 搜索 `source:` 查看路径变化
   - 版本 2→3: 搜索 `width:` 和 `height:` 查看尺寸变化

### 使用 diff 工具

```bash
# Windows 上使用 PowerShell
cd "docs/2026-01-27/Screen01_versions"

# 比较版本 1 和版本 2
diff "Screen01.ui.qml.v1-a000b5cd-初始版本.qml" "Screen01.ui.qml.v2-39c8451a-图片路径修复.qml"

# 比较版本 2 和版本 3
diff "Screen01.ui.qml.v2-39c8451a-图片路径修复.qml" "Screen01.ui.qml.v3-41986199-尺寸修复-当前版本.qml"
```

## 关键差异位置

### 版本 1 → 版本 2 (图片路径)

**查找**: 搜索 `source: "images/`
**替换为**: `source: "Input1Content/images/`
**影响行数**: 约 115 行

**示例位置**:
- 第 20 行: back 背景图
- 第 28 行: image1
- 第 36 行: image2
- ... 等等

### 版本 2 → 版本 3 (尺寸)

**查找**:
```qml
width: Constants.width
height: Constants.height
```

**替换为**:
```qml
anchors.fill: parent
```

**影响行数**: 约 7 行
**位置**: 文件开头的 Rectangle 定义

## 推荐查看顺序

1. **先看版本 3（当前版本）**
   - 了解最终的正确实现
   - 文件名: `Screen01.ui.qml.v3-41986199-尺寸修复-当前版本.qml`

2. **对比版本 2 和版本 3**
   - 查看尺寸修复的具体变化
   - 重点关注文件开头的 Rectangle 定义

3. **对比版本 1 和版本 2**
   - 查看图片路径修复
   - 搜索所有 `source:` 属性

## 注意事项

1. **文件编码**: 所有文件都是 UTF-8 编码
2. **行尾符**: 使用 LF（Unix 格式）
3. **文件大小**: 三个版本大小相近（约 46KB）
4. **总行数**: 约 1770 行

## 相关文档

- [24-Screen01.ui.qml版本历史分析.md](../24-Screen01.ui.qml版本历史分析.md) - 详细的版本历史分析
- [21-FIX100.300.52-修复QML组件缺失导致加载失败.md](../21-FIX100.300.52-修复QML组件缺失导致加载失败.md) - QML 组件修复
- [23-FIX100.300.52.1-CMakeLists缺失Head组件.md](../23-FIX100.300.52.1-CMakeLists缺失Head组件.md) - CMakeLists 修复

## 使用建议

1. **学习参考**: 查看版本演进，了解问题修复过程
2. **问题排查**: 如果遇到类似问题，参考修复方法
3. **代码审查**: 对比不同版本，理解最佳实践
4. **备份恢复**: 如果需要回退，可以参考历史版本

## 快速对比命令

```powershell
# 在 PowerShell 中快速查看差异
cd "e:\2025\3_gongkongji\belt_control_system\docs\2026-01-27\Screen01_versions"

# 统计每个版本的行数
Get-ChildItem *.qml | ForEach-Object {
    $lines = (Get-Content $_.Name | Measure-Object -Line).Lines
    Write-Host "$($_.Name): $lines 行"
}

# 查找特定内容
Select-String -Path "*.qml" -Pattern "source:" | Group-Object Filename
```
