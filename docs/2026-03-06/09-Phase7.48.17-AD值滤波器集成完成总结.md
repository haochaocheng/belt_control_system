# Phase 7.48.17 — AD值滤波器集成完成总结

**日期**：2026-03-06
**阶段**：Phase 7.48.17
**类型**：功能增强
**用时**：30 分钟

---

## 一、实施内容

### 1.1 核心功能

**AD值滤波处理**：
- 为模拟量输入添加6种滤波算法
- 支持动态切换滤波器类型
- 支持启用/禁用滤波功能
- 每个通道独立滤波（2模块×8通道=16个滤波器）

### 1.2 滤波器类型

| 类型 | 算法 | 优点 | 适用场景 |
|------|------|------|----------|
| `median` | 中值滤波（5点） | 去除脉冲干扰效果好 | 偶然出现的脉冲干扰 |
| `average` | 滑动平均（8点） | 平滑周期性干扰 | 周期性干扰 |
| `limit` | 限幅滤波（阈值100） | 去除异常值 | 偶然出现的大幅跳变 |
| `lag` | 一阶滞后（α=0.3） | 平滑慢变化量 | 温度、压力等慢变量 |
| `combined` | 中值+平均（推荐） | 综合效果最好 | 工业现场通用 |
| `lightweight` | 限幅+滞后 | 计算量小 | 资源受限场景 |

**默认配置**：
- 滤波器类型：`combined`（中值+平均）
- 启用状态：`true`（默认启用）

---

## 二、代码修改

### 2.1 新增文件

**src/mqtt/ADFilter.h**（完整滤波器库）：
- 基类 `ADFilterBase`：定义滤波器接口
- `MedianFilter`：中值滤波器（5点窗口）
- `MovingAverageFilter`：滑动平均滤波器（8点窗口）
- `LimitFilter`：限幅滤波器（阈值100）
- `FirstOrderLagFilter`：一阶滞后滤波器（α=0.3）
- `CombinedFilter`：组合滤波器（中值+平均）
- `LightweightFilter`：轻量级滤波器（限幅+滞后）

### 2.2 修改 AIDataManager.h

**新增内容**：

1. **包含头文件**（第21行）：
```cpp
#include "ADFilter.h"  // ✅ 2026-03-06 [Phase 7.48.17]: AD值滤波器
```

2. **新增属性**（第58-60行）：
```cpp
Q_PROPERTY(QString filterType READ filterType WRITE setFilterType NOTIFY filterTypeChanged)
Q_PROPERTY(bool filterEnabled READ filterEnabled WRITE setFilterEnabled NOTIFY filterEnabledChanged)
```

3. **新增访问器**（第69-74行）：
```cpp
QString filterType() const { return m_filterType; }
void setFilterType(const QString &type);

bool filterEnabled() const { return m_filterEnabled; }
void setFilterEnabled(bool enabled);
```

4. **新增信号**（第84-86行）：
```cpp
void filterTypeChanged();
void filterEnabledChanged();
```

5. **新增私有方法**（第96-101行）：
```cpp
void initFilters();
quint16 applyFilter(int moduleIndex, int channelIndex, quint16 rawValue);
```

6. **新增成员变量**（第108-113行）：
```cpp
QString m_filterType;           // 滤波器类型
bool m_filterEnabled;           // 滤波器启用状态
QVector<QVector<ADFilterBase*>> m_filters;  // 滤波器实例（2×8=16个）
```

### 2.3 修改 AIDataManager.cpp

**修改1：构造函数初始化**（第16-28行）：
```cpp
AIDataManager::AIDataManager(QObject *parent)
    : QObject(parent)
    , m_changeThreshold(10)
    , m_filterType("combined")  // ✅ 默认使用组合滤波器
    , m_filterEnabled(true)     // ✅ 默认启用滤波
{
    // 初始化2个模块，每个8通道
    m_aiData.resize(2);
    for (int i = 0; i < 2; ++i) {
        m_aiData[i].resize(8);
    }

    // ✅ 初始化滤波器
    initFilters();

    qDebug() << "✅ [AIDataManager] 初始化模拟量数据管理器（滤波器:" << m_filterType << "）";
}
```

