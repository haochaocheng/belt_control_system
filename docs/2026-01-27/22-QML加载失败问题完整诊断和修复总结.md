# QML 加载失败问题完整诊断和修复总结

**日期**: 2026-01-27 21:35
**问题**: 容器启动成功，但 QML 加载失败
**状态**: ✅ 已修复，正在重新部署

## 问题时间线

### 1. 容器启动失败（已解决）

**问题**: `exec /app/app-entrypoint.sh: no such file or directory`

**根本原因**: Shell 脚本是 Windows CRLF 格式，Linux 无法执行

**修复**:
- 使用 dos2unix 转换文件格式
- 在 build-ubuntu24-apt.ps1 中添加自动转换逻辑

**文档**:
- 19-FIX100.300.50-最终诊断报告.md
- 20-FIX100.300.51-自动转换Shell脚本为Unix格式.md

### 2. QML 加载失败（本次修复）

**问题**: `Head is not a type`

**根本原因**: Head.ui.qml 和 Head_MiddleMenu.ui.qml 文件丢失

**修复**: 从临时文件恢复缺失的 QML 组件

**文档**: 21-FIX100.300.52-修复QML组件缺失导致加载失败.md

## 详细调查过程

### QML 加载链分析

```
main.qml:68
  ↓ 使用 App {}
App.qml:171
  ↓ 使用 ControlPanel {}
ControlPanel.qml:6
  ↓ 导入 "../Input1/Input1Content"
ControlPanel.qml:99
  ↓ 使用 Head {}
Head.ui.qml
  ❌ 文件不存在！
```

### 文件丢失原因分析

**发现**：
- Head.ui.qml 文件不存在
- 只有临时文件：`Head.ui.qml.tmp.36968.1768894585608`
- 最新临时文件日期：2026-01-20 15:36

**可能原因**：
1. Qt Design Studio (QDS) 崩溃，未完成保存
2. Git 操作覆盖了文件
3. 文件系统错误

**QDS 临时文件机制**：
- 编辑时创建：`文件名.tmp.进程ID.时间戳`
- 保存时：临时文件 → 原文件
- 崩溃时：临时文件保留，原文件丢失

## 修复步骤

### 1. 恢复文件

```bash
# 从最新临时文件恢复
cp "Head.ui.qml.tmp.36968.1768894585608" "Head.ui.qml"
cp "Head_MiddleMenu.ui.qml.tmp.36968.1768894475998" "Head_MiddleMenu.ui.qml"
```

### 2. 验证恢复

```bash
$ ls -l src/qml/Input1/Input1Content/Head*.qml
-rw-r--r-- 1 54999 197610 6576  1月 27 21:31 Head.ui.qml
-rw-r--r-- 1 54999 197610 1249  1月 27 21:31 Head_MiddleMenu.ui.qml
```

### 3. Git 提交

```bash
git add src/qml/Input1/Input1Content/Head.ui.qml
git add src/qml/Input1/Input1Content/Head_MiddleMenu.ui.qml
git commit -m "fix: 恢复缺失的 Head QML 组件 - FIX 100.300.52"
```

提交哈希：`01598904`

### 4. 重新部署

```powershell
.\build-ubuntu24-apt.ps1 192.168.1.8
```

**状态**: 🔄 正在后台运行（任务 ID: be040b1）

## 恢复的文件内容

### Head.ui.qml (6576 字节)

**功能**: 头部组件，包含5个菜单对应5个画面

**关键代码**：
```qml
Rectangle {
    id: rectangle
    width: 1920
    height: 100
    property int currentPageIndex: 0  // 当前页面索引（0-4）

    Head_MiddleMenu {
        id: menu1_home
        menuText: "首页"                // 画面 1: ControlPanel
        isActive: rectangle.currentPageIndex === 0
    }

    Head_MiddleMenu {
        id: menu2_params
        menuText: "参数设置"            // 画面 2: ParameterSettings
        isActive: rectangle.currentPageIndex === 1
    }

    // ... 其他3个菜单
}
```

### Head_MiddleMenu.ui.qml (1249 字节)

**功能**: 菜单项组件

**属性**:
- `menuText`: 菜单文本
- `isActive`: 是否激活状态

## 预期结果

部署完成后，应用程序应该：

1. ✅ 容器正常启动（CRLF 问题已修复）
2. ✅ QML 组件加载成功（Head 组件已恢复）
3. ✅ 应用程序正常启动
4. ✅ 界面显示正常

## 预防措施

### 1. 定期清理临时文件

```bash
# 删除超过7天的临时文件
find src/qml -name "*.tmp.*" -mtime +7 -delete
```

### 2. 添加 Git 钩子

创建 `.git/hooks/pre-commit`：
```bash
#!/bin/bash
# 检查是否有 .ui.qml 文件被删除但临时文件存在
for tmp in $(git diff --cached --name-only --diff-filter=D | grep '\.ui\.qml$'); do
    if ls "${tmp}.tmp."* 2>/dev/null; then
        echo "警告: $tmp 被删除，但临时文件存在"
        echo "请检查是否需要从临时文件恢复"
        exit 1
    fi
done
```

### 3. 定期备份 QML 文件

```powershell
# 每天备份 QML 文件
$date = Get-Date -Format "yyyy-MM-dd"
robocopy "src\qml" "backups\qml-$date" *.qml /S /XO
```

## 相关文档

- [19-FIX100.300.50-最终诊断报告.md](19-FIX100.300.50-最终诊断报告.md) - CRLF 问题诊断
- [20-FIX100.300.51-自动转换Shell脚本为Unix格式.md](20-FIX100.300.51-自动转换Shell脚本为Unix格式.md) - CRLF 自动转换
- [21-FIX100.300.52-修复QML组件缺失导致加载失败.md](21-FIX100.300.52-修复QML组件缺失导致加载失败.md) - QML 组件恢复

## 下一步

等待构建完成（预计 5-10 分钟），然后：

1. 检查部署日志
2. 测试应用程序启动
3. 验证界面显示
4. 确认所有功能正常

## 总结

**两个关键问题**：
1. ✅ Shell 脚本 CRLF 格式 → 容器启动失败
2. ✅ QML 组件文件丢失 → 应用程序加载失败

**两个修复**：
1. ✅ 自动转换 CRLF 为 LF
2. ✅ 从临时文件恢复 QML 组件

**状态**: 🔄 正在重新部署，等待测试结果
