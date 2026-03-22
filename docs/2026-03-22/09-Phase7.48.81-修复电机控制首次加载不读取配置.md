# Phase 7.48.81 - 修复电机控制首次加载不读取配置

## 修复日期
2026-03-22

## 问题描述
打开设备配置弹窗，切换到电机控制大类时，1号电机显示默认值（如启动延时8秒、停止延时8秒），
而非数据库中保存的配置（如启动延时2秒、停止延时3秒）。
只有在电机列表中切换到其他电机再切回来时，才会正确加载配置。

## 根因分析
`MotorControlPage.qml` 中，`loadMotorConfig()` 仅在以下时机被调用：
1. `onMotorListIndexChanged`（行115）- 电机索引变化时
2. `onTabIndexChanged`（行138）- Tab切换时
3. 重置按钮点击（行618）

问题：`currentMotorIndex` 初始值为 0，页面加载时索引不会变化，
因此 `onMotorListIndexChanged` 不会被触发，配置不会被加载。

## 修复方案
在 `motorConfigPanel`（Loader）的 `onLoaded` 回调末尾添加：
```javascript
Qt.callLater(root.loadMotorConfig)
```
使用 `Qt.callLater` 确保 Loader 完全加载后再读取配置。

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| MotorControlPage.qml | motorConfigPanel.onLoaded 添加初始配置加载 |