**修改2：新增配置方法**（第67-93行）：
```cpp
void AIDataManager::setFilterType(const QString &type)
{
    if (m_filterType != type) {
        m_filterType = type;
        initFilters();  // 重新初始化滤波器
        qDebug() << "✅ [AIDataManager] 滤波器类型:" << type;
        emit filterTypeChanged();
    }
}

void AIDataManager::setFilterEnabled(bool enabled)
{
    if (m_filterEnabled != enabled) {
        m_filterEnabled = enabled;
        qDebug() << "✅ [AIDataManager] 滤波器" << (enabled ? "启用" : "禁用");
        emit filterEnabledChanged();
    }
}
```

**修改3：应用滤波**（第164-169行）：
```cpp
ChannelData &ch = newData[i];
// ✅ 2026-03-06 [Phase 7.48.17]: 应用滤波器
quint16 rawValue = static_cast<quint16>(chObj["value"].toInt());
ch.adValue = applyFilter(dataIndex, i, rawValue);
ch.voltage = chObj["voltage"].toDouble();
ch.timestamp = timestamp;
ch.valid = true;
```

**修改4：新增滤波器初始化方法**（第238-279行）：
```cpp
void AIDataManager::initFilters()
{
    // 清理旧滤波器
    for (auto &moduleFilters : m_filters) {
        for (auto *filter : moduleFilters) {
            delete filter;
        }
    }
    m_filters.clear();

    // 创建新滤波器（2个模块×8通道）
    m_filters.resize(2);
    for (int i = 0; i < 2; ++i) {
        m_filters[i].resize(8);
        for (int j = 0; j < 8; ++j) {
            if (m_filterType == "median") {
                m_filters[i][j] = new MedianFilter(5);
            } else if (m_filterType == "average") {
                m_filters[i][j] = new MovingAverageFilter(8);
            } else if (m_filterType == "limit") {
                m_filters[i][j] = new LimitFilter(100);
            } else if (m_filterType == "lag") {
                m_filters[i][j] = new FirstOrderLagFilter(0.3);
            } else if (m_filterType == "combined") {
                m_filters[i][j] = new CombinedFilter(5, 8);
            } else if (m_filterType == "lightweight") {
                m_filters[i][j] = new LightweightFilter(100, 0.3);
            } else {
                m_filters[i][j] = nullptr;  // 无滤波
            }
        }
    }

    qDebug() << "✅ [AIDataManager] 滤波器初始化完成，类型:" << m_filterType;
}
```

**修改5：新增滤波应用方法**（第281-303行）：
```cpp
quint16 AIDataManager::applyFilter(int moduleIndex, int channelIndex, quint16 rawValue)
{
    // 滤波器未启用，直接返回原始值
    if (!m_filterEnabled) {
        return rawValue;
    }

    // 检查索引有效性
    if (moduleIndex < 0 || moduleIndex >= 2 || channelIndex < 0 || channelIndex >= 8) {
        return rawValue;
    }

    // 获取滤波器
    ADFilterBase *filter = m_filters[moduleIndex][channelIndex];
    if (!filter) {
        return rawValue;  // 无滤波器，返回原始值
    }

    // 应用滤波
    return filter->filter(rawValue);
}
```

---

## 三、工作流程

### 3.1 数据处理流程

