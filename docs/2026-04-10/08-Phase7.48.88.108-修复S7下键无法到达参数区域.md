# Phase 7.48.88.108 — 修复S7控制页面下键无法到达参数配置区域

## 提交信息
- **日期**: 2026-04-10
- **类型**: fix

## 问题描述
当焦点在S7主站或S7从站Tab上时，按下键无法进入参数配置界面和数据概览界面。

## 根因分析

### 直接原因
`focusSubArea`被意外重置为0（列表区），导致Down键走入了`focusSubArea===0`的列表处理分支，但S7没有列表区域（已被注释掉），所以什么都不做。

### 根本原因
`DeviceSettingsDialog.qml`的Left键处理逻辑（第1543行）在`focusSubArea===1`时，排除了串口(7)/CAN(8)/TCP(9)/MQTT(11)页面，但**漏掉了S7(10)**。

S7与TCP/MQTT一样使用4区域模式（0=列表 1=Tab 2=参数 3=按钮），`focusSubArea=1`表示Tab栏。但因为没有被排除，Left键走入了电机控制页面的参数区域逻辑（该逻辑中`focusSubArea=1`表示参数区域），在左列时执行`currentPage.focusSubArea = 0`，将S7的focusSubArea错误重置为0。

### 复现路径
1. 导航到S7控制（类别10）
2. 右键进入内容区 → focusSubArea=1（Tab栏）✓
3. 右键在Tab间切换（S7主站→S7从站）✓
4. 左键切换回S7主站 → **触发电机页面的参数左列逻辑** → focusSubArea被重置为0 ✗
5. 此后按下键 → focusSubArea===0分支 → S7无列表处理 → 无响应

### QDS日志证据
```
focusSubArea 值: 1   ← 首次进入S7，正确
导航: 从参数区域返回列表区域  ← Left键误触发
focusSubArea 值: 0   ← 之后所有操作都卡在0
```

## 修复内容
- `DeviceSettingsDialog.qml` 第1543行：在Left键`focusSubArea===1`排除条件中添加S7(category 10)
  ```javascript
  // 旧: !isSerialPortControlPage && !isCANControlPage && !isTCPControlPage && !isMQTTControlPage
  // 新: 增加 !isS7ControlPage
  var isS7ControlPage = (currentCategory === 10)
  if (currentPage.focusSubArea === 1 && ... && !isS7ControlPage && ...) {
  ```

## 修改文件
- `src/qml/components/device_info/DeviceSettingsDialog.qml` — Left键排除条件增加S7

## 经验教训
新增使用4区域模式（0=列表 1=Tab 2=参数 3=按钮）的页面时，需要在所有区分"电机模式"和"NavigationManager模式"的判断中添加排除条件。这类判断至少出现在Left键的`focusSubArea===1`分支中。
