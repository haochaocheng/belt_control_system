# Phase 7.48.88.67 - 逻辑控制设备池同步电机禁用状态

## 修改日期
2026-03-29

## 问题描述
在电机控制界面将电机设为"禁用"后，切换到逻辑控制界面的设备池中，该电机仍然正常显示，与其他投入的电机没有区别。用户无法在设备池中区分哪些电机是禁用的。

## 修复方案

### 新增功能
1. LogicControlPanel 新增 `disabledDevices` 属性（禁用设备名称列表）
2. `loadDisabledDevices()` 函数从数据库加载所有电机和制动器的运行状态
3. `isDeviceDisabled()` 辅助函数判断设备是否禁用
4. 切换到逻辑控制面板时自动刷新禁用设备列表

### 禁用设备视觉样式
| 样式元素 | 正常设备 | 禁用设备 |
|----------|----------|----------|
| 背景色 | #1e3a5f（深蓝） | #1a1a1a（深黑） |
| 透明度 | 1.0 | 0.5 |
| 边框色 | 组颜色 | #FF5722（红色） |
| 文字色 | 白色 | #FF5722（红色） |
| 删除线 | 无 | 有 |
| 斜线标记 | 无 | 左上→右下红色斜线 |
| 右上角标签 | 无 | 红色圆形"禁"字 |
| 鼠标可点击 | 是 | 否（不可添加到序列） |

## 修改的文件

### 1. `src/qml/components/device_info/pages/LogicControlPanel.qml`
- 新增属性 `disabledDevices: []`
- 新增函数 `isDeviceDisabled(deviceName)`
- 新增函数 `loadDisabledDevices()` — 遍历8个电机+8个制动器
- `loadFromConfig()` 末尾调用 `loadDisabledDevices()`
- 设备池 Rectangle：添加 `isDisabled` 属性，修改 color/opacity/border
- 设备池 Text：禁用时红色+删除线
- 新增 Canvas 斜线标记
- 新增右上角"禁"标签
- MouseArea：禁用设备不可点击

### 2. `src/qml/components/device_info/DeviceSettingsDialog.qml`
- `onCurrentCategoryChanged`：切换到逻辑控制（index=11）时刷新禁用设备列表

## 测试要点
1. 电机控制界面：禁用3号电机 → 保存
2. 切换到逻辑控制界面 → 设备池中3号电机显示红色+删除线+斜线+"禁"标签
3. 尝试点击禁用的3号电机 → 不可添加到序列
4. 其他电机正常显示蓝色，可正常添加
5. 重新启用3号电机 → 保存 → 切换到逻辑控制 → 恢复正常蓝��显示
