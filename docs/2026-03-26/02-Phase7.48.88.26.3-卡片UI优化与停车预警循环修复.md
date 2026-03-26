# Phase 7.48.88.26.3 - 卡片UI优化与停车预警循环修复

## 修改时间
2026-03-26 15:00 (北京时间)

## 修改文件
1. `src/qml/Input1/Input1Content/MyIN_Data.ui.qml` - 卡片组件UI优化
2. `src/qml/Input1/Input1Content/Screen01.qml` - AI数据绑定修复+调试日志
3. `src/mqtt/AIDataManager.h` - 新增QML友好信号
4. `src/mqtt/AIDataManager.cpp` - 发出QVariantMap信号
5. `src/control/CommonControl.cpp` - 修复停车预警循环Bug

---

## 修复内容

### 1. 卡片UI优化（MyIN_Data.ui.qml）

#### 问题1：设备名称移到header band中央
- **现象**：设备名称在装饰线下方，用户希望放在背景图青色装饰线之间
- **修复**：标题栏改为 y:5, width:100%, 水平居中对齐
- 状态指示（灯+文字）独立移到 y:55 左侧显示
- 内容区从 y:78 开始，可用高度增加到 232px
- 核心数据区恢复为 140px

#### 问题3：进度条增强 - 工业仪表风格
- **现象**：进度条过于简单，缺乏工业科技感
- **修复**：
  - 高度：6px → 10px（参数）/ 8px → 12px（序列）
  - 添加10等分刻度线（半透明分隔）
  - 填充条顶部白色高光线（15%透明度）
  - 发光球增加内核高亮（白色6px圆点）
  - 底部光晕层扩散6-8px
  - 参数Item高度 52px → 56px 适配

### 2. AI数据实时更新修复（AIDataManager + Screen01）

#### 问题2：速度值只在启动时显示，后续不更新
- **根因**：`channelChanged` 信号传递 C++ 结构体 `ChannelData`，该结构体没有 `Q_DECLARE_METATYPE` 注册，QML 无法解析信号参数
  - `getChannel()` 方法返回 `QVariantMap`，初始加载成功
  - 信号参数到达 QML 后为 undefined，被 `if (!data || !data.valid)` 过滤
- **修复**：
  - `AIDataManager.h`：新增 `channelUpdatedMap(int, int, QVariantMap)` 信号
  - `AIDataManager.cpp`：`detectChanges` 中同时 emit 新信号，用 `channelDataToVariant()` 转换
  - `Screen01.qml`：改用 `onChannelUpdatedMap` 替代 `onChannelChanged`
- **调试日志**：
  - `rebuildBeltSensorMappings`：输出每条皮带的映射配置
  - `applyMappedValue`：输出 AD值→工程值转换结果

### 3. 停车预警循环播放修复（CommonControl.cpp）

#### Bug现象
按2键启动设备后，再次按2键停止，停车预警音频无限循环播放

#### 根因分析
1. 用户快速连按2键 → 多个停止请求入 `m_pendingBeltOps` 队列
2. 停车音频播完 → `onPlaybackFinished` → `stopDeviceSequence(2)` 开始执行4步序列
3. **紧接着** `processPendingBeltOps()` 取出队列中的下一个停止请求
4. 又调 `stopBelt(2)` → `m_beltRunning[2]` 仍为 true → 再播停车音频 → 循环

#### 修复方案
1. `stopBelt` 入口清除队列中该皮带所有重复停止请求
2. 检查该皮带是否已有停止序列在执行（`!isStartup && isRunning`），有则忽略
3. `startBelt` 同步加队列清理保护

---

## 日志分析要点

### 速度映射（所有皮带映射到同一通道）
```
皮带 1 速度映射: moduleIndex=2 channelIndex=0 rangeValue=5
皮带 2 速度映射: moduleIndex=2 channelIndex=0 rangeValue=5
...（8条皮带全部相同）
```
这是数据库配置问题，所有皮带默认速度保护配置指向同一AI通道。代码逻辑正确。

### 停车循环日志特征
```
5189: 2号皮带执行停止顺序: 3号电机→2号电机→1号制动器→张紧控制
5192: 处理待处理操作 - 停止 2号皮带  ← 队列中的旧请求！
5193: 请求停止 2号皮带  ← 又触发停止！
5194: 停车预警  ← 覆盖了正在执行的序列
```
