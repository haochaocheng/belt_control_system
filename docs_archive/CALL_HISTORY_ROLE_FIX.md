# 通话记录显示修复 - Role 名称问题

## 问题描述

**用户反馈**:
- ❌ 时间和时长没有显示
- ❌ 底部显示 0 条通话记录
- ✅ 接入的通话可以记录
- ❌ 本机拨打的通话没有记录

## 根本原因

QML 使用的 model role 名称与 Risip SDK 提供的 role 名称不匹配：

### Risip SDK 的 Role 定义

**文件**: `F:\0\risip-master\risip-master\src\risipsdk\core\models\risipcallhistorymodel.h`

```cpp
enum CallDataRole {
    CallContactRole = Qt::UserRole + 1,     // "callContact"
    CallDirectionRole,                       // "callDirection"
    CallDurationRole,                        // "callDuration"
    CallTimestampRole                        // "callTimestamp"
};
```

**文件**: `F:\0\risip-master\risip-master\src\risipsdk\core\models\risipcallhistorymodel.cpp`

```cpp
QHash<int, QByteArray> RisipCallHistoryModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[CallContactRole] = "callContact";      // ✅ 带 "call" 前缀
    roles[CallDirectionRole] = "callDirection";  // ✅ 带 "call" 前缀
    roles[CallDurationRole] = "callDuration";    // ✅ 带 "call" 前缀
    roles[CallTimestampRole] = "callTimestamp";  // ✅ 带 "call" 前缀
    return roles;
}
```

### QML 之前使用的错误 Role 名称

**文件**: [SipHistoryPage.qml](src/qml/components/sip_phone/pages/SipHistoryPage.qml)

```qml
// ❌ 错误：缺少 "call" 前缀
model.contact      // 应该是 model.callContact
model.direction    // 应该是 model.callDirection
model.duration     // 应该是 model.callDuration
model.timestamp    // 应该是 model.callTimestamp
```

**影响**:
- QML 访问不存在的 role 名称时返回 `undefined`
- 时间和时长显示为空
- `model.rowCount()` 可能返回 0（因为绑定失效）

---

## 修复方案

### 修改文件: [SipHistoryPage.qml](src/qml/components/sip_phone/pages/SipHistoryPage.qml)

将所有 model role 引用改为正确的名称（添加 "call" 前缀）：

| 修改前（错误） | 修改后（正确） | 说明 |
|---------------|---------------|------|
| `model.contact` | `model.callContact` | 联系人号码 |
| `model.direction` | `model.callDirection` | 呼叫方向 (0=拨出, 1=接入) |
| `model.duration` | `model.callDuration` | 通话时长（秒） |
| `model.timestamp` | `model.callTimestamp` | 通话时间戳 |

### 具体修改位置

#### 1. 通话类型图标 (Line 221-223)
```qml
// 修改前
if (model.direction === 0) return "📤"
if (model.direction === 1) return "📥"

// 修改后
if (model.callDirection === 0) return "📤"
if (model.callDirection === 1) return "📥"
```

#### 2. 联系人号码显示 (Line 236)
```qml
// 修改前
text: model.contact || "未知号码"

// 修改后
text: model.callContact || "未知号码"
```

#### 3. 呼叫方向标签 (Line 243)
```qml
// 修改前
text: model.direction === 0 ? "拨出" : "接入"

// 修改后
text: model.callDirection === 0 ? "拨出" : "接入"
```

#### 4. 时间戳显示 (Line 255, 261)
```qml
// 修改前
text: Qt.formatDateTime(model.timestamp, "yyyy-MM-dd")
text: Qt.formatDateTime(model.timestamp, "hh:mm:ss")

// 修改后
text: Qt.formatDateTime(model.callTimestamp, "yyyy-MM-dd")
text: Qt.formatDateTime(model.callTimestamp, "hh:mm:ss")
```

#### 5. 通话时长显示 (Line 269)
```qml
// 修改前
text: formatDuration(model.duration || 0)

// 修改后
text: formatDuration(model.callDuration || 0)
```

#### 6. 回拨按钮 (Line 293)
```qml
// 修改前
root.callNumber(model.contact || "")

// 修改后
root.callNumber(model.callContact || "")
```

---

## 编译状态

- ✅ 编译成功 (2025-12-09)
- ✅ 可执行文件: `build/bin_windows/belt_control_system.exe`
- ✅ 所有 role 名称已修复

---

## 测试步骤

### 测试 1: 拨出通话记录

1. 运行应用程序:
   ```bash
   build/bin_windows/belt_control_system.exe
   ```

2. 登录 SIP 账户

3. 本机拨打对方号码（语音或视频通话）

4. 通话结束后，切换到"历史"页面

5. **检查**:
   - ✅ 应该显示通话记录（拨出图标 📤）
   - ✅ 联系人号码应该显示
   - ✅ 时间应该显示（yyyy-MM-dd 和 hh:mm:ss）
   - ✅ 时长应该显示（MM:SS 格式）
   - ✅ 底部状态栏应显示"显示 X 条通话记录"（X > 0）

### 测试 2: 接入通话记录

1. 让对方拨打本机号码

2. 接听通话

3. 通话结束后，切换到"历史"页面