```
MQTT接收原始AD值
    ↓
parseJsonData() 解析JSON
    ↓
applyFilter() 应用滤波
    ↓
    ├─ 滤波器未启用 → 返回原始值
    ├─ 滤波器类型 = "combined" → 中值+平均滤波
    ├─ 滤波器类型 = "median" → 中值滤波
    ├─ 滤波器类型 = "average" → 滑动平均
    ├─ 滤波器类型 = "limit" → 限幅滤波
    ├─ 滤波器类型 = "lag" → 一阶滞后
    └─ 滤波器类型 = "lightweight" → 限幅+滞后
    ↓
存储滤波后的AD值
    ↓
detectChanges() 检测变化
    ↓
发送信号通知界面更新
```

### 3.2 滤波器切换流程

```
用户调用 setFilterType("median")
    ↓
initFilters() 重新初始化
    ↓
清理旧滤波器（delete）
    ↓
创建新滤波器（16个）
    ↓
发送 filterTypeChanged() 信号
```

---

## 四、使用示例

### 4.1 C++ 代码使用

```cpp
// 获取 AIDataManager 实例
AIDataManager *manager = ...;

// 设置滤波器类型
manager->setFilterType("combined");  // 使用组合滤波器

// 启用/禁用滤波
manager->setFilterEnabled(true);

// 设置变化阈值
manager->setChangeThreshold(10);
```

### 4.2 QML 代码使用

```qml
AIDataManager {
    id: aiManager

    // 滤波器配置
    filterType: "combined"  // 可选：median, average, limit, lag, combined, lightweight
    filterEnabled: true

    // 变化阈值
    changeThreshold: 10

    // 监听数据变化
    onModule3DataChanged: {
        console.log("模块3数据更新（已滤波）")
    }
}
```

---

## 五、滤波器参数说明

### 5.1 中值滤波器（MedianFilter）

**参数**：
- `windowSize`：窗口大小（默认5）

**原理**：
- 取最近N个采样值的中值
- 排序后取中间值

**效果**：
- 去除脉冲干扰效果好
- 对周期性干扰效果一般

### 5.2 滑动平均滤波器（MovingAverageFilter）

**参数**：
- `windowSize`：窗口大小（默认8）

**原理**：
- 取最近N个采样值的算术平均

**效果**：
- 平滑周期性干扰
- 对脉冲干扰效果一般

### 5.3 限幅滤波器（LimitFilter）

**参数**：
- `maxDelta`：最大变化量（默认100）

**原理**：
- 如果新值与上次值差值超过阈值，则认为异常
- 异常值使用上次值

**效果**：
- 去除偶然出现的大幅跳变
- 对渐变干扰无效

### 5.4 一阶滞后滤波器（FirstOrderLagFilter）

**参数**：
- `alpha`：滞后系数（0-1，默认0.3）

**原理**：
- 指数移动平均：`output = alpha * input + (1-alpha) * lastOutput`
- alpha越小，滤波效果越强，响应越慢

**效果**：
- 平滑慢变化量
- 响应速度可调

### 5.5 组合滤波器（CombinedFilter）

**参数**：
- `medianSize`：中值窗口（默认5）
- `averageSize`：平均窗口（默认8）

**原理**：
- 先中值滤波去除脉冲
- 再滑动平均平滑数据

**效果**：
- 综合效果最好
- 推荐工业现场使用

### 5.6 轻量级滤波器（LightweightFilter）

**参数**：
- `maxDelta`：限幅阈值（默认100）
- `alpha`：滞后系数（默认0.3）

**原理**：
- 先限幅去除异常值
- 再一阶滞后平滑

**效果**：
- 计算量小
- 适合资源受限场景

---

## 六、验证测试

### 测试1：滤波器初始化（待测试）

**操作**：
```cpp
AIDataManager manager;
qDebug() << manager.filterType();     // 应输出 "combined"
qDebug() << manager.filterEnabled();  // 应输出 true
```

**预期结果**：
- 默认使用组合滤波器
- 默认启用滤波
- 日志输出：`✅ [AIDataManager] 初始化模拟量数据管理器（滤波器:combined）`

### 测试2：滤波器切换（待测试）

**操作**：
```cpp
manager.setFilterType("median");
```

**预期结果**：
- 日志输出：`✅ [AIDataManager] 滤波器类型:median`
- 日志输出：`✅ [AIDataManager] 滤波器初始化完成，类型:median`
- 发送 `filterTypeChanged()` 信号

### 测试3：滤波效果验证（待测试）

**操作**：
1. 连接设备 192.168.10.154
2. 观察原始AD值波动
3. 启用滤波器
4. 观察滤波后AD值波动

**预期结果**：
- 滤波后AD值波动明显减小
- 脉冲干扰被去除
- 数据更平滑

### 测试4：禁用滤波器（待测试）

**操作**：
```cpp
manager.setFilterEnabled(false);
```

**预期结果**：
- 日志输出：`✅ [AIDataManager] 滤波器禁用`
- AD值恢复为原始值（无滤波）

---

## 七、性能分析

### 7.1 计算复杂度

| 滤波器类型 | 时间复杂度 | 空间复杂度 | 说明 |
|-----------|-----------|-----------|------|
| `median` | O(N log N) | O(N) | N=5，排序开销 |
| `average` | O(N) | O(N) | N=8，累加开销 |
| `limit` | O(1) | O(1) | 最快 |
| `lag` | O(1) | O(1) | 最快 |
| `combined` | O(N log N) | O(N) | 中值+平均 |
| `lightweight` | O(1) | O(1) | 最快 |

### 7.2 内存占用

**每个滤波器实例**：
- `MedianFilter`：5 × 2字节 = 10字节
- `MovingAverageFilter`：8 × 2字节 = 16字节
- `LimitFilter`：2字节
- `FirstOrderLagFilter`：2字节
- `CombinedFilter`：26字节（10+16）
- `LightweightFilter`：4字节

**总内存占用**（16个滤波器）：
- `combined`：26 × 16 = 416字节
- `lightweight`：4 × 16 = 64字节

**结论**：内存占用极小，可忽略不计。

### 7.3 CPU 占用

**假设**：
- 采样频率：100Hz（每秒100次）
- 16个通道

**计算量**：
- `combined`：16 × 100 × (5 log 5 + 8) ≈ 25,600次操作/秒
- `lightweight`：16 × 100 × 2 = 3,200次操作/秒

**结论**：CPU占用极小，对系统性能影响可忽略。

---

## 八、后续优化

### 8.1 短期优化（1-2周）

1. **添加滤波器参数配置**
   - 支持自定义窗口大小
   - 支持自定义滞后系数
   - 支持自定义限幅阈值

2. **添加滤波器性能监控**
   - 统计滤波前后AD值差异
   - 统计滤波器执行时间
   - 记录滤波器切换次数

3. **添加滤波器自适应调整**
   - 根据噪声水平自动选择滤波器类型
   - 根据变化速度自动调整参数

### 8.2 长期优化（1-2月）

1. **添加卡尔曼滤波器**
   - 更精确的状态估计
   - 适合动态系统

2. **添加自适应滤波器**
   - 根据信号特性自动调整参数
   - 适合复杂工况

3. **添加滤波器效果评估**
   - 信噪比计算
   - 滤波效果可视化

---

## 九、完成总结

✅ **ADFilter.h 滤波器库**：6种滤波算法，工业级实现
✅ **AIDataManager.h 集成**：新增滤波器配置属性和方法
✅ **AIDataManager.cpp 实现**：滤波器初始化、切换、应用
✅ **默认配置**：组合滤波器（中值+平均），默认启用
✅ **性能优化**：内存占用极小，CPU占用可忽略

**下一步**：
1. 编译测试（确保无编译错误）
2. 部署到设备 192.168.10.154
3. 验证滤波效果（观察AD值波动）
4. 根据实际效果调整滤波器参数

---

**文档版本**：v1.0
**创建时间**：2026-03-06 16:30
**作者**：Claude
**审阅状态**：待审阅