4. **检查**:
   - ✅ 应该显示通话记录（接入图标 📥）
   - ✅ 联系人号码应该显示
   - ✅ 时间应该显示
   - ✅ 时长应该显示
   - ✅ 记录总数增加

### 测试 3: 混合记录

1. 进行多次拨出和接入通话

2. 切换到"历史"页面

3. **检查**:
   - ✅ 所有记录都显示完整
   - ✅ 拨出和接入记录都正确显示图标
   - ✅ 时间按倒序排列（最新的在上面）
   - ✅ 可以点击回拨按钮重新拨打

### 测试 4: 筛选功能

1. 点击"全部"按钮 - 应显示所有记录
2. 点击"未接"按钮 - 应只显示未接来电
3. 点击"已拨"按钮 - 应只显示拨出记录

---

## 已知问题（可能需要进一步调查）

### 问题 1: 本机拨打的通话没有记录

**可能原因**:

1. **Risip SDK 的 Call History 保存逻辑**:
   - 检查 `RisipCallManager` 是否只在 `onCallStateChanged` 的特定状态保存记录
   - 拨出通话可能需要特定的结束状态才会保存

2. **Call ID 不匹配**:
   - 拨出通话的 Call ID 可能与记录关联的 Call ID 不一致

3. **账户 URI 不匹配**:
   - Risip 按账户 URI 过滤记录，拨出通话可能使用了不同的 URI 格式

**调查方法**:

```bash
# 查看拨出通话时的日志
# 搜索关键词: "Call state changed", "Saving call history", "Call ended"
```

**可能需要修改**:
- `src/risip/core/risipcallmanager.cpp` - Call state handler
- `src/risip/core/models/risipcallhistorymodel.cpp` - Save logic

### 问题 2: 底部显示 0 条记录

**可能原因**:

1. **Model 未正确绑定**: 虽然 role 名称已修复，但如果 model 是 `null` 或未初始化，仍会显示 0

2. **rowCount() 返回错误**: Risip SDK 的 model 实现问题

**验证方法**:

在 QML 中添加调试信息：
```qml
Component.onCompleted: {
    console.log("History model:", historyList.model)
    console.log("Row count:", historyList.model ? historyList.model.rowCount() : "null")
}
```

---

## 技术参考

### Qt Model/View 角色名称机制

**QAbstractListModel::roleNames()**:
- 返回一个 `QHash<int, QByteArray>` 映射
- key = Role 枚举值 (如 `Qt::UserRole + 1`)
- value = QML 中使用的角色名称字符串 (如 `"callContact"`)

**QML 数据绑定**:
```qml
ListView {
    model: myModel
    delegate: Text {
        text: model.callContact  // QML 自动查找 "callContact" 角色
    }
}
```

如果 QML 使用 `model.contact` 但 roleNames() 中只定义了 `"callContact"`，则返回 `undefined`。

### Risip CallHistoryModel 数据结构

```cpp
class RisipCallHistoryModel : public QAbstractListModel {
    // 数据成员
    QList<RisipCallHistoryRecord*> m_records;

    // Role 定义
    enum CallDataRole {
        CallContactRole = Qt::UserRole + 1,  // 号码
        CallDirectionRole,                    // 0=拨出, 1=接入
        CallDurationRole,                     // 时长（秒）
        CallTimestampRole                     // QDateTime 时间戳
    };
};
```

---

## 相关文件

- **已修改**:
  - [SipHistoryPage.qml:217-295](src/qml/components/sip_phone/pages/SipHistoryPage.qml#L217-L295) - **Role 名称修复（本次修改）**

- **Risip SDK 源码**（参考）:
  - `F:\0\risip-master\risip-master\src\risipsdk\core\models\risipcallhistorymodel.h` - Role 定义
  - `F:\0\risip-master\risip-master\src\risipsdk\core\models\risipcallhistorymodel.cpp` - roleNames() 实现

- **相关修复**:
  - [SipHistoryPage.qml:12-22](src/qml/components/sip_phone/pages/SipHistoryPage.qml#L12-L22) - 注册状态监听（之前修复）

---

## 下一步

### 如果测试后仍有问题：

#### 场景 A: 时间和时长仍然不显示

**可能原因**: Risip SDK 的数据类型与 QML 不兼容

**调试方法**:
```qml
Text {
    text: {
        console.log("callTimestamp type:", typeof model.callTimestamp)
        console.log("callTimestamp value:", model.callTimestamp)
        console.log("callDuration type:", typeof model.callDuration)
        console.log("callDuration value:", model.callDuration)
        return "Debug info"
    }
}
```

#### 场景 B: 底部仍显示 0 条记录

**可能原因**: Model 未正确绑定或返回 null

**解决方案**:
1. 检查 `SipPhoneManager::getCallHistoryModel()` 返回值
2. 添加 null 检查和错误处理
3. 确保在账户注册成功后才获取 model

#### 场景 C: 拨出通话仍然不记录

**需要调查**: Risip SDK 的 Call History 保存逻辑

**可能需要修改**:
- `risipcallmanager.cpp` 中的 call state change handler
- 确保拨出通话在结束时调用 `saveCallHistory()`

---

预期修复后所有显示问题都应该解决。如果还有问题，请提供新的测试日志。🎉
